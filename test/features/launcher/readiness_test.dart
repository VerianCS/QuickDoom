import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/domain/entities/iwad.dart';
import 'package:quickdoom/domain/entities/source_port.dart';
import 'package:quickdoom/features/launcher/presentation/providers/launch_provider.dart';
import 'package:quickdoom/app/theme/app_colors.dart';
import 'package:quickdoom/features/launcher/presentation/widgets/quick_launch_bar.dart';

const _port = SourcePort(id: 'p', name: 'gzdoom', executablePath: '/opt/gzdoom');
const _iwad = Iwad(id: 'i', name: 'doom2.wad', path: '/wads/doom2.wad');

void main() {
  group('readinessLine', () {
    test('a full, healthy bench is ready', () {
      expect(
        readinessLine(missing: const [], broken: const []).$1,
        'Ready to fire',
      );
    });

    // The slot showed a warning while the plate under it still said "Ready to
    // fire", and the plate is what people read before pressing it.
    test('a seated file that cannot be run is not "ready"', () {
      final (text, colour) =
          readinessLine(missing: const [], broken: const ['source port']);

      expect(text, contains('cannot be run'));
      expect(colour, AppColors.caution);
    });

    test('an empty socket outranks a broken one, because it comes first', () {
      expect(
        readinessLine(
          missing: const ['an IWAD'],
          broken: const ['source port'],
        ).$1,
        'Seat an IWAD to arm',
      );
    });

    test('both broken files are named', () {
      expect(
        readinessLine(
          missing: const [],
          broken: const ['source port', 'IWAD'],
        ).$1,
        contains('source port and IWAD'),
      );
    });
  });

  Future<void> pumpBar(
    WidgetTester tester, {
    SourcePort? port,
    Iwad? iwad,
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Hold a subscription: reading an autoDispose provider and letting go
    // schedules a dispose timer that outlives the test binding.
    container.listen(launchNotifierProvider, (_, _) {}, fireImmediately: true);

    final notifier = container.read(launchNotifierProvider.notifier);
    if (port != null) notifier.setSourcePort(port);
    if (iwad != null) notifier.setIwad(iwad);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: QuickLaunchBar(
            canLaunch: container.read(launchNotifierProvider).canLaunch,
            isLaunching: false,
            onLaunch: ({required bool animate}) {},
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  group('the launch plate explains why it is dark', () {
    testWidgets('with nothing seated it names both', (tester) async {
      await pumpBar(tester);
      expect(
        find.text('Seat a source port and an IWAD to arm'),
        findsOneWidget,
      );
    });

    // The article belongs to the phrase, not to the position: joining with
    // " and an " produced "Seat a IWAD to arm" whenever only the IWAD was
    // missing.
    testWidgets('with only the IWAD missing it says "an IWAD"',
        (tester) async {
      await pumpBar(tester, port: _port);
      expect(find.text('Seat an IWAD to arm'), findsOneWidget);
    });

    testWidgets('with only the port missing it says "a source port"',
        (tester) async {
      await pumpBar(tester, iwad: _iwad);
      expect(find.text('Seat a source port to arm'), findsOneWidget);
    });

    testWidgets('fully loaded, it reports ready', (tester) async {
      await pumpBar(tester, port: _port, iwad: _iwad);
      expect(find.text('Ready to fire'), findsOneWidget);
      expect(find.text('CTRL+L'), findsOneWidget);
    });
  });
}
