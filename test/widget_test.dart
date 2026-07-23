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
    await tester.pump();

    expect(find.text('QuickDoom'), findsOneWidget);
    expect(find.text('Source Port'), findsOneWidget);
    expect(find.text('IWAD'), findsOneWidget);
    expect(find.text('PWADs / Mods'), findsOneWidget);
    expect(find.text('Launch'), findsNWidgets(2));
  });
}
