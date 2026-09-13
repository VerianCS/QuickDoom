import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Animated boot screen shown while the app hydrates.
///
/// Drives every effect from one controller, so the whole screen costs a single
/// repaint per frame. The splash stays up for at least [minimumDuration] once
/// shown — a launcher that boots in ~120 ms would otherwise flash the screen
/// for two frames — then fades out and calls [onFinished].
class BootSplash extends StatefulWidget {
  /// Set once the bootstrap pipeline has finished its work.
  final bool bootComplete;

  /// Called after the fade-out completes; the splash can be torn down here.
  final VoidCallback onFinished;

  /// Current boot phase, rendered under the progress bar.
  final String status;

  final Duration minimumDuration;
  final Duration fadeOutDuration;

  const BootSplash({
    super.key,
    required this.bootComplete,
    required this.onFinished,
    this.status = 'Starting…',
    this.minimumDuration = const Duration(milliseconds: 1100),
    this.fadeOutDuration = const Duration(milliseconds: 420),
  });

  @override
  State<BootSplash> createState() => _BootSplashState();
}

class _BootSplashState extends State<BootSplash>
    with TickerProviderStateMixin {
  /// Free-running clock for embers, flicker and the progress sweep.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  /// Drives both the intro fade-in and the exit fade-out.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
    reverseDuration: widget.fadeOutDuration,
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _reveal,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  late final Animation<double> _rise = Tween<double>(begin: 18, end: 0).animate(
    CurvedAnimation(parent: _reveal, curve: Curves.easeOutCubic),
  );

  final Stopwatch _shownFor = Stopwatch();
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _shownFor.start();
    _reveal.forward();
    if (widget.bootComplete) _scheduleDismiss();
  }

  @override
  void didUpdateWidget(BootSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bootComplete && !oldWidget.bootComplete) _scheduleDismiss();
  }

  /// Waits out the remainder of [BootSplash.minimumDuration], then fades out.
  void _scheduleDismiss() {
    if (_dismissing) return;
    _dismissing = true;

    final remaining = widget.minimumDuration - _shownFor.elapsed;
    final delay = remaining.isNegative ? Duration.zero : remaining;

    Future<void>.delayed(delay, () async {
      if (!mounted) return;
      await _reveal.reverse();
      if (!mounted) return;
      _loop.stop();
      widget.onFinished();
    });
  }

  @override
  void dispose() {
    _loop.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect the platform's reduced-motion setting: the screen still fades,
    // but embers, flicker and the sweep hold still.
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Material(
      color: AppColors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _SplashBackdrop(),
          if (!reduceMotion)
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _loop,
                builder: (context, _) => CustomPaint(
                  painter: _EmberPainter(progress: _loop.value),
                  size: Size.infinite,
                ),
              ),
            ),
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_reveal, _loop]),
              builder: (context, _) {
                return Opacity(
                  opacity: _fade.value,
                  child: Transform.translate(
                    offset: Offset(0, _rise.value),
                    child: _SplashContent(
                      glow: reduceMotion ? 0.85 : _flicker(_loop.value),
                      sweep: reduceMotion ? null : _loop.value,
                      status: widget.status,
                    ),
                  ),
                );
              },
            ),
          ),
          const IgnorePointer(child: _ScanlineOverlay()),
        ],
      ),
    );
  }

  /// Layered sines approximating a guttering flame, in 0.35–1.0.
  static double _flicker(double t) {
    final phase = t * math.pi * 2;
    final a = math.sin(phase * 11.0);
    final b = math.sin(phase * 23.3 + 1.7);
    final c = math.sin(phase * 37.7 + 3.1);
    return (0.78 + 0.14 * a * b + 0.08 * c).clamp(0.35, 1.0);
  }
}

/// Static gradient ground: cheap, and it is what the very first frame shows.
class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, 0.55),
          radius: 1.1,
          colors: [
            Color(0xFF3A1013),
            Color(0xFF221012),
            AppColors.background,
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
    );
  }
}

class _SplashContent extends StatelessWidget {
  /// Title glow strength, 0–1.
  final double glow;

  /// Loop position for the progress sweep, or null to hold it still.
  final double? sweep;

  final String status;

