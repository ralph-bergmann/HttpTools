# HttpTools

A comprehensive collection of Dart and Flutter packages for HTTP request handling, providing intercepting, logging, and caching capabilities to enhance your network operations.

## 📦 Packages Overview

| Package | Version | Description |
|---------|---------|-------------|
| [`http_client_interceptor`](https://pub.dev/packages/http_client_interceptor) | [![pub package](https://img.shields.io/pub/v/http_client_interceptor.svg)](https://pub.dev/packages/http_client_interceptor) | Core HTTP interceptor framework |
| [`http_client_logger`](https://pub.dev/packages/http_client_logger) | [![pub package](https://img.shields.io/pub/v/http_client_logger.svg)](https://pub.dev/packages/http_client_logger) | Comprehensive HTTP request/response logging |
| [`http_client_cache`](https://pub.dev/packages/http_client_cache) | [![pub package](https://img.shields.io/pub/v/http_client_cache.svg)](https://pub.dev/packages/http_client_cache) | HTTP caching with disk/memory storage |

## 🚀 Quick Start

### Installation

Add any or all packages to your `pubspec.yaml`:

```yaml
dependencies:
  http_client_interceptor: ^1.0.1
  http_client_logger: ^1.1.2
  http_client_cache: ^1.0.3
```

### Basic Usage - All Features Combined

```dart
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_client_interceptor/http_client_interceptor.dart';
import 'package:http_client_logger/http_client_logger.dart';
import 'package:http_client_cache/http_client_cache.dart';
import 'package:logging/logging.dart' hide Level;

Future<void> main() async {
  // Enable logging to see what's happening
  Logger.root.onRecord.listen((record) {
    print('[${record.level.name}] ${record.message}');
  });

  // Initialize cache
  final cache = HttpCache();
  await cache.initInMemory(); // or initLocal(Directory) for persistent cache

  // Configure HTTP client with all interceptors
  await http.runWithClient(
    () async {
      final client = http.Client();
      
      // Make requests - they'll be logged and cached automatically
      final response1 = await client.get(
        Uri.parse('https://jsonplaceholder.typicode.com/posts/1')
      );
      print('First request: ${response1.statusCode}');
      
      // Second identical request will be served from cache
      final response2 = await client.get(
        Uri.parse('https://jsonplaceholder.typicode.com/posts/1')
      );
      print('Second request: ${response2.statusCode}');
      
      client.close();
    },
    () => HttpClientProxy(
      interceptors: [
        HttpLogger(level: Level.headers), // Log requests/responses
        cache, // Cache responses
      ],
    ),
  );
}
```

## 📋 Detailed Package Documentation

### http_client_interceptor

**Core HTTP interceptor framework** - Foundation for all other packages

**Key Features:**
- ✅ Intercept HTTP requests and responses
- ✅ Modify headers, body, and URLs
- ✅ Handle errors and retries
- ✅ Chain multiple interceptors
- ✅ Compatible with all popular HTTP packages

**Simple Custom Interceptor:**

```dart
import 'package:http_client_interceptor/http_client_interceptor.dart';

class AuthInterceptor extends HttpInterceptor {
  final String apiKey;
  AuthInterceptor(this.apiKey);

  @override
  FutureOr<OnRequest> onRequest(BaseRequest request) {
    // Add API key to all requests
    request.headers['Authorization'] = 'Bearer $apiKey';
    return OnRequest.next(request);
  }

  @override
  FutureOr<OnResponse> onResponse(StreamedResponse response) {
    print('Response: ${response.statusCode} for ${response.request?.url}');
    return OnResponse.next(response);
  }

  @override
  FutureOr<OnError> onError(BaseRequest request, Object error, StackTrace? stackTrace) {
    print('Request failed: ${request.url} - Error: $error');
    return OnError.next(request, error, stackTrace);
  }
}
```

### http_client_logger

**Comprehensive HTTP logging** - See exactly what your app is sending and receiving

**Key Features:**
- ✅ **Unique Request IDs** - Track concurrent requests easily
- ✅ **Multiple Log Levels** - `basic`, `headers`, `body` 
- ✅ **Smart Binary Detection** - Clean logs without garbage data
- ✅ **Production Ready** - Configurable for development vs production
- ✅ **Human Readable** - Clean, structured log format

**Log Output Examples:**
```
[a1b2c3d4] --> GET https://api.example.com/users/123
[a1b2c3d4]     authorization: Bearer ***
[a1b2c3d4]     content-type: application/json
[a1b2c3d4] --> END GET
[a1b2c3d4] <-- 200 OK (145ms)
[a1b2c3d4]     content-type: application/json
[a1b2c3d4]     {"id": 123, "name": "John Doe"}
[a1b2c3d4] <-- END
```

**Usage:**
```dart
import 'package:http_client_logger/http_client_logger.dart';
import 'package:logging/logging.dart' hide Level;

// Set up logging
Logger.root.onRecord.listen((record) => print(record.message));

// Configure logger
HttpClientProxy(
  interceptors: [
    HttpLogger(
      level: Level.body, // basic | headers | body
      logBodyContentTypes: {'application/json'}, // Only log JSON as text
    ),
  ],
)
```

### http_client_cache

**HTTP caching with disk/memory storage** - Improve performance and reduce network usage

**Key Features:**
- ✅ **RFC 7234 Compliant** - Standard HTTP caching behavior
- ✅ **Memory & Disk Storage** - Choose what fits your needs
- ✅ **Cache-Control Support** - Respects server cache directives
- ✅ **Stale-While-Revalidate** - Serve stale content while updating
- ✅ **Stale-If-Error** - Fallback to cache when network fails
- ✅ **Automatic Cleanup** - LRU eviction and size limits
- ✅ **Private Content Filtering** - Secure handling of sensitive data

**Cache Behavior Examples:**
```
Cache miss for https://api.example.com/posts/1      # First request
Cache hit for https://api.example.com/posts/1       # Served from cache
Cache entry expired for https://api.example.com/posts/1  # Needs refresh
Serving stale content due to network error           # Stale-if-error fallback
```

**Usage:**
```dart
import 'package:http_client_cache/http_client_cache.dart';

Future<void> setupCache() async {
  final cache = HttpCache();
  
  // Option 1: Memory cache (faster, doesn't persist)
  await cache.initInMemory(maxCacheSize: 50 * 1024 * 1024); // 50MB
  
  // Option 2: Disk cache (persists between app restarts)
  // final cacheDir = Directory('cache');
  // await cache.initLocal(cacheDir, maxCacheSize: 100 * 1024 * 1024);

  return HttpClientProxy(interceptors: [cache]);
}
```

## 🔧 Advanced Usage Patterns

### Conditional Interceptors
```dart
HttpClientProxy(
  interceptors: [
    if (kDebugMode) HttpLogger(level: Level.body), // Only log in debug
    AuthInterceptor(apiKey),
    cache,
  ],
)
```

### Custom Cache Control
```dart
class CacheControlInterceptor extends HttpInterceptor {
  @override
  FutureOr<OnResponse> onResponse(StreamedResponse response) {
    final headers = Map<String, String>.from(response.headers);
    
    // Cache API responses with resilience features
    if (response.request?.url.path.startsWith('/api/') ?? false) {
      headers['cache-control'] = 
        'max-age=300, stale-while-revalidate=60, stale-if-error=3600';
      // Cache for 5 min, serve stale for 1 min while revalidating,
      // serve stale for 1 hour if network fails
    }
    
    return OnResponse.next(response.copyWith(headers: headers));
  }
}
```

## 🔗 Framework Compatibility

Works seamlessly with popular HTTP packages:

- ✅ [`http`](https://pub.dev/packages/http) - A composable, multi-platform, Future-based API for HTTP requests.
- ✅ [`chopper`](https://pub.dev/packages/chopper) - An http client generator using source_gen, inspired by Retrofit 
- ✅ [`retrofit`](https://pub.dev/packages/retrofit) - An dio client generator using source_gen and inspired by Chopper and Retrofit
- ✅ [`dio`](https://pub.dev/packages/dio) - A powerful HTTP networking package

**Note:** `dio` and `retrofit` (which uses `dio`) require the [`dio_compatibility_layer`](https://pub.dev/packages/dio_compatibility_layer) package to work with the standard `http` package that these interceptors depend on.

```yaml
dependencies:
  http: ^1.2.0
  dio_compatibility_layer: ^3.0.0  # Required for dio/retrofit compatibility
```

## 📊 Performance Considerations

**Development vs Production:**
```dart
HttpClientProxy(
  interceptors: [
    // Production: Only basic logging
    if (kReleaseMode) HttpLogger(level: Level.basic),
    
    // Development: Full logging with bodies  
    if (kDebugMode) HttpLogger(level: Level.body),
    
    // Always cache for better performance
    cache,
  ],
)
```

**Memory Management:**
- Cache automatically manages size with LRU eviction
- Use `cache.clearCache()` when memory is low
- Use `cache.deletePrivateContent()` when user logs out

## 🐛 Debugging Tips

**Enable verbose logging:**
```dart
Logger.root.level = Level.ALL;
Logger.root.onRecord.listen((record) {
  print('[${record.time}] ${record.level.name}: ${record.message}');
  if (record.error != null) print('Error: ${record.error}');
  if (record.stackTrace != null) print('Stack: ${record.stackTrace}');
});
```

**Check cache status:**
```dart
// Look for Cache-Status headers in responses
final cacheStatus = response.headers['cache-status'];
print('Cache status: $cacheStatus');
```

## 🤝 Contributing

Found a bug or want to contribute? Check our [GitHub repository](https://github.com/ralph-bergmann/HttpTools) for:

- 🐛 [Bug Reports](https://github.com/ralph-bergmann/HttpTools/issues)
- 💡 [Feature Requests](https://github.com/ralph-bergmann/HttpTools/issues)
- 🔀 [Pull Requests](https://github.com/ralph-bergmann/HttpTools/pulls)

## 📄 License

This project is licensed under the MIT License - see individual package licenses for details.

---

**Need help?** Check out the individual package documentation or [open an issue](https://github.com/ralph-bergmann/HttpTools/issues) on GitHub!
```
