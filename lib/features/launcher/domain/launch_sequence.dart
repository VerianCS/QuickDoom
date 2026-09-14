import 'dart:ui';

/// Where the launch is in its takeover animation.
///
/// The stages run in order on a successful launch. [fault] is entered from
/// anywhere the spawn fails, and [idle] is the resting state.
enum LaunchStage {
  idle,

  /// The button depresses and the shell dims.
  arm,

  /// The charge winds up. The process is spawned during this stage.
  charge,

  /// Flash and shockwave.
  ignite,

  /// The shell collapses like a CRT powering down, then the window hides.
  handoff,

  /// The window is hidden and the game is running.
  running,

  /// The window is back and powering on again.
  returning,

  /// The session readout is up.
  summary,

  /// The spawn failed; the window was never hidden.
  fault,
}

/// Stage durations, injectable so tests can run the whole sequence instantly
/// and so reduced-motion callers can collapse it without a second code path.
class LaunchTimings {
  final Duration arm;
  final Duration charge;
  final Duration ignite;
  final Duration handoff;
  final Duration powerOn;

  /// How far into [charge] the process is spawned.
  ///
  /// Deliberately small: the animation exists to cover the second or so a
  /// source port takes to put a window on screen, not to add to it.
  final Duration spawnDelay;

  /// How long to wait after the game exits for its output pipes to drain.
  ///
  /// A port that dies on startup writes its reason and exits in the same
  /// breath, and exitCode can resolve first. Bounded, so a port that leaves a
  /// pipe open cannot hold the window hidden.
  final Duration tailGrace;

  const LaunchTimings({
    required this.arm,
    required this.charge,
    required this.ignite,
    required this.handoff,
    required this.powerOn,
    required this.spawnDelay,
    this.tailGrace = Duration.zero,
  });

  static const LaunchTimings standard = LaunchTimings(
    arm: Duration(milliseconds: 120),
    charge: Duration(milliseconds: 500),
    ignite: Duration(milliseconds: 280),
    handoff: Duration(milliseconds: 450),
    powerOn: Duration(milliseconds: 320),
    spawnDelay: Duration(milliseconds: 30),
    tailGrace: Duration(milliseconds: 400),
  );

  /// Every stage collapsed: used for reduced motion, for the user's own
  /// "skip the animation" setting, and in tests.
  static const LaunchTimings instant = LaunchTimings(
    arm: Duration.zero,
    charge: Duration.zero,
    ignite: Duration.zero,
    handoff: Duration.zero,
    powerOn: Duration.zero,
    spawnDelay: Duration.zero,
  );

  Duration forStage(LaunchStage stage) => switch (stage) {
        LaunchStage.arm => arm,
        LaunchStage.charge => charge,
        LaunchStage.ignite => ignite,
        LaunchStage.handoff => handoff,
        LaunchStage.returning => powerOn,
        _ => Duration.zero,
      };
}

/// What the session readout shows once the game exits.
class LaunchSummary {
  final String portName;
  final String iwadName;
  final int modCount;
  final Duration playTime;
  final int exitCode;

  /// The last few stderr lines, shown only when the exit code is non-zero.
  final List<String> errorLines;

  const LaunchSummary({
    required this.portName,
    required this.iwadName,
    required this.modCount,
    required this.playTime,
    required this.exitCode,
    this.errorLines = const [],
  });

  bool get ok => exitCode == 0;

  String get playTimeLabel {
    final total = playTime.inSeconds;
    if (total < 60) return '${total}s';
    final hours = playTime.inHours;
    final minutes = playTime.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m ${total.remainder(60)}s';
  }
}

/// Current state of the takeover.
class LaunchSequenceState {
  final LaunchStage stage;

  /// Screen position of the launch control, so the charge and shockwave
  /// originate from the thing the user pressed. Null falls back to centre.
  final Offset? focal;

  final LaunchSummary? summary;
  final String? error;

  const LaunchSequenceState({
    this.stage = LaunchStage.idle,
    this.focal,
    this.summary,
    this.error,
  });

  /// True while the overlay should be painting over the shell.
  bool get isTakingOver =>
      stage != LaunchStage.idle && stage != LaunchStage.summary;

  bool get isArmed =>
      stage == LaunchStage.arm ||
      stage == LaunchStage.charge ||
      stage == LaunchStage.ignite;

  LaunchSequenceState copyWith({
    LaunchStage? stage,
    Offset? focal,
    LaunchSummary? summary,
    String? error,
    bool clearSummary = false,
    bool clearError = false,
  }) {
    return LaunchSequenceState(
      stage: stage ?? this.stage,
      focal: focal ?? this.focal,
      summary: clearSummary ? null : summary ?? this.summary,
      error: clearError ? null : error ?? this.error,
    );
  }
}
