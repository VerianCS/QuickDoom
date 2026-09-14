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

    // The controller closes once both pipes are done, which gives listeners a
    // way to know the output is complete. Without it the stream stayed open
    // for the life of the app, and a reader that wanted the tail of stderr had
    // no way to tell "nothing more is coming" from "nothing yet" — exitCode
    // can resolve before the pipes have drained.
    var openPipes = 2;
    void pipeDone() {
      if (--openPipes == 0) logController.close();
    }

    process.stdout.transform(utf8.decoder).listen(
          logController.add,
          onDone: pipeDone,
          onError: (Object error) => logController.add('[STDERR] $error'),
        );

    process.stderr.transform(utf8.decoder).listen(
          (data) => logController.add(markStderr(data)),
          onDone: pipeDone,
          onError: (Object error) => logController.add('[STDERR] $error'),
        );

    return ProcessStreamResult(
      outputLogs: logController.stream.asBroadcastStream(),
      exitCode: process.exitCode,
    );
  }

  Future<bool> isExecutable(String path) async {
    return File(path).exists();
  }

  /// Marks every line of a stderr chunk, not just the first.
  ///
  /// A port that fails on startup writes several lines in one write, and
  /// readers tell stderr from stdout by the marker — tagging only the chunk
  /// left every line after the first looking like ordinary output.
  static String markStderr(String chunk) {
    final marked = <String>[];
    for (final line in chunk.split('\n')) {
      if (line.isEmpty) continue;
      marked.add('[STDERR] $line');
    }
    if (marked.isEmpty) return chunk;
    return '${marked.join('\n')}\n';
  }
}
