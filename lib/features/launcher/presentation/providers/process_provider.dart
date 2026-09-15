import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/process_service.dart';

part 'process_provider.g.dart';

class RunningProcess {
  final ProcessStreamResult result;
  final String executable;
  final List<String> args;

  /// When the process was spawned, so the session readout can report how long
  /// the game was actually up.
  final DateTime startedAt;

  const RunningProcess({
    required this.result,
    required this.executable,
    required this.args,
    required this.startedAt,
  });
}

@riverpod
class ProcessManager extends _$ProcessManager {
  @override
  RunningProcess? build() => null;

  void track(RunningProcess process) {
    state = process;
  }

  void clear() {
    state = null;
  }
}
