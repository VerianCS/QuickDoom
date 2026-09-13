// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mod_library_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$modLibraryHash() => r'c09d571cd91a387a669930040427cde0ffb85d9b';

/// Every mod QuickDoom has unpacked, newest first.
///
/// Copied from [ModLibrary].
@ProviderFor(ModLibrary)
final modLibraryProvider =
    AutoDisposeAsyncNotifierProvider<ModLibrary, List<InstalledMod>>.internal(
  ModLibrary.new,
  name: r'modLibraryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$modLibraryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ModLibrary = AutoDisposeAsyncNotifier<List<InstalledMod>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
