import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:quickdoom/core/services/library_paths.dart';
import 'package:quickdoom/features/library/data/repositories/mod_library_store.dart';
import 'package:quickdoom/features/library/domain/entities/installed_mod.dart';

void main() {
  late Directory temp;
  late ModLibraryStore store;

  InstalledMod mod(String id, {String dir = '', List<String> files = const []}) {
    return InstalledMod(
      id: id,
      name: 'Mod $id',
      installDir: dir,
      files: files,
      author: 'Tester',
      sizeBytes: 2048,
      installedAt: DateTime(2024, 1, 1),
    );
  }

  setUp(() {
    temp = Directory.systemTemp.createTempSync('quickdoom_library_');
    Hive.init(temp.path);
    store = ModLibraryStore();
  });

  tearDown(() async {
    await Hive.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('saves and reads back a mod', () async {
    await store.save(mod('a', files: ['/x/a.wad']));

    final all = await store.getAll();
    expect(all, hasLength(1));
    expect(all.single.id, 'a');
    expect(all.single.files, ['/x/a.wad']);
    expect(all.single.sizeFormatted, '2.0 KB');
  });

  test('saving the same id updates rather than duplicates', () async {
    await store.save(mod('a'));
    await store.save(mod('a').copyWith(name: 'Renamed'));

    final all = await store.getAll();
    expect(all, hasLength(1));
    expect(all.single.name, 'Renamed');
  });

  test('delete removes the entry but leaves files alone', () async {
    final dir = Directory(p.join(temp.path, 'mods', 'a'))
      ..createSync(recursive: true);
    final file = File(p.join(dir.path, 'a.wad'))..writeAsStringSync('x');

    await store.save(mod('a', dir: dir.path, files: [file.path]));
    await store.delete('a');

    expect(await store.getAll(), isEmpty);
    expect(file.existsSync(), isTrue);
  });

  test('deleteWithFiles removes the install directory', () async {
    final modsRoot = p.join(temp.path, 'mods');
    final dir = Directory(p.join(modsRoot, 'a'))..createSync(recursive: true);
    File(p.join(dir.path, 'a.wad')).writeAsStringSync('x');

    await store.save(mod('a', dir: dir.path));
    await store.deleteWithFiles('a', libraryRoot: modsRoot);

    expect(await store.getAll(), isEmpty);
    expect(dir.existsSync(), isFalse);
  });

  test('deleteWithFiles refuses to delete the library root itself', () async {
    final modsRoot = p.join(temp.path, 'mods');
    Directory(modsRoot).createSync(recursive: true);

    // A malformed row pointing at the root must not take the library with it.
    await store.save(mod('a', dir: modsRoot));
    await store.deleteWithFiles('a', libraryRoot: modsRoot);

    expect(await store.getAll(), isEmpty);
    expect(Directory(modsRoot).existsSync(), isTrue);
  });

  test('a sibling directory sharing the root prefix is left alone', () async {
    final modsRoot = p.join(temp.path, 'mods');
    // "<root>2" starts with "<root>" as a string but is a different directory.
    final sibling = Directory('${modsRoot}2')..createSync(recursive: true);
    File(p.join(sibling.path, 'keep.wad')).writeAsStringSync('x');

    await store.save(mod('a', dir: sibling.path));
    await store.deleteWithFiles('a', libraryRoot: modsRoot);

    expect(await store.getAll(), isEmpty);
    expect(sibling.existsSync(), isTrue);
  });

  test('rows without an id are skipped', () {
    expect(ModLibraryStore.fromMap({'name': 'no id'}), isNull);
    expect(ModLibraryStore.fromMap({'id': '', 'name': 'blank'}), isNull);
  });

  test('map round-trip preserves fields', () {
    final original = mod('a', dir: '/d', files: ['/d/a.wad', '/d/a.deh'])
        .copyWith(idgamesId: 77);

    final restored = ModLibraryStore.fromMap(ModLibraryStore.toMap(original))!;

    expect(restored.id, 'a');
    expect(restored.idgamesId, 77);
    expect(restored.files, ['/d/a.wad', '/d/a.deh']);
    expect(restored.primaryFileName, 'a.wad');
    expect(restored.installedAt, DateTime(2024, 1, 1));
  });

  group('LibraryPaths', () {
    test('sanitize makes release tags safe as a path segment', () {
      expect(LibraryPaths.sanitize('g4.12.0'), 'g4.12.0');
      expect(LibraryPaths.sanitize('release/2024'), 'release_2024');
      expect(LibraryPaths.sanitize('../../etc'), 'etc');
      expect(LibraryPaths.sanitize(''), 'untitled');
      expect(LibraryPaths.sanitize('...'), 'untitled');
    });

    test('directories are created under the injected root', () async {
      final paths = LibraryPaths(rootResolver: () async => temp.path);

      final engineDir = await paths.engineDir('gzdoom', 'g4.12/beta');

      expect(Directory(engineDir).existsSync(), isTrue);
      expect(p.basename(engineDir), 'g4.12_beta');
      expect(p.isWithin(temp.path, engineDir), isTrue);
    });
  });
}
