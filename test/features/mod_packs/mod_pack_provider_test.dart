import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quickdoom/features/mod_packs/domain/entities/mod_pack.dart';
import 'package:quickdoom/features/mod_packs/presentation/providers/mod_pack_provider.dart';

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('quickdoom_packs_');
    Hive.init(temp.path);
  });

  tearDown(() async {
    await Hive.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  Future<ModPack> firstPack(ProviderContainer container) async {
    final packs = await container.read(modPackListProvider.future);
    return packs.first;
  }

  group('persistence', () {
    test('created packs survive a reload', () async {
      final container = makeContainer();
      await container.read(modPackListProvider.notifier).create('Slaughter');

      final reloaded = makeContainer();
      final packs = await reloaded.read(modPackListProvider.future);
      expect(packs.map((p) => p.name), ['Slaughter']);
    });

    test('entries round-trip through storage', () async {
      final container = makeContainer();
      final notifier = container.read(modPackListProvider.notifier);

      await notifier.create('Pack');
      final pack = await firstPack(container);
      await notifier.addMods(pack.id, ['mod-a', 'mod-b']);
      await notifier.toggleMod(pack.id, 'mod-b');

      final reloaded = await firstPack(makeContainer());
      expect(reloaded.entries.map((e) => e.modId), ['mod-a', 'mod-b']);
      expect(reloaded.entries[0].isEnabled, isTrue);
      expect(reloaded.entries[1].isEnabled, isFalse);
      expect(reloaded.enabledCount, 1);
    });
  });

  group('editing', () {
    test('addMods skips mods already in the pack', () async {
      final container = makeContainer();
      final notifier = container.read(modPackListProvider.notifier);

      await notifier.create('Pack');
      final pack = await firstPack(container);
      await notifier.addMods(pack.id, ['a', 'b']);
      await notifier.addMods(pack.id, ['b', 'c']);

      expect((await firstPack(container)).entries.map((e) => e.modId),
          ['a', 'b', 'c']);
    });

    test('removeMod drops only the named entry', () async {
      final container = makeContainer();
      final notifier = container.read(modPackListProvider.notifier);

      await notifier.create('Pack');
      final pack = await firstPack(container);
      await notifier.addMods(pack.id, ['a', 'b', 'c']);
      await notifier.removeMod(pack.id, 'b');

      expect((await firstPack(container)).entries.map((e) => e.modId),
          ['a', 'c']);
    });

    test('reorder moves an entry down, accounting for the removed slot',
        () async {
      final container = makeContainer();
      final notifier = container.read(modPackListProvider.notifier);

      await notifier.create('Pack');
      final pack = await firstPack(container);
      await notifier.addMods(pack.id, ['a', 'b', 'c']);

      // ReorderableListView reports newIndex before the item is removed.
      await notifier.reorder(pack.id, 0, 3);

      expect((await firstPack(container)).entries.map((e) => e.modId),
          ['b', 'c', 'a']);
    });

    test('reorder moves an entry up', () async {
      final container = makeContainer();
      final notifier = container.read(modPackListProvider.notifier);

      await notifier.create('Pack');
      final pack = await firstPack(container);
      await notifier.addMods(pack.id, ['a', 'b', 'c']);
      await notifier.reorder(pack.id, 2, 0);

      expect((await firstPack(container)).entries.map((e) => e.modId),
          ['c', 'a', 'b']);
    });

    test('reorder ignores an out-of-range index', () async {
      final container = makeContainer();
      final notifier = container.read(modPackListProvider.notifier);

      await notifier.create('Pack');
      final pack = await firstPack(container);
      await notifier.addMods(pack.id, ['a', 'b']);
      await notifier.reorder(pack.id, 9, 0);

      expect((await firstPack(container)).entries.map((e) => e.modId),
          ['a', 'b']);
    });
  });

  group('legacy rows', () {
    test('a pre-library pack loads without its placeholder modIds', () {
      // Packs written before the library stored ints that referenced nothing.
      final pack = packFromMap({
        'id': 'p1',
        'name': 'Old Pack',
        'description': 'from before',
        'modIds': [1, 2, 3],
        'iwadId': 'iwad-1',
        'engineId': 'engine-1',
      });

      expect(pack.id, 'p1');
      expect(pack.name, 'Old Pack');
      expect(pack.description, 'from before');
      expect(pack.entries, isEmpty);
      expect(pack.iwadId, 'iwad-1');
      expect(pack.engineId, 'engine-1');
    });

    test('malformed entries are skipped rather than throwing', () {
      final pack = packFromMap({
        'id': 'p2',
        'name': 'Mixed',
        'entries': [
          {'modId': 'good', 'isEnabled': false},
          {'isEnabled': true},
          {'modId': ''},
          'nonsense',
        ],
      });

      expect(pack.entries, hasLength(1));
      expect(pack.entries.single.modId, 'good');
      expect(pack.entries.single.isEnabled, isFalse);
    });

    test('packToMap and packFromMap round-trip', () {
      const original = ModPack(
        id: 'p3',
        name: 'Round Trip',
        entries: [
          ModPackEntry(modId: 'a'),
          ModPackEntry(modId: 'b', isEnabled: false),
        ],
        iwadId: 'i',
        engineId: 'e',
      );

      final restored = packFromMap(packToMap(original));

      expect(restored.name, original.name);
      expect(restored.entries.map((e) => e.modId), ['a', 'b']);
      expect(restored.entries[1].isEnabled, isFalse);
      expect(restored.iwadId, 'i');
      expect(restored.engineId, 'e');
    });
  });
}
