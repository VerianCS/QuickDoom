import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';

import '../../../console/presentation/widgets/console_panel.dart';
import '../../../launcher/presentation/screens/launcher_screen.dart';
import '../../../mod_browser/presentation/screens/mod_browser_screen.dart';
import '../../../engine_manager/presentation/screens/engine_manager_screen.dart';
import '../../../mod_packs/presentation/screens/mod_pack_list_screen.dart';
import '../../../map_viewer/presentation/screens/map_viewer_screen.dart';
import '../../../library/presentation/screens/library_screen.dart';

enum AppTab { launcher, modBrowser, engines, library, modPacks, mapViewer }

final currentTabProvider = StateProvider<AppTab>((ref) => AppTab.launcher);

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(currentTabProvider);

    return Scaffold(
      // Stretch, or the nav bar shrink-wraps its tabs and a Column centres it,
      // leaving the tab strip floating in the middle of the window.
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NavBar(tab: tab),
          Expanded(
            child: IndexedStack(
              index: tab.index,
              children: const [
                LauncherScreen(),
                ModBrowserScreen(),
                EngineManagerScreen(),
                LibraryScreen(),
                ModPackListScreen(),
                MapViewerScreen(),
              ],
            ),
          ),
          const ConsolePanel(),
        ],
      ),
    );
  }
}

class _NavBar extends ConsumerWidget {
  final AppTab tab;

  const _NavBar({required this.tab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.dividerColor),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in AppTab.values)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _NavTab(
                  icon: _iconFor(t),
                  label: _labelFor(t),
                  selected: t == tab,
                  onTap: () => ref.read(currentTabProvider.notifier).state = t,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(AppTab t) => switch (t) {
    AppTab.launcher => Icons.rocket_launch_outlined,
    AppTab.modBrowser => Icons.search,
    AppTab.engines => Icons.download_for_offline_outlined,
    AppTab.library => Icons.inventory_2_outlined,
    AppTab.modPacks => Icons.folder_outlined,
    AppTab.mapViewer => Icons.map_outlined,
  };

  String _labelFor(AppTab t) => switch (t) {
    AppTab.launcher => 'Launch',
    AppTab.modBrowser => 'Mod Browser',
    AppTab.engines => 'Engines',
    AppTab.library => 'Library',
    AppTab.modPacks => 'Mod Packs',
    AppTab.mapViewer => 'Map Viewer',
  };
}

/// A nav slot.
///
/// The active tab is backlit and seated into the bar rather than underlined:
/// an underline is a web tab, a lit slot reads as a switch on a console.
class _NavTab extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavTab> createState() => _NavTabState();
}

class _NavTabState extends State<_NavTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final foreground = selected
        ? AppColors.primary
        : _hovered
            ? AppColors.onSurface
            : AppColors.onBackground;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.standard,
          decoration: BoxDecoration(
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 18,
                    ),
                  ]
                : const [],
          ),
          child: CustomPaint(
            painter: _NavSlotPainter(selected: selected, hovered: _hovered),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 15, color: foreground),
                  const SizedBox(width: 7),
                  Text(
                    widget.label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: AppFonts.doomText,
                      fontSize: 12,
                      letterSpacing: 1.3,
                      color: foreground,
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

class _NavSlotPainter extends CustomPainter {
  final bool selected;
  final bool hovered;

  const _NavSlotPainter({required this.selected, required this.hovered});

  @override
  void paint(Canvas canvas, Size size) {
    // Only the top corners are cut: the slot sits on the bar's bottom edge, so
    // cutting the bottom would float it.
    final cut = AppShape.notchSmall;
    final path = Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, cut)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, cut)
      ..close();

    if (selected) {
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.30),
              AppColors.primary.withValues(alpha: 0.07),
            ],
          ).createShader(Offset.zero & size),
      );
    } else if (hovered) {
      canvas.drawPath(
        path,
        Paint()..color = AppColors.surfaceHigh,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = selected
            ? AppColors.primary.withValues(alpha: 0.75)
            : hovered
                ? AppColors.dividerColor
                : Colors.transparent,
    );

    // The lit filament along the bottom of the active slot.
    if (selected) {
      canvas.drawRect(
        Rect.fromLTWH(1, size.height - 2, size.width - 2, 2),
        Paint()..color = AppColors.primary,
      );
    }
  }

  @override
  bool shouldRepaint(_NavSlotPainter oldDelegate) =>
      oldDelegate.selected != selected || oldDelegate.hovered != hovered;
}
