import 'package:http/http.dart';
import 'package:meta/meta.dart';

/// A class hierarchy used to handle responses that occur during HTTP request
/// processing.
///
/// This sealed class allows different handling strategies for responses:
/// - [OnResponseNext]: Continue with the next response interceptor in the
///   chain.
/// - [OnResponseResolve]: Resolve the response and return a custom response.
/// - [OnResponseReject]: Reject the response and propagate an error.
@immutable
sealed class OnResponse {
  const OnResponse();

  /// Creates an instance of [OnResponseNext] which allows the response handling
  /// to continue to the next interceptor.
  static const next = OnResponseNext.new;

  /// Creates an instance of [OnResponseResolve] which resolves the response and
  /// returns a custom response.
  static const resolve = OnResponseResolve.new;

  /// Creates an instance of [OnResponseReject] which rejects the response and
  /// propagates an error.
  static const reject = OnResponseReject.new;
}

/// Forwards the `response` to the next interceptor.
///
/// Can be used to manipulate the response before it is processed.
@immutable
class OnResponseNext extends OnResponse {
  const OnResponseNext(
    this.response,
  );

  final StreamedResponse response;
}

/// Completes the request with `response`.
///
/// The response will be returned to the caller.
/// Following interceptors are skipped unless
/// `skipFollowingResponseInterceptors` is false.
@immutable
class OnResponseResolve extends OnResponse {
  const OnResponseResolve(
    this.response,
  );

  final StreamedResponse response;
}

/// Rejects the response by returning an `error`.
///
/// The response will not be processed, instead, `error` will be returned to
/// the caller.
/// Following error interceptors are skipped unless
/// `skipFollowingErrorInterceptors` is false.
@immutable
class OnResponseReject extends OnResponse {
  const OnResponseReject(
    this.error, {
    this.skipFollowingErrorInterceptors = true,
  });

  final Object error;
  final bool skipFollowingErrorInterceptors;
}
