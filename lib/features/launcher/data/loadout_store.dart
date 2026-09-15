import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/gameplay_options.dart';
import '../../../domain/entities/pwad.dart';

/// Where the bench is remembered.
///
/// Defaults to remembering nothing, and main() overrides it with the Hive
/// store. Persistence is opt-in rather than opt-out because a store reached
/// by default drags a real database into every test that so much as reads the
/// launch state — and Hive reports a missing box to the zone as well as to
/// its caller, so it cannot even be caught at the call site.
final loadoutStoreProvider = Provider<LoadoutStore>(
  (ref) => const NoLoadoutStore(),
);

/// Remembers the bench between runs.
abstract class LoadoutStore {
  Future<void> save(SavedLoadout loadout);
  Future<SavedLoadout?> read();
  Future<void> clear();
}

/// Forgets everything, which is what a test wants unless it says otherwise.
class NoLoadoutStore implements LoadoutStore {
  const NoLoadoutStore();

  @override
  Future<void> save(SavedLoadout loadout) async {}

  @override
  Future<SavedLoadout?> read() async => null;

  @override
  Future<void> clear() async {}
}

/// What was on the bench when the app last closed.
///
/// Stored as a plain map rather than a typed adapter, like the rest of this
/// app's persistence, so adding a field later cannot strand an existing box.
/// The port and IWAD are kept by id and resolved against their own boxes on
/// the way back, so one the user has since deleted simply does not return
/// rather than reappearing as a dead entry.
class HiveLoadoutStore implements LoadoutStore {
  static const String _key = 'last_loadout';

  final String boxName;

  const HiveLoadoutStore({this.boxName = AppConstants.hiveBoxName});

  Future<Box<dynamic>> _box() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box<dynamic>(boxName);
    return Hive.openBox<dynamic>(boxName);
  }

  @override
  Future<void> save(SavedLoadout loadout) async {
    final box = await _box();
    await box.put(_key, loadout.toMap());
  }

  @override
  Future<SavedLoadout?> read() async {
    final box = await _box();
    final raw = box.get(_key);
    if (raw is! Map) return null;
    return SavedLoadout.fromMap(raw);
  }

  @override
  Future<void> clear() async {
    final box = await _box();
    await box.delete(_key);
  }
}

class SavedLoadout {
  final String? sourcePortId;
  final String? iwadId;
  final List<Pwad> pwads;
  final String customArgs;
  final GameplayOptions gameplay;

  const SavedLoadout({
    this.sourcePortId,
    this.iwadId,
    this.pwads = const [],
    this.customArgs = '',
    this.gameplay = const GameplayOptions(),
  });

  Map<String, dynamic> toMap() => {
        'sourcePortId': sourcePortId,
        'iwadId': iwadId,
        'customArgs': customArgs,
        'gameplay': gameplay.toMap(),
        'pwads': [
          for (final p in pwads)
            {
              'id': p.id,
              'path': p.path,
              'isEnabled': p.isEnabled,
              'loadOrder': p.loadOrder,
            },
        ],
      };

  static SavedLoadout fromMap(Map<dynamic, dynamic> map) {
    final rawPwads = map['pwads'];
    final gameplay = map['gameplay'];

    return SavedLoadout(
      sourcePortId: map['sourcePortId'] as String?,
      iwadId: map['iwadId'] as String?,
      customArgs: map['customArgs'] as String? ?? '',
      gameplay: gameplay is Map
          ? GameplayOptions.fromMap(gameplay)
          : const GameplayOptions(),
      pwads: rawPwads is List
          ? [
              for (var i = 0; i < rawPwads.length; i++)
                if (rawPwads[i] is Map && rawPwads[i]['path'] is String)
                  Pwad(
                    id: rawPwads[i]['id'] as String? ?? 'restored-$i',
                    path: rawPwads[i]['path'] as String,
                    isEnabled: rawPwads[i]['isEnabled'] as bool? ?? true,
                    loadOrder: rawPwads[i]['loadOrder'] as int? ?? i,
                  ),
            ]
          : const [],
    );
  }
}
