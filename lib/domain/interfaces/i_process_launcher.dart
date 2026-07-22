import '../../core/services/process_service.dart';

abstract class IProcessLauncher {
  Future<ProcessStreamResult> launch(String executable, List<String> args);
  Future<bool> canLaunch(String executable);
}
