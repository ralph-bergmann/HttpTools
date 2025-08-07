// ignore_for_file: avoid_positional_boolean_parameters

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:http_client_cache/http_client_cache.dart';
import 'package:http_client_cache/src/base_response_extensions.dart';
import 'package:http_client_cache/src/cache_status.dart';
import 'package:http_client_cache/src/journal/cache_entry_extensions.dart';
import 'package:http_client_cache/src/journal/journal.pb.dart';
import 'package:http_client_interceptor/http_client_interceptor.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_test_handler/shelf_test_handler.dart';
import 'package:test/test.dart';

void main() {
  group('CacheEntry', () {
    test('getCacheEntryForRequest returns null if no entry exists', () async {
      final httpCache = await _createHttpCache();

      final request = http.Request('GET', Uri.parse('https://example.com'));
      final cacheEntry = httpCache.getCacheEntryForRequest(request);
      expect(cacheEntry, isNull);
    });

    test('getCachedResponse returns null if no entry exists', () async {
      final httpCache = await _createHttpCache();

      final request = http.Request('GET', Uri.parse('https://example.com'));
      final cachedResponse = httpCache.getCachedResponse(request);
      expect(cachedResponse, isNull);
    });

    test('add a new cache entry', () async {
      final httpCache = await _createHttpCache();

      final stream = Stream.value(utf8.encode('body'));
      final response = http.StreamedResponse(
        stream,
        200,
        request: http.Request('GET', Uri.parse('https://example.com')),
      );
      await httpCache.addOrUpdateCacheEntryForResponse(response);
      await httpCache.addResponseToCache(response.secondaryCacheKey!, stream);

      final cacheEntry = httpCache.getCacheEntryForRequest(response.request!);
      expect(cacheEntry, isNotNull);

      final cachedResponse = httpCache.getCachedResponse(response.request!);
      expect(cachedResponse, isNotNull);
      final body = await cachedResponse!.stream.toBytes();
      expect(utf8.decode(body), 'body');
    });

    test('update an existing cache entry', () async {
      final httpCache = await _createHttpCache();

      // initial cached response
      var stream = Stream.value(utf8.encode('body'));
      var response = http.StreamedResponse(
        stream,
        200,
        request: http.Request('GET', Uri.parse('https://example.com')),
        headers: <String, String>{
          'custom header': 'custom header value',
        },
      );
      await httpCache.addOrUpdateCacheEntryForResponse(response);
      await httpCache.addResponseToCache(response.secondaryCacheKey!, stream);

      var cacheEntry = httpCache.getCacheEntryForRequest(response.request!);
      expect(cacheEntry, isNotNull);

      var header = cacheEntry!.responseHeaders.entries.firstOrNull;
      expect(header, isNotNull);
      expect(header!.key, 'custom header');
      expect(header.value, 'custom header value');

      var cachedResponse = httpCache.getCachedResponse(response.request!);
      expect(cachedResponse, isNotNull);
      var body = await cachedResponse!.stream.toBytes();
      expect(utf8.decode(body), 'body');

      // updated cached response
      stream = Stream.value(utf8.encode('updated body'));
      response = http.StreamedResponse(
        stream,
        200,
        request: http.Request('GET', Uri.parse('https://example.com')),
        headers: <String, String>{
          'custom header': 'updated custom header value',
        },
      );
      await httpCache.addOrUpdateCacheEntryForResponse(response);
      await httpCache.addResponseToCache(response.secondaryCacheKey!, stream);

      cacheEntry = httpCache.getCacheEntryForRequest(response.request!);
      expect(cacheEntry, isNotNull);

      header = cacheEntry!.responseHeaders.entries.firstOrNull;
      expect(header, isNotNull);
      expect(header!.key, 'custom header');
      expect(header.value, 'updated custom header value');

      cachedResponse = httpCache.getCachedResponse(response.request!);
      expect(cachedResponse, isNotNull);
      body = await cachedResponse!.stream.toBytes();
      expect(utf8.decode(body), 'updated body');
    });
  });

  group('CacheControlFlags', () {
    group('private cache', () {
      Future<void> runCacheControlTests(bool isPrivate) async {
        final httpCache = await _createHttpCache(isPrivate: isPrivate);
        final client = _createClient(httpCache);

        final server = await _createTestServer([
          (request) => shelf.Response.ok(
                'body',
                headers: {HttpHeaders.cacheControlHeader: 'private'},
              ),
        ]);

        final response = await client.get(server.testUrl);

        expect(response.body, 'body');
        final cacheEntry = httpCache.getCacheEntryForRequest(response.request!);
        if (isPrivate) {
          expect(cacheEntry, isNotNull);
          expect(cacheEntry!.isPrivate, isTrue);
        } else {
          expect(cacheEntry, isNull);
        }
      }

      test('private cache', () async {
        await runCacheControlTests(true);
      });

      test('non-private cache', () async {
        await runCacheControlTests(false);
      });
    });

    group('revalidation', () {
      Future<void> testRevalidation(
        String cacheControlHeader,
        bool notModified,
      ) async {
        final httpCache = await _createHttpCache();
        final client = _createClient(httpCache);

        var requestCount = 0;

        final server = await _createTestServer([
          (request) {
            requestCount++;
            return shelf.Response.ok(
              'body1',
              headers: {HttpHeaders.cacheControlHeader: cacheControlHeader},
            );
          },
          if (notModified)
            (request) {
              requestCount++;
              return shelf.Response.notModified();
            }
          else
            (request) {
              requestCount++;
              return shelf.Response.ok(
                'body2',
                headers: {HttpHeaders.cacheControlHeader: cacheControlHeader},
              );
            },
        ]);

        final response1 = await client.get(server.testUrl);
        expect(response1.body, 'body1');

        final cacheEntry = httpCache.getCacheEntryForRequest(response1.request!);
        expect(cacheEntry, isNotNull);

        // Make the request again to trigger revalidation.
        // This second request should cause the cache to revalidate the entry
        // by making another request to the server. The server request count
        // should be incremented to 2, indicating that revalidation occurred.
        // Depending on whether the notModified flag is true, the response
        // body should be either 'body1' or 'body2' (comes from the cache or the
        // server, respectively).
        final response2 = await client.get(server.testUrl);
        expect(response2.body, notModified ? 'body1' : 'body2');
        expect(requestCount, 2);
      }

      test('no-cache directive requires revalidation - not modified', () async {
        await testRevalidation('/no-cache', true);
      });

      test('no-cache directive requires revalidation - modified', () async {
        await testRevalidation('/no-cache', false);
      });

      test('must-revalidate requires revalidation - not modified', () async {
        await testRevalidation('/must-revalidate', true);
      });

      test('must-revalidate requires revalidation - modified', () async {
        await testRevalidation('/must-revalidate', false);
      });

      Future<void> testStaleWhileRevalidate(bool notModified) async {
        final httpCache = await _createHttpCache();
        final client = _createClient(httpCache);

        var requestCount = 0;

        final server = await _createTestServer([
          (request) {
            requestCount++;
            return shelf.Response.ok(
              'body1',
              headers: {
                HttpHeaders.cacheControlHeader: 'max-age=0, stale-while-revalidate=60',
              },
            );
          },
          if (notModified)
            (request) {
              requestCount++;
              return shelf.Response.notModified();
            }
          else
            (request) {
              requestCount++;
              return shelf.Response.ok(
                'body2',
                headers: {
                  HttpHeaders.cacheControlHeader: 'max-age=0, stale-while-revalidate=60',
                },
              );
            },
        ]);

        // First request - caches the response
        final response1 = await client.get(server.testUrl);
        expect(response1.body, 'body1');
        expect(requestCount, 1);

        // Second request - should return stale response while revalidating
        final response2 = await client.get(server.testUrl);

        // Should return stale response (body1) while revalidating
        expect(response2.body, 'body1');

        // Wait for background revalidation to complete.
        // The second request gets its response immediately from the cache,
        // and does not need to wait for the revalidation to complete.
        // The revalidation request should be made in the background and needs
        // some time to complete.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(requestCount, 2);

        // Verify the cache was updated with new response
        // Get the actual cached response body
        final cachedResponse = httpCache.getCachedResponse(response2.request!);
        expect(cachedResponse, isNotNull);
        final cachedBody = await cachedResponse!.stream.bytesToString();
        expect(cachedBody, notModified ? 'body1' : 'body2');
      }

      test('stale-while-revalidate directive - not modified', () async {
        await testStaleWhileRevalidate(true);
      });

      test('stale-while-revalidate directive - modified', () async {
        await testStaleWhileRevalidate(false);
      });
    });

    test('stale-if-error directive is handled', () async {
      final httpCache = await _createHttpCache();
      final client = _createClient(httpCache);

      // Step 1: Set up the server to handle the initial request
      final server = await _createTestServer([
        (request) => shelf.Response.ok(
              'body',
              headers: {
                HttpHeaders.cacheControlHeader: 'max-age=0, stale-if-error=60',
              },
            ),
      ]);
      final testUrl = server.testUrl;

      // Step 2: Make the initial request to cache the response
      final response1 = await client.get(testUrl);
      expect(response1.body, 'body');

      // Verify that the cache entry exists
      final cacheEntry = httpCache.getCacheEntryForRequest(response1.request!);
      expect(cacheEntry, isNotNull);

      // Step 3: Shut down the server to simulate an error
      await server.close();

      // Step 4: Make the request again to trigger the stale-if-error behavior
      final response2 = await client.get(testUrl);
      expect(response2.body, 'body');

      // Verify that the response is served from the cache
      final cacheStatusHeader = response2.headers[CacheStatus.headerName];
      expect(cacheStatusHeader, isNotNull);

      final cacheStatus = CacheStatus.fromHeader(cacheStatusHeader!);
      expect(cacheStatus.hit, isTrue);
    });

    test('no-store directive prevents caching', () async {
      final httpCache = await _createHttpCache();
      final client = _createClient(httpCache);
      final server = await _createTestServer([
        (request) => shelf.Response.ok(
              'body',
              headers: {HttpHeaders.cacheControlHeader: 'no-store'},
            ),
      ]);

      final response = await client.get(server.testUrl);

      expect(response.body, 'body');
      final cacheEntry = httpCache.getCacheEntryForRequest(response.request!);
      expect(cacheEntry, isNull);
    });

    group('expiration', () {
      Future<void> expiration(Map<String, String> headers) async {
        final httpCache = await _createHttpCache();
        final client = _createClient(httpCache);

        final server = await _createTestServer([
          (request) => shelf.Response.ok(
                'body1',
                headers: headers,
              ),
          (request) => shelf.Response.ok(
                'body2',
                headers: headers,
              ),
        ]);

        // verify first response
        final response1 = await client.get(server.testUrl);
        expect(response1.body, 'body1');
        final cacheEntry = httpCache.getCacheEntryForRequest(response1.request!);
        expect(cacheEntry, isNotNull);
        final cachedResponse1 = httpCache.getCachedResponse(response1.request!);
        expect(cachedResponse1, isNotNull);
        final cachedBody1 = await cachedResponse1!.stream.bytesToString();
        expect(cachedBody1, 'body1');

        // Wait a few seconds and make the request again. The response should be
        // served from the cache.
        await Future<void>.delayed(const Duration(seconds: 2));

        final response2 = await client.get(server.testUrl);
        expect(response2.body, 'body1');
        final cachedResponse2 = httpCache.getCachedResponse(response2.request!);
        expect(cachedResponse2, isNotNull);
        final cachedBody2 = await cachedResponse2!.stream.bytesToString();
        expect(cachedBody2, 'body1');

        // Wait for the cache entry to expire
        await Future<void>.delayed(const Duration(seconds: 5));

        // Make the request again and verify the response
        final response3 = await client.get(server.testUrl);
        expect(response3.body, 'body2');
        final cachedResponse3 = httpCache.getCachedResponse(response3.request!);
        expect(cachedResponse3, isNotNull);
        final cachedBody3 = await cachedResponse3!.stream.bytesToString();
        expect(cachedBody3, 'body2');
      }

      test('max-age', () async {
        await expiration({HttpHeaders.cacheControlHeader: 'max-age=5'});
      });

      test('expires', () async {
        await expiration(
          {
            HttpHeaders.expiresHeader: HttpDate.format(
              DateTime.now().add(const Duration(seconds: 5)).toUtc(),
            ),
          },
        );
      });

      test('max-age takes precedence over expires', () async {
        // According to RFC 9111 section 4.2.1, the max-age directive takes
        // precedence over the expires header. Should expire after 5 seconds
        // (max-age) and not 60 seconds (expires).
        await expiration({
          HttpHeaders.cacheControlHeader: 'max-age=5',
          HttpHeaders.expiresHeader: HttpDate.format(
            DateTime.now().add(const Duration(seconds: 60)).toUtc(),
          ),
        });
      });
    });

    test('Vary header', () async {
      final httpCache = await _createHttpCache();
      final client = _createClient(httpCache);

      final server = await _createTestServer([
        (request) => shelf.Response.ok(
              'body for agent 1',
              headers: {
                HttpHeaders.cacheControlHeader: 'public, max-age=60',
                'vary': 'User-Agent',
                'x-user-agent': request.headers[HttpHeaders.userAgentHeader]!,
              },
            ),
        (request) => shelf.Response.ok(
              'body for agent 2',
              headers: {
                HttpHeaders.cacheControlHeader: 'public, max-age=60',
                'vary': 'User-Agent',
                'x-user-agent': request.headers[HttpHeaders.userAgentHeader]!,
              },
            ),
      ]);

      final response1 = await client.get(
        server.testUrl,
        headers: {HttpHeaders.userAgentHeader: 'TestAgent1'},
      );
      expect(response1.body, 'body for agent 1');
      expect(response1.headers['x-user-agent'], 'TestAgent1');

      // The Vary header indicates that the response varies based on the
      // User-Agent header. Therefore, the cache should store separate
      // responses for different User-Agent values. The second response
      // should be different from the first response because it has a
      // different User-Agent.
      final response2 = await client.get(
        server.testUrl,
        headers: {HttpHeaders.userAgentHeader: 'TestAgent2'},
      );
      expect(response2.body, 'body for agent 2');
      expect(response2.headers['x-user-agent'], 'TestAgent2');

      // Verify that the cache store contains two cache entries, one for each
      // User-Agent value. The response should come from the cache and not
      // from the server. Server will throw an exception when another request
      // is made.
      final response3 = await client.get(
        server.testUrl,
        headers: {HttpHeaders.userAgentHeader: 'TestAgent1'},
      );
      expect(response3.body, 'body for agent 1');

      final response4 = await client.get(
        server.testUrl,
        headers: {HttpHeaders.userAgentHeader: 'TestAgent2'},
      );
      expect(response4.body, 'body for agent 2');
    });
  });

  group('Cache invalidation', () {
    Future<void> testCacheInvalidation(String method, String path) async {
      final httpCache = await _createHttpCache();
      final client = _createClient(httpCache);
      final server = await ShelfTestServer.create();
      addTearDown(server.close);

      server.handler.expect(
        'GET',
        path,
        (request) => shelf.Response.ok(
          'body',
          headers: {HttpHeaders.cacheControlHeader: 'max-age=60'},
        ),
      );

      server.handler.expect(
        method,
        path,
        (request) => shelf.Response.ok('ok'),
      );

      server.handler.expect(
        'GET',
        path,
        (request) => shelf.Response.ok(
          'updated body',
          headers: {HttpHeaders.cacheControlHeader: 'max-age=60'},
        ),
      );

      final response1 = await client.get(server.url.replace(path: path));
      expect(response1.body, 'body');

      final cacheEntry = httpCache.getCacheEntryForRequest(response1.request!);
      expect(cacheEntry, isNotNull);

      // Invalidate the cache entry with the specified request method
      if (method == 'PUT' || method == 'DELETE' || method == 'POST' || method == 'PATCH') {
        final response2 = await client.send(
          http.Request(method, server.url.replace(path: path))..body = 'new data',
        );
        final body = await response2.stream.bytesToString();
        expect(body, 'ok');
      } else {
        fail('Unsupported method: $method');
      }

      // Make the request again to ensure the cache entry has been invalidated
      final response3 = await client.get(server.url.replace(path: path));
      expect(response3.body, 'updated body');
    }

    test('Cache invalidation on PUT request', () async {
      await testCacheInvalidation('PUT', '/invalidate-put');
    });

    test('Cache invalidation on DELETE request', () async {
      await testCacheInvalidation('DELETE', '/invalidate-delete');
    });

    test('Cache invalidation on POST request', () async {
      await testCacheInvalidation('POST', '/invalidate-post');
    });

    test('Cache invalidation on PATCH request', () async {
      await testCacheInvalidation('PATCH', '/invalidate-patch');
    });

    test('should invalidate cache for a given request', () async {
      final httpCache = await _createHttpCache();

      // Create a dummy request and response
      final request = Request('GET', Uri.parse('https://example.com/data'));
      final response = StreamedResponse(
        Stream.value([1, 2, 3]),
        200,
        request: request,
        headers: {HttpHeaders.cacheControlHeader: 'max-age=3600'},
      );

      // Add the response to the cache
      await httpCache.onResponse(response);

      // Verify that the cache entry exists
      expect(httpCache.getCachedResponse(request), isNotNull);

      // Invalidate the cache for the request
      await httpCache.invalidateCacheForRequest(request);

      // Verify that the cache entry has been invalidated
      expect(httpCache.getCachedResponse(request), isNull);
    });

    test('should handle non-existent cache entries gracefully', () async {
      final httpCache = await _createHttpCache();

      // Create a dummy request
      final request = Request('GET', Uri.parse('https://example.com/nonexistent'));

      // Invalidate the cache for the request
      await httpCache.invalidateCacheForRequest(request);

      // Verify that no exception is thrown and the cache remains empty
      expect(httpCache.getCachedResponse(request), isNull);
    });
  });

  group('isMatchingCacheEntry', () {
    test('should return true when vary headers match', () async {
      final httpCache = await _createHttpCache();

      final request = http.Request('GET', Uri.parse('https://example.com'));
      request.headers['Accept'] = 'application/json';

      final cacheEntry = CacheEntry(
        cacheKey: 'cacheKey',
        reasonPhrase: 'OK',
        contentLength: 123,
        responseHeaders: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        }.entries,
        varyHeaders: {'Accept': 'application/json'}.entries,
      );

      final result = httpCache.isMatchingCacheEntry(request, cacheEntry);
      expect(result, isTrue);
    });

    test('should return false when vary headers do not match', () async {
      final httpCache = await _createHttpCache();

      final request = http.Request('GET', Uri.parse('https://example.com'));
      request.headers['Accept'] = 'application/xml';

      final cacheEntry = CacheEntry(
        cacheKey: 'cacheKey',
        reasonPhrase: 'OK',
        contentLength: 123,
        responseHeaders: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        }.entries,
        varyHeaders: {'Accept': 'application/json'}.entries,
      );

      final result = httpCache.isMatchingCacheEntry(request, cacheEntry);
      expect(result, isFalse);
    });

    test('should return true when there are no vary headers', () async {
      final httpCache = await _createHttpCache();

      final request = http.Request('GET', Uri.parse('https://example.com'));

      final cacheEntry = CacheEntry(
        cacheKey: 'cacheKey',
        reasonPhrase: 'OK',
        contentLength: 123,
        responseHeaders: {'Content-Type': 'application/json'}.entries,
        varyHeaders: {},
      );

      final result = httpCache.isMatchingCacheEntry(request, cacheEntry);
      expect(result, isTrue);
    });

    test('should return true when request has more headers than vary headers', () async {
      final httpCache = await _createHttpCache();

      final request = http.Request('GET', Uri.parse('https://example.com'));
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer token';

      final cacheEntry = CacheEntry(
        cacheKey: 'cacheKey',
        reasonPhrase: 'OK',
        contentLength: 123,
        responseHeaders: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        }.entries,
        varyHeaders: {'Accept': 'application/json'}.entries,
      );

      final result = httpCache.isMatchingCacheEntry(request, cacheEntry);
      expect(result, isTrue);
    });

    test('should return false when vary headers have more headers than request', () async {
      final httpCache = await _createHttpCache();

      final request = http.Request('GET', Uri.parse('https://example.com'));
      request.headers['Accept'] = 'application/json';

      final cacheEntry = CacheEntry(
        cacheKey: 'cacheKey',
        reasonPhrase: 'OK',
        contentLength: 123,
        responseHeaders: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer token',
        }.entries,
        varyHeaders: {
          'Accept': 'application/json',
          'Authorization': 'Bearer token',
        }.entries,
      );

      final result = httpCache.isMatchingCacheEntry(request, cacheEntry);
      expect(result, isFalse);
    });

    test('should return true when headers are in different order', () async {
      final httpCache = await _createHttpCache();

      final request = http.Request('GET', Uri.parse('https://example.com'));
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer token';

      final cacheEntry = CacheEntry(
        cacheKey: 'cacheKey',
        reasonPhrase: 'OK',
        contentLength: 123,
        responseHeaders: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer token',
          'Accept': 'application/json',
        }.entries,
        varyHeaders: {
          'Authorization': 'Bearer token',
          'Accept': 'application/json',
        }.entries,
      );

      final result = httpCache.isMatchingCacheEntry(request, cacheEntry);
      expect(result, isTrue);
    });

    test('should return true when header names are in different cases', () async {
      final httpCache = await _createHttpCache();

      final request = http.Request('GET', Uri.parse('https://example.com'));
      request.headers['accept'] = 'application/json';
      request.headers['authorization'] = 'Bearer token';

      final cacheEntry = CacheEntry(
        cacheKey: 'cacheKey',
        reasonPhrase: 'OK',
        contentLength: 123,
        responseHeaders: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer token',
          'Accept': 'application/json',
        }.entries,
        varyHeaders: {
          'Authorization': 'Bearer token',
          'Accept': 'application/json',
        }.entries,
      );

      final result = httpCache.isMatchingCacheEntry(request, cacheEntry);
      expect(result, isTrue);
    });
  });

  group('checkCacheSizeAndClean', () {
    test('should clean cache when size exceeds limit', () async {
      const maxCacheSize = 10;
      final httpCache = HttpCache();
      await httpCache.initInMemory(maxCacheSize: maxCacheSize);

      // Add entries to the cache to exceed the size limit
      for (var i = 0; i < 10; i++) {
        final stream = Stream.value(utf8.encode('body $i'));
        final response = http.StreamedResponse(
          stream,
          200,
          request: http.Request('GET', Uri.parse('https://example.com/$i')),
        );
        await httpCache.addOrUpdateCacheEntryForResponse(response);
        await httpCache.addResponseToCache(response.secondaryCacheKey!, stream);
      }

      // Verify that the cache size is within the limit
      final cacheSize = httpCache.getCacheSize();
      expect(cacheSize, 6); // only one entry in cache, no space for more
      expect(cacheSize, lessThanOrEqualTo(maxCacheSize));
    });

    test('should not clean cache when size is within limit', () async {
      const maxCacheSize = 500;
      final httpCache = HttpCache();
      await httpCache.initInMemory(maxCacheSize: maxCacheSize);

      // Add entries to the cache within the size limit
      for (var i = 0; i < 10; i++) {
        final stream = Stream.value(utf8.encode('body $i'));
        final response = http.StreamedResponse(
          stream,
          200,
          request: http.Request('GET', Uri.parse('https://example.com/$i')),
        );
        await httpCache.addOrUpdateCacheEntryForResponse(response);
        await httpCache.addResponseToCache(response.secondaryCacheKey!, stream);
      }

      // Verify that the cache size is within the limit
      final cacheSize = httpCache.getCacheSize();
      expect(cacheSize, 60); // 10 entries in cache
      expect(cacheSize, lessThanOrEqualTo(maxCacheSize));
    });
  });
}

