// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'path_problem_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$portProblemHash() => r'cb6b7586bab2d6e5e329ec9e1ad1f9df1f587131';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Whether the executable at [path] can still be run.
///
/// Copied from [portProblem].
@ProviderFor(portProblem)
const portProblemProvider = PortProblemFamily();

/// Whether the executable at [path] can still be run.
///
/// Copied from [portProblem].
class PortProblemFamily extends Family<AsyncValue<String?>> {
  /// Whether the executable at [path] can still be run.
  ///
  /// Copied from [portProblem].
  const PortProblemFamily();

  /// Whether the executable at [path] can still be run.
  ///
  /// Copied from [portProblem].
  PortProblemProvider call(
    String path,
  ) {
    return PortProblemProvider(
      path,
    );
  }

  @override
  PortProblemProvider getProviderOverride(
    covariant PortProblemProvider provider,
  ) {
    return call(
      provider.path,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'portProblemProvider';
}

/// Whether the executable at [path] can still be run.
///
/// Copied from [portProblem].
class PortProblemProvider extends AutoDisposeFutureProvider<String?> {
  /// Whether the executable at [path] can still be run.
  ///
  /// Copied from [portProblem].
  PortProblemProvider(
    String path,
  ) : this._internal(
          (ref) => portProblem(
            ref as PortProblemRef,
            path,
          ),
          from: portProblemProvider,
          name: r'portProblemProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$portProblemHash,
          dependencies: PortProblemFamily._dependencies,
          allTransitiveDependencies:
              PortProblemFamily._allTransitiveDependencies,
          path: path,
        );

  PortProblemProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.path,
  }) : super.internal();

  final String path;

  @override
  Override overrideWith(
    FutureOr<String?> Function(PortProblemRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PortProblemProvider._internal(
        (ref) => create(ref as PortProblemRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        path: path,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<String?> createElement() {
    return _PortProblemProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PortProblemProvider && other.path == path;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, path.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin PortProblemRef on AutoDisposeFutureProviderRef<String?> {
  /// The parameter `path` of this provider.
  String get path;
}

class _PortProblemProviderElement
    extends AutoDisposeFutureProviderElement<String?> with PortProblemRef {
  _PortProblemProviderElement(super.provider);

  @override
  String get path => (origin as PortProblemProvider).path;
}

String _$iwadProblemHash() => r'3923af2cde8f77277a1f5fc7fa5fcca064b5cca3';

/// Whether the WAD at [path] is still there.
///
/// Copied from [iwadProblem].
@ProviderFor(iwadProblem)
const iwadProblemProvider = IwadProblemFamily();

/// Whether the WAD at [path] is still there.
///
/// Copied from [iwadProblem].
class IwadProblemFamily extends Family<AsyncValue<String?>> {
  /// Whether the WAD at [path] is still there.
  ///
  /// Copied from [iwadProblem].
  const IwadProblemFamily();

  /// Whether the WAD at [path] is still there.
  ///
  /// Copied from [iwadProblem].
  IwadProblemProvider call(
    String path,
  ) {
    return IwadProblemProvider(
      path,
    );
  }

  @override
  IwadProblemProvider getProviderOverride(
    covariant IwadProblemProvider provider,
  ) {
    return call(
      provider.path,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'iwadProblemProvider';
}

/// Whether the WAD at [path] is still there.
///
/// Copied from [iwadProblem].
class IwadProblemProvider extends AutoDisposeFutureProvider<String?> {
  /// Whether the WAD at [path] is still there.
  ///
  /// Copied from [iwadProblem].
  IwadProblemProvider(
    String path,
  ) : this._internal(
          (ref) => iwadProblem(
            ref as IwadProblemRef,
            path,
          ),
          from: iwadProblemProvider,
          name: r'iwadProblemProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$iwadProblemHash,
          dependencies: IwadProblemFamily._dependencies,
          allTransitiveDependencies:
              IwadProblemFamily._allTransitiveDependencies,
          path: path,
        );

  IwadProblemProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.path,
  }) : super.internal();

  final String path;

  @override
  Override overrideWith(
    FutureOr<String?> Function(IwadProblemRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: IwadProblemProvider._internal(
        (ref) => create(ref as IwadProblemRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        path: path,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<String?> createElement() {
    return _IwadProblemProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IwadProblemProvider && other.path == path;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, path.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin IwadProblemRef on AutoDisposeFutureProviderRef<String?> {
  /// The parameter `path` of this provider.
  String get path;
}

class _IwadProblemProviderElement
    extends AutoDisposeFutureProviderElement<String?> with IwadProblemRef {
  _IwadProblemProviderElement(super.provider);

  @override
  String get path => (origin as IwadProblemProvider).path;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
