import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/core/services/process_service.dart';
import 'package:quickdoom/core/services/window_controller.dart';
import 'package:quickdoom/domain/interfaces/i_process_launcher.dart';
import 'package:quickdoom/features/launcher/domain/launch_sequence.dart';
import 'package:quickdoom/features/launcher/presentation/providers/launch_sequence_provider.dart';
import 'package:quickdoom/features/launcher/presentation/widgets/launch_sequence_overlay.dart';
import 'package:quickdoom/features/launcher/presentation/widgets/launch_sequence_painter.dart';

class _SilentWindow implements WindowController {
  @override
  Future<void> hide() async {}
  @override
  Future<void> show() async {}
  @override
  Future<void> focus() async {}
}

class _StubLauncher implements IProcessLauncher {
  final Completer<int> exit = Completer<int>();
  final StreamController<String> logs = StreamController<String>.broadcast();

  @override
  Future<ProcessStreamResult> launch(String executable, List<String> args) async {
    return ProcessStreamResult(outputLogs: logs.stream, exitCode: exit.future);
  }

  @override
  Future<bool> canLaunch(String executable) async => true;
}

void main() {
  late _StubLauncher launcher;
  late ProviderContainer container;

  setUp(() {
    launcher = _StubLauncher();
    container = ProviderContainer(overrides: [
      windowControllerProvider.overrideWithValue(_SilentWindow()),
      processLauncherProvider.overrideWithValue(launcher),
    ]);
    addTearDown(container.dispose);
  });

  Future<void> pumpOverlay(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Color(0xFF1E1E1E)),
            LaunchSequenceOverlay(timings: LaunchTimings.instant),
          ],
        ),
      ),
    ));
    await tester.pump();
  }

  Future<void> runToSummary(
    WidgetTester tester, {
    int exitCode = 0,
    List<String> stderr = const [],
  }) async {
    await container.read(launchSequenceProvider.notifier).run(
          executable: '/bin/fakedoom',
          args: const ['-iwad', '/wads/freedoom2.wad'],
          portName: 'FakeDoom',
          iwadName: 'freedoom2.wad',
          modCount: 3,
          timings: LaunchTimings.instant,
        );
    // Emitted only once the sequence is listening: the log stream is a
    // broadcast, so anything sent before the subscription exists is dropped.
    for (final line in stderr) {
      launcher.logs.add(line);
    }
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    launcher.exit.complete(exitCode);
    // The exit continuation is a real microtask; the fake-async zone a widget
    // test runs in will not drain it without stepping outside first.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  /// Matches this overlay's own painter, not the CustomPaints Material uses
  /// internally.
  final sequencePaint = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is LaunchSequencePainter,
  );

  testWidgets('draws nothing while idle', (tester) async {
    await pumpOverlay(tester);
    expect(sequencePaint, findsNothing);
    expect(find.text('SESSION ENDED'), findsNothing);
  });

  testWidgets('paints the takeover while the game is up', (tester) async {
    await pumpOverlay(tester);

    // Instant timings so no scheduled stage timer outlives the test; the
    // process is left running, which is still a takeover stage.
    await container.read(launchSequenceProvider.notifier).run(
          executable: '/bin/fakedoom',
          args: const [],
          portName: 'FakeDoom',
          iwadName: 'freedoom2.wad',
          modCount: 0,
          timings: LaunchTimings.instant,
        );
    await tester.pump();

    expect(container.read(launchSequenceProvider).stage, LaunchStage.running);
    expect(sequencePaint, findsOneWidget);

    launcher.exit.complete(0);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  });

  testWidgets('the readout reports the session', (tester) async {
    await pumpOverlay(tester);
    await runToSummary(tester);

    expect(find.text('SESSION ENDED'), findsOneWidget);
    expect(find.text('FakeDoom'), findsOneWidget);
    expect(find.text('freedoom2.wad'), findsOneWidget);
    expect(find.text('3 loaded'), findsOneWidget);
    expect(find.text('exit 0'), findsOneWidget);
  });

  testWidgets('the readout sits under a Material', (tester) async {
    // The overlay lives outside the router's Scaffold. Without a Material
    // ancestor every Text in it renders with debug underlines.
    await pumpOverlay(tester);
    await runToSummary(tester);

    expect(
      find.ancestor(
        of: find.text('SESSION ENDED'),
        matching: find.byType(Material),
      ),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('a non-zero exit reads as a fault', (tester) async {
    await pumpOverlay(tester);
    await runToSummary(
      tester,
      exitCode: 3,
      stderr: const ['[STDERR] Error: IWAD not found\n'],
    );

    expect(find.text('SESSION FAULTED'), findsOneWidget);
    expect(find.text('exit 3'), findsOneWidget);
    expect(find.text('Error: IWAD not found'), findsOneWidget);
  });

  testWidgets('dismissing clears the overlay', (tester) async {
    await pumpOverlay(tester);
    await runToSummary(tester);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.text('SESSION ENDED'), findsNothing);
    expect(
      container.read(launchSequenceProvider).stage,
      LaunchStage.idle,
    );
  });
}
