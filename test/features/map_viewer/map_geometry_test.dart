import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/features/map_viewer/presentation/widgets/map_geometry.dart';

import 'map_fixtures.dart';

void main() {
  group('MapGeometry sector loops', () {
    test('builds a closed loop for a simple room', () {
      final map = MapFixtures.room();
      final loops = MapGeometry.buildSectorLoops(map);

      expect(loops, hasLength(1));
      expect(loops.single.sectorIndex, 0);
      expect(loops.single.vertexIndices.length, greaterThanOrEqualTo(3));
    });

    test('builds separate loops for wall-sharing sectors', () {
      final map = MapFixtures.twRooms();
      final loops = MapGeometry.buildSectorLoops(map);

      expect(loops, hasLength(2));
      expect(loops.map((l) => l.sectorIndex).toSet(), {0, 1});
    });
  });

  group('MapGeometry picking', () {
    test('picks the closest linedef within tolerance', () {
      final map = MapFixtures.room();
      final point = Offset(32, 4); // inside the room, near the y=0 wall
      expect(MapGeometry.pickLinedef(map, point, 8), greaterThanOrEqualTo(0));
    });

    test('returns -1 when no linedef is within tolerance', () {
      final map = MapFixtures.room();
      final point = Offset(128, -128); // room centre, far from walls
      expect(MapGeometry.pickLinedef(map, point, 8), -1);
    });

    test('picks the nearest thing within tolerance', () {
      final map = MapFixtures.room();
      final point = Offset(128, -128); // on top of the player start
      expect(MapGeometry.pickThing(map, point, 4), 0);
    });

    test('returns -1 when no thing is within tolerance', () {
      final map = MapFixtures.room();
      expect(MapGeometry.pickThing(map, Offset(32, -32), 4), -1);
    });

    test('sectorAtPoint returns the containing sector', () {
      final map = MapFixtures.room();
      final loops = MapGeometry.buildSectorLoops(map);
      expect(MapGeometry.sectorAtPoint(map, Offset(128, -128), loops), 0);
    });

    test('sectorAtPoint returns -1 outside all sectors', () {
      final map = MapFixtures.room();
      final loops = MapGeometry.buildSectorLoops(map);
      expect(MapGeometry.sectorAtPoint(map, Offset(2000, 2000), loops), -1);
    });
  });

  group('pickElement', () {
    test('prefers linedef over thing when both within tolerance', () {
      final map = MapFixtures.thingNearLine();
      final element = pickElement(map, Offset(32, 1));
      expect(element, isA<LinedefSelection>());
    });

    test('prefers thing over sector when no linedef is near', () {
      final map = MapFixtures.room();
      final element = pickElement(map, Offset(128, -128));
      expect(element, isA<ThingSelection>());
    });

    test('falls back to sector when nothing else is near', () {
      final map = MapFixtures.room();
      final element = pickElement(map, Offset(64, -64));
      expect(element, isA<SectorSelection>());
      expect((element! as SectorSelection).sectorIndex, 0);
    });

    test('returns null far from any map geometry', () {
      final map = MapFixtures.room();
      expect(pickElement(map, Offset(9999, 9999)), isNull);
    });
  });
}