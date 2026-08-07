import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/features/map_viewer/domain/models/doom_map.dart';
import 'package:quickdoom/features/map_viewer/presentation/widgets/map_viewport.dart';

void main() {
  const bounds = MapBounds(minX: 0, maxX: 100, minY: -50, maxY: 50);

  group('MapViewport world/screen mapping', () {
    test('flips the Y axis (Doom up is screen down)', () {
      final viewport = MapViewport(scale: 2, offsetX: 10, offsetY: 20);
      final low = viewport.worldToScreen(0, -50);
      final high = viewport.worldToScreen(0, 50);

      expect(low.dy, greaterThan(high.dy));
      expect(high, const Offset(10, -80));
    });

    test('screenToWorld is the inverse of worldToScreen', () {
      final viewport = MapViewport(scale: 3.5, offsetX: 40, offsetY: -25);
      final screen = viewport.worldToScreen(12.5, -7.25);
      final (x, y) = viewport.screenToWorld(screen);

      expect(x, closeTo(12.5, 1e-9));
      expect(y, closeTo(-7.25, 1e-9));
    });
  });

  group('MapViewport fit', () {
    test('fits bounds into a wider viewport', () {
      final viewport = MapViewport();
      viewport.fit(bounds, const Size(500, 200));

      expect(viewport.scale, closeTo(1.36, 0.01)); // height limited
      final topLeft = viewport.worldToScreen(0, 50);
      final bottomRight = viewport.worldToScreen(100, -50);
      expect(topLeft.dx, closeTo(182, 1e-6));
      expect(topLeft.dy, closeTo(32, 1e-6));
      expect(bottomRight.dx, closeTo(318, 1e-6));
      expect(bottomRight.dy, closeTo(168, 1e-6));
    });

    test('fits bounds into a taller viewport', () {
      final viewport = MapViewport();
      viewport.fit(bounds, const Size(200, 500));

      expect(viewport.scale, closeTo(1.36, 0.01)); // width limited
      final topLeft = viewport.worldToScreen(0, 50);
      final bottomRight = viewport.worldToScreen(100, -50);
      expect(topLeft.dx, closeTo(32, 1e-6));
      expect(topLeft.dy, closeTo(182, 1e-6));
      expect(bottomRight.dx, closeTo(168, 1e-6));
      expect(bottomRight.dy, closeTo(318, 1e-6));
    });

    test('handles empty bounds without crashing', () {
      final viewport = MapViewport();
      viewport.fit(MapBounds.empty, const Size(300, 300));
      expect(viewport.scale, 1);
    });
  });

  group('MapViewport pan and zoom', () {
    test('pan shifts offsets', () {
      final viewport = MapViewport(scale: 1, offsetX: 0, offsetY: 0);
      viewport.pan(5, -7);
      expect(viewport.offsetX, 5);
      expect(viewport.offsetY, -7);
    });

    test('zoomAt keeps the world point under the focal fixed', () {
      final viewport = MapViewport(scale: 2, offsetX: 10, offsetY: 20);
      const focal = Offset(100, 80);
      final before = viewport.screenToWorld(focal);

      viewport.zoomAt(focal, 4);

      final after = viewport.screenToWorld(focal);
      expect(viewport.scale, 8);
      expect(after.$1, closeTo(before.$1, 1e-9));
      expect(after.$2, closeTo(before.$2, 1e-9));
    });

    test('zoom is clamped to min/max scale', () {
      final viewport = MapViewport(scale: 1, offsetX: 0, offsetY: 0);
      viewport.zoomAt(Offset.zero, 0.0001);
      expect(viewport.scale, MapViewport.minScale);
      viewport.zoomAt(Offset.zero, 1e12);
      expect(viewport.scale, MapViewport.maxScale);
    });
  });
}
