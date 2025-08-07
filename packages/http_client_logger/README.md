# http_client_logger

A flexible HTTP logging interceptor for Dart and Flutter applications that provides configurable logging levels for HTTP requests and responses.

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
