import 'dart:ui';

import '../../domain/models/doom_map.dart';

/// A closed polygon loop of vertex indices, used to fill a sector.
class SectorLoop {
  final int sectorIndex;
  final List<int> vertexIndices;

  const SectorLoop({required this.sectorIndex, required this.vertexIndices});
}

/// Pure geometry helpers: builds sector polygons from linedefs and picks the
/// element under a world-space point.
class MapGeometry {
  /// Builds the closed loops that make up each sector by walking the sidedef
  /// edges. Every sidedef contributes its linedef's edge, flipped so the loop
  /// is consistently wound (the front side of a linedef is on its right).
  static List<SectorLoop> buildSectorLoops(DoomMap map) {
    final edgesBySector = <int, List<(int, int)>>{};
    for (var i = 0; i < map.linedefs.length; i++) {
      final line = map.linedefs[i];
      final start = line.startVertexIndex;
      final end = line.endVertexIndex;

      final front = map.sidedefAt(line.frontSidedefIndex);
      if (front != null) {
        edgesBySector
            .putIfAbsent(front.sectorIndex, () => [])
            .add((start, end));
      }
      final back = map.sidedefAt(line.backSidedefIndex);
      if (back != null) {
        edgesBySector
            .putIfAbsent(back.sectorIndex, () => [])
            .add((end, start));
      }
    }

    final loops = <SectorLoop>[];
    edgesBySector.forEach((sectorIndex, edges) {
      final used = List<bool>.filled(edges.length, false);
      for (var i = 0; i < edges.length; i++) {
        if (used[i]) continue;
        final loop = <int>[];
        var (currentStart, currentEnd) = edges[i];
        used[i] = true;
        loop.add(currentStart);
        loop.add(currentEnd);

        var advanced = true;
        while (advanced && currentEnd != edges[i].$1) {
          advanced = false;
          for (var j = 0; j < edges.length; j++) {
            if (used[j]) continue;
            if (edges[j].$1 == currentEnd) {
              used[j] = true;
              currentEnd = edges[j].$2;
              loop.add(currentEnd);
              advanced = true;
              break;
            }
          }
        }
        if (loop.length >= 3) {
          loops.add(SectorLoop(sectorIndex: sectorIndex, vertexIndices: loop));
        }
      }
    });
    return loops;
  }

  /// Distance from a point to the segment [a]-[b].
  static double distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return (p - a).distance;
    final t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / lengthSquared;
    final clamped = t.clamp(0.0, 1.0);
    final projection =
        Offset(a.dx + ab.dx * clamped, a.dy + ab.dy * clamped);
    return (p - projection).distance;
  }

  /// Index of the linedef whose segment is closest to [point] within
  /// [maxDistance] world units, or -1.
  static int pickLinedef(DoomMap map, Offset point, double maxDistance) {
    var best = -1;
    var bestDistance = maxDistance;
    for (var i = 0; i < map.linedefs.length; i++) {
      final line = map.linedefs[i];
      final a = map.vertexAt(line.startVertexIndex);
      final b = map.vertexAt(line.endVertexIndex);
      if (a == null || b == null) continue;
      final distance = distanceToSegment(
        point,
        Offset(a.x.toDouble(), a.y.toDouble()),
        Offset(b.x.toDouble(), b.y.toDouble()),
      );
      if (distance <= bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    return best;
  }

  /// Index of the thing closest to [point] within [maxDistance] world units,
  /// or -1.
  static int pickThing(DoomMap map, Offset point, double maxDistance) {
    var best = -1;
    var bestDistance = maxDistance;
    for (var i = 0; i < map.things.length; i++) {
      final thing = map.things[i];
      final distance = (point -
              Offset(thing.x.toDouble(), thing.y.toDouble()))
          .distance;
      if (distance <= bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    return best;
  }

  /// Sector index containing [point] using even-odd ray casting over the
  /// sector loops, or -1. Holes (inner loops) are handled by counting all
  /// loops of a sector together with even-odd winding.
  static int sectorAtPoint(
    DoomMap map,
    Offset point,
    List<SectorLoop> loops,
  ) {
    final loopsBySector = <int, List<List<int>>>{};
    for (final loop in loops) {
      loopsBySector.putIfAbsent(loop.sectorIndex, () => []).add(loop.vertexIndices);
    }
    for (final entry in loopsBySector.entries) {
      if (_pointInSector(map, entry.value, point)) return entry.key;
    }
    return -1;
  }

  static bool _pointInSector(DoomMap map, List<List<int>> loops, Offset p) {
    var crossings = 0;
    for (final vertices in loops) {
      for (var i = 0, j = vertices.length - 1; i < vertices.length; j = i++) {
        final vi = map.vertexAt(vertices[i]);
        final vj = map.vertexAt(vertices[j]);
        if (vi == null || vj == null) continue;
        final xi = vi.x.toDouble();
        final yi = vi.y.toDouble();
        final xj = vj.x.toDouble();
        final yj = vj.y.toDouble();

        if ((yi > p.dy) != (yj > p.dy) &&
            p.dx < (xj - xi) * (p.dy - yi) / (yj - yi) + xi) {
          crossings++;
        }
      }
    }
    return crossings.isOdd;
  }
}

/// A picked map element, for the inspector.
sealed class MapSelection {
  const MapSelection();
}

class LinedefSelection extends MapSelection {
  final int linedefIndex;
  const LinedefSelection(this.linedefIndex);
}

class ThingSelection extends MapSelection {
  final int thingIndex;
  const ThingSelection(this.thingIndex);
}

class SectorSelection extends MapSelection {
  final int sectorIndex;
  const SectorSelection(this.sectorIndex);
}

/// Picks the best element under a world-space point: a linedef if within
/// [linedefMaxDistance], else a thing within [thingMaxDistance], else the
/// sector containing the point.
MapSelection? pickElement(
  DoomMap map,
  Offset worldPoint, {
  double linedefMaxDistance = 16,
  double thingMaxDistance = 32,
  List<SectorLoop>? loops,
}) {
  final linedef = MapGeometry.pickLinedef(map, worldPoint, linedefMaxDistance);
  if (linedef >= 0) return LinedefSelection(linedef);

  final thing = MapGeometry.pickThing(map, worldPoint, thingMaxDistance);
  if (thing >= 0) return ThingSelection(thing);

  final sector = MapGeometry.sectorAtPoint(
    map,
    worldPoint,
    loops ?? MapGeometry.buildSectorLoops(map),
  );
  if (sector >= 0) return SectorSelection(sector);

  return null;
}

/// Distance threshold in world units for a given screen-space pixel tolerance.
double pixelsToWorld(double pixels, double scale) => pixels / scale;
