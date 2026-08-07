/// A sector: floor/ceiling heights and textures, light level and specials.
class Sector {
  final int floorHeight;
  final int ceilingHeight;
  final String floorTexture;
  final String ceilingTexture;
  final int lightLevel;
  final int special;
  final int tag;

  const Sector({
    required this.floorHeight,
    required this.ceilingHeight,
    required this.floorTexture,
    required this.ceilingTexture,
    required this.lightLevel,
    required this.special,
    required this.tag,
  });

  /// Secret sector: classic special 9, or the ZDoom secret bitmask 0x400.
  bool get isSecret => special == 9 || (special & 0x400) != 0;

  /// Classic damaging floor specials (wound, nukage, hurt floor).
  bool get isDamageFloor => const {4, 5, 7, 16, 17}.contains(special);

  bool get hasTag => tag != 0;
}