  const _SplashContent({
    required this.glow,
    required this.sweep,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.gamepad,
          size: 46,
          color: Color.lerp(AppColors.primaryDark, AppColors.primary, glow),
        ),
        const SizedBox(height: 18),
        Text(
          'QUICKDOOM',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            letterSpacing: 10,
            color: Color.lerp(const Color(0xFFFFD9D0), Colors.white, glow),
            shadows: [
              Shadow(
                color: AppColors.primary.withValues(alpha: 0.85 * glow),
                blurRadius: 26 * glow,
              ),
              Shadow(
                color: AppColors.secondary.withValues(alpha: 0.45 * glow),
                blurRadius: 54 * glow,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'RIP AND TEAR, INSTANTLY',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 4.5,
            fontWeight: FontWeight.w600,
            color: AppColors.onBackground.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 34),
        _ProgressSweep(sweep: sweep),
        const SizedBox(height: 12),
        Text(
          status,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            color: AppColors.onBackground.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}

/// Indeterminate bar: a bright head sweeping a dim track.
class _ProgressSweep extends StatelessWidget {
  final double? sweep;

  const _ProgressSweep({required this.sweep});

  static const double _width = 260;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: 3,
      child: CustomPaint(
        painter: _SweepPainter(progress: sweep),
      ),
    );
  }
}

class _SweepPainter extends CustomPainter {
  final double? progress;

  const _SweepPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()..color = AppColors.dividerColor.withValues(alpha: 0.5);
    final radius = Radius.circular(size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      track,
    );

    // Held still (reduced motion): show a modest static fill instead.
    if (progress == null) {
      final fill = Paint()..color = AppColors.primary.withValues(alpha: 0.8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width * 0.4, size.height),
          radius,
        ),
        fill,
      );
      return;
    }

    // Ease the head so it lingers at the edges rather than snapping around.
    final t = (math.sin(progress! * math.pi * 2 * 1.5) + 1) / 2;
    const headWidth = 74.0;
    final left = (size.width + headWidth) * t - headWidth;

    final rect = Rect.fromLTWH(left, 0, headWidth, size.height);
    final head = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0x00DC143C),
          AppColors.primary,
          Color(0xFFFF7A5C),
          AppColors.primary,
          Color(0x00DC143C),
        ],
        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(rect);

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, radius));
    canvas.drawRect(rect, head);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SweepPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Embers drifting up from the bottom of the screen.
class _EmberPainter extends CustomPainter {
  final double progress;

  _EmberPainter({required this.progress});

  static const int _count = 30;

  /// Fixed seed: the same ember field every boot, and no allocation per frame.
  static final List<_Ember> _embers = List.generate(_count, (i) {
    final random = math.Random(1993 + i);
    return _Ember(
      x: random.nextDouble(),
      speed: 0.25 + random.nextDouble() * 0.55,
      phase: random.nextDouble(),
      radius: 0.7 + random.nextDouble() * 1.9,
      drift: 0.012 + random.nextDouble() * 0.05,
      wobble: 1.5 + random.nextDouble() * 3.5,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final ember in _embers) {
      // Each ember runs its own loop; 1 - t makes them travel upward.
      final t = (progress * ember.speed + ember.phase) % 1.0;
      final y = size.height * (1.0 - t);

      final wobble =
          math.sin((t * ember.wobble + ember.phase) * math.pi * 2) * ember.drift;
      final x = size.width * (ember.x + wobble);

      // Fade in off the bottom edge and burn out before the top.
      final fadeIn = (t / 0.12).clamp(0.0, 1.0);
      final fadeOut = ((1.0 - t) / 0.45).clamp(0.0, 1.0);
      final alpha = fadeIn * fadeOut * 0.75;
      if (alpha <= 0.01) continue;

      paint.color = Color.lerp(
        AppColors.secondary,
        AppColors.primary,
        t,
      )!
          .withValues(alpha: alpha);

      canvas.drawCircle(Offset(x, y), ember.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_EmberPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Ember {
  final double x;
  final double speed;
  final double phase;
  final double radius;
  final double drift;
  final double wobble;

  const _Ember({
    required this.x,
    required this.speed,
    required this.phase,
    required this.radius,
    required this.drift,
    required this.wobble,
  });
}

/// CRT scanlines plus a vignette, both static.
class _ScanlineOverlay extends StatelessWidget {
  const _ScanlineOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _ScanlinePainter(),
      size: Size.infinite,
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  const _ScanlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..strokeWidth = 1;

    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }

    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.55),
        ],
        stops: const [0.62, 1.0],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(_ScanlinePainter oldDelegate) => false;
}
