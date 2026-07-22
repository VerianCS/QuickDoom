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

  group('validateExecutable', () {
    test('should return true for .exe files', () {
      expect(command.validateExecutable('gzdoom.exe'), true);
    });

    test('should return false for empty string', () {
      expect(command.validateExecutable(''), false);
    });
  });
}
