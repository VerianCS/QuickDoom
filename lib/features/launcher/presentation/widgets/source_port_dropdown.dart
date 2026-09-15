import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/file_picker_service.dart';
import '../../../../domain/entities/source_port.dart';
import '../../../source_ports/presentation/providers/source_port_provider.dart';
import '../providers/launch_provider.dart';
import '../providers/path_problem_provider.dart';
import 'loadout_slot.dart';
import 'slot_picker.dart';

/// Slot I of the bench: the engine that will run.
class SourcePortSelector extends ConsumerWidget {
  const SourcePortSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portsAsync = ref.watch(sourcePortListProvider);
    final selected =
        ref.watch(launchNotifierProvider.select((s) => s.sourcePort));
    final ports = portsAsync.valueOrNull ?? const <SourcePort>[];

    return LoadoutSlot(
      ordinal: 'I',
      label: 'Source Port',
      icon: Icons.memory,
      emptyHint: portsAsync.isLoading
          ? 'Reading saved ports…'
          : 'No engine seated',
      value: selected?.name,
      detail: selected?.executablePath,
      // Checked here rather than only at launch, so a port that has been
      // moved or uninstalled reads as broken instead of looking seated.
      problem: selected == null
          ? null
          : ref.watch(portProblemProvider(selected.executablePath)).valueOrNull,
      onTap: () => _pick(context, ref, ports, selected),
      actions: [
        if (selected != null) ...[
          SlotAction(
            icon: Icons.tune,
            tooltip: 'Edit port',
            onPressed: () => _showEditDialog(context, ref, selected),
          ),
          SlotAction(
            icon: Icons.delete_outline,
            tooltip: 'Remove port',
            onPressed: () => _confirmDelete(context, ref, selected),
          ),
        ],
        SlotAction(
          icon: Icons.folder_open,
          tooltip: 'Browse for an executable',
          tint: AppColors.primary,
          onPressed: () => _browseAndAdd(ref),
        ),
      ],
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    List<SourcePort> ports,
    SourcePort? selected,
  ) async {
    final choice = await showSlotPicker<SourcePort>(
      context: context,
      title: 'Source Port',
      entries: [
        for (final p in ports)
          SlotEntry(
            value: p,
            label: p.name,
            detail: p.executablePath,
            selected: p.id == selected?.id,
          ),
      ],
      emptyLabel: 'No saved ports yet.',
      browseLabel: 'Browse for an executable…',
    );

    if (choice == null) return;
    if (choice.browse) {
      await _browseAndAdd(ref);
    } else if (choice.value != null) {
      ref.read(launchNotifierProvider.notifier).setSourcePort(choice.value!);
    }
  }

  Future<void> _browseAndAdd(WidgetRef ref) async {
    final path = await FilePickerService().pickExecutable(
      dialogTitle: 'Select Source Port Executable',
    );
    if (path == null) return;

    final name = path.split('\\').last.split('/').last;
    final port = SourcePort(
      id: const Uuid().v4(),
      name: name,
      executablePath: path,
    );
    await ref.read(sourcePortListProvider.notifier).save(port);
    ref.read(launchNotifierProvider.notifier).setSourcePort(port);
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, SourcePort port) {
    final nameCtrl = TextEditingController(text: port.name);
    final pathCtrl = TextEditingController(text: port.executablePath);
    final argsCtrl = TextEditingController(text: port.defaultArgs);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Source Port'),
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
                labelText: 'Executable Path',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.folder_open, size: 18),
                  onPressed: () async {
                    final p = await FilePickerService().pickExecutable(
                      dialogTitle: 'Select Source Port Executable',
                    );
                    if (p != null) pathCtrl.text = p;
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: argsCtrl,
              decoration: const InputDecoration(labelText: 'Default Args'),
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
              final updated = port.copyWith(
                name: nameCtrl.text.trim(),
                executablePath: pathCtrl.text.trim(),
                defaultArgs: argsCtrl.text.trim(),
              );
              await ref.read(sourcePortListProvider.notifier).save(updated);
              ref.read(launchNotifierProvider.notifier).setSourcePort(updated);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, SourcePort port) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Source Port'),
        content: Text('Delete "${port.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(sourcePortListProvider.notifier).delete(port.id);
              ref.read(launchNotifierProvider.notifier).clearSourcePort();
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
