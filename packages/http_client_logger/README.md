# http_client_logger

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
          HttpLogger(),
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
import 'package:http_client_interceptor/http_client_interceptor.dart';
import 'package:http_client_logger/http_client_logger.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  // Set up logging to print to the console.
  Logger.root.onRecord.listen((record) {
    print(record.message);
  });

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
      () {
        runApp(const MyApp());
      },
      () => HttpClientProxy(
        interceptors: [
          HttpLogger(),
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
