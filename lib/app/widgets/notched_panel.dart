import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A plate with two corners cut at 45 degrees.
///
/// The app's surfaces are cut metal, not web cards: a rounded rectangle reads
/// as a browser, an angled cut reads as equipment. The cut is on opposite
/// corners so a column of panels has a consistent diagonal rhythm.
class NotchedPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Size of the corner cut. Controls use [AppShape.notchSmall].
  final double notch;

  final Color? background;
  final Color? borderColor;

  /// Lifts the panel and warms the border, for a panel that is selected or
  /// holding something live.
  final bool highlighted;

  /// The notched outline for a box of [size].
  ///
  /// Shared so buttons and chips are cut the same way as panels.
  static Path buildPath(Size size, double notch) {
    final cut = notch.clamp(0.0, size.shortestSide / 2);
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, cut)
      ..close();
  }

  const NotchedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.notch = AppShape.notch,
    this.background,
    this.borderColor,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final border = borderColor ??
        (highlighted
            ? AppColors.primary.withValues(alpha: 0.55)
            : AppColors.dividerColor);

    final fill = background ??
        (highlighted ? AppColors.surfaceHigh : AppColors.surface);

    return CustomPaint(
      painter: _NotchedPanelPainter(
        notch: notch,
        border: border,
        fill: fill,
        highlighted: highlighted,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _NotchedPanelPainter extends CustomPainter {
  final double notch;
  final Color border;
  final Color fill;
  final bool highlighted;

  const _NotchedPanelPainter({
    required this.notch,
    required this.border,
    required this.fill,
    required this.highlighted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = NotchedPanel.buildPath(size, notch);

    // A vertical ramp rather than a flat fill: light falls from above, which
    // is what makes the surface read as a plate rather than a rectangle.
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(fill, AppColors.core, highlighted ? 0.06 : 0.03)!,
            fill,
            Color.lerp(fill, AppColors.void_, 0.35)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );
  }

  @override
  bool shouldRepaint(_NotchedPanelPainter oldDelegate) {
    return oldDelegate.notch != notch ||
        oldDelegate.border != border ||
        oldDelegate.fill != fill ||
        oldDelegate.highlighted != highlighted;
  }
}
