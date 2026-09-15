import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/app/theme/app_colors.dart';
import 'package:quickdoom/core/services/file_problem.dart';
import 'package:quickdoom/features/launcher/presentation/widgets/loadout_slot.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: 460, child: child))),
    );

void main() {
  group('FileProblem', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('qd_problem'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('an existing data file is fine without an execute bit', () async {
      final f = File('${dir.path}/doom2.wad')..writeAsStringSync('x');
      expect(await FileProblem.describe(f.path, noun: 'IWAD'), isNull);
    });

    test('a missing IWAD is named as an IWAD, not a source port', () async {
      final problem = await FileProblem.describe(
        '${dir.path}/gone.wad',
        noun: 'IWAD',
      );
      expect(problem, startsWith('IWAD not found'));
    });

    test('summarise keeps the first line for a one-line slot', () {
      expect(
        FileProblem.summarise('IWAD not found: /x\nIt may have been moved.'),
        'IWAD not found: /x',
      );
    });
  });

  group('a slot with a broken file', () {
    testWidgets('shows the problem instead of the path', (tester) async {
      await tester.pumpWidget(_wrap(const LoadoutSlot(
        ordinal: 'II',
        label: 'IWAD',
        icon: Icons.album_outlined,
        emptyHint: 'No game seated',
        value: 'doom2.wad',
        detail: '/usr/share/doom/doom2.wad',
        problem:
            'IWAD not found: /usr/share/doom/doom2.wad\nIt may have moved.',
      )));

      expect(
        find.text('IWAD not found: /usr/share/doom/doom2.wad'),
        findsOneWidget,
      );
      expect(find.text('…/doom/doom2.wad'), findsNothing);
    });

    testWidgets('warns rather than showing the content icon', (tester) async {
      await tester.pumpWidget(_wrap(const LoadoutSlot(
        ordinal: 'I',
        label: 'Source Port',
        icon: Icons.memory,
        emptyHint: 'No engine seated',
        value: 'gzdoom',
        detail: '/opt/gzdoom',
        problem: 'Source port not found: /opt/gzdoom',
      )));

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.byIcon(Icons.memory), findsNothing);
    });

    testWidgets('the name is recoloured, so a glance is enough',
        (tester) async {
      await tester.pumpWidget(_wrap(const LoadoutSlot(
        ordinal: 'I',
        label: 'Source Port',
        icon: Icons.memory,
        emptyHint: 'No engine seated',
        value: 'gzdoom',
        problem: 'Source port not found: /opt/gzdoom',
      )));

      final name = tester.widget<Text>(find.text('gzdoom'));
      expect(name.style?.color, AppColors.caution);
    });

    // An empty socket is not broken; it has nothing in it to be wrong.
    testWidgets('an empty slot is never marked broken', (tester) async {
      await tester.pumpWidget(_wrap(const LoadoutSlot(
        ordinal: 'I',
        label: 'Source Port',
        icon: Icons.memory,
        emptyHint: 'No engine seated',
        problem: 'ignored while nothing is seated',
      )));

      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.byIcon(Icons.memory), findsOneWidget);
    });

    testWidgets('a healthy slot still shows its path', (tester) async {
      await tester.pumpWidget(_wrap(const LoadoutSlot(
        ordinal: 'II',
        label: 'IWAD',
        icon: Icons.album_outlined,
        emptyHint: 'No game seated',
        value: 'doom2.wad',
        detail: '/usr/share/doom/doom2.wad',
      )));

      expect(find.text('…/doom/doom2.wad'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });
  });
}
