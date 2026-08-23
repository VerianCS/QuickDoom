import 'dart:convert';
import 'dart:typed_data';

import '../errors/wad_format_exception.dart';
import '../models/wad_file.dart';
import '../models/wad_lump.dart';
import 'mapinfo_parser.dart';

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
    // ZDoom / Hexen per-map lumps that may follow the standard set.
    'ZNODES', 'DIALOGUE', 'POLYOBJ',
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

    if (directoryOffset < headerSize) {
      throw const WadFormatException('WAD directory starts inside the header');
    }

    final directoryEnd = directoryOffset + lumpCount * directoryEntrySize;
    if (directoryEnd > bytes.length) {
      throw const WadFormatException('WAD directory is out of bounds');
    }

    final lumps = <WadLump>[];
    for (var i = 0; i < lumpCount; i++) {
      final entry = directoryOffset + i * directoryEntrySize;
      final offset = view.getUint32(entry, Endian.little);
      final size = view.getUint32(entry + 4, Endian.little);
      final name = _readAscii(view, entry + 8, lumpNameLength).toUpperCase();

      if (offset + size > bytes.length) {
        throw WadFormatException('Lump "$name" exceeds file bounds');
      }

      // A lump's data must not overlap the directory region.
      if (offset < directoryEnd && offset + size > directoryOffset) {
        throw WadFormatException('Lump "$name" overlaps the WAD directory');
      }

      lumps.add(WadLump(
        name: name,
        offset: offset,
        size: size,
        data: ByteData.sublistView(bytes, offset, offset + size),
      ));
    }

    return fromLumps(magic, lumps);
  }

  /// Builds a [WadFile] from already-decoded lumps (used by [parseBytes] and
  /// by readers for other container formats such as PK3).
  ///
  /// [knownMapNames] overrides the set of marker names used for grouping. When
  /// omitted, map markers are detected via the classic `E#M#` / `MAP##` regex
  /// plus any names declared in a `MAPINFO` lump.
  static WadFile fromLumps(String magic, List<WadLump> lumps,
      {Set<String>? knownMapNames}) {
    final mapNames = knownMapNames ??
        _defaultMapNames(lumps)..addAll(_mapInfoNames(lumps));
    return WadFile(
      magic: magic,
      lumps: lumps,
      maps: _groupMaps(lumps, mapNames),
    );
  }

  static bool isMapMarker(String name) => _mapNameRegex.hasMatch(name);

  static Set<String> _defaultMapNames(List<WadLump> lumps) {
    final names = <String>{};
    for (final lump in lumps) {
      if (_mapNameRegex.hasMatch(lump.name)) names.add(lump.name);
    }
    return names;
  }

  static Set<String> _mapInfoNames(List<WadLump> lumps) {
    final info = _findIgnoreCase(lumps, 'MAPINFO');
    if (info == null) return const {};
    return MapInfoParser.parseNames(latin1.decode(info.bytes));
  }

  static WadLump? _findIgnoreCase(List<WadLump> lumps, String name) {
    final upper = name.toUpperCase();
    for (final lump in lumps) {
      if (lump.name == upper) return lump;
    }
    return null;
  }

  /// Groups each map marker with the sub-lumps that immediately follow it.
  /// Stops at the next map marker or the first non-map lump.
  static List<WadMapLumps> _groupMaps(
      List<WadLump> lumps, Set<String> mapNames) {
    final maps = <WadMapLumps>[];
    for (var i = 0; i < lumps.length; i++) {
      final name = lumps[i].name;
      if (!mapNames.contains(name)) continue;

      final subLumps = <WadLump>[];
      var j = i + 1;
      while (j < lumps.length &&
          !mapNames.contains(lumps[j].name) &&
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
