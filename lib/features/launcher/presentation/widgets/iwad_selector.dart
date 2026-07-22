import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/file_picker_service.dart';
import '../../../../domain/entities/iwad.dart';
import '../../../iwads/presentation/providers/iwad_provider.dart';
import '../providers/launch_provider.dart';

class IwadSelector extends ConsumerWidget {
  const IwadSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iwadsAsync = ref.watch(iwadListProvider);
    final selected = ref.watch(launchNotifierProvider.select((s) => s.iwad));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('IWAD', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: iwadsAsync.when(
                data: (iwads) {
                  final currentValue = selected != null && iwads.any((i) => i.id == selected.id)
                      ? iwads.firstWhere((i) => i.id == selected.id)
                      : null;
                  return InputDecorator(
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Iwad>(
                        value: currentValue,
                        hint: const Text('Select a saved IWAD...'),
                        isExpanded: true,
                        items: [
                          ...iwads.map((i) => DropdownMenuItem(
                            value: i,
                            child: Text(i.name, overflow: TextOverflow.ellipsis),
                          )),
                          DropdownMenuItem(
                            value: null,
                            enabled: false,
                            child: Row(
                              children: [
                                Icon(Icons.folder_open, size: 16, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text('Browse...', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (iwad) {
                          if (iwad != null) {
                            ref.read(launchNotifierProvider.notifier).setIwad(iwad);
                          } else {
                            _browseAndAdd(ref);
                          }
                        },
                      ),
                    ),
                  );
                },
                loading: () => const TextField(
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'Loading IWADs...',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
                error: (err, _) => TextField(
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'Error loading IWADs',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ),
            ),
            if (selected != null) ...[
              const SizedBox(width: 4),
              _IconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit',
                onPressed: () => _showEditDialog(context, ref, selected),
              ),
              _IconButton(
                icon: Icons.delete_outline,
                tooltip: 'Delete',
                onPressed: () => _confirmDelete(context, ref, selected),
              ),
            ],
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: () => _browseAndAdd(ref),
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('Browse'),
            ),
          ],
        ),
      ],
    );
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
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _IconButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurface.withAlpha(180)),
        ),
      ),
    );
  }
}
