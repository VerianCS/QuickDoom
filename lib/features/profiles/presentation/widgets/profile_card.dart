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

    return Material(
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
        trailing: IconButton(
          icon: Icon(
            Icons.delete_outline,
            size: 18,
            color: Theme.of(context).colorScheme.error.withAlpha(153),
          ),
          onPressed: () => _confirmDelete(context, ref),
        ),
        onTap: () {
          ref.read(currentProfileIdProvider.notifier).select(profile.id);
        },
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
              ref.read(currentProfileIdProvider.notifier).clear();
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
