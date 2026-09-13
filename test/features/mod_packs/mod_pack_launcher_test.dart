import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quickdoom/data/models/iwad_model.dart';
import 'package:quickdoom/data/models/launch_profile_model.dart';
import 'package:quickdoom/data/models/pwad_model.dart';
import 'package:quickdoom/data/models/source_port_model.dart';
import 'package:quickdoom/domain/entities/iwad.dart';
import 'package:quickdoom/domain/entities/source_port.dart';
import 'package:quickdoom/features/iwads/presentation/providers/iwad_provider.dart';
import 'package:quickdoom/features/launcher/presentation/providers/launch_provider.dart';
import 'package:quickdoom/features/library/domain/entities/installed_mod.dart';
import 'package:quickdoom/features/library/presentation/providers/mod_library_provider.dart';
import 'package:quickdoom/features/mod_packs/domain/entities/mod_pack.dart';
import 'package:quickdoom/features/mod_packs/presentation/providers/mod_pack_launcher.dart';
import 'package:quickdoom/features/source_ports/presentation/providers/source_port_provider.dart';

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('quickdoom_packlaunch_');
    Hive.init(temp.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SourcePortModelAdapter());
      Hive.registerAdapter(IwadModelAdapter());
      Hive.registerAdapter(PwadModelAdapter());
      Hive.registerAdapter(LaunchProfileModelAdapter());
    }
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

  InstalledMod installed(String id, List<String> files) => InstalledMod(
        id: id,
        name: 'Mod $id',
        installDir: '/lib/$id',
        files: files,
        installedAt: DateTime(2024),
      );

  test('loads engine, IWAD and ordered pwads into the launcher', () async {
    final container = makeContainer();

    await container.read(sourcePortListProvider.notifier).save(
          const SourcePort(
            id: 'port-1',
            name: 'GZDoom',
            executablePath: '/bin/gzdoom',
          ),
        );
    await container.read(iwadListProvider.notifier).save(
          const Iwad(id: 'iwad-1', name: 'DOOM2', path: '/wads/doom2.wad'),
        );

    final library = container.read(modLibraryProvider.notifier);
    await library.add(installed('a', ['/lib/a/a.wad', '/lib/a/a.deh']));
    await library.add(installed('b', ['/lib/b/b.pk3']));

    const pack = ModPack(
      id: 'pack-1',
      name: 'My Pack',
      entries: [
        ModPackEntry(modId: 'a'),
        ModPackEntry(modId: 'b', isEnabled: false),
      ],
      iwadId: 'iwad-1',
      engineId: 'port-1',
    );

    final result =
        await container.read(modPackLauncherProvider).loadIntoLauncher(pack);

    expect(result.fileCount, 3);
    expect(result.missingMods, 0);
    expect(result.engineResolved, isTrue);
    expect(result.iwadResolved, isTrue);
    expect(result.warning, isNull);

    final state = container.read(launchNotifierProvider);
    expect(state.sourcePort?.id, 'port-1');
    expect(state.iwad?.id, 'iwad-1');
    expect(state.pwads.map((p) => p.path), [
      '/lib/a/a.wad',
      '/lib/a/a.deh',
      '/lib/b/b.pk3',
    ]);
    expect(state.pwads.map((p) => p.loadOrder), [0, 1, 2]);
    expect(state.pwads.last.isEnabled, isFalse,
        reason: 'a disabled entry stays disabled in the launcher');
    expect(state.canLaunch, isTrue);
  });

  test('reports mods that are no longer installed', () async {
    final container = makeContainer();
    await container
        .read(modLibraryProvider.notifier)
        .add(installed('a', ['/lib/a/a.wad']));

    const pack = ModPack(
      id: 'pack-2',
      name: 'Partly Missing',
      entries: [
        ModPackEntry(modId: 'a'),
        ModPackEntry(modId: 'gone'),
      ],
    );

    final result =
        await container.read(modPackLauncherProvider).loadIntoLauncher(pack);

    expect(result.fileCount, 1);
    expect(result.missingMods, 1);
    expect(result.warning, contains('1 mod missing'));
    expect(container.read(launchNotifierProvider).pwads, hasLength(1));
  });

  test('an unset engine and IWAD are reported, not invented', () async {
    final container = makeContainer();

    const pack = ModPack(id: 'pack-3', name: 'Bare');
    final result =
        await container.read(modPackLauncherProvider).loadIntoLauncher(pack);

    expect(result.engineResolved, isFalse);
    expect(result.iwadResolved, isFalse);
    expect(result.warning, contains('no engine set'));
    expect(result.warning, contains('no IWAD set'));

    final state = container.read(launchNotifierProvider);
    expect(state.sourcePort, isNull);
    expect(state.iwad, isNull);
    expect(state.canLaunch, isFalse);
  });

  test('an engine id that no longer exists does not resolve', () async {
    final container = makeContainer();

    const pack = ModPack(id: 'pack-4', name: 'Stale', engineId: 'deleted');
    final result =
        await container.read(modPackLauncherProvider).loadIntoLauncher(pack);

    expect(result.engineResolved, isFalse);
    expect(container.read(launchNotifierProvider).sourcePort, isNull);
  });
}
