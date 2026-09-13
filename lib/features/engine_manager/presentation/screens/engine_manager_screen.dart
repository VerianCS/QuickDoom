import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/platform_utils.dart';
import '../../domain/entities/engine_source.dart';
import '../../domain/entities/engine_release.dart';
import '../providers/engine_list_provider.dart';
import '../providers/engine_releases_provider.dart';
import '../../../downloads/domain/download_task.dart';
import '../../../downloads/presentation/providers/download_queue_provider.dart';
import '../../../downloads/presentation/widgets/download_button.dart';

class EngineManagerScreen extends ConsumerWidget {
  const EngineManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engines = ref.watch(engineListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Source Port Downloads',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                'Showing ${enginePlatformLabel()} builds — installed engines are '
                'added to the launcher automatically.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(140),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: engines.length,
            itemBuilder: (context, index) => _EngineSourceCard(engine: engines[index]),
          ),
        ),
      ],
    );
  }
}

class _EngineSourceCard extends ConsumerWidget {
  final EngineSource engine;

  const _EngineSourceCard({required this.engine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releasesAsync = ref.watch(engineReleasesProvider(engine));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(Icons.videogame_asset_outlined, color: Theme.of(context).colorScheme.primary),
        title: Text(engine.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('github.com/${engine.githubOwner}/${engine.githubRepo}', style: const TextStyle(fontSize: 11)),
        children: [
          releasesAsync.when(
            data: (releases) {
              if (releases.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No releases found'),
                );
              }
              return Column(
                children: releases
                    .take(10)
                    .map((r) => _ReleaseCard(engine: engine, release: r))
                    .toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Failed to load releases: $err', style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReleaseCard extends ConsumerWidget {
  final EngineSource engine;
  final EngineRelease release;

  const _ReleaseCard({required this.engine, required this.release});

  List<EngineAsset> get _platformAssets =>
      release.assetsForPlatform(enginePlatformKey());

  /// Falls back to every asset when the release ships nothing matching this
  /// platform, so an unusual naming scheme is not a dead end.
  List<EngineAsset> get _assetsToShow =>
      _platformAssets.isNotEmpty ? _platformAssets : release.assets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(
            release.tagName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: release.prerelease ? FontWeight.normal : FontWeight.w600,
              color: release.prerelease ? Theme.of(context).colorScheme.onSurface.withAlpha(153) : null,
            ),
          ),
          subtitle: Text(
            '${release.publishedAt.year}-${release.publishedAt.month.toString().padLeft(2, '0')}-${release.publishedAt.day.toString().padLeft(2, '0')}'
            '${release.prerelease ? '  [Pre-release]' : ''}',
            style: const TextStyle(fontSize: 11),
          ),
          children: [
            if (release.body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  release.body.length > 200 ? '${release.body.substring(0, 200)}...' : release.body,
                  style: const TextStyle(fontSize: 11),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ..._assetsToShow.map((asset) => _AssetRow(
                  engine: engine,
                  release: release,
                  asset: asset,
                )),
            if (_assetsToShow.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'No downloadable assets in this release.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(140),
                  ),
                ),
              )
            else if (_platformAssets.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  'No ${enginePlatformLabel()} build in this release — showing '
                  'all assets.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(140),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


/// Platform key understood by [EngineRelease.assetsForPlatform].
String enginePlatformKey() => switch (PlatformUtils.current) {
      AppPlatform.windows => 'windows',
      AppPlatform.linux => 'linux',
      AppPlatform.macOS => 'macos',
    };

String enginePlatformLabel() => switch (PlatformUtils.current) {
      AppPlatform.windows => 'Windows',
      AppPlatform.linux => 'Linux',
      AppPlatform.macOS => 'macOS',
    };

class _AssetRow extends ConsumerWidget {
  final EngineSource engine;
  final EngineRelease release;
  final EngineAsset asset;

  const _AssetRow({
    required this.engine,
    required this.release,
    required this.asset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      dense: true,
      leading: Icon(
        Icons.file_download_outlined,
        size: 18,
        color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
      ),
      title: Text(
        asset.name,
        style: const TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(asset.sizeFormatted, style: const TextStyle(fontSize: 11)),
      trailing: DownloadButton(
        taskId: DownloadTask.engineKey(engine.id, release.tagName, asset.name),
        idleLabel: 'Install',
        onStart: () => ref.read(downloadQueueProvider.notifier).downloadEngine(
              source: engine,
              release: release,
              asset: asset,
            ),
      ),
    );
  }
}
