import 'dart:async';
import 'package:http/http.dart';
import 'package:http_client_interceptor/http_client_interceptor.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

/// Logger instance for HTTP logging.
final _logger = Logger('HttpLogger');

/// UUID generator for unique request identifiers.
const _uuid = Uuid();

/// Custom header key to track request IDs.
const _requestId = 'x-request-id';

/// A [HttpInterceptor] to log HTTP requests and responses.
///
/// This interceptor can be configured to log different levels of details
/// such as basic info, headers, and full body content.
///
/// Example usage
/// ```dart
/// void main() async {
///   Logger.root.onRecord.listen((record) {
///     print(record.message);
///   });
///
///   http.runWithClient(
///     () {
///       http.get(
///         Uri.parse('https://jsonplaceholder.typicode.com/posts/1'),
///         headers: {
///           HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
///         },
///       );
///     },
///     () => HttpClientProxy(interceptors: [HttpLogger(level: Level.basic)]),
///   );
/// }
/// ```
class HttpLogger extends HttpInterceptor {
  /// Creates an instance of [HttpLogger] with an optional logging [level].
  HttpLogger({
    this.level = Level.basic,
  });

  /// The logging level to be used by this logger.
  final Level level;

  /// Map to keep track of request timers for calculating request durations.
  final Map<String, Stopwatch> _requestTimers = {};

  /// Logs request details based on the specified [level].
  @override
  FutureOr<OnRequest> onRequest(BaseRequest request) {
    final isBasic = level.index >= Level.basic.index;
    final isHeaders = level.index >= Level.headers.index;
    //final isBody = level.index >= Level.body.index;

    if (isBasic) {
      _logger.info(
        '--> ${request.method} '
        '${request.url.toString()}',
      );
    }
    if (isHeaders) {
      request.headers.forEach((header, value) {
        _logger.info('$header: $value');
      });
    }
    //if (isBody && request.body != null) {
    //  _logger
    //    ..info('\n')
    //    ..info(request.body);
    //}
    if (isHeaders) {
      _logger.info('--> END ${request.method}');
    }

    final requestId = _uuid.v4();
    final stopwatch = Stopwatch()..start();
    _requestTimers[requestId] = stopwatch;

    request.headers[_requestId] = requestId;
    return OnRequest.next(request);
  }

  /// Logs response details based on the specified [level].
  @override
  FutureOr<OnResponse> onResponse(StreamedResponse response) {
    final isBasic = level.index >= Level.basic.index;
    final isHeaders = level.index >= Level.headers.index;
    //final isBody = level.index >= Level.body.index;

    if (isBasic) {
      final requestId = response.request?.headers[_requestId];
      final duration = _stopTimer(requestId);

      _logger.info(
        '<-- ${response.statusCode} ${response.reasonPhrase} '
        '[${duration}ms] ${response.request?.url.toString()}',
      );
    }
    if (isHeaders) {
      response.headers.forEach((header, value) {
        _logger.info('$header: $value');
      });
    }
    //if (isBody && response.body.isNotEmpty) {
    //  _logger
    //    ..info('\n')
    //    ..info(response.body);
    //}
    if (isHeaders) {
      _logger.info('<-- END');
    }
    return OnResponse.next(response);
  }

  /// Handles errors during HTTP transactions.
  @override
  FutureOr<OnError> onError(
    BaseRequest request,
    Object error,
    StackTrace? stackTrace,
  ) {
    _logger.severe('HTTP Error: $error', error, stackTrace);
    return OnError.next(request, error, stackTrace);
  }

  /// Cleans up resources used by the logger, particularly stopping any
  /// active timers.
  @override
  void dispose() {
    for (final stopwatch in _requestTimers.values) {
      stopwatch.stop();
    }
    _requestTimers.clear();
  }

  /// Stops the timer associated with the given [requestId] and returns the
  /// elapsed time in milliseconds.
  int? _stopTimer(String? requestId) {
    if (requestId != null && _requestTimers.containsKey(requestId)) {
      final stopwatch = _requestTimers.remove(requestId);
      stopwatch?.stop();
      return stopwatch?.elapsedMilliseconds;
    }
    return null;
  }
}

/// Defines the logging levels available for HTTP logging.
enum Level {
  /// No logs will be recorded.
  none,

  /// Logs basic information about the HTTP request and response.
  basic,

  /// Logs basic information along with request and response headers.
  headers,

  ///// Logs complete request and response headers and bodies.
  //body
}
