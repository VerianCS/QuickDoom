import 'dart:math' as math;

import '../models/doom_map.dart';
import 'hologram_camera.dart';

/// What a wall surface represents, which decides how it is lit and coloured.
enum WallKind {
  /// One-sided line: a solid wall from floor to ceiling.
  solid,

  /// The step up between two sectors' floors.
  lowerStep,

  /// The drop between two sectors' ceilings.
  upperStep,

  /// A line carrying an action special.
  trigger,

  /// A line flagged secret.
  secret,
}

/// One quad of wall, as four world-space corners wound bottom-left,
/// bottom-right, top-right, top-left.
class WallQuad {
  final Vec3 a;
  final Vec3 b;
  final Vec3 c;
  final Vec3 d;
  final WallKind kind;

  /// Sector light level 0-255, used to modulate brightness.
  final int light;

  /// Index of the linedef this came from, for selection.
  final int linedefIndex;

  const WallQuad({
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.kind,
    required this.light,
    required this.linedefIndex,
  });

  /// Midpoint, used for depth sorting.
  Vec3 get centre => Vec3(
        (a.x + b.x + c.x + d.x) / 4,
        (a.y + b.y + c.y + d.y) / 4,
        (a.z + b.z + c.z + d.z) / 4,
      );

  double get height => (d.z - a.z).abs();
}

/// A sector's floor outline, drawn as the "deck" the walls stand on.
class FloorPoly {
  final int sectorIndex;
  final List<Vec3> points;
  final int light;
  final bool isSecret;
  final bool isDamage;

  const FloorPoly({
    required this.sectorIndex,
    required this.points,
    required this.light,
    this.isSecret = false,
    this.isDamage = false,
  });

  Vec3 get centre {
    if (points.isEmpty) return Vec3.zero;
    var x = 0.0, y = 0.0, z = 0.0;
    for (final p in points) {
      x += p.x;
      y += p.y;
      z += p.z;
    }
    final n = points.length.toDouble();
    return Vec3(x / n, y / n, z / n);
  }
}

/// A thing, lifted onto the floor of the sector it stands in.
class ThingMarker {
  final Vec3 position;
  final int thingIndex;
  final bool isPlayerStart;
  final bool isTeleport;
  final double angleRadians;

  const ThingMarker({
    required this.position,
    required this.thingIndex,
    required this.isPlayerStart,
    required this.isTeleport,
    required this.angleRadians,
  });
}

/// The 3D form of a map: extruded walls, floor outlines and thing markers.
///
/// Doom has no explicit 3D geometry. Walls are reconstructed from linedefs and
/// the floor/ceiling heights of the sectors on either side, which is exactly
/// what the engine itself does when it renders.
class MapMesh {
  final List<WallQuad> walls;
  final List<FloorPoly> floors;
  final List<ThingMarker> things;

  /// Vertical span of the map, for framing and for the grid plane.
  final double minZ;
  final double maxZ;

  const MapMesh({
    required this.walls,
    required this.floors,
    required this.things,
    required this.minZ,
    required this.maxZ,
  });

  static const MapMesh empty = MapMesh(
    walls: [],
    floors: [],
    things: [],
    minZ: 0,
    maxZ: 0,
  );

  bool get isEmpty => walls.isEmpty && floors.isEmpty && things.isEmpty;

  Vec3 get centre => Vec3(0, 0, (minZ + maxZ) / 2);

