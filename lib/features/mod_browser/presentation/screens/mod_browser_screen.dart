import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/mod_search_provider.dart';
import '../providers/mod_download_provider.dart';
import '../../domain/entities/mod_file.dart';

class ModBrowserScreen extends ConsumerStatefulWidget {
  const ModBrowserScreen({super.key});

  @override
  ConsumerState<ModBrowserScreen> createState() => _ModBrowserScreenState();
}

class _ModBrowserScreenState extends ConsumerState<ModBrowserScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(modSearchProvider.notifier).search(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(modSearchProvider);
    final downloadState = ref.watch(modDownloadProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search mods on idgames...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              isDense: true,
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(modSearchProvider.notifier).search('');
                      },
                    )
                  : null,
            ),
          ),
        ),
        Expanded(
          child: searchState.when(
            data: (results) {
              if (results.isEmpty) {
                return Center(
                  child: Text(
                    _searchController.text.length < 3
                        ? 'Type at least 3 characters to search'
                        : 'No results found',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final mod = results[index];
                  final isDownloading = downloadState.isDownloading;
                  return _ModResultCard(
                    mod: mod,
                    isDownloading: isDownloading,
                    onDownload: () => ref.read(modDownloadProvider.notifier).download(mod),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (err, _) => Center(
              child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
            ),
          ),
        ),
        if (downloadState.isDownloading)
          _DownloadProgressBar(progress: downloadState.progress),
        if (downloadState.error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              downloadState.error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _ModResultCard extends StatelessWidget {
  final ModFile mod;
  final bool isDownloading;
  final VoidCallback onDownload;

  const _ModResultCard({
    required this.mod,
    required this.isDownloading,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mod.title.isNotEmpty ? mod.title : mod.filename,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (mod.author.isNotEmpty) ...[
                        Icon(Icons.person_outline, size: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(128)),
                        const SizedBox(width: 4),
                        Text(mod.author, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(128))),
                        const SizedBox(width: 12),
                      ],
                      Icon(Icons.file_present_outlined, size: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(128)),
                      const SizedBox(width: 4),
                      Text(mod.filename, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(128))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(mod.sizeFormatted, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 12),
                      if (mod.rating > 0) ...[
                        Icon(Icons.star, size: 12, color: Colors.amber.shade600),
                        const SizedBox(width: 2),
                        Text('${mod.rating.toStringAsFixed(1)} (${mod.votes})', style: const TextStyle(fontSize: 12)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: isDownloading ? null : onDownload,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Get', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadProgressBar extends StatelessWidget {
  final double progress;

  const _DownloadProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: LinearProgressIndicator(value: progress, minHeight: 4),
          ),
          const SizedBox(width: 8),
          Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
