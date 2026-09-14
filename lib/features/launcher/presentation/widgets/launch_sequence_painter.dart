import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/launch_sequence.dart';

/// Paints the launch takeover over the whole window.
///
/// One painter covers every stage so the effect is a single repaint per frame
/// rather than a stack of animated widgets, and so each stage can hand off to
/// the next without a seam.
class LaunchSequencePainter extends CustomPainter {
  final LaunchStage stage;

  /// Progress through the current stage, 0-1.
  final double t;

  /// Where the charge converges and the shockwave starts.
  final Offset? focal;

  LaunchSequencePainter({
    required this.stage,
    required this.t,
    this.focal,
  });

  /// Embers converging on the button. Fixed seed so the field is the same
  /// every launch and nothing is allocated per frame.
  static final List<_Spark> _sparks = List.generate(44, (i) {
    final random = math.Random(7000 + i);
    return _Spark(
      angle: random.nextDouble() * math.pi * 2,
      distance: 0.35 + random.nextDouble() * 0.85,
      size: 0.9 + random.nextDouble() * 2.0,
      lead: random.nextDouble() * 0.45,
      drift: (random.nextDouble() - 0.5) * 0.9,
    );
  });

  Offset _focalFor(Size size) =>
      focal ?? Offset(size.width / 2, size.height * 0.62);

  @override
  void paint(Canvas canvas, Size size) {
    switch (stage) {
      case LaunchStage.idle:
      case LaunchStage.summary:
        return;
      case LaunchStage.arm:
        _paintScrim(canvas, size, 0.38 * t);
        _paintFocalGlow(canvas, size, t * 0.5);
      case LaunchStage.charge:
        _paintScrim(canvas, size, 0.38 + 0.16 * t);
        _paintFocalGlow(canvas, size, 0.5 + 0.5 * t);
        _paintSparks(canvas, size, t);
        _paintChargeRing(canvas, size, t);
      case LaunchStage.ignite:
        _paintScrim(canvas, size, 0.54);
        _paintShockwave(canvas, size, t);
        _paintFlash(canvas, size, t);
      case LaunchStage.handoff:
        _paintCollapse(canvas, size, t);
      case LaunchStage.running:
        canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
      case LaunchStage.returning:
        // The power-on is the collapse run backwards.
        _paintCollapse(canvas, size, 1 - t);
      case LaunchStage.fault:
        _paintFault(canvas, size, t);
    }
  }

