import 'package:quickdoom/features/map_viewer/domain/models/doom_map.dart';
import 'package:quickdoom/features/map_viewer/domain/models/linedef.dart';
import 'package:quickdoom/features/map_viewer/domain/models/sector.dart';
import 'package:quickdoom/features/map_viewer/domain/models/sidedef.dart';
import 'package:quickdoom/features/map_viewer/domain/models/thing.dart';
import 'package:quickdoom/features/map_viewer/domain/models/vertex.dart';

/// Hand-built [DoomMap]s for geometry/picking tests (no WAD parsing needed).
///
/// Linedefs are (startVertex, endVertex, frontSector, backSector), where -1
/// means "no sidedef on that side".
class MapFixtures {
  /// A single 256x256 room: one sector, four enclosing linedefs, one thing in
  /// the middle. Large enough that the centre is well clear of the walls.
  static DoomMap room() {
    return _build(
      vertices: const [(0, 0), (256, 0), (256, -256), (0, -256)],
      lines: const [
        (0, 1, 0, -1),
        (1, 2, 0, -1),
        (2, 3, 0, -1),
        (3, 0, 0, -1),
      ],
      things: const [(128, -128)],
    );
  }

  /// Two rooms sharing a single two-sided wall -> two sectors.
  static DoomMap twRooms() {
    return _build(
      vertices: const [
        (0, 0),
        (64, 0),
        (64, -64),
        (0, -64),
        (128, 0),
        (128, -64),
      ],
      lines: const [
        (0, 1, 0, -1),
        (1, 2, 0, 1),
        (2, 3, 0, -1),
        (3, 0, 0, -1),
        (1, 4, 1, -1),
        (4, 5, 1, -1),
        (5, 2, 1, -1),
      ],
    );
  }

  /// A thing sitting one unit off the bottom edge of a single room.
  static DoomMap thingNearLine() {
    return _build(
      vertices: const [(0, 0), (64, 0), (64, -64), (0, -64)],
      lines: const [
        (0, 1, 0, -1),
        (1, 2, 0, -1),
        (2, 3, 0, -1),
        (3, 0, 0, -1),
      ],
      things: const [(32, -1)],
    );
  }

  static DoomMap _build({
    required List<(int, int)> vertices,
    required List<(int, int, int, int)> lines,
    List<(int, int)> things = const [],
  }) {
    final sidedefs = <Sidedef>[];
    final resolved = <(int, int, int, int)>[];

    for (final (start, end, frontSector, backSector) in lines) {
      var frontIndex = -1;
      var backIndex = -1;
      if (frontSector >= 0) {
        frontIndex = sidedefs.length;
        sidedefs.add(_sidedef(frontSector));
      }
      if (backSector >= 0) {
        backIndex = sidedefs.length;
        sidedefs.add(_sidedef(backSector));
      }
      resolved.add((start, end, frontIndex, backIndex));
    }

    return DoomMap(
      name: 'TEST',
      format: MapFormat.classicDoom,
      vertices: [for (final (x, y) in vertices) Vertex(x: x, y: y)],
      linedefs: [
        for (final (start, end, frontSide, backSide) in resolved)
          Linedef(
            startVertexIndex: start,
            endVertexIndex: end,
            flags: 0,
            special: 0,
            tag: 0,
            frontSidedefIndex: frontSide,
            backSidedefIndex: backSide,
          ),
      ],
      sidedefs: sidedefs,
      sectors: const [
        Sector(
          floorHeight: -64,
          ceilingHeight: 128,
          floorTexture: 'FLOOR4_8',
          ceilingTexture: 'CEIL3_5',
          lightLevel: 160,
          special: 0,
          tag: 0,
        ),
        Sector(
          floorHeight: -64,
          ceilingHeight: 128,
          floorTexture: 'FLOOR4_8',
          ceilingTexture: 'CEIL3_5',
          lightLevel: 160,
          special: 0,
          tag: 0,
        ),
      ],
      things: [
        for (final (x, y) in things)
          Thing(x: x, y: y, angle: 0, type: 1, flags: 7),
      ],
    );
  }

  static Sidedef _sidedef(int sectorIndex) => Sidedef(
        xOffset: 0,
        yOffset: 0,
        upperTexture: '',
        lowerTexture: '',
        middleTexture: 'WALL',
        sectorIndex: sectorIndex,
      );
}
