import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/mod_pack.dart';

part 'mod_pack_provider.g.dart';

const _boxName = 'mod_packs';
const _key = 'packs';

@riverpod
class ModPackList extends _$ModPackList {
  @override
  Future<List<ModPack>> build() async => _getPacks();

  Future<void> create(String name, {String description = ''}) async {
    await _savePack(ModPack(
      id: const Uuid().v4(),
      name: name,
      description: description,
    ));
  }

  Future<void> save(ModPack pack) async => _savePack(pack);

  Future<void> delete(String id) async {
    final packs = await _getPacks();
    packs.removeWhere((p) => p.id == id);
    await _persist(packs);
    ref.invalidateSelf();
  }

  /// Adds mods to the end of a pack, skipping ones already in it.
  Future<void> addMods(String packId, Iterable<String> modIds) async {
    final packs = await _getPacks();
    final index = packs.indexWhere((p) => p.id == packId);
    if (index < 0) return;

    final pack = packs[index];
    final additions = modIds
        .where((id) => !pack.contains(id))
        .map((id) => ModPackEntry(modId: id));

    packs[index] = pack.copyWith(entries: [...pack.entries, ...additions]);
    await _persist(packs);
    ref.invalidateSelf();
  }

  Future<void> removeMod(String packId, String modId) async {
    await _mutate(packId, (pack) {
      return pack.copyWith(
        entries: pack.entries.where((e) => e.modId != modId).toList(),
      );
    });
  }

  Future<void> toggleMod(String packId, String modId) async {
    await _mutate(packId, (pack) {
      return pack.copyWith(
        entries: pack.entries
            .map((e) =>
                e.modId == modId ? e.copyWith(isEnabled: !e.isEnabled) : e)
            .toList(),
      );
    });
  }

  Future<void> reorder(String packId, int oldIndex, int newIndex) async {
    await _mutate(packId, (pack) {
      final entries = List<ModPackEntry>.from(pack.entries);
      if (oldIndex < 0 || oldIndex >= entries.length) return pack;

      // ReorderableListView reports the insertion index before removal.
      var target = newIndex;
      if (target > oldIndex) target--;
      target = target.clamp(0, entries.length - 1);

      final moved = entries.removeAt(oldIndex);
      entries.insert(target, moved);
      return pack.copyWith(entries: entries);
    });
  }

  Future<void> _mutate(
    String packId,
    ModPack Function(ModPack pack) change,
  ) async {
    final packs = await _getPacks();
    final index = packs.indexWhere((p) => p.id == packId);
    if (index < 0) return;

    packs[index] = change(packs[index]);
    await _persist(packs);
    ref.invalidateSelf();
  }

  Future<List<ModPack>> _getPacks() async {
    final box = await Hive.openBox(_boxName);
    final data = box.get(_key) as List<dynamic>? ?? const [];
    return data.whereType<Map<dynamic, dynamic>>().map(packFromMap).toList();
  }

  Future<void> _savePack(ModPack pack) async {
    final packs = await _getPacks();
    final index = packs.indexWhere((p) => p.id == pack.id);
    if (index >= 0) {
      packs[index] = pack;
    } else {
      packs.add(pack);
    }
    await _persist(packs);
    ref.invalidateSelf();
  }

  Future<void> _persist(List<ModPack> packs) async {
    final box = await Hive.openBox(_boxName);
    await box.put(_key, packs.map(packToMap).toList());
  }
}

Map<String, dynamic> packToMap(ModPack p) => {
      'id': p.id,
      'name': p.name,
      'description': p.description,
      'entries': p.entries
          .map((e) => {'modId': e.modId, 'isEnabled': e.isEnabled})
          .toList(),
      'iwadId': p.iwadId,
      'engineId': p.engineId,
    };

/// Reads a persisted pack.
///
/// Packs written before the library existed carry a `modIds` list of
/// placeholder integers that never referenced a real file. Those are dropped
/// rather than migrated — there is nothing on disk to point them at — while
/// the pack itself, its name and its engine/IWAD choices survive.
ModPack packFromMap(Map<dynamic, dynamic> m) {
  final rawEntries = m['entries'] as List<dynamic>? ?? const [];

  return ModPack(
    id: m['id'] as String? ?? '',
    name: m['name'] as String? ?? 'Untitled',
    description: m['description'] as String? ?? '',
    entries: rawEntries
        .whereType<Map<dynamic, dynamic>>()
        .map((e) {
          final modId = e['modId'] as String?;
          if (modId == null || modId.isEmpty) return null;
          return ModPackEntry(
            modId: modId,
            isEnabled: e['isEnabled'] as bool? ?? true,
          );
        })
        .whereType<ModPackEntry>()
        .toList(),
    iwadId: m['iwadId'] as String?,
    engineId: m['engineId'] as String?,
  );
}
