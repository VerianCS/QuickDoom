import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// What an install produced on disk.
class InstallResult {
  /// Directory the payload now lives in.
  final String installDir;

  /// Files the source port can load, in load order.
  final List<String> loadableFiles;

  /// Candidate engine binaries, best guess first.
  final List<String> executables;

  /// Total bytes written.
  final int sizeBytes;

  const InstallResult({
    required this.installDir,
    this.loadableFiles = const [],
    this.executables = const [],
    this.sizeBytes = 0,
  });
}

/// Thrown when a downloaded archive cannot be turned into something loadable.
class InstallException implements Exception {
  final String message;

  const InstallException(this.message);

  @override
  String toString() => 'InstallException: $message';
}

/// Unpacks downloaded archives into the library.
///
/// A download is one of three things: a zip that needs extracting, a file the
/// port loads directly (`.wad`, `.pk3`, ...), or something we don't recognise.
/// Note that `.pk3`/`.pk7`/`.ipk3` are themselves zips but must stay packed —
/// the port reads them as containers — so extension wins over file signature.
class InstallService {
  /// Extensions a source port can be pointed at with `-file`.
  static const Set<String> loadableExtensions = {
    '.wad',
    '.pk3',
    '.pk7',
    '.ipk3',
    '.ipk7',
    '.deh',
    '.bex',
  };

  /// Loaded before patches, so map/content files take priority.
  static const Set<String> _contentExtensions = {
    '.wad',
    '.pk3',
    '.pk7',
    '.ipk3',
    '.ipk7',
  };

  static const List<int> _zipSignature = [0x50, 0x4B, 0x03, 0x04];

  /// Installs [archivePath] into [destDir], which is created if missing.
  ///
  /// The source file is left where it is; callers own the download cache.
  Future<InstallResult> install(
    String archivePath, {
    required String destDir,
    String? preferredExecutableName,
  }) async {
    final source = File(archivePath);
    if (!await source.exists()) {
      throw InstallException('Archive not found: $archivePath');
    }

    final dest = Directory(destDir);
    await dest.create(recursive: true);

    if (!await _isZip(source)) {
      return _installLooseFile(source, dest);
    }

    return _extractZip(source, dest, preferredExecutableName);
  }

  /// True when [file] should be unpacked rather than loaded as-is.
  Future<bool> _isZip(File file) async {
    final ext = p.extension(file.path).toLowerCase();
    if (loadableExtensions.contains(ext)) return false;
    if (ext == '.zip') return true;

    // No useful extension (common for GitHub assets): sniff the header.
    final handle = await file.open();
    try {
      final header = await handle.read(4);
      if (header.length < 4) return false;
      for (var i = 0; i < 4; i++) {
        if (header[i] != _zipSignature[i]) return false;
      }
      return true;
    } finally {
      await handle.close();
    }
  }

  Future<InstallResult> _installLooseFile(File source, Directory dest) async {
    final ext = p.extension(source.path).toLowerCase();
    if (!loadableExtensions.contains(ext)) {
      throw InstallException(
        'Unsupported file type "$ext" — expected a zip or a loadable mod file.',
      );
    }

    final target = p.join(dest.path, p.basename(source.path));
    if (p.equals(target, source.path)) {
      final length = await source.length();
      return InstallResult(
        installDir: dest.path,
        loadableFiles: [target],
        sizeBytes: length,
      );
    }

    final copied = await source.copy(target);
    return InstallResult(
      installDir: dest.path,
      loadableFiles: [copied.path],
      sizeBytes: await copied.length(),
    );
  }

