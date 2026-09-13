import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/doom_map.dart';
import 'map_geometry.dart';
import 'map_viewport.dart';

/// How the map is drawn: flat plan, or the extruded holographic projection.
enum MapViewMode { plan, hologram }

/// Which layers are drawn.
class MapViewerLayers {
  final bool showSectors;
  final bool showLinedefs;
  final bool showThings;
  final bool showGrid;

  const MapViewerLayers({
    this.showSectors = true,
    this.showLinedefs = true,
    this.showThings = true,
    this.showGrid = false,
  });

  MapViewerLayers copyWith({
    bool? showSectors,
    bool? showLinedefs,
    bool? showThings,
    bool? showGrid,
  }) {
    return MapViewerLayers(
      showSectors: showSectors ?? this.showSectors,
      showLinedefs: showLinedefs ?? this.showLinedefs,
      showThings: showThings ?? this.showThings,
      showGrid: showGrid ?? this.showGrid,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MapViewerLayers &&
      other.showSectors == showSectors &&
      other.showLinedefs == showLinedefs &&
      other.showThings == showThings &&
      other.showGrid == showGrid;

  @override
  int get hashCode =>
      Object.hash(showSectors, showLinedefs, showThings, showGrid);
}

/// Renders a [DoomMap] onto a canvas: optional sector fills, linedefs colored
/// by type, things and a grid. All coordinates go through [MapViewport] so the
/// world's y-up axis is flipped to the screen's y-down axis.
class DoomMapPainter extends CustomPainter {
  final DoomMap map;
  final MapViewport viewport;
  final MapViewerLayers layers;
  final MapSelection? selection;
  final List<SectorLoop> sectorLoops;

  DoomMapPainter({
    required this.map,
    required this.viewport,
    required this.layers,
    required this.sectorLoops,
    this.selection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF151515),
    );

    if (layers.showGrid) _paintGrid(canvas, size);
    if (layers.showSectors) _paintSectorFills(canvas);
    if (layers.showLinedefs) _paintLinedefs(canvas);
    if (layers.showThings) _paintThings(canvas);
    if (selection != null) _paintSelection(canvas);
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF222222)
      ..strokeWidth = 1;

    var gridSize = 64.0;
    while (gridSize * viewport.scale < 24) {
      gridSize *= 2;
    }

    final (minX, minY) = viewport.screenToWorld(Offset.zero);
    final (maxX, maxY) = viewport.screenToWorld(Offset(size.width, size.height));
    final minGridX = math.min(minX, maxX);
    final maxGridX = math.max(minX, maxX);
    final minGridY = math.min(minY, maxY);
    final maxGridY = math.max(minY, maxY);

    final firstX = (minGridX / gridSize).floor() * gridSize;
    for (var x = firstX; x <= maxGridX; x += gridSize) {
      final start = viewport.worldToScreen(x, minGridY);
      final end = viewport.worldToScreen(x, maxGridY);
      canvas.drawLine(start, end, paint);
    }
    final firstY = (minGridY / gridSize).floor() * gridSize;
    for (var y = firstY; y <= maxGridY; y += gridSize) {
      final start = viewport.worldToScreen(minGridX, y);
      final end = viewport.worldToScreen(maxGridX, y);
      canvas.drawLine(start, end, paint);
    }
  }

