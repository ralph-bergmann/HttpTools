[![Status](https://img.shields.io/badge/Status-Work%20in%20Progress-yellow)](/)
> ⚠️ **Work in Progress:** This repository is under active development. Features
> may be incomplete or subject to change.

# HttpTools

HttpTools is a comprehensive suite of Dart and Flutter libraries designed to
enhance your HTTP request handling capabilities. This package includes tools for
logging, caching, and intercepting HTTP requests, making it easier to manage and
debug your network interactions.

Packages
http_logger: Logs HTTP requests and responses for easier debugging.
http_cache: Provides caching mechanisms for HTTP requests to improve
performance.
http_interceptor: Allows interception and manipulation of HTTP requests and
responses.

http_logger
The http_logger package provides an interceptor to log HTTP requests and
responses.

Example

```dart
import 'package:http/http.dart' as http;
import 'package:http_logger/http_logger.dart';
import 'package:http_interceptor/http_interceptor.dart';
import 'package:logging/logging.dart';

void main() {
  Logger.root.onRecord.listen((record) {
    print(record.message);
  });

  final client = HttpClientProxy(
    interceptors: [HttpLogger(level: Level.basic)],
  );

  client.get(
    Uri.parse('https://jsonplaceholder.typicode.com/posts/1'),
    headers: {
      HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
    },
  ).then((response) {
    print(response.body);
    client.close();
  });
}
```

http_cache
The http_cache package provides caching mechanisms to improve the performance of
your HTTP requests.

Example

```dart
import 'dart:io' hide Directory;
import 'package:http/http.dart' as http;
import 'package:http_cache/http_cache.dart';
import 'package:http_interceptor/http_interceptor.dart';
import 'package:logging/logging.dart';

void main() {
  HttpOverrides.global = _HttpOverrides();

  Logger.root.onRecord.listen((record) {
    print(record.message);
  });

  final cache = HttpCache.inMemory();

  http.runWithClient(
    _myDartApp,
        () =>
        HttpClientProxy(
          interceptors: [HttpCacheInterceptor(cache: cache)],
        ),
  );
}

Future<void> _myDartApp() async {
  final client = http.Client();
  final response = await client.get(
      Uri.parse('https://jsonplaceholder.typicode.com/posts/1'));
  print(response.body);
  client.close();
}
```

http_interceptor
The http_interceptor package allows you to intercept and manipulate HTTP
requests and responses.

Example

```dart
import 'package:http/http.dart' as http;
import 'package:http_interceptor/http_interceptor.dart';

class LoggingInterceptor extends HttpInterceptor {
  @override
  FutureOr<OnRequest> onRequest(RequestOptions requestOptions) {
    print('Request: ${requestOptions.method} ${requestOptions.url}');
    return OnRequest.next(requestOptions);
  }

  @override
  FutureOr<OnResponse> onResponse(http.Response response) {
    print('Response: ${response.statusCode}');
    return OnResponse.next(response);
  }

  @override
  FutureOr<OnError> onError(RequestOptions requestOptions, Object error) {
    print('Error: $error');
    return OnError.next(requestOptions, error);
  }
}

void main() {
  http.runWithClient(
    _myDartApp,
        () =>
        HttpClientProxy(
          interceptors: [LoggingInterceptor()],
        ),
  );
}

Future<void> _myDartApp() async {
  final client = http.Client();
  final response = await client.get(
      Uri.parse('https://jsonplaceholder.typicode.com/posts/1'));
  print(response.body);
  client.close();
}
```
