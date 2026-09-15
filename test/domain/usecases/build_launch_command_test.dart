import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/domain/entities/iwad.dart';
import 'package:quickdoom/domain/entities/launch_profile.dart';
import 'package:quickdoom/domain/entities/pwad.dart';
import 'package:quickdoom/domain/entities/source_port.dart';
import 'package:quickdoom/domain/usecases/build_launch_command.dart';

void main() {
  late BuildLaunchCommand command;
  late SourcePort port;
  late Iwad iwad;

  setUp(() {
    command = BuildLaunchCommand();
    port = const SourcePort(
      id: 'port1',
      name: 'GZDoom',
      executablePath: 'C:\\Games\\gzdoom.exe',
    );
    iwad = const Iwad(
      id: 'iwad1',
      name: 'Doom 2',
      path: 'C:\\WADs\\doom2.wad',
    );
  });

  group('buildArgs', () {
    test('should return args with -iwad when no pwads or custom args', () {
      final profile = LaunchProfile(
        id: 'profile1',
        name: 'Test',
        sourcePortId: 'port1',
        iwadId: 'iwad1',
      );

      final args = command.buildArgs(profile: profile, port: port, iwad: iwad);

      expect(args, ['-iwad', 'C:\\WADs\\doom2.wad']);
    });

    test('should include port default args when present', () {
      final portWithDefaults = SourcePort(
        id: 'port1',
        name: 'GZDoom',
        executablePath: 'C:\\Games\\gzdoom.exe',
        defaultArgs: '-nogui',
      );
      final profile = LaunchProfile(
        id: 'profile1',
        name: 'Test',
        sourcePortId: 'port1',
        iwadId: 'iwad1',
      );

      final args = command.buildArgs(
        profile: profile,
        port: portWithDefaults,
        iwad: iwad,
      );

      expect(args, ['-nogui', '-iwad', 'C:\\WADs\\doom2.wad']);
    });

    test('should append -file with sorted enabled pwads', () {
      final pwads = [
        Pwad(id: 'p1', path: 'C:\\Mods\\brutalv21.pk3', isEnabled: true, loadOrder: 1),
        Pwad(id: 'p2', path: 'C:\\Mods\\map20.wad', isEnabled: true, loadOrder: 0),
      ];
      final profile = LaunchProfile(
        id: 'profile1',
        name: 'Test',
        sourcePortId: 'port1',
        iwadId: 'iwad1',
        pwadList: pwads,
      );

      final args = command.buildArgs(profile: profile, port: port, iwad: iwad);

      expect(args, [
        '-iwad', 'C:\\WADs\\doom2.wad',
        '-file',
        'C:\\Mods\\map20.wad',
        'C:\\Mods\\brutalv21.pk3',
      ]);
    });

    test('should exclude disabled pwads', () {
      final pwads = [
        Pwad(id: 'p1', path: 'C:\\Mods\\brutalv21.pk3', isEnabled: false, loadOrder: 1),
        Pwad(id: 'p2', path: 'C:\\Mods\\map20.wad', isEnabled: true, loadOrder: 0),
      ];
      final profile = LaunchProfile(
        id: 'profile1',
        name: 'Test',
        sourcePortId: 'port1',
        iwadId: 'iwad1',
        pwadList: pwads,
      );

      final args = command.buildArgs(profile: profile, port: port, iwad: iwad);

      expect(args, [
        '-iwad', 'C:\\WADs\\doom2.wad',
        '-file',
        'C:\\Mods\\map20.wad',
      ]);
    });

    test('should append custom args at the end', () {
      final profile = LaunchProfile(
        id: 'profile1',
        name: 'Test',
        sourcePortId: 'port1',
        iwadId: 'iwad1',
        customArgs: '+map map01 -skill 4',
      );

      final args = command.buildArgs(profile: profile, port: port, iwad: iwad);

      expect(args, [
        '-iwad', 'C:\\WADs\\doom2.wad',
        '+map',
        'map01',
        '-skill',
        '4',
      ]);
    });

    test('should handle empty pwad list', () {
      final profile = LaunchProfile(
        id: 'profile1',
        name: 'Test',
        sourcePortId: 'port1',
        iwadId: 'iwad1',
        pwadList: [],
      );

      final args = command.buildArgs(profile: profile, port: port, iwad: iwad);

      expect(args, ['-iwad', 'C:\\WADs\\doom2.wad']);
    });

    test('should handle empty custom args', () {
      final profile = LaunchProfile(
        id: 'profile1',
        name: 'Test',
        sourcePortId: 'port1',
        iwadId: 'iwad1',
        customArgs: '',
      );

      final args = command.buildArgs(profile: profile, port: port, iwad: iwad);

      expect(args, ['-iwad', 'C:\\WADs\\doom2.wad']);
    });
  });

  group('tokenize', () {
    test('splits on whitespace like it always did', () {
      expect(
        BuildLaunchCommand.tokenize('+map map01 -skill 4'),
        ['+map', 'map01', '-skill', '4'],
      );
    });

    // The bug: a Windows path with a space became five arguments and the
    // port silently could not find the file.
    test('keeps a quoted Windows path in one piece', () {
      expect(
        BuildLaunchCommand.tokenize(r'-file "C:\Program Files\Doom\x.wad"'),
        ['-file', r'C:\Program Files\Doom\x.wad'],
      );
    });

    test('a backslash stays literal, because it is a path separator', () {
      expect(
        BuildLaunchCommand.tokenize(r'C:\Games\new\test.wad'),
        [r'C:\Games\new\test.wad'],
      );
    });

    test('single quotes group too, for POSIX paths', () {
      expect(
        BuildLaunchCommand.tokenize("-file '/home/me/my mods/x.wad'"),
        ['-file', '/home/me/my mods/x.wad'],
      );
    });

    test('a quote can open mid-token', () {
      expect(
        BuildLaunchCommand.tokenize('-file="two words.wad"'),
        ['-file=two words.wad'],
      );
    });

    test('collapses runs of whitespace instead of emitting empty args', () {
      expect(
        BuildLaunchCommand.tokenize('  -fast \t\n -nomonsters  '),
        ['-fast', '-nomonsters'],
      );
    });

    test('an empty quoted pair is still an argument', () {
      expect(BuildLaunchCommand.tokenize('-name ""'), ['-name', '']);
    });

    test('an unterminated quote keeps the rest rather than dropping it', () {
      expect(
        BuildLaunchCommand.tokenize('-file "C:\\Doom\\x.wad'),
        ['-file', r'C:\Doom\x.wad'],
      );
    });

    test('an empty string yields no arguments', () {
      expect(BuildLaunchCommand.tokenize(''), isEmpty);
      expect(BuildLaunchCommand.tokenize('   '), isEmpty);
    });
  });

  group('quoting through buildArgs', () {
    test('a quoted custom arg survives into the command line', () {
      final profile = LaunchProfile(
        id: 'profile1',
        name: 'Test',
        sourcePortId: 'port1',
        iwadId: 'iwad1',
        customArgs: r'-config "C:\Program Files\Doom\my config.ini"',
      );

      final args = command.buildArgs(profile: profile, port: port, iwad: iwad);

      expect(args, [
        '-iwad', 'C:\\WADs\\doom2.wad',
        '-config',
        r'C:\Program Files\Doom\my config.ini',
      ]);
    });

    test('port default args are tokenized the same way', () {
      const spacedPort = SourcePort(
        id: 'port1',
        name: 'GZDoom',
        executablePath: r'C:\gzdoom\gzdoom.exe',
        defaultArgs: r'-savedir "C:\My Saves"',
      );

      final profile = LaunchProfile(
        id: 'profile1',
        name: 'Test',
        sourcePortId: 'port1',
        iwadId: 'iwad1',
      );

      final args = command.buildArgs(
        profile: profile,
        port: spacedPort,
        iwad: iwad,
      );

      expect(args.take(2), ['-savedir', r'C:\My Saves']);
    });
  });
}
