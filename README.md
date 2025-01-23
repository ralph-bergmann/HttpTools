# HttpTools

HttpTools provides a collection of Dart and Flutter libraries for HTTP request handling. 
The packages offer logging, caching, and intercepting capabilities to help developers 
work effectively with network requests.

## Packages
 
### http_client_interceptor

The [http_client_interceptor](https://pub.dev/packages/http_client_interceptor) package allows you to intercept and manipulate HTTP
requests and responses.

```dart
import 'package:http/http.dart' as http;
import 'package:http_client_interceptor/http_interceptor.dart';

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

### http_client_logger

The [http_client_logger](https://pub.dev/packages/http_client_logger) package provides an interceptor to log HTTP requests and
responses.

```dart
import 'package:http/http.dart' as http;
import 'package:http_client_logger/http_client_logger.dart';
import 'package:http_client_interceptor/http_interceptor.dart';
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

### http_client_cache

The [http_client_cache](https://pub.dev/packages/http_client_cache) package provides caching mechanisms to improve the performance of
your HTTP requests.

```dart
import 'dart:io' hide Directory;
import 'package:http/http.dart' as http;
import 'package:http_client_cache/http_client_cache.dart';
import 'package:http_client_interceptor/http_interceptor.dart';
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
