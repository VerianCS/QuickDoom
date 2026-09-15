import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../data/repositories/iwad_repository_impl.dart';
import '../../../../core/services/hive_service.dart';
import '../../../../data/repositories/source_port_repository_impl.dart';
import '../../../../domain/entities/gameplay_options.dart';
import '../../../../domain/entities/iwad.dart';
import '../../../../domain/entities/launch_profile.dart';
import '../../../../domain/entities/pwad.dart';
import '../../../../domain/entities/source_port.dart';
import '../../../../domain/entities/warp_target.dart';
import '../../../../domain/usecases/build_launch_command.dart';
import '../../data/loadout_store.dart';
import '../../domain/launch_sequence.dart';
import 'launch_sequence_provider.dart';

part 'launch_provider.g.dart';

class LaunchState {
  final SourcePort? sourcePort;
  final Iwad? iwad;
  final List<Pwad> pwads;
  final String customArgs;
  final bool isLaunching;
  final String? error;
  final bool launchSuccess;

  /// The map to start on, set from the map viewer.
  final WarpTarget? warp;

  final GameplayOptions gameplay;

  const LaunchState({
    this.sourcePort,
    this.iwad,
    this.pwads = const [],
    this.customArgs = '',
    this.isLaunching = false,
    this.error,
    this.launchSuccess = false,
    this.warp,
    this.gameplay = const GameplayOptions(),
  });

  LaunchState copyWith({
    SourcePort? sourcePort,
    Iwad? iwad,
    List<Pwad>? pwads,
    String? customArgs,
    bool? isLaunching,
    String? error,
    bool? launchSuccess,
    WarpTarget? warp,
    GameplayOptions? gameplay,
    bool clearError = false,
    bool clearWarp = false,
    // Explicit flags, because `sourcePort ?? this.sourcePort` cannot tell
    // "leave it alone" from "clear it": clearSourcePort passed null and the
    // old port survived, so deleting a seated port left it on the bench.
    bool clearSourcePort = false,
    bool clearIwad = false,
  }) {
    return LaunchState(
      sourcePort: clearSourcePort ? null : sourcePort ?? this.sourcePort,
      iwad: clearIwad ? null : iwad ?? this.iwad,
      pwads: pwads ?? this.pwads,
      customArgs: customArgs ?? this.customArgs,
      isLaunching: isLaunching ?? this.isLaunching,
      error: clearError ? null : error ?? this.error,
      launchSuccess: launchSuccess ?? this.launchSuccess,
      warp: clearWarp ? null : warp ?? this.warp,
      gameplay: gameplay ?? this.gameplay,
    );
  }

  bool get canLaunch =>
      sourcePort != null &&
      iwad != null &&
      !isLaunching;
}

@riverpod
class LaunchNotifier extends _$LaunchNotifier {
  /// True while [restore] is writing the saved bench back in, so restoring
  /// does not immediately re-save what it just read.
  bool _restoring = false;

  /// Nothing is written until the saved bench has been read back.
  ///
  /// listenSelf fires once when the provider mounts, carrying the empty
  /// initial state — which promptly overwrote the saved loadout before
  /// restore() could read it, so every restart came back empty and the box
  /// looked like it had never been written.
  bool _restored = false;

  @override
  LaunchState build() {
    // Every mutator persists through one place rather than each remembering
    // to; forgetting one is how half a loadout comes back.
    listenSelf((_, next) {
      if (_restored && !_restoring) unawaited(_persist(next));
    });
    return const LaunchState();
  }

  /// Remembering the bench is a convenience, so a store that cannot be
  /// written — no Hive yet, a read-only profile directory — costs the user
  /// that convenience and nothing else. It must never take the launcher down.
  Future<void> _persist(LaunchState s) async {
    try {
      await ref.read(loadoutStoreProvider).save(
            SavedLoadout(
              sourcePortId: s.sourcePort?.id,
              iwadId: s.iwad?.id,
              pwads: s.pwads,
              customArgs: s.customArgs,
              gameplay: s.gameplay,
            ),
          );
    } catch (_) {
      // Nothing the user can act on, and nothing worth a crash.
    }
  }

  /// Puts the last bench back, as far as it still exists.
  ///
  /// The warp target is deliberately not saved at all: it is an intent for
  /// one launch, and silently starting on MAP14 days later because that is
  /// where you were last looking would be a surprise.
  Future<void> restore() async {
    // Set on every path out, including the failures: a bench that could not
    // be read is still a bench the user can now change and expect kept.
    try {
      await _restoreInner();
    } finally {
      _restored = true;
    }
  }

  Future<void> _restoreInner() async {
    final SavedLoadout saved;
    final SourcePort? port;
    final Iwad? iwad;

    // The whole read is guarded: a missing box, a box opened elsewhere with a
    // different type, a corrupt record. None of that is worth refusing to
    // start — the cost of failing here is an empty bench, and the cost of
    // throwing is a launcher that will not open.
    try {
      final read = await ref.read(loadoutStoreProvider).read();
      if (read == null) return;
      saved = read;

      port = saved.sourcePortId == null
          ? null
          : (await SourcePortRepositoryImpl(HiveService()).getPorts())
              .cast<SourcePort?>()
              .firstWhere(
                (p) => p!.id == saved.sourcePortId,
                orElse: () => null,
              );

      iwad = saved.iwadId == null
          ? null
          : (await IwadRepositoryImpl(HiveService()).getIwads())
              .cast<Iwad?>()
              .firstWhere(
                (i) => i!.id == saved.iwadId,
                orElse: () => null,
              );
    } catch (_) {
      return;
    }

    _restoring = true;
    state = state.copyWith(
      sourcePort: port,
      iwad: iwad,
      pwads: saved.pwads,
      customArgs: saved.customArgs,
      gameplay: saved.gameplay,
    );
    _restoring = false;
  }

