import 'wad_lump.dart';

/// A map marker lump (e.g. MAP01, E1M1) plus the sub-lumps that follow it.
class WadMapLumps {
  final String name;
  final List<WadLump> lumps;

  const WadMapLumps({required this.name, required this.lumps});

  WadLump? lumpByName(String lumpName) {
    final upper = lumpName.toUpperCase();
    for (final lump in lumps) {
      if (lump.name == upper) return lump;
    }
    return null;
  }
}

/// Parsed WAD file: magic (IWAD/PWAD), the full lump directory and grouped
/// map lump sets.
class WadFile {
  final String magic;
  final List<WadLump> lumps;
  final List<WadMapLumps> maps;

  const WadFile({required this.magic, required this.lumps, required this.maps});

  bool get isIwad => magic == 'IWAD';
  bool get isPwad => magic == 'PWAD';

  WadLump? lumpByName(String name) {
    final upper = name.toUpperCase();
    for (final lump in lumps) {
      if (lump.name == upper) return lump;
    }
    return null;
  }
}
