import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../domain/entities/pwad.dart';
import '../../../launcher/presentation/providers/launch_provider.dart';
import '../../../main/presentation/screens/main_screen.dart';
import '../../domain/entities/installed_mod.dart';
import '../providers/mod_library_provider.dart';

/// Everything QuickDoom has downloaded and unpacked.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(modLibraryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Text('Library',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              libraryAsync.maybeWhen(
                data: (mods) => Text(
                  '${mods.length} installed',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(140),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        Expanded(
          child: libraryAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (err, _) => Center(
              child: Text('Could not read library: $err',
                  style: const TextStyle(color: Colors.red)),
            ),
            data: (mods) {
              if (mods.isEmpty) return const _EmptyLibrary();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: mods.length,
                itemBuilder: (context, index) =>
                    _InstalledModCard(mod: mods[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyLibrary extends ConsumerWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dim = Theme.of(context).colorScheme.onSurface.withAlpha(128);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 40, color: dim),
          const SizedBox(height: 12),
          Text(
            'Nothing installed yet.',
            style: TextStyle(color: dim, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            'Downloads from the Mod Browser land here.',
            style: TextStyle(color: dim, fontSize: 12),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => ref.read(currentTabProvider.notifier).state =
                AppTab.modBrowser,
            icon: const Icon(Icons.search, size: 16),
            label: const Text('Browse Mods'),
          ),
        ],
      ),
    );
  }
}

class _InstalledModCard extends ConsumerWidget {
  final InstalledMod mod;

  const _InstalledModCard({required this.mod});

  /// Appends this mod's files to the launcher's PWAD stack.
  void _addToLauncher(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(launchNotifierProvider.notifier);
    final existing = ref.read(launchNotifierProvider).pwads.length;

    notifier.addPwads([
      for (final (index, file) in mod.files.indexed)
        Pwad(
          id: const Uuid().v4(),
          path: file,
          loadOrder: existing + index,
        ),
    ]);

    ref.read(currentTabProvider.notifier).state = AppTab.launcher;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Added ${mod.files.length} file'
            '${mod.files.length == 1 ? '' : 's'} from "${mod.name}".'),
      ));
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove mod?'),
        content: Text(
          '"${mod.name}" and its unpacked files will be deleted from disk.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref.read(modLibraryProvider.notifier).remove(mod.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dim = Theme.of(context).colorScheme.onSurface.withAlpha(140);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.extension_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          mod.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            if (mod.author.isNotEmpty) mod.author,
            '${mod.files.length} file${mod.files.length == 1 ? '' : 's'}',
            mod.sizeFormatted,
          ].join(' · '),
          style: TextStyle(fontSize: 12, color: dim),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.tonalIcon(
              onPressed: mod.files.isEmpty
                  ? null
                  : () => _addToLauncher(context, ref),
              icon: const Icon(Icons.playlist_add, size: 16),
              label: const Text('Add', style: TextStyle(fontSize: 12)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Remove from library',
              onPressed: () => _confirmRemove(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
