import 'dart:typed_data';

import '../models/doom_map.dart';
import '../models/linedef.dart';
import '../models/sector.dart';
import '../models/sidedef.dart';
import '../models/thing.dart';
import '../models/vertex.dart';
import '../models/wad_file.dart';
import 'udmf_parser.dart';

/// Parses the classic Doom and Hexen binary map lumps (VERTEXES, LINEDEFS,
/// SIDEDEFS, SECTORS, THINGS) into [DoomMap]. All integers are little-endian.
///
/// UDMF maps are detected and handed off to [UdmfParser].
class DoomMapParser {
  static const int vertexSize = 4;
  static const int linedefSize = 14;
  static const int hexenLinedefSize = 16;
  static const int sidedefSize = 30;
  static const int sectorSize = 26;
  static const int thingSize = 10;
  static const int hexenThingSize = 20;
  static const int textureNameLength = 8;

  /// Sentinel for "no sidedef" in the binary format (0xFFFF).
  static const int noSidedef = 0xFFFF;

  static MapFormat detectFormat(WadMapLumps map) {
    if (map.lumpByName('TEXTMAP') != null) return MapFormat.udmf;
    if (map.lumpByName('BEHAVIOR') != null) return MapFormat.classicHexen;
    return MapFormat.classicDoom;
  }

  static DoomMap parse(WadMapLumps map) {
    switch (detectFormat(map)) {
      case MapFormat.udmf:
        return UdmfParser.parseMap(map);
      case MapFormat.classicHexen:
        return _parseHexen(map);
      case MapFormat.classicDoom:
        return _parseDoom(map);
    }
  }

  static DoomMap _parseHexen(WadMapLumps map) {
    return DoomMap(
      name: map.name,
      format: MapFormat.classicHexen,
      vertices: _parseVertices(map),
      linedefs: _parseHexenLinedefs(map),
      sidedefs: _parseSidedefs(map),
      sectors: _parseSectors(map),
      things: _parseHexenThings(map),
    );
  }

  static DoomMap _parseDoom(WadMapLumps map) {
    return DoomMap(
      name: map.name,
      format: MapFormat.classicDoom,
      vertices: _parseVertices(map),
      linedefs: _parseLinedefs(map),
      sidedefs: _parseSidedefs(map),
      sectors: _parseSectors(map),
      things: _parseThings(map),
    );
  }

  static List<DoomMap> parseAll(WadFile wad) => wad.maps.map(parse).toList();

  static List<Vertex> _parseVertices(WadMapLumps map) {
    final lump = map.lumpByName('VERTEXES');
    if (lump == null) return const [];
    final data = lump.data;
    final count = data.lengthInBytes ~/ vertexSize;
    return List<Vertex>.generate(count, (i) {
      final offset = i * vertexSize;
      return Vertex(
        x: data.getInt16(offset, Endian.little),
        y: data.getInt16(offset + 2, Endian.little),
      );
    });
  }

  static List<Linedef> _parseLinedefs(WadMapLumps map) {
    final lump = map.lumpByName('LINEDEFS');
    if (lump == null) return const [];
    final data = lump.data;
    final count = data.lengthInBytes ~/ linedefSize;
    return List<Linedef>.generate(count, (i) {
      final offset = i * linedefSize;
      return Linedef(
        startVertexIndex: data.getUint16(offset, Endian.little),
        endVertexIndex: data.getUint16(offset + 2, Endian.little),
        flags: data.getUint16(offset + 4, Endian.little),
        special: data.getUint16(offset + 6, Endian.little),
        tag: data.getUint16(offset + 8, Endian.little),
        frontSidedefIndex: _sidedefIndex(data, offset + 10),
        backSidedefIndex: _sidedefIndex(data, offset + 12),
      );
    });
  }

  /// Hexen linedefs are 16 bytes: v1, v2, flags (each int16), then a single
  /// special byte followed by 5 argument bytes, then front/back sidedefs.
  static List<Linedef> _parseHexenLinedefs(WadMapLumps map) {
    final lump = map.lumpByName('LINEDEFS');
    if (lump == null) return const [];
    final data = lump.data;
    final count = data.lengthInBytes ~/ hexenLinedefSize;
    return List<Linedef>.generate(count, (i) {
      final offset = i * hexenLinedefSize;
      return Linedef(
        startVertexIndex: data.getUint16(offset, Endian.little),
        endVertexIndex: data.getUint16(offset + 2, Endian.little),
        flags: data.getUint16(offset + 4, Endian.little),
        special: data.getUint8(offset + 6),
        tag: 0,
        args: [
          for (var a = 0; a < 5; a++) data.getUint8(offset + 7 + a),
        ],
        frontSidedefIndex: _sidedefIndex(data, offset + 12),
        backSidedefIndex: _sidedefIndex(data, offset + 14),
      );
    });
  }

