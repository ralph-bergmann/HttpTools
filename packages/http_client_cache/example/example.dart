import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_client_cache/http_client_cache.dart';
import 'package:http_client_interceptor/http_client_interceptor.dart';
import 'package:http_client_logger/http_client_logger.dart';
import 'package:logging/logging.dart' hide Level;
import 'package:mime/mime.dart';

Future<void> main() async {
  // HttpOverrides.global = _HttpOverrides();

  Logger.root.onRecord.listen((record) {
    print(record.message);
  });

  final cache = HttpCache();

  // create a cache instance which persists the cache entries on disk
  // final dir = Directory('cache');
  // await cache.initLocal(dir);

  // create a cache instance which persists the cache entries in memory
  await cache.initInMemory();

  await http.runWithClient(
    _myDartApp,
    () => _createHttpClient(cache),
  );
}

/// Simulates a Dart application making an HTTP GET request to a public API
/// endpoint.
///
/// This function performs a GET request to 'https://jsonplaceholder.typicode.com/posts/1'.
///
/// The HTTP client is created and closed again once the request has been
/// completed. This is important to free up system resources and avoid possible
/// memory leaks. Reusing the same client keeps the HTTP connection open.
/// In addition, `_createHttpClient` is not called again for every HTTP request.
Future<void> _myDartApp() async {
  // Instantiate a new HTTP client. This client will be configured to use
  // the interceptors defined in `http.runWithClient` if any are set up.
  final client = http.Client();

  try {
    await client.get(Uri.parse('https://jsonplaceholder.typicode.com/posts/1'));
    await client.get(Uri.parse('https://jsonplaceholder.typicode.com/posts/2'));
    await client.get(Uri.parse('https://jsonplaceholder.typicode.com/posts/1'));
    await client.get(Uri.parse('https://jsonplaceholder.typicode.com/posts/3'));
  } finally {
    // Always close the client after use to free up system resources
    // and avoid potential memory leaks.
    client.close();
  }
}

http.Client _createHttpClient(HttpCache cache) => HttpClientProxy(
      interceptors: [
        // The order of interceptors is important.
        // This logging interceptor logs the original request and response.
        HttpLogger(/* level: Level.headers */),
        _CacheControlInterceptor(),
        // This logging interceptor logs the modified request and response
        // after the [_CacheControlInterceptor] has modified the cache control
        // header.
        // HttpLogger(/* level: Level.headers */),
        cache,
      ],
    );

/// This interceptor modifies the cache control header of the response
/// depending on the request url and the response mime type.
class _CacheControlInterceptor extends HttpInterceptorWrapper {
  @override
  Future<OnResponse> onResponse(http.StreamedResponse response) async {
    late final CacheControl cacheControl;

    if (response.request?.url.pathSegments.last == '/login') {
      // This is a login request, so we don't want to cache the response.
      cacheControl = CacheControl.sensitiveContent();
    } else if (extensionFromMime(response.headers[HttpHeaders.cacheControlHeader]!) == 'jpg') {
      // This is a jpg image, so we want to cache the response for a long time
      // and for all users (shared content).
      //
      // Note: in production, you should test if there is a cache control header
      // and don't force it with the postfix null assertion "bang" operator (!)
      cacheControl = CacheControl.sharedContent(
        maxAge: const Duration(days: 1),
        staleWhileRevalidate: const Duration(hours: 12),
        staleIfError: const Duration(days: 2),
      );
    } else {
      // This is a regular request, so we want to cache the response for a short
      // time and only for the current user (private content).
      // You should prune the cache with [HttpCache.deletePrivateContent()]
      // after the user has logged out.
      cacheControl = CacheControl.privateContent(
        maxAge: const Duration(seconds: 60),
        staleWhileRevalidate: const Duration(seconds: 30),
        staleIfError: const Duration(seconds: 300),
      );
    }

    // Create new headers map with the updated cache control
    final newHeaders = Map<String, String>.from(response.headers);
    newHeaders[HttpHeaders.cacheControlHeader] = cacheControl.toString();

    return OnResponse.next(response.copyWith(headers: newHeaders));
  }
}

// HttpOverrides to see the http(s) traffic in debug proxies like Charles Proxy
// ignore: unused_element
class _HttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback = (_, __, ___) => true;

  @override
  String findProxyFromEnvironment(_, __) => 'PROXY 10.0.1.1:8888;';
}
