import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_compatibility_layer/dio_compatibility_layer.dart';
import 'package:http_client_interceptor/http_client_interceptor.dart';

Future<void> main() async {
  // Create an instance of [HttpClientProxy] with interceptors.
  final httpClient = HttpClientProxy(
    interceptors: [
      HttpInterceptorWrapper(
        onRequest: (request) {
          // Add a custom header to the request.
          request.headers['customHeader'] = 'customHeaderValue';
          return OnRequest.next(request);
        },
      ),
    ],
  );

  // Create a [ConversionLayerAdapter] using the [HttpClientProxy].
  // This adapter allows [Dio] to use the HTTP client from the `http` package
  // instead of its default HTTP client.
  final dioAdapter = ConversionLayerAdapter(httpClient);

  // Instantiate Dio and configure it to use the custom HTTP client adapter.
  final dio = Dio()..httpClientAdapter = dioAdapter;

  // Make a GET request.
  final response = await dio.get(
    'https://jsonplaceholder.typicode.com/posts/1',
  );

  // Close the Dio instance.
  // Calling close is important to free up resources and avoid potential
  // memory leaks.
  dio.close();

  // Print the response.
  print(response);
}
