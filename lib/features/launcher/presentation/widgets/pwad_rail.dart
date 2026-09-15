import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../app/widgets/notched_panel.dart';
import '../../../../app/widgets/section_rule.dart';
import '../../../../core/services/file_picker_service.dart';
import '../../../../domain/entities/pwad.dart';
import '../providers/launch_provider.dart';

/// The mod stack, as a load order rather than a list.
///
/// Doom resolves duplicate lumps by load order, so which file wins is decided
/// by position. A plain list buries that: numbering each slot down a rail and
/// marking the last one as the winner makes the rule visible.
class PwadRail extends ConsumerWidget {
  const PwadRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pwads = ref.watch(launchNotifierProvider.select((s) => s.pwads));
    final active = pwads.where((p) => p.isEnabled).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionRule(
          label: 'Load Order',
          note: pwads.isEmpty
              ? 'empty'
              : '$active of ${pwads.length} active',
          trailing: _AddButton(onPressed: () => _addFiles(ref)),
        ),
        const SizedBox(height: 10),
        if (pwads.isEmpty)
          const _EmptyRail()
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pwads.length,
            onReorderItem: (oldIndex, newIndex) => ref
                .read(launchNotifierProvider.notifier)
                .movePwad(oldIndex, newIndex),
            proxyDecorator: (child, index, animation) =>
                Material(color: Colors.transparent, child: child),
            itemBuilder: (context, index) {
              final pwad = pwads[index];
              return Padding(
                key: ValueKey(pwad.id),
                padding: const EdgeInsets.only(bottom: 5),
                child: _PwadSlot(
                  pwad: pwad,
                  index: index,
                  isLast: index == pwads.length - 1,
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _addFiles(WidgetRef ref) async {
    final paths = await FilePickerService().pickMultipleFiles(
      allowedExtensions: [
        'wad', 'pk3', 'pk7', 'ipk3', 'ipk7', 'deh', 'bex', 'zip',
      ],
      dialogTitle: 'Select Mod Files',
    );
    if (paths.isEmpty) return;

    ref.read(launchNotifierProvider.notifier).addPwads(
          paths.map((p) => Pwad(id: const Uuid().v4(), path: p)).toList(),
        );
  }
}

class _PwadSlot extends ConsumerWidget {
  final Pwad pwad;
  final int index;

  /// The deepest file in the order, so the one whose lumps survive.
  final bool isLast;

  const _PwadSlot({
    required this.pwad,
    required this.index,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(launchNotifierProvider.notifier);
    final on = pwad.isEnabled;
    final fileName = pwad.path.split('\\').last.split('/').last;

    return CustomPaint(
      painter: _SlotPainter(enabled: on),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 10, 5, 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.drag_indicator,
                      size: 16,
                      color: AppColors.onSurfaceFaint,
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 20,
                      child: Text(
                        // Monospace, not the display face: the index is the
                        // whole point of the rail, and the Doom cut has no
                        // legible digits at this size.
                        (index + 1).toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          color: on
                              ? AppColors.primary
                              : AppColors.onSurfaceFaint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          InkWell(
            onTap: () => notifier.togglePwad(pwad.id),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                on ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
                color: on ? AppColors.primary : AppColors.onSurfaceFaint,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: on ? AppColors.onSurface : AppColors.onSurfaceFaint,
              ),
            ),
          ),
          if (isLast && on) ...[
            Tooltip(
              message: 'Loaded last — its lumps override the ones above',
              child: Text(
                'TOP',
                style: TextStyle(
                  fontFamily: AppFonts.doomText,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          InkWell(
            onTap: () => notifier.removePwad(pwad.id),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.close, size: 15, color: AppColors.onBackground),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _SlotPainter extends CustomPainter {
  final bool enabled;

  const _SlotPainter({required this.enabled});

  @override
  void paint(Canvas canvas, Size size) {
    final path = NotchedPanel.buildPath(size, AppShape.notchSmall);

    canvas.drawPath(
      path,
      Paint()..color = enabled ? AppColors.surface : AppColors.background,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.dividerSoft,
    );

    // The rail: a lit spine down the left of an active slot.
    if (enabled) {
      canvas.drawRect(
        Rect.fromLTWH(0, 2, 2, size.height - 4),
        Paint()..color = AppColors.primary.withValues(alpha: 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(_SlotPainter oldDelegate) =>
      oldDelegate.enabled != enabled;
}

class _EmptyRail extends StatelessWidget {
  const _EmptyRail();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: NotchedPanel(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
        background: AppColors.background,
        borderColor: AppColors.dividerSoft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.download_outlined,
              size: 20,
              color: AppColors.onSurfaceFaint,
            ),
            const SizedBox(height: 8),
            const Text(
              'Nothing loaded — drop WAD or PK3 files anywhere',
              style: TextStyle(color: AppColors.onSurfaceFaint, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _AddButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 15, color: AppColors.primary),
            SizedBox(width: 4),
            Text(
              'ADD',
              style: TextStyle(
                fontFamily: AppFonts.doomText,
                fontSize: 11,
                letterSpacing: 1.2,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
