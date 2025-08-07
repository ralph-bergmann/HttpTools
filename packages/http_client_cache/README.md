# http_client_cache

The [`http_client_cache`](https://pub.dev/packages/http_client_cache) package provides
a simple and efficient way to cache HTTP responses in Dart and Flutter applications. It allows you to store and retrieve cached responses, reducing the need for redundant network requests and improving the performance of your application.

## Installation

### For Dart

Run the following command:

```sh
dart pub add http_client_cache
```

### For Flutter

Run the following command:
```sh
flutter pub add http_client_cache

```
## Usage

To use the `http_client_cache` package, you need to create an instance of `HttpClientProxy` and use it with your HTTP client. Here's a basic example:

```dart
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http_client_cache/http_client_cache.dart';
import 'package:http_client_interceptor/http_client_interceptor.dart';

Future<void> main() async {
  final cache = HttpCache();

  // create a cache instance which persists the cache entries on disk
  // final dir = Directory('cache');
  // await cache.initLocal(dir);

  // create a cache instance which persists the cache entries in memory
  await cache.initInMemory();

  unawaited(
    http.runWithClient(
      _myDartApp,
      () => HttpClientProxy(
        interceptors: [
          cache,
        ],
      ),
    ),
  );
}

Future<void> _myDartApp() async {
  final client = http.Client();
  final response = await client.get(Uri.parse('https://api.example.com/data'));
  print(response.body);
}
```

### For Flutter

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_client_cache/http_client_cache.dart';
import 'package:http_client_interceptor/http_client_interceptor.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  // the HttpCache interceptor
  late final HttpCache httpCache;

  unawaited(
    // Create a new [HttpClientProxy] with the [HttpCache] interceptor
    // and make it the default [http.Client] for the [http.Client.new] factory method.
    //
    // A better way may be to create the [http.Client] and inject it where it is needed, 
    // instead of running your application with [runWithClient].
    //
    // For better performance, reuse the same [http.Client] for multiple http requests. So that
    // open connections are reused.
    http.runWithClient(
      () async {
        // needed for getApplicationCacheDirectory
        WidgetsFlutterBinding.ensureInitialized();

        // we need to init the cache in the runWithClient callback
        // because the runWithClient callback creates a new Zone
        // and we need to init the cache in the same zone.
        httpCache = HttpCache();
        final cacheDirectory = await getApplicationCacheDirectory();
        await httpCache.initLocal(cacheDirectory);

        runApp(const MyApp());
      },
      () => HttpClientProxy(
        interceptors: [
          httpCache,
        ],
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // add your code here
  }
}
```

## Advanced Usage

You can also use a `HttpInterceptorWrapper` to customize the `cache-control` header for specific requests.

```dart
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_client_cache/http_client_cache.dart';
import 'package:http_client_interceptor/http_client_interceptor.dart';

Future<void> main() async {
  final cache = HttpCache();

  // create a cache instance which persists the cache entries on disk
  // final dir = Directory('cache');
  // await cache.initLocal(dir);

  // create a cache instance which persists the cache entries in memory
  await cache.initInMemory();

  unawaited(
    http.runWithClient(
      _myDartApp,
      () => HttpClientProxy(
        interceptors: [
          _CacheControlInterceptor(),
          cache,
        ],
      ),
    ),
  );
}

Future<void> _myDartApp() async {
  final client = http.Client();
  final response = await client.get(Uri.parse('https://api.example.com/data'));
  print(response.body);
}

class _CacheControlInterceptor extends HttpInterceptorWrapper {
  @override
  Future<OnResponse> onResponse(http.StreamedResponse response) async {
    final cacheControlHeader = response.headers[HttpHeaders.cacheControlHeader];
    if (cacheControlHeader == null) {
      return OnResponse.next(response);
    }

    // Add/override the cache control max-age parameter to cache the response.
    // In production, there should be some logic to having different caching
    // strategies for different content/mime types and/or urls.
    final cacheControl = CacheControl.dynamicContent(
      maxAge: const Duration(seconds: 60),
      staleWhileRevalidate: const Duration(seconds: 30),
      staleIfError: const Duration(seconds: 300),
    );

    // Create new headers map with the updated cache control
    final newHeaders = Map<String, String>.from(response.headers);
    newHeaders[HttpHeaders.cacheControlHeader] = cacheControl.toString();

    return OnResponse.next(response.copyWith(headers: newHeaders));
  }
}
```

## Debugging

The cache provides detailed logging to help you understand cache behavior. To enable logging, set up a logger listener:

```dart
import 'package:logging/logging.dart';

void main() {
  // Enable cache logging
  Logger.root.onRecord.listen((record) {
    print('[${record.level.name}] ${record.loggerName}: ${record.message}');
  });
  
  // Your cache setup...
}
```

**Example log messages:**
- `Cache hit for https://api.example.com/data` - Request served from cache
- `Cache miss for https://api.example.com/data` - No cached response found
- `Cache entry expired for https://api.example.com/data` - Cached response is stale
- `Skipping cache for private response: https://api.example.com/data` - Private content not cached
- `Skipping cache due to no-store directive: https://api.example.com/data` - Server forbids caching
- `Skipping cache due to Vary: * header: https://api.example.com/data` - Response varies by all headers

**Tip:** Use logging levels to control verbosity:
```dart
Logger.root.level = Level.INFO; // Show cache hits/misses
Logger.root.level = Level.WARNING; // Show only errors
```

## Compatibility

See [`http_client_interceptor`](https://pub.dev/packages/http_client_interceptor) 
for how to use this package with popular Dart [http](https://pub.dev/packages/http) packages, 
like [Chopper](https://pub.dev/packages/chopper), [Dio](https://pub.dev/packages/dio_compa fotibility_layer), [Retrofit](https://pub.dev/packages/retrofit), [http_image_provider](https://pub.dev/packages/http_image_provider) 
and other [`http` comppatible packages](https://pub.dev/packages/http#choosing-an-implementation).


## Update protobuf Dart files

- Install protobuf `brew install protobuf`
- Install Dart lib `dart pub global activate protoc_plugin`
- In `http_client_cache/lib/src/journal` call `protoc --dart_out=. journal.proto timestamp.proto`

