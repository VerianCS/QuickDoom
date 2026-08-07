import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/features/map_viewer/domain/errors/wad_format_exception.dart';
import 'package:quickdoom/features/map_viewer/domain/models/doom_map.dart';
import 'package:quickdoom/features/map_viewer/domain/parsers/udmf_parser.dart';

void main() {
  const basic = '''
// room with a door
vertex
{
  x = 0; y = 0;
}
vertex { x = 64; y = 0; }
vertex { x = 64; y = -64; }

sector
{
  heightfloor = -64;
  heightceiling = 128;
  texturefloor = "FLOOR4_8";
  textureceiling = "CEIL3_5";
  lightlevel = 160;
}

sidedef
{
  offsetx = 0;
  offsety = 0;
  texturetop = "-";
  texturebottom = "-";
  texturemiddle = "STARTAN1";
  sector = 0;
}

line
{
  id = 7;
  v1 = 1;
  v2 = 2;
  special = 1;
  sidefront = 1;
  flags = "impassable";
}

thing
{
  x = 64;
  y = -64;
  angle = 90;
  type = 1;
  flags = "skill1 skill2 skill3";
}
''';

  group('UdmfParser basic blocks', () {
    test('parses vertex blocks', () {
      final map = UdmfParser.parseText(basic, mapName: 'MAP01');
      expect(map.vertices, hasLength(3));
      expect(map.vertices[0].x, 0);
      expect(map.vertices[0].y, 0);
      expect(map.vertices[1].x, 64);
      expect(map.vertices[2].y, -64);
    });

    test('parses sector blocks', () {
      final map = UdmfParser.parseText(basic, mapName: 'MAP01');
      final sector = map.sectors.single;
      expect(sector.floorHeight, -64);
      expect(sector.ceilingHeight, 128);
      expect(sector.floorTexture, 'FLOOR4_8');
      expect(sector.ceilingTexture, 'CEIL3_5');
      expect(sector.lightLevel, 160);
      expect(sector.special, 0);
      expect(sector.tag, 0);
    });

    test('parses sidedef blocks with - textures as empty', () {
      final map = UdmfParser.parseText(basic, mapName: 'MAP01');
      final sidedef = map.sidedefs.single;
      expect(sidedef.upperTexture, '');
      expect(sidedef.lowerTexture, '');
      expect(sidedef.middleTexture, 'STARTAN1');
      expect(sidedef.sectorIndex, 0);
      expect(sidedef.xOffset, 0);
      expect(sidedef.yOffset, 0);
    });

    test('parses line blocks with 1-based references', () {
      final map = UdmfParser.parseText(basic, mapName: 'MAP01');
      final line = map.linedefs.single;
      expect(line.startVertexIndex, 0);
      expect(line.endVertexIndex, 1);
      expect(line.special, 1);
      expect(line.tag, 7);
      expect(line.frontSidedefIndex, 0);
      expect(line.backSidedefIndex, -1);
      expect(line.isImpassable, isTrue);
      expect(line.args, [0, 0, 0, 0, 0]);
    });

    test('parses thing blocks with numeric type', () {
      final map = UdmfParser.parseText(basic, mapName: 'MAP01');
      final thing = map.things.single;
      expect(thing.type, 1);
      expect(thing.typeName, isNull);
      expect(thing.isPlayerStart, isTrue);
      expect(thing.x, 64);
      expect(thing.y, -64);
      expect(thing.angle, 90);
      expect(thing.appearsInSkill(1), isTrue);
      expect(thing.appearsInSkill(2), isTrue);
      expect(thing.appearsInSkill(3), isTrue);
      expect(thing.appearsInSkill(4), isFalse);
    });

    test('sets format and map name', () {
      final map = UdmfParser.parseText(basic, mapName: 'MAP02');
      expect(map.format, MapFormat.udmf);
      expect(map.name, 'MAP02');
    });
  });

  group('UdmfParser numeric types', () {
    test('parses fractional coordinates truncated to ints', () {
      final map = UdmfParser.parseText(
        '''
vertex { x = 12.75; y = -3.25; }
''',
        mapName: 'MAP01',
      );
      expect(map.vertices.single.x, 13);
      expect(map.vertices.single.y, -3);
    });

    test('parses hex numbers', () {
      final map = UdmfParser.parseText(
        '''
thing { x = 0x10; y = 0; angle = 0; type = 1; }
''',
        mapName: 'MAP01',
      );
      expect(map.things.single.x, 16);
    });

    test('parses negative numbers', () {
      final map = UdmfParser.parseText(
        '''
vertex { x = -8; y = -8; }
''',
        mapName: 'MAP01',
      );
      expect(map.vertices.single.x, -8);
      expect(map.vertices.single.y, -8);
    });
  });

  group('UdmfParser string properties', () {
    test('handles escaped quotes in texture names', () {
      final map = UdmfParser.parseText(
        '''
sector {
  heightfloor = 0; heightceiling = 64;
  texturefloor = "A \\"B";
  textureceiling = "C";
  lightlevel = 128;
}
''',
        mapName: 'MAP01',
      );
      expect(map.sectors.single.floorTexture, 'A "B');
    });
  });

  group('UdmfParser flags', () {
    test('parses named line flags', () {
      final map = UdmfParser.parseText(
        '''
vertex { x = 0; y = 0; }
vertex { x = 16; y = 0; }
line {
  v1 = 1; v2 = 2;
  special = 0;
  sidefront = 1;
  flags = "twosided secret dontpegtop";
}
sidedef { sector = 0; }
sector {
  heightfloor = 0; heightceiling = 64; lightlevel = 128;
}
''',
        mapName: 'MAP01',
      );
      final line = map.linedefs.single;
      expect(line.isTwoSided, isTrue);
      expect(line.isSecret, isTrue);
      expect(line.isUpperUnpegged, isTrue);
      expect(line.isVisibleOnAutomap, isTrue);
    });

    test('parses numeric line flags', () {
      final map = UdmfParser.parseText(
        '''
vertex { x = 0; y = 0; }
vertex { x = 16; y = 0; }
line {
  v1 = 1; v2 = 2;
  special = 0;
  sidefront = 1;
  flags = 9;
}
sidedef { sector = 0; }
sector {
  heightfloor = 0; heightceiling = 64; lightlevel = 128;
}
''',
        mapName: 'MAP01',
      );
      expect(map.linedefs.single.flags, 9);
    });

    test('parses named thing flags', () {
      final map = UdmfParser.parseText(
        '''
thing {
  x = 0; y = 0; angle = 0; type = 1;
  flags = "ambush multiplayer";
}
''',
        mapName: 'MAP01',
      );
      final thing = map.things.single;
      expect(thing.isAmbush, isTrue);
      expect(thing.isMultiplayerOnly, isTrue);
    });
  });

  group('UdmfParser Hexen-style extras', () {
    test('parses args and special', () {
      final map = UdmfParser.parseText(
        '''
vertex { x = 0; y = 0; }
vertex { x = 16; y = 0; }
line {
  v1 = 1; v2 = 2;
  special = 10;
  arg0 = 7; arg1 = 8; arg2 = 9; arg3 = 10; arg4 = 11;
  sidefront = 1;
}
sidedef { sector = 0; }
sector {
  heightfloor = 0; heightceiling = 64; lightlevel = 128;
}
''',
        mapName: 'MAP01',
      );
      final line = map.linedefs.single;
      expect(line.special, 10);
      expect(line.args, [7, 8, 9, 10, 11]);
    });

    test('parses thing tid and z', () {
      final map = UdmfParser.parseText(
        '''
thing {
  x = 0; y = 0; angle = 0; type = 14;
  z = 32; tid = 5;
}
''',
        mapName: 'MAP01',
      );
      final thing = map.things.single;
      expect(thing.tid, 5);
      expect(thing.z, 32);
      expect(thing.isTeleportDestination, isTrue);
    });

    test('parses named thing type teleportdest', () {
      final map = UdmfParser.parseText(
        '''
thing {
  x = 0; y = 0; angle = 0; type = "TeleportDest";
}
''',
        mapName: 'MAP01',
      );
      final thing = map.things.single;
      expect(thing.type, 14);
      expect(thing.typeName, 'TeleportDest');
      expect(thing.isTeleportDestination, isTrue);
    });
  });

  group('UdmfParser comments and errors', () {
    test('ignores line and block comments', () {
      final map = UdmfParser.parseText(
        '''
// line comment
/* block
   comment */
vertex { x = 1; y = 2; } // trailing
''',
        mapName: 'MAP01',
      );
      expect(map.vertices, hasLength(1));
    });

    test('throws on unterminated block comment', () {
      expect(
        () => UdmfParser.parseText('/* never closed', mapName: 'MAP01'),
        throwsA(isA<WadFormatException>()),
      );
    });

    test('throws on unexpected character', () {
      expect(
        () => UdmfParser.parseText('@', mapName: 'MAP01'),
        throwsA(isA<WadFormatException>()),
      );
    });

    test('throws when missing block close brace', () {
      expect(
        () => UdmfParser.parseText('vertex { x = 1;', mapName: 'MAP01'),
        throwsA(isA<WadFormatException>()),
      );
    });

    test('throws when missing value after equals', () {
      expect(
        () => UdmfParser.parseText('vertex { x = ; }', mapName: 'MAP01'),
        throwsA(isA<WadFormatException>()),
      );
    });

    test('ignores unknown blocks instead of crashing', () {
      final map = UdmfParser.parseText(
        '''
unknownblock { anything = 1; }
vertex { x = 0; y = 0; }
''',
        mapName: 'MAP01',
      );
      expect(map.vertices, hasLength(1));
    });
  });
}
