import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'features/launcher/data/loadout_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      // Persistence is opt-in; this is where the app opts in.
      overrides: [
        loadoutStoreProvider.overrideWithValue(const HiveLoadoutStore()),
      ],
      child: const QuickDoomApp(),
    ),
  );
}
