import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import 'notched_panel.dart';

/// A small toggle or filter, cut like the panels.
///
/// [tint] carries meaning where the chip stands for something with a colour of
/// its own — a map layer, a download state — so the chip and the thing it
/// controls read as the same object.
class DoomChip extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final Color? tint;

  const DoomChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.tint,
  });

  @override
  State<DoomChip> createState() => _DoomChipState();
}

class _DoomChipState extends State<DoomChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tint = widget.tint ?? AppColors.primary;
    final active = widget.selected;
    final lit = active || _hovered;

    final foreground = active
        ? tint
        : _hovered
            ? AppColors.onSurface
            : AppColors.onBackground;

    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: CustomPaint(
          painter: _ChipPainter(
            fill: active
                ? tint.withValues(alpha: 0.16)
                : _hovered
                    ? AppColors.surfaceHigh
                    : Colors.transparent,
            border: lit
                ? tint.withValues(alpha: active ? 0.7 : 0.4)
                : AppColors.dividerColor,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 13, color: foreground),
                  const SizedBox(width: 6),
                ],
                Text(
                  widget.label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AppFonts.doomText,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipPainter extends CustomPainter {
  final Color fill;
  final Color border;

  const _ChipPainter({required this.fill, required this.border});

  @override
  void paint(Canvas canvas, Size size) {
    final path = NotchedPanel.buildPath(size, 6);
    if (fill.a > 0) canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );
  }

  @override
  bool shouldRepaint(_ChipPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.border != border;
}
