import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/launch_profile.dart';
import '../providers/profile_provider.dart';

class ProfileCard extends ConsumerWidget {
  final LaunchProfile profile;
  final bool isSelected;

  const ProfileCard({
    super.key,
    required this.profile,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tileColor = isSelected
        ? Theme.of(context).colorScheme.primary.withAlpha(30)
        : Colors.transparent;

    return GestureDetector(
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, ref, details.globalPosition),
      onLongPressStart: (details) =>
          _showContextMenu(context, ref, details.globalPosition),
      child: Material(
        color: tileColor,
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isSelected
                ? BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1,
                  )
                : BorderSide.none,
          ),
          title: Text(
            profile.name,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            _subtitle(),
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
            ),
          ),
          trailing: PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
            ),
            onSelected: (value) => _handleMenuAction(context, ref, value),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'rename',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined, size: 18),
                  title: Text('Rename'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'duplicate',
                child: ListTile(
                  leading: Icon(Icons.copy_outlined, size: 18),
                  title: Text('Duplicate'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, size: 18),
                  title: Text('Delete'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          onTap: () {
            ref.read(currentProfileIdProvider.notifier).select(profile.id);
          },
        ),
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[];
    if (profile.sourcePortId.isNotEmpty) parts.add('Port set');
    if (profile.iwadId.isNotEmpty) parts.add('IWAD set');
    if (profile.pwadList.isNotEmpty) {
      parts.add('${profile.pwadList.length} mods');
    }
    return parts.isEmpty ? 'Empty profile' : parts.join(' · ');
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    if (action == 'rename') _showRenameDialog(context, ref);
    if (action == 'duplicate') _duplicateProfile(ref);
    if (action == 'delete') _confirmDelete(context, ref);
  }

  void _showContextMenu(BuildContext context, WidgetRef ref, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx, position.dy, position.dx + 1, position.dy + 1,
      ),
      items: [
        const PopupMenuItem(
          value: 'rename',
          child: ListTile(
            leading: Icon(Icons.edit_outlined, size: 18),
            title: Text('Rename'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'duplicate',
          child: ListTile(
            leading: Icon(Icons.copy_outlined, size: 18),
            title: Text('Duplicate'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, size: 18),
            title: Text('Delete'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((value) {
      if (value != null && context.mounted) _handleMenuAction(context, ref, value);
    });
  }

  void _duplicateProfile(WidgetRef ref) {
    ref.read(profileListProvider.notifier).duplicate(profile.id);
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: profile.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Profile'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Profile name...'),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              ref.read(profileListProvider.notifier).save(
                profile.copyWith(name: value.trim()),
              );
              Navigator.of(ctx).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(profileListProvider.notifier).save(
                  profile.copyWith(name: name),
                );
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text('Delete "${profile.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(profileListProvider.notifier).delete(profile.id);
              Navigator.of(ctx).pop();
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