  void setGameplay(GameplayOptions options) {
    state = state.copyWith(gameplay: options, clearError: true);
  }

  void setSourcePort(SourcePort port) {
    state = state.copyWith(sourcePort: port, clearError: true);
  }

  /// Starts the next launch on [target].
  ///
  /// The map's own file is seated in the load order too, because warping to a
  /// map the port has not been given is how you get a port that starts on the
  /// IWAD's map of that number instead — silently the wrong level.
  void setWarp(WarpTarget target) {
    final path = target.sourcePath;
    final alreadyLoaded = path == null ||
        path == state.iwad?.path ||
        state.pwads.any((p) => p.path == path);

    state = state.copyWith(
      warp: target,
      clearError: true,
      pwads: alreadyLoaded
          ? state.pwads
          : [
              ...state.pwads,
              Pwad(
                id: 'warp-${DateTime.now().microsecondsSinceEpoch}',
                path: path,
                loadOrder: state.pwads.length,
              ),
            ],
    );
  }

  void clearWarp() {
    state = state.copyWith(clearWarp: true);
  }

  void clearSourcePort() {
    state = state.copyWith(clearSourcePort: true);
  }

  void setIwad(Iwad iwad) {
    state = state.copyWith(iwad: iwad, clearError: true);
  }

  void clearIwad() {
    state = state.copyWith(clearIwad: true);
  }

  void addPwads(List<Pwad> newPwads) {
    final updated = List<Pwad>.from(state.pwads);
    for (final pwad in newPwads) {
      updated.add(pwad);
    }
    state = state.copyWith(pwads: updated);
  }

  void removePwad(String id) {
    state = state.copyWith(
      pwads: state.pwads.where((p) => p.id != id).toList(),
    );
  }

  /// Moves the mod at [from] to sit at [to] in the final order.
  ///
  /// [to] is the destination in the list as it will be *after* the move, which
  /// is what `ReorderableListView.onReorderItem` reports. Load order is then
  /// renumbered from the new positions, because Doom resolves duplicate lumps
  /// by load order and the index is the whole meaning of the row.
  void movePwad(int from, int to) {
    if (from == to) return;
    final pwads = List<Pwad>.from(state.pwads);
    if (from < 0 || from >= pwads.length) return;
    final item = pwads.removeAt(from);
    pwads.insert(to.clamp(0, pwads.length), item);
    state = state.copyWith(
      pwads: pwads
          .asMap()
          .entries
          .map((e) => e.value.copyWith(loadOrder: e.key))
          .toList(),
    );
  }

  void setCustomArgs(String args) {
    state = state.copyWith(customArgs: args);
  }

  void togglePwad(String id) {
    state = state.copyWith(
      pwads: state.pwads.map((p) {
        if (p.id == id) return p.copyWith(isEnabled: !p.isEnabled);
        return p;
      }).toList(),
    );
  }

  /// Runs the launch takeover and starts the game.
  ///
  /// [animate] is false when the platform asks for reduced motion or the user
  /// has turned the sequence off; the stages still run, they just take no
  /// time, so there is only one path through this code.
  Future<void> launch({bool animate = true}) async {
    if (!state.canLaunch) return;

    state = state.copyWith(
      isLaunching: true,
      clearError: true,
      launchSuccess: false,
    );

    try {
      final profile = LaunchProfile(
        id: '',
        name: 'Quick Launch',
        sourcePortId: state.sourcePort!.id,
        iwadId: state.iwad!.id,
        pwadList: state.pwads,
        customArgs: state.customArgs,
      );

      final args = BuildLaunchCommand().buildArgs(
        profile: profile,
        port: state.sourcePort!,
        iwad: state.iwad!,
        warp: state.warp,
        gameplay: state.gameplay,
      );

      final outcome = await ref.read(launchSequenceProvider.notifier).run(
            executable: state.sourcePort!.executablePath,
            args: args,
            portName: state.sourcePort!.name,
            iwadName: state.iwad!.name,
            modCount: state.pwads.where((p) => p.isEnabled).length,
            timings: animate && ref.read(launchAnimationEnabledProvider)
                ? LaunchTimings.standard
                : LaunchTimings.instant,
          );

      state = state.copyWith(
        isLaunching: false,
        launchSuccess: outcome.started,
        error: outcome.started
            ? null
            : 'Launch failed: ${readableLaunchError(outcome.error)}',
      );
    } catch (e) {
      state = state.copyWith(
        isLaunching: false,
        error: 'Launch failed: ${readableLaunchError(e)}',
      );
    }
  }

  void loadFromProfile({
    required LaunchProfile profile,
    SourcePort? port,
    Iwad? iwad,
  }) {
    state = LaunchState(
      sourcePort: port,
      iwad: iwad,
      pwads: profile.pwadList,
      customArgs: profile.customArgs,
    );
  }

  void clearAll() {
    state = const LaunchState();
  }
}

/// Strips Dart's `Exception: ` prefix so a message written for the user is
/// shown as written. The error plate said "Launch failed: Exception: Source
/// port is not executable", which reads like a crash rather than advice.
@visibleForTesting
String readableLaunchError(Object? error) {
  final text = error?.toString() ?? 'Unknown error';
  const prefix = 'Exception: ';
  return text.startsWith(prefix) ? text.substring(prefix.length) : text;
}
