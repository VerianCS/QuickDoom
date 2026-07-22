import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:quickdoom/app/theme/app_colors.dart';

class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return DragToMoveArea(
      child: Container(
        height: 36,
        color: AppColors.titleBar,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(
              Icons.gamepad,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'QuickDoom',
              style: TextStyle(
                color: AppColors.onSurface.withAlpha(200),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            _TitleButton(
              icon: Icons.horizontal_rule_rounded,
              onPressed: () => windowManager.minimize(),
            ),
            _TitleButton(
              icon: Icons.close_rounded,
              onPressed: () => windowManager.close(),
              isClose: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  const _TitleButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 36,
      child: InkWell(
        onTap: onPressed,
        hoverColor: isClose
            ? AppColors.primary.withAlpha(180)
            : Colors.white.withAlpha(20),
        child: Center(
          child: Icon(
            icon,
            size: 16,
            color: isClose
                ? AppColors.onSurface
                : AppColors.onSurface.withAlpha(180),
          ),
        ),
      ),
    );
  }
}
