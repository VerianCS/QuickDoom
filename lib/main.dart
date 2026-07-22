import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'data/models/iwad_model.dart';
import 'data/models/launch_profile_model.dart';
import 'data/models/pwad_model.dart';
import 'data/models/source_port_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(SourcePortModelAdapter());
  Hive.registerAdapter(IwadModelAdapter());
  Hive.registerAdapter(PwadModelAdapter());
  Hive.registerAdapter(LaunchProfileModelAdapter());

  await Hive.openBox('quickdoom');

  runApp(
    const ProviderScope(
      child: QuickDoomApp(),
    ),
  );
}
