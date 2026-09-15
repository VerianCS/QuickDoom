import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

/// An engraved section header: a label in the display cut, then a rule running
/// to the end of the row, with optional trailing controls.
class SectionRule extends StatelessWidget {
  final String label;

  /// Sits between the label and the rule, for a count or a unit.
  final String? note;

  /// Sits after the rule.
  final Widget? trailing;

  final Color? accent;

  const SectionRule({
    super.key,
    required this.label,
    this.note,
    this.trailing,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? AppColors.primary;

    return Row(
      children: [
        Container(width: 3, height: 13, color: tint),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: AppFonts.doomText,
            fontSize: 13,
            letterSpacing: 1.6,
            color: AppColors.onSurface,
          ),
        ),
        if (note != null) ...[
          const SizedBox(width: 8),
          Text(
            note!,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.onSurfaceFaint,
            ),
          ),
        ],
        const SizedBox(width: 12),
        const Expanded(child: Divider(height: 1)),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}
