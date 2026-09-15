import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../app/widgets/crt_overlay.dart';
import '../../domain/models/doom_map.dart';
import '../../domain/projection/hologram_camera.dart';
import '../../domain/projection/map_mesh.dart';
import 'doom_map_painter.dart';
import 'map_geometry.dart';

/// Palette for the holographic view, matching the boot splash: white-hot
/// cores bleeding into crimson, with amber as the warm secondary.
class HologramPalette {
  const HologramPalette._();

  static const Color core = Color(0xFFFFF1EC);
  static const Color primary = Color(0xFFDC143C);
  static const Color secondary = Color(0xFFE85D3A);
  static const Color cool = Color(0xFF4FC3F7);
  static const Color secret = Color(0xFFFFD54F);
  static const Color player = Color(0xFF66BB6A);
  static const Color selection = Color(0xFFFFEB3B);
  static const Color grid = Color(0xFF6E2230);
}

/// Draws a [MapMesh] as a holographic projection.
///
/// Surfaces are drawn back to front and kept translucent, so the depth order
/// reads without needing a depth buffer — and where the painter's algorithm
/// does get an overlap wrong, transparency hides it rather than flickering.
///
/// Glow is what makes it read as a hologram, and glow is expensive: a blurred
/// stroke per line would mean thousands of blurred draws. Edges are instead
/// batched into one [Path] per colour bucket and stroked twice — once wide and
/// blurred, once thin and bright — so the whole frame costs a handful of draws.
class HologramPainter extends CustomPainter {
  final DoomMap map;
  final MapMesh mesh;
  final HologramCamera camera;
  final MapViewerLayers layers;
  final MapSelection? selection;

  /// Animation phase 0-1, driving the scan sweep.
  final double sweep;

  HologramPainter({
    required this.map,
    required this.mesh,
    required this.camera,
    required this.layers,
    required this.sweep,
    this.selection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackdrop(canvas, size);
    if (mesh.isEmpty) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    if (layers.showGrid) _paintGrid(canvas, size);
    if (layers.showSectors) _paintFloors(canvas, size);
    if (layers.showLinedefs) _paintWalls(canvas, size);
    if (layers.showThings) _paintThings(canvas, size);
    if (selection != null) _paintSelection(canvas, size);

    canvas.restore();
    _paintOverlay(canvas, size);
  }

  void _paintBackdrop(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, 0.35),
          radius: 1.15,
          colors: [Color(0xFF2A0F14), Color(0xFF170C0E), Color(0xFF0E0A0B)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );
  }

  /// Ground plane grid at the map's lowest floor, which anchors the geometry
  /// in space — without it the walls read as a flat scribble.
  void _paintGrid(Canvas canvas, Size size) {
    final bounds = map.bounds;
    if (bounds.width <= 0 || bounds.height <= 0) return;

    // Keep the line count bounded regardless of map size.
    var step = 128.0;
    while (bounds.width / step > 48 || bounds.height / step > 48) {
      step *= 2;
    }

    final z = mesh.minZ - 8;
    final path = Path();

    final startX = (bounds.minX / step).floor() * step;
    for (var x = startX; x <= bounds.maxX + step; x += step) {
      _addProjectedSegment(
        path,
        Vec3(x, bounds.minY, z),
        Vec3(x, bounds.maxY, z),
        size,
      );
    }
    final startY = (bounds.minY / step).floor() * step;
    for (var y = startY; y <= bounds.maxY + step; y += step) {
      _addProjectedSegment(
        path,
        Vec3(bounds.minX, y, z),
        Vec3(bounds.maxX, y, z),
        size,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = HologramPalette.grid.withValues(alpha: 0.5),
    );
  }

  void _paintFloors(Canvas canvas, Size size) {
    // Far to near, so nearer decks lay over further ones.
    final ordered = [...mesh.floors]..sort(
        (a, b) => _distance(b.centre).compareTo(_distance(a.centre)),
      );

    final outlines = Path();

    for (final floor in ordered) {
      final points = <Offset>[];
      for (final point in floor.points) {
        final projected = camera.project(point, size);
        if (!projected.visible) {
          points.clear();
          break;
        }
        points.add(projected.screen);
      }
      if (points.length < 3) continue;

      final path = Path()..addPolygon(points, true);

      final light = (floor.light / 255).clamp(0.0, 1.0);
      final base = floor.isSecret
          ? HologramPalette.secret
          : floor.isDamage
              ? HologramPalette.secondary
              : HologramPalette.primary;

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = base.withValues(alpha: 0.05 + 0.10 * light),
      );
      outlines.addPath(path, Offset.zero);
    }

    canvas.drawPath(
      outlines,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = HologramPalette.primary.withValues(alpha: 0.35),
    );
  }

