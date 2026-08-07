import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/features/map_viewer/domain/models/doom_map.dart';
import 'package:quickdoom/features/map_viewer/domain/parsers/doom_map_parser.dart';
import 'package:quickdoom/features/map_viewer/domain/parsers/wad_parser.dart';

import 'fixtures/wad_fixture.dart';

void main() {
  final wad = WadParser.parseBytes(WadFixture.hexenMap01());
  final map = DoomMapParser.parse(wad.maps.single);

  group('DoomMapParser Hexen format', () {
    test('detects and parses the map format', () {
      expect(map.format, MapFormat.classicHexen);
      expect(map.name, 'MAP01');
    });

    test('parses things with 20-byte records', () {
      expect(map.things, hasLength(2));

      final fighter = map.things[0];
      expect(fighter.tid, 0);
      expect(fighter.x, 64);
      expect(fighter.y, -64);
      expect(fighter.z, 0);
      expect(fighter.angle, 90);
      expect(fighter.type, 3000);
      expect(fighter.isHexenPlayerStart, isTrue);
      expect(fighter.special, 0);
      expect(fighter.args, [0, 0, 0, 0, 0]);

      final thing = map.things[1];
      expect(thing.tid, 5);
      expect(thing.x, 128);
      expect(thing.y, 128);
      expect(thing.z, 32);
      expect(thing.angle, 0);
      expect(thing.type, 1);
      expect(thing.special, 42);
      expect(thing.args, [1, 2, 3, 4, 5]);
    });

    test('parses linedefs with byte special and 5 args', () {
      expect(map.linedefs, hasLength(2));

      final door = map.linedefs[0];
      expect(door.startVertexIndex, 0);
      expect(door.endVertexIndex, 1);
      expect(door.flags, 0x0001);
      expect(door.special, 10);
      expect(door.args, [7, 0, 0, 0, 0]);
      expect(door.frontSidedefIndex, 0);
      expect(door.backSidedefIndex, -1);

      final line = map.linedefs[1];
      expect(line.special, 0);
      expect(line.args, [0, 0, 0, 0, 0]);
    });

    test('parses shared geometry lumps (vertices, sectors, sidedefs)', () {
      expect(map.vertices, hasLength(3));
      expect(map.sectors, hasLength(1));
      expect(map.sidedefs, hasLength(2));
      expect(map.sectors.single.floorHeight, -64);
      expect(map.sectors.single.ceilingHeight, 128);
    });
  });
}