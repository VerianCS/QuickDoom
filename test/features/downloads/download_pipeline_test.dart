import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:quickdoom/core/services/library_paths.dart';
import 'package:quickdoom/data/models/iwad_model.dart';
import 'package:quickdoom/data/models/launch_profile_model.dart';
import 'package:quickdoom/data/models/pwad_model.dart';
import 'package:quickdoom/data/models/source_port_model.dart';
import 'package:quickdoom/features/downloads/domain/download_task.dart';
import 'package:quickdoom/features/downloads/presentation/providers/download_queue_provider.dart';
import 'package:quickdoom/features/engine_manager/domain/entities/engine_release.dart';
import 'package:quickdoom/features/engine_manager/domain/entities/engine_source.dart';
import 'package:quickdoom/features/library/presentation/providers/mod_library_provider.dart';
import 'package:quickdoom/features/mod_browser/domain/entities/mod_file.dart';
import 'package:quickdoom/features/source_ports/presentation/providers/source_port_provider.dart';

/// End-to-end cover for the real download → extract → register pipeline,
/// served over a loopback HTTP server so no live network is involved.
void main() {
  late Directory temp;
  late HttpServer server;
  late Uri baseUri;

  /// Payload served at /mod.zip and /engine.zip.
  late List<int> modZip;
  late List<int> engineZip;

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('quickdoom_pipeline_');
    Hive.init(temp.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SourcePortModelAdapter());
      Hive.registerAdapter(IwadModelAdapter());
      Hive.registerAdapter(PwadModelAdapter());
      Hive.registerAdapter(LaunchProfileModelAdapter());
    }

    modZip = ZipEncoder().encode(Archive()
      ..add(ArchiveFile.bytes('MYMAP.wad', List.filled(64, 7)))
      ..add(ArchiveFile.bytes('readme.txt', [1, 2, 3])));

    engineZip = ZipEncoder().encode(Archive()
      ..add(ArchiveFile.bytes('gzdoom', List.filled(32, 1)))
      ..add(ArchiveFile.bytes('LICENSE', [4])));

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = Uri.parse('http://127.0.0.1:${server.port}');

    server.listen((request) async {
      final body = switch (request.uri.path) {
        '/mod.zip' => modZip,
        '/engine.zip' => engineZip,
        _ => null,
      };

      if (body == null) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.binary
        ..contentLength = body.length
        ..add(body);
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await Hive.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(overrides: [
      libraryPathsProvider.overrideWithValue(
        LibraryPaths(rootResolver: () async => temp.path),
      ),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  ModFile modFile(String path) => ModFile(
        id: 7,
        title: 'Pipeline Mod',
        filename: 'mod.zip',
        author: 'Tester',
        description: '',
        size: 0,
        rating: 0,
        votes: 0,
        downloadUrl: baseUri.resolve(path).toString(),
        uploadDate: DateTime(2024),
        dir: 'levels/',
      );

  test('a mod is fetched, unpacked and registered in the library', () async {
    final container = makeContainer();

    await container
        .read(downloadQueueProvider.notifier)
        .downloadMod(modFile('/mod.zip'));

    final task = container.read(downloadQueueProvider)[DownloadTask.modKey(7)]!;
    expect(task.stage, DownloadStage.done, reason: task.error ?? '');

    final library = await container.read(modLibraryProvider.future);
    expect(library, hasLength(1));

    final installed = library.single;
    expect(installed.name, 'Pipeline Mod');
    expect(installed.files, hasLength(1));
    expect(p.basename(installed.files.single), 'MYMAP.wad');

    // The wad really exists on disk with the bytes the server sent.
    final wad = File(installed.files.single);
    expect(wad.existsSync(), isTrue);
    expect(wad.lengthSync(), 64);

    // The non-loadable file was extracted too, just not offered to the port.
    expect(
      File(p.join(installed.installDir, 'readme.txt')).existsSync(),
      isTrue,
    );

    // No .part file is left behind once the transfer completes.
    final downloads = Directory(p.join(temp.path, 'downloads'));
    expect(
      downloads.listSync().where((f) => f.path.endsWith('.part')),
      isEmpty,
    );
  });

  test('an engine is installed and registered as a source port', () async {
    final container = makeContainer();

    await container.read(downloadQueueProvider.notifier).downloadEngine(
          source: const EngineSource(
            id: 'gzdoom',
            displayName: 'GZDoom',
            githubOwner: 'ZDoom',
            githubRepo: 'gzdoom',
          ),
          release: EngineRelease(
            tagName: 'g4.12.0',
            name: 'GZDoom 4.12.0',
            prerelease: false,
            body: '',
            publishedAt: DateTime(2024),
            assets: const [],
          ),
          asset: EngineAsset(
            name: 'engine.zip',
            downloadUrl: baseUri.resolve('/engine.zip').toString(),
            size: 0,
            downloadCount: 0,
          ),
        );

    final key = DownloadTask.engineKey('gzdoom', 'g4.12.0', 'engine.zip');
    final task = container.read(downloadQueueProvider)[key]!;
    expect(task.stage, DownloadStage.done, reason: task.error ?? '');

    final ports = await container.read(sourcePortListProvider.future);
    expect(ports, hasLength(1));
    expect(ports.single.name, 'GZDoom g4.12.0');
    expect(p.basename(ports.single.executablePath), 'gzdoom');
    expect(File(ports.single.executablePath).existsSync(), isTrue);

    // The release tag became a single safe path segment.
    expect(ports.single.executablePath, contains('g4.12.0'));
  }, testOn: '!windows');

  test('a 404 fails the task without touching the library', () async {
    final container = makeContainer();

    await container
        .read(downloadQueueProvider.notifier)
        .downloadMod(modFile('/missing.zip'));

    final task = container.read(downloadQueueProvider)[DownloadTask.modKey(7)]!;
    expect(task.stage, DownloadStage.failed);
    expect(task.error, contains('404'));

    expect(await container.read(modLibraryProvider.future), isEmpty);

    // The aborted transfer left nothing half-written.
    final downloads = Directory(p.join(temp.path, 'downloads'));
    if (downloads.existsSync()) {
      expect(downloads.listSync(), isEmpty);
    }
  });
}
