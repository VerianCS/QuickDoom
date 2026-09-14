import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/core/services/process_service.dart';

void main() {
  group('markStderr', () {
    test('marks every line of a multi-line chunk', () {
      expect(
        ProcessService.markStderr('Error: one\nFatal: two\n'),
        '[STDERR] Error: one\n[STDERR] Fatal: two\n',
      );
    });

    test('marks a single line', () {
      expect(ProcessService.markStderr('boom\n'), '[STDERR] boom\n');
    });

    test('leaves an empty chunk alone', () {
      expect(ProcessService.markStderr(''), '');
      expect(ProcessService.markStderr('\n'), '\n');
    });
  });

  group('startProcess', () {
    test('streams output and closes once the pipes drain', () async {
      final result = await ProcessService().startProcess(
        '/bin/sh',
        ['-c', 'echo out; echo bad 1>&2; echo worse 1>&2; exit 3'],
      );

      final lines = <String>[];
      final done = result.outputLogs.listen(lines.add).asFuture<void>();

      expect(await result.exitCode, 3);
      // Completing at all is the point: the stream used to stay open forever,
      // so nothing could tell that the output was finished.
      await done.timeout(const Duration(seconds: 5));

      final text = lines.join();
      expect(text, contains('out'));
      expect(text, contains('[STDERR] bad'));
      expect(
        text,
        contains('[STDERR] worse'),
        reason: 'the second stderr line must be marked too',
      );
    });
  }, skip: Platform.isWindows ? 'POSIX shell only' : null);
}
