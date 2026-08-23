import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/features/map_viewer/data/repositories/pk3_reader.dart';
import 'package:quickdoom/features/map_viewer/domain/models/doom_map.dart';

import 'fixtures/wad_fixture.dart';

Uint8List buildZip(List<(String, List<int>)> files) {
  final archive = Archive();
  for (final (name, bytes) in files) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

DoomMap? mapNamed(List<DoomMap> maps, String name) {
  for (final m in maps) {
    if (m.name == name) return m;
  }
  return null;
}

void main() {
  group('Pk3Reader', () {
    test('reads an embedded WAD under maps/', () {
      final zip = buildZip([
        ('maps/e1m1.wad', WadFixture.classicDoomE1M1()),
      ]);

      final maps = Pk3Reader.parseBytes(zip);

      expect(maps, hasLength(1));
      final map = mapNamed(maps, 'E1M1')!;
      expect(map.format, MapFormat.classicDoom);
      expect(map.vertices, hasLength(3));
    });

    test('reads a folder-based UDMF map with a custom name', () {
      const textmap = '''
namespace = "zdoom";
vertex { x = 0; y = 0; }
vertex { x = 64; y = 0; }
thing { x = 32; y = 0; angle = 90; type = 1; }
''';
      final zip = buildZip([
        ('maps/MYMAP/TEXTMAP', textmap.codeUnits.toList()),
        ('maps/MYMAP/THINGS', [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
      ]);

      final maps = Pk3Reader.parseBytes(zip);

      expect(maps, hasLength(1));
      final map = mapNamed(maps, 'MYMAP')!;
      expect(map.format, MapFormat.udmf);
      expect(map.vertices, hasLength(2));
      expect(map.things, hasLength(1));
    });

    test('combines embedded WADs and folder-based maps', () {
      const textmap = 'namespace = "zdoom";\n';
      final zip = buildZip([
        ('maps/e1m1.wad', WadFixture.classicDoomE1M1()),
        ('maps/MYMAP/TEXTMAP', textmap.codeUnits.toList()),
      ]);

      final maps = Pk3Reader.parseBytes(zip);

      expect(mapNamed(maps, 'E1M1'), isNotNull);
      expect(mapNamed(maps, 'MYMAP'), isNotNull);
    });
  });
}
