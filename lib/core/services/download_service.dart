import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

class DownloadProgress {
  final int receivedBytes;
  final int totalBytes;

  const DownloadProgress({required this.receivedBytes, required this.totalBytes});

  double get fraction => totalBytes > 0 ? receivedBytes / totalBytes : 0.0;
}

class DownloadService {
  Stream<DownloadProgress> download(String url, String destPath) async* {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw HttpException('Download failed: HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      var receivedBytes = 0;

      final file = File(destPath);
      await file.create(recursive: true);
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        yield DownloadProgress(receivedBytes: receivedBytes, totalBytes: totalBytes);
      }

      await sink.close();
    } finally {
      client.close();
    }
  }
}