  /// Hexen things are 20 bytes: tid, x, y, z, angle, type, flags (int16s),
  /// then a special byte followed by 5 argument bytes.
  static List<Thing> _parseHexenThings(WadMapLumps map) {
    final lump = map.lumpByName('THINGS');
    if (lump == null) return const [];
    final data = lump.data;
    final count = data.lengthInBytes ~/ hexenThingSize;
    return List<Thing>.generate(count, (i) {
      final offset = i * hexenThingSize;
      return Thing(
        tid: data.getUint16(offset, Endian.little),
        x: data.getInt16(offset + 2, Endian.little),
        y: data.getInt16(offset + 4, Endian.little),
        z: data.getInt16(offset + 6, Endian.little),
        angle: data.getInt16(offset + 8, Endian.little),
        type: data.getUint16(offset + 10, Endian.little),
        flags: data.getUint16(offset + 12, Endian.little),
        special: data.getUint8(offset + 14),
        args: [
          for (var a = 0; a < 5; a++) data.getUint8(offset + 15 + a),
        ],
      );
    });
  }

  static List<Sidedef> _parseSidedefs(WadMapLumps map) {
    final lump = map.lumpByName('SIDEDEFS');
    if (lump == null) return const [];
    final data = lump.data;
    final count = data.lengthInBytes ~/ sidedefSize;
    return List<Sidedef>.generate(count, (i) {
      final offset = i * sidedefSize;
      return Sidedef(
        xOffset: data.getInt16(offset, Endian.little),
        yOffset: data.getInt16(offset + 2, Endian.little),
        upperTexture: _textureName(data, offset + 4),
        lowerTexture: _textureName(data, offset + 12),
        middleTexture: _textureName(data, offset + 20),
        sectorIndex: data.getUint16(offset + 28, Endian.little),
      );
    });
  }

  static List<Sector> _parseSectors(WadMapLumps map) {
    final lump = map.lumpByName('SECTORS');
    if (lump == null) return const [];
    final data = lump.data;
    final count = data.lengthInBytes ~/ sectorSize;
    return List<Sector>.generate(count, (i) {
      final offset = i * sectorSize;
      return Sector(
        floorHeight: data.getInt16(offset, Endian.little),
        ceilingHeight: data.getInt16(offset + 2, Endian.little),
        floorTexture: _textureName(data, offset + 4),
        ceilingTexture: _textureName(data, offset + 12),
        lightLevel: data.getUint16(offset + 20, Endian.little),
        special: data.getUint16(offset + 22, Endian.little),
        tag: data.getUint16(offset + 24, Endian.little),
      );
    });
  }

  static List<Thing> _parseThings(WadMapLumps map) {
    final lump = map.lumpByName('THINGS');
    if (lump == null) return const [];
    final data = lump.data;
    final count = data.lengthInBytes ~/ thingSize;
    return List<Thing>.generate(count, (i) {
      final offset = i * thingSize;
      return Thing(
        x: data.getInt16(offset, Endian.little),
        y: data.getInt16(offset + 2, Endian.little),
        angle: data.getUint16(offset + 4, Endian.little),
        type: data.getUint16(offset + 6, Endian.little),
        flags: data.getUint16(offset + 8, Endian.little),
      );
    });
  }

  static int _sidedefIndex(ByteData data, int offset) {
    final raw = data.getUint16(offset, Endian.little);
    return raw == noSidedef ? -1 : raw;
  }

  /// Reads an 8-byte null-padded texture name, trimmed of padding and
  /// trailing spaces. `-` names become empty strings.
  static String _textureName(ByteData data, int offset) {
    final bytes = <int>[];
    for (var i = 0; i < textureNameLength; i++) {
      final byte = data.getUint8(offset + i);
      if (byte == 0) break;
      bytes.add(byte);
    }
    final name = String.fromCharCodes(bytes).trim();
    return name == '-' ? '' : name;
  }
}
