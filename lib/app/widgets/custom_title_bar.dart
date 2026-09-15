import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

/// The window's own chrome: a dark plate with the wordmark engraved into it.
///
/// Drawn rather than decorated so the plate can carry a rivet line and a lit
/// top edge without a stack of nested containers.
class CustomTitleBar extends StatelessWidget {
  const CustomTitleBar({super.key});

  static const double height = 34;

  @override
  Widget build(BuildContext context) {
    return DragToMoveArea(
      child: SizedBox(
        height: height,
        child: CustomPaint(
          painter: const _TitlePlatePainter(),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Container(width: 3, height: 12, color: AppColors.primary),
              const SizedBox(width: 9),
              Text(
                'QUICKDOOM',
                style: TextStyle(
                  fontFamily: AppFonts.doomLeft,
                  fontSize: 13,
                  letterSpacing: 2.2,
                  color: AppColors.onSurface.withValues(alpha: 0.82),
                ),
              ),
              const Spacer(),
              _WindowButton(
                icon: Icons.remove,
                onPressed: () => windowManager.minimize(),
              ),
              _WindowButton(
                icon: Icons.close,
                onPressed: () => windowManager.close(),
                danger: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitlePlatePainter extends CustomPainter {
  const _TitlePlatePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B1413), AppColors.titleBar],
        ).createShader(Offset.zero & size),
    );

    // Lit top edge and a shaded bottom: the plate catches light from above.
    canvas.drawLine(
      Offset.zero,
      Offset(size.width, 0),
      Paint()..color = Colors.white.withValues(alpha: 0.05),
    );
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()..color = AppColors.primary.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(_TitlePlatePainter oldDelegate) => false;
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.danger = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final wash = widget.danger
        ? AppColors.primary.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.08);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          width: 44,
          height: CustomTitleBar.height,
          color: _hovered ? wash : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 15,
            color: _hovered && widget.danger
                ? AppColors.onPrimary
                : AppColors.onBackground,
          ),
        ),
      ),
    );
  }
}
