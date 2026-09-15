import 'dart:io';

/// Whether a path the user chose earlier is still usable.
///
/// A saved port or IWAD is a path, and paths rot: files get moved, renamed,
/// uninstalled or restored without their permission bits. Until this was
/// surfaced the bench happily showed a seated slot for a file that no longer
/// existed, and only said so once the launch failed.
class FileProblem {
  const FileProblem._();

  /// What is wrong with [path], or null if nothing is.
  ///
  /// [needsExecuteBit] is for a program rather than a data file; it is
  /// ignored on Windows, which decides by extension and has no bit to read,
  /// so asking there would reject every valid port.
  static Future<String?> describe(
    String path, {
    bool needsExecuteBit = false,
    String noun = 'Source port',
  }) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return 'No $noun is set.';

    final type = await FileSystemEntity.type(trimmed);

    if (type == FileSystemEntityType.notFound) {
      return '$noun not found: $trimmed\n'
          'It may have been moved, renamed or uninstalled.';
    }

    if (type == FileSystemEntityType.directory) {
      return 'That is a folder, not a file: $trimmed';
    }

    if (needsExecuteBit && !Platform.isWindows) {
      final mode = (await File(trimmed).stat()).mode;
      // 0o111: executable by owner, group or other.
      if (mode & 0x49 == 0) {
        return '$noun is not executable: $trimmed\n'
            'Run: chmod +x "$trimmed"';
      }
    }

    return null;
  }

  /// A one-line version for a slot, which has no room for the advice.
  static String summarise(String problem) => problem.split('\n').first;
}
