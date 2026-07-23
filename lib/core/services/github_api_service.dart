import 'dart:convert';

import 'package:http/http.dart' as http;

class GithubAsset {
  final int id;
  final String name;
  final String browserDownloadUrl;
  final int size;
  final int downloadCount;

  const GithubAsset({
    required this.id,
    required this.name,
    required this.browserDownloadUrl,
    required this.size,
    required this.downloadCount,
  });

  factory GithubAsset.fromJson(Map<String, dynamic> json) {
    return GithubAsset(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      browserDownloadUrl: json['browser_download_url'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      downloadCount: json['download_count'] as int? ?? 0,
    );
  }
}

class GithubRelease {
  final String tagName;
  final String name;
  final bool prerelease;
  final String body;
  final DateTime publishedAt;
  final List<GithubAsset> assets;

  const GithubRelease({
    required this.tagName,
    required this.name,
    required this.prerelease,
    required this.body,
    required this.publishedAt,
    required this.assets,
  });

  factory GithubRelease.fromJson(Map<String, dynamic> json) {
    final assetsList = (json['assets'] as List<dynamic>?)
            ?.map((a) => GithubAsset.fromJson(a as Map<String, dynamic>))
            .toList() ??
        [];

    return GithubRelease(
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      prerelease: json['prerelease'] as bool? ?? false,
      body: json['body'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '') ?? DateTime(1970),
      assets: assetsList,
    );
  }

  List<GithubAsset> assetsForPlatform(String platform) {
    final lower = platform.toLowerCase();
    return assets.where((a) {
      final name = a.name.toLowerCase();
      if (lower == 'windows') {
        return name.contains('win64') || name.contains('win32') || name.contains('windows');
      }
      if (lower == 'linux') {
        return name.contains('linux') && !name.contains('win');
      }
      if (lower == 'macos') {
        return name.contains('mac') || name.contains('osx') || name.contains('darwin');
      }
      return false;
    }).toList();
  }
}

class GithubApiService {
  static const String _baseUrl = 'https://api.github.com';

  Future<List<GithubRelease>> fetchReleases(String owner, String repo, {int perPage = 20}) async {
    final uri = Uri.parse('$_baseUrl/repos/$owner/$repo/releases').replace(queryParameters: {
      'per_page': perPage.toString(),
    });

    final response = await http.get(
      uri,
      headers: {'Accept': 'application/vnd.github.v3+json', 'User-Agent': 'QuickDoom'},
    );

    if (response.statusCode != 200) return [];

    final body = jsonDecode(response.body) as List<dynamic>;
    return body
        .cast<Map<String, dynamic>>()
        .map((r) => GithubRelease.fromJson(r))
        .toList();
  }

  Future<GithubRelease?> fetchLatestRelease(String owner, String repo) async {
    final uri = Uri.parse('$_baseUrl/repos/$owner/$repo/releases/latest');

    final response = await http.get(
      uri,
      headers: {'Accept': 'application/vnd.github.v3+json', 'User-Agent': 'QuickDoom'},
    );

    if (response.statusCode != 200) return null;

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return GithubRelease.fromJson(body);
  }
}
