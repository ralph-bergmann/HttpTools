import 'dart:async';
import 'dart:convert';

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
    late HttpCache httpCache;

    setUp(() async {
      httpCache = HttpCache();
      await httpCache.initInMemory();
    });

    test('getCacheEntryForRequest returns null if no entry exists', () {
      final request = http.Request('GET', Uri.parse('https://example.com'));
      final cacheEntry = httpCache.getCacheEntryForRequest(request);
      expect(cacheEntry, isNull);
    });

    test('getCachedResponse returns null if no entry exists', () {
      final request = http.Request('GET', Uri.parse('https://example.com'));
      final cachedResponse = httpCache.getCachedResponse(request);
      expect(cachedResponse, isNull);
    });

    test('add a new cache entry', () async {
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
      // inital cached response
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
    late HttpCache httpCache;
    late ShelfTestServer server;

    setUp(() async {
      server = await ShelfTestServer.create();
    });

    tearDown(() async {
      await server.close();
    });

    void runCacheControlTests(bool isPrivate) {
      setUp(() async {
        httpCache = HttpCache();
        await httpCache.initInMemory(private: isPrivate);
      });

      test('no-store directive prevents caching', () async {
        server.handler.expect(
          'GET',
          '/no-store',
          (request) => shelf.Response.ok(
            'body',
            headers: {'cache-control': 'no-store'},
          ),
        );

        final client = HttpClientProxy(
          innerClient: http.Client(),
          interceptors: [httpCache],
        );
        final response =
            await client.get(server.url.replace(path: '/no-store'));

        expect(response.body, 'body');
        final cacheEntry = httpCache.getCacheEntryForRequest(response.request!);
        expect(cacheEntry, isNull);
      });

      test('private directive is respected', () async {
        server.handler.expect(
          'GET',
          '/private',
          (request) => shelf.Response.ok(
            'body',
            headers: {'cache-control': 'private'},
          ),
        );

        final client = HttpClientProxy(
          innerClient: http.Client(),
          interceptors: [httpCache],
        );
        final response = await client.get(server.url.replace(path: '/private'));

        expect(response.body, 'body');
        final cacheEntry = httpCache.getCacheEntryForRequest(response.request!);
        if (isPrivate) {
          expect(cacheEntry, isNotNull);
          expect(cacheEntry!.isPrivate, isTrue);
        } else {
          expect(cacheEntry, isNull);
        }
      });

      Future<void> testRevalidation(
        String path,
        String cacheControlHeader,
      ) async {
        var requestCount = 0;
        final timestamp = DateTime.now().toIso8601String();

        server.handler.expect('GET', path, (request) {
          requestCount++;
          return shelf.Response.ok(
            'body',
            headers: {
              'cache-control': cacheControlHeader,
              'x-timestamp': timestamp,
            },
          );
        });
        server.handler.expect('GET', path, (request) {
          requestCount++;
          return shelf.Response.ok(
            'body',
            headers: {
              'cache-control': cacheControlHeader,
              'x-timestamp': timestamp,
            },
          );
        });
        final client = HttpClientProxy(
          innerClient: http.Client(),
          interceptors: [httpCache],
        );
        final response1 = await client.get(server.url.replace(path: path));
        expect(response1.body, 'body');
        expect(response1.headers['x-timestamp'], timestamp);

        final cacheEntry =
            httpCache.getCacheEntryForRequest(response1.request!);
        expect(cacheEntry, isNotNull);

        // Make the request again to trigger revalidation.
        // This second request should cause the cache to revalidate the entry
        // by making another request to the server. The server request count
        // should be incremented to 2, indicating that revalidation occurred.
        // The response of the second request should be equal to the response
        // from the first request because it comes from the cache.
        final response2 = await client.get(server.url.replace(path: path));
        expect(response2.body, 'body');
        expect(response2.headers['x-timestamp'], timestamp);
        expect(requestCount, 2);
      }

      test('no-cache directive requires revalidation', () async {
        await testRevalidation('/no-cache', 'no-cache');
      });

      test('must-revalidate requires revalidation', () async {
        await testRevalidation('/must-revalidate', 'must-revalidate');
      });

      test('stale-while-revalidate directive is handled', () async {
        server.handler.expect(
          'GET',
          '/stale-while-revalidate',
          (request) => shelf.Response.ok(
            'body',
            headers: {'cache-control': 'max-age=0, stale-while-revalidate=60'},
          ),
        );

        final client = HttpClientProxy(
          innerClient: http.Client(),
          interceptors: [httpCache],
        );
        final response = await client
            .get(server.url.replace(path: '/stale-while-revalidate'));

        expect(response.body, 'body');
        final cacheEntry = httpCache.getCacheEntryForRequest(response.request!);
        expect(cacheEntry, isNotNull);
        expect(cacheEntry!.isStaleWhileRevalidate, isTrue);
      });

      test('stale-if-error directive is handled', () async {
        // Step 1: Set up the server to handle the initial request
        server.handler.expect(
          'GET',
          '/stale-if-error',
          (request) => shelf.Response.ok(
            'body',
            headers: {'cache-control': 'max-age=0, stale-if-error=60'},
          ),
        );

        final client = HttpClientProxy(
          innerClient: http.Client(),
          interceptors: [httpCache],
        );

        final url = server.url.replace(path: '/stale-if-error');

        // Step 2: Make the initial request to cache the response
        final response1 = await client.get(url);
        expect(response1.body, 'body');

        // Verify that the cache entry exists
        final cacheEntry =
            httpCache.getCacheEntryForRequest(response1.request!);
        expect(cacheEntry, isNotNull);

        // Step 3: Shut down the server to simulate an error
        await server.close();

        // Step 4: Make the request again to trigger the stale-if-error behavior
        final response2 = await client.get(url);
        expect(response2.body, 'body');

        // Verify that the response is served from the cache
        final cacheStatusHeader = response2.headers[CacheStatus.headerName];
        expect(cacheStatusHeader, isNotNull);

        final cacheStatus = CacheStatus.fromHeader(cacheStatusHeader!);
        expect(cacheStatus.hit, isTrue);
      });

      Future<void> testRevalidationFailure(
        String path,
        String cacheControlHeader,
      ) async {
        var requestCount = 0;
        final initialTimestamp = DateTime.now().toIso8601String();
        final updatedTimestamp =
            DateTime.now().add(const Duration(seconds: 1)).toIso8601String();
        server.handler.expect('GET', path, (request) {
          requestCount++;

          return shelf.Response.ok(
            'body',
            headers: {
              'cache-control': cacheControlHeader,
              'x-timestamp': initialTimestamp,
            },
          );
        });
        server.handler.expect('GET', path, (request) {
          requestCount++;

          return shelf.Response.ok(
            'body',
            headers: {
              'cache-control': cacheControlHeader,
              'x-timestamp': updatedTimestamp,
            },
          );
        });

        final client = HttpClientProxy(
          innerClient: http.Client(),
          interceptors: [httpCache],
        );
        final response1 = await client.get(server.url.replace(path: path));
        expect(response1.body, 'body');
        expect(response1.headers['x-timestamp'], initialTimestamp);

        final cacheEntry =
            httpCache.getCacheEntryForRequest(response1.request!);
        expect(cacheEntry, isNotNull);

        // Make the request again to trigger revalidation.
        // This second request should cause the cache to revalidate the entry
        // by making another request to the server. The server request count
        // should be incremented to 2, indicating that revalidation occurred.
        // The response of the second request should have a different timestamp
        // indicating that it is not served by the cache.
        final response2 = await client.get(server.url.replace(path: path));
        expect(response2.body, 'body');
        expect(requestCount, 2);
        expect(response2.headers['x-timestamp'], updatedTimestamp);
      }

      test('no-cache directive revalidation failure', () async {
        await testRevalidationFailure('/no-cache-failure', 'no-cache');
      });

      test('must-revalidate revalidation failure', () async {
        await testRevalidationFailure(
          '/must-revalidate-failure',
          'must-revalidate',
        );
      });

      test('max-age directive expires cache entry', () async {
        var requestCount = 0;
        final initialTimestamp = DateTime.now().toIso8601String();
        final updatedTimestamp =
            DateTime.now().add(const Duration(seconds: 2)).toIso8601String();

        server.handler.expect('GET', '/max-age', (request) {
          requestCount++;
          return shelf.Response.ok(
            'body',
            headers: {
              'cache-control': 'max-age=1',
              'x-timestamp':
                  requestCount == 1 ? initialTimestamp : updatedTimestamp,
            },
          );
        });
        server.handler.expect('GET', '/max-age', (request) {
          requestCount++;
          return shelf.Response.ok(
            'body',
            headers: {
              'cache-control': 'max-age=1',
              'x-timestamp':
                  requestCount == 1 ? initialTimestamp : updatedTimestamp,
            },
          );
        });

        final client = HttpClientProxy(
          innerClient: http.Client(),
          interceptors: [httpCache],
        );
        final response1 =
            await client.get(server.url.replace(path: '/max-age'));
        expect(response1.body, 'body');
        expect(response1.headers['x-timestamp'], initialTimestamp);

        final cacheEntry =
            httpCache.getCacheEntryForRequest(response1.request!);
        expect(cacheEntry, isNotNull);

        // Wait for the cache entry to expire
        await Future.delayed(const Duration(seconds: 2));

        // Make the request again to ensure the cache entry has expired
        final response2 =
            await client.get(server.url.replace(path: '/max-age'));
        expect(response2.body, 'body');
        expect(response2.headers['x-timestamp'], updatedTimestamp);
      });

      test('Vary header is respected', () async {
        server.handler.expect('GET', '/vary', (request) {
          final userAgent = request.headers['user-agent'] ?? '';
          return shelf.Response.ok(
            'body',
            headers: {
              'cache-control': 'public, max-age=60',
              'vary': 'User-Agent',
              'x-user-agent': userAgent,
            },
          );
        });
        server.handler.expect('GET', '/vary', (request) {
          final userAgent = request.headers['user-agent'] ?? '';
          return shelf.Response.ok(
            'body',
            headers: {
              'cache-control': 'public, max-age=60',
              'vary': 'User-Agent',
              'x-user-agent': userAgent,
            },
          );
        });

        final client = HttpClientProxy(
          innerClient: http.Client(),
          interceptors: [httpCache],
        );
        final response1 = await client.get(
          server.url.replace(path: '/vary'),
          headers: {'User-Agent': 'TestAgent1'},
        );
        expect(response1.body, 'body');
        expect(response1.headers['x-user-agent'], 'TestAgent1');

        // The Vary header indicates that the response varies based on the
        // User-Agent header. Therefore, the cache should store separate
        // responses for different User-Agent values. The second response
        // should be different from the first response because it has a
        // different User-Agent.
        final response2 = await client.get(
          server.url.replace(path: '/vary'),
          headers: {'User-Agent': 'TestAgent2'},
        );
        expect(response2.body, 'body');
        expect(response2.headers['x-user-agent'], 'TestAgent2');
      });

      Future<void> testCacheInvalidation(String method, String path) async {
        server.handler.expect(
          'GET',
          path,
          (request) => shelf.Response.ok(
            'body',
            headers: {'cache-control': 'max-age=60'},
          ),
        );

        server.handler.expect(
          method,
          path,
          (request) => shelf.Response.ok('updated body'),
        );

        server.handler.expect(
          'GET',
          path,
          (request) => shelf.Response.ok(
            'updated body',
            headers: {'cache-control': 'max-age=60'},
          ),
        );

        final client = HttpClientProxy(
          innerClient: http.Client(),
          interceptors: [httpCache],
        );
        final response1 = await client.get(server.url.replace(path: path));
        expect(response1.body, 'body');

        final cacheEntry =
            httpCache.getCacheEntryForRequest(response1.request!);
        expect(cacheEntry, isNotNull);

        // Invalidate the cache entry with the specified request method
        if (method == 'PUT' ||
            method == 'DELETE' ||
            method == 'POST' ||
            method == 'PATCH') {
          await client.send(
            http.Request(method, server.url.replace(path: path))
              ..body = 'new data',
          );
        } else {
          await client
              .send(http.Request(method, server.url.replace(path: path)));
        }

        // Make the request again to ensure the cache entry has been invalidated
        final response2 = await client.get(server.url.replace(path: path));
        expect(response2.body, 'updated body');
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
    }

    group('with private cache', () {
      runCacheControlTests(true);
    });

    group('with non-private cache', () {
      runCacheControlTests(false);
    });
  });

  group('isMatchingCacheEntry', () {
    late HttpCache httpCache;

    setUp(() {
      httpCache = HttpCache();
    });

    test('should return true when vary headers match', () {
      final request = http.Request('GET', Uri.parse('https://example.com'));
      request.headers['Accept'] = 'application/json';

      final cacheEntry = CacheEntry(
        cacheKey: 'cacheKey',
        reasonPhrase: 'OK',
        contentLength: 123,
        responseHeaders: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        varyHeaders: {'Accept': 'application/json'},
      );

      final result = httpCache.isMatchingCacheEntry(request, cacheEntry);
      expect(result, isTrue);
    });

    test('should return false when vary headers do not match', () {
      final request = http.Request('GET', Uri.parse('https://example.com'));
      request.headers['Accept'] = 'application/xml';

      final cacheEntry = CacheEntry(
        cacheKey: 'cacheKey',
        reasonPhrase: 'OK',
        contentLength: 123,
        responseHeaders: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        varyHeaders: {'Accept': 'application/json'},
      );

      final result = httpCache.isMatchingCacheEntry(request, cacheEntry);
      expect(result, isFalse);
    });

    test('should return true when there are no vary headers', () {
      final request = http.Request('GET', Uri.parse('https://example.com'));

      final cacheEntry = CacheEntry(
        cacheKey: 'cacheKey',
        reasonPhrase: 'OK',
        contentLength: 123,
        responseHeaders: {'Content-Type': 'application/json'},
        varyHeaders: {},
      );

      final result = httpCache.isMatchingCacheEntry(request, cacheEntry);
      expect(result, isTrue);
    });

    test('should return true when request has more headers than vary headers',
        () {
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
        },
        varyHeaders: {'Accept': 'application/json'},
      );

      final result = httpCache.isMatchingCacheEntry(request, cacheEntry);
      expect(result, isTrue);
    });

    test('should return false when vary headers have more headers than request',
        () {
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
        },
        varyHeaders: {
          'Accept': 'application/json',
          'Authorization': 'Bearer token',
        },
      );

      final result = httpCache.isMatchingCacheEntry(request, cacheEntry);
      expect(result, isFalse);
    });

    test('should return true when headers are in different order', () {
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
        },
        varyHeaders: {
          'Authorization': 'Bearer token',
          'Accept': 'application/json',
        },
      );

      final result = httpCache.isMatchingCacheEntry(request, cacheEntry);
      expect(result, isTrue);
    });

    test('should return true when header names are in different cases', () {
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
        },
        varyHeaders: {
          'Authorization': 'Bearer token',
          'Accept': 'application/json',
        },
      );

      final result = httpCache.isMatchingCacheEntry(request, cacheEntry);
      expect(result, isTrue);
    });
  });

  group('invalidateCacheForRequest', () {
    late HttpCache httpCache;

    setUp(() async {
      // Initialize the HttpCache with in-memory storage
      httpCache = HttpCache();
      await httpCache.initInMemory();
    });

    test('should invalidate cache for a given request', () async {
      // Create a dummy request and response
      final request = Request('GET', Uri.parse('https://example.com/data'));
      final response = StreamedResponse(
        Stream.value([1, 2, 3]),
        200,
        request: request,
        headers: {'cache-control': 'max-age=3600'},
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
      // Create a dummy request
      final request =
          Request('GET', Uri.parse('https://example.com/nonexistent'));

      // Invalidate the cache for the request
      await httpCache.invalidateCacheForRequest(request);

      // Verify that no exception is thrown and the cache remains empty
      expect(httpCache.getCachedResponse(request), isNull);
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