  Future<InstallResult> _extractZip(
    File source,
    Directory dest,
    String? preferredExecutableName,
  ) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(await source.readAsBytes());
    } catch (e) {
      throw InstallException('Could not read archive: $e');
    }

    final written = <String>[];
    var totalBytes = 0;

    for (final entry in archive.files) {
      if (!entry.isFile || entry.isSymbolicLink) continue;

      final target = _resolveSafely(dest.path, entry.name);
      if (target == null) continue; // Zip-slip attempt; skip the entry.

      final bytes = entry.readBytes();
      if (bytes == null) continue;

      final file = File(target);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);

      written.add(target);
      totalBytes += bytes.length;
    }

    if (written.isEmpty) {
      throw InstallException('Archive contained no usable files.');
    }

    final loadable = sortLoadable(
      written.where((f) => loadableExtensions.contains(
            p.extension(f).toLowerCase(),
          )),
    );

    final executables = await _findExecutables(written, preferredExecutableName);

    return InstallResult(
      installDir: dest.path,
      loadableFiles: loadable,
      executables: executables,
      sizeBytes: totalBytes,
    );
  }

  /// Joins [entryName] onto [root], returning null if it escapes [root].
  ///
  /// Guards against zip-slip: archive entries come off the internet and may
  /// contain `../` segments or absolute paths.
  static String? _resolveSafely(String root, String entryName) {
    final normalized = p.normalize(entryName).replaceAll('\\', '/');
    if (normalized.startsWith('/') || normalized.startsWith('..')) return null;
    if (p.isAbsolute(normalized)) return null;

    final target = p.normalize(p.join(root, normalized));
    if (!p.isWithin(root, target)) return null;
    return target;
  }

  /// Content files (maps, resources) before patches, alphabetical within each.
  static List<String> sortLoadable(Iterable<String> files) {
    final sorted = files.toList()
      ..sort((a, b) {
        final aContent = _contentExtensions.contains(p.extension(a).toLowerCase());
        final bContent = _contentExtensions.contains(p.extension(b).toLowerCase());
        if (aContent != bContent) return aContent ? -1 : 1;
        return p.basename(a).toLowerCase().compareTo(p.basename(b).toLowerCase());
      });
    return sorted;
  }

  /// Picks engine binaries out of an extracted release, best guess first.
  ///
  /// On POSIX the extracted files carry no permission bits from the zip, so
  /// every candidate is marked executable before being returned.
  Future<List<String>> _findExecutables(
    List<String> files,
    String? preferredName,
  ) async {
    final candidates = files.where(isExecutableCandidate).toList()
      ..sort((a, b) => _executableRank(a, preferredName)
          .compareTo(_executableRank(b, preferredName)));

    if (!Platform.isWindows) {
      for (final path in candidates) {
        await _markExecutable(path);
      }
    }

    return candidates;
  }

  /// True when [path] looks like a launchable engine binary.
  static bool isExecutableCandidate(String path) {
    final name = p.basename(path);
    final ext = p.extension(path).toLowerCase();

    if (ext == '.exe') return true;
    if (ext == '.appimage') return true;

    // Bare names (no extension) are the usual Linux/macOS binary shape.
    // Skip dotfiles and anything that is plainly data.
    if (ext.isEmpty && !name.startsWith('.')) {
      return !_nonExecutableNames.contains(name.toUpperCase());
    }

    return false;
  }

  static const Set<String> _nonExecutableNames = {
    'LICENSE',
    'COPYING',
    'README',
    'CHANGELOG',
    'AUTHORS',
    'NOTICE',
    'INSTALL',
    'MAKEFILE',
  };

  /// Lower sorts earlier: exact name match, then prefix match, then the rest.
  static int _executableRank(String path, String? preferredName) {
    final stem = p.basenameWithoutExtension(path).toLowerCase();
    final wanted = preferredName?.toLowerCase();

    if (wanted != null && wanted.isNotEmpty) {
      if (stem == wanted) return 0;
      if (stem.startsWith(wanted) || wanted.startsWith(stem)) return 1;
    }
    // Prefer binaries at the archive root over ones buried in subfolders.
    return 2 + p.split(path).length;
  }

  Future<void> _markExecutable(String path) async {
    try {
      await Process.run('chmod', ['+x', path]);
    } catch (_) {
      // Best effort: a non-executable bit surfaces at launch time instead.
    }
  }

  /// Reads the first bytes of [bytes] to check for a zip header.
  ///
  /// Exposed for tests and callers holding an in-memory payload.
  static bool looksLikeZip(Uint8List bytes) {
    if (bytes.length < 4) return false;
    for (var i = 0; i < 4; i++) {
      if (bytes[i] != _zipSignature[i]) return false;
    }
    return true;
  }
}
