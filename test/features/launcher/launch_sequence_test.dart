import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/core/services/process_service.dart';
import 'package:quickdoom/core/services/window_controller.dart';
import 'package:quickdoom/domain/interfaces/i_process_launcher.dart';
import 'package:quickdoom/features/launcher/domain/launch_sequence.dart';
import 'package:quickdoom/features/launcher/presentation/providers/launch_sequence_provider.dart';
import 'package:quickdoom/features/launcher/presentation/providers/process_provider.dart';

/// Records the order window calls arrive in, which is the whole point: the
/// window must not hide before the sequence has played, and must never hide
/// at all if the game failed to start.
class FakeWindow implements WindowController {
  final List<String> calls = [];

  @override
  Future<void> hide() async => calls.add('hide');

  @override
  Future<void> show() async => calls.add('show');

  @override
  Future<void> focus() async => calls.add('focus');
}

class FakeLauncher implements IProcessLauncher {
  final Completer<int> exit = Completer<int>();
  final StreamController<String> logs = StreamController<String>.broadcast();
  final Object? failWith;

  /// Stages observed at the moment the process was spawned.
  LaunchStage? stageAtSpawn;

  final LaunchSequenceState Function()? readState;

  FakeLauncher({this.failWith, this.readState});

  int launches = 0;
  String? lastExecutable;
  List<String>? lastArgs;

  @override
  Future<ProcessStreamResult> launch(String executable, List<String> args) async {
    launches++;
    lastExecutable = executable;
    lastArgs = args;
    stageAtSpawn = readState?.call().stage;
    if (failWith != null) throw failWith!;
    return ProcessStreamResult(
      outputLogs: logs.stream,
      exitCode: exit.future,
    );
  }

  @override
  Future<bool> canLaunch(String executable) async => failWith == null;
}