  void _paintSectorFills(Canvas canvas) {
    final fillCache = <int, Color>{};
    for (final loop in sectorLoops) {
      final path = Path();
      final vertices = <Offset>[];
      for (final index in loop.vertexIndices) {
        final vertex = map.vertexAt(index);
        if (vertex == null) continue;
        vertices.add(viewport.worldToScreen(vertex.x.toDouble(), vertex.y.toDouble()));
      }
      if (vertices.length < 3) continue;
      path.addPolygon(vertices, true);

      final sector = map.sectorAt(loop.sectorIndex);
      final light = sector?.lightLevel ?? 128;
      final fill = fillCache.putIfAbsent(loop.sectorIndex, () {
        final t = (light / 255).clamp(0.0, 1.0);
        return Color.lerp(const Color(0xFF1E1E1E), const Color(0xFF4A4A4A), t)!;
      });
      canvas.drawPath(
        path,
        Paint()
          ..color = fill
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF3A3A3A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  void _paintLinedefs(Canvas canvas) {
    for (var i = 0; i < map.linedefs.length; i++) {
      final line = map.linedefs[i];
      final a = map.vertexAt(line.startVertexIndex);
      final b = map.vertexAt(line.endVertexIndex);
      if (a == null || b == null) continue;

      final paint = Paint()..strokeWidth = 1.5;
      if (line.hasTrigger) {
        paint.color = const Color(0xFF4FC3F7); // blue: special action
      } else if (line.isSecret) {
        paint.color = const Color(0xFFFFD54F); // yellow: secret
      } else if (line.isTwoSided) {
        paint.color = const Color(0xFF8D8D8D); // gray: interior line
      } else {
        paint.color = const Color(0xFFE0E0E0); // bright: wall
      }

      canvas.drawLine(
        viewport.worldToScreen(a.x.toDouble(), a.y.toDouble()),
        viewport.worldToScreen(b.x.toDouble(), b.y.toDouble()),
        paint,
      );
    }
  }

  void _paintThings(Canvas canvas) {
    for (var i = 0; i < map.things.length; i++) {
      final thing = map.things[i];
      final center = viewport.worldToScreen(thing.x.toDouble(), thing.y.toDouble());
      final radius = 3.0;

      final paint = Paint();
      if (thing.isPlayerStart || thing.isHexenPlayerStart) {
        paint.color = const Color(0xFF66BB6A); // green
        canvas.drawCircle(center, radius + 1, paint);
        final angleRad = thing.angle * math.pi / 180;
        canvas.drawLine(
          center,
          center +
              Offset(math.cos(angleRad) * 8, -math.sin(angleRad) * 8) *
                  viewport.scale
                      .clamp(0.5, 2.0),
          Paint()
            ..color = const Color(0xFF66BB6A)
            ..strokeWidth = 1.5,
        );
      } else if (thing.isTeleportDestination) {
        paint.color = const Color(0xFF26C6DA); // cyan
        canvas.drawCircle(center, radius + 1, paint);
      } else {
        paint.color = const Color(0xFFEF5350); // red: monsters/items
      }
      canvas.drawCircle(center, radius, paint);
    }
  }

  void _paintSelection(Canvas canvas) {
    switch (selection!) {
      case LinedefSelection(:final linedefIndex):
        final line = map.linedefAt(linedefIndex);
        if (line == null) return;
        final a = map.vertexAt(line.startVertexIndex);
        final b = map.vertexAt(line.endVertexIndex);
        if (a == null || b == null) return;
        canvas.drawLine(
          viewport.worldToScreen(a.x.toDouble(), a.y.toDouble()),
          viewport.worldToScreen(b.x.toDouble(), b.y.toDouble()),
          Paint()
            ..color = const Color(0xFFFFEB3B)
            ..strokeWidth = 3,
        );
      case ThingSelection(:final thingIndex):
        final thing = map.things[thingIndex];
        canvas.drawCircle(
          viewport.worldToScreen(thing.x.toDouble(), thing.y.toDouble()),
          6,
          Paint()
            ..color = const Color(0xFFFFEB3B)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      case SectorSelection(:final sectorIndex):
        for (final loop in sectorLoops) {
          if (loop.sectorIndex != sectorIndex) continue;
          final vertices = <Offset>[];
          for (final index in loop.vertexIndices) {
            final vertex = map.vertexAt(index);
            if (vertex == null) continue;
            vertices.add(viewport.worldToScreen(vertex.x.toDouble(), vertex.y.toDouble()));
          }
          if (vertices.length < 3) continue;
          canvas.drawPath(
            Path()..addPolygon(vertices, true),
            Paint()
              ..color = const Color(0x33FFEB3B)
              ..style = PaintingStyle.fill,
          );
        }
    }
  }

  @override
  bool shouldRepaint(covariant DoomMapPainter oldDelegate) {
    return oldDelegate.map != map ||
        oldDelegate.viewport.scale != viewport.scale ||
        oldDelegate.viewport.offsetX != viewport.offsetX ||
        oldDelegate.viewport.offsetY != viewport.offsetY ||
        oldDelegate.layers != layers ||
        oldDelegate.selection != selection;
  }
}
