import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/services/process_service.dart';
import '../../../../data/repositories/process_launcher_impl.dart';
import '../../../../domain/entities/iwad.dart';
import '../../../../domain/entities/launch_profile.dart';
import '../../../../domain/entities/pwad.dart';
import '../../../../domain/entities/source_port.dart';
import '../../../../domain/interfaces/i_process_launcher.dart';
import '../../../../domain/usecases/build_launch_command.dart';
import 'process_provider.dart';

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

  void reorderPwad(int oldIndex, int newIndex) {
    final pwads = List<Pwad>.from(state.pwads);
    if (newIndex > oldIndex) newIndex--;
    final item = pwads.removeAt(oldIndex);
    pwads.insert(newIndex, item);
    final reindexed = pwads.asMap().entries.map((e) =>
      e.value.copyWith(loadOrder: e.key)
    ).toList();
    state = state.copyWith(pwads: reindexed);
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

  Future<void> launch() async {
    if (!state.canLaunch) return;

    state = state.copyWith(isLaunching: true, clearError: true, launchSuccess: false);

    try {
      final commandBuilder = BuildLaunchCommand();
      final launcher = _createLauncher();

      final profile = LaunchProfile(
        id: '',
        name: 'Quick Launch',
        sourcePortId: state.sourcePort!.id,
        iwadId: state.iwad!.id,
        pwadList: state.pwads,
        customArgs: state.customArgs,
      );

      final args = commandBuilder.buildArgs(
        profile: profile,
        port: state.sourcePort!,
        iwad: state.iwad!,
      );

      final result = await launcher.launch(state.sourcePort!.executablePath, args);

      final runningProcess = RunningProcess(
        result: result,
        executable: state.sourcePort!.executablePath,
        args: args,
      );
      ref.read(processManagerProvider.notifier).track(runningProcess);

      await windowManager.hide();

      result.exitCode.then((code) async {
        ref.read(processManagerProvider.notifier).clear();
        await windowManager.show();
        await windowManager.focus();
      });

      state = state.copyWith(isLaunching: false, launchSuccess: true);
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

  IProcessLauncher _createLauncher() {
    return ProcessLauncherImpl(ProcessService());
  }
}
