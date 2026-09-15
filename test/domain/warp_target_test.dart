import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/domain/entities/iwad.dart';
import 'package:quickdoom/domain/entities/launch_profile.dart';
import 'package:quickdoom/domain/entities/source_port.dart';
import 'package:quickdoom/domain/entities/warp_target.dart';
import 'package:quickdoom/domain/usecases/build_launch_command.dart';

void main() {
  group('WarpTarget.toArgs', () {
    // -warp is the portable spelling; +map is a ZDoom console command and
    // does nothing on vanilla, Boom, DSDA or Chocolate.
    test('MAPxx becomes a numeric -warp', () {
      expect(const WarpTarget(mapName: 'MAP14').toArgs(), ['-warp', '14']);
    });

    test('a leading zero is dropped, because -warp takes a number', () {
      expect(const WarpTarget(mapName: 'MAP01').toArgs(), ['-warp', '1']);
    });

    test('ExMy becomes the two-argument form', () {
      expect(const WarpTarget(mapName: 'E2M3').toArgs(), ['-warp', '2', '3']);
    });

    test('lower case is accepted', () {
      expect(const WarpTarget(mapName: 'map07').toArgs(), ['-warp', '7']);
    });

    // A PWAD is free to name its maps anything; -warp cannot address those
    // at all, so +map is the only option left.
    test('a custom lump name falls back to +map', () {
      expect(
        const WarpTarget(mapName: 'TITLEMAP').toArgs(),
        ['+map', 'TITLEMAP'],
      );
    });

    test('a custom name keeps its original case for the lump lookup', () {
      expect(const WarpTarget(mapName: 'HubEntry').toArgs().last, 'HubEntry');
    });
  });

  group('warping through buildArgs', () {
    const port = SourcePort(
      id: 'p',
      name: 'GZDoom',
      executablePath: '/opt/gzdoom',
    );
    const iwad = Iwad(id: 'i', name: 'doom2.wad', path: '/wads/doom2.wad');

    test('the warp lands after the wads', () {
      final args = BuildLaunchCommand().buildArgs(
        profile: LaunchProfile(
          id: '',
          name: 'x',
          sourcePortId: 'p',
          iwadId: 'i',
        ),
        port: port,
        iwad: iwad,
        warp: const WarpTarget(mapName: 'MAP14'),
      );

      expect(args, ['-iwad', '/wads/doom2.wad', '-warp', '14']);
    });

    test('custom args still get the last word', () {
      final args = BuildLaunchCommand().buildArgs(
        profile: LaunchProfile(
          id: '',
          name: 'x',
          sourcePortId: 'p',
          iwadId: 'i',
          customArgs: '-warp 20',
        ),
        port: port,
        iwad: iwad,
        warp: const WarpTarget(mapName: 'MAP14'),
      );

      expect(args.sublist(args.length - 2), ['-warp', '20']);
    });

    test('no warp leaves the command line untouched', () {
      final args = BuildLaunchCommand().buildArgs(
        profile: LaunchProfile(
          id: '',
          name: 'x',
          sourcePortId: 'p',
          iwadId: 'i',
        ),
        port: port,
        iwad: iwad,
      );

      expect(args, ['-iwad', '/wads/doom2.wad']);
    });
  });
}
