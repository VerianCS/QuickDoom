import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/features/map_viewer/presentation/widgets/doom_map_painter.dart';
import 'package:quickdoom/features/map_viewer/presentation/widgets/hologram_map_viewer.dart';
import 'package:quickdoom/features/map_viewer/presentation/widgets/map_geometry.dart';

import 'map_fixtures.dart';

void main() {
  // animate: false everywhere — the scan sweep repeats forever and would stop
  // the tester from ever settling.

  Future<void> pumpViewer(
    WidgetTester tester, {
    required ValueChanged<MapSelection?> onSelectionChanged,
    MapSelection? selection,
  }) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: HologramMapViewer(
            map: MapFixtures.room(),
            layers: const MapViewerLayers(showGrid: true),
            selection: selection,
            animate: false,
            onSelectionChanged: onSelectionChanged,
          ),
        ),
      ),
    ));
  }

  testWidgets('renders a map without throwing', (tester) async {
    await pumpViewer(tester, onSelectionChanged: (_) {});
    await tester.pumpAndSettle();

    expect(find.byType(HologramMapViewer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('frames the map on first layout', (tester) async {
    await pumpViewer(tester, onSelectionChanged: (_) {});
    await tester.pumpAndSettle();

    final state = tester.state<HologramMapViewerState>(
      find.byType(HologramMapViewer),
    );

    expect(state.camera.distance, greaterThan(0));
    expect(state.camera.target.x, closeTo(128, 1));
    expect(state.camera.target.y, closeTo(-128, 1));
  });

  testWidgets('dragging orbits rather than selecting', (tester) async {
    MapSelection? selected;
    var callbacks = 0;

    await pumpViewer(tester, onSelectionChanged: (s) {
      selected = s;
      callbacks++;
    });
    await tester.pumpAndSettle();

    final state = tester.state<HologramMapViewerState>(
      find.byType(HologramMapViewer),
    );
    final yawBefore = state.camera.yaw;

    await tester.drag(find.byType(HologramMapViewer), const Offset(120, 0));
    await tester.pumpAndSettle();

    expect(state.camera.yaw, isNot(yawBefore), reason: 'the drag orbited');
    expect(callbacks, 0, reason: 'a drag must not be treated as a click');
    expect(selected, isNull);
  });

  testWidgets('a click reports a selection', (tester) async {
    MapSelection? selected;
    var called = false;

    await pumpViewer(tester, onSelectionChanged: (s) {
      selected = s;
      called = true;
    });
    await tester.pumpAndSettle();

    // The middle of the viewport looks at the middle of the framed map.
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(selected, isNotNull);
  });

  testWidgets('resetView re-frames after the camera has moved',
      (tester) async {
    await pumpViewer(tester, onSelectionChanged: (_) {});
    await tester.pumpAndSettle();

    final state = tester.state<HologramMapViewerState>(
      find.byType(HologramMapViewer),
    );
    final framedDistance = state.camera.distance;

    state.camera.dolly(4);
    state.camera.orbit(1.2, 0.3);
    expect(state.camera.distance, isNot(framedDistance));

    state.resetView();
    await tester.pumpAndSettle();

    expect(state.camera.distance, closeTo(framedDistance, 0.001));
  });

  testWidgets('shows a grab cursor when idle', (tester) async {
    await pumpViewer(tester, onSelectionChanged: (_) {});
    await tester.pumpAndSettle();

    final region = tester.widget<MouseRegion>(
      find.byKey(const Key('hologramMouseRegion')),
    );
    expect(region.cursor, SystemMouseCursors.grab);
  });
}
