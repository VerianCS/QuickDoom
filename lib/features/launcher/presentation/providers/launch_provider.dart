import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../domain/entities/iwad.dart';
import '../../../../domain/entities/launch_profile.dart';
import '../../../../domain/entities/pwad.dart';
import '../../../../domain/entities/source_port.dart';
import '../../../../domain/usecases/build_launch_command.dart';
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

  const LaunchState({
    this.sourcePort,
    this.iwad,
    this.pwads = const [],
    this.customArgs = '',
    this.isLaunching = false,
    this.error,
    this.launchSuccess = false,
  });

  LaunchState copyWith({
    SourcePort? sourcePort,
    Iwad? iwad,
    List<Pwad>? pwads,
    String? customArgs,
    bool? isLaunching,
    String? error,
    bool? launchSuccess,
    bool clearError = false,
  }) {
    return LaunchState(
      sourcePort: sourcePort ?? this.sourcePort,
      iwad: iwad ?? this.iwad,
      pwads: pwads ?? this.pwads,
      customArgs: customArgs ?? this.customArgs,
      isLaunching: isLaunching ?? this.isLaunching,
      error: clearError ? null : error ?? this.error,
      launchSuccess: launchSuccess ?? this.launchSuccess,
    );
  }

  bool get canLaunch =>
      sourcePort != null &&
      iwad != null &&
      !isLaunching;
}

@riverpod
class LaunchNotifier extends _$LaunchNotifier {
  @override
  LaunchState build() => const LaunchState();

  void setSourcePort(SourcePort port) {
    state = state.copyWith(sourcePort: port, clearError: true);
  }

  void clearSourcePort() {
    state = state.copyWith(sourcePort: null);
  }

  void setIwad(Iwad iwad) {
    state = state.copyWith(iwad: iwad, clearError: true);
  }

  void clearIwad() {
    state = state.copyWith(iwad: null);
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
        error: outcome.started ? null : 'Launch failed: ${outcome.error}',
      );
    } catch (e) {
      state = state.copyWith(
        isLaunching: false,
        error: 'Launch failed: $e',
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
