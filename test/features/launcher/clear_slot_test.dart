import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/domain/entities/gameplay_options.dart';
import 'package:quickdoom/domain/entities/iwad.dart';
import 'package:quickdoom/domain/entities/source_port.dart';
import 'package:quickdoom/features/launcher/presentation/providers/launch_provider.dart';

const _port = SourcePort(id: 'p', name: 'gzdoom', executablePath: '/opt/gz');
const _iwad = Iwad(id: 'i', name: 'doom2.wad', path: '/wads/doom2.wad');

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

  // copyWith used `sourcePort ?? this.sourcePort`, which cannot tell "leave
  // it alone" from "clear it", so clearSourcePort passed null and the old
  // port survived: deleting a seated port left it sitting on the bench.
  test('clearSourcePort actually empties the slot', () {
    notifier().setSourcePort(_port);
    expect(state().sourcePort, isNotNull);

    notifier().clearSourcePort();
    expect(state().sourcePort, isNull);
  });

  test('clearIwad actually empties the slot', () {
    notifier().setIwad(_iwad);
    notifier().clearIwad();
    expect(state().iwad, isNull);
  });

  test('clearing one slot leaves the other seated', () {
    notifier().setSourcePort(_port);
    notifier().setIwad(_iwad);

    notifier().clearSourcePort();

    expect(state().sourcePort, isNull);
    expect(state().iwad, isNotNull);
    expect(state().canLaunch, isFalse);
  });

  test('gameplay options survive an unrelated change', () {
    notifier().setGameplay(const GameplayOptions(skill: Skill.ultraViolence));
    notifier().setIwad(_iwad);

    expect(state().gameplay.skill, Skill.ultraViolence);
  });
}
