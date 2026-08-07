import 'dart:typed_data';

/// Builds in-memory WAD files as raw binary bytes for tests.
class WadFixture {
  static Uint8List build({
    required String magic,
    required List<(String, List<int>)> lumps,
  }) {
    var dataOffset = 12;
    final entries = <(int, int, String)>[];
    for (final (name, bytes) in lumps) {
      entries.add((dataOffset, bytes.length, name));
      dataOffset += bytes.length;
    }

    final totalSize = dataOffset + entries.length * 16;
    final bytes = Uint8List(totalSize);
    final view = ByteData.sublistView(bytes);

    _writeAscii(view, 0, magic);
    view.setUint32(4, lumps.length, Endian.little);
    view.setUint32(8, dataOffset, Endian.little);

    var cursor = 12;
    for (var i = 0; i < lumps.length; i++) {
      final lumpBytes = lumps[i].$2;
      bytes.setRange(cursor, cursor + lumpBytes.length, lumpBytes);
      cursor += lumpBytes.length;
    }

    var entryOffset = dataOffset;
    for (final (offset, size, name) in entries) {
      view.setUint32(entryOffset, offset, Endian.little);
      view.setUint32(entryOffset + 4, size, Endian.little);
      _writeAscii(view, entryOffset + 8, name.padRight(8, '\u0000').substring(0, 8));
      entryOffset += 16;
    }

    return bytes;
  }

  static void _writeAscii(ByteData view, int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      view.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  static List<int> u16(int value) => [value & 0xFF, (value >> 8) & 0xFF];

  static List<int> i16(int value) => u16(value & 0xFFFF);

  static List<int> texture(String name) {
    final bytes = <int>[];
    final padded = name.padRight(8, '\u0000');
    for (var i = 0; i < 8; i++) {
      bytes.add(padded.codeUnitAt(i));
    }
    return bytes;
  }

  static List<int> vertex(int x, int y) => [...i16(x), ...i16(y)];

  static List<int> linedef(int v1, int v2, int flags, int special, int tag,
      int frontSidedef, int backSidedef) {
    return [
      ...u16(v1),
      ...u16(v2),
      ...u16(flags),
      ...u16(special),
      ...u16(tag),
      ...u16(frontSidedef),
      ...u16(backSidedef),
    ];
  }

  static List<int> sidedef(int xOffset, int yOffset, String upper, String lower,
      String mid, int sectorIndex) {
    return [
      ...i16(xOffset),
      ...i16(yOffset),
      ...texture(upper),
      ...texture(lower),
      ...texture(mid),
      ...u16(sectorIndex),
    ];
  }

  static List<int> sector(
      int floorH, int ceilH, String floorTex, String ceilTex, int light,
      int special, int tag) {
    return [
      ...i16(floorH),
      ...i16(ceilH),
      ...texture(floorTex),
      ...texture(ceilTex),
      ...u16(light),
      ...u16(special),
      ...u16(tag),
    ];
  }

  static List<int> thing(int x, int y, int angle, int type, int flags) {
    return [...i16(x), ...i16(y), ...u16(angle), ...u16(type), ...u16(flags)];
  }

  static List<int> hexenThing(int tid, int x, int y, int z, int angle,
      int type, int flags, int special, List<int> args) {
    assert(args.length <= 5);
    return [
      ...u16(tid),
      ...i16(x),
      ...i16(y),
      ...i16(z),
      ...u16(angle),
      ...u16(type),
      ...u16(flags),
      special & 0xFF,
      ...[for (final arg in args) arg & 0xFF],
      ...List<int>.filled(5 - args.length, 0),
    ];
  }

  static List<int> hexenLinedef(int v1, int v2, int flags, int special,
      List<int> args, int frontSidedef, int backSidedef) {
    assert(args.length <= 5);
    return [
      ...u16(v1),
      ...u16(v2),
      ...u16(flags),
      special & 0xFF,
      ...[for (final arg in args) arg & 0xFF],
      ...List<int>.filled(5 - args.length, 0),
      ...u16(frontSidedef),
      ...u16(backSidedef),
    ];
  }

  /// PWAD containing a Hexen map (MAP01 with BEHAVIOR lump), one sector,
  /// three vertices, two linedefs with args and a fighter start thing.
  static Uint8List hexenMap01() {
    return build(
      magic: 'PWAD',
      lumps: [
        ('MAP01', const []),
        ('THINGS', [
          ...hexenThing(0, 64, -64, 0, 90, 3000, 0x00E1, 0, const []),
          ...hexenThing(5, 128, 128, 32, 0, 1, 0x00E1, 42, const [1, 2, 3, 4, 5]),
        ]),
        ('LINEDEFS', [
          ...hexenLinedef(0, 1, 0x0001, 10, const [7, 0, 0, 0, 0], 0, 0xFFFF),
          ...hexenLinedef(1, 2, 0x0005, 0, const [], 1, 0xFFFF),
        ]),
        ('SIDEDEFS', [
          ...sidedef(0, 0, '-', '-', 'STARTAN1', 0),
          ...sidedef(-16, 0, 'BIGDOOR1', 'BIGDOOR1', '-', 0),
        ]),
        ('VERTEXES', [
          ...vertex(0, 0),
          ...vertex(64, 0),
          ...vertex(64, -64),
        ]),
        ('SECTORS', [
          ...sector(-64, 128, 'FLOOR4_8', 'CEIL3_5', 160, 9, 0),
        ]),
        ('BEHAVIOR', const [0, 0]),
      ],
    );
  }

  /// Minimal PWAD containing a classic Doom E1M1 with one sector,
  /// three vertices, two linedefs, two sidedefs and two things.
  static Uint8List classicDoomE1M1() {
    return build(
      magic: 'PWAD',
      lumps: [
        ('E1M1', const []),
        ('THINGS', [
          ...thing(64, -64, 90, 1, 7), // player 1 start
          ...thing(128, 128, 0, 3001, 7), // imp
        ]),
        ('LINEDEFS', [
          ...linedef(0, 1, 0x0001, 0, 0, 0, 0xFFFF),
          ...linedef(1, 2, 0x0005, 1, 7, 1, 0xFFFF),
        ]),
        ('SIDEDEFS', [
          ...sidedef(0, 0, '-', '-', 'STARTAN1', 0),
          ...sidedef(-16, 0, 'BIGDOOR1', 'BIGDOOR1', '-', 0),
        ]),
        ('VERTEXES', [
          ...vertex(0, 0),
          ...vertex(64, 0),
          ...vertex(64, -64),
        ]),
        ('SECTORS', [
          ...sector(-64, 128, 'FLOOR4_8', 'CEIL3_5', 160, 9, 0),
        ]),
      ],
    );
  }
}