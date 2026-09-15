import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../app/widgets/notched_panel.dart';
import '../providers/launch_provider.dart';

/// Shows the map the next launch will start on.
///
/// Warping is invisible in the command line until the game is already running,
/// so without this the bench would look identical whether or not it was about
/// to skip straight to MAP14.
class WarpPlate extends ConsumerWidget {
  const WarpPlate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warp = ref.watch(launchNotifierProvider.select((s) => s.warp));
    if (warp == null) return const SizedBox.shrink();

    final file = warp.sourcePath?.split(RegExp(r'[/\\]')).last;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: NotchedPanel(
        padding: const EdgeInsets.fromLTRB(12, 9, 6, 10),
        background: AppColors.surface,
        borderColor: AppColors.secondary.withValues(alpha: 0.5),
        child: Row(
          children: [
            const Icon(Icons.my_location, size: 16, color: AppColors.secondary),
            const SizedBox(width: 10),
            const Text(
              'START ON',
              style: TextStyle(
                fontFamily: AppFonts.doomText,
                fontSize: 10,
                letterSpacing: 1.5,
                color: AppColors.onSurfaceFaint,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              warp.mapName,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: AppColors.secondary,
              ),
            ),
            if (file != null) ...[
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'from $file',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.onSurfaceFaint,
                  ),
                ),
              ),
            ],
            const Spacer(),
            Tooltip(
              message: 'Start at the beginning instead',
              child: InkWell(
                onTap: () =>
                    ref.read(launchNotifierProvider.notifier).clearWarp(),
                child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(Icons.close,
                      size: 15, color: AppColors.onBackground),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
