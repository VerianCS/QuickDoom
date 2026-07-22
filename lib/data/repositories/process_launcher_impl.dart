import 'dart:io';

import '../../core/services/process_service.dart';
import '../../domain/interfaces/i_process_launcher.dart';

class ProcessLauncherImpl implements IProcessLauncher {
  final ProcessService _processService;

  ProcessLauncherImpl(this._processService);

  @override
  Future<ProcessStreamResult> launch(
    String executable,
    List<String> args,
  ) async {
    final file = File(executable);
    if (!await file.exists()) {
      throw Exception('Executable not found: $executable');
    }

    return _processService.startProcess(executable, args);
  }

  @override
  Future<bool> canLaunch(String executable) async {
    return File(executable).exists();
  }
}
