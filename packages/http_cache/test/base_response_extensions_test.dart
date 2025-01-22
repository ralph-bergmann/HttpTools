// ignore_for_file: lines_longer_than_80_chars

import 'package:http/http.dart';
import 'package:http_cache/src/base_response_extensions.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('BaseResponseExtensions', () {
    group('varyFields', () {
      test('returns an empty set when there is no Vary header', () {
        final response = Response('', 200);
        expect(response.varyFields, isEmpty);
      });

      test('returns a set of vary fields when Vary header is present', () {
        final headers = {
          'vary': 'Accept, Authorization',
        };
        final response = Response('', 200, headers: headers);
        expect(response.varyFields, containsAll(['accept', 'authorization']));
      });

      test('trims and lowercases vary fields', () {
        final headers = {
          'vary': ' Accept , AUTHORIZATION ',
        };
        final response = Response('', 200, headers: headers);
        expect(response.varyFields, containsAll(['accept', 'authorization']));
      });

      test('returns a sorted set of vary fields', () {
        final headers = {
          'vary': 'Authorization, Accept',
        };
        final response = Response('', 200, headers: headers);
        final varyFields = response.varyFields.toList();
        expect(varyFields, equals(['accept', 'authorization']));
      });
    });

    group('varyHeaders', () {
      test('returns an empty map when there are no vary fields', () {
        final response = Response('', 200);
        expect(response.varyHeaders, isEmpty);
      });

      test('returns a map of vary headers and their values from the request',
          () {
        final headers = {
          'vary': 'Accept, Authorization',
        };
        final requestHeaders = {
          'accept': 'application/json',
          'authorization': 'Bearer token',
        };
        final request = Request('GET', Uri.parse('https://example.com'))
          ..headers.addAll(requestHeaders);
        final response = StreamedResponse(
          const Stream.empty(),
          200,
          request: request,
          headers: headers,
        );
        expect(response.varyHeaders, equals(requestHeaders));
      });

      test('returns only the vary headers present in the request', () {
        final headers = {
          'vary': 'Accept, Authorization',
        };
        final requestHeaders = {
          'accept': 'application/json',
        };
        final request = Request('GET', Uri.parse('https://example.com'))
          ..headers.addAll(requestHeaders);
        final response = StreamedResponse(
          const Stream.empty(),
          200,
          request: request,
          headers: headers,
        );
        expect(response.varyHeaders, equals({'accept': 'application/json'}));
      });

      test(
          'returns an empty map when vary fields are not present in the request',
          () {
        final headers = {
          'vary': 'Accept, Authorization',
        };
        final request = Request('GET', Uri.parse('https://example.com'));
        final response = StreamedResponse(
          const Stream.empty(),
          200,
          request: request,
          headers: headers,
        );
        expect(response.varyHeaders, isEmpty);
      });
    });

    group('secondaryCacheKey', () {
      test('returns null when request is null', () {
        final response = Response('', 200);
        expect(response.secondaryCacheKey, isNull);
      });

      test('returns a UUID v5 hash of the URL when there are no vary headers',
          () {
        final request = Request('GET', Uri.parse('https://example.com'));
        final response =
            StreamedResponse(const Stream.empty(), 200, request: request);
        final expectedKey =
            const Uuid().v5(Namespace.url.value, 'https://example.com|');
        expect(response.secondaryCacheKey, equals(expectedKey));
      });

      test('returns a UUID v5 hash of the URL and vary headers', () {
        final headers = {
          'vary': 'Accept, Authorization',
        };
        final requestHeaders = {
          'accept': 'application/json',
          'authorization': 'Bearer token',
        };
        final request = Request('GET', Uri.parse('https://example.com'))
          ..headers.addAll(requestHeaders);
        final response = StreamedResponse(
          const Stream.empty(),
          200,
          request: request,
          headers: headers,
        );
        const combinedString =
            'https://example.com|accept:application/json,authorization:Bearer token';
        final expectedKey =
            const Uuid().v5(Namespace.url.value, combinedString);
        expect(response.secondaryCacheKey, equals(expectedKey));
      });

      test('returns a UUID v5 hash of the URL and sorted vary headers', () {
        final headers = {
          'vary': 'Authorization, Accept',
        };
        final requestHeaders = {
          'accept': 'application/json',
          'authorization': 'Bearer token',
        };
        final request = Request('GET', Uri.parse('https://example.com'))
          ..headers.addAll(requestHeaders);
        final response = StreamedResponse(
          const Stream.empty(),
          200,
          request: request,
          headers: headers,
        );
        const combinedString =
            'https://example.com|accept:application/json,authorization:Bearer token';
        final expectedKey =
            const Uuid().v5(Namespace.url.value, combinedString);
        expect(response.secondaryCacheKey, equals(expectedKey));
      });
    });

    group('hasVaryAll', () {
      test('returns true when Vary header contains *', () {
        final headers = {
          'vary': '*',
        };
        final response = Response('', 200, headers: headers);
        expect(response.hasVaryAll(), isTrue);
      });

      test('returns true when Vary header contains multiple values including *',
          () {
        final headers = {
          'vary': 'Accept, Authorization, *',
        };
        final response = Response('', 200, headers: headers);
        expect(response.hasVaryAll(), isTrue);
      });

      test('returns false when Vary header does not contain *', () {
        final headers = {
          'vary': 'Accept, Authorization',
        };
        final response = Response('', 200, headers: headers);
        expect(response.hasVaryAll(), isFalse);
      });

      test('returns false when there is no Vary header', () {
        final response = Response('', 200);
        expect(response.hasVaryAll(), isFalse);
      });
    });
  });
}
