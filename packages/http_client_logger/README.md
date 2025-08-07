# http_client_logger

A flexible HTTP logging interceptor for Dart and Flutter applications that provides configurable logging levels for HTTP requests and responses. Features unique request ID tracking for easy debugging of concurrent requests.

## Performance Considerations

⚠️ **Important:** Different logging levels have varying performance impacts:

- `Level.basic` and `Level.headers` - Minimal performance overhead
- `Level.body` - **Significant performance impact** as it reads and processes the entire request/response body content

**Recommendation:** Use `Level.body` only during development and debugging. Avoid using it in production environments where performance is critical.

## Installation

### For Dart

Run the following command:

```sh
dart pub add http_client_logger
```

### For Flutter

Run the following command:
```sh
flutter pub add http_client_logger

```

## Usage

To use the `http_client_logger` package, you need to create an instance of `HttpClientProxy` and use it with your HTTP client. Here's a basic example:

```dart
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_client_interceptor/http_client_interceptor.dart';
import 'package:http_client_logger/http_client_logger.dart';
import 'package:logging/logging.dart' hide Level;

Future<void> main() async {
  // Set up logging to print to the console.
  Logger.root.onRecord.listen((record) {
    print(record.message);
  });

  unawaited(
    http.runWithClient(
      _myDartApp,
      () => HttpClientProxy(
        interceptors: [
          // Use Level.basic for production, Level.body for debugging only
          HttpLogger(level: Level.headers), // or Level.body for full logging
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

### Logging Levels

The `HttpLogger` supports different logging levels:

- `Level.none` - No logging
- `Level.basic` - Request method, URL, status code, and timing
- `Level.headers` - Basic info + request/response headers  
- `Level.body` - Headers info + complete request/response bodies ⚠️ **Performance Impact**

### Example with different levels:

```dart
// For production - minimal logging
HttpLogger(level: Level.basic)

// For development - includes headers
HttpLogger(level: Level.headers) 

// For debugging only - includes bodies (slow!)
HttpLogger(level: Level.body)
```

### Binary Content Filtering

When using `Level.body`, the logger intelligently handles binary content to avoid cluttering logs with unreadable data:

```dart
HttpLogger(
  level: Level.body,
  logBodyContentTypes: {'application/json', 'text/plain'}, // Only log these as text
)
```

**Binary content is displayed with:**
- **MIME type** - Shows the actual content type 
- **Human-readable size** - Automatically formats as bytes, KB, or MB

**Example outputs:**
```
[a1b2c3d4]     <binary content of image/jpeg with a length of 833 bytes>
[a1b2c3d4]     <binary content of image/png with a length of 1.5KB>  
[a1b2c3d4]     <binary content of video/mp4 with a length of 2.3MB>
```

**Default text content types include:**
- `application/json`, `application/xml`
- `text/plain`, `text/html`, `text/css`
- `application/javascript`, `text/javascript`
- `application/x-www-form-urlencoded`

### Log Output Format

The logger provides clean, structured output with unique request IDs to track individual requests:

```
[a1b2c3d4] --> GET https://api.example.com/data
[a1b2c3d4]     authorization: Bearer token...
[a1b2c3d4]     content-type: application/json
[a1b2c3d4]     <empty request body>
[a1b2c3d4] --> END GET
[a1b2c3d4] <-- 200 OK (150ms)
[a1b2c3d4]     content-type: application/json
[a1b2c3d4]     content-length: 1234
[a1b2c3d4]     {"data": "response content"}
[a1b2c3d4] <-- END
```

**Features:**
- 🆔 **Unique Request IDs**: Each request gets a unique 8-character ID for easy tracking
- 🔗 **Consistent Tracking**: Same ID appears in HTTP headers (`x-request-id`) and logs
- 📝 **Clear Structure**: Request/response boundaries with `-->` and `<--` markers
- 🧵 **Concurrent Support**: Easy to follow multiple simultaneous requests

### For Flutter

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_client_interceptor/http_client_interceptor.dart';
import 'package:http_client_logger/http_client_logger.dart';
import 'package:logging/logging.dart' hide Level;

void main() {
  // Set up logging to print to the console.
  Logger.root.onRecord.listen((record) {
    print(record.message);
  });

  unawaited(
    // Create a new [HttpClientProxy] with the [HttpLogger] interceptor
    // and make it the default [http.Client] for the [http.Client.new] factory method.
    //
    // A better way may be to create the [http.Client] and inject it where it is needed, 
    // instead of running your application with [runWithClient].
    //
    // For better performance, reuse the same [http.Client] for multiple http requests. So that
    // open connections are reused.
    http.runWithClient(
      () {
        runApp(const MyApp());
      },
      () => HttpClientProxy(
        interceptors: [
          // Use appropriate level based on environment
          HttpLogger(level: Level.headers), // Avoid Level.body in production
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
