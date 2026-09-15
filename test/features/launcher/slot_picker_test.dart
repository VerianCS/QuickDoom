import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/app/widgets/notched_panel.dart';
import 'package:quickdoom/features/launcher/presentation/widgets/slot_picker.dart';

void main() {
  Future<SlotChoice<String>?> open(
    WidgetTester tester, {
    List<SlotEntry<String>> entries = const [],
  }) async {
    SlotChoice<String>? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showSlotPicker<String>(
                context: context,
                title: 'Source Port',
                entries: entries,
                emptyLabel: 'No saved ports yet.',
                browseLabel: 'Browse for an executable…',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('the browse row is reachable when the list is empty',
      (tester) async {
    await open(tester);

    expect(find.text('No saved ports yet.'), findsOneWidget);
    await tester.tap(find.text('Browse for an executable…'));
    await tester.pumpAndSettle();

    expect(find.text('No saved ports yet.'), findsNothing,
        reason: 'the picker should have closed');
  });

  testWidgets('picking an entry returns it', (tester) async {
    await open(tester, entries: const [
      SlotEntry(value: 'gzdoom', label: 'GZDoom', detail: '/opt/gzdoom'),
      SlotEntry(value: 'dsda', label: 'DSDA-Doom', detail: '/opt/dsda'),
    ]);

    expect(find.text('GZDoom'), findsOneWidget);
    await tester.tap(find.text('DSDA-Doom'));
    await tester.pumpAndSettle();

    expect(find.text('GZDoom'), findsNothing);
  });

  testWidgets('an empty picker does not stretch to its maximum height',
      (tester) async {
    await open(tester);

    // Dialog's own box is the full-screen inset padding, so measure the panel.
    final box = tester.getSize(find.byType(NotchedPanel));
    expect(box.height, lessThan(300),
        reason: 'an empty list should not fill the 460px cap');
  });
}
