import 'dart:io';
import 'dart:typed_data';

import '../../domain/models/doom_map.dart';
import '../../domain/models/map_order.dart';
import '../../domain/models/wad_file.dart';
import '../../domain/parsers/doom_map_parser.dart';
import '../../domain/parsers/wad_parser.dart';
import 'pk3_reader.dart';

/// Loads WAD / PK3 files from disk and parses them into domain models.
class WadRepository {
  Future<WadFile> loadWad(String path) async {
    final bytes = await File(path).readAsBytes();
    return WadParser.parseBytes(bytes);
  }

  Future<List<DoomMap>> loadMaps(String path) async {
    final bytes = await File(path).readAsBytes();
    return parseBytes(path, bytes);
  }

  /// Parses already-read bytes, dispatching to the PK3 reader when the path
  /// extension or the zip signature indicates a compressed container.
  ///
  /// Maps come back in level order rather than the order they happen to sit in
  /// the container, which for PWADs is the order they were authored in.
  List<DoomMap> parseBytes(String path, Uint8List bytes) {
    final maps = _isZipContainer(path, bytes)
        ? Pk3Reader.parseBytes(bytes)
        : DoomMapParser.parseAll(WadParser.parseBytes(bytes));
    return MapOrder.sorted(maps);
  }

  static bool _isZipContainer(String path, Uint8List bytes) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.pk3') ||
        lower.endsWith('.pk4') ||
        lower.endsWith('.zip')) {
      return true;
    }
    // Local file header (PK\x03\x04) or empty archive (PK\x05\x06).
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        ((bytes[2] == 0x03 && bytes[3] == 0x04) ||
            (bytes[2] == 0x05 && bytes[3] == 0x06));
  }
}
