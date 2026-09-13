import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../main/presentation/screens/main_screen.dart';
import '../../domain/entities/mod_pack.dart';
import '../providers/mod_pack_launcher.dart';
import '../providers/mod_pack_provider.dart';
import 'mod_pack_editor_screen.dart';

class ModPackListScreen extends ConsumerWidget {
  const ModPackListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packsAsync = ref.watch(modPackListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Text('Mod Packs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => _createPack(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Pack'),
              ),
            ],
          ),
        ),
        Expanded(
          child: packsAsync.when(
            data: (packs) {
              if (packs.isEmpty) {
                return Center(
                  child: Text(
                    'No mod packs yet.\nCreate one to organize your mods!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(128)),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: packs.length,
                itemBuilder: (context, index) {
                  final pack = packs[index];
                  return _ModPackCard(
                    pack: pack,
                    onEdit: () => _editPack(context, pack),
                    onLoad: () => _loadPack(context, ref, pack),
                    onDuplicate: () => _duplicatePack(ref, pack),
                    onDelete: () => _deletePack(ref, pack),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
          ),
        ),
      ],
    );
  }

  void _createPack(BuildContext context, WidgetRef ref) {
    final pack = ModPack(
      id: const Uuid().v4(),
      name: 'New Mod Pack',
    );
    ref.read(modPackListProvider.notifier).save(pack);
    _editPack(context, pack);
  }

  void _editPack(BuildContext context, ModPack pack) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ModPackEditorScreen(pack: pack)),
    );
  }

  void _duplicatePack(WidgetRef ref, ModPack pack) {
    final copy = pack.copyWith(
      id: const Uuid().v4(),
      name: '${pack.name} (Copy)',
    );
    ref.read(modPackListProvider.notifier).save(copy);
  }

  void _deletePack(WidgetRef ref, ModPack pack) {
    ref.read(modPackListProvider.notifier).delete(pack.id);
  }

  Future<void> _loadPack(
    BuildContext context,
    WidgetRef ref,
    ModPack pack,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result =
        await ref.read(modPackLauncherProvider).loadIntoLauncher(pack);

    ref.read(currentTabProvider.notifier).state = AppTab.launcher;

    final warning = result.warning;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          warning == null
              ? 'Loaded "${pack.name}" — ${result.fileCount} file'
                  '${result.fileCount == 1 ? '' : 's'} ready to launch.'
              : 'Loaded "${pack.name}" with issues: $warning.',
        ),
      ));
  }
}

class _ModPackCard extends StatelessWidget {
  final ModPack pack;
  final VoidCallback onEdit;
  final VoidCallback onLoad;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _ModPackCard({
    required this.pack,
    required this.onEdit,
    required this.onLoad,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(Icons.folder_outlined, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 20),
        ),
        title: Text(pack.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          pack.entries.isEmpty
              ? 'Empty pack'
              : '${pack.entries.length} mod'
                  '${pack.entries.length == 1 ? '' : 's'}'
                  ' · ${pack.enabledCount} enabled',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.rocket_launch_outlined, size: 18),
              tooltip: 'Load into Launcher',
              onPressed: pack.entries.isEmpty ? null : onLoad,
            ),
            PopupMenuButton<String>(
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              onSelected: (action) {
                switch (action) {
                  case 'edit': onEdit();
                  case 'duplicate': onDuplicate();
                  case 'delete': onDelete();
                }
              },
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}
