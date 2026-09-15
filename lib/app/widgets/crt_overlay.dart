import 'package:flutter/material.dart';

/// Scanlines and a vignette — the CRT treatment shared by the boot splash, the
/// map viewer hologram and the console.
///
/// This lived as a private painter in two places before; a third use would
/// have made three copies of the same constants drifting apart.
class CrtOverlay {
  const CrtOverlay._();

  /// Gap between scanlines, in logical pixels.
  static const double lineSpacing = 3;

  /// Paints horizontal scanlines across [size].
  static void paintScanlines(
    Canvas canvas,
    Size size, {
    double opacity = 0.16,
  }) {
    if (opacity <= 0) return;
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: opacity)
      ..strokeWidth = 1;

    for (var y = 0.0; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  /// Darkens the corners so the middle of the screen reads as the lit part.
  static void paintVignette(
    Canvas canvas,
    Size size, {
    double opacity = 0.55,
    double start = 0.62,
  }) {
    if (opacity <= 0) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: opacity),
          ],
          stops: [start, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  /// Both, in the order they should be drawn.
  static void paint(
    Canvas canvas,
    Size size, {
    double scanlineOpacity = 0.16,
    double vignetteOpacity = 0.55,
    double vignetteStart = 0.62,
  }) {
    paintScanlines(canvas, size, opacity: scanlineOpacity);
    paintVignette(
      canvas,
      size,
      opacity: vignetteOpacity,
      start: vignetteStart,
    );
  }
}

/// A widget that lays the CRT treatment over whatever is behind it.
class CrtOverlayLayer extends StatelessWidget {
  final double scanlineOpacity;
  final double vignetteOpacity;

  const CrtOverlayLayer({
    super.key,
    this.scanlineOpacity = 0.16,
    this.vignetteOpacity = 0.55,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _CrtOverlayPainter(
          scanlineOpacity: scanlineOpacity,
          vignetteOpacity: vignetteOpacity,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _CrtOverlayPainter extends CustomPainter {
  final double scanlineOpacity;
  final double vignetteOpacity;

  const _CrtOverlayPainter({
    required this.scanlineOpacity,
    required this.vignetteOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    CrtOverlay.paint(
      canvas,
      size,
      scanlineOpacity: scanlineOpacity,
      vignetteOpacity: vignetteOpacity,
    );
  }

  @override
  bool shouldRepaint(_CrtOverlayPainter oldDelegate) {
    return oldDelegate.scanlineOpacity != scanlineOpacity ||
        oldDelegate.vignetteOpacity != vignetteOpacity;
  }
}
