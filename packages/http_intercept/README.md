# http_intercept

The [`http_intercept`](https://pub.dev/packages/http_intercept) package provides
a flexible and easy-to-use way to intercept and manipulate HTTP requests and
responses in Dart and Flutter applications. It allows you to add custom behavior
such as logging, authentication, and error handling to your HTTP requests.

## Installation

### For Dart

Run the following command:

```sh
dart pub add http_intercept
```

### For Flutter

Run the following command:

```sh
flutter pub add http_intercept
```

## Usage

To use the `http_intercept` package, you need to create an instance
of `HttpInterceptorWrapper` and use it with your HTTP client. Here's a basic
example:

### For Dart

```dart
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http_intercept/http_intercept.dart';

void main() {
  unawaited(
    http.runWithClient(
      _myDartApp,
      () => HttpClientProxy(
        interceptors: [
          HttpInterceptorWrapper(
            onRequest: (requestOptions) {
              // Add custom headers or modify the request
              requestOptions.headers['Authorization'] = 'Bearer YOUR_TOKEN';
              return OnRequest.next(requestOptions);
            },
          ),
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
import 'package:http_intercept/http_intercept.dart';

void main() {
  unawaited(
    http.runWithClient(
      () {
        runApp(const MyApp());
      },
      () => HttpClientProxy(
        interceptors: [
          HttpInterceptorWrapper(
            onRequest: (requestOptions) {
              // Add custom headers or modify the request
              requestOptions.headers['Authorization'] = 'Bearer YOUR_TOKEN';
              return OnRequest.next(requestOptions);
            },
          ),
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

For more advanced usage, you can chain multiple interceptors, handle specific
error types, or modify responses before they reach your application. Here's an
example:

```dart
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http_intercept/http_intercept.dart';

class LoggingInterceptor extends HttpInterceptor {
  @override
  FutureOr<OnRequest> onRequest(http.BaseRequest request) {
    print('Request: ${request.method} ${request.url}');
    return OnRequest.next(request);
  }

  @override
  FutureOr<OnResponse> onResponse(http.StreamedResponse response) {
    print('Response: ${response.statusCode}');
    return OnResponse.next(response);
  }

  @override
  FutureOr<OnError> onError(
    http.BaseRequest request,
    Object error,
    StackTrace? stackTrace,
  ) {
    print('Error: $error');
    return OnError.next(request, error, stackTrace);
  }
}

void main() {
  unawaited(
    http.runWithClient(
      _myDartApp,
      () => HttpClientProxy(
        interceptors: [
          LoggingInterceptor(),
          // other interceptors
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

## Compatibility

`http_intercept` works with popular HTTP packages like 
[Chopper](https://pub.dev/packages/chopper), [Retrofit](https://pub.dev/packages/retrofit),
and [Dio](https://pub.dev/packages/dio_compatibility_layer). You can also combine it with other HTTP
clients, like [`cupertino_http`](https://pub.dev/packages/cupertino_http) for iOS and macOS,
[`cronet_http`](https://pub.dev/packages/cronet_http) for Android, and
[`RetryClient`](https://pub.dev/documentation/http/latest/retry/RetryClient-class.html),
that are compatible with the [http](https://pub.dev/packages/http) package. This
makes it easy to integrate into various projects and setups.

### Note for Flutter's Image Widget

`http_intercept` will not work directly with Flutter's 
[`Image.network`](https://api.flutter.dev/flutter/widgets/Image/Image.network.html) widget 
because the [`NetworkImage`](https://api.flutter.dev/flutter/painting/NetworkImage-class.html) 
used by the `Image.network` widget relies on the 
[`HttpClient`](https://api.flutter.dev/flutter/dart-io/HttpClient-class.html) from the 
`dart:io` package. However, you can achieve this functionality by using the 
[`http_image_provider`](https://pub.dev/packages/http_image_provider) package, which 
allows you to use the `http` package with the `Image` widget, enabling the use of `http_intercept`.

### Using with Chopper

To use `http_intercept` with Chopper, you need to create an instance of
`HttpClientProxy` and pass it to the Chopper client. Here's an example:

```dart
import 'dart:async';

import 'package:chopper/chopper.dart';
import 'package:http_intercept/http_intercept.dart';

part 'main_chopper.chopper.dart';

Future<void> main() async {
  // Create an instance of HttpClientProxy with interceptors.
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

  // Create a ChopperClient using the custom HttpClientProxy.
  // This allows Chopper to use the custom HTTP client with interceptors
  // instead of the default HTTP client.
  final chopper = ChopperClient(
    client: httpClient,
    services: [PostsService.create()],
  );

  // Get an instance of the PostsService.
  final postsService = chopper.getService<PostsService>();

  // Make a GET request to fetch a post by ID.
  final response = await postsService.getPost('1');

  // Close the ChopperClient's HTTP client.
  // Calling close is important to free up resources and avoid potential
  // memory leaks.
  chopper.httpClient.close();

  // Print the response body.
  print(response.body);
}

@ChopperApi(baseUrl: 'https://jsonplaceholder.typicode.com/posts')
abstract class PostsService extends ChopperService {
  // Factory method to create an instance of PostsService.
  static PostsService create([ChopperClient? client]) => _$PostsService(client);

  // Define a GET request to fetch a post by ID.
  @Get(path: '/{id}')
  Future<Response> getPost(@Path() String id);
}
```

### Using with Dio

To use `http_intercept` with Dio, you need to use the
package [`dio_compatibility_layer`](https://pub.dev/packages/dio_compatibility_layer).
This package provides a compatibility layer to make Dio work
with `http_intercept`. Here's an example:

```dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_compatibility_layer/dio_compatibility_layer.dart';
import 'package:http_intercept/http_intercept.dart';

Future<void> main() async {
  // Create an instance of HttpClientProxy with interceptors.
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

  // Create a ConversionLayerAdapter using the HttpClientProxy.
  // This adapter allows Dio to use the HTTP client from the `http` package
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
```

### Using with Retrofit

Using `http_intercept` with Retrofit is very similar to using it with Dio, as both
require the `dio_compatibility_layer` package. Here's an example:

```dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_compatibility_layer/dio_compatibility_layer.dart';
import 'package:http_intercept/http_intercept.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:retrofit/http.dart';
import 'package:retrofit/retrofit.dart';

part 'main_retrofit.g.dart';

Future<void> main() async {
  // Create an instance of HttpClientProxy with interceptors.
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

  // Create a ConversionLayerAdapter using the HttpClientProxy.
  // This adapter allows Dio to use the HTTP client from the `http` package
  // instead of its default HTTP client.
  final dioAdapter = ConversionLayerAdapter(httpClient);

  // Instantiate Dio and configure it to use the custom HTTP client adapter.
  final dio = Dio()..httpClientAdapter = dioAdapter;

  // Instantiate a RestClient using the configured Dio instance.
  final client = RestClient(dio);

  // Make a GET request to fetch a post with ID '1'.
  final response = await client.getPost('1');

  // Close the Dio instance.
  // Calling close is important to free up resources and avoid potential
  // memory leaks.
  dio.close();

  // Print the response.
  print(response);
}

@RestApi(baseUrl: 'https://jsonplaceholder.typicode.com/')
abstract class RestClient {
  // Factory constructor to create an instance of RestClient using Dio.f
  factory RestClient(Dio dio, {String baseUrl}) = _RestClient;

  // Define a GET request to fetch a post by its ID.
  @GET('/posts/{id}')
  Future<Post> getPost(@Path('id') String id);
}

@JsonSerializable()
class Post {
  const Post({
    required this.userId,
    required this.id,
    required this.title,
    required this.body,
  });

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);

  final int userId;
  final int id;
  final String title;
  final String body;

  @override
  String toString() => 'Post id: $id - title: $title';
}
```

### Combined with http compatible clients such as `cupertino_http`, `cronet_http` and `retry`.

These examples demonstrate how to use `http_intercept` with HTTP-compatible clients such as 
`cupertino_http`, `cronet_http`, and `retry`. It's important to note that `cupertino_http` 
and `cronet_http` are specifically designed for Flutter applications, so they cannot be used 
in plain Dart projects. However, the integration principles remain similar across different 
client libraries, allowing you to leverage the interceptor functionality alongside the 
unique features of each client.

```dart
import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:http_intercept/http_intercept.dart';

void main() {
  http.runWithClient(
    () {
      // Ensure that the Flutter framework is properly initialized.
      WidgetsFlutterBinding.ensureInitialized();

      // Run the Flutter application.
      runApp(const MyApp());
    },
    // Create and configure the HTTP client with interceptors.
    _createHttpClient,
  );
}

/// The root widget of the application.
///
/// This widget sets up the basic structure of the app, including the home page
/// with an AppBar and a centered image loaded via HTTP.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Flutter UI code goes here
  }
}

/// Creates and configures an HTTP client with interceptors.
///
/// This function sets up a client based on the platform and adds an interceptor.
http.Client _createHttpClient() {
  return HttpClientProxy(
    // Use RetryClient as the inner client for automatic retries
    innerClient: RetryClient(
      // Choose the appropriate client based on the platform
      switch (Platform.operatingSystem) {
        'android' => CronetClient.fromCronetEngine(CronetEngine.build()),
        'ios' || 'macos' => CupertinoClient.defaultSessionConfiguration(),
        _ => throw UnimplementedError(),
      },
    ),
    // Add interceptors to modify requests
    interceptors: [
      HttpInterceptorWrapper(
        onRequest: (requestOptions) {
          // Add custom headers or modify the request
          requestOptions.headers['Authorization'] = 'Bearer YOUR_TOKEN';
          return OnRequest.next(requestOptions);
        },
      ),
    ],
  );
}
```
