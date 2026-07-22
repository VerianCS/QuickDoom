import 'package:path/path.dart' as p;

class PathUtils {
  static String normalizePath(String raw) {
    return p.normalize(raw.trim()).replaceAll('/', '\\');
  }

  static String getFileName(String path) {
    return p.basename(path);
  }

  static String getDirectory(String path) {
    return p.dirname(path);
  }

  static bool isValidPath(String path) {
    return path.trim().isNotEmpty && path.length > 2;
  }
}
