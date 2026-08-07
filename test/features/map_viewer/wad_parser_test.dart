import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/features/map_viewer/domain/errors/wad_format_exception.dart';
import 'package:quickdoom/features/map_viewer/domain/parsers/wad_parser.dart';

import 'fixtures/wad_fixture.dart';

void main() {
  group('WadParser header', () {
    test('reads PWAD magic, lump count and directory offset', () {
      final wad = WadParser.parseBytes(WadFixture.classicDoomE1M1());

      expect(wad.magic, 'PWAD');
      expect(wad.isPwad, isTrue);
      expect(wad.isIwad, isFalse);
      expect(wad.lumps, hasLength(6));
    });

    test('reads IWAD magic', () {
      final wad = WadParser.parseBytes(WadFixture.build(
        magic: 'IWAD',
        lumps: [('E1M1', const [])],
      ));

      expect(wad.isIwad, isTrue);
      expect(wad.isPwad, isFalse);
    });

    test('throws on invalid magic', () {
      final bytes = WadFixture.build(
        magic: 'XXXX',
        lumps: const [('E1M1', <int>[])],
      );

      expect(() => WadParser.parseBytes(bytes),
          throwsA(isA<WadFormatException>()));
    });

    test('throws on file too small to be a WAD', () {
      final bytes = Uint8List(4);
      expect(() => WadParser.parseBytes(bytes),
          throwsA(isA<WadFormatException>()));
    });
  });

  group('WadParser directory', () {
    test('exposes lump names, sizes and offsets', () {
      final wad = WadParser.parseBytes(WadFixture.classicDoomE1M1());

      final names = wad.lumps.map((l) => l.name).toList();
      expect(names, [
        'E1M1', 'THINGS', 'LINEDEFS', 'SIDEDEFS', 'VERTEXES', 'SECTORS',
      ]);

      final things = wad.lumpByName('THINGS');
      expect(things, isNotNull);
      expect(things!.size, 20);
      expect(things.bytes, hasLength(20));
    });

    test('trims null-padded short lump names', () {
      final wad = WadParser.parseBytes(WadFixture.build(
        magic: 'PWAD',
        lumps: const [('X', <int>[])],
      ));

      expect(wad.lumps.single.name, 'X');
    });

    test('reads lump data via zero-copy views', () {
      final wad = WadParser.parseBytes(WadFixture.classicDoomE1M1());
      final vertices = wad.lumpByName('VERTEXES')!;

      // Three vertices - no padding/overlap in the buffer view.
      expect(vertices.data.lengthInBytes, 12);
    });
  });

  group('WadParser map grouping', () {
    test('groups E1M1 marker with its sub-lumps', () {
      final wad = WadParser.parseBytes(WadFixture.classicDoomE1M1());

      expect(wad.maps, hasLength(1));
      final map = wad.maps.single;
      expect(map.name, 'E1M1');
      expect(map.lumps.map((l) => l.name), [
        'THINGS', 'LINEDEFS', 'SIDEDEFS', 'VERTEXES', 'SECTORS',
      ]);
    });

    test('detects multiple maps (E1M1 and MAP01) in one WAD', () {
      final wad = WadParser.parseBytes(WadFixture.build(
        magic: 'PWAD',
        lumps: const [
          ('E1M1', <int>[]),
          ('THINGS', <int>[]),
          ('VERTEXES', <int>[]),
          ('PLAYPAL', <int>[]),
          ('MAP01', <int>[]),
          ('THINGS', <int>[]),
          ('LINEDEFS', <int>[]),
        ],
      ));

      expect(wad.maps, hasLength(2));
      expect(wad.maps[0].name, 'E1M1');
      expect(wad.maps[0].lumps.map((l) => l.name), ['THINGS', 'VERTEXES']);
      expect(wad.maps[1].name, 'MAP01');
      expect(wad.maps[1].lumps.map((l) => l.name), ['THINGS', 'LINEDEFS']);
    });

    test('ignores non-map lumps between maps', () {
      final wad = WadParser.parseBytes(WadFixture.build(
        magic: 'PWAD',
        lumps: const [
          ('DMXGUS', <int>[]),
          ('E1M1', <int>[]),
          ('THINGS', <int>[]),
        ],
      ));

      expect(wad.maps, hasLength(1));
      expect(wad.maps.single.name, 'E1M1');
    });
  });

  test('throws when the directory is out of bounds', () {
    final bytes = WadFixture.build(
      magic: 'PWAD',
      lumps: const [('E1M1', <int>[])],
    );
    // Corrupt the directory offset to point past the end of the file.
    final view = ByteData.sublistView(bytes);
    view.setUint32(8, 0x7FFFFFFF, Endian.little);
    bytes[4] = 0xFF;

    expect(() => WadParser.parseBytes(bytes),
        throwsA(isA<WadFormatException>()));
  });
}