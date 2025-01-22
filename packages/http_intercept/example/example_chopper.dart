import 'dart:async';

import 'package:chopper/chopper.dart';
import 'package:http_intercept/http_intercept.dart';

part 'example_chopper.chopper.dart';

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

  // Create a [ChopperClient] using the custom [HttpClientProxy].
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
