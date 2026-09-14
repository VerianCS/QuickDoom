import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../providers/launch_sequence_provider.dart';

/// Footer bar carrying the launch control.
///
/// Reports the button's position to the sequence so the charge and shockwave
/// originate from the control the user pressed rather than the middle of the
/// window.
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

  /// Pushes the button's centre in global coordinates into the sequence.
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
    final armed = sequence.isArmed;
    final enabled = widget.canLaunch && !widget.isLaunching;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.keyboard,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
          ),
          const SizedBox(width: 8),
          Text(
            'Ctrl+L to launch',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
              fontSize: 12,
            ),
          ),
          const Spacer(),
          const _SequenceToggle(),
          const SizedBox(width: 8),
          AnimatedContainer(
            key: _buttonKey,
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              boxShadow: armed
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.55),
                        blurRadius: 22,
                        spreadRadius: 1,
                      ),
                    ]
                  : const [],
            ),
            child: FilledButton(
              onPressed: enabled
                  ? () => widget.onLaunch(
                        animate: !(MediaQuery.maybeOf(context)?.disableAnimations ??
                            false),
                      )
                  : null,
              child: widget.isLaunching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Launch'),
            ),
          ),
        ],
      ),
    );
  }
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
        color: enabled
            ? AppColors.primary
            : Theme.of(context).colorScheme.onSurface.withAlpha(110),
      ),
    );
  }
}
