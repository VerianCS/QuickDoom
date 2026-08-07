/// A linedef (wall line) connecting two vertices, with up to two sidedefs.
class Linedef {
  final int startVertexIndex;
  final int endVertexIndex;
  final int flags;
  final int special;
  final int tag;

  /// Index into the map's sidedef list, or -1 when absent.
  final int frontSidedefIndex;
  final int backSidedefIndex;

  /// Hexen 5-argument line specials (empty for classic Doom).
  final List<int> args;

  const Linedef({
    required this.startVertexIndex,
    required this.endVertexIndex,
    required this.flags,
    required this.special,
    required this.tag,
    this.frontSidedefIndex = -1,
    this.backSidedefIndex = -1,
    this.args = const [],
  });

  static const int flagImpassable = 0x0001;
  static const int flagBlockMonster = 0x0002;
  static const int flagTwoSided = 0x0004;
  static const int flagUpperUnpegged = 0x0008;
  static const int flagLowerUnpegged = 0x0010;
  static const int flagSecret = 0x0020;
  static const int flagBlockSound = 0x0040;
  static const int flagNotOnMap = 0x0080;
  static const int flagAlreadyOnMap = 0x0100;

  bool get isImpassable => flags & flagImpassable != 0;
  bool get isTwoSided => flags & flagTwoSided != 0;
  bool get isSecret => flags & flagSecret != 0;
  bool get isUpperUnpegged => flags & flagUpperUnpegged != 0;
  bool get isLowerUnpegged => flags & flagLowerUnpegged != 0;
  bool get isBlockingSound => flags & flagBlockSound != 0;
  bool get isVisibleOnAutomap => flags & flagNotOnMap == 0;

  /// Line carries a trigger/action special.
  bool get hasTrigger => special != 0;
  bool get hasFrontSidedef => frontSidedefIndex >= 0;
  bool get hasBackSidedef => backSidedefIndex >= 0;
}
