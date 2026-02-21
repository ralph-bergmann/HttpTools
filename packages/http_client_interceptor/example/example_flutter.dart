import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_client_cache/http_client_cache.dart';
import 'package:http_client_interceptor/http_client_interceptor.dart';
import 'package:http_client_logger/http_client_logger.dart';
import 'package:http_image_provider/http_image_provider.dart';
import 'package:logging/logging.dart' as log;
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  // Set up logging to print log messages to the console.
  log.Logger.root.level = log.Level.ALL;
  log.Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print(record.message);
  });

  // Ensure that the Flutter framework is properly initialized.
  WidgetsFlutterBinding.ensureInitialized();

  // Get the directory for application-specific cache files.
  final cacheDir = await getApplicationCacheDirectory();

  // Initialize the local cache with the obtained directory.
  final cache = HttpCache();
  await cache.initLocal(cacheDir);

  // Create a HttpClientProxy to intercept HTTP requests for caching.
  final httpClient = HttpClientProxy(
    interceptors: [
      //HttpLogger(level: Level.headers),
      HttpInterceptorWrapper(
        onResponse: (response) {
          // Create new headers map with the updated cache control
          final newHeaders = Map<String, String>.from(response.headers);
          newHeaders[HttpHeaders.cacheControlHeader] = CacheControl.staticAsset(
            maxAge: const Duration(days: 1),
          ).toString();

          return OnResponse.next(response.copyWith(headers: newHeaders));
        },
      ),
      HttpLogger(level: Level.headers),
      cache,
    ],
  );

  // Run the application.
  runApp(MyApp(httpClient: httpClient));
}

/// The main application widget.
class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.httpClient,
  });

  final http.Client httpClient;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Text('HttpImageProvider:'),
            Image(
              image: HttpImageProvider(
                client: httpClient,
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
