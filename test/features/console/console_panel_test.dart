import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/app/theme/app_colors.dart';
import 'package:quickdoom/core/services/process_service.dart';
import 'package:quickdoom/features/console/presentation/widgets/console_panel.dart';
import 'package:quickdoom/features/launcher/presentation/providers/process_provider.dart';

void main() {
  late StreamController<String> logs;
  late Completer<int> exit;
  late ProviderContainer container;

  RunningProcess makeProcess() => RunningProcess(
        result: ProcessStreamResult(
          outputLogs: logs.stream,
          exitCode: exit.future,
        ),
        executable: '/bin/fakedoom',
        args: const [],
        startedAt: DateTime.now(),
      );

  setUp(() {
    logs = StreamController<String>.broadcast();
    exit = Completer<int>();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Future<void> pumpConsole(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: Column(children: [ConsolePanel()])),
      ),
    ));
    await tester.pump();
  }

  testWidgets('stays out of the way when nothing has run', (tester) async {
    await pumpConsole(tester);
    expect(find.text('IDLE'), findsNothing);
    expect(find.byType(ConsolePanel), findsOneWidget);
  });

  testWidgets('reads RUNNING while a process is up', (tester) async {
    await pumpConsole(tester);
    container.read(processManagerProvider.notifier).track(makeProcess());
    await tester.pump();

    expect(find.text('RUNNING'), findsOneWidget);
  });

  testWidgets('shows output and counts the lines', (tester) async {
    await pumpConsole(tester);
    container.read(processManagerProvider.notifier).track(makeProcess());
    await tester.pump();

    logs.add('FakeDoom 1.0 starting\nargs: -iwad doom2.wad\n');
    await tester.pump();

    expect(find.text('FakeDoom 1.0 starting'), findsOneWidget);
    expect(find.text('args: -iwad doom2.wad'), findsOneWidget);
    expect(find.text('2 lines'), findsOneWidget);
  });

  testWidgets('keeps every chunk across rebuilds', (tester) async {
    // Each arriving chunk triggers a rebuild. Re-subscribing there dropped
    // whatever landed in the gap, losing the startup banner.
    await pumpConsole(tester);
    container.read(processManagerProvider.notifier).track(makeProcess());
    await tester.pump();

    logs.add('FakeDoom 1.0 starting\n');
    await tester.pump();
    logs.add('args: -iwad doom2.wad\n');
    await tester.pump();
    logs.add('FakeDoom exiting cleanly\n');
    await tester.pump();

    expect(find.text('FakeDoom 1.0 starting'), findsOneWidget);
    expect(find.text('args: -iwad doom2.wad'), findsOneWidget);
    expect(find.text('FakeDoom exiting cleanly'), findsOneWidget);
    expect(find.text('3 lines'), findsOneWidget);
  });

  testWidgets('strips the stderr marker and colours the line', (tester) async {
    await pumpConsole(tester);
    container.read(processManagerProvider.notifier).track(makeProcess());
    await tester.pump();

    logs.add('[STDERR] Error: IWAD not found\n');
    await tester.pump();

    // The marker is plumbing, not something to read.
    expect(find.text('Error: IWAD not found'), findsOneWidget);
    expect(find.textContaining('[STDERR]'), findsNothing);

    final line = tester.widget<Text>(find.text('Error: IWAD not found'));
    expect(line.style?.color, AppColors.error);
  });

  testWidgets('reports the exit code once the process ends', (tester) async {
    await pumpConsole(tester);
    container.read(processManagerProvider.notifier).track(makeProcess());
    await tester.pump();

    logs.add('starting\n');
    await tester.pump();

    exit.complete(3);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    container.read(processManagerProvider.notifier).clear();
    await tester.pump();

    expect(find.text('EXIT 3'), findsOneWidget);
  });

  testWidgets('clear is offered only once the process has stopped',
      (tester) async {
    await pumpConsole(tester);
    container.read(processManagerProvider.notifier).track(makeProcess());
    await tester.pump();

    logs.add('starting\n');
    await tester.pump();
    expect(find.text('CLEAR'), findsNothing);

    exit.complete(0);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    container.read(processManagerProvider.notifier).clear();
    await tester.pump();

    expect(find.text('CLEAR'), findsOneWidget);
    await tester.tap(find.text('CLEAR'));
    await tester.pump();

    expect(find.text('starting'), findsNothing);
  });
}
