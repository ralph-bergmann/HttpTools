// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'example_chopper.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$PostsService extends PostsService {
  _$PostsService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = PostsService;

  @override
  Future<Response<dynamic>> getPost(String id) {
    final Uri $url =
        Uri.parse('https://jsonplaceholder.typicode.com/posts/${id}');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }
}
