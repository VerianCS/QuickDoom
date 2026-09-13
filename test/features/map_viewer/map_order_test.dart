import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/features/map_viewer/domain/models/doom_map.dart';
import 'package:quickdoom/features/map_viewer/domain/models/map_order.dart';

DoomMap named(String name) => DoomMap(
      name: name,
      format: MapFormat.classicDoom,
      vertices: const [],
      linedefs: const [],
      sidedefs: const [],
      sectors: const [],
      things: const [],
    );

List<String> order(List<String> names) =>
    MapOrder.sorted([for (final name in names) named(name)])
        .map((m) => m.name)
        .toList();

void main() {
  group('MAP## sets', () {
    test('authoring order becomes level order', () {
      // The exact shape a PWAD produces when maps are appended as made.
      expect(
        order(['MAP01', 'MAP08', 'MAP04', 'MAP10', 'MAP02']),
        ['MAP01', 'MAP02', 'MAP04', 'MAP08', 'MAP10'],
      );
    });

    test('numbers sort numerically, not as text', () {
      expect(
        order(['MAP10', 'MAP9', 'MAP2', 'MAP20', 'MAP1']),
        ['MAP1', 'MAP2', 'MAP9', 'MAP10', 'MAP20'],
      );
    });

    test('a full 32-level set comes out in order', () {
      final shuffled = [
        for (var i = 32; i >= 1; i--) 'MAP${i.toString().padLeft(2, '0')}',
      ];
      final sorted = order(shuffled);

      expect(sorted.first, 'MAP01');
      expect(sorted[9], 'MAP10');
      expect(sorted.last, 'MAP32');
      expect(sorted, hasLength(32));
    });

    test('three-digit map names are handled', () {
      expect(order(['MAP100', 'MAP99', 'MAP01']), ['MAP01', 'MAP99', 'MAP100']);
    });
  });

  group('episodic sets', () {
    test('sorted by episode then level', () {
      expect(
        order(['E2M1', 'E1M9', 'E1M1', 'E3M4', 'E1M10', 'E2M9']),
        ['E1M1', 'E1M9', 'E1M10', 'E2M1', 'E2M9', 'E3M4'],
      );
    });

    test('episode beats level number', () {
      expect(order(['E4M1', 'E1M8']), ['E1M8', 'E4M1']);
    });
  });

  group('mixed and unusual names', () {
    test('episodic maps group ahead of MAP## maps', () {
      final sorted = order(['MAP01', 'E1M1', 'MAP02', 'E1M2']);
      expect(sorted, ['E1M1', 'E1M2', 'MAP01', 'MAP02']);
    });

    test('custom names sort after the known shapes', () {
      final sorted = order(['TITLEMAP', 'MAP01', 'E1M1']);
      expect(sorted, ['E1M1', 'MAP01', 'TITLEMAP']);
    });

    test('custom names compare naturally among themselves', () {
      expect(
        order(['LEVEL10', 'LEVEL2', 'LEVEL1']),
        ['LEVEL1', 'LEVEL2', 'LEVEL10'],
      );
    });

    test('name matching is case-insensitive', () {
      expect(order(['map03', 'MAP01', 'Map02']),
          ['MAP01', 'Map02', 'map03']);
    });
  });

  group('stability', () {
    test('duplicate names keep their original relative order', () {
      // A PWAD replacing an IWAD level can produce two markers with one name;
      // Dart's sort is not stable, so this is pinned deliberately.
      final first = named('MAP01');
      final second = named('MAP01');
      final sorted = MapOrder.sorted([first, second, named('MAP00')]);

      expect(sorted[0].name, 'MAP00');
      expect(identical(sorted[1], first), isTrue);
      expect(identical(sorted[2], second), isTrue);
    });

    test('an already ordered list is unchanged', () {
      expect(order(['MAP01', 'MAP02', 'MAP03']), ['MAP01', 'MAP02', 'MAP03']);
    });

    test('empty and single-item lists are fine', () {
      expect(order([]), isEmpty);
      expect(order(['MAP07']), ['MAP07']);
    });
  });

  group('compareNames', () {
    test('is consistent with itself', () {
      expect(MapOrder.compareNames('MAP01', 'MAP02'), lessThan(0));
      expect(MapOrder.compareNames('MAP02', 'MAP01'), greaterThan(0));
      expect(MapOrder.compareNames('MAP01', 'MAP01'), 0);
    });
  });
}
