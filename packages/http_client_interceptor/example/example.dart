import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_client_interceptor/http_client_interceptor.dart';

/// This example demonstrates how to use the [HttpClientProxy] with a
/// [HttpInterceptor] to intercept HTTP requests.
///
/// The function [http.runWithClient] is used to set the [HttpClientProxy] as
/// the default client for HTTP calls. This setup allows us to inject custom
/// behavior into the HTTP request/response lifecycle.
///
/// The [HttpInterceptorWrapper] is configured to modify requests by adding
/// custom headers. This can be useful for scenarios such as adding
/// authentication tokens, logging request details, or modifying request headers
/// before the request is sent to the server.
///
/// The example fetches data from a public API and demonstrates how interceptors
/// can be used to modify the outgoing request.
void main() {
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
    final response = await client.get(
      Uri.parse('https://jsonplaceholder.typicode.com/posts/1'),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
      },
    );
    print('response: ${response.body}');
  } finally {
    // Always close the client after use to free up system resources
    // and avoid potential memory leaks.
    client.close();
  }
}

/// Creates an HTTP client configured with an interceptor.
///
/// This function returns an instance of [HttpClientProxy] configured with
/// a list of interceptors. In this example, a single [HttpInterceptorWrapper]
/// is used to add a custom header to every request.
http.Client _createHttpClient() => HttpClientProxy(
      interceptors: [
        HttpInterceptorWrapper(
          onRequest: (request) {
            request.headers['customHeader'] = 'customHeaderValue';
            return OnRequest.next(request);
          },
        ),
      ],
    );
