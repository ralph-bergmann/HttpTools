import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_client_interceptor/http_client_interceptor.dart';
import 'package:http_client_logger/http_client_logger.dart';
import 'package:http_client_logger/src/http_logger.dart';
import 'package:logging/logging.dart' hide Level;

/// This example demonstrates how to use the [HttpLogger] with the `http`
/// package to log HTTP requests and responses.
///
/// This example sets up a simple HTTP GET request to a public API and logs
/// the request and response using the [HttpLogger]. The logger is configured
/// to use a `basic` logging level, which includes essential information.
///
/// To run this example:
/// 1. Ensure you have the `http`, `http_logger`, and `logging`
///    packages in your `pubspec.yaml`.
/// 2. Run this Dart file from your command line or IDE.
void main() {
  // Set up logging to print to the console.
  Logger.root.onRecord.listen((record) {
    print(record.message);
  });

  unawaited(
    http.runWithClient(
      _myDartApp,
      _createHttpClient,
    ),
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
    await client.get(
      Uri.parse('https://jsonplaceholder.typicode.com/posts/1'),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
      },
    );
  } finally {
    // Always close the client after use to free up system resources
    // and avoid potential memory leaks.
    client.close();
  }
}

/// Creates an HTTP client configured with an interceptor to log all HTTP
/// transactions.
///
/// This function returns an instance of [HttpClientProxy] configured with
/// a [HttpLogger] interceptor. The logger is set to a `basic` level, ensuring
/// that essential details of each HTTP transaction are logged.
http.Client _createHttpClient() => HttpClientProxy(
      interceptors: [
        HttpLogger(level: Level.basic),
      ],
    );
