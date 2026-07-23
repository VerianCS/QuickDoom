import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/engine_source.dart';
import '../../domain/entities/engine_release.dart';
import '../providers/engine_download_provider.dart';
import '../providers/engine_list_provider.dart';
import '../providers/engine_releases_provider.dart';

class EngineManagerScreen extends ConsumerWidget {
  const EngineManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engines = ref.watch(engineListProvider);
    final downloadState = ref.watch(engineDownloadProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Source Port Downloads', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: engines.length,
            itemBuilder: (context, index) => _EngineSourceCard(engine: engines[index]),
          ),
        ),
        if (downloadState.isDownloading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(value: downloadState.progress, minHeight: 4),
                ),
                const SizedBox(width: 8),
                Text('${(downloadState.progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        if (downloadState.error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(downloadState.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
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
                children: releases.take(10).map((r) => _ReleaseCard(release: r)).toList(),
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
  final EngineRelease release;

  const _ReleaseCard({required this.release});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(engineDownloadProvider);

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
            ...release.assetsForPlatform('windows').map((asset) => ListTile(
              dense: true,
              leading: const Icon(Icons.file_download_outlined, size: 18),
              title: Text(asset.name, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(asset.sizeFormatted, style: const TextStyle(fontSize: 11)),
              onTap: downloadState.isDownloading
                  ? null
                  : () => ref.read(engineDownloadProvider.notifier).download(
                        asset.downloadUrl,
                        asset.name,
                      ),
            )),
            if (release.assetsForPlatform('windows').isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('No Windows assets found', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
