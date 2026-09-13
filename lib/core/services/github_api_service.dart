import 'dart:convert';

import 'package:flutter/foundation.dart';
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

/// A GitHub request that did not succeed.
///
/// Surfaced rather than swallowed: unauthenticated clients get 60 requests an
/// hour, and browsing a handful of engines is enough to hit it. Reporting that
/// as "no releases" sends people looking for a bug that is not there.
class GithubApiException implements Exception {
  final int statusCode;
  final String message;

  const GithubApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class GithubApiService {
  static const String _baseUrl = 'https://api.github.com';

  static const Map<String, String> _headers = {
    'Accept': 'application/vnd.github.v3+json',
    'User-Agent': 'QuickDoom',
  };

  /// Turns a failed response into a message worth showing a user.
  @visibleForTesting
  static GithubApiException errorFor(http.Response response) {
    final remaining = response.headers['x-ratelimit-remaining'];
    final status = response.statusCode;

    if ((status == 403 || status == 429) && remaining == '0') {
      final reset = response.headers['x-ratelimit-reset'];
      final seconds = int.tryParse(reset ?? '');
      final when = seconds == null
          ? ''
          : ' Try again after '
              '${DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal()}.';
      return GithubApiException(
        status,
        'GitHub rate limit reached — 60 requests per hour for unauthenticated '
        'clients.$when',
      );
    }

    if (status == 404) {
      return const GithubApiException(404, 'Repository not found on GitHub.');
    }

    return GithubApiException(status, 'GitHub returned HTTP $status.');
  }

  Future<List<GithubRelease>> fetchReleases(String owner, String repo, {int perPage = 20}) async {
    final uri = Uri.parse('$_baseUrl/repos/$owner/$repo/releases').replace(queryParameters: {
      'per_page': perPage.toString(),
    });

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) throw errorFor(response);

    final body = jsonDecode(response.body) as List<dynamic>;
    return body
        .cast<Map<String, dynamic>>()
        .map((r) => GithubRelease.fromJson(r))
        .toList();
  }

  Future<GithubRelease?> fetchLatestRelease(String owner, String repo) async {
    final uri = Uri.parse('$_baseUrl/repos/$owner/$repo/releases/latest');

    final response = await http.get(uri, headers: _headers);

    // A repo with no releases yet is a legitimate empty answer, not an error.
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) throw errorFor(response);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return GithubRelease.fromJson(body);
  }
}
