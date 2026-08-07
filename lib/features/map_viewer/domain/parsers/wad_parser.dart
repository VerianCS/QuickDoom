import 'dart:typed_data';

import '../errors/wad_format_exception.dart';
import '../models/wad_file.dart';
import '../models/wad_lump.dart';

/// Parses the WAD header and lump directory into [WadFile].
///
/// All reads go through [ByteData] with little-endian decoding. Lump data is
/// exposed as zero-copy `ByteData` views over the source bytes.
class WadParser {
  static const int headerSize = 12;
  static const int directoryEntrySize = 16;
  static const int lumpNameLength = 8;

  /// Doom 1 (E1M1), Doom 2 / Heretic / Hexen (MAP01..MAP99+) markers.
  static final RegExp _mapNameRegex = RegExp(r'^(E\d+M\d+|MAP\d{2,3})$');

  /// Lump names that belong to a map once a marker is found.
  static const Set<String> _mapLumpNames = {
    'THINGS', 'LINEDEFS', 'SIDEDEFS', 'VERTEXES', 'SECTORS',
    'SEGS', 'SSECTORS', 'NODES', 'REJECT', 'BLOCKMAP',
    'BEHAVIOR', 'TEXTMAP', 'SCRIPTS', 'LEAFS', 'LIGHTS',
    'MACROS', 'SOUNDINFO',
    'GL_VERT', 'GL_SEGS', 'GL_SSECT', 'GL_NODES', 'GL_LABELS',
    'GL_LEVEL', 'GL_PVS',
  };

  static WadFile parseBytes(Uint8List bytes) {
    if (bytes.length < headerSize) {
      throw const WadFormatException('File is too small to be a WAD');
    }

    final view = ByteData.sublistView(bytes);
    final magic = _readAscii(view, 0, 4);
    if (magic != 'IWAD' && magic != 'PWAD') {
      throw WadFormatException('Not a valid WAD: unknown magic "$magic"');
    }

    final lumpCount = view.getUint32(4, Endian.little);
    final directoryOffset = view.getUint32(8, Endian.little);

    if (lumpCount * directoryEntrySize > bytes.length ||
        directoryOffset + lumpCount * directoryEntrySize > bytes.length) {
      throw const WadFormatException('WAD directory is out of bounds');
    }

    final lumps = <WadLump>[];
    for (var i = 0; i < lumpCount; i++) {
      final entry = directoryOffset + i * directoryEntrySize;
      final offset = view.getUint32(entry, Endian.little);
      final size = view.getUint32(entry + 4, Endian.little);
      final name = _readAscii(view, entry + 8, lumpNameLength);

      if (offset + size > bytes.length) {
        throw WadFormatException('Lump "$name" exceeds file bounds');
      }

      lumps.add(WadLump(
        name: name,
        offset: offset,
        size: size,
        data: ByteData.sublistView(bytes, offset, offset + size),
      ));
    }

    return WadFile(magic: magic, lumps: lumps, maps: _groupMaps(lumps));
  }

  static bool isMapMarker(String name) => _mapNameRegex.hasMatch(name);

  /// Groups each map marker with the sub-lumps that immediately follow it.
  /// Stops at the next map marker or the first non-map lump.
  static List<WadMapLumps> _groupMaps(List<WadLump> lumps) {
    final maps = <WadMapLumps>[];
    for (var i = 0; i < lumps.length; i++) {
      final name = lumps[i].name;
      if (!_mapNameRegex.hasMatch(name)) continue;

      final subLumps = <WadLump>[];
      var j = i + 1;
      while (j < lumps.length &&
          !_mapNameRegex.hasMatch(lumps[j].name) &&
          _mapLumpNames.contains(lumps[j].name)) {
        subLumps.add(lumps[j]);
        j++;
      }

      maps.add(WadMapLumps(name: name, lumps: subLumps));
    }
    return maps;
  }

  static String _readAscii(ByteData view, int offset, int length) {
    final sb = StringBuffer();
    for (var i = 0; i < length; i++) {
      final byte = view.getUint8(offset + i);
      if (byte == 0) break;
      sb.writeCharCode(byte);
    }
    return sb.toString();
  }
}
