/// A map to start the game on, chosen in the map viewer.
class WarpTarget {
  /// The map's lump name, e.g. `MAP14` or `E2M3`.
  final String mapName;

  /// The file the map came from, so the launcher can make sure it is loaded.
  /// Null when the map lives in the IWAD itself.
  final String? sourcePath;

  const WarpTarget({required this.mapName, this.sourcePath});

  /// The arguments that start a port on this map.
  ///
  /// `-warp` is the portable spelling: vanilla, Boom, DSDA, Chocolate and the
  /// ZDoom family all accept it, whereas `+map` is a ZDoom console command and
  /// does nothing elsewhere. It only understands the two standard naming
  /// schemes, though, so a PWAD with a custom lump name falls back to `+map`,
  /// which is the only thing that can address it at all.
  List<String> toArgs() {
    final name = mapName.toUpperCase();

    final mapNn = RegExp(r'^MAP(\d{1,2})$').firstMatch(name);
    if (mapNn != null) {
      return ['-warp', int.parse(mapNn.group(1)!).toString()];
    }

    final exMy = RegExp(r'^E(\d)M(\d)$').firstMatch(name);
    if (exMy != null) {
      return ['-warp', exMy.group(1)!, exMy.group(2)!];
    }

    return ['+map', mapName];
  }

  @override
  bool operator ==(Object other) =>
      other is WarpTarget &&
      other.mapName == mapName &&
      other.sourcePath == sourcePath;

  @override
  int get hashCode => Object.hash(mapName, sourcePath);
}
