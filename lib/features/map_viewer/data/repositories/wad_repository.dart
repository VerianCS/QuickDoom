import 'dart:io';

import '../../domain/models/doom_map.dart';
import '../../domain/models/wad_file.dart';
import '../../domain/parsers/doom_map_parser.dart';
import '../../domain/parsers/wad_parser.dart';

/// Loads WAD files from disk and parses them into domain models.
class WadRepository {
  Future<WadFile> loadWad(String path) async {
    final bytes = await File(path).readAsBytes();
    return WadParser.parseBytes(bytes);
  }

  Future<List<DoomMap>> loadMaps(String path) async {
    final wad = await loadWad(path);
    return DoomMapParser.parseAll(wad);
  }
}
