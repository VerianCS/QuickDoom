import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/domain/entities/pwad.dart';
import 'package:quickdoom/features/launcher/presentation/providers/launch_provider.dart';
import 'package:quickdoom/features/launcher/presentation/widgets/pwad_rail.dart';

Pwad _p(String name) => Pwad(id: name, path: '/mods/$name.wad');

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    container.listen(launchNotifierProvider, (_, _) {}, fireImmediately: true);
    container
        .read(launchNotifierProvider.notifier)
        .addPwads([_p('a'), _p('b'), _p('c'), _p('d')]);
  });

  tearDown(() => container.dispose());

  Future<void> pumpRail(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: PwadRail())),
      ),
    ));
    await tester.pump();
  }

  List<String> order() =>
      container.read(launchNotifierProvider).pwads.map((p) => p.id).toList();

  /// Drags the handle of the row at [from] by [rows] slots.
  Future<void> dragRow(WidgetTester tester, int from, int rows) async {
    final handle = find.byIcon(Icons.drag_indicator).at(from);
    final rowHeight = tester.getSize(find.byIcon(Icons.close).first).height + 41;

    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 600));
    // Several small steps: one jump does not let the list settle its
    // drop target.
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(Offset(0, rows * rowHeight / 8));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  group('the load order rail', () {
    testWidgets('numbers every slot from one', (tester) async {
      await pumpRail(tester);

      expect(find.text('01'), findsOneWidget);
      expect(find.text('04'), findsOneWidget);
      expect(find.text('4 of 4 active'), findsOneWidget);
    });

    testWidgets('marks the deepest file as the one that wins', (tester) async {
      await pumpRail(tester);

      expect(find.text('TOP'), findsOneWidget);
      final top = tester.getCenter(find.text('TOP'));
      final last = tester.getCenter(find.text('d.wad'));
      expect(top.dy, closeTo(last.dy, 2));
    });

    // This pins the index correction at the call site. onReorder reports a
    // destination in the pre-lift list, movePwad wants a post-drop one, and
    // getting that wrong is an off-by-one that only ever shows up on a
    // downward drag.
    testWidgets('dragging down lands where it was dropped', (tester) async {
      await pumpRail(tester);
      await dragRow(tester, 0, 2);

      expect(order(), ['b', 'c', 'a', 'd']);
    });

    testWidgets('dragging up lands where it was dropped', (tester) async {
      await pumpRail(tester);
      await dragRow(tester, 3, -3);

      expect(order(), ['d', 'a', 'b', 'c']);
    });

    testWidgets('toggling a row off drops it from the active count',
        (tester) async {
      await pumpRail(tester);

      await tester.tap(find.byIcon(Icons.check_box).first);
      await tester.pump();

      expect(find.text('3 of 4 active'), findsOneWidget);
    });

    testWidgets('removing a row renumbers the rest', (tester) async {
      await pumpRail(tester);

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();

      expect(order(), ['b', 'c', 'd']);
      expect(find.text('03'), findsOneWidget);
      expect(find.text('04'), findsNothing);
    });
  });
}
