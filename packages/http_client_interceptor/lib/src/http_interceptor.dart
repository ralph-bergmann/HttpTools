import 'dart:async';

import 'package:http/http.dart';
import 'package:meta/meta.dart';

import 'on_error.dart';
import 'on_request.dart';
import 'on_response.dart';

/// A class used to intercept HTTP requests, responses, and errors.
///
/// This class allows different handling strategies for HTTP transactions:
/// - [onRequest]: Intercept and manipulate the request before it is sent.
/// - [onResponse]: Intercept and manipulate the response before it is
///   processed.
/// - [onError]: Handle errors that occur during the HTTP request lifecycle.
class HttpInterceptor {
  const HttpInterceptor();

  /// Intercepts the [request] before it is sent.
  ///
  /// Can be used to manipulate the request before it is sent.
  FutureOr<OnRequest> onRequest(BaseRequest request) => OnRequest.next(request);

  /// Intercepts the [response] before it is processed.
  ///
  /// Can be used to manipulate the response before it is processed.
  FutureOr<OnResponse> onResponse(StreamedResponse response) =>
      OnResponse.next(response);

  /// Handles errors that occur during the HTTP request lifecycle.
  ///
  /// Can be used to handle errors and potentially recover from them.
  FutureOr<OnError> onError(
    BaseRequest request,
    Object error,
    StackTrace? stackTrace,
  ) =>
      OnError.next(request, error, stackTrace);

  /// Disposes of any resources held by the interceptor.
  ///
  /// This method should be called when the interceptor is no longer needed.
  FutureOr<void> dispose() {}
}

/// A wrapper class for [HttpInterceptor] that allows custom callbacks for
/// request, response, and error handling.
///
/// This class provides a convenient way to define custom behavior for
/// intercepting HTTP transactions by passing callback functions.
@immutable
class HttpInterceptorWrapper extends HttpInterceptor {
  /// Creates an instance of [HttpInterceptorWrapper] with optional custom
  /// callbacks for request, response, and error handling.
  ///
  /// If no callbacks are provided, the default behavior is to forward the
  /// request, response, or error to the next interceptor.
  const HttpInterceptorWrapper({
    OnRequestCallback? onRequest,
    OnResponseCallback? onResponse,
    OnErrorCallback? onError,
  })  : _onRequest = onRequest ?? OnRequest.next,
        _onResponse = onResponse ?? OnResponse.next,
        _onError = onError ?? _convertOnError;

  final OnRequestCallback _onRequest;
  final OnResponseCallback _onResponse;
  final OnErrorCallback _onError;

  /// Intercepts the [request] before it is sent using the provided callback.
  ///
  /// Can be used to manipulate the request before it is sent.
  @override
  FutureOr<OnRequest> onRequest(BaseRequest request) => _onRequest(request);

  /// Intercepts the [response] before it is processed using the provided
  /// callback.
  ///
  /// Can be used to manipulate the response before it is processed.
  @override
  FutureOr<OnResponse> onResponse(StreamedResponse response) =>
      _onResponse(response);

  /// Handles errors that occur during the HTTP request lifecycle using the
  /// provided callback.
  ///
  /// Can be used to handle errors and potentially recover from them.
  @override
  FutureOr<OnError> onError(
    BaseRequest request,
    Object error,
    StackTrace? stackTrace,
  ) =>
      _onError(request, error, stackTrace);
}

/// Converts an error to an [OnError] instance that continues to the next
/// interceptor.
FutureOr<OnError> _convertOnError(
  BaseRequest request,
  Object e,
  StackTrace? s,
) =>
    OnError.next(request, e, s);

/// Callback type for intercepting and manipulating requests.
typedef OnRequestCallback = FutureOr<OnRequest> Function(
  BaseRequest request,
);

/// Callback type for intercepting and manipulating responses.
typedef OnResponseCallback = FutureOr<OnResponse> Function(
  StreamedResponse response,
);

/// Callback type for intercepting and manipulating errors.
typedef OnErrorCallback = FutureOr<OnError> Function(
  BaseRequest request,
  Object error,
  StackTrace? stackTrace,
);
