import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:quickdoom/core/services/github_api_service.dart';
import 'package:quickdoom/core/services/idgames_api_service.dart';

void main() {
  // These services used to answer every failure with an empty list, which the
  // UI rendered as "nothing found". What a user now sees instead is worth
  // pinning down.

  group('GithubApiService.errorFor', () {
    test('names the rate limit when the quota is spent', () {
      final error = GithubApiService.errorFor(http.Response('{}', 403, headers: {
        'x-ratelimit-remaining': '0',
        'x-ratelimit-reset': '1700000000',
      }));

      expect(error.statusCode, 403);
      expect(error.message, contains('rate limit'));
      expect(error.message, contains('Try again after'));
    });

    test('handles a spent quota with no reset header', () {
      final error = GithubApiService.errorFor(http.Response('{}', 429, headers: {
        'x-ratelimit-remaining': '0',
      }));

      expect(error.message, contains('rate limit'));
      expect(error.message, isNot(contains('Try again after')));
    });

    test('a 403 with quota left is not reported as rate limiting', () {
      final error = GithubApiService.errorFor(http.Response('{}', 403, headers: {
        'x-ratelimit-remaining': '57',
      }));

      expect(error.message, contains('HTTP 403'));
      expect(error.message, isNot(contains('rate limit')));
    });

    test('reports a missing repository', () {
      final error = GithubApiService.errorFor(http.Response('{}', 404));
      expect(error.statusCode, 404);
      expect(error.message, contains('not found'));
    });

    test('falls back to the status code', () {
      final error = GithubApiService.errorFor(http.Response('{}', 503));
      expect(error.message, contains('HTTP 503'));
    });
  });

  group('exceptions', () {
    test('GithubApiException prints its message', () {
      const e = GithubApiException(503, 'GitHub returned HTTP 503.');
      expect(e.toString(), 'GitHub returned HTTP 503.');
    });

    test('IdgamesApiException prints its message', () {
      const e = IdgamesApiException('idgames returned HTTP 500.');
      expect(e.toString(), 'idgames returned HTTP 500.');
    });
  });
}
