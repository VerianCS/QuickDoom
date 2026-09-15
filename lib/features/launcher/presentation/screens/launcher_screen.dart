import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../app/widgets/doom_button.dart';
import '../../../../app/widgets/notched_panel.dart';
import '../../../../app/widgets/section_rule.dart';
import '../../../../core/services/hive_service.dart';
import '../../../../data/repositories/iwad_repository_impl.dart';
import '../../../../data/repositories/profile_repository_impl.dart';
import '../../../../data/repositories/source_port_repository_impl.dart';
import '../../../../domain/entities/iwad.dart';
import '../../../../domain/entities/source_port.dart';
import '../../../profiles/presentation/providers/profile_provider.dart';
import '../../../profiles/presentation/widgets/profile_list_sidebar.dart';
import '../../../wads/presentation/widgets/wad_drop_zone.dart';
import '../providers/launch_provider.dart';
import '../widgets/iwad_selector.dart';
import '../widgets/pwad_rail.dart';
import '../widgets/quick_launch_bar.dart';
import '../widgets/source_port_dropdown.dart';
import '../widgets/gameplay_panel.dart';
import '../widgets/warp_plate.dart';

class LauncherScreen extends ConsumerStatefulWidget {
  const LauncherScreen({super.key});

  @override
  ConsumerState<LauncherScreen> createState() => _LauncherScreenState();
}

class _LauncherScreenState extends ConsumerState<LauncherScreen> {
  @override
  void initState() {
    super.initState();
    // The bench is rebuilt from what was on it when the app closed. Without
    // this every restart started from two empty sockets.
    ref.read(launchNotifierProvider.notifier).restore();
  }

  Future<void> _loadProfile(WidgetRef ref, String profileId) async {
    final profileRepo = ProfileRepositoryImpl(HiveService());
    final profile = await profileRepo.getProfile(profileId);
    if (profile == null) return;

    final SourcePort? port;
    if (profile.sourcePortId.isNotEmpty) {
      final portRepo = SourcePortRepositoryImpl(HiveService());
      final ports = await portRepo.getPorts();
      port = ports.cast<SourcePort?>().firstWhere(
        (p) => p!.id == profile.sourcePortId,
        orElse: () => null,
      );
    } else {
      port = null;
    }

    final Iwad? iwad;
    if (profile.iwadId.isNotEmpty) {
      final iwadRepo = IwadRepositoryImpl(HiveService());
      final iwads = await iwadRepo.getIwads();
      iwad = iwads.cast<Iwad?>().firstWhere(
        (i) => i!.id == profile.iwadId,
        orElse: () => null,
      );
    } else {
      iwad = null;
    }

    ref.read(launchNotifierProvider.notifier).loadFromProfile(
      profile: profile,
      port: port,
      iwad: iwad,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentProfileIdProvider, (prev, next) {
      if (next != null && next != prev) {
        _loadProfile(ref, next);
      }
    });

    final state = ref.watch(launchNotifierProvider);
    final currentProfileId = ref.watch(currentProfileIdProvider);

    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyL, control: true): () {
            if (state.canLaunch && !state.isLaunching) {
              ref.read(launchNotifierProvider.notifier).launch();
            }
          },
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
            if (currentProfileId != null) _saveToProfile(ref);
          },
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ProfileListSidebar(),
                  Expanded(
                    child: WadDropZone(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                        children: [
                          _BenchHeader(
                            profileId: currentProfileId,
                            onSave: () => _saveToProfile(ref),
                          ),
                          const SizedBox(height: 16),
                          const WarpPlate(),
                          const SectionRule(
                            label: 'Engine & Game',
                            note: 'both required',
                          ),
                          const SizedBox(height: 10),
                          const SourcePortSelector(),
                          const SizedBox(height: 8),
                          const IwadSelector(),
                          const SizedBox(height: 20),
                          const GameplayPanel(),
                          const SizedBox(height: 20),
                          const PwadRail(),
                          const SizedBox(height: 20),
                          const SectionRule(
                            label: 'Arguments',
                            note: 'appended to the command line',
                          ),
                          const SizedBox(height: 10),
                          _CustomArgsField(),
                          if (state.error != null) ...[
                            const SizedBox(height: 16),
                            _ErrorBanner(message: state.error!),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            QuickLaunchBar(
              canLaunch: state.canLaunch,
              isLaunching: state.isLaunching,
              onLaunch: ({required bool animate}) => ref
                  .read(launchNotifierProvider.notifier)
                  .launch(animate: animate),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveToProfile(WidgetRef ref) async {
    final state = ref.read(launchNotifierProvider);
    final currentId = ref.read(currentProfileIdProvider);
    if (currentId == null) return;

    final profileRepo = ProfileRepositoryImpl(HiveService());
    final existing = await profileRepo.getProfile(currentId);
    if (existing == null) return;

    if (state.sourcePort != null) {
      final portRepo = SourcePortRepositoryImpl(HiveService());
      await portRepo.savePort(state.sourcePort!);
    }
    if (state.iwad != null) {
      final iwadRepo = IwadRepositoryImpl(HiveService());
      await iwadRepo.saveIwad(state.iwad!);
    }

    final updated = existing.copyWith(
      sourcePortId: state.sourcePort?.id ?? existing.sourcePortId,
      iwadId: state.iwad?.id ?? existing.iwadId,
      pwadList: state.pwads,
      customArgs: state.customArgs,
    );
    await profileRepo.saveProfile(updated);

    ref.invalidate(profileListProvider);
  }
}

/// The bench title, and the save control for whichever profile is seated.
class _BenchHeader extends StatelessWidget {
  final String? profileId;
  final VoidCallback onSave;

  const _BenchHeader({required this.profileId, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'LOADOUT',
            style: TextStyle(
              fontFamily: AppFonts.doomLeft,
              fontSize: 26,
              letterSpacing: 3,
              color: AppColors.onSurface,
            ),
          ),
        ),
        if (profileId != null)
          DoomButton(
            label: 'Save',
            icon: Icons.save_outlined,
            hint: 'CTRL+S',
            onPressed: onSave,
          ),
      ],
    );
  }
}

class _CustomArgsField extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CustomArgsField> createState() => _CustomArgsFieldState();
}

class _CustomArgsFieldState extends ConsumerState<_CustomArgsField> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text =
        ref.read(launchNotifierProvider.select((s) => s.customArgs));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(launchNotifierProvider.select((s) => s.customArgs), (prev, next) {
      if (_controller.text != next) {
        _controller.text = next;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: next.length),
        );
      }
    });

    final customArgs =
        ref.watch(launchNotifierProvider.select((s) => s.customArgs));

    return TextField(
      controller: _controller,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      onChanged: (value) =>
          ref.read(launchNotifierProvider.notifier).setCustomArgs(value),
      decoration: InputDecoration(
        hintText: '-skill 4 -fast -nomonsters',
        hintStyle: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: AppColors.onSurfaceFaint,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        suffixIcon: customArgs.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 16),
                onPressed: () {
                  ref.read(launchNotifierProvider.notifier).setCustomArgs('');
                  _controller.clear();
                },
              )
            : null,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return NotchedPanel(
      background: AppColors.surface,
      borderColor: AppColors.error.withValues(alpha: 0.55),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.error, size: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
