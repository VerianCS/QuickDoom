import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/services/github_api_service.dart';
import '../../data/repositories/engine_repository.dart';
import '../../domain/entities/engine_release.dart';
import '../../domain/entities/engine_source.dart';

part 'engine_releases_provider.g.dart';

final _engineRepositoryProvider = Provider<EngineRepository>((ref) {
  return EngineRepository(GithubApiService());
});

@riverpod
Future<List<EngineRelease>> engineReleases(EngineReleasesRef ref, EngineSource source) async {
  return ref.read(_engineRepositoryProvider).fetchReleases(source);
}
