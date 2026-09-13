import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quickdoom/core/services/download_service.dart';
import 'package:quickdoom/core/services/install_service.dart';
import 'package:quickdoom/core/services/library_paths.dart';
import 'package:quickdoom/features/downloads/domain/download_task.dart';
import 'package:quickdoom/features/downloads/presentation/providers/download_queue_provider.dart';
import 'package:quickdoom/features/library/presentation/providers/mod_library_provider.dart';
import 'package:quickdoom/features/mod_browser/domain/entities/mod_file.dart';

/// Emits a fixed progress sequence, or fails partway through.
class _FakeDownloadService extends DownloadService {
  final int chunks;
  final int total;
  final Object? failWith;

  _FakeDownloadService({this.chunks = 4, this.total = 400, this.failWith});

  @override
  Stream<DownloadProgress> download(String url, String destPath) async* {
    for (var i = 1; i <= chunks; i++) {
      if (failWith != null && i == 2) throw failWith!;
      yield DownloadProgress(
        receivedBytes: (total ~/ chunks) * i,
        totalBytes: total,
      );
    }
  }
}

class _FakeInstallService extends InstallService {
  final InstallResult? result;
  final Object? failWith;

  _FakeInstallService({this.result, this.failWith});

  @override
  Future<InstallResult> install(
    String archivePath, {
    required String destDir,
    String? preferredExecutableName,
  }) async {
    if (failWith != null) throw failWith!;
    return result ??
        InstallResult(
          installDir: destDir,
          loadableFiles: ['$destDir/MYMAP.wad'],
          sizeBytes: 400,
        );
  }
}

ModFile _mod({int id = 42}) => ModFile(
      id: id,
      title: 'Test Mod',
      filename: 'testmod.zip',
      author: 'Tester',
      description: '',
      size: 400,
      rating: 4.5,
      votes: 10,
      downloadUrl: 'https://example.invalid/testmod.zip',
      uploadDate: DateTime(2020),
      dir: 'levels/doom2/',
    );

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('quickdoom_queue_');
    Hive.init(temp.path);
  });

  tearDown(() async {
    await Hive.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  ProviderContainer containerWith({
    DownloadService? download,
    InstallService? install,
  }) {
    final container = ProviderContainer(overrides: [
      downloadServiceProvider.overrideWithValue(download ?? _FakeDownloadService()),
      installServiceProvider.overrideWithValue(install ?? _FakeInstallService()),
      // Keep every path under the test's temp directory.
      libraryPathsProvider.overrideWithValue(
        LibraryPaths(rootResolver: () async => temp.path),
      ),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('a finished mod download lands in the library', () async {
    final container = containerWith();
    final mod = _mod();

    await container.read(downloadQueueProvider.notifier).downloadMod(mod);

    final task = container.read(downloadQueueProvider)[DownloadTask.modKey(42)];
    expect(task, isNotNull);
    expect(task!.stage, DownloadStage.done);
    expect(task.fraction, 1.0);

    final library = await container.read(modLibraryProvider.future);
    expect(library, hasLength(1));
    expect(library.single.name, 'Test Mod');
    expect(library.single.idgamesId, 42);
    expect(library.single.files.single, endsWith('MYMAP.wad'));
  });

  test('progress updates are reported as bytes arrive', () async {
    final container = containerWith(
      download: _FakeDownloadService(chunks: 2, total: 200),
    );

    await container.read(downloadQueueProvider.notifier).downloadMod(_mod());

    final task = container.read(downloadQueueProvider)[DownloadTask.modKey(42)]!;
    expect(task.totalBytes, 200);
    expect(task.receivedBytes, 200);
  });

  test('a transfer failure marks the task failed and skips the library',
      () async {
    final container = containerWith(
      download: _FakeDownloadService(failWith: const DownloadException('boom')),
    );

    await container.read(downloadQueueProvider.notifier).downloadMod(_mod());

    final task = container.read(downloadQueueProvider)[DownloadTask.modKey(42)]!;
    expect(task.stage, DownloadStage.failed);
    expect(task.error, 'boom');

    expect(await container.read(modLibraryProvider.future), isEmpty);
  });

  test('an install failure surfaces the installer message', () async {
    final container = containerWith(
      install: _FakeInstallService(failWith: const InstallException('no wads')),
    );

    await container.read(downloadQueueProvider.notifier).downloadMod(_mod());

    final task = container.read(downloadQueueProvider)[DownloadTask.modKey(42)]!;
    expect(task.stage, DownloadStage.failed);
    expect(task.error, 'no wads');
  });

  test('an archive with no loadable files is rejected', () async {
    final container = containerWith(
      install: _FakeInstallService(
        result: const InstallResult(installDir: '/tmp/x', loadableFiles: []),
      ),
    );

    await container.read(downloadQueueProvider.notifier).downloadMod(_mod());

    final task = container.read(downloadQueueProvider)[DownloadTask.modKey(42)]!;
    expect(task.stage, DownloadStage.failed);
    expect(task.error, contains('No .wad or .pk3'));
  });

  test('dismiss clears a finished task but leaves active ones alone', () async {
    final container = containerWith();
    final notifier = container.read(downloadQueueProvider.notifier);

    await notifier.downloadMod(_mod());
    expect(container.read(downloadQueueProvider), hasLength(1));

    notifier.dismiss(DownloadTask.modKey(42));
    expect(container.read(downloadQueueProvider), isEmpty);
  });

  test('task keys are distinct per target', () {
    expect(DownloadTask.modKey(1), isNot(DownloadTask.modKey(2)));
    expect(
      DownloadTask.engineKey('gzdoom', 'g4.12', 'a.zip'),
      isNot(DownloadTask.engineKey('gzdoom', 'g4.12', 'b.zip')),
    );
  });

  group('DownloadTask', () {
    test('reports an indeterminate fraction without a total', () {
      const task = DownloadTask(
        id: 'x',
        label: 'x',
        stage: DownloadStage.downloading,
        receivedBytes: 10,
      );
      expect(task.fraction, isNull);
      expect(task.progressLabel, '10 B');
    });

    test('clamps the fraction when the server undercounts', () {
      const task = DownloadTask(
        id: 'x',
        label: 'x',
        stage: DownloadStage.downloading,
        receivedBytes: 300,
        totalBytes: 200,
      );
      expect(task.fraction, 1.0);
    });
  });
}