  void _paintWalls(Canvas canvas, Size size) {
    final visible = <(WallQuad, List<Offset>, double)>[];

    for (final wall in mesh.walls) {
      final corners = <Offset>[];
      var ok = true;
      for (final corner in [wall.a, wall.b, wall.c, wall.d]) {
        final projected = camera.project(corner, size);
        if (!projected.visible) {
          ok = false;
          break;
        }
        corners.add(projected.screen);
      }
      if (!ok) continue;
      visible.add((wall, corners, _distance(wall.centre)));
    }

    visible.sort((a, b) => b.$3.compareTo(a.$3));

    // Fills go down first, back to front, then every edge is stroked in one
    // batch per bucket so the bloom stays cheap.
    final edgesByKind = <WallKind, Path>{};

    for (final (wall, corners, _) in visible) {
      final path = Path()..addPolygon(corners, true);
      final light = (wall.light / 255).clamp(0.0, 1.0);
      final colour = _colourFor(wall.kind);

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = colour.withValues(alpha: 0.06 + 0.16 * light),
      );

      edgesByKind.putIfAbsent(wall.kind, Path.new).addPath(path, Offset.zero);
    }

    for (final entry in edgesByKind.entries) {
      _strokeGlowing(
        canvas,
        entry.value,
        _colourFor(entry.key),
        width: entry.key == WallKind.solid ? 1.4 : 1.0,
        glowWidth: entry.key == WallKind.solid ? 5.0 : 3.5,
      );
    }
  }

  void _paintThings(Canvas canvas, Size size) {
    final stems = Path();
    final marks = <(Offset, Color, double)>[];

    for (final thing in mesh.things) {
      final top = camera.project(thing.position, size);
      if (!top.visible) continue;

      final base = camera.project(
        Vec3(thing.position.x, thing.position.y, thing.position.z - 16),
        size,
      );

      final colour = thing.isPlayerStart
          ? HologramPalette.player
          : thing.isTeleport
              ? HologramPalette.cool
              : HologramPalette.secondary;

      // A short stem tying the marker to the floor gives it a position in
      // depth; a floating dot alone is ambiguous.
      if (base.visible) {
        stems.moveTo(base.screen.dx, base.screen.dy);
        stems.lineTo(top.screen.dx, top.screen.dy);
      }

      // Scale with distance so near things do not swell into blobs.
      final radius = (260 / top.depth * 3).clamp(1.5, 5.0);
      marks.add((top.screen, colour, radius));
    }

    canvas.drawPath(
      stems,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = HologramPalette.secondary.withValues(alpha: 0.35),
    );

    final glow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (final (centre, colour, radius) in marks) {
      canvas.drawCircle(
        centre,
        radius * 1.8,
        glow..color = colour.withValues(alpha: 0.45),
      );
      canvas.drawCircle(centre, radius, Paint()..color = colour);
    }
  }

  void _paintSelection(Canvas canvas, Size size) {
    final path = Path();

    switch (selection!) {
      case LinedefSelection(:final linedefIndex):
        for (final wall in mesh.walls) {
          if (wall.linedefIndex != linedefIndex) continue;
          final corners = <Offset>[];
          var ok = true;
          for (final corner in [wall.a, wall.b, wall.c, wall.d]) {
            final projected = camera.project(corner, size);
            if (!projected.visible) {
              ok = false;
              break;
            }
            corners.add(projected.screen);
          }
          if (ok) path.addPolygon(corners, true);
        }
      case ThingSelection(:final thingIndex):
        for (final thing in mesh.things) {
          if (thing.thingIndex != thingIndex) continue;
          final projected = camera.project(thing.position, size);
          if (projected.visible) {
            path.addOval(
              Rect.fromCircle(center: projected.screen, radius: 9),
            );
          }
        }
      case SectorSelection(:final sectorIndex):
        for (final floor in mesh.floors) {
          if (floor.sectorIndex != sectorIndex) continue;
          final points = <Offset>[];
          var ok = true;
          for (final point in floor.points) {
            final projected = camera.project(point, size);
            if (!projected.visible) {
              ok = false;
              break;
            }
            points.add(projected.screen);
          }
          if (ok && points.length >= 3) path.addPolygon(points, true);
        }
    }

    if (path.getBounds().isEmpty) return;

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = HologramPalette.selection.withValues(alpha: 0.16),
    );
    _strokeGlowing(
      canvas,
      path,
      HologramPalette.selection,
      width: 2,
      glowWidth: 7,
    );
  }

  /// Scanlines, a travelling scan band and a vignette — the same treatment the
  /// boot splash uses, so the two screens read as one system.
  void _paintOverlay(Canvas canvas, Size size) {
    CrtOverlay.paintScanlines(canvas, size, opacity: 0.13);

    final bandY = size.height * sweep;
    canvas.drawRect(
      Rect.fromLTWH(0, bandY - 40, size.width, 80),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, bandY - 40),
          Offset(0, bandY + 40),
          [
            HologramPalette.primary.withValues(alpha: 0.0),
            HologramPalette.primary.withValues(alpha: 0.07),
            HologramPalette.primary.withValues(alpha: 0.0),
          ],
          [0.0, 0.5, 1.0],
        ),
    );

    CrtOverlay.paintVignette(canvas, size, start: 0.6);
  }

  /// Strokes [path] twice: a wide blurred pass for bloom, then a bright core.
  void _strokeGlowing(
    Canvas canvas,
    Path path,
    Color colour, {
    required double width,
    required double glowWidth,
  }) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = glowWidth
        ..color = colour.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = Color.lerp(colour, HologramPalette.core, 0.55)!
            .withValues(alpha: 0.95),
    );
  }

  void _addProjectedSegment(Path path, Vec3 from, Vec3 to, Size size) {
    final a = camera.project(from, size);
    final b = camera.project(to, size);
    if (!a.visible || !b.visible) return;
    path.moveTo(a.screen.dx, a.screen.dy);
    path.lineTo(b.screen.dx, b.screen.dy);
  }

  double _distance(Vec3 point) => (point - camera.position).length;

  static Color _colourFor(WallKind kind) => switch (kind) {
        WallKind.solid => HologramPalette.primary,
        WallKind.lowerStep => HologramPalette.secondary,
        WallKind.upperStep => HologramPalette.secondary,
        WallKind.trigger => HologramPalette.cool,
        WallKind.secret => HologramPalette.secret,
      };

  @override
  bool shouldRepaint(covariant HologramPainter oldDelegate) {
    return oldDelegate.mesh != mesh ||
        oldDelegate.camera.yaw != camera.yaw ||
        oldDelegate.camera.pitch != camera.pitch ||
        oldDelegate.camera.distance != camera.distance ||
        oldDelegate.camera.panOffset != camera.panOffset ||
        oldDelegate.layers != layers ||
        oldDelegate.selection != selection ||
        oldDelegate.sweep != sweep;
  }
}
