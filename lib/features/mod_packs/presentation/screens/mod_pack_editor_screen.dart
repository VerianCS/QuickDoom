import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/iwad.dart';
import '../../../../domain/entities/source_port.dart';
import '../../../iwads/presentation/providers/iwad_provider.dart';
import '../../../library/domain/entities/installed_mod.dart';
import '../../../library/presentation/providers/mod_library_provider.dart';
import '../../../main/presentation/screens/main_screen.dart';
import '../../../source_ports/presentation/providers/source_port_provider.dart';
import '../../domain/entities/mod_pack.dart';
import '../providers/mod_pack_launcher.dart';
import '../providers/mod_pack_provider.dart';
import '../widgets/add_mods_dialog.dart';

class ModPackEditorScreen extends ConsumerStatefulWidget {
  final ModPack pack;

  const ModPackEditorScreen({super.key, required this.pack});

  @override
  ConsumerState<ModPackEditorScreen> createState() =>
      _ModPackEditorScreenState();
}

class _ModPackEditorScreenState extends ConsumerState<ModPackEditorScreen> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.pack.name);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// The live copy of this pack, so edits made here re-render immediately.
  ModPack _current(List<ModPack> packs) {
    for (final pack in packs) {
      if (pack.id == widget.pack.id) return pack;
    }
    return widget.pack;
  }

  void _saveName(ModPack pack) {
    final name = _nameController.text.trim();
    if (name.isEmpty || name == pack.name) return;
    ref.read(modPackListProvider.notifier).save(pack.copyWith(name: name));
  }

  Future<void> _addMods(ModPack pack) async {
    final library = await ref.read(modLibraryProvider.future);
    if (!mounted) return;

    final available =
        library.where((mod) => !pack.contains(mod.id)).toList();

    if (available.isEmpty) {
      _notify(
        library.isEmpty
            ? 'Your library is empty — download mods from the Mod Browser first.'
            : 'Every mod in your library is already in this pack.',
      );
      return;
    }

    final selected = await showAddModsDialog(context, available);
    if (selected == null || selected.isEmpty) return;

    await ref.read(modPackListProvider.notifier).addMods(pack.id, selected);
  }

  Future<void> _loadIntoLauncher(ModPack pack) async {
    final result =
        await ref.read(modPackLauncherProvider).loadIntoLauncher(pack);
    if (!mounted) return;

    ref.read(currentTabProvider.notifier).state = AppTab.launcher;
    Navigator.of(context).pop();

    final warning = result.warning;
    _notify(
      warning == null
          ? 'Loaded "${pack.name}" — ${result.fileCount} file'
              '${result.fileCount == 1 ? '' : 's'} ready to launch.'
          : 'Loaded "${pack.name}" with issues: $warning.',
    );
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final packsAsync = ref.watch(modPackListProvider);
    final pack = packsAsync.maybeWhen(
      data: _current,
      orElse: () => widget.pack,
    );

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _nameController,
          onSubmitted: (_) => _saveName(pack),
          onTapOutside: (_) => _saveName(pack),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton.icon(
              onPressed:
                  pack.entries.isEmpty ? null : () => _loadIntoLauncher(pack),
              icon: const Icon(Icons.rocket_launch_outlined, size: 16),
              label: const Text('Load into Launcher'),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PackSettings(pack: pack),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Text('Mods',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text(
                  '${pack.enabledCount} of ${pack.entries.length} enabled · '
                  'drag to reorder',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(140),
                  ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () => _addMods(pack),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Mods'),
                ),
              ],
            ),
          ),
          Expanded(child: _ModList(pack: pack)),
        ],
      ),
    );
  }
}

/// Engine and IWAD pickers, both optional.
class _PackSettings extends ConsumerWidget {
  final ModPack pack;

