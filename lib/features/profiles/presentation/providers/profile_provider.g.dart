// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$profileListHash() => r'200e1d5d6a280ee391f5479e78ddc31fae8b0d13';

/// See also [ProfileList].
@ProviderFor(ProfileList)
final profileListProvider =
    AutoDisposeAsyncNotifierProvider<ProfileList, List<LaunchProfile>>.internal(
  ProfileList.new,
  name: r'profileListProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$profileListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ProfileList = AutoDisposeAsyncNotifier<List<LaunchProfile>>;
String _$currentProfileIdHash() => r'ca9bd50540fd1e8f3026958b51f27efe21f22a57';

/// See also [CurrentProfileId].
@ProviderFor(CurrentProfileId)
final currentProfileIdProvider =
    AutoDisposeNotifierProvider<CurrentProfileId, String?>.internal(
  CurrentProfileId.new,
  name: r'currentProfileIdProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentProfileIdHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CurrentProfileId = AutoDisposeNotifier<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
