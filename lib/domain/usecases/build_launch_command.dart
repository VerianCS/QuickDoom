import 'package:path/path.dart' as p;

import '../entities/iwad.dart';
import '../entities/launch_profile.dart';
import '../entities/source_port.dart';

class BuildLaunchCommand {
  List<String> buildArgs({
    required LaunchProfile profile,
    required SourcePort port,
    required Iwad iwad,
  }) {
    final args = <String>[];

    if (port.defaultArgs.isNotEmpty) {
      args.addAll(port.defaultArgs.split(' ').where((s) => s.isNotEmpty));
    }

    args.addAll(['-iwad', iwad.path]);

    final sortedPwads = profile.pwadList
        .where((p) => p.isEnabled)
        .toList()
      ..sort((a, b) => a.loadOrder.compareTo(b.loadOrder));

    if (sortedPwads.isNotEmpty) {
      args.add('-file');
      args.addAll(sortedPwads.map((p) => p.path));
    }

    if (profile.customArgs.isNotEmpty) {
      args.addAll(profile.customArgs.split(' ').where((s) => s.isNotEmpty));
    }

    return args;
  }

  bool validateExecutable(String path) {
    if (path.trim().isEmpty) return false;
    final ext = p.extension(path).toLowerCase();
    return ext == '.exe' || ext == '' || ext == '.AppImage';
  }
}
