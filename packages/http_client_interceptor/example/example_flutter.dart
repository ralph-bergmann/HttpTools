import 'dart:async';
import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:http_client_cache/http_client_cache.dart';
import 'package:http_client_interceptor/http_client_interceptor.dart';
import 'package:http_client_logger/http_client_logger.dart';
import 'package:http_image_provider/http_image_provider.dart';
import 'package:logging/logging.dart' as log;
import 'package:path_provider/path_provider.dart';

void main() {
  // Set up logging to print log messages to the console.
  log.Logger.root.level = log.Level.ALL;
  log.Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print(record.message);
  });

  // Create an instance of [HttpCache].
  // It will be initialized as a local cache later.
  // We can't initialize it earlier because we need `WidgetsFlutterBinding` to
  // be initialized to get the app's cache path, and its initialization must
  // run in the same `Zone` as runApp.
  final cache = HttpCache();

  // Run the Dart application with a custom HTTP client.
  unawaited(
    http.runWithClient(
      () async {
        // Ensure that the Flutter framework is properly initialized.
        WidgetsFlutterBinding.ensureInitialized();

        // Get the directory for application-specific cache files.
        final cacheDir = await getApplicationCacheDirectory();

        // Initialize the local cache with the obtained directory.
        await cache.initLocal(cacheDir);

        // Run the Flutter application.
        runApp(const MyApp());
      },
      // Create and configure the HTTP client with interceptors.
      () => _createHttpClient(cache),
    ),
  );
}

/// The root widget of the application.
///
/// This widget sets up the basic structure of the app, including the home page
/// with an AppBar and a centered image loaded via HTTP.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const Text('HttpImageProvider:'),
                Image(
                  image: HttpImageProvider(
                    Uri.https(
                      'docs.flutter.dev',
                      'assets/images/dash/dash-fainting.gif',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Creates an HTTP client configured with interceptors for logging and caching.
///
/// This function returns an instance of [HttpClientProxy] configured with
/// a [HttpLogger] interceptor for logging HTTP transactions and a [HttpCache]
/// interceptor for caching HTTP responses.
///
/// [cache] - The [HttpCache] instance used for caching HTTP responses.
http.Client _createHttpClient(HttpCache cache) => HttpClientProxy(
      innerClient: RetryClient(
        switch (Platform.operatingSystem) {
          'android' => CronetClient.fromCronetEngine(CronetEngine.build()),
          'ios' || 'macos' => CupertinoClient.defaultSessionConfiguration(),
          _ => throw UnimplementedError(),
        },
      ),
      interceptors: [
        HttpInterceptorWrapper(
          onResponse: (response) {
            // Create new headers map with the updated cache control
            final newHeaders = Map<String, String>.from(response.headers);
            newHeaders[HttpHeaders.cacheControlHeader] =
                CacheControl.staticAsset(maxAge: const Duration(days: 1))
                    .toString();

            return OnResponse.next(response.copyWith(headers: newHeaders));
          },
        ),
        cache,
        HttpLogger(level: Level.headers),
      ],
    );
