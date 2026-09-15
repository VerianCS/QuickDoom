import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/launch_sequence.dart';
import '../providers/launch_sequence_provider.dart';
import 'launch_sequence_painter.dart';

/// Sits above the whole shell, including the title bar, and plays the launch
/// takeover.
///
/// The stage machine emits discrete stages; this animates 0-1 across whichever
/// stage is current, using the same timings the machine used to schedule it.
class LaunchSequenceOverlay extends ConsumerStatefulWidget {
  /// Stage durations, matched to the ones the sequence was run with.
  final LaunchTimings timings;

  const LaunchSequenceOverlay({
    super.key,
    this.timings = LaunchTimings.standard,
  });

  @override
  ConsumerState<LaunchSequenceOverlay> createState() =>
      _LaunchSequenceOverlayState();
}

class _LaunchSequenceOverlayState extends ConsumerState<LaunchSequenceOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  LaunchStage _lastStage = LaunchStage.idle;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Restarts the 0-1 run whenever the machine moves to a new stage.
  void _onStage(LaunchStage stage) {
    if (stage == _lastStage) return;
    _lastStage = stage;

    final duration = stage == LaunchStage.fault
        ? const Duration(milliseconds: 700)
        : widget.timings.forStage(stage);

    if (duration <= Duration.zero) {
      _controller
        ..duration = const Duration(milliseconds: 1)
        ..value = 1;
      return;
    }

    _controller
      ..duration = duration
      ..forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final sequence = ref.watch(launchSequenceProvider);

    // Scheduling the controller during build would fight the frame; the stage
    // change is applied after it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onStage(sequence.stage);
    });

    if (sequence.stage == LaunchStage.idle) return const SizedBox.shrink();

    final showReadout =
        sequence.stage == LaunchStage.summary && sequence.summary != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (sequence.isTakingOver)
          IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: LaunchSequencePainter(
                    stage: sequence.stage,
                    t: _controller.value,
                    focal: sequence.focal,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        if (showReadout)
          _SessionReadout(
            summary: sequence.summary!,
            onDismiss: () =>
                ref.read(launchSequenceProvider.notifier).dismissSummary(),
          ),
      ],
    );
  }
}

/// What the session was, once the game exits.
class _SessionReadout extends StatelessWidget {
  final LaunchSummary summary;
  final VoidCallback onDismiss;

  const _SessionReadout({required this.summary, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final accent = summary.ok ? AppColors.success : AppColors.error;

    // The overlay sits outside the router's Scaffold, so without a Material
    // ancestor every Text here renders with debug underlines.
    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onTap: onDismiss,
          behavior: HitTestBehavior.opaque,
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.62),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: accent.withValues(alpha: 0.55)),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.18),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        color: accent.withValues(alpha: 0.14),
                        child: Row(
                          children: [
                            Icon(
                              summary.ok
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              size: 16,
                              color: accent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              summary.ok ? 'SESSION ENDED' : 'SESSION FAULTED',
                              style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'exit ${summary.exitCode}',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: AppColors.onBackground.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Column(
                          children: [
                            _Row(label: 'Port', value: summary.portName),
                            _Row(label: 'IWAD', value: summary.iwadName),
                            _Row(
                              label: 'Mods',
                              value: summary.modCount == 0
                                  ? 'none'
                                  : '${summary.modCount} loaded',
                            ),
                            _Row(label: 'Played', value: summary.playTimeLabel),
                          ],
                        ),
                      ),
                      if (summary.errorLines.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.consoleBg,
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final line in summary.errorLines)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    line,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: AppColors.error,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: onDismiss,
                            child: const Text('Dismiss'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.onBackground.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: AppColors.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
