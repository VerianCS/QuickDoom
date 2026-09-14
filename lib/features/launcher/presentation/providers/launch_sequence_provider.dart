import 'dart:async';
import 'dart:ui';

import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/process_service.dart';
import '../../../../core/services/window_controller.dart';
import '../../../../data/repositories/process_launcher_impl.dart';
import '../../../../domain/interfaces/i_process_launcher.dart';
import '../../domain/launch_sequence.dart';
import 'process_provider.dart';

part 'launch_sequence_provider.g.dart';

final windowControllerProvider = Provider<WindowController>((ref) {
  return const WindowManagerController();
});

final processLauncherProvider = Provider<IProcessLauncher>((ref) {
  return ProcessLauncherImpl(ProcessService());
});

/// Whether the launch takeover plays, persisted across runs.
///
/// Someone testing a mod launches dozens of times an hour; making them sit
/// through the sequence every time would be the fastest way to have them
/// resent it.
@Riverpod(keepAlive: true)
class LaunchAnimationEnabled extends _$LaunchAnimationEnabled {
  static const String _key = 'launchAnimationEnabled';

  @override
  bool build() => _read() ?? true;

  void toggle() => set(!state);

  void set(bool value) {
    state = value;
    final box = _box();
    if (box != null) box.put(_key, value);
  }

  static bool? _read() => _box()?.get(_key) as bool?;

  /// Null before the bootstrap has opened storage, and in tests that never
  /// open it — the setting then falls back to on rather than failing.
  static Box<dynamic>? _box() {
    if (!Hive.isBoxOpen(AppConstants.hiveBoxName)) return null;
    return Hive.box<dynamic>(AppConstants.hiveBoxName);
  }
}

/// Result of running the sequence, so the caller can report an error without
/// having to read back through the stage state.
class LaunchOutcome {
  final bool started;
  final String? error;

  const LaunchOutcome.started()
      : started = true,
        error = null;

  const LaunchOutcome.failed(this.error) : started = false;
}

/// Drives the launch takeover.
///
/// Kept alive: the sequence outlives the launcher screen, since the window is
/// hidden for the whole session and the readout has to survive until the game
/// exits and the user dismisses it.
@Riverpod(keepAlive: true)
class LaunchSequence extends _$LaunchSequence {
  /// How many trailing stderr lines are kept for a fault readout.
  static const int _errorTailLength = 6;

  Timer? _pending;
  StreamSubscription<String>? _logs;

  @override
  LaunchSequenceState build() {
    ref.onDispose(() {
      _pending?.cancel();
      _logs?.cancel();
    });
    return const LaunchSequenceState();
  }

  /// Records where the launch control sits on screen, so the charge and the
  /// shockwave come out of the button the user actually pressed.
  void setFocal(Offset? focal) {
    if (focal == state.focal) return;
    state = state.copyWith(focal: focal);
  }

  void dismissSummary() {
    if (state.stage != LaunchStage.summary && state.stage != LaunchStage.fault) {
      return;
    }
    state = const LaunchSequenceState().copyWith(focal: state.focal);
  }

  /// Runs the whole takeover.
  ///
  /// Returns once the window has been hidden and the game is running — not
  /// when the game exits. The return leg is driven from the process's own exit
  /// future so the caller is not blocked for the length of a play session.
  Future<LaunchOutcome> run({
    required String executable,
    required List<String> args,
    required String portName,
    required String iwadName,
    required int modCount,
    required LaunchTimings timings,
  }) async {
    if (state.isTakingOver) return const LaunchOutcome.failed('Already launching');

    final window = ref.read(windowControllerProvider);
    final launcher = ref.read(processLauncherProvider);

    state = LaunchSequenceState(stage: LaunchStage.arm, focal: state.focal);
    await _hold(timings.arm);

    _to(LaunchStage.charge);
    await _hold(timings.spawnDelay);

    // The process starts here, part way into the charge, so the rest of the
    // animation runs over startup latency that was going to happen anyway.
    final ProcessStreamResult result;
    try {
      result = await launcher.launch(executable, args);
    } catch (e) {
      // Never hide the window over a game that failed to start.
      state = state.copyWith(stage: LaunchStage.fault, error: '$e');
      return LaunchOutcome.failed('$e');
    }

    final startedAt = DateTime.now();
    ref.read(processManagerProvider.notifier).track(RunningProcess(
          result: result,
          executable: executable,
          args: args,
          startedAt: startedAt,
        ));

    final errorTail = <String>[];
    _logs?.cancel();
    final logSubscription = result.outputLogs.listen((chunk) {
      for (final line in chunk.split('\n')) {
        if (line.trim().isEmpty) continue;
        if (!line.contains('[STDERR]')) continue;
        errorTail.add(line.replaceAll('[STDERR]', '').trim());
        if (errorTail.length > _errorTailLength) errorTail.removeAt(0);
      }
    });
    _logs = logSubscription;
    // Completes when the process's pipes close, which can be after exitCode.
    final tailDrained = logSubscription.asFuture<void>();

    await _hold(timings.charge - timings.spawnDelay);
    _to(LaunchStage.ignite);
    await _hold(timings.ignite);
    _to(LaunchStage.handoff);
    await _hold(timings.handoff);

    await window.hide();
    _to(LaunchStage.running);

    unawaited(_awaitExit(
      result: result,
      window: window,
      startedAt: startedAt,
      portName: portName,
      iwadName: iwadName,
      modCount: modCount,
      timings: timings,
      errorTail: errorTail,
      tailDrained: tailDrained,
    ));

    return const LaunchOutcome.started();
  }

  Future<void> _awaitExit({
    required ProcessStreamResult result,
    required WindowController window,
    required DateTime startedAt,
    required String portName,
    required String iwadName,
    required int modCount,
    required LaunchTimings timings,
    required List<String> errorTail,
    required Future<void> tailDrained,
  }) async {
    final exitCode = await result.exitCode;

    // Give the output pipes a moment to finish; see LaunchTimings.tailGrace.
    if (timings.tailGrace > Duration.zero) {
      await tailDrained
          .timeout(timings.tailGrace, onTimeout: () {})
          .catchError((_) {});
    }

    await _logs?.cancel();
    _logs = null;

    ref.read(processManagerProvider.notifier).clear();

    await window.show();
    await window.focus();

    final summary = LaunchSummary(
      portName: portName,
      iwadName: iwadName,
      modCount: modCount,
      playTime: DateTime.now().difference(startedAt),
      exitCode: exitCode,
      errorLines: exitCode == 0 ? const [] : List.unmodifiable(errorTail),
    );

    state = state.copyWith(stage: LaunchStage.returning, summary: summary);
    await _hold(timings.powerOn);
    state = state.copyWith(stage: LaunchStage.summary, summary: summary);
  }

  void _to(LaunchStage stage) {
    state = state.copyWith(stage: stage);
  }

  Future<void> _hold(Duration duration) {
    if (duration <= Duration.zero) return Future<void>.value();
    final completer = Completer<void>();
    _pending?.cancel();
    _pending = Timer(duration, completer.complete);
    return completer.future;
  }
}
