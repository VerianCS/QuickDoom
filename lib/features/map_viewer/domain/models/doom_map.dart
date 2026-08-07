import 'linedef.dart';
import 'sector.dart';
import 'sidedef.dart';
import 'thing.dart';
import 'vertex.dart';

/// Binary or text format a map was stored in.
enum MapFormat { classicDoom, classicHexen, udmf }

/// Axis-aligned bounds of a map in Doom map space (x right, y up).
class MapBounds {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  const MapBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  static const MapBounds empty = MapBounds(minX: 0, maxX: 0, minY: 0, maxY: 0);

  factory MapBounds.fromVertices(List<Vertex> vertices) {
    if (vertices.isEmpty) return MapBounds.empty;
    var minX = vertices.first.x.toDouble();
    var maxX = minX;
    var minY = vertices.first.y.toDouble();
    var maxY = minY;
    for (final v in vertices) {
      final vx = v.x.toDouble();
      final vy = v.y.toDouble();
      if (vx < minX) minX = vx;
      if (vx > maxX) maxX = vx;
      if (vy < minY) minY = vy;
      if (vy > maxY) maxY = vy;
    }
    return MapBounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY);
  }

  double get width => maxX - minX;
  double get height => maxY - minY;
  double get centerX => (minX + maxX) / 2;
  double get centerY => (minY + maxY) / 2;
}

/// A fully parsed map: geometry, sectors, sidedefs and things.
class DoomMap {
  final String name;
  final MapFormat format;
  final List<Vertex> vertices;
  final List<Linedef> linedefs;
  final List<Sidedef> sidedefs;
  final List<Sector> sectors;
  final List<Thing> things;

  late final MapBounds bounds = MapBounds.fromVertices(vertices);

  DoomMap({
    required this.name,
    required this.format,
    required this.vertices,
    required this.linedefs,
    required this.sidedefs,
    required this.sectors,
    required this.things,
  });

  bool get isEmpty => vertices.isEmpty && linedefs.isEmpty && things.isEmpty;

  Vertex? vertexAt(int index) =>
      index >= 0 && index < vertices.length ? vertices[index] : null;

  Linedef? linedefAt(int index) =>
      index >= 0 && index < linedefs.length ? linedefs[index] : null;

  Sidedef? sidedefAt(int index) =>
      index >= 0 && index < sidedefs.length ? sidedefs[index] : null;

  Sector? sectorAt(int index) =>
      index >= 0 && index < sectors.length ? sectors[index] : null;
}
