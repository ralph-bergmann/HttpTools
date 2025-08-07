import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:async/async.dart';
import 'package:http/http.dart';
import 'package:http_client_interceptor/http_client_interceptor.dart';
import 'package:logging/logging.dart';

/// Logger instance for HTTP logging.
final _logger = Logger('HttpLogger');

/// Random number generator for unique request identifiers.
final _random = Random();

/// Custom header key to track request IDs.
const _requestId = 'x-request-id';

/// Generates a short but unique request ID.
///
/// Uses timestamp (in milliseconds since epoch) combined with random bits
/// to ensure uniqueness while keeping the ID short and readable.
String _generateRequestId() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final randomBits = _random.nextInt(0xFFFF); // 16-bit random number

  // Take last 24 bits of timestamp (about 4.6 hours of uniqueness)
  // and combine with 16 bits of random data for 40 bits total
  final combined = ((timestamp & 0xFFFFFF) << 16) | randomBits;

  // Convert to base-36 string (using 0-9, a-z) for compact representation
  return combined.toRadixString(36).padLeft(8, '0');
}

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
///     () => HttpClientProxy(interceptors: [HttpLogger(level: Level.body)]),
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
    final isBody = level.index >= Level.body.index;

    final requestId = _generateRequestId();
    final stopwatch = Stopwatch()..start();
    _requestTimers[requestId] = stopwatch;
    request.headers[_requestId] = requestId;

    // Use the same ID for both headers and logging
    final shortId = requestId;

    if (isBasic) {
      _logger.info(
        '[$shortId] --> ${request.method} ${request.url}',
      );
    }
    if (isHeaders) {
      if (request.headers.isNotEmpty) {
        request.headers.forEach((header, value) {
          // Skip our internal request ID header
          if (header != _requestId) {
            _logger.info('[$shortId]     $header: $value');
          }
        });
      } else {
        _logger.info('[$shortId]     <no headers>');
      }
    }
    if (isBody) {
      _logRequestBody(request, shortId);
    }
    if (isHeaders || isBody) {
      _logger.info('[$shortId] --> END ${request.method}');
    }

    return OnRequest.next(request);
  }

  /// Logs response details based on the specified [level].
  @override
  FutureOr<OnResponse> onResponse(StreamedResponse response) async {
    final isBasic = level.index >= Level.basic.index;
    final isHeaders = level.index >= Level.headers.index;
    final isBody = level.index >= Level.body.index;

    final requestId = response.request?.headers[_requestId];
    final duration = _stopTimer(requestId);

    // Use the same ID that's in the headers
    final shortId = requestId ?? 'unknown';

    if (isBasic) {
      _logger.info(
        '[$shortId] <-- ${response.statusCode} ${response.reasonPhrase ?? ''} '
        '(${duration ?? '?'}ms)',
      );
    }

    if (isHeaders) {
      if (response.headers.isNotEmpty) {
        response.headers.forEach((header, value) {
          _logger.info('[$shortId]     $header: $value');
        });
      } else {
        _logger.info('[$shortId]     <no headers>');
      }
    }

    // If we need to log the body, split the stream
    StreamedResponse finalResponse;
    if (isBody) {
      final streams = StreamSplitter.splitFrom(response.stream);

      // Log the body using one stream and wait for it to complete
      await _logResponseBody(streams[0], shortId);

      // Create the final response with the other stream
      finalResponse = StreamedResponse(
        streams[1],
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } else {
      finalResponse = response;
    }

    if (isHeaders || isBody) {
      _logger.info('[$shortId] <-- END');
    }

    return OnResponse.next(finalResponse);
  }

  /// Handles errors during HTTP transactions.
  @override
  FutureOr<OnError> onError(
    BaseRequest request,
    Object error,
    StackTrace? stackTrace,
  ) {
    final requestId = request.headers[_requestId];
    final shortId = requestId ?? 'unknown';

    _logger.severe('[$shortId] HTTP Error: $error', error, stackTrace);
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

  /// Logs the body of the HTTP request.
  void _logRequestBody(BaseRequest request, String shortId) {
    try {
      if (request is Request) {
        if (request.body.isNotEmpty) {
          _logger.info('[$shortId]     ${request.body}');
        } else {
          _logger.info('[$shortId]     <empty request body>');
        }
      } else if (request is MultipartRequest) {
        _logger.info('[$shortId]     Multipart request with '
            '${request.fields.length} fields and ${request.files.length} files');
        if (request.fields.isNotEmpty) {
          _logger.info('[$shortId]     Fields:');
          request.fields.forEach((key, value) {
            _logger.info('[$shortId]       $key: $value');
          });
        }
        if (request.files.isNotEmpty) {
          _logger.info('[$shortId]     Files:');
          for (final file in request.files) {
            _logger.info('[$shortId]       ${file.field}: '
                '${file.filename ?? '<no filename>'} (${file.length} bytes)');
          }
        }
      } else {
        _logger.info('[$shortId]     <binary or unsupported request body>');
      }
    } catch (e) {
      _logger.info('[$shortId]     <error reading request body: $e>');
    }
  }

  /// Logs the body of the HTTP response.
  Future<void> _logResponseBody(Stream<List<int>> bodyStream, String shortId) async {
    try {
      final chunks = await bodyStream.toList();
      final bodyBytes = <int>[];
      chunks.forEach(bodyBytes.addAll);

      final bodyString = utf8.decode(bodyBytes, allowMalformed: true);

      if (bodyString.isNotEmpty) {
        _logger.info('[$shortId]     $bodyString');
      } else {
        _logger.info('[$shortId]     <empty response body>');
      }
    } catch (e) {
      _logger.info('[$shortId]     <error reading response body: $e>');
    }
  }
}

/// Defines the logging levels available for HTTP logging.
///
/// **Warning:** Higher logging levels may impact HTTP request performance:
/// - [headers] level adds minimal overhead
/// - [body] level can significantly slow down requests as it reads and
///   processes the entire request/response body content
enum Level {
  /// No logs will be recorded.
  none,

  /// Logs basic information about the HTTP request and response.
  basic,

  /// Logs basic information along with request and response headers.
  ///
  /// **Note:** Minimal performance impact.
  headers,

  /// Logs complete request and response headers and bodies.
  ///
  /// **Warning:** This level can significantly impact performance as it reads
  /// and processes the entire request/response body content. Use with caution
  /// in production environments.
  body
}
