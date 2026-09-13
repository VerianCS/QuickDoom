import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/download_service.dart';
import '../../../../core/services/install_service.dart';
import '../../../../core/services/library_paths.dart';
import '../../../../domain/entities/source_port.dart';
import '../../../engine_manager/domain/entities/engine_release.dart';
import '../../../engine_manager/domain/entities/engine_source.dart';
import '../../../library/domain/entities/installed_mod.dart';
import '../../../mod_browser/domain/entities/mod_file.dart';
import '../../../library/presentation/providers/mod_library_provider.dart';
import '../../../source_ports/presentation/providers/source_port_provider.dart';
import '../../domain/download_task.dart';

part 'download_queue_provider.g.dart';

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService();
});

final installServiceProvider = Provider<InstallService>((ref) {
  return InstallService();
});

/// Tracks every download in flight, keyed by target.
///
/// Mods land in the library; engines are registered as source ports so they
/// show up in the launcher dropdown without another trip through a file picker.
///
/// Kept alive deliberately: an auto-disposed queue would drop its tasks — and
/// orphan the transfers feeding them — as soon as the last row stopped
/// watching, so switching tabs mid-download would lose the download.
@Riverpod(keepAlive: true)
class DownloadQueue extends _$DownloadQueue {
  final Map<String, StreamSubscription<DownloadProgress>> _subscriptions = {};

  @override
  Map<String, DownloadTask> build() {
    ref.onDispose(() {
      for (final sub in _subscriptions.values) {
        sub.cancel();
      }
      _subscriptions.clear();
    });
    return const {};
  }

  DownloadTask? taskFor(String id) => state[id];

  /// Downloads a mod from idgames and registers it in the library.
  Future<void> downloadMod(ModFile mod) async {
    final id = DownloadTask.modKey(mod.id);
    if (state[id]?.isActive ?? false) return;

    final label = mod.title.isNotEmpty ? mod.title : mod.filename;
    _put(DownloadTask(id: id, label: label, totalBytes: mod.size));

    await _run(
      id: id,
      url: mod.downloadUrl,
      filename: mod.filename,
      install: (archivePath) async {
        final modId = const Uuid().v4();
        final result = await ref.read(installServiceProvider).install(
              archivePath,
              destDir: await ref.read(libraryPathsProvider).modDir(modId),
            );

        if (result.loadableFiles.isEmpty) {
          throw const InstallException(
            'No .wad or .pk3 files found inside the archive.',
          );
        }

        await ref.read(modLibraryProvider.notifier).add(
              InstalledMod(
                id: modId,
                name: label,
                installDir: result.installDir,
                files: result.loadableFiles,
                idgamesId: mod.id,
                author: mod.author,
                sizeBytes: result.sizeBytes,
                installedAt: DateTime.now(),
              ),
            );

        return result.installDir;
      },
    );
  }

  /// Downloads an engine release asset and registers it as a source port.
  Future<void> downloadEngine({
    required EngineSource source,
    required EngineRelease release,
    required EngineAsset asset,
  }) async {
    final id = DownloadTask.engineKey(source.id, release.tagName, asset.name);
    if (state[id]?.isActive ?? false) return;

    final label = '${source.displayName} ${release.tagName}';
    _put(DownloadTask(id: id, label: label, totalBytes: asset.size));

    await _run(
      id: id,
      url: asset.downloadUrl,
      filename: asset.name,
      install: (archivePath) async {
        final result = await ref.read(installServiceProvider).install(
              archivePath,
              destDir: await ref
                  .read(libraryPathsProvider)
                  .engineDir(source.id, release.tagName),
              preferredExecutableName: source.githubRepo,
            );

        if (result.executables.isEmpty) {
          throw const InstallException(
            'No engine executable found inside the archive.',
          );
        }

        await ref.read(sourcePortListProvider.notifier).save(
              SourcePort(
                id: '${source.id}-${LibraryPaths.sanitize(release.tagName)}',
                name: label,
                executablePath: result.executables.first,
              ),
            );

        return result.installDir;
      },
    );
  }

  /// Shared transfer-then-install pipeline.
  Future<void> _run({
    required String id,
    required String url,
    required String filename,
    required Future<String> Function(String archivePath) install,
  }) async {
    try {
      final downloadsDir = await ref.read(libraryPathsProvider).downloads();
      // Prefix with the task id: two mods can ship the same filename, and
      // concurrent downloads must not write over each other's archive.
      final archivePath = p.join(
        downloadsDir,
        '${LibraryPaths.sanitize(id)}__'
            '${LibraryPaths.sanitize(filename.isEmpty ? 'download' : filename)}',
      );

      _update(id, (t) => t.copyWith(stage: DownloadStage.downloading));

      final subscription = ref
          .read(downloadServiceProvider)
          .download(url, archivePath)
          .listen((progress) {
        _update(
          id,
          (t) => t.copyWith(
            receivedBytes: progress.receivedBytes,
            totalBytes: progress.totalBytes > 0
                ? progress.totalBytes
                : t.totalBytes,
          ),
        );
      });
      _subscriptions[id] = subscription;

      try {
        await subscription.asFuture<void>();
      } finally {
        _subscriptions.remove(id);
      }

      // cancel() clears the task; nothing left to install.
      if (!state.containsKey(id)) return;

      _update(id, (t) => t.copyWith(stage: DownloadStage.installing));
      final installDir = await install(archivePath);

      _update(
        id,
        (t) => t.copyWith(stage: DownloadStage.done, installDir: installDir),
      );
    } catch (e) {
      _subscriptions.remove(id);
      if (!state.containsKey(id)) return;
      _update(
        id,
        (t) => t.copyWith(stage: DownloadStage.failed, error: _message(e)),
      );
    }
  }

  /// Stops an in-flight transfer and drops the task.
  void cancel(String id) {
    _subscriptions.remove(id)?.cancel();
    final next = Map<String, DownloadTask>.from(state)..remove(id);
    state = next;
  }

  /// Clears a finished task so the row returns to its idle state.
  void dismiss(String id) {
    final task = state[id];
    if (task == null || task.isActive) return;
    final next = Map<String, DownloadTask>.from(state)..remove(id);
    state = next;
  }

  void clearFinished() {
    state = Map.fromEntries(state.entries.where((e) => e.value.isActive));
  }

  void _put(DownloadTask task) {
    state = {...state, task.id: task};
  }

  void _update(String id, DownloadTask Function(DownloadTask) change) {
    final current = state[id];
    if (current == null) return;
    state = {...state, id: change(current)};
  }

  static String _message(Object error) {
    if (error is InstallException) return error.message;
    if (error is DownloadException) return error.message;
    return error.toString();
  }
}
