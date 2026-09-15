import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../app/widgets/notched_panel.dart';
import '../providers/launch_provider.dart';
import '../providers/launch_sequence_provider.dart';
import '../providers/path_problem_provider.dart';

/// The anchor of the launcher: a wide plate that lights when the bench is
/// loaded and the app is actually able to fire.
///
/// It also reports its own centre to the sequence, so the charge and the
/// shockwave originate from the control the user pressed rather than from the
/// middle of the window.
class QuickLaunchBar extends ConsumerStatefulWidget {
  final bool canLaunch;
  final bool isLaunching;

  /// Called with false when the platform asks for reduced motion.
  final void Function({required bool animate}) onLaunch;

  const QuickLaunchBar({
    super.key,
    required this.canLaunch,
    required this.isLaunching,
    required this.onLaunch,
  });

  @override
  ConsumerState<QuickLaunchBar> createState() => _QuickLaunchBarState();
}

class _QuickLaunchBarState extends ConsumerState<QuickLaunchBar> {
  final _buttonKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reportFocal();
  }

  /// Pushes the plate's centre in global coordinates into the sequence.
  void _reportFocal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      ref
          .read(launchSequenceProvider.notifier)
          .setFocal(box.localToGlobal(box.size.center(Offset.zero)));
    });
  }

  @override
  Widget build(BuildContext context) {
    _reportFocal();

    final sequence = ref.watch(launchSequenceProvider);
    final enabled = widget.canLaunch && !widget.isLaunching;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.dividerColor)),
      ),
      child: Row(
        children: [
          const Expanded(child: _Readiness()),
          const SizedBox(width: 12),
          const _SequenceToggle(),
          const SizedBox(width: 12),
          SizedBox(
            key: _buttonKey,
            width: 240,
            height: 52,
            child: _LaunchPlate(
              enabled: enabled,
              busy: widget.isLaunching,
              armed: sequence.isArmed,
              onPressed: () => widget.onLaunch(
                animate:
                    !(MediaQuery.maybeOf(context)?.disableAnimations ?? false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Says what is still missing, so a dark plate is never a mystery.
class _Readiness extends ConsumerWidget {
  const _Readiness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(launchNotifierProvider);

    // Each phrase carries its own article, because "a" and "an" do not
    // alternate with position: one missing IWAD read as "Seat a IWAD to arm".
    final missing = <String>[
      if (state.sourcePort == null) 'a source port',
      if (state.iwad == null) 'an IWAD',
    ];

    // A seated file can still be gone. Without this the slot showed the
    // warning while the plate underneath it went on saying "Ready to fire",
    // and the anchor is the thing people read.
    final broken = <String>[
      if (state.sourcePort != null &&
          ref
                  .watch(portProblemProvider(state.sourcePort!.executablePath))
                  .valueOrNull !=
              null)
        'source port',
      if (state.iwad != null &&
          ref.watch(iwadProblemProvider(state.iwad!.path)).valueOrNull != null)
        'IWAD',
    ];

    final (text, colour) = readinessLine(missing: missing, broken: broken);

    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: colour),
          ),
        ),
      ],
    );
  }
}

/// What the plate says about the bench.
///
/// Pulled out of the widget because the interesting cases are all about which
/// sentence wins: a file that is seated but gone used to lose to "Ready to
/// fire", so the slot showed a warning while the plate invited a launch.
@visibleForTesting
(String, Color) readinessLine({
  required List<String> missing,
  required List<String> broken,
}) {
  if (missing.isNotEmpty) {
    return ('Seat ${missing.join(' and ')} to arm', AppColors.onSurfaceFaint);
  }
  if (broken.isNotEmpty) {
    return (
      'The ${broken.join(' and ')} cannot be run — check the slot above',
      AppColors.caution,
    );
  }
  return ('Ready to fire', AppColors.success);
}

class _LaunchPlate extends StatefulWidget {
  final bool enabled;
  final bool busy;
  final bool armed;
  final VoidCallback onPressed;

  const _LaunchPlate({
    required this.enabled,
    required this.busy,
    required this.armed,
    required this.onPressed,
  });

  @override
  State<_LaunchPlate> createState() => _LaunchPlateState();
}

class _LaunchPlateState extends State<_LaunchPlate> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final live = widget.enabled || widget.armed;

    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.enabled
            ? () {
                setState(() => _pressed = false);
                widget.onPressed();
              }
            : null,
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.standard,
          decoration: BoxDecoration(
            boxShadow: widget.armed
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.55),
                      blurRadius: 26,
                      spreadRadius: 1,
                    ),
                  ]
                : live && _hovered
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.30),
                          blurRadius: 18,
                        ),
                      ]
                    : const [],
          ),
          child: CustomPaint(
            painter: _PlatePainter(
              live: live,
              hovered: _hovered,
              pressed: _pressed || widget.armed,
            ),
            child: Center(
              child: widget.busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.core,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'LAUNCH',
                          style: TextStyle(
                            fontFamily: AppFonts.doomLeft,
                            fontSize: 21,
                            letterSpacing: 2.4,
                            color: live
                                ? AppColors.core
                                : AppColors.onSurfaceFaint,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'CTRL+L',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            letterSpacing: 0.5,
                            color: live
                                ? AppColors.core.withValues(alpha: 0.55)
                                : AppColors.onSurfaceFaint
                                    .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatePainter extends CustomPainter {
  final bool live;
  final bool hovered;
  final bool pressed;

  const _PlatePainter({
    required this.live,
    required this.hovered,
    required this.pressed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = NotchedPanel.buildPath(size, AppShape.notch);

    final top = live
        ? Color.lerp(AppColors.primary, AppColors.core, hovered ? 0.22 : 0.08)!
        : AppColors.surfaceHigh;
    final bottom = live
        ? Color.lerp(AppColors.primary, AppColors.void_, 0.35)!
        : AppColors.surface;

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: pressed ? Alignment.bottomCenter : Alignment.topCenter,
          end: pressed ? Alignment.topCenter : Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = live
            ? AppColors.core.withValues(alpha: hovered ? 0.5 : 0.28)
            : AppColors.dividerColor,
    );

    // The filament along the top edge — the plate's own light source.
    if (live) {
      canvas.drawRect(
        Rect.fromLTWH(AppShape.notch, 0, size.width - AppShape.notch, 1.5),
        Paint()
          ..color = AppColors.core.withValues(alpha: hovered ? 0.85 : 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(_PlatePainter oldDelegate) =>
      oldDelegate.live != live ||
      oldDelegate.hovered != hovered ||
      oldDelegate.pressed != pressed;
}

/// Lets someone who launches dozens of times an hour turn the takeover off.
class _SequenceToggle extends ConsumerWidget {
  const _SequenceToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(launchAnimationEnabledProvider);

    return IconButton(
      tooltip: enabled
          ? 'Launch animation on — click to skip it'
          : 'Launch animation off',
      visualDensity: VisualDensity.compact,
      iconSize: 17,
      onPressed: () =>
          ref.read(launchAnimationEnabledProvider.notifier).toggle(),
      icon: Icon(
        enabled ? Icons.auto_awesome : Icons.auto_awesome_outlined,
        color: enabled ? AppColors.primary : AppColors.onSurfaceFaint,
      ),
    );
  }
}
