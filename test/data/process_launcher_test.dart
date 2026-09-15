import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/core/services/file_picker_service.dart';
import 'package:quickdoom/core/services/process_service.dart';
import 'package:quickdoom/data/repositories/process_launcher_impl.dart';
import 'package:quickdoom/features/launcher/presentation/providers/launch_provider.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('qd_launcher'));
  tearDown(() => dir.deleteSync(recursive: true));

  File writeFile(String name, {int? mode}) {
    final f = File('${dir.path}/$name')..writeAsStringSync('#!/bin/sh\n');
    if (mode != null) Process.runSync('chmod', [mode.toString(), f.path]);
    return f;
  }

  group('describeProblem', () {
    test('accepts an extensionless executable, as on Linux', () async {
      final f = writeFile('gzdoom', mode: 755);
      expect(await ProcessLauncherImpl.describeProblem(f.path), isNull);
    });

    test('names a port that has been moved or deleted', () async {
      final problem = await ProcessLauncherImpl.describeProblem(
        '${dir.path}/gone',
      );
      expect(problem, contains('not found'));
      expect(problem, contains('${dir.path}/gone'));
    });

    test('rejects a folder', () async {
      final sub = Directory('${dir.path}/bundle')..createSync();
      expect(
        await ProcessLauncherImpl.describeProblem(sub.path),
        contains('folder'),
      );
    });

    test('rejects an empty path', () async {
      expect(await ProcessLauncherImpl.describeProblem('  '), isNotNull);
    });

    test('a file without the executable bit says how to fix it', () async {
      final f = writeFile('gzdoom', mode: 644);
      final problem = await ProcessLauncherImpl.describeProblem(f.path);

      if (Platform.isWindows) {
        expect(problem, isNull, reason: 'Windows has no executable bit');
      } else {
        expect(problem, contains('not executable'));
        expect(problem, contains('chmod +x'));
      }
    }, skip: Platform.isWindows ? 'no permission bits on Windows' : null);

    test('canLaunch agrees with describeProblem', () async {
      final launcher = ProcessLauncherImpl(_NullProcessService());
      final good = writeFile('ok', mode: 755);

      expect(await launcher.canLaunch(good.path), isTrue);
      expect(await launcher.canLaunch('${dir.path}/nope'), isFalse);
    });
  });

  group('readableLaunchError', () {
    // describeProblem writes a sentence for the user; wrapping it in an
    // Exception and printing that put "Exception: " in front of it on the
    // error plate, which reads like a crash rather than like advice.
    test("drops Dart's Exception prefix", () {
      expect(
        readableLaunchError(Exception('Source port is not executable: /x')),
        'Source port is not executable: /x',
      );
    });

    test('leaves a plain message alone', () {
      expect(readableLaunchError('Port closed the pipe'),
          'Port closed the pipe');
    });

    test('survives a null', () {
      expect(readableLaunchError(null), isNotEmpty);
    });
  });

  group('executable picker filter', () {
    // The old filter was ['exe', 'AppImage', ''], and a file dialog matches on
    // suffix, so the empty entry matched nothing and Linux binaries — which
    // have no suffix at all — could not be selected.
    test('does not filter off Windows, so extensionless binaries show', () {
      expect(FilePickerService.executableExtensions(false), isNull);
    });

    test('filters on Windows, where the extension is what marks a program',
        () {
      expect(FilePickerService.executableExtensions(true), contains('exe'));
    });
  });
}

/// canLaunch never reaches the process service, so it never needs to work.
class _NullProcessService implements ProcessService {
  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
