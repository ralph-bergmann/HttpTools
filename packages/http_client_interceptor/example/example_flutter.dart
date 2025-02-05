import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_client_cache/http_client_cache.dart';
import 'package:http_client_interceptor/http_client_interceptor.dart';
import 'package:http_client_logger/http_client_logger.dart';
import 'package:http_image_provider/http_image_provider.dart';
import 'package:inject_annotation/inject_annotation.dart';
import 'package:logging/logging.dart' as log;
import 'package:path_provider/path_provider.dart';

import 'example_flutter.inject.dart' as g;

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

  // Create an API module with the cache instance.
  final apiModule = ApiModule(httpCache: cache);

  // Create the main component with the API module.
  final mainComponent = MainComponent.create(apiModule: apiModule);

  // Create the application instance.
  final app = mainComponent.appFactory.create();

  // Run the application.
  runApp(app);
}

/// Component for the main application.
///
/// This component provides the [MyAppFactory] for creating the application.
@Component([ApiModule])
abstract class MainComponent {
  static const create = g.MainComponent$Component.create;

  @inject
  MyAppFactory get appFactory;
}

/// ApiModule handles HTTP client configuration with interceptors.
///
/// The HttpCache is intentionally passed as a constructor parameter rather than
/// being created within the module. This design choice is made because:
///
/// 1. HttpCache initialization is asynchronous (requires await)
/// 2. If ApiModule created the cache internally, its provider methods would
///    need to be async
/// 3. This would force all dependent classes that inject the HTTP client to
///    also use async providers
/// 4. The async dependency chain would propagate throughout the dependency tree
///
/// By accepting a pre-initialized HttpCache, we:
/// - Keep provider methods synchronous
/// - Isolate async initialization to the application bootstrap phase
/// - Prevent cascading async dependencies across the codebase
/// - Maintain cleaner dependency injection patterns
///
/// Example usage:
/// ```dart
/// final cache = HttpCache();
/// await cache.initLocal(cacheDir); // Async init happens once
/// final apiModule = ApiModule(httpCache: cache); // Rest is sync
/// ```
@module
class ApiModule {
  const ApiModule({required HttpCache httpCache}) : _httpCache = httpCache;

  final HttpCache _httpCache;

  /// Creates an HTTP client configured with interceptors:
  /// - HttpLogger for logging HTTP transactions
  /// - HttpCache for caching HTTP responses
  /// - HttpInterceptorWrapper to modify the cache headers of HTTP responses
  ///
  /// This function returns an instance of [HttpClientProxy] configured with
  /// a [HttpLogger] interceptor for logging HTTP transactions and a [HttpCache]
  /// interceptor for caching HTTP responses.
  @provides
  @singleton
  http.Client provideHttpClient() => HttpClientProxy(
        interceptors: [
          //HttpLogger(level: Level.headers),
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
          HttpLogger(level: Level.headers),
          _httpCache,
        ],
      );
}

/// The factory for creating instances of [MyApp].
///
/// Used to create instances of [MyApp] with the necessary dependencies
/// injected.
@assistedFactory
abstract class MyAppFactory {
  MyApp create({Key? key});
}

/// The main application widget.
///
/// Created by the [MyAppFactory]. Don't create this class directly.
/// Factory makes sure that all the dependencies are injected correctly.
class MyApp extends StatelessWidget {
  @assistedInject
  const MyApp({
    @assisted super.key,
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
