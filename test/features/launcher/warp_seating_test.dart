import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/domain/entities/iwad.dart';
import 'package:quickdoom/domain/entities/pwad.dart';
import 'package:quickdoom/domain/entities/warp_target.dart';
import 'package:quickdoom/features/launcher/presentation/providers/launch_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    container.listen(launchNotifierProvider, (_, _) {}, fireImmediately: true);
  });
  tearDown(() => container.dispose());

  LaunchNotifier notifier() =>
      container.read(launchNotifierProvider.notifier);
  LaunchState state() => container.read(launchNotifierProvider);

  group('setWarp', () {
    // Warping to a map the port was never given is how you silently land on
    // the IWAD's map of that number instead of the one you were looking at.
    test('seats the map file in the load order', () {
      notifier().setWarp(
        const WarpTarget(mapName: 'MAP14', sourcePath: '/mods/sunlust.wad'),
      );

      expect(state().warp?.mapName, 'MAP14');
      expect(state().pwads.map((p) => p.path), ['/mods/sunlust.wad']);
    });

    test('does not seat a file that is already loaded', () {
      notifier().addPwads([Pwad(id: 'a', path: '/mods/sunlust.wad')]);
      notifier().setWarp(
        const WarpTarget(mapName: 'MAP14', sourcePath: '/mods/sunlust.wad'),
      );

      expect(state().pwads.length, 1);
    });

    test('does not seat the IWAD as a mod', () {
      notifier().setIwad(
        const Iwad(id: 'i', name: 'doom2.wad', path: '/wads/doom2.wad'),
      );
      notifier().setWarp(
        const WarpTarget(mapName: 'MAP14', sourcePath: '/wads/doom2.wad'),
      );

      expect(state().pwads, isEmpty);
    });

    test('a map with no file of its own seats nothing', () {
      notifier().setWarp(const WarpTarget(mapName: 'E1M1'));
      expect(state().pwads, isEmpty);
      expect(state().warp?.mapName, 'E1M1');
    });

    test('the new file goes last, so its maps win', () {
      notifier().addPwads([Pwad(id: 'a', path: '/mods/tex.wad')]);
      notifier().setWarp(
        const WarpTarget(mapName: 'MAP14', sourcePath: '/mods/sunlust.wad'),
      );

      expect(state().pwads.last.path, '/mods/sunlust.wad');
      expect(state().pwads.last.loadOrder, 1);
    });

    test('clearWarp leaves the file loaded but starts from the beginning', () {
      notifier().setWarp(
        const WarpTarget(mapName: 'MAP14', sourcePath: '/mods/sunlust.wad'),
      );
      notifier().clearWarp();

      expect(state().warp, isNull);
      expect(state().pwads.length, 1);
    });
  });
}
