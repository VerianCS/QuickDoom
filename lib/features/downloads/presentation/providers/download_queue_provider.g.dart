// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_queue_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$downloadQueueHash() => r'df2c6ecb83a451b9b5cdd68cf8f0ca71abbaae36';

/// Tracks every download in flight, keyed by target.
///
/// Mods land in the library; engines are registered as source ports so they
/// show up in the launcher dropdown without another trip through a file picker.
///
/// Kept alive deliberately: an auto-disposed queue would drop its tasks — and
/// orphan the transfers feeding them — as soon as the last row stopped
/// watching, so switching tabs mid-download would lose the download.
///
/// Copied from [DownloadQueue].
@ProviderFor(DownloadQueue)
final downloadQueueProvider =
    NotifierProvider<DownloadQueue, Map<String, DownloadTask>>.internal(
  DownloadQueue.new,
  name: r'downloadQueueProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$downloadQueueHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DownloadQueue = Notifier<Map<String, DownloadTask>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
