import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import 'notched_panel.dart';

/// How prominent a button is.
enum DoomButtonVariant {
  /// The one action a screen is about.
  primary,

  /// Everything else.
  ghost,

  /// Destructive.
  danger,
}

/// A cut-metal button.
///
/// Its states are lit rather than raised: hover warms the edge, pressing sinks
/// the fill, and [armed] holds it glowing for a control that is live — the
/// launch plate during a takeover, say. No drop shadows; light in this app
/// comes from emission.
class DoomButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final DoomButtonVariant variant;

  /// Holds the lit state on regardless of pointer.
  final bool armed;

  /// Fills the available width instead of hugging the label.
  final bool expand;

  /// Shown instead of the label, for work in flight.
  final bool busy;

  /// Small print on the right of the plate, e.g. a shortcut.
  final String? hint;

  const DoomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = DoomButtonVariant.ghost,
    this.armed = false,
    this.expand = false,
    this.busy = false,
    this.hint,
  });

  @override
  State<DoomButton> createState() => _DoomButtonState();
}

class _DoomButtonState extends State<DoomButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.busy;

  Color get _accent => switch (widget.variant) {
        DoomButtonVariant.primary => AppColors.primary,
        DoomButtonVariant.ghost => AppColors.primary,
        DoomButtonVariant.danger => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    final lit = _enabled && (_hovered || widget.armed);
    final accent = _accent;

    final Color fill;
    final Color border;
    final Color foreground;

    if (!_enabled) {
      fill = AppColors.surface;
      border = AppColors.dividerSoft;
      foreground = AppColors.onSurfaceFaint;
    } else if (widget.variant == DoomButtonVariant.primary) {
      fill = _pressed
          ? Color.lerp(accent, AppColors.void_, 0.35)!
          : lit
              ? Color.lerp(accent, AppColors.core, 0.16)!
              : accent;
      border = lit ? AppColors.core : Color.lerp(accent, AppColors.core, 0.25)!;
      foreground = AppColors.onPrimary;
    } else {
      fill = _pressed
          ? AppColors.void_
          : lit
              ? accent.withValues(alpha: 0.16)
              : AppColors.surface;
      border = lit ? accent : AppColors.dividerColor;
      foreground = lit ? accent : AppColors.onSurface;
    }

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.busy)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        else if (widget.icon != null)
          Icon(widget.icon, size: 15, color: foreground),
        if (widget.busy || widget.icon != null) const SizedBox(width: 8),
        Text(
          widget.label.toUpperCase(),
          style: TextStyle(
            fontFamily: AppFonts.doomText,
            fontSize: 13,
            letterSpacing: 1.5,
            color: foreground,
          ),
        ),
        if (widget.hint != null) ...[
          const SizedBox(width: 10),
          Text(
            widget.hint!,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.8,
              color: foreground.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );

    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel:
            _enabled ? () => setState(() => _pressed = false) : null,
        onTap: _enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          decoration: BoxDecoration(
            boxShadow: lit
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 16,
                    ),
                  ]
                : const [],
          ),
          child: CustomPaint(
            painter: _ButtonPainter(fill: fill, border: border),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonPainter extends CustomPainter {
  final Color fill;
  final Color border;

  const _ButtonPainter({required this.fill, required this.border});

  @override
  void paint(Canvas canvas, Size size) {
    final path = NotchedPanel.buildPath(size, AppShape.notchSmall);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );
  }

  @override
  bool shouldRepaint(_ButtonPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.border != border;
}
