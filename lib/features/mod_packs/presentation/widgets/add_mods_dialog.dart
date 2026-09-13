import 'package:flutter/material.dart';

import '../../../library/domain/entities/installed_mod.dart';

/// Multi-select picker over the library. Returns the chosen mod ids, or null
/// if the user dismissed the dialog.
Future<List<String>?> showAddModsDialog(
  BuildContext context,
  List<InstalledMod> available,
) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _AddModsDialog(available: available),
  );
}

class _AddModsDialog extends StatefulWidget {
  final List<InstalledMod> available;

  const _AddModsDialog({required this.available});

  @override
  State<_AddModsDialog> createState() => _AddModsDialogState();
}

class _AddModsDialogState extends State<_AddModsDialog> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Mods'),
      content: SizedBox(
        width: 420,
        height: 360,
        child: ListView.builder(
          itemCount: widget.available.length,
          itemBuilder: (context, index) {
            final mod = widget.available[index];
            final checked = _selected.contains(mod.id);

            return CheckboxListTile(
              dense: true,
              value: checked,
              title: Text(
                mod.name,
                style: const TextStyle(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${mod.primaryFileName} · ${mod.sizeFormatted}',
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onChanged: (value) => setState(() {
                if (value ?? false) {
                  _selected.add(mod.id);
                } else {
                  _selected.remove(mod.id);
                }
              }),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selected.toList()),
          child: Text('Add ${_selected.length}'),
        ),
      ],
    );
  }
}
