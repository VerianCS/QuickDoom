import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../domain/models/doom_map.dart';
import '../../domain/models/wad_lump.dart';
import '../../domain/parsers/doom_map_parser.dart';
import '../../domain/parsers/wad_parser.dart';

/// Reads maps out of a PK3 / PK4 (ZIP) container.
///
/// Two layouts are supported:
///  * `maps/<name>.wad` — a complete embedded WAD, decoded by [WadParser].
///  * `maps/<name>/<LUMP>` — a folder of lump files, typically a UDMF map
///    (`TEXTMAP`, `THINGS`, ...). The folder name is the map name, so custom
///    map names work without relying on marker-lump conventions.
class Pk3Reader {
  static List<DoomMap> parseBytes(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final maps = <DoomMap>[];

    // 1) Embedded WADs under maps/.
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = file.name.toLowerCase();
      if (name.startsWith('maps/') && name.endsWith('.wad')) {
        final wadBytes = Uint8List.fromList(file.content as List<int>);
        maps.addAll(DoomMapParser.parseAll(WadParser.parseBytes(wadBytes)));
      }
    }

    // 2) Folder-based maps: maps/<name>/<LUMP>.
    final folderMaps = <String, Map<String, Uint8List>>{};
    const prefix = 'maps/';
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = file.name;
      if (!name.toLowerCase().startsWith(prefix)) continue;
      final rest = name.substring(prefix.length);
      final slash = rest.indexOf('/');
      if (slash <= 0) continue; // must be maps/<name>/<lump>
      final mapName = rest.substring(0, slash);
      final lumpName = rest.substring(slash + 1);
      if (lumpName.isEmpty) continue;
      folderMaps
          .putIfAbsent(mapName, () => <String, Uint8List>{})
          .putIfAbsent(lumpName.toUpperCase(), () {
        return Uint8List.fromList(file.content as List<int>);
      });
    }

    for (final entry in folderMaps.entries) {
      final mapName = entry.key.toUpperCase();
      final lumpsData = entry.value;

      final lumps = <WadLump>[_marker(mapName)];
      for (final lumpEntry in lumpsData.entries) {
        if (lumpEntry.key == mapName) continue;
        lumps.add(_lump(lumpEntry.key, lumpEntry.value));
      }

      final wad = WadParser.fromLumps(
        'PK3',
        lumps,
        knownMapNames: {mapName},
      );
      maps.addAll(DoomMapParser.parseAll(wad));
    }

    return maps;
  }

  static WadLump _marker(String name) {
    return WadLump(
      name: name,
      offset: 0,
      size: 0,
      data: ByteData.sublistView(Uint8List(0)),
    );
  }

  static WadLump _lump(String name, Uint8List bytes) {
    return WadLump(
      name: name,
      offset: 0,
      size: bytes.length,
      data: ByteData.sublistView(bytes),
    );
  }
}