  void _paintScrim(Canvas canvas, Size size, double alpha) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: alpha.clamp(0.0, 1.0)),
    );
  }

  /// A pool of light under the launch control, so the shell reads as dimmed
  /// around the one thing that is now live.
  void _paintFocalGlow(Canvas canvas, Size size, double intensity) {
    if (intensity <= 0) return;
    final centre = _focalFor(size);
    final radius = size.shortestSide * 0.42;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(centre, radius, [
          AppColors.primary.withValues(alpha: 0.26 * intensity),
          AppColors.primary.withValues(alpha: 0.0),
        ], [0.0, 1.0]),
    );
  }

  void _paintSparks(Canvas canvas, Size size, double t) {
    final centre = _focalFor(size);
    final reach = size.shortestSide * 0.55;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final spark in _sparks) {
      // Each spark starts its run at a slightly different moment.
      final local = ((t - spark.lead) / (1 - spark.lead)).clamp(0.0, 1.0);
      if (local <= 0) continue;

      // Ease in: slow drift, then snapped into the centre.
      final eased = local * local;
      final distance = reach * spark.distance * (1 - eased);
      final angle = spark.angle + spark.drift * eased;

      final position = centre +
          Offset(math.cos(angle) * distance, math.sin(angle) * distance);

      // Bright as they arrive, then consumed.
      final alpha = (local < 0.85 ? local : (1 - local) / 0.15).clamp(0.0, 1.0);

      paint.color =
          Color.lerp(AppColors.secondary, Colors.white, eased * 0.7)!
              .withValues(alpha: alpha * 0.9);
      canvas.drawCircle(position, spark.size * (1 - eased * 0.4), paint);
    }
  }

  void _paintChargeRing(Canvas canvas, Size size, double t) {
    final centre = _focalFor(size);
    final radius = 34.0 + 10 * t;
    final rect = Rect.fromCircle(center: centre, radius: radius);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * t,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = AppColors.primary.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * t,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(AppColors.primary, Colors.white, 0.55)!,
    );
  }

  /// The blast ring.
  ///
  /// Built from nested even-odd annulus paths rather than stroked circles.
  /// A large-radius stroked circle rasterises as its filled bounding box on
  /// the software renderer this was verified against — a white rectangle over
  /// the window — while filled annulus paths come out clean. The annulus is
  /// equivalent geometry and safe on any backend, so there is no reason to
  /// depend on the stroke behaving.
  void _paintShockwave(Canvas canvas, Size size, double t) {
    final centre = _focalFor(size);
    final maxRadius = size.longestSide * 0.95;
    // Fast out of the gate, then decelerating.
    final radius = maxRadius * math.sqrt(t);
    if (radius < 2) return;

    final fade = (1 - t).clamp(0.0, 1.0);
    final spread = 10 + 54 * fade;
    const bands = 5;

    // Widest and faintest first, so the bright core lands on top.
    for (var i = bands; i >= 1; i--) {
      final k = i / bands;
      final half = math.max(1.0, spread * k);
      _fillAnnulus(
        canvas,
        centre,
        inner: radius - half,
        outer: radius + half,
        color: Color.lerp(AppColors.secondary, Colors.white, 1 - k)!
            .withValues(alpha: (0.07 + 0.34 * (1 - k)) * fade),
      );
    }

    // A crisp edge on the wavefront so the blast has a leading line.
    _fillAnnulus(
      canvas,
      centre,
      inner: radius - 1.4,
      outer: radius + 1.4,
      color: Colors.white.withValues(alpha: 0.78 * fade),
    );
  }

  static void _fillAnnulus(
    Canvas canvas,
    Offset centre, {
    required double inner,
    required double outer,
    required Color color,
  }) {
    if (outer <= 0) return;
    final path = Path()..fillType = PathFillType.evenOdd;
    path.addOval(Rect.fromCircle(center: centre, radius: outer));
    if (inner > 0) {
      path.addOval(Rect.fromCircle(center: centre, radius: inner));
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  /// A hard white spike, gone well before the stage ends. Short is what makes
  /// it read as ignition rather than a wash.
  void _paintFlash(Canvas canvas, Size size, double t) {
    final intensity =
        t < 0.10 ? t / 0.10 : math.max(0.0, 1 - (t - 0.10) / 0.34);
    if (intensity <= 0) return;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = Color.lerp(AppColors.secondary, Colors.white, 0.92)!
            .withValues(alpha: 0.80 * intensity * intensity),
    );
  }

  /// CRT power-down: the picture squeezes to a bright horizontal line, then
  /// the line pinches out sideways. Run with a falling t it becomes power-on.
  void _paintCollapse(Canvas canvas, Size size, double t) {
    final clamped = t.clamp(0.0, 1.0);
    final centreY = size.height / 2;

    // First 70% closes the vertical slot, the rest pinches the line.
    final squeeze = (clamped / 0.7).clamp(0.0, 1.0);
    final pinch = ((clamped - 0.7) / 0.3).clamp(0.0, 1.0);

    final halfHeight = (size.height / 2) * (1 - squeeze);
    final black = Paint()..color = Colors.black;

    canvas.drawRect(
      Rect.fromLTRB(0, 0, size.width, centreY - halfHeight),
      black,
    );
    canvas.drawRect(
      Rect.fromLTRB(0, centreY + halfHeight, size.width, size.height),
      black,
    );

    if (clamped <= 0) return;

    final lineWidth = size.width * (1 - pinch);
    if (lineWidth <= 0) {
      canvas.drawRect(Offset.zero & size, black);
      return;
    }

    final left = (size.width - lineWidth) / 2;
    final thickness = 2.0 + 6.0 * squeeze;
    final line = Rect.fromLTWH(
      left,
      centreY - thickness / 2,
      lineWidth,
      thickness,
    );

    canvas.drawRect(
      line.inflate(6),
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.6 * squeeze)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawRect(
      line,
      Paint()..color = Colors.white.withValues(alpha: 0.92 * squeeze),
    );
  }

  /// The spawn failed: a red wash that pulses once and clears, leaving the
  /// shell visible and the error on screen.
  void _paintFault(Canvas canvas, Size size, double t) {
    final intensity = t < 0.2 ? t / 0.2 : math.max(0.0, 1 - (t - 0.2) / 0.8);
    if (intensity <= 0) return;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.32 * intensity),
    );

    final centre = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(centre, size.longestSide * 0.7, [
          Colors.transparent,
          AppColors.error.withValues(alpha: 0.5 * intensity),
        ], [0.35, 1.0]),
    );
  }

  @override
  bool shouldRepaint(covariant LaunchSequencePainter oldDelegate) {
    return oldDelegate.stage != stage ||
        oldDelegate.t != t ||
        oldDelegate.focal != focal;
  }
}

class _Spark {
  final double angle;
  final double distance;
  final double size;
  final double lead;
  final double drift;

  const _Spark({
    required this.angle,
    required this.distance,
    required this.size,
    required this.lead,
    required this.drift,
  });
}
