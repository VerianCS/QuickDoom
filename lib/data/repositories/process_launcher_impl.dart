import '../../core/services/file_problem.dart';
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
    final problem = await describeProblem(executable);
    if (problem != null) throw Exception(problem);

    return _processService.startProcess(executable, args);
  }

  @override
  Future<bool> canLaunch(String executable) async =>
      await describeProblem(executable) == null;

  /// Why [executable] cannot be run, or null if it can.
  ///
  /// This replaces an extension test that lived in BuildLaunchCommand, was
  /// never called from anywhere but its own test, and could not have worked:
  /// it lower-cased the extension and then compared it against '.AppImage'.
  /// Extensions cannot answer the question anyway — a Linux source port has
  /// none — so the check belongs here, next to the IO, where the real
  /// properties of the file can be read and a saved port that has since been
  /// moved, deleted or left non-executable gives a sentence rather than a
  /// failed spawn.
  static Future<String?> describeProblem(String executable) =>
      FileProblem.describe(executable, needsExecuteBit: true);
}
