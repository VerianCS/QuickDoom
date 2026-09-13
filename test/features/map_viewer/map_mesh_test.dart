import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/features/map_viewer/domain/models/doom_map.dart';
import 'package:quickdoom/features/map_viewer/domain/models/linedef.dart';
import 'package:quickdoom/features/map_viewer/domain/models/sector.dart';
import 'package:quickdoom/features/map_viewer/domain/models/sidedef.dart';
import 'package:quickdoom/features/map_viewer/domain/models/thing.dart';
import 'package:quickdoom/features/map_viewer/domain/models/vertex.dart';
import 'package:quickdoom/features/map_viewer/domain/projection/map_mesh.dart';

/// Builds a map with explicit sector heights, which the shared fixtures do
/// not vary — and height difference is exactly what extrusion depends on.
DoomMap buildMap({
  required List<(int, int)> vertices,
  required List<(int, int, int, int)> lines,
  required List<(int floor, int ceiling)> sectorHeights,
  List<(int, int)> things = const [],
  List<int>? lineFlags,
  List<int>? lineSpecials,
}) {
  final sidedefs = <Sidedef>[];
  final resolved = <(int, int, int, int)>[];

  for (final (start, end, frontSector, backSector) in lines) {
    var front = -1;
    var back = -1;
    if (frontSector >= 0) {
      front = sidedefs.length;
      sidedefs.add(Sidedef(
        xOffset: 0,
        yOffset: 0,
        upperTexture: '',
        lowerTexture: '',
        middleTexture: 'W',
        sectorIndex: frontSector,
      ));
    }
    if (backSector >= 0) {
      back = sidedefs.length;
      sidedefs.add(Sidedef(
        xOffset: 0,
        yOffset: 0,
        upperTexture: '',
        lowerTexture: '',
        middleTexture: 'W',
        sectorIndex: backSector,
      ));
    }
    resolved.add((start, end, front, back));
  }

  return DoomMap(
    name: 'MESH',
    format: MapFormat.classicDoom,
    vertices: [for (final (x, y) in vertices) Vertex(x: x, y: y)],
    linedefs: [
      for (var i = 0; i < resolved.length; i++)
        Linedef(
          startVertexIndex: resolved[i].$1,
          endVertexIndex: resolved[i].$2,
          flags: lineFlags == null ? 0 : lineFlags[i],
          special: lineSpecials == null ? 0 : lineSpecials[i],
          tag: 0,
          frontSidedefIndex: resolved[i].$3,
          backSidedefIndex: resolved[i].$4,
        ),
    ],
    sidedefs: sidedefs,
    sectors: [
      for (final (floor, ceiling) in sectorHeights)
        Sector(
          floorHeight: floor,
          ceilingHeight: ceiling,
          floorTexture: 'F',
          ceilingTexture: 'C',
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

List<({int sectorIndex, List<int> vertexIndices})> loopsFor(
  Map<int, List<int>> bySector,
) {
  return [
    for (final entry in bySector.entries)
      (sectorIndex: entry.key, vertexIndices: entry.value),
  ];
}

void main() {
  group('one-sided walls', () {
    test('span the sector from floor to ceiling', () {
      final map = buildMap(
        vertices: const [(0, 0), (64, 0), (64, -64), (0, -64)],
        lines: const [
          (0, 1, 0, -1),
          (1, 2, 0, -1),
          (2, 3, 0, -1),
          (3, 0, 0, -1),
        ],
        sectorHeights: const [(-32, 96)],
      );

      final mesh = MapMesh.build(map, sectorLoops: const []);

      expect(mesh.walls, hasLength(4));
      for (final wall in mesh.walls) {
        expect(wall.kind, WallKind.solid);
        expect(wall.a.z, -32);
        expect(wall.d.z, 96);
        expect(wall.height, 128);
      }
      expect(mesh.minZ, -32);
      expect(mesh.maxZ, 96);
    });

    test('carry the linedef index for selection', () {
      final map = buildMap(
        vertices: const [(0, 0), (64, 0)],
        lines: const [(0, 1, 0, -1)],
        sectorHeights: const [(0, 64)],
      );

      final mesh = MapMesh.build(map, sectorLoops: const []);
      expect(mesh.walls.single.linedefIndex, 0);
    });
  });

  group('two-sided lines', () {
    DoomMap twoSectors({
      required (int, int) a,
      required (int, int) b,
      int flags = 0,
      int special = 0,
    }) {
      return buildMap(
        vertices: const [(0, 0), (64, 0)],
        lines: const [(0, 1, 0, 1)],
        sectorHeights: [a, b],
        lineFlags: [flags],
        lineSpecials: [special],
      );
    }

    test('a floor difference becomes a lower step', () {
      final mesh = MapMesh.build(
        twoSectors(a: (0, 128), b: (32, 128)),
        sectorLoops: const [],
      );

      expect(mesh.walls, hasLength(1));
      final step = mesh.walls.single;
      expect(step.kind, WallKind.lowerStep);
      expect(step.a.z, 0);
      expect(step.d.z, 32);
    });

    test('a ceiling difference becomes an upper step', () {
      final mesh = MapMesh.build(
        twoSectors(a: (0, 128), b: (0, 96)),
        sectorLoops: const [],
      );

      expect(mesh.walls, hasLength(1));
      final step = mesh.walls.single;
      expect(step.kind, WallKind.upperStep);
      expect(step.a.z, 96);
      expect(step.d.z, 128);
    });

    test('both differences produce both steps', () {
      final mesh = MapMesh.build(
        twoSectors(a: (0, 128), b: (24, 100)),
        sectorLoops: const [],
      );

      expect(mesh.walls, hasLength(2));
      expect(
        mesh.walls.map((w) => w.kind).toSet(),
        {WallKind.lowerStep, WallKind.upperStep},
      );
    });

    test('matching sectors leave an open portal with nothing to draw', () {
      final mesh = MapMesh.build(
        twoSectors(a: (0, 128), b: (0, 128)),
        sectorLoops: const [],
      );

      expect(mesh.walls, isEmpty,
          reason: 'a flat opening has no visible surface');
    });

    test('a trigger on an open portal is still drawn', () {
      final mesh = MapMesh.build(
        twoSectors(a: (0, 128), b: (0, 128), special: 11),
        sectorLoops: const [],
      );

      expect(mesh.walls, hasLength(1));
      expect(mesh.walls.single.kind, WallKind.trigger);
      expect(mesh.walls.single.height, 128);
    });
  });

  group('line kinds', () {
    test('a special marks the wall as a trigger', () {
      final map = buildMap(
        vertices: const [(0, 0), (64, 0)],
        lines: const [(0, 1, 0, -1)],
        sectorHeights: const [(0, 64)],
        lineSpecials: const [31],
      );

      final mesh = MapMesh.build(map, sectorLoops: const []);
      expect(mesh.walls.single.kind, WallKind.trigger);
    });

    test('the secret flag wins over a special', () {
      final map = buildMap(
        vertices: const [(0, 0), (64, 0)],
        lines: const [(0, 1, 0, -1)],
        sectorHeights: const [(0, 64)],
        lineFlags: const [Linedef.flagSecret],
        lineSpecials: const [31],
      );

      final mesh = MapMesh.build(map, sectorLoops: const []);
      expect(mesh.walls.single.kind, WallKind.secret);
    });
  });

  group('floors and things', () {
    test('floor outlines sit at the sector floor height', () {
      final map = buildMap(
        vertices: const [(0, 0), (64, 0), (64, -64), (0, -64)],
        lines: const [(0, 1, 0, -1)],
        sectorHeights: const [(48, 160)],
      );

      final mesh = MapMesh.build(
        map,
        sectorLoops: loopsFor({
          0: [0, 1, 2, 3],
        }),
      );

      expect(mesh.floors, hasLength(1));
      expect(mesh.floors.single.sectorIndex, 0);
      for (final point in mesh.floors.single.points) {
        expect(point.z, 48);
      }
    });

    test('a thing stands on the floor of the sector containing it', () {
      // A small inner sector at height 64 nested inside a large one at 0.
      final map = buildMap(
        vertices: const [
          (0, 0),
          (256, 0),
          (256, -256),
          (0, -256),
          (100, -100),
          (150, -100),
          (150, -150),
          (100, -150),
        ],
        lines: const [(0, 1, 0, -1)],
        sectorHeights: const [(0, 128), (64, 128)],
        things: const [(125, -125)],
      );

      final mesh = MapMesh.build(
        map,
        sectorLoops: loopsFor({
          0: [0, 1, 2, 3],
          1: [4, 5, 6, 7],
        }),
      );

      expect(
        mesh.things.single.position.z,
        64 + 16,
        reason: 'the inner sector is the smaller containing outline',
      );
    });

    test('a thing outside every outline falls back to the lowest floor', () {
      final map = buildMap(
        vertices: const [(0, 0), (64, 0), (64, -64), (0, -64)],
        lines: const [(0, 1, 0, -1)],
        sectorHeights: const [(16, 128)],
        things: const [(5000, 5000)],
      );

      final mesh = MapMesh.build(
        map,
        sectorLoops: loopsFor({
          0: [0, 1, 2, 3],
        }),
      );

      expect(mesh.things.single.position.z, 16 + 16);
    });
  });

  test('an empty map produces an empty mesh', () {
    final map = buildMap(
      vertices: const [],
      lines: const [],
      sectorHeights: const [],
    );

    expect(MapMesh.build(map, sectorLoops: const []).isEmpty, isTrue);
  });
}
