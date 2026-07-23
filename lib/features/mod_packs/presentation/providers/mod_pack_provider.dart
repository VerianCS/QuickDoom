import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/mod_pack.dart';

part 'mod_pack_provider.g.dart';

const _boxName = 'mod_packs';

@riverpod
class ModPackList extends _$ModPackList {
  @override
  Future<List<ModPack>> build() async {
    final box = await Hive.openBox(_boxName);
    final data = box.get('packs') as List<dynamic>? ?? [];
    return data
        .cast<Map<dynamic, dynamic>>()
        .map((m) => _fromMap(m))
        .toList();
  }

  Future<void> create(String name, {String description = ''}) async {
    final pack = ModPack(
      id: const Uuid().v4(),
      name: name,
      description: description,
    );
    await _savePack(pack);
  }

  Future<void> save(ModPack pack) async {
    await _savePack(pack);
  }

  Future<void> delete(String id) async {
    final packs = await _getPacks();
    packs.removeWhere((p) => p.id == id);
    await _persist(packs);
    ref.invalidateSelf();
  }

  Future<List<ModPack>> _getPacks() async {
    final box = await Hive.openBox(_boxName);
    final data = box.get('packs') as List<dynamic>? ?? [];
    return data.cast<Map<dynamic, dynamic>>().map((m) => _fromMap(m)).toList();
  }

  Future<void> _savePack(ModPack pack) async {
    final packs = await _getPacks();
    final idx = packs.indexWhere((p) => p.id == pack.id);
    if (idx >= 0) {
      packs[idx] = pack;
    } else {
      packs.add(pack);
    }
    await _persist(packs);
    ref.invalidateSelf();
  }

  Future<void> _persist(List<ModPack> packs) async {
    final box = await Hive.openBox(_boxName);
    await box.put('packs', packs.map((p) => _toMap(p)).toList());
  }

  Map<String, dynamic> _toMap(ModPack p) => {
    'id': p.id,
    'name': p.name,
    'description': p.description,
    'modIds': p.modIds,
    'iwadId': p.iwadId,
    'engineId': p.engineId,
  };

  ModPack _fromMap(Map<dynamic, dynamic> m) => ModPack(
    id: m['id'] as String,
    name: m['name'] as String,
    description: m['description'] as String? ?? '',
    modIds: (m['modIds'] as List<dynamic>?)?.cast<int>().toList() ?? [],
    iwadId: m['iwadId'] as String?,
    engineId: m['engineId'] as String?,
  );
}
