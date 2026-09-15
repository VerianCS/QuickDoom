import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/file_problem.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../app/widgets/notched_panel.dart';

/// One seated slot on the loadout bench.
///
/// A slot is either loaded — it shows what is in it and where that came from —
/// or it is an open socket, hatched and underlined in crimson so an unfilled
/// requirement is visible from across the room rather than being an empty
/// dropdown that looks much like a filled one.
class LoadoutSlot extends StatefulWidget {
  /// The rail marker, e.g. `I`. Lit when the slot is loaded.
  final String ordinal;

  final String label;

  /// What is seated here. Null means the socket is open.
  final String? value;

  /// Where [value] came from — a path, shown tail-first.
  final String? detail;

  /// Shown in place of [value] when the socket is open.
  final String emptyHint;

  final IconData icon;

  /// Opens the picker. The whole plate is the target.
  final VoidCallback? onTap;

  /// Controls at the right-hand end of the plate.
  final List<Widget> actions;

  /// What is wrong with what is seated here — a file that has been moved, or
  /// one that is not executable. Shown in place of the path.
  final String? problem;

  const LoadoutSlot({
    super.key,
    required this.ordinal,
    required this.label,
    required this.icon,
    required this.emptyHint,
    this.value,
    this.detail,
    this.onTap,
    this.actions = const [],
    this.problem,
  });

  /// The tail of a path, which is the part that identifies it.
  ///
  /// `/usr/share/games/doom/freedoom2.wad` reads as `…/doom/freedoom2.wad`.
  /// Ellipsising the other end, as a plain overflow would, cuts off exactly
  /// the half that tells two files apart.
  static String shortenPath(String path) {
    final parts = path.split(RegExp(r'[/\\]')).where((p) => p.isNotEmpty);
    if (parts.length <= 2) return path;
    return '…/${parts.toList().sublist(parts.length - 2).join('/')}';
  }

  @override
  State<LoadoutSlot> createState() => _LoadoutSlotState();
}

class _LoadoutSlotState extends State<LoadoutSlot> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final loaded = widget.value != null;
    final broken = loaded && widget.problem != null;

    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: CustomPaint(
        painter: _SocketPainter(
          loaded: loaded,
          hovered: _hovered,
          broken: broken,
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: widget.onTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 11),
                  child: Row(
                    children: [
                      _OrdinalRail(ordinal: widget.ordinal, lit: loaded),
                      const SizedBox(width: 12),
                      Icon(
                        broken ? Icons.warning_amber_rounded : widget.icon,
                        size: 17,
                        color: broken
                            ? AppColors.caution
                            : loaded
                                ? AppColors.primary
                                : AppColors.onSurfaceFaint,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.label.toUpperCase(),
                              style: const TextStyle(
                                fontFamily: AppFonts.doomText,
                                fontSize: 10,
                                letterSpacing: 1.5,
                                color: AppColors.onSurfaceFaint,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.value ?? widget.emptyHint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.1,
                                color: broken
                                    ? AppColors.caution
                                    : loaded
                                        ? AppColors.onSurface
                                        : AppColors.onSurfaceFaint,
                              ),
                            ),
                            if (broken) ...[
                              const SizedBox(height: 3),
                              Tooltip(
                                message: widget.problem!,
                                child: Text(
                                  FileProblem.summarise(widget.problem!),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.caution,
                                  ),
                                ),
                              ),
                            ] else if (loaded && widget.detail != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                LoadoutSlot.shortenPath(widget.detail!),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10.5,
                                  color: AppColors.onSurfaceFaint,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.actions.isNotEmpty) ...[
              ...widget.actions,
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// The marker down the left edge of a slot.
class _OrdinalRail extends StatelessWidget {
  final String ordinal;
  final bool lit;

  const _OrdinalRail({required this.ordinal, required this.lit});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: lit
            ? AppColors.primary.withValues(alpha: 0.16)
            : AppColors.surfaceHigh,
        border: Border.all(
          color: lit ? AppColors.primary.withValues(alpha: 0.5) : AppColors.dividerSoft,
        ),
      ),
      child: Text(
        ordinal,
        style: TextStyle(
          fontFamily: AppFonts.doomText,
          fontSize: 11,
          color: lit ? AppColors.primary : AppColors.onSurfaceFaint,
        ),
      ),
    );
  }
}

class _SocketPainter extends CustomPainter {
  final bool loaded;
  final bool hovered;
  final bool broken;

  const _SocketPainter({
    required this.loaded,
    required this.hovered,
    this.broken = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = NotchedPanel.buildPath(size, AppShape.notch);

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: loaded
              ? [AppColors.surfaceHigh, AppColors.surface]
              : [AppColors.surface, AppColors.background],
        ).createShader(Offset.zero & size),
    );

    // An open socket is hatched, so it reads as a recess waiting for something
    // rather than as a filled plate with nothing written on it.
    if (!loaded) {
      canvas.save();
      canvas.clipPath(path);
      final hatch = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.dividerSoft;
      for (double x = -size.height; x < size.width; x += 9) {
        canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), hatch);
      }
      canvas.restore();
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = broken
            ? AppColors.caution.withValues(alpha: 0.7)
            : hovered
                ? AppColors.primary.withValues(alpha: 0.6)
                : loaded
                    ? AppColors.dividerColor
                    : AppColors.primary.withValues(alpha: 0.35),
    );

    // The crimson baseline: present on an open socket, and lit along its whole
    // width once something is seated.
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 2, loaded ? size.width - AppShape.notch : size.width * 0.34, 2),
      Paint()
        ..color = broken
            ? AppColors.caution
            : loaded
                ? AppColors.primary.withValues(alpha: 0.55)
                : AppColors.primary,
    );
  }

  @override
  bool shouldRepaint(_SocketPainter oldDelegate) =>
      oldDelegate.loaded != loaded ||
      oldDelegate.hovered != hovered ||
      oldDelegate.broken != broken;
}

/// A small square control seated at the end of a slot.
class SlotAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? tint;

  const SlotAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 17, color: tint ?? AppColors.onBackground),
        ),
      ),
    );
  }
}
