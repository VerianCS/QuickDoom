import 'dart:convert';

import 'package:http/http.dart' as http;

import '../http/browser_client.dart';

class IdgamesFileResult {
  final int id;
  final String title;
  final String dir;
  final String filename;
  final int size;
  final DateTime date;
  final String author;
  final String email;
  final String description;
  final double rating;
  final int votes;
  final String url;
  final String idgamesUrl;

  const IdgamesFileResult({
    required this.id,
    required this.title,
    required this.dir,
    required this.filename,
    required this.size,
    required this.date,
    required this.author,
    required this.email,
    required this.description,
    required this.rating,
    required this.votes,
    required this.url,
    required this.idgamesUrl,
  });

  String get downloadUrl => 'https://www.doomworld.com/idgames/$dir$filename';

  factory IdgamesFileResult.fromJson(Map<String, dynamic> json) {
    return IdgamesFileResult(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      dir: json['dir'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime(1970),
      author: json['author'] as String? ?? '',
      email: json['email'] as String? ?? '',
      description: json['description'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      votes: json['votes'] as int? ?? 0,
      url: json['url'] as String? ?? '',
      idgamesUrl: json['idgamesurl'] as String? ?? '',
    );
  }
}

/// An idgames request that failed, or that the archive answered with an error.
///
/// Reported rather than swallowed so a network or API problem is not shown as
/// "no results found".
class IdgamesApiException implements Exception {
  final String message;

  const IdgamesApiException(this.message);

  @override
  String toString() => message;
}

class IdgamesApiService {
  static const String _baseUrl = 'https://www.doomworld.com/idgames/api/api.php';

  /// Pulls the human-readable reason out of an idgames error payload.
  static String _errorMessage(Map<String, dynamic> body) {
    final error = body['error'];
    if (error is Map && error['message'] is String) {
      return error['message'] as String;
    }
    return 'The idgames archive returned an error.';
  }

  Future<List<IdgamesFileResult>> search({
    required String query,
    String type = 'title',
    String sort = 'date',
    String dir = 'desc',
  }) async {
    if (query.length < 3) return [];

    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'action': 'search',
      'query': query,
      'type': type,
      'sort': sort,
      'dir': dir,
      'out': 'json',
    });

    final client = BrowserClient();
    final http.Response response;
    try {
      response = await client.get(uri);
    } finally {
      client.close();
    }

    if (response.statusCode != 200) {
      throw IdgamesApiException(
        'idgames returned HTTP ${response.statusCode}.',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body case {'error': _}) throw IdgamesApiException(_errorMessage(body));

    // A search with no matches comes back as a warning, which is not an error.

    final content = body['content'] as Map<String, dynamic>?;
    if (content == null) return [];

    final fileData = content['file'];
    if (fileData == null) return [];

    if (fileData is List) {
      return fileData
          .cast<Map<String, dynamic>>()
          .map((f) => IdgamesFileResult.fromJson(f))
          .toList();
    }

    if (fileData is Map<String, dynamic>) {
      return [IdgamesFileResult.fromJson(fileData)];
    }

    return [];
  }

  Future<IdgamesFileResult?> getDetails(int id) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'action': 'get',
      'id': id.toString(),
      'out': 'json',
    });

    final client = BrowserClient();
    final http.Response response;
    try {
      response = await client.get(uri);
    } finally {
      client.close();
    }

    if (response.statusCode != 200) {
      throw IdgamesApiException(
        'idgames returned HTTP ${response.statusCode}.',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body case {'error': _}) throw IdgamesApiException(_errorMessage(body));

    final content = body['content'] as Map<String, dynamic>?;
    if (content == null) return null;

    return IdgamesFileResult.fromJson(content);
  }
}