  /// Builds the mesh for [map].
  ///
  /// [sectorLoops] comes from MapGeometry and is reused rather than rebuilt,
  /// since the 2D view has already paid for it.
  static MapMesh build(
    DoomMap map, {
    required List<({int sectorIndex, List<int> vertexIndices})> sectorLoops,
  }) {
    if (map.vertices.isEmpty) return empty;

    final walls = <WallQuad>[];
    var minZ = double.infinity;
    var maxZ = -double.infinity;

    void trackZ(double z) {
      if (z < minZ) minZ = z;
      if (z > maxZ) maxZ = z;
    }

    for (var i = 0; i < map.linedefs.length; i++) {
      final line = map.linedefs[i];
      final start = map.vertexAt(line.startVertexIndex);
      final end = map.vertexAt(line.endVertexIndex);
      if (start == null || end == null) continue;

      final x1 = start.x.toDouble();
      final y1 = start.y.toDouble();
      final x2 = end.x.toDouble();
      final y2 = end.y.toDouble();

      final frontSide = map.sidedefAt(line.frontSidedefIndex);
      final backSide = map.sidedefAt(line.backSidedefIndex);
      final front =
          frontSide == null ? null : map.sectorAt(frontSide.sectorIndex);
      final back = backSide == null ? null : map.sectorAt(backSide.sectorIndex);

      // Lines carrying a special or a secret flag are called out whatever
      // their geometry, so they stay findable in a dense map.
      WallKind kindFor(WallKind base) {
        if (line.isSecret) return WallKind.secret;
        if (line.hasTrigger) return WallKind.trigger;
        return base;
      }

      void addQuad(double bottom, double top, WallKind kind, int light) {
        if (top <= bottom) return;
        trackZ(bottom);
        trackZ(top);
        walls.add(WallQuad(
          a: Vec3(x1, y1, bottom),
          b: Vec3(x2, y2, bottom),
          c: Vec3(x2, y2, top),
          d: Vec3(x1, y1, top),
          kind: kind,
          light: light,
          linedefIndex: i,
        ));
      }

      if (back == null) {
        // One-sided: a solid wall spanning the whole sector.
        final sector = front;
        if (sector == null) {
          // Geometry with no sector reference still deserves a line on the
          // floor plane rather than vanishing.
          addQuad(0, 1, kindFor(WallKind.solid), 160);
          continue;
        }
        addQuad(
          sector.floorHeight.toDouble(),
          sector.ceilingHeight.toDouble(),
          kindFor(WallKind.solid),
          sector.lightLevel,
        );
        continue;
      }

      if (front == null) continue;

      // Two-sided: the visible surfaces are the height differences, which is
      // what a player actually sees as steps and overhangs.
      final floorLow = math.min(front.floorHeight, back.floorHeight).toDouble();
      final floorHigh = math.max(front.floorHeight, back.floorHeight).toDouble();
      final ceilLow =
          math.min(front.ceilingHeight, back.ceilingHeight).toDouble();
      final ceilHigh =
          math.max(front.ceilingHeight, back.ceilingHeight).toDouble();
      final light = ((front.lightLevel + back.lightLevel) / 2).round();

      addQuad(floorLow, floorHigh, kindFor(WallKind.lowerStep), light);
      addQuad(ceilLow, ceilHigh, kindFor(WallKind.upperStep), light);

      // A flat doorway between two identical sectors has no step to draw, but
      // a trigger or secret there still needs to be visible.
      if (floorHigh == floorLow &&
          ceilHigh == ceilLow &&
          (line.hasTrigger || line.isSecret)) {
        addQuad(floorLow, ceilLow, kindFor(WallKind.lowerStep), light);
      }
    }

    final floors = <FloorPoly>[];
    for (final loop in sectorLoops) {
      final sector = map.sectorAt(loop.sectorIndex);
      if (sector == null) continue;
      final z = sector.floorHeight.toDouble();
      trackZ(z);

      final points = <Vec3>[];
      for (final index in loop.vertexIndices) {
        final vertex = map.vertexAt(index);
        if (vertex == null) continue;
        points.add(Vec3(vertex.x.toDouble(), vertex.y.toDouble(), z));
      }
      if (points.length < 3) continue;

      floors.add(FloorPoly(
        sectorIndex: loop.sectorIndex,
        points: points,
        light: sector.lightLevel,
        isSecret: sector.isSecret,
        isDamage: sector.isDamageFloor,
      ));
    }

    // Things stand on the floor of whichever sector contains them.
    final areas = [for (final floor in floors) _area(floor.points)];
    final things = <ThingMarker>[];
    for (var i = 0; i < map.things.length; i++) {
      final thing = map.things[i];
      final x = thing.x.toDouble();
      final y = thing.y.toDouble();
      final z = _floorHeightAt(
        floors,
        areas,
        x,
        y,
        fallback: minZ.isFinite ? minZ : 0,
      );
      things.add(ThingMarker(
        position: Vec3(x, y, z + 16),
        thingIndex: i,
        isPlayerStart: thing.isPlayerStart || thing.isHexenPlayerStart,
        isTeleport: thing.isTeleportDestination,
        angleRadians: thing.angle * math.pi / 180,
      ));
    }

    if (!minZ.isFinite || !maxZ.isFinite) {
      minZ = 0;
      maxZ = 0;
    }

    return MapMesh(
      walls: walls,
      floors: floors,
      things: things,
      minZ: minZ,
      maxZ: maxZ,
    );
  }

  /// Floor height at (x, y): the containing sector outline, or the nearest
  /// one when the point falls outside every loop.
  ///
  /// Sector outlines nest — an inner loop cuts a hole in the one around it —
  /// so of the outlines containing the point the smallest wins, which is the
  /// one the thing actually stands in.
  static double _floorHeightAt(
    List<FloorPoly> floors,
    List<double> areas,
    double x,
    double y, {
    required double fallback,
  }) {
    var bestArea = double.infinity;
    double? containedZ;

    for (var i = 0; i < floors.length; i++) {
      if (areas[i] >= bestArea) continue;
      if (!_contains(floors[i].points, x, y)) continue;
      bestArea = areas[i];
      containedZ = floors[i].points.first.z;
    }
    if (containedZ != null) return containedZ;

    var bestDistance = double.infinity;
    var bestZ = fallback;
    for (final floor in floors) {
      final centre = floor.centre;
      final dx = centre.x - x;
      final dy = centre.y - y;
      final distance = dx * dx + dy * dy;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestZ = centre.z;
      }
    }
    return bestZ;
  }

  /// Even-odd point-in-polygon test on the floor plane.
  static bool _contains(List<Vec3> points, double x, double y) {
    var inside = false;
    for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
      final pi = points[i];
      final pj = points[j];
      if ((pi.y > y) != (pj.y > y) &&
          x < (pj.x - pi.x) * (y - pi.y) / (pj.y - pi.y) + pi.x) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Unsigned shoelace area, used to rank nested outlines.
  static double _area(List<Vec3> points) {
    if (points.length < 3) return double.infinity;
    var sum = 0.0;
    for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
      sum += (points[j].x + points[i].x) * (points[j].y - points[i].y);
    }
    return (sum / 2).abs();
  }
}
