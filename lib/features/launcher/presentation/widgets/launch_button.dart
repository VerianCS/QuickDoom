import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/launch_provider.dart';

class LaunchButton extends ConsumerWidget {
  const LaunchButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(launchNotifierProvider);

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: state.canLaunch
            ? () => ref.read(launchNotifierProvider.notifier).launch()
            : null,
        icon: state.isLaunching
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.play_arrow_rounded, size: 28),
        label: Text(state.isLaunching ? 'Launching...' : 'LAUNCH'),
      ),
    );
  }
}
