import '../../../../core/services/github_api_service.dart';
import '../../domain/entities/engine_release.dart';
import '../../domain/entities/engine_source.dart';

class EngineRepository {
  final GithubApiService _api;

  EngineRepository(this._api);

  Future<List<EngineRelease>> fetchReleases(EngineSource source, {int perPage = 20}) async {
    final releases = await _api.fetchReleases(source.githubOwner, source.githubRepo, perPage: perPage);
    return releases.map(_toEngineRelease).toList();
  }

  Future<EngineRelease?> fetchLatestRelease(EngineSource source) async {
    final release = await _api.fetchLatestRelease(source.githubOwner, source.githubRepo);
    return release != null ? _toEngineRelease(release) : null;
  }

  EngineRelease _toEngineRelease(GithubRelease r) {
    return EngineRelease(
      tagName: r.tagName,
      name: r.name,
      prerelease: r.prerelease,
      body: r.body,
      publishedAt: r.publishedAt,
      assets: r.assets.map((a) => EngineAsset(
        name: a.name,
        downloadUrl: a.browserDownloadUrl,
        size: a.size,
        downloadCount: a.downloadCount,
      )).toList(),
    );
  }
}
