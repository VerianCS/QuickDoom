import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../console/presentation/widgets/console_panel.dart';
import '../../../launcher/presentation/screens/launcher_screen.dart';
import '../../../mod_browser/presentation/screens/mod_browser_screen.dart';
import '../../../engine_manager/presentation/screens/engine_manager_screen.dart';
import '../../../mod_packs/presentation/screens/mod_pack_list_screen.dart';
import '../../../map_viewer/presentation/screens/map_viewer_screen.dart';

enum AppTab { launcher, modBrowser, engines, modPacks, mapViewer }

final currentTabProvider = StateProvider<AppTab>((ref) => AppTab.launcher);

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(currentTabProvider);

    return Scaffold(
      body: Column(
        children: [
          _NavBar(tab: tab),
          Expanded(
            child: IndexedStack(
              index: tab.index,
              children: const [
                LauncherScreen(),
                ModBrowserScreen(),
                EngineManagerScreen(),
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
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in AppTab.values)
              _NavTab(
                icon: _iconFor(t),
                label: _labelFor(t),
                selected: t == tab,
                onTap: () => ref.read(currentTabProvider.notifier).state = t,
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
    AppTab.modPacks => Icons.folder_outlined,
    AppTab.mapViewer => Icons.map_outlined,
  };

  String _labelFor(AppTab t) => switch (t) {
    AppTab.launcher => 'Launch',
    AppTab.modBrowser => 'Mod Browser',
    AppTab.engines => 'Engines',
    AppTab.modPacks => 'Mod Packs',
    AppTab.mapViewer => 'Map Viewer',
  };
}

class _NavTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withAlpha(153);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: selected
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
