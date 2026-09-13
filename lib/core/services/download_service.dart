import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../http/browser_client.dart';

class DownloadProgress {
  final int receivedBytes;
  final int totalBytes;

  const DownloadProgress({required this.receivedBytes, required this.totalBytes});

  /// 0.0 when the server sent no Content-Length, so callers can fall back to
  /// an indeterminate bar rather than showing a stuck 0%.
  double get fraction => totalBytes > 0 ? receivedBytes / totalBytes : 0.0;

  bool get hasTotal => totalBytes > 0;
}

class DownloadException implements Exception {
  final String message;

  const DownloadException(this.message);

  @override
  String toString() => 'DownloadException: $message';
}

/// Streams a remote file to disk, reporting progress as it goes.
///
/// The payload is written to a sibling `.part` file and renamed only once the
/// transfer finishes, so an interrupted download can never be mistaken for a
/// complete one by the installer.
class DownloadService {
  final http.Client Function(Uri url) _clientFactory;

  DownloadService({http.Client Function(Uri url)? clientFactory})
      : _clientFactory = clientFactory ?? _defaultClient;

  /// idgames rejects non-browser agents; everything else gets a plain client.
  static http.Client _defaultClient(Uri url) {
    if (url.host.endsWith('doomworld.com')) return BrowserClient();
    return http.Client();
  }

  Stream<DownloadProgress> download(String url, String destPath) async* {
    final uri = Uri.parse(url);
    final client = _clientFactory(uri);
    final partPath = '$destPath.part';
    final partFile = File(partPath);

    try {
      final request = http.Request('GET', uri)
        ..headers['User-Agent'] = 'QuickDoom'
        ..followRedirects = true;

      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw DownloadException('HTTP ${response.statusCode} for $url');
      }

      final totalBytes = response.contentLength ?? 0;
      var receivedBytes = 0;

      await partFile.parent.create(recursive: true);
      final sink = partFile.openWrite();

      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          yield DownloadProgress(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
          );
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (totalBytes > 0 && receivedBytes != totalBytes) {
        throw DownloadException(
          'Incomplete download: got $receivedBytes of $totalBytes bytes.',
        );
      }

      // Rename is atomic on the same filesystem, so destPath either does not
      // exist or is the finished payload.
      final dest = File(destPath);
      if (await dest.exists()) await dest.delete();
      await partFile.rename(destPath);

      yield DownloadProgress(
        receivedBytes: receivedBytes,
        totalBytes: totalBytes > 0 ? totalBytes : receivedBytes,
      );
    } finally {
      client.close();
      // A cancelled or failed transfer leaves no half-written file behind.
      if (await partFile.exists()) {
        try {
          await partFile.delete();
        } catch (_) {
          // Nothing actionable; the .part name keeps it out of the installer.
        }
      }
    }
  }
}
