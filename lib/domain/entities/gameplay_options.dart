/// Difficulty, by its Doom name.
///
/// The number is what `-skill` takes; the labels are what the games have
/// always called them, because "UV" is how people ask for skill 4.
enum Skill {
  tooYoungToDie(1, 'ITYTD', "I'm Too Young To Die"),
  heyNotTooRough(2, 'HNTR', 'Hey, Not Too Rough'),
  hurtMePlenty(3, 'HMP', 'Hurt Me Plenty'),
  ultraViolence(4, 'UV', 'Ultra-Violence'),
  nightmare(5, 'NM', 'Nightmare!');

  final int value;
  final String short;
  final String label;

  const Skill(this.value, this.short, this.label);
}

/// The switches a launcher exists to spare you typing.
class GameplayOptions {
  /// Null means "let the port decide", which is not the same as picking a
  /// skill: passing -skill always overrides the port's own saved default.
  final Skill? skill;

  final bool fast;
  final bool noMonsters;
  final bool respawn;

  const GameplayOptions({
    this.skill,
    this.fast = false,
    this.noMonsters = false,
    this.respawn = false,
  });

  bool get isDefault =>
      skill == null && !fast && !noMonsters && !respawn;

  GameplayOptions copyWith({
    Skill? skill,
    bool? fast,
    bool? noMonsters,
    bool? respawn,
    bool clearSkill = false,
  }) {
    return GameplayOptions(
      skill: clearSkill ? null : skill ?? this.skill,
      fast: fast ?? this.fast,
      noMonsters: noMonsters ?? this.noMonsters,
      respawn: respawn ?? this.respawn,
    );
  }

  List<String> toArgs() => [
        if (skill != null) ...['-skill', '${skill!.value}'],
        if (fast) '-fast',
        if (noMonsters) '-nomonsters',
        if (respawn) '-respawn',
      ];

  Map<String, dynamic> toMap() => {
        'skill': skill?.name,
        'fast': fast,
        'noMonsters': noMonsters,
        'respawn': respawn,
      };

  static GameplayOptions fromMap(Map<dynamic, dynamic> map) {
    final name = map['skill'] as String?;
    return GameplayOptions(
      skill: name == null
          ? null
          : Skill.values.where((s) => s.name == name).firstOrNull,
      fast: map['fast'] as bool? ?? false,
      noMonsters: map['noMonsters'] as bool? ?? false,
      respawn: map['respawn'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameplayOptions &&
      other.skill == skill &&
      other.fast == fast &&
      other.noMonsters == noMonsters &&
      other.respawn == respawn;

  @override
  int get hashCode => Object.hash(skill, fast, noMonsters, respawn);
}
