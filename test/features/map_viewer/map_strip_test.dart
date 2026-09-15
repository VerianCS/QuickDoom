import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/features/map_viewer/data/repositories/wad_repository.dart';
import 'package:quickdoom/features/map_viewer/domain/models/doom_map.dart';
import 'package:quickdoom/features/map_viewer/presentation/widgets/map_strip.dart';

import 'fixtures/wad_fixture.dart';

DoomMap named(String name) => DoomMap(
      name: name,
      format: MapFormat.classicDoom,
      vertices: const [],
      linedefs: const [],
      sidedefs: const [],
      sectors: const [],
      things: const [],
    );

List<DoomMap> megawad() => [
      for (var i = 1; i <= 32; i++)
        named('MAP${i.toString().padLeft(2, '0')}'),
    ];

/// Builds a WAD carrying [names] as map markers, in the order given.
Uint8List wadWithMaps(List<String> names) {
  return WadFixture.build(magic: 'PWAD', lumps: [
    for (final name in names) ...[
      (name, <int>[]),
      ('THINGS', <int>[]),
      ('LINEDEFS', <int>[]),
      ('VERTEXES', <int>[]),
      ('SIDEDEFS', <int>[]),
      ('SECTORS', <int>[]),
    ],
  ]);
}

void main() {
  Future<void> pumpStrip(
    WidgetTester tester,
    List<DoomMap> maps, {
    DoomMap? current,
    ValueChanged<DoomMap>? onSelected,
    double width = 900,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: MapStrip(
              maps: maps,
              current: current ?? maps.first,
              onSelected: onSelected ?? (_) {},
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('reachability', () {
    testWidgets('renders every map, not just the ones that fit one row',
        (tester) async {
      // The old horizontal list built only what was on screen and could not be
      // scrolled with a mouse, so the tail of a megawad was unreachable.
      final maps = megawad();
      await pumpStrip(tester, maps);

      for (final map in maps) {
        expect(
          find.text(map.name),
          findsOneWidget,
          reason: '${map.name} must be in the list',
        );
      }
    });

    testWidgets('the last map of a 32-level set can be tapped',
        (tester) async {
      final maps = megawad();
      DoomMap? tapped;

      await pumpStrip(tester, maps, onSelected: (map) => tapped = map);

      await tester.scrollUntilVisible(find.text('MAP32'), 40);
      await tester.tap(find.text('MAP32'));
      await tester.pumpAndSettle();

      expect(tapped?.name, 'MAP32');
    });

    testWidgets('stays scrollable at a narrow width', (tester) async {
      final maps = megawad();
      await pumpStrip(tester, maps, width: 320);

      await tester.scrollUntilVisible(find.text('MAP32'), 40);
      expect(find.text('MAP32'), findsOneWidget);
    });

    testWidgets('chips share rows instead of one map per line',
        (tester) async {
      // Container.alignment expands a chip to the full width offered, which
      // under a Wrap puts every map on its own row and pushes the rest out of
      // reach again.
      await pumpStrip(tester, megawad(), width: 900);

      final first = tester.getCenter(find.text('MAP01'));
      final second = tester.getCenter(find.text('MAP02'));

      expect(second.dy, first.dy, reason: 'MAP01 and MAP02 share a row');
      expect(second.dx, greaterThan(first.dx));
      expect(
        tester.getSize(find.byType(MapStrip)).width,
        greaterThan(tester.getSize(find.text('MAP01')).width * 4),
        reason: 'a chip must not span the whole strip',
      );
    });

    testWidgets('a short list needs no scrolling', (tester) async {
      final maps = [named('MAP01'), named('MAP02')];
      await pumpStrip(tester, maps);

      expect(find.text('MAP01'), findsOneWidget);
      expect(find.text('MAP02'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('selection', () {
    testWidgets('tapping a map reports it', (tester) async {
      final maps = [named('MAP01'), named('MAP02'), named('MAP03')];
      DoomMap? tapped;

      await pumpStrip(tester, maps, onSelected: (map) => tapped = map);
      await tester.tap(find.text('MAP02'));
      await tester.pumpAndSettle();

      expect(tapped?.name, 'MAP02');
    });
  });

  group('ordering through the repository', () {
    test('maps come back in level order, not directory order', () {
      final bytes = wadWithMaps(['MAP01', 'MAP08', 'MAP04', 'MAP10', 'MAP02']);
      final maps = WadRepository().parseBytes('test.wad', bytes);

      expect(
        maps.map((m) => m.name),
        ['MAP01', 'MAP02', 'MAP04', 'MAP08', 'MAP10'],
      );
    });

    test('episodic maps are ordered by episode then level', () {
      final bytes = wadWithMaps(['E1M10', 'E2M1', 'E1M2', 'E1M1']);
      final maps = WadRepository().parseBytes('test.wad', bytes);

      expect(maps.map((m) => m.name), ['E1M1', 'E1M2', 'E1M10', 'E2M1']);
    });
  });
}
