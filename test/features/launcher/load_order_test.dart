import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/domain/entities/pwad.dart';
import 'package:quickdoom/features/launcher/presentation/providers/launch_provider.dart';

Pwad _p(String name) => Pwad(id: name, path: '/mods/$name.wad');

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    container.read(launchNotifierProvider.notifier).addPwads(
      [_p('a'), _p('b'), _p('c'), _p('d')],
    );
  });

  tearDown(() => container.dispose());

  List<String> order() =>
      container.read(launchNotifierProvider).pwads.map((p) => p.id).toList();

  List<int> loadOrders() => container
      .read(launchNotifierProvider)
      .pwads
      .map((p) => p.loadOrder)
      .toList();

  group('movePwad', () {
    // ReorderableListView.onReorderItem reports the destination in the list as
    // it will be after the move, so no off-by-one correction belongs here. The
    // old reorderPwad decremented newIndex itself, which double-corrected once
    // the call site switched.
    test('moving down lands at the reported destination', () {
      container.read(launchNotifierProvider.notifier).movePwad(0, 2);
      expect(order(), ['b', 'c', 'a', 'd']);
    });

    test('moving up lands at the reported destination', () {
      container.read(launchNotifierProvider.notifier).movePwad(3, 0);
      expect(order(), ['d', 'a', 'b', 'c']);
    });

    test('moving to the end works', () {
      container.read(launchNotifierProvider.notifier).movePwad(0, 3);
      expect(order(), ['b', 'c', 'd', 'a']);
    });

    test('load order is renumbered from the new positions', () {
      container.read(launchNotifierProvider.notifier).movePwad(3, 0);
      expect(loadOrders(), [0, 1, 2, 3]);
    });

    test('a no-op move changes nothing', () {
      container.read(launchNotifierProvider.notifier).movePwad(1, 1);
      expect(order(), ['a', 'b', 'c', 'd']);
    });

    test('an out-of-range source is ignored rather than throwing', () {
      container.read(launchNotifierProvider.notifier).movePwad(9, 0);
      expect(order(), ['a', 'b', 'c', 'd']);
    });
  });
}
