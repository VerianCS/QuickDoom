import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickdoom/features/launcher/presentation/widgets/loadout_slot.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: 460, child: child))),
    );

void main() {
  group('LoadoutSlot', () {
    testWidgets('an open socket says so instead of showing a blank plate',
        (tester) async {
      await tester.pumpWidget(_wrap(const LoadoutSlot(
        ordinal: 'I',
        label: 'Source Port',
        icon: Icons.memory,
        emptyHint: 'No engine seated',
      )));

      expect(find.text('No engine seated'), findsOneWidget);
      expect(find.text('SOURCE PORT'), findsOneWidget);
    });

    testWidgets('a seated slot shows the name over the path', (tester) async {
      await tester.pumpWidget(_wrap(const LoadoutSlot(
        ordinal: 'II',
        label: 'IWAD',
        icon: Icons.album_outlined,
        emptyHint: 'No game seated',
        value: 'freedoom2.wad',
        detail: '/usr/share/games/doom/freedoom2.wad',
      )));

      expect(find.text('freedoom2.wad'), findsOneWidget);
      expect(find.text('…/doom/freedoom2.wad'), findsOneWidget);
      expect(find.text('No game seated'), findsNothing);
    });

    testWidgets('the whole plate is the picker target', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(LoadoutSlot(
        ordinal: 'I',
        label: 'Source Port',
        icon: Icons.memory,
        emptyHint: 'No engine seated',
        onTap: () => taps++,
      )));

      await tester.tap(find.text('No engine seated'));
      expect(taps, 1);
    });

    testWidgets('actions sit outside the picker target', (tester) async {
      var taps = 0;
      var browsed = 0;
      await tester.pumpWidget(_wrap(LoadoutSlot(
        ordinal: 'I',
        label: 'Source Port',
        icon: Icons.memory,
        emptyHint: 'No engine seated',
        onTap: () => taps++,
        actions: [
          SlotAction(
            icon: Icons.folder_open,
            tooltip: 'Browse',
            onPressed: () => browsed++,
          ),
        ],
      )));

      await tester.tap(find.byIcon(Icons.folder_open));
      await tester.pump();

      expect(browsed, 1);
      expect(taps, 0, reason: 'browsing must not also open the picker');
    });
  });

  group('shortenPath', () {
    test('keeps the tail, which is the part that identifies a file', () {
      expect(
        LoadoutSlot.shortenPath('/usr/share/games/doom/freedoom2.wad'),
        '…/doom/freedoom2.wad',
      );
    });

    test('leaves a short path alone', () {
      expect(LoadoutSlot.shortenPath('doom/x.wad'), 'doom/x.wad');
      expect(LoadoutSlot.shortenPath('x.wad'), 'x.wad');
    });

    test('handles Windows separators', () {
      expect(
        LoadoutSlot.shortenPath(r'C:\Games\Doom\gzdoom.exe'),
        '…/Doom/gzdoom.exe',
      );
    });
  });
}
