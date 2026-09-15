import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ProcessStreamResult {
  /// Output from the moment of subscription onward.
  final Stream<String> outputLogs;

  /// Everything written so far, oldest first.
  ///
  /// The stream is a broadcast, so a listener only hears what comes after it
  /// attaches — and a game writes its startup banner before anything has had a
  /// chance to subscribe. Consumers that need the whole session read this
  /// first and then follow [outputLogs]. It grows as the process writes.
  final List<String> history;

  final Future<int> exitCode;

  const ProcessStreamResult({
    required this.outputLogs,
    required this.exitCode,
    this.history = const [],
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

    // Broadcast from the start, so no subscriber can drain a buffer out from
    // under the others: whoever attached first used to receive everything the
    // process had already written, and everyone else got nothing.
    final logController = StreamController<String>.broadcast();
    final history = <String>[];

    void emit(String chunk) {
      history.add(chunk);
      if (!logController.isClosed) logController.add(chunk);
    }

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
          emit,
          onDone: pipeDone,
          onError: (Object error) => emit('[STDERR] $error'),
        );

    process.stderr.transform(utf8.decoder).listen(
          (data) => emit(markStderr(data)),
          onDone: pipeDone,
          onError: (Object error) => emit('[STDERR] $error'),
        );

    return ProcessStreamResult(
      outputLogs: logController.stream,
      history: history,
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
