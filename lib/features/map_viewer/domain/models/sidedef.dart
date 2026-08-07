/// A sidedef describing one side of a linedef: texture offsets, the three
/// texture slots and the sector it faces.
class Sidedef {
  final int xOffset;
  final int yOffset;
  final String upperTexture;
  final String lowerTexture;
  final String middleTexture;
  final int sectorIndex;

  const Sidedef({
    required this.xOffset,
    required this.yOffset,
    required this.upperTexture,
    required this.lowerTexture,
    required this.middleTexture,
    required this.sectorIndex,
  });

  bool get hasUpperTexture => upperTexture.isNotEmpty;
  bool get hasLowerTexture => lowerTexture.isNotEmpty;
  bool get hasMiddleTexture => middleTexture.isNotEmpty;
}
