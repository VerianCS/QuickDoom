import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/installed_mod.dart';

/// Hive-backed persistence for installed mods.
///
/// Stored as plain maps under a single key rather than via a typed adapter, so
/// the library can gain fields without a Hive schema migration.
class ModLibraryStore {
  static const String boxName = 'mod_library';
  static const String _key = 'mods';

  Future<Box<dynamic>> _box() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box<dynamic>(boxName);
    return Hive.openBox<dynamic>(boxName);
  }

  Future<List<InstalledMod>> getAll() async {
    final box = await _box();
    final raw = box.get(_key) as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map(fromMap)
        .whereType<InstalledMod>()
        .toList();
  }

  Future<void> save(InstalledMod mod) async {
    final mods = await getAll();
    final index = mods.indexWhere((m) => m.id == mod.id);
    if (index >= 0) {
      mods[index] = mod;
    } else {
      mods.add(mod);
    }
    await _persist(mods);
  }

  Future<void> delete(String id) async {
    final mods = await getAll();
    mods.removeWhere((m) => m.id == id);
    await _persist(mods);
  }

  /// Removes the library entry and the files it unpacked.
  ///
  /// Only [InstalledMod.installDir] is removed, never the shared library root,
  /// so a malformed entry cannot take the whole library with it.
  Future<void> deleteWithFiles(String id, {required String libraryRoot}) async {
    final mods = await getAll();
    final matches = mods.where((m) => m.id == id).toList();
    final mod = matches.isEmpty ? null : matches.first;

    if (mod != null && mod.installDir.isNotEmpty) {
      final dir = Directory(mod.installDir);
      // p.isWithin, not a string prefix: "<root>2" starts with "<root>" but
      // is a different directory entirely.
      final isNested = p.isWithin(libraryRoot, mod.installDir);
      if (isNested && await dir.exists()) {
        try {
          await dir.delete(recursive: true);
        } catch (_) {
          // Leave the files behind rather than failing the removal.
        }
      }
    }

    await delete(id);
  }

  Future<void> _persist(List<InstalledMod> mods) async {
    final box = await _box();
    await box.put(_key, mods.map(toMap).toList());
  }

  static Map<String, dynamic> toMap(InstalledMod m) => {
        'id': m.id,
        'name': m.name,
        'installDir': m.installDir,
        'files': m.files,
        'idgamesId': m.idgamesId,
        'author': m.author,
        'sizeBytes': m.sizeBytes,
        'installedAt': m.installedAt.toIso8601String(),
      };

  /// Returns null for rows missing an id, which would be unaddressable.
  static InstalledMod? fromMap(Map<dynamic, dynamic> m) {
    final id = m['id'] as String?;
    if (id == null || id.isEmpty) return null;

    return InstalledMod(
      id: id,
      name: m['name'] as String? ?? 'Untitled',
      installDir: m['installDir'] as String? ?? '',
      files: (m['files'] as List<dynamic>?)?.whereType<String>().toList() ??
          const [],
      idgamesId: (m['idgamesId'] as num?)?.toInt(),
      author: m['author'] as String? ?? '',
      sizeBytes: (m['sizeBytes'] as num?)?.toInt() ?? 0,
      installedAt:
          DateTime.tryParse(m['installedAt'] as String? ?? '') ?? DateTime(1970),
    );
  }
}
