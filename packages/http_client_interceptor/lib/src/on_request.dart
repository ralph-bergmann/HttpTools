import 'package:http/http.dart';
import 'package:meta/meta.dart';

/// A class hierarchy used to handle requests before they are sent.
///
/// This sealed class allows different handling strategies for requests:
/// - [OnRequestNext]: Continue with the next request interceptor in the chain.
/// - [OnRequestResolve]: Resolve the request and return a custom response.
/// - [OnRequestResolveAndNext]: Resolve the request with a custom response and
///   continue with the next interceptor.
/// - [OnRequestReject]: Reject the request and propagate an error.
@immutable
sealed class OnRequest {
  const OnRequest();

  /// Creates an instance of [OnRequestNext] which allows the request handling
  /// to continue to the next interceptor.
  static const next = OnRequestNext.new;

  /// Creates an instance of [OnRequestResolve] which resolves the request and
  /// returns a custom response.
  static const resolve = OnRequestResolve.new;

  /// Creates an instance of [OnRequestResolveAndNext] which resolves the
  /// request with a custom response and continues to the next interceptor.
  static const resolveAndNext = OnRequestResolveAndNext.new;

  /// Creates an instance of [OnRequestReject] which rejects the request and
  /// propagates an error.
  static const reject = OnRequestReject.new;
}

/// Forwards the `request` to the next interceptor.
///
/// Can be used to manipulate the request before it is sent.
@immutable
class OnRequestNext extends OnRequest {
  const OnRequestNext(
    this.request,
  );

  final BaseRequest request;
}

/// Completes the request with `response`.
///
/// The request will not be invoked, instead, `response` will be returned to
/// the caller.
/// Following response interceptors are skipped unless
/// `skipFollowingResponseInterceptors` is false.
@immutable
class OnRequestResolve extends OnRequest {
  const OnRequestResolve(
    this.response, {
    this.skipFollowingResponseInterceptors = true,
  });

  final StreamedResponse response;
  final bool skipFollowingResponseInterceptors;
}

/// Completes the request with `response` but also invokes the
/// `request`. Needed for `package:http_cache`.
///
/// The request will be invoked, but `response` will be returned to
/// the caller.
/// Following response interceptors are skipped unless
/// `skipFollowingErrorInterceptors` is false.
@immutable
class OnRequestResolveAndNext extends OnRequest {
  const OnRequestResolveAndNext(
    this.request,
    this.response, {
    this.skipFollowingResponseInterceptors = true,
  });

  final BaseRequest request;
  final StreamedResponse response;
  final bool skipFollowingResponseInterceptors;
}

/// Rejects the request by returning an `error`.
///
/// The request will not be invoked, instead, `error` will be returned to
/// the caller.
/// Following error interceptors are skipped unless
/// `skipFollowingErrorInterceptors` is false.
@immutable
class OnRequestReject extends OnRequest {
  const OnRequestReject(
    this.error, {
    this.skipFollowingErrorInterceptors = true,
  });

  final Object error;
  final bool skipFollowingErrorInterceptors;
}
