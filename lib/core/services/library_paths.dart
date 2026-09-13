import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where QuickDoom keeps downloaded content.
///
/// Everything lives under one root, by default the platform
/// application-support directory:
///
///     <root>/downloads              raw archives as fetched
///     <root>/mods/<id>              one directory per installed mod
///     <root>/engines/<id>/<tag>     one directory per engine release
///
/// [rootResolver] is injectable so tests can point the whole tree at a
/// temporary directory instead of reaching for a platform channel.
class LibraryPaths {
  final Future<String> Function() _rootResolver;

  LibraryPaths({Future<String> Function()? rootResolver})
      : _rootResolver = rootResolver ?? _applicationSupportRoot;

  static Future<String> _applicationSupportRoot() async {
    final dir = await getApplicationSupportDirectory();
    return dir.path;
  }

  Future<String> root() => _rootResolver();

  Future<String> downloads() => _ensure(['downloads']);

  Future<String> modsRoot() => _ensure(['mods']);

  Future<String> enginesRoot() => _ensure(['engines']);

  Future<String> modDir(String modId) => _ensure(['mods', sanitize(modId)]);

  Future<String> engineDir(String engineId, String tag) =>
      _ensure(['engines', sanitize(engineId), sanitize(tag)]);

  Future<String> _ensure(List<String> segments) async {
    final path = p.joinAll([await root(), ...segments]);
    await Directory(path).create(recursive: true);
    return path;
  }

  /// Makes [value] safe to use as a single path segment.
  ///
  /// Release tags carry slashes and colons, which would silently nest
  /// directories or fail outright on Windows.
  static String sanitize(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final trimmed = cleaned.replaceAll(RegExp(r'^[._]+'), '');
    return trimmed.isEmpty ? 'untitled' : trimmed;
  }
}
