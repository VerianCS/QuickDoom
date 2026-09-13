import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../domain/entities/iwad.dart';
import '../../../../domain/entities/launch_profile.dart';
import '../../../../domain/entities/pwad.dart';
import '../../../../domain/entities/source_port.dart';
import '../../../iwads/presentation/providers/iwad_provider.dart';
import '../../../launcher/presentation/providers/launch_provider.dart';
import '../../../library/presentation/providers/mod_library_provider.dart';
import '../../../source_ports/presentation/providers/source_port_provider.dart';
import '../../domain/entities/mod_pack.dart';

/// Outcome of pushing a pack into the launcher, so the UI can report what
/// actually made it across.
class ModPackLoadResult {
  final int fileCount;

  /// Entries whose mod is no longer in the library.
  final int missingMods;

  final bool engineResolved;
  final bool iwadResolved;

  const ModPackLoadResult({
    required this.fileCount,
    required this.missingMods,
    required this.engineResolved,
    required this.iwadResolved,
  });

  /// Human-readable note about anything that did not resolve, or null when the
  /// pack loaded cleanly.
  String? get warning {
    final problems = <String>[];
    if (missingMods > 0) {
      problems.add('$missingMods mod${missingMods == 1 ? '' : 's'} missing '
          'from the library');
    }
    if (!engineResolved) problems.add('no engine set');
    if (!iwadResolved) problems.add('no IWAD set');
    return problems.isEmpty ? null : problems.join(', ');
  }
}

final modPackLauncherProvider = Provider<ModPackLauncher>((ref) {
  return ModPackLauncher(ref);
});

/// Resolves a pack against the library and loads it into the launcher.
class ModPackLauncher {
  final Ref _ref;

  ModPackLauncher(this._ref);

  Future<ModPackLoadResult> loadIntoLauncher(ModPack pack) async {
    final mods = await _ref.read(modLibraryProvider.future);
    final byId = {for (final m in mods) m.id: m};

    final pwads = <Pwad>[];
    var missing = 0;

    for (final entry in pack.entries) {
      final mod = byId[entry.modId];
      if (mod == null) {
        missing++;
        continue;
      }
      for (final file in mod.files) {
        pwads.add(Pwad(
          id: const Uuid().v4(),
          path: file,
          isEnabled: entry.isEnabled,
          loadOrder: pwads.length,
        ));
      }
    }

    final port = await _findPort(pack.engineId);
    final iwad = await _findIwad(pack.iwadId);

    _ref.read(launchNotifierProvider.notifier).loadFromProfile(
          profile: LaunchProfile(
            id: pack.id,
            name: pack.name,
            sourcePortId: pack.engineId ?? '',
            iwadId: pack.iwadId ?? '',
            pwadList: pwads,
          ),
          port: port,
          iwad: iwad,
        );

    return ModPackLoadResult(
      fileCount: pwads.length,
      missingMods: missing,
      engineResolved: port != null,
      iwadResolved: iwad != null,
    );
  }

  Future<SourcePort?> _findPort(String? id) async {
    if (id == null || id.isEmpty) return null;
    final ports = await _ref.read(sourcePortListProvider.future);
    for (final port in ports) {
      if (port.id == id) return port;
    }
    return null;
  }

  Future<Iwad?> _findIwad(String? id) async {
    if (id == null || id.isEmpty) return null;
    final iwads = await _ref.read(iwadListProvider.future);
    for (final iwad in iwads) {
      if (iwad.id == id) return iwad;
    }
    return null;
  }
}
