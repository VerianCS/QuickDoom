import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/library_paths.dart';
import '../../data/repositories/mod_library_store.dart';
import '../../domain/entities/installed_mod.dart';

part 'mod_library_provider.g.dart';

final modLibraryStoreProvider = Provider<ModLibraryStore>((ref) {
  return ModLibraryStore();
});

/// Resolves QuickDoom's download/install directories.
///
/// Overridden in tests to redirect the tree into a temporary directory.
final libraryPathsProvider = Provider<LibraryPaths>((ref) {
  return LibraryPaths();
});

/// Every mod QuickDoom has unpacked, newest first.
@riverpod
class ModLibrary extends _$ModLibrary {
  @override
  Future<List<InstalledMod>> build() async {
    final mods = await ref.read(modLibraryStoreProvider).getAll();
    mods.sort((a, b) => b.installedAt.compareTo(a.installedAt));
    return mods;
  }

  Future<void> add(InstalledMod mod) async {
    await ref.read(modLibraryStoreProvider).save(mod);
    ref.invalidateSelf();
  }

  Future<void> remove(String id, {bool deleteFiles = true}) async {
    final store = ref.read(modLibraryStoreProvider);
    if (deleteFiles) {
      final root = await ref.read(libraryPathsProvider).modsRoot();
      await store.deleteWithFiles(id, libraryRoot: root);
    } else {
      await store.delete(id);
    }
    ref.invalidateSelf();
  }

  /// Looks up mods by id, skipping ids that are no longer installed.
  ///
  /// Mod packs hold ids, so a pack referencing a removed mod resolves to the
  /// mods that do remain instead of failing.
  Future<List<InstalledMod>> resolve(Iterable<String> ids) async {
    final mods = await future;
    final byId = {for (final m in mods) m.id: m};
    return ids
        .map((id) => byId[id])
        .whereType<InstalledMod>()
        .toList();
  }
}
