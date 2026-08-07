import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/features/map_viewer/presentation/widgets/doom_map_painter.dart';
import 'package:quickdoom/features/map_viewer/presentation/widgets/doom_map_viewer.dart';
import 'package:quickdoom/features/map_viewer/presentation/widgets/map_geometry.dart';

import 'map_fixtures.dart';

void main() {
  Future<void> pumpViewer(
    WidgetTester tester, {
    required ValueChanged<MapSelection?> onSelection,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DoomMapViewer(
            map: MapFixtures.room(),
            layers: const MapViewerLayers(),
            onSelectionChanged: onSelection,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the map without errors', (tester) async {
    await pumpViewer(tester, onSelection: (_) {});
    expect(find.byType(DoomMapViewer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap at a thing reports a thing selection', (tester) async {
    MapSelection? picked;
    await pumpViewer(tester, onSelection: (s) => picked = s);

    // The thing sits at world (128, -128) in a 256x256 map inside a
    // 800x600 viewport; it lands centre-ish of the canvas.
    await tester.tapAt(const Offset(400, 300));
    await tester.pump();

    expect(picked, isA<ThingSelection>());
  });

  testWidgets('tap on empty space clears selection to null', (tester) async {
    MapSelection? picked = const LinedefSelection(0);
    await pumpViewer(tester, onSelection: (s) => picked = s);

    // Top-right corner: the fitted 256x256 map (in an 800x600 viewport)
    // ends near x=670, so this lands in the margin outside the map.
    await tester.tapAt(const Offset(770, 40));
    await tester.pump();

    expect(picked, isNull);
  });
}
