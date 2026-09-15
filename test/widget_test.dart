import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:quickdoom/app/app.dart';
import 'package:quickdoom/data/models/iwad_model.dart';
import 'package:quickdoom/data/models/launch_profile_model.dart';
import 'package:quickdoom/data/models/pwad_model.dart';
import 'package:quickdoom/data/models/source_port_model.dart';

final _tempDir = Directory('test/temp_${DateTime.now().millisecondsSinceEpoch}');

void main() {
  setUp(() async {
    _tempDir.createSync();
    Hive.init(_tempDir.path);
    Hive.registerAdapter(SourcePortModelAdapter());
    Hive.registerAdapter(IwadModelAdapter());
    Hive.registerAdapter(PwadModelAdapter());
    Hive.registerAdapter(LaunchProfileModelAdapter());
    await Hive.openBox('quickdoom');
  });

  tearDown(() async {
    await Hive.close();
    await _tempDir.delete(recursive: true);
  });

  testWidgets('QuickDoom app renders launcher screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: QuickDoomApp(),
      ),
    );
    // Two pumps: the first builds the shell, the second lands the saved-port
    // and IWAD reads so the slots show their real empty state rather than
    // "Reading saved ports…".
    await tester.pump();
    await tester.pump();

    // Shell chrome sets its own labels in the display cut, which is upper
    // case. LAUNCH appears twice by design: the nav slot and the plate the
    // whole screen is anchored on.
    expect(find.text('QUICKDOOM'), findsOneWidget);
    expect(find.text('LAUNCH'), findsNWidgets(2));
    expect(find.text('MAP VIEWER'), findsOneWidget);

    // The bench: two seated slots and the load order below them.
    expect(find.text('LOADOUT'), findsOneWidget);
    expect(find.text('ENGINE & GAME'), findsOneWidget);
    expect(find.text('SOURCE PORT'), findsOneWidget);
    expect(find.text('IWAD'), findsOneWidget);
    expect(find.text('LOAD ORDER'), findsOneWidget);

    // The saved-port and IWAD reads never settle under the test binding, so
    // the slots are still reporting the read rather than an empty socket.
    // LoadoutSlot's own states are covered in loadout_slot_test.dart.
    expect(find.text('Reading saved ports…'), findsOneWidget);
    expect(find.text('Reading saved IWADs…'), findsOneWidget);

    // Nothing is seated, so the plate explains itself rather than being an
    // unexplained dark rectangle.
    expect(
      find.text('Seat a source port and an IWAD to arm'),
      findsOneWidget,
    );
  });
}
