import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/features/map_viewer/domain/projection/hologram_camera.dart';

void main() {
  const size = Size(800, 600);

  group('position', () {
    test('sits at distance from the target, above it', () {
      final camera = HologramCamera(
        yaw: 0,
        pitch: math.pi / 4,
        distance: 1000,
        target: Vec3.zero,
      );

      final position = camera.position;
      expect(position.length, closeTo(1000, 0.001));
      expect(position.z, greaterThan(0), reason: 'the camera looks down');
    });

    test('yaw swings the camera around the target', () {
      final east = HologramCamera(yaw: 0, pitch: 0.3, distance: 500).position;
      final north =
          HologramCamera(yaw: math.pi / 2, pitch: 0.3, distance: 500).position;

      expect(east.x, greaterThan(0));
      expect(east.y, closeTo(0, 0.001));
      expect(north.y, greaterThan(0));
      expect(north.x, closeTo(0, 0.001));
    });
  });

  group('project', () {
    test('the target lands at the centre of the viewport', () {
      final camera = HologramCamera(distance: 1000, target: Vec3.zero);
      final projected = camera.project(Vec3.zero, size);

      expect(projected.visible, isTrue);
      expect(projected.screen.dx, closeTo(size.width / 2, 0.001));
      expect(projected.screen.dy, closeTo(size.height / 2, 0.001));
      expect(projected.depth, closeTo(1000, 0.001));
    });

    test('height moves a point up the screen', () {
      final camera = HologramCamera(distance: 1000, target: Vec3.zero);

      final floor = camera.project(Vec3.zero, size);
      final raised = camera.project(const Vec3(0, 0, 200), size);

      expect(raised.screen.dy, lessThan(floor.screen.dy));
    });

    test('points behind the camera are rejected', () {
      final camera = HologramCamera(
        yaw: 0,
        pitch: 0.3,
        distance: 500,
        target: Vec3.zero,
      );

      // Twice the camera distance along its own axis: well behind the lens.
      final behind = camera.position * 2;
      expect(camera.project(behind, size).visible, isFalse);
    });

    test('nearer points project further from centre than far ones', () {
      final camera = HologramCamera(distance: 2000, target: Vec3.zero);

      final near = camera.project(const Vec3(0, 0, 100), size);
      final far = camera.project(const Vec3(0, 0, 100), size);
      expect(near.screen, far.screen, reason: 'projection is deterministic');

      final closer = HologramCamera(distance: 1000, target: Vec3.zero)
          .project(const Vec3(0, 0, 100), size);
      expect(
        (closer.screen - Offset(size.width / 2, size.height / 2)).distance,
        greaterThan(
          (near.screen - Offset(size.width / 2, size.height / 2)).distance,
        ),
        reason: 'dollying in magnifies the offset from centre',
      );
    });

    test('pan shifts the whole projection', () {
      final camera = HologramCamera(distance: 1000, target: Vec3.zero)
        ..pan(const Offset(40, -25));

      final projected = camera.project(Vec3.zero, size);
      expect(projected.screen.dx, closeTo(size.width / 2 + 40, 0.001));
      expect(projected.screen.dy, closeTo(size.height / 2 - 25, 0.001));
    });
  });

  group('controls', () {
    test('pitch is clamped so the camera never flips over the map', () {
      final camera = HologramCamera(pitch: 0.5);

      camera.orbit(0, 10);
      expect(camera.pitch, HologramCamera.maxPitch);

      camera.orbit(0, -10);
      expect(camera.pitch, HologramCamera.minPitch);
    });

    test('dolly is clamped at both ends', () {
      final camera = HologramCamera(distance: 1000);

      camera.dolly(0.0001);
      expect(camera.distance, HologramCamera.minDistance);

      camera.dolly(100000);
      expect(camera.distance, HologramCamera.maxDistance);
    });
  });

  group('frame', () {
    /// Projects the corners of a footprint and reports whether all fit.
    bool footprintFits(HologramCamera camera, double w, double d, Size size) {
      for (final corner in [
        Vec3(-w / 2, -d / 2, 0),
        Vec3(w / 2, -d / 2, 0),
        Vec3(w / 2, d / 2, 0),
        Vec3(-w / 2, d / 2, 0),
      ]) {
        final projected = camera.project(corner, size);
        if (!projected.visible) return false;
        if (projected.screen.dx < 0 || projected.screen.dx > size.width) {
          return false;
        }
        if (projected.screen.dy < 0 || projected.screen.dy > size.height) {
          return false;
        }
      }
      return true;
    }

    test('fits the footprint at a range of angles', () {
      const width = 4000.0;
      const depth = 1500.0;

      for (final yaw in [0.0, 0.4, -math.pi / 4, math.pi / 3, math.pi]) {
        for (final pitch in [0.25, 0.62, 1.2]) {
          final camera = HologramCamera(yaw: yaw, pitch: pitch);
          camera.frame(
            centre: Vec3.zero,
            width: width,
            depth: depth,
            aspect: size.width / size.height,
          );

          expect(
            footprintFits(camera, width, depth, size),
            isTrue,
            reason: 'yaw $yaw pitch $pitch left part of the map off screen',
          );
        }
      }
    });

    test('a wider map needs more distance', () {
      final small = HologramCamera()
        ..frame(centre: Vec3.zero, width: 1000, depth: 1000);
      final large = HologramCamera()
        ..frame(centre: Vec3.zero, width: 8000, depth: 8000);

      expect(large.distance, greaterThan(small.distance));
    });

    test('framing recentres and clears any pan', () {
      final camera = HologramCamera()..pan(const Offset(120, 90));
      camera.frame(
        centre: const Vec3(500, -300, 40),
        width: 1000,
        depth: 1000,
      );

      expect(camera.panOffset, Offset.zero);
      expect(camera.target.x, 500);
      expect(camera.target.y, -300);
    });

    test('a degenerate footprint still yields a usable distance', () {
      final camera = HologramCamera()
        ..frame(centre: Vec3.zero, width: 0, depth: 0);

      expect(camera.distance, greaterThanOrEqualTo(HologramCamera.minDistance));
      expect(camera.distance.isFinite, isTrue);
    });
  });
}
