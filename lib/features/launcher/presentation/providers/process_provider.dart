import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/process_service.dart';

part 'process_provider.g.dart';

class RunningProcess {
  final ProcessStreamResult result;
  final String executable;
  final List<String> args;

  const RunningProcess({
    required this.result,
    required this.executable,
    required this.args,
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