/// Creates and configures a [ShelfTestServer] for testing HTTP interactions.
///
/// Takes [callbacks] that returns a [shelf.Response] to be send when the server
/// receives a request.
///
/// Parameters:
/// - [callbacks]: A list of functions that return a [shelf.Response] to be
///   executed when the server receives a request.
///
/// The server is automatically closed during test teardown.
/// Uses [expectAsync1] to ensure the callback is called during testing.
///
/// Returns a [Future] that completes with the configured [ShelfTestServer].
Future<ShelfTestServer> _createTestServer(
  List<FutureOr<shelf.Response> Function(shelf.Request request)> callbacks,
) async {
  final server = await ShelfTestServer.create();
  addTearDown(server.close);
  for (final callback in callbacks) {
    server.handler.expect('GET', '/test', expectAsync1(callback));
  }
  return server;
}

/// Creates a [HttpClientProxy] with a [httpCache] interceptor.
///
/// The client is automatically closed during test teardown.
http.Client _createClient(HttpCache httpCache) {
  final client = HttpClientProxy(interceptors: [httpCache]);
  addTearDown(client.close);
  return client;
}

/// Creates a [HttpCache] instance.
///
/// The cache is automatically disposed during test teardown.
Future<HttpCache> _createHttpCache({bool isPrivate = true}) async {
  final cache = HttpCache();
  await cache.initInMemory(private: isPrivate);
  addTearDown(cache.dispose);
  return cache;
}

/// Extension on [ShelfTestServer] to provide a convenience method for creating the test URL.
extension _TestUrl on ShelfTestServer {
  /// Returns a [Uri] for the '/test' path on the test server.
  Uri get testUrl => url.replace(path: '/test');
}
