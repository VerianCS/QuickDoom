import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/doom_chip.dart';
import '../../../../app/widgets/section_rule.dart';
import '../../../../domain/entities/gameplay_options.dart';
import '../providers/launch_provider.dart';

/// Difficulty and the three switches people actually use.
///
/// These were reachable only by typing -skill 4 -fast into the arguments box,
/// which is exactly the kind of thing a launcher exists to spare you.
class GameplayPanel extends ConsumerWidget {
  const GameplayPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(launchNotifierProvider.select((s) => s.gameplay));
    final notifier = ref.read(launchNotifierProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionRule(
          label: 'Gameplay',
          note: options.isDefault ? "the port's own defaults" : null,
          trailing: options.isDefault
              ? null
              : _Reset(onTap: () => notifier.setGameplay(
                    const GameplayOptions(),
                  )),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final skill in Skill.values)
              Tooltip(
                message: skill.label,
                child: DoomChip(
                  label: skill.short,
                  selected: options.skill == skill,
                  // Nightmare is not a harder Ultra-Violence, it respawns
                  // monsters; colouring it apart stops it being picked by
                  // accident as "the next one along".
                  tint: skill == Skill.nightmare
                      ? AppColors.error
                      : AppColors.primary,
                  onTap: () => notifier.setGameplay(
                    options.skill == skill
                        ? options.copyWith(clearSkill: true)
                        : options.copyWith(skill: skill),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            DoomChip(
              label: 'Fast',
              icon: Icons.fast_forward,
              selected: options.fast,
              tint: AppColors.secondary,
              onTap: () =>
                  notifier.setGameplay(options.copyWith(fast: !options.fast)),
            ),
            DoomChip(
              label: 'No Monsters',
              icon: Icons.person_off_outlined,
              selected: options.noMonsters,
              tint: AppColors.secondary,
              onTap: () => notifier.setGameplay(
                options.copyWith(noMonsters: !options.noMonsters),
              ),
            ),
            DoomChip(
              label: 'Respawn',
              icon: Icons.refresh,
              selected: options.respawn,
              tint: AppColors.secondary,
              onTap: () => notifier.setGameplay(
                options.copyWith(respawn: !options.respawn),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Reset extends StatelessWidget {
  final VoidCallback onTap;

  const _Reset({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          'RESET',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.2,
            color: AppColors.onBackground,
          ),
        ),
      ),
    );
  }
}
