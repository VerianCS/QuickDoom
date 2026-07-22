import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ProcessStreamResult {
  final Stream<String> outputLogs;
  final Future<int> exitCode;

  const ProcessStreamResult({
    required this.outputLogs,
    required this.exitCode,
  });
}

class ProcessService {
  Future<ProcessStreamResult> startProcess(
    String executable,
    List<String> args, {
    String? workingDirectory,
  }) async {
    final process = await Process.start(
      executable,
      args,
      workingDirectory: workingDirectory,
      runInShell: true,
    );

    final logController = StreamController<String>();

    process.stdout
        .transform(utf8.decoder)
        .listen((data) => logController.add(data));

    process.stderr
        .transform(utf8.decoder)
        .listen((data) => logController.add('[STDERR] $data'));

    return ProcessStreamResult(
      outputLogs: logController.stream,
      exitCode: process.exitCode,
    );
  }

  Future<bool> isExecutable(String path) async {
    return File(path).exists();
  }
}
