class FileExtensions {
  static const List<String> wadExtensions = ['.wad', '.pk3', '.pk7', '.ipk3', '.ipk7'];
  static const List<String> iwadExtensions = ['.wad'];
  static const List<String> pwadExtensions = ['.wad', '.pk3', '.pk7', '.ipk3', '.ipk7', '.deh', '.bex'];
  static const List<String> executableExtensions = ['.exe', '', '.AppImage'];

  static bool isWadFile(String path) {
    final lower = path.toLowerCase();
    return wadExtensions.any((ext) => lower.endsWith(ext));
  }
}
