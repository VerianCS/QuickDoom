import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_tray/system_tray.dart';

final systemTrayProvider = StateProvider<SystemTray?>((ref) => null);
