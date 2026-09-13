import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quickdoom/core/services/install_service.dart';

void main() {
  late Directory temp;
  late InstallService service;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('quickdoom_install_');
    service = InstallService();
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  String writeZip(String name, Map<String, List<int>> entries) {
    final archive = Archive();
    entries.forEach((path, bytes) {
      archive.add(ArchiveFile.bytes(path, bytes));
    });

    final encoded = ZipEncoder().encode(archive);
    final path = p.join(temp.path, name);
    File(path).writeAsBytesSync(encoded);
    return path;
  }

  String dest(String name) => p.join(temp.path, 'out_$name');

  group('install', () {
    test('extracts a zip and reports loadable files', () async {
      final zip = writeZip('mod.zip', {
        'MYMAP.wad': [1, 2, 3, 4],
        'readme.txt': [5, 6],
        'patch.deh': [7],
      });

      final result = await service.install(zip, destDir: dest('a'));

      expect(result.loadableFiles.map(p.basename), ['MYMAP.wad', 'patch.deh']);
      expect(File(p.join(result.installDir, 'readme.txt')).existsSync(), isTrue);
      expect(result.sizeBytes, 7);
    });

    test('orders content files before patches', () async {
      final zip = writeZip('ordered.zip', {
        'zpatch.deh': [1],
        'amap.wad': [2],
        'bmod.pk3': [3],
      });

      final result = await service.install(zip, destDir: dest('b'));

      expect(
        result.loadableFiles.map(p.basename),
        ['amap.wad', 'bmod.pk3', 'zpatch.deh'],
      );
    });

    test('copies a loose wad without extracting it', () async {
      final wad = p.join(temp.path, 'loose.wad');
      File(wad).writeAsBytesSync([9, 9, 9]);

      final result = await service.install(wad, destDir: dest('c'));

      expect(result.loadableFiles, hasLength(1));
      expect(p.basename(result.loadableFiles.single), 'loose.wad');
      expect(File(result.loadableFiles.single).readAsBytesSync(), [9, 9, 9]);
    });

    test('keeps a pk3 packed even though it is a zip', () async {
      // A pk3 is a zip, but the source port loads it as a container.
      final archive = Archive()
        ..add(ArchiveFile.bytes('maps/MAP01.wad', [1, 2]));
      final pk3 = p.join(temp.path, 'mod.pk3');
      File(pk3).writeAsBytesSync(ZipEncoder().encode(archive));

      final result = await service.install(pk3, destDir: dest('d'));

      expect(result.loadableFiles, hasLength(1));
      expect(p.basename(result.loadableFiles.single), 'mod.pk3');
      expect(
        Directory(result.installDir).listSync().whereType<Directory>(),
        isEmpty,
        reason: 'the pk3 must not have been unpacked',
      );
    });

    test('detects zips that have no .zip extension', () async {
      final archive = Archive()..add(ArchiveFile.bytes('doom.wad', [4, 2]));
      final blob = p.join(temp.path, 'release-asset');
      File(blob).writeAsBytesSync(ZipEncoder().encode(archive));

      final result = await service.install(blob, destDir: dest('e'));

      expect(result.loadableFiles.map(p.basename), ['doom.wad']);
    });

    test('rejects entries that escape the destination (zip slip)', () async {
      final zip = writeZip('evil.zip', {
        '../../escaped.wad': [1],
        'safe.wad': [2],
      });

      final result = await service.install(zip, destDir: dest('f'));

      expect(result.loadableFiles.map(p.basename), ['safe.wad']);
      expect(
        File(p.join(temp.path, 'escaped.wad')).existsSync(),
        isFalse,
        reason: 'the traversing entry must not be written outside destDir',
      );
    });

    test('throws when the file is neither a zip nor loadable', () async {
      final junk = p.join(temp.path, 'notes.txt');
      File(junk).writeAsStringSync('hello');

      expect(
        () => service.install(junk, destDir: dest('g')),
        throwsA(isA<InstallException>()),
      );
    });

    test('throws when the archive is missing', () async {
      expect(
        () => service.install(p.join(temp.path, 'nope.zip'), destDir: dest('h')),
        throwsA(isA<InstallException>()),
      );
    });
  });

  group('executables', () {
    test('ranks the name matching the repo first', () async {
      final zip = writeZip('engine.zip', {
        'tools/helper': [1],
        'gzdoom': [2],
        'libstuff.so': [3],
      });

      final result = await service.install(
        zip,
        destDir: dest('i'),
        preferredExecutableName: 'gzdoom',
      );

      expect(p.basename(result.executables.first), 'gzdoom');
    });

    test('treats .exe as executable and skips licence files', () {
      expect(InstallService.isExecutableCandidate('/x/gzdoom.exe'), isTrue);
      expect(InstallService.isExecutableCandidate('/x/game.AppImage'), isTrue);
      expect(InstallService.isExecutableCandidate('/x/woof'), isTrue);
      expect(InstallService.isExecutableCandidate('/x/LICENSE'), isFalse);
      expect(InstallService.isExecutableCandidate('/x/notes.txt'), isFalse);
    });
  });

  test('looksLikeZip reads the PK header', () {
    expect(
      InstallService.looksLikeZip(Uint8List.fromList([0x50, 0x4B, 0x03, 0x04])),
      isTrue,
    );
    expect(InstallService.looksLikeZip(Uint8List.fromList([1, 2, 3, 4])), isFalse);
    expect(InstallService.looksLikeZip(Uint8List.fromList([0x50])), isFalse);
  });
}
