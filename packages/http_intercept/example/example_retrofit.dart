import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_compatibility_layer/dio_compatibility_layer.dart';
import 'package:http_intercept/http_intercept.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:retrofit/http.dart';
import 'package:retrofit/retrofit.dart';

part 'example_retrofit.g.dart';

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

  // Create a [ConversionLayerAdapter] using the [HttpClientProxy].
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
