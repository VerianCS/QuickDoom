/// A thing placed in the map (player start, monster, item, decoration...).
class Thing {
  final int x;
  final int y;
  final int angle;
  final int type;
  final int flags;

  /// Hexen fields (unused for classic Doom).
  final int z;
  final int special;
  final List<int> args;

  /// Hexen thing ID (TID), 0 when unused.
  final int tid;

  /// Raw UDMF type name when the map uses names instead of numbers.
  final String? typeName;

  const Thing({
    required this.x,
    required this.y,
    required this.angle,
    required this.type,
    required this.flags,
    this.z = 0,
    this.special = 0,
    this.args = const [],
    this.tid = 0,
    this.typeName,
  });

  /// Skill flags: 0x0001 = easy (skills 1-2), 0x0002 = medium (skill 3),
  /// 0x0004 = hard (skills 4-5).
  static const int flagSkill1 = 0x0001;
  static const int flagSkill2 = 0x0001;
  static const int flagSkill3 = 0x0002;
  static const int flagSkill4 = 0x0004;
  static const int flagSkill5 = 0x0004;
  static const int flagAmbush = 0x0008;
  static const int flagMultiplayerOnly = 0x0010;
  static const int flagNotMultiplayer = 0x0020;

  /// Whether this thing appears on the given skill level (1-5).
  bool appearsInSkill(int skill) {
    final bit = switch (skill) {
      1 || 2 => flagSkill1,
      3 => flagSkill3,
      _ => flagSkill4,
    };
    return flags & bit != 0;
  }

  /// Player 1 start (classic Doom/Heretic thing type 1; Strife uses 11).
  bool get isPlayerStart => type == 1 || type == 11;

  /// Hexen class starts (Fighter 3000, Cleric 3001, Mage 3002, players 4-5
  /// 3003-3004). Only meaningful on Hexen-format maps.
  bool get isHexenPlayerStart => type >= 3000 && type <= 3004;

  bool get isTeleportDestination =>
      type == 14 || typeName?.toLowerCase() == 'teleportdest';
  bool get isAmbush => flags & flagAmbush != 0;
  bool get isMultiplayerOnly => flags & flagMultiplayerOnly != 0;
  bool get isNotInMultiplayer => flags & flagNotMultiplayer != 0;
}
