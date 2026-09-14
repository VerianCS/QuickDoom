// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'launch_sequence_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$launchAnimationEnabledHash() =>
    r'cb4100e3607eab27708fb6f45f486430f54a468b';

/// Whether the launch takeover plays, persisted across runs.
///
/// Someone testing a mod launches dozens of times an hour; making them sit
/// through the sequence every time would be the fastest way to have them
/// resent it.
///
/// Copied from [LaunchAnimationEnabled].
@ProviderFor(LaunchAnimationEnabled)
final launchAnimationEnabledProvider =
    NotifierProvider<LaunchAnimationEnabled, bool>.internal(
  LaunchAnimationEnabled.new,
  name: r'launchAnimationEnabledProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$launchAnimationEnabledHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$LaunchAnimationEnabled = Notifier<bool>;
String _$launchSequenceHash() => r'dd91f389fe37753d5c8f28b817c522aacde4ba7c';

/// Drives the launch takeover.
///
/// Kept alive: the sequence outlives the launcher screen, since the window is
/// hidden for the whole session and the readout has to survive until the game
/// exits and the user dismisses it.
///
/// Copied from [LaunchSequence].
@ProviderFor(LaunchSequence)
final launchSequenceProvider =
    NotifierProvider<LaunchSequence, LaunchSequenceState>.internal(
  LaunchSequence.new,
  name: r'launchSequenceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$launchSequenceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$LaunchSequence = Notifier<LaunchSequenceState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