  const _PackSettings({required this.pack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ports = ref.watch(sourcePortListProvider);
    final iwads = ref.watch(iwadListProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: ports.maybeWhen(
              data: (data) => _Dropdown<SourcePort>(
                label: 'Engine',
                hint: 'Use launcher selection',
                items: data,
                selectedId: pack.engineId,
                idOf: (p) => p.id,
                labelOf: (p) => p.name,
                onChanged: (port) =>
                    ref.read(modPackListProvider.notifier).save(
                          port == null
                              ? pack.copyWith(clearEngine: true)
                              : pack.copyWith(engineId: port.id),
                        ),
              ),
              orElse: () => const _DropdownPlaceholder(label: 'Engine'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: iwads.maybeWhen(
              data: (data) => _Dropdown<Iwad>(
                label: 'IWAD',
                hint: 'Use launcher selection',
                items: data,
                selectedId: pack.iwadId,
                idOf: (i) => i.id,
                labelOf: (i) => i.name,
                onChanged: (iwad) => ref.read(modPackListProvider.notifier).save(
                      iwad == null
                          ? pack.copyWith(clearIwad: true)
                          : pack.copyWith(iwadId: iwad.id),
                    ),
              ),
              orElse: () => const _DropdownPlaceholder(label: 'IWAD'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final String label;
  final String hint;
  final List<T> items;
  final String? selectedId;
  final String Function(T) idOf;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;

  const _Dropdown({
    required this.label,
    required this.hint,
    required this.items,
    required this.selectedId,
    required this.idOf,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // A stale id (the port or IWAD was deleted) must not be passed to the
    // dropdown, which asserts the value exists among its items.
    final validId =
        items.any((item) => idOf(item) == selectedId) ? selectedId : null;

    return DropdownButtonFormField<String>(
      initialValue: validId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      style: const TextStyle(fontSize: 13),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text(hint, style: const TextStyle(fontSize: 13)),
        ),
        ...items.map((item) => DropdownMenuItem<String>(
              value: idOf(item),
              child: Text(
                labelOf(item),
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            )),
      ],
      onChanged: (id) {
        if (id == null) {
          onChanged(null);
          return;
        }
        for (final item in items) {
          if (idOf(item) == id) {
            onChanged(item);
            return;
          }
        }
      },
    );
  }
}

class _DropdownPlaceholder extends StatelessWidget {
  final String label;

  const _DropdownPlaceholder({required this.label});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      child: const Text('Loading…', style: TextStyle(fontSize: 13)),
    );
  }
}

/// The pack's mods, resolved against the library and reorderable.
class _ModList extends ConsumerWidget {
  final ModPack pack;

  const _ModList({required this.pack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(modLibraryProvider);

    if (pack.entries.isEmpty) {
      return _EmptyState(
        icon: Icons.playlist_add,
        message: 'No mods in this pack yet.\n'
            'Add mods from your library to build a load order.',
      );
    }

    return libraryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (err, _) => Center(
        child: Text('Could not read library: $err',
            style: const TextStyle(color: Colors.red)),
      ),
      data: (library) {
        final byId = {for (final mod in library) mod.id: mod};

        return ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: pack.entries.length,
          onReorder: (oldIndex, newIndex) => ref
              .read(modPackListProvider.notifier)
              .reorder(pack.id, oldIndex, newIndex),
          itemBuilder: (context, index) {
            final entry = pack.entries[index];
            return _ModRow(
              key: ValueKey(entry.modId),
              index: index,
              order: index + 1,
              entry: entry,
              mod: byId[entry.modId],
              onToggle: () => ref
                  .read(modPackListProvider.notifier)
                  .toggleMod(pack.id, entry.modId),
              onRemove: () => ref
                  .read(modPackListProvider.notifier)
                  .removeMod(pack.id, entry.modId),
            );
          },
        );
      },
    );
  }
}

class _ModRow extends StatelessWidget {
  final int index;
  final int order;
  final ModPackEntry entry;

  /// Null when the mod has been removed from the library.
  final InstalledMod? mod;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  const _ModRow({
    super.key,
    required this.index,
    required this.order,
    required this.entry,
    required this.mod,
    required this.onToggle,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final missing = mod == null;
    final dim = Theme.of(context).colorScheme.onSurface.withAlpha(140);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: SizedBox(
          width: 52,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Icon(Icons.drag_indicator, size: 18, color: dim),
              ),
              const SizedBox(width: 4),
              Text('$order',
                  style: TextStyle(fontSize: 12, color: dim)),
            ],
          ),
        ),
        title: Text(
          missing ? 'Missing mod' : mod!.name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: missing ? Theme.of(context).colorScheme.error : null,
            decoration: entry.isEnabled ? null : TextDecoration.lineThrough,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          missing
              ? 'No longer in your library — remove it from this pack.'
              : mod!.primaryFileName,
          style: TextStyle(fontSize: 11, color: dim),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: entry.isEnabled && !missing,
              onChanged: missing ? null : (_) => onToggle(),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Remove from pack',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final dim = Theme.of(context).colorScheme.onSurface.withAlpha(128);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: dim),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: dim)),
        ],
      ),
    );
  }
}
