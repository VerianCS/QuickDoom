import 'package:flutter/material.dart';

class QuickLaunchBar extends StatelessWidget {
  final VoidCallback onLaunch;

  const QuickLaunchBar({super.key, required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
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
          FilledButton(
            onPressed: onLaunch,
            child: const Text('Launch'),
          ),
        ],
      ),
    );
  }
}
