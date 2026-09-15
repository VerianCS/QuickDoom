import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/file_picker_service.dart';
import '../../../../domain/entities/iwad.dart';
import '../../../iwads/presentation/providers/iwad_provider.dart';
import '../providers/launch_provider.dart';
import '../providers/path_problem_provider.dart';
import 'loadout_slot.dart';
import 'slot_picker.dart';

/// Slot II of the bench: the game the engine will run.
class IwadSelector extends ConsumerWidget {
  const IwadSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iwadsAsync = ref.watch(iwadListProvider);
    final selected = ref.watch(launchNotifierProvider.select((s) => s.iwad));
    final iwads = iwadsAsync.valueOrNull ?? const <Iwad>[];

    return LoadoutSlot(
      ordinal: 'II',
      label: 'IWAD',
      icon: Icons.album_outlined,
      emptyHint:
          iwadsAsync.isLoading ? 'Reading saved IWADs\u2026' : 'No game seated',
      value: selected?.name,
      detail: selected?.path,
      problem: selected == null
          ? null
          : ref.watch(iwadProblemProvider(selected.path)).valueOrNull,
      onTap: () => _pick(context, ref, iwads, selected),
      actions: [
        if (selected != null) ...[
          SlotAction(
            icon: Icons.tune,
            tooltip: 'Edit IWAD',
            onPressed: () => _showEditDialog(context, ref, selected),
          ),
          SlotAction(
            icon: Icons.delete_outline,
            tooltip: 'Remove IWAD',
            onPressed: () => _confirmDelete(context, ref, selected),
          ),
        ],
        SlotAction(
          icon: Icons.folder_open,
          tooltip: 'Browse for a WAD',
          tint: AppColors.primary,
          onPressed: () => _browseAndAdd(ref),
        ),
      ],
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    List<Iwad> iwads,
    Iwad? selected,
  ) async {
    final choice = await showSlotPicker<Iwad>(
      context: context,
      title: 'IWAD',
      entries: [
        for (final i in iwads)
          SlotEntry(
            value: i,
            label: i.name,
            detail: i.path,
            selected: i.id == selected?.id,
          ),
      ],
      emptyLabel: 'No saved IWADs yet.',
      browseLabel: 'Browse for a WAD\u2026',
    );

    if (choice == null) return;
    if (choice.browse) {
      await _browseAndAdd(ref);
    } else if (choice.value != null) {
      ref.read(launchNotifierProvider.notifier).setIwad(choice.value!);
    }
  }

  Future<void> _browseAndAdd(WidgetRef ref) async {
    final path = await FilePickerService().pickFile(
      allowedExtensions: ['wad'],
      dialogTitle: 'Select IWAD File',
    );
    if (path == null) return;

    final name = path.split('\\').last.split('/').last;
    final iwad = Iwad(
      id: const Uuid().v4(),
      name: name,
      path: path,
    );
    await ref.read(iwadListProvider.notifier).save(iwad);
    ref.read(launchNotifierProvider.notifier).setIwad(iwad);
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Iwad iwad) {
    final nameCtrl = TextEditingController(text: iwad.name);
    final pathCtrl = TextEditingController(text: iwad.path);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit IWAD'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pathCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'File Path',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.folder_open, size: 18),
                  onPressed: () async {
                    final p = await FilePickerService().pickFile(
                      allowedExtensions: ['wad'],
                      dialogTitle: 'Select IWAD File',
                    );
                    if (p != null) pathCtrl.text = p;
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final updated = iwad.copyWith(
                name: nameCtrl.text.trim(),
                path: pathCtrl.text.trim(),
              );
              await ref.read(iwadListProvider.notifier).save(updated);
              ref.read(launchNotifierProvider.notifier).setIwad(updated);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Iwad iwad) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete IWAD'),
        content: Text('Delete "${iwad.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(iwadListProvider.notifier).delete(iwad.id);
              ref.read(launchNotifierProvider.notifier).clearIwad();
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
