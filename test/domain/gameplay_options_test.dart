import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/domain/entities/gameplay_options.dart';

void main() {
  group('toArgs', () {
    test('no options means no arguments, not -skill 0', () {
      expect(const GameplayOptions().toArgs(), isEmpty);
      expect(const GameplayOptions().isDefault, isTrue);
    });

    test('a skill becomes its number', () {
      expect(
        const GameplayOptions(skill: Skill.ultraViolence).toArgs(),
        ['-skill', '4'],
      );
    });

    test('nightmare is skill 5', () {
      expect(const GameplayOptions(skill: Skill.nightmare).toArgs().last, '5');
    });

    test('the switches each add their flag', () {
      expect(
        const GameplayOptions(fast: true, noMonsters: true, respawn: true)
            .toArgs(),
        ['-fast', '-nomonsters', '-respawn'],
      );
    });

    test('skill comes before the switches', () {
      expect(
        const GameplayOptions(skill: Skill.hurtMePlenty, fast: true).toArgs(),
        ['-skill', '3', '-fast'],
      );
    });
  });

  group('copyWith', () {
    // Clearing has to be explicit: `skill ?? this.skill` cannot tell "leave
    // it" from "unset it", so deselecting a skill chip needs its own flag.
    test('clearSkill unsets the skill', () {
      const options = GameplayOptions(skill: Skill.ultraViolence, fast: true);
      final cleared = options.copyWith(clearSkill: true);

      expect(cleared.skill, isNull);
      expect(cleared.fast, isTrue, reason: 'only the skill was cleared');
    });

    test('a false switch is not mistaken for "unchanged"', () {
      const options = GameplayOptions(fast: true);
      expect(options.copyWith(fast: false).fast, isFalse);
    });
  });

  group('round trip', () {
    test('survives being written and read back', () {
      const options = GameplayOptions(
        skill: Skill.heyNotTooRough,
        noMonsters: true,
      );
      expect(GameplayOptions.fromMap(options.toMap()), options);
    });

    test('an unknown skill name reads as no skill rather than throwing', () {
      expect(
        GameplayOptions.fromMap({'skill': 'brutal', 'fast': true}).skill,
        isNull,
      );
    });

    test('an empty map is the default', () {
      expect(GameplayOptions.fromMap({}), const GameplayOptions());
    });
  });
}
