import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../domain/entities/launch_profile.dart';
import '../providers/profile_provider.dart';

/// One tab in the profile rack.
///
/// The selected profile is seated: its left edge lights and the tab reaches
/// toward the bench, so the rack reads as a row of switches down the edge of
/// the machine rather than as a list of documents.
class ProfileCard extends ConsumerStatefulWidget {
  final LaunchProfile profile;
  final bool isSelected;

  const ProfileCard({
    super.key,
    required this.profile,
    required this.isSelected,
  });

  @override
  ConsumerState<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<ProfileCard> {
  bool _hovered = false;

  LaunchProfile get profile => widget.profile;

  @override
  Widget build(BuildContext context) {
    final selected = widget.isSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () =>
            ref.read(currentProfileIdProvider.notifier).select(profile.id),
        onSecondaryTapDown: (d) =>
            _showContextMenu(context, ref, d.globalPosition),
        onLongPressStart: (d) =>
            _showContextMenu(context, ref, d.globalPosition),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          padding: const EdgeInsets.fromLTRB(0, 8, 4, 9),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.11)
                : _hovered
                    ? AppColors.surfaceHigh
                    : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: selected
                    ? AppColors.primary
                    : _hovered
                        ? AppColors.dividerColor
                        : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: selected
                            ? AppColors.primary
                            : AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.onSurfaceFaint,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hovered || selected)
                PopupMenuButton<String>(
                  tooltip: 'Profile actions',
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(
                    Icons.more_horiz,
                    color: AppColors.onBackground,
                  ),
                  onSelected: (v) => _handleMenuAction(context, ref, v),
                  itemBuilder: (_) => _menuItems,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static const List<PopupMenuEntry<String>> _menuItems = [
    PopupMenuItem(value: 'rename', child: Text('Rename')),
    PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
    PopupMenuItem(value: 'delete', child: Text('Delete')),
  ];

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
