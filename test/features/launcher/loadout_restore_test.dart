import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quickdoom/domain/entities/gameplay_options.dart';
import 'package:quickdoom/domain/entities/iwad.dart';
import 'package:quickdoom/domain/entities/pwad.dart';
import 'package:quickdoom/domain/entities/source_port.dart';
import 'package:quickdoom/domain/entities/warp_target.dart';
import 'package:quickdoom/features/launcher/data/loadout_store.dart';
import 'package:quickdoom/features/launcher/presentation/providers/launch_provider.dart';

/// Stands in for Hive, so these tests are about the wiring and nothing else.
class FakeLoadoutStore implements LoadoutStore {
  SavedLoadout? saved;
  int writes = 0;

  @override
  Future<void> save(SavedLoadout loadout) async {
    saved = loadout;
    writes++;
  }

  @override
  Future<SavedLoadout?> read() async => saved;

  @override
  Future<void> clear() async => saved = null;
}

const _port = SourcePort(id: 'p1', name: 'gzdoom', executablePath: '/opt/gz');
const _iwad = Iwad(id: 'i1', name: 'doom2.wad', path: '/wads/doom2.wad');

void main() {
  late FakeLoadoutStore store;
  late ProviderContainer container;

  setUp(() {
    store = FakeLoadoutStore();
    container = ProviderContainer(
      overrides: [loadoutStoreProvider.overrideWithValue(store)],
    );
    container.listen(launchNotifierProvider, (_, _) {}, fireImmediately: true);
  });
  tearDown(() => container.dispose());

  LaunchNotifier notifier() =>
      container.read(launchNotifierProvider.notifier);
  LaunchState state() => container.read(launchNotifierProvider);

  group('persisting', () {
    // listenSelf fires once when the provider mounts, carrying the empty
    // initial state. Persisting that overwrote the saved bench before
    // restore() could read it, so every restart came back empty.
    test('mounting alone never writes over the saved bench', () async {
      container.read(launchNotifierProvider);
      await Future<void>.delayed(Duration.zero);

      expect(store.writes, 0);
    });

    test('a change before restore does not write either', () async {
      notifier().setSourcePort(_port);
      await Future<void>.delayed(Duration.zero);

      expect(store.writes, 0);
    });

    test('every change writes the bench once it has been read back', () async {
      await notifier().restore();
      notifier().setSourcePort(_port);
      await Future<void>.delayed(Duration.zero);

      expect(store.saved?.sourcePortId, 'p1');
    });

    test('the load order is written with it', () async {
      await notifier().restore();
      notifier().addPwads([Pwad(id: 'a', path: '/mods/a.wad')]);
      await Future<void>.delayed(Duration.zero);

      expect(store.saved?.pwads.single.path, '/mods/a.wad');
    });

    test('gameplay options are written', () async {
      await notifier().restore();
      notifier().setGameplay(const GameplayOptions(skill: Skill.nightmare));
      await Future<void>.delayed(Duration.zero);

      expect(store.saved?.gameplay.skill, Skill.nightmare);
    });
  });

  group('restoring', () {
    setUp(() async {
      // The repositories open their own boxes with their own types; opening
      // them here as Box<dynamic> first is what makes Hive refuse them.
      Hive.init('test/temp_restore_${DateTime.now().microsecondsSinceEpoch}');
    });

    tearDown(() async => Hive.deleteFromDisk());

    test('an empty store leaves an empty bench', () async {
      await notifier().restore();

      expect(state().sourcePort, isNull);
      expect(state().iwad, isNull);
    });

    test('mods, args and gameplay come back', () async {
      store.saved = SavedLoadout(
        customArgs: '-config "my file.ini"',
        gameplay: const GameplayOptions(skill: Skill.ultraViolence),
        pwads: [Pwad(id: 'a', path: '/mods/a.wad', loadOrder: 0)],
      );

      await notifier().restore();

      expect(state().customArgs, '-config "my file.ini"');
      expect(state().gameplay.skill, Skill.ultraViolence);
      expect(state().pwads.single.path, '/mods/a.wad');
    });

    // A port the user deleted since must not come back as a dead entry
    // pointing at an id that no longer resolves.
    test('a port that no longer exists does not return', () async {
      store.saved = const SavedLoadout(sourcePortId: 'deleted-port');

      await notifier().restore();

      expect(state().sourcePort, isNull);
    });

    // Warping is an intent for one launch; silently starting on MAP14 days
    // later because that is where you were last looking would be a surprise.
    // It is never written, so a later session cannot inherit one.
    test('a warp target is never written to the store', () async {
      await notifier().restore();
      notifier().setWarp(const WarpTarget(mapName: 'MAP14'));
      await Future<void>.delayed(Duration.zero);

      final fresh = ProviderContainer(
        overrides: [loadoutStoreProvider.overrideWithValue(store)],
      );
      addTearDown(fresh.dispose);
      await fresh.read(launchNotifierProvider.notifier).restore();

      expect(fresh.read(launchNotifierProvider).warp, isNull);
    });

    test('restoring does not immediately re-save what it just read', () async {
      store.saved = const SavedLoadout(customArgs: '-fast');
      store.writes = 0;

      await notifier().restore();
      await Future<void>.delayed(Duration.zero);

      expect(store.writes, 0);
    });
  });

  test('an unseated bench and a restored one agree on canLaunch', () async {
    store.saved = const SavedLoadout(sourcePortId: 'p1', iwadId: 'i1');
    await notifier().restore();

    expect(state().canLaunch, isFalse,
        reason: 'neither id resolves, so nothing is seated');
    expect(_port.id, 'p1');
    expect(_iwad.id, 'i1');
  });
}
