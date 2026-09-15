import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

/// A number over its label, for instrument-panel rows of counts.
class StatReadout extends StatelessWidget {
  final String value;
  final String label;
  final Color? tint;

  /// Uses a smaller value type, for readouts packed four or more to a row.
  final bool compact;

  const StatReadout({
    super.key,
    required this.value,
    required this.label,
    this.tint,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: AppFonts.doomText,
            fontSize: compact ? 14 : 18,
            letterSpacing: 0.8,
            color: tint ?? AppColors.onSurface,
          ),
          maxLines: 1,
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            letterSpacing: 1.1,
            color: AppColors.onSurfaceFaint,
          ),
          maxLines: 1,
        ),
      ],
    );
  }
}
