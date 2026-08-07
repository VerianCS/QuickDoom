import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/features/map_viewer/domain/models/doom_map.dart';
import 'package:quickdoom/features/map_viewer/domain/parsers/doom_map_parser.dart';
import 'package:quickdoom/features/map_viewer/domain/parsers/wad_parser.dart';

import 'fixtures/wad_fixture.dart';

void main() {
  final wad = WadParser.parseBytes(WadFixture.classicDoomE1M1());
  final map = DoomMapParser.parse(wad.maps.single);

  group('DoomMapParser vertices', () {
    test('decodes signed little-endian coordinates', () {
      expect(map.vertices, hasLength(3));
      expect(map.vertices[0].x, 0);
      expect(map.vertices[0].y, 0);
      expect(map.vertices[1].x, 64);
      expect(map.vertices[1].y, 0);
      expect(map.vertices[2].x, 64);
      expect(map.vertices[2].y, -64);
    });

    test('computes map bounds from vertices', () {
      expect(map.bounds.minX, 0);
      expect(map.bounds.maxX, 64);
      expect(map.bounds.minY, -64);
      expect(map.bounds.maxY, 0);
      expect(map.bounds.width, 64);
      expect(map.bounds.height, 64);
    });
  });

  group('DoomMapParser linedefs', () {
    test('decodes vertex indices, flags, special and tag', () {
      expect(map.linedefs, hasLength(2));
      final first = map.linedefs[0];
      expect(first.startVertexIndex, 0);
      expect(first.endVertexIndex, 1);
      expect(first.flags, 0x0001);
      expect(first.special, 0);
      expect(first.tag, 0);
    });

    test('converts 0xFFFF sidedef index to -1', () {
      expect(map.linedefs[0].frontSidedefIndex, 0);
      expect(map.linedefs[0].backSidedefIndex, -1);
      expect(map.linedefs[0].hasFrontSidedef, isTrue);
      expect(map.linedefs[0].hasBackSidedef, isFalse);
    });

    test('exposes flag getters', () {
      final impassable = map.linedefs[0];
      final twoSided = map.linedefs[1];

      expect(impassable.isImpassable, isTrue);
      expect(impassable.isTwoSided, isFalse);
      expect(impassable.hasTrigger, isFalse);
      expect(twoSided.isImpassable, isTrue);
      expect(twoSided.isTwoSided, isTrue);
      expect(twoSided.hasTrigger, isTrue);
      expect(twoSided.tag, 7);
    });
  });

  group('DoomMapParser sidedefs', () {
    test('decodes offsets, textures and sector index', () {
      expect(map.sidedefs, hasLength(2));
      final first = map.sidedefs[0];
      expect(first.xOffset, 0);
      expect(first.yOffset, 0);
      expect(first.middleTexture, 'STARTAN1');
      expect(first.sectorIndex, 0);
    });

    test('maps "-" texture names to empty strings', () {
      final first = map.sidedefs[0];
      expect(first.upperTexture, '');
      expect(first.lowerTexture, '');
      expect(first.hasMiddleTexture, isTrue);
      expect(first.hasUpperTexture, isFalse);

      final second = map.sidedefs[1];
      expect(second.upperTexture, 'BIGDOOR1');
      expect(second.middleTexture, '');
      expect(second.xOffset, -16);
    });
  });

  group('DoomMapParser sectors', () {
    test('decodes signed heights and unsigned light/special/tag', () {
      expect(map.sectors, hasLength(1));
      final sector = map.sectors.single;
      expect(sector.floorHeight, -64);
      expect(sector.ceilingHeight, 128);
      expect(sector.floorTexture, 'FLOOR4_8');
      expect(sector.ceilingTexture, 'CEIL3_5');
      expect(sector.lightLevel, 160);
      expect(sector.special, 9);
      expect(sector.tag, 0);
    });

    test('flags classic secret special 9', () {
      expect(map.sectors.single.isSecret, isTrue);
    });

    test('flags ZDoom secret bitmask 0x400', () {
      final sector = map.sectors.single;
      expect(sector.special & 0x400, 0);
    });
  });

  group('DoomMapParser things', () {
    test('decodes signed coordinates, angle, type and flags', () {
      expect(map.things, hasLength(2));
      final playerStart = map.things[0];
      expect(playerStart.x, 64);
      expect(playerStart.y, -64);
      expect(playerStart.angle, 90);
      expect(playerStart.type, 1);
      expect(playerStart.flags, 7);
    });

    test('recognizes player starts and teleport destinations', () {
      expect(map.things[0].isPlayerStart, isTrue);
      expect(map.things[1].isPlayerStart, isFalse);
      expect(map.things[1].isTeleportDestination, isFalse);
    });

    test('appearsInSkill maps bits to skill levels', () {
      final thing = map.things[0]; // flags = 7
      expect(thing.appearsInSkill(1), isTrue);
      expect(thing.appearsInSkill(3), isTrue);
      expect(thing.appearsInSkill(5), isTrue);
    });

    test('appearsInSkill respects missing skill bits', () {
      final bytes = WadFixture.build(
        magic: 'PWAD',
        lumps: [
          ('MAP01', const <int>[]),
          ('THINGS', WadFixture.thing(0, 0, 0, 3001, 0x0002)),
        ],
      );
      final mediumOnlyWad = WadParser.parseBytes(bytes);
      final mediumOnly =
          DoomMapParser.parse(mediumOnlyWad.maps.single).things.single;

      expect(mediumOnly.appearsInSkill(1), isFalse);
      expect(mediumOnly.appearsInSkill(2), isFalse);
      expect(mediumOnly.appearsInSkill(3), isTrue);
      expect(mediumOnly.appearsInSkill(4), isFalse);
      expect(mediumOnly.appearsInSkill(5), isFalse);
    });
  });

  group('DoomMapParser format detection', () {
    test('detects UDMF maps', () {
      final textmap = latin1
          .encode('vertex {\n  x = 0;\n  y = 0;\n}\n');
      final bytes = WadFixture.build(
        magic: 'PWAD',
        lumps: [
          ('MAP01', const <int>[]),
          ('TEXTMAP', textmap),
        ],
      );
      final udmfWad = WadParser.parseBytes(bytes);

      expect(DoomMapParser.detectFormat(udmfWad.maps.single), MapFormat.udmf);
      expect(DoomMapParser.parse(udmfWad.maps.single).format, MapFormat.udmf);
    });

    test('detects Hexen maps', () {
      final bytes = WadFixture.build(
        magic: 'PWAD',
        lumps: const [
          ('MAP01', <int>[]),
          ('BEHAVIOR', <int>[1, 2, 3]),
        ],
      );
      final hexenWad = WadParser.parseBytes(bytes);

      expect(
          DoomMapParser.detectFormat(hexenWad.maps.single), MapFormat.classicHexen);
      expect(DoomMapParser.parse(hexenWad.maps.single).format,
          MapFormat.classicHexen);
    });

    test('classic maps parse with empty sub-lumps for missing lumps', () {
      final bytes = WadFixture.build(
        magic: 'PWAD',
        lumps: const [
          ('MAP01', <int>[]),
          ('THINGS', <int>[]),
        ],
      );
      final emptyWad = WadParser.parseBytes(bytes);
      final emptyMap = DoomMapParser.parse(emptyWad.maps.single);

      expect(emptyMap.format, MapFormat.classicDoom);
      expect(emptyMap.vertices, isEmpty);
      expect(emptyMap.linedefs, isEmpty);
      expect(emptyMap.sidedefs, isEmpty);
      expect(emptyMap.sectors, isEmpty);
      expect(emptyMap.things, isEmpty);
      expect(emptyMap.isEmpty, isTrue);
    });
  });

  group('DoomMapParser parseAll', () {
    test('parses every map in the WAD', () {
      final bytes = WadFixture.build(
        magic: 'PWAD',
        lumps: const [
          ('E1M1', <int>[]),
          ('VERTEXES', <int>[]),
          ('MAP01', <int>[]),
          ('VERTEXES', <int>[]),
        ],
      );
      final multiWad = WadParser.parseBytes(bytes);
      final maps = DoomMapParser.parseAll(multiWad);

      expect(maps, hasLength(2));
      expect(maps.map((m) => m.name), ['E1M1', 'MAP01']);
    });
  });
}
