import 'package:http/http.dart' as http;

class BrowserClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  static const Map<String, String> _browserHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': 'https://www.doomworld.com/idgames/',
  };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_browserHeaders);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}
