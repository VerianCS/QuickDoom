import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quickdoom/domain/entities/gameplay_options.dart';
import 'package:quickdoom/domain/entities/pwad.dart';
import 'package:quickdoom/features/launcher/data/loadout_store.dart';

void main() {
  late Directory dir;
  const store = HiveLoadoutStore(boxName: 'loadout_test');

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('qd_loadout');
    Hive.init(dir.path);
    await Hive.openBox<dynamic>('loadout_test');
  });

  tearDown(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  test('nothing saved reads as null rather than an empty bench', () async {
    expect(await store.read(), isNull);
  });

  test('a full bench survives a round trip', () async {
    await store.save(SavedLoadout(
      sourcePortId: 'port-1',
      iwadId: 'iwad-1',
      customArgs: '-config "my file.ini"',
      gameplay: const GameplayOptions(skill: Skill.ultraViolence, fast: true),
      pwads: [
        Pwad(id: 'a', path: '/mods/a.wad', loadOrder: 0),
        Pwad(id: 'b', path: '/mods/b.wad', isEnabled: false, loadOrder: 1),
      ],
    ));

    final read = await store.read()!;
    expect(read!.sourcePortId, 'port-1');
    expect(read.iwadId, 'iwad-1');
    expect(read.customArgs, '-config "my file.ini"');
    expect(read.gameplay.skill, Skill.ultraViolence);
    expect(read.gameplay.fast, isTrue);
    expect(read.pwads.map((p) => p.path), ['/mods/a.wad', '/mods/b.wad']);
  });

  // Load order is the whole meaning of the rail, so it has to come back in
  // the same order, with the same rows switched off.
  test('load order and the enabled flags come back intact', () async {
    await store.save(SavedLoadout(pwads: [
      Pwad(id: 'a', path: '/a.wad', loadOrder: 0),
      Pwad(id: 'b', path: '/b.wad', isEnabled: false, loadOrder: 1),
      Pwad(id: 'c', path: '/c.wad', loadOrder: 2),
    ]));

    final read = (await store.read())!;
    expect(read.pwads.map((p) => p.loadOrder), [0, 1, 2]);
    expect(read.pwads.map((p) => p.isEnabled), [true, false, true]);
  });

  test('an empty bench round trips as empty', () async {
    await store.save(const SavedLoadout());
    final read = (await store.read())!;

    expect(read.sourcePortId, isNull);
    expect(read.pwads, isEmpty);
    expect(read.gameplay.isDefault, isTrue);
  });

  // A box written by an older build will not have the newer keys, and a
  // launcher that throws on startup because of that is worse than one that
  // forgets a setting.
  test('a partial record from an older build still reads', () async {
    final box = Hive.box<dynamic>('loadout_test');
    await box.put('last_loadout', {'sourcePortId': 'port-1'});

    final read = (await store.read())!;
    expect(read.sourcePortId, 'port-1');
    expect(read.pwads, isEmpty);
    expect(read.customArgs, '');
  });

  test('a junk record reads as nothing saved', () async {
    final box = Hive.box<dynamic>('loadout_test');
    await box.put('last_loadout', 'not a map');

    expect(await store.read(), isNull);
  });

  test('a pwad entry with no path is skipped, not restored as empty', () async {
    final box = Hive.box<dynamic>('loadout_test');
    await box.put('last_loadout', {
      'pwads': [
        {'id': 'a', 'path': '/a.wad'},
        {'id': 'b'},
      ],
    });

    final read = (await store.read())!;
    expect(read.pwads.map((p) => p.path), ['/a.wad']);
  });

  test('clear forgets the bench', () async {
    await store.save(const SavedLoadout(sourcePortId: 'p'));
    await store.clear();
    expect(await store.read(), isNull);
  });
}
