import 'doom_map.dart';

/// Ordering for the map list.
///
/// A WAD's directory is in authoring order, not level order: PWADs routinely
/// append maps as they are built, so the markers come out as MAP01, MAP08,
/// MAP04 and a player browsing levels sees no progression. Sorting by name as
/// plain text is no better — it puts MAP10 before MAP2. These helpers order
/// maps the way the episodes actually run.
class MapOrder {
  const MapOrder._();

  /// `E2M4` -> episode 2, map 4.
  static final RegExp _episodeMap = RegExp(r'^E(\d+)M(\d+)$');

  /// `MAP07`, and the three-digit form some megawads use.
  static final RegExp _mapNumber = RegExp(r'^MAP(\d+)$');

  /// Families sort as a block so an episodic set never interleaves with a
  /// MAP## set in a WAD that somehow carries both.
  static const int _familyEpisode = 0;
  static const int _familyMapNumber = 1;
  static const int _familyOther = 2;

  /// Orders two map names by episode and level number, falling back to a
  /// natural (digit-aware) comparison for names that fit neither shape.
  static int compareNames(String a, String b) {
    final upperA = a.toUpperCase();
    final upperB = b.toUpperCase();

    final keyA = _keyFor(upperA);
    final keyB = _keyFor(upperB);

    if (keyA.family != keyB.family) return keyA.family.compareTo(keyB.family);
    if (keyA.family != _familyOther) {
      if (keyA.major != keyB.major) return keyA.major.compareTo(keyB.major);
      if (keyA.minor != keyB.minor) return keyA.minor.compareTo(keyB.minor);
      return upperA.compareTo(upperB);
    }

    return _naturalCompare(upperA, upperB);
  }

  /// Returns [maps] in level order.
  ///
  /// The sort is made stable by hand: Dart's List.sort is not stable, and two
  /// maps sharing a name (a PWAD replacing an IWAD level, say) would otherwise
  /// swap around unpredictably between loads.
  static List<DoomMap> sorted(List<DoomMap> maps) {
    final indexed = <(int, DoomMap)>[
      for (var i = 0; i < maps.length; i++) (i, maps[i]),
    ];

    indexed.sort((a, b) {
      final byName = compareNames(a.$2.name, b.$2.name);
      if (byName != 0) return byName;
      return a.$1.compareTo(b.$1);
    });

    return [for (final (_, map) in indexed) map];
  }

  static _SortKey _keyFor(String name) {
    final episode = _episodeMap.firstMatch(name);
    if (episode != null) {
      return _SortKey(
        _familyEpisode,
        int.parse(episode.group(1)!),
        int.parse(episode.group(2)!),
      );
    }

    final numbered = _mapNumber.firstMatch(name);
    if (numbered != null) {
      return _SortKey(_familyMapNumber, int.parse(numbered.group(1)!), 0);
    }

    return const _SortKey(_familyOther, 0, 0);
  }

  /// Compares digit runs as numbers and everything else as text, so MAP2
  /// sorts before MAP10 even in names that do not match the known shapes.
  static int _naturalCompare(String a, String b) {
    var i = 0;
    var j = 0;

    while (i < a.length && j < b.length) {
      final aDigit = _isDigit(a.codeUnitAt(i));
      final bDigit = _isDigit(b.codeUnitAt(j));

      if (aDigit && bDigit) {
        final startA = i;
        final startB = j;
        while (i < a.length && _isDigit(a.codeUnitAt(i))) {
          i++;
        }
        while (j < b.length && _isDigit(b.codeUnitAt(j))) {
          j++;
        }

        final numberA = int.tryParse(a.substring(startA, i)) ?? 0;
        final numberB = int.tryParse(b.substring(startB, j)) ?? 0;
        if (numberA != numberB) return numberA.compareTo(numberB);
        continue;
      }

      if (a.codeUnitAt(i) != b.codeUnitAt(j)) {
        return a.codeUnitAt(i).compareTo(b.codeUnitAt(j));
      }
      i++;
      j++;
    }

    return (a.length - i).compareTo(b.length - j);
  }

  static bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;
}

class _SortKey {
  final int family;
  final int major;
  final int minor;

  const _SortKey(this.family, this.major, this.minor);
}