void main() {
  late FakeWindow window;

  ProviderContainer containerWith(FakeLauncher launcher) {
    final container = ProviderContainer(overrides: [
      windowControllerProvider.overrideWithValue(window),
      processLauncherProvider.overrideWithValue(launcher),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => window = FakeWindow());

  Future<LaunchOutcome> run(
    ProviderContainer container, {
    LaunchTimings timings = LaunchTimings.instant,
    int modCount = 2,
  }) {
    return container.read(launchSequenceProvider.notifier).run(
          executable: '/bin/gzdoom',
          args: const ['-iwad', '/wads/doom2.wad'],
          portName: 'GZDoom',
          iwadName: 'DOOM II',
          modCount: modCount,
          timings: timings,
        );
  }

  group('a successful launch', () {
    test('hides the window only after the sequence has played', () async {
      final launcher = FakeLauncher();
      final container = containerWith(launcher);

      final outcome = await run(container);

      expect(outcome.started, isTrue);
      expect(window.calls, ['hide']);
      expect(container.read(launchSequenceProvider).stage, LaunchStage.running);
    });

    test('spawns the process during charge, not after handoff', () async {
      late FakeLauncher launcher;
      late ProviderContainer container;

      launcher = FakeLauncher(
        readState: () => container.read(launchSequenceProvider),
      );
      container = containerWith(launcher);

      await run(container);

      expect(
        launcher.stageAtSpawn,
        LaunchStage.charge,
        reason: 'the animation must cover startup latency, not follow it',
      );
    });

    test('passes the resolved command through to the launcher', () async {
      final launcher = FakeLauncher();
      final container = containerWith(launcher);

      await run(container);

      expect(launcher.launches, 1);
      expect(launcher.lastExecutable, '/bin/gzdoom');
      expect(launcher.lastArgs, ['-iwad', '/wads/doom2.wad']);
    });

    test('tracks the running process with a start time', () async {
      final launcher = FakeLauncher();
      final container = containerWith(launcher);

      await run(container);

      final process = container.read(processManagerProvider);
      expect(process, isNotNull);
      expect(process!.executable, '/bin/gzdoom');
      expect(
        DateTime.now().difference(process.startedAt).inSeconds,
        lessThan(5),
      );
    });

    test('walks the stages in order', () async {
      final launcher = FakeLauncher();
      final container = containerWith(launcher);

      final seen = <LaunchStage>[];
      container.listen(
        launchSequenceProvider,
        (_, next) => seen.add(next.stage),
        fireImmediately: true,
      );

      await run(container);

      expect(
        seen.where((s) => s != LaunchStage.idle).toList(),
        containsAllInOrder([
          LaunchStage.arm,
          LaunchStage.charge,
          LaunchStage.ignite,
          LaunchStage.handoff,
          LaunchStage.running,
        ]),
      );
    });
  });

  group('the return leg', () {
    test('restores the window and reports the session', () async {
      final launcher = FakeLauncher();
      final container = containerWith(launcher);

      await run(container);
      expect(window.calls, ['hide']);

      launcher.exit.complete(0);
      await pumpEventQueue();

      expect(window.calls, ['hide', 'show', 'focus']);

      final state = container.read(launchSequenceProvider);
      expect(state.stage, LaunchStage.summary);
      expect(state.summary!.ok, isTrue);
      expect(state.summary!.portName, 'GZDoom');
      expect(state.summary!.iwadName, 'DOOM II');
      expect(state.summary!.modCount, 2);
      expect(container.read(processManagerProvider), isNull);
    });

    test('a non-zero exit carries the stderr tail', () async {
      final launcher = FakeLauncher();
      final container = containerWith(launcher);

      await run(container);

      launcher.logs.add('[STDERR] Error: W_InitFiles: no files found\n');
      launcher.logs.add('ordinary stdout chatter\n');
      launcher.logs.add('[STDERR] Fatal: startup aborted\n');
      await pumpEventQueue();

      launcher.exit.complete(1);
      await pumpEventQueue();

      final summary = container.read(launchSequenceProvider).summary!;
      expect(summary.ok, isFalse);
      expect(summary.exitCode, 1);
      expect(summary.errorLines, [
        'Error: W_InitFiles: no files found',
        'Fatal: startup aborted',
      ]);
    });

    test('stderr written just before exit still reaches the readout', () async {
      // A port that dies on startup writes its reason and exits at once, so
      // the tail has to be waited for rather than sampled at exit time.
      final launcher = FakeLauncher();
      final container = containerWith(launcher);

      const withTail = LaunchTimings(
        arm: Duration.zero,
        charge: Duration.zero,
        ignite: Duration.zero,
        handoff: Duration.zero,
        powerOn: Duration.zero,
        spawnDelay: Duration.zero,
        tailGrace: Duration(milliseconds: 400),
      );

      await run(container, timings: withTail);

      launcher.logs.add('[STDERR] Error: IWAD not found\n');
      launcher.logs.add('[STDERR] Fatal: startup aborted\n');
      launcher.exit.complete(3);
      await launcher.logs.close();
      await pumpEventQueue();

      final summary = container.read(launchSequenceProvider).summary!;
      expect(summary.errorLines, [
        'Error: IWAD not found',
        'Fatal: startup aborted',
      ]);
    });

    test('a port that leaves its pipes open does not hang the return',
        () async {
      final launcher = FakeLauncher();
      final container = containerWith(launcher);

      const withTail = LaunchTimings(
        arm: Duration.zero,
        charge: Duration.zero,
        ignite: Duration.zero,
        handoff: Duration.zero,
        powerOn: Duration.zero,
        spawnDelay: Duration.zero,
        tailGrace: Duration(milliseconds: 100),
      );

      await run(container, timings: withTail);
      launcher.exit.complete(0);
      // The log stream is deliberately never closed.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await pumpEventQueue();

      expect(
        container.read(launchSequenceProvider).stage,
        anyOf(LaunchStage.returning, LaunchStage.summary),
        reason: 'the wait for the tail is bounded',
      );
    });

    test('a clean exit carries no error lines', () async {
      final launcher = FakeLauncher();
      final container = containerWith(launcher);

      await run(container);
      launcher.logs.add('[STDERR] a warning nobody needs to see\n');
      await pumpEventQueue();
      launcher.exit.complete(0);
      await pumpEventQueue();

      expect(container.read(launchSequenceProvider).summary!.errorLines, isEmpty);
    });

    test('dismissing the readout returns to idle', () async {
      final launcher = FakeLauncher();
      final container = containerWith(launcher);

      await run(container);
      launcher.exit.complete(0);
      await pumpEventQueue();

      container.read(launchSequenceProvider.notifier).dismissSummary();

      final state = container.read(launchSequenceProvider);
      expect(state.stage, LaunchStage.idle);
      expect(state.summary, isNull);
    });
  });

  group('a failed spawn', () {
    test('never hides the window', () async {
      final launcher = FakeLauncher(failWith: Exception('Executable not found'));
      final container = containerWith(launcher);

      final outcome = await run(container);

      expect(outcome.started, isFalse);
      expect(
        window.calls,
        isEmpty,
        reason: 'hiding over a game that never started strands the user',
      );
    });

    test('lands in fault with the reason', () async {
      final launcher = FakeLauncher(failWith: Exception('Executable not found'));
      final container = containerWith(launcher);

      await run(container);

      final state = container.read(launchSequenceProvider);
      expect(state.stage, LaunchStage.fault);
      expect(state.error, contains('Executable not found'));
      expect(container.read(processManagerProvider), isNull);
    });

    test('does not reach ignite or handoff', () async {
      final launcher = FakeLauncher(failWith: Exception('boom'));
      final container = containerWith(launcher);

      final seen = <LaunchStage>[];
      container.listen(launchSequenceProvider, (_, next) => seen.add(next.stage));

      await run(container);

      expect(seen, isNot(contains(LaunchStage.ignite)));
      expect(seen, isNot(contains(LaunchStage.handoff)));
      expect(seen, isNot(contains(LaunchStage.running)));
    });
  });

  group('recovering from a fault', () {
    test('a failed launch does not block the next one', () async {
      // The fault stage used to count as "taking over", so one bad launch
      // left the button refusing every attempt after it.
      final failing = FakeLauncher(failWith: Exception('Executable not found'));
      final container = containerWith(failing);

      final first = await run(container);
      expect(first.started, isFalse);

      // Still faulted, and a second attempt is accepted rather than refused.
      final second = await run(container);
      expect(
        second.error,
        isNot(contains('already under way')),
        reason: 'a fault is a shown state, not a launch in progress',
      );
    });

    test('the fault clears itself back to idle', () async {
      final launcher = FakeLauncher(failWith: Exception('boom'));
      final container = containerWith(launcher);

      await run(container);
      expect(container.read(launchSequenceProvider).stage, LaunchStage.fault);

      await Future<void>.delayed(
        LaunchSequence.faultFlashDuration + const Duration(milliseconds: 120),
      );

      expect(container.read(launchSequenceProvider).stage, LaunchStage.idle);
    });

    test('a launch succeeds after an earlier failure', () async {
      final failing = FakeLauncher(failWith: Exception('nope'));
      final container = containerWith(failing);
      await run(container);

      // A fresh container stands in for the user picking a working port.
      final working = FakeLauncher();
      final second = containerWith(working);
      final outcome = await run(second);

      expect(outcome.started, isTrue);
      expect(working.launches, 1);
    });
  });

  group('guards', () {
    test('a second launch while one is in flight is refused', () async {
      final launcher = FakeLauncher();
      final container = containerWith(launcher);

      final first = run(container, timings: LaunchTimings.standard);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final second = await run(container, timings: LaunchTimings.standard);

      expect(second.started, isFalse);
      expect(second.error, contains('already under way'));
      await first;
      expect(launcher.launches, 1);
    });

    test('the animated run takes materially longer than the instant one',
        () async {
      final quick = Stopwatch()..start();
      await run(containerWith(FakeLauncher()));
      quick.stop();

      final slow = Stopwatch()..start();
      await run(containerWith(FakeLauncher()), timings: LaunchTimings.standard);
      slow.stop();

      expect(slow.elapsedMilliseconds, greaterThan(800));
      expect(quick.elapsedMilliseconds, lessThan(400));
    });
  });

  group('timings', () {
    test('instant collapses every stage', () {
      for (final stage in LaunchStage.values) {
        expect(LaunchTimings.instant.forStage(stage), Duration.zero);
      }
    });

    test('the standard sequence stays close to a second and a half', () {
      const t = LaunchTimings.standard;
      final total = t.arm + t.charge + t.ignite + t.handoff;
      expect(total.inMilliseconds, lessThanOrEqualTo(1500));
      expect(t.spawnDelay, lessThan(t.charge));
    });
  });

  group('summary formatting', () {
    LaunchSummary withPlayTime(Duration d) => LaunchSummary(
          portName: 'p',
          iwadName: 'i',
          modCount: 0,
          playTime: d,
          exitCode: 0,
        );

    test('reads as seconds, minutes or hours', () {
      expect(withPlayTime(const Duration(seconds: 42)).playTimeLabel, '42s');
      expect(
        withPlayTime(const Duration(minutes: 7, seconds: 5)).playTimeLabel,
        '7m 5s',
      );
      expect(
        withPlayTime(const Duration(hours: 2, minutes: 13)).playTimeLabel,
        '2h 13m',
      );
    });
  });
}
