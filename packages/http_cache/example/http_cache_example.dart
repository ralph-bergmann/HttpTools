import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_cache/http_cache.dart';
import 'package:http_cache/src/cache_status.dart';
import 'package:http_intercept/http_intercept.dart';
import 'package:http_logger/http_logger.dart';
import 'package:logging/logging.dart' hide Level;

Future<void> main() async {
  // HttpOverrides.global = _HttpOverrides();

  Logger.root.onRecord.listen((record) {
    print(record.message);
  });

  final cache = HttpCache();

  // final dir = Directory('cache');
  // await cache.initLocal(dir);

  await cache.initInMemory();

  await http.runWithClient(
    _myDartApp,
    () => _createHttpClient(cache),
  );
}

/// Simulates a Dart application making an HTTP GET request to a public API
/// endpoint.
///
/// This function performs a GET request to 'https://jsonplaceholder.typicode.com/posts/1',
/// including a content type header that specifies JSON as the expected response
/// format.
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
    var response = await client.get(
      Uri.parse('https://jsonplaceholder.typicode.com/posts/1'),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
      },
    );
    //print('response 1: ${response.body}');
    print('response 1: ${response.headers[CacheStatus.headerName]}');

    response = await client.get(
      Uri.parse('https://jsonplaceholder.typicode.com/posts/2'),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
      },
    );
    //print('response 2: ${response.body}');
    print('response 2: ${response.headers[CacheStatus.headerName]}');

    response = await client.get(
      Uri.parse('https://jsonplaceholder.typicode.com/posts/1'),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
      },
    );
    //print('response 3: ${response.body}');
    print('response 3: ${response.headers[CacheStatus.headerName]}');

    response = await client.get(
      Uri.parse('https://jsonplaceholder.typicode.com/posts/3'),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
      },
    );
    //print('response 4: ${response.body}');
    print('response 4: ${response.headers[CacheStatus.headerName]}');
  } finally {
    // Always close the client after use to free up system resources
    // and avoid potential memory leaks.
    client.close();
  }
}

http.Client _createHttpClient(HttpCache cache) => HttpClientProxy(
      interceptors: [
        HttpLogger(),
        cache,
      ],
    );

// HttpOverrides to see the http(s) traffic in Charles Proxy.
// ignore: unused_element
class _HttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback = (_, __, ___) => true;

  @override
  String findProxyFromEnvironment(_, __) => 'PROXY 10.0.1.1:8888;';
}
