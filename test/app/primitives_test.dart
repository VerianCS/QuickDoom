import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/app/theme/app_colors.dart';
import 'package:quickdoom/app/widgets/doom_button.dart';
import 'package:quickdoom/app/widgets/doom_chip.dart';
import 'package:quickdoom/app/widgets/notched_panel.dart';
import 'package:quickdoom/app/widgets/section_rule.dart';
import 'package:quickdoom/app/widgets/stat_readout.dart';

Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('NotchedPanel', () {
    test('cuts opposite corners and closes the outline', () {
      final path = NotchedPanel.buildPath(const Size(100, 40), 10);
      final bounds = path.getBounds();

      expect(bounds.width, 100);
      expect(bounds.height, 40);
      // The cut corners are outside the shape.
      expect(path.contains(const Offset(2, 2)), isFalse);
      expect(path.contains(const Offset(98, 38)), isFalse);
      // The other two are not.
      expect(path.contains(const Offset(98, 2)), isTrue);
      expect(path.contains(const Offset(2, 38)), isTrue);
    });

    test('a notch larger than the box does not invert it', () {
      final path = NotchedPanel.buildPath(const Size(20, 20), 999);
      expect(path.getBounds().width, 20);
      expect(path.getBounds().height, 20);
    });

    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(wrap(
        const NotchedPanel(child: Text('seated')),
      ));
      expect(find.text('seated'), findsOneWidget);
    });
  });

  group('DoomButton', () {
    testWidgets('upper-cases its label and fires', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(
        DoomButton(label: 'Launch', onPressed: () => taps++),
      ));

      expect(find.text('LAUNCH'), findsOneWidget);
      await tester.tap(find.byType(DoomButton));
      expect(taps, 1);
    });

    testWidgets('does not fire without a callback', (tester) async {
      await tester.pumpWidget(wrap(const DoomButton(label: 'Launch')));
      await tester.tap(find.byType(DoomButton));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a busy button shows a spinner and ignores taps',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(
        DoomButton(label: 'Launch', busy: true, onPressed: () => taps++),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(DoomButton));
      expect(taps, 0);
    });

    testWidgets('shows a hint alongside the label', (tester) async {
      await tester.pumpWidget(wrap(
        DoomButton(label: 'Launch', hint: 'Ctrl+L', onPressed: () {}),
      ));
      expect(find.text('Ctrl+L'), findsOneWidget);
    });
  });

  group('DoomChip', () {
    testWidgets('reports taps and upper-cases its label', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(
        DoomChip(label: 'Things', onTap: () => taps++),
      ));

      expect(find.text('THINGS'), findsOneWidget);
      await tester.tap(find.byType(DoomChip));
      expect(taps, 1);
    });

    testWidgets('renders selected without throwing', (tester) async {
      await tester.pumpWidget(wrap(
        const DoomChip(label: 'Grid', selected: true, tint: AppColors.caution),
      ));
      expect(tester.takeException(), isNull);
    });
  });

  group('SectionRule', () {
    testWidgets('shows the label, note and trailing widget', (tester) async {
      await tester.pumpWidget(wrap(
        const SectionRule(
          label: 'PWADs',
          note: '3 loaded',
          trailing: Text('trail'),
        ),
      ));

      expect(find.text('PWADS'), findsOneWidget);
      expect(find.text('3 loaded'), findsOneWidget);
      expect(find.text('trail'), findsOneWidget);
    });
  });

  group('StatReadout', () {
    testWidgets('shows value over an upper-cased label', (tester) async {
      await tester.pumpWidget(wrap(
        const StatReadout(value: '1189', label: 'verts'),
      ));

      expect(find.text('1189'), findsOneWidget);
      expect(find.text('VERTS'), findsOneWidget);
    });
  });

  group('tokens', () {
    test('state colours are not the accent', () {
      // A running game and a selected tab must not be the same colour.
      expect(AppColors.success, isNot(AppColors.primary));
      expect(AppColors.phosphor, isNot(AppColors.primary));
      expect(AppColors.caution, isNot(AppColors.primary));
    });

    test('the neutral ramp gets lighter in order', () {
      double luminance(Color c) => c.computeLuminance();

      expect(luminance(AppColors.void_), lessThan(luminance(AppColors.background)));
      expect(
        luminance(AppColors.background),
        lessThan(luminance(AppColors.surface)),
      );
      expect(
        luminance(AppColors.surface),
        lessThan(luminance(AppColors.surfaceHigh)),
      );
    });

    test('text tones descend in prominence', () {
      expect(
        AppColors.onSurface.computeLuminance(),
        greaterThan(AppColors.onBackground.computeLuminance()),
      );
      expect(
        AppColors.onBackground.computeLuminance(),
        greaterThan(AppColors.onSurfaceFaint.computeLuminance()),
      );
    });
  });
}
