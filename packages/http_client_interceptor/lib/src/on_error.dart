import 'package:http/http.dart';
import 'package:meta/meta.dart';

/// An class hierarchy used to handle errors that occur during HTTP request
/// processing.
///
/// This sealed class allows different handling strategies for errors:
/// - [OnErrorNext]: Continue with the next error interceptor in the chain.
/// - [OnErrorResolve]: Resolve the error and return a custom response.
/// - [OnErrorReject]: Reject the request and propagate the error.
@immutable
sealed class OnError {
  const OnError();

  /// Creates an instance of [OnErrorNext] which allows the error handling to
  /// continue to the next interceptor.
  static const next = OnErrorNext.new;

  /// Creates an instance of [OnErrorResolve] which resolves the error and
  /// returns a custom response.
  static const resolve = OnErrorResolve.new;

  /// Creates an instance of [OnErrorReject] which rejects the request and
  /// propagates the error.
  static const reject = OnErrorReject.new;
}

/// Represents an action to continue with the next error interceptor.
///
/// This class is used when an error occurs, and the handling strategy is to
/// allow further processing of the error by subsequent interceptors.
@immutable
class OnErrorNext extends OnError {
  /// Constructs an [OnErrorNext] with the given [request], [error],
  /// and [stackTrace].
  const OnErrorNext(
    this.request,
    this.error, [
    this.stackTrace,
  ]);

  /// The HTTP request that caused the error.
  final BaseRequest request;

  /// The current error being handled.
  final Object error;

  /// The current stack trace being handled.
  final StackTrace? stackTrace;
}

/// Represents an action to resolve the error and return a custom response.
///
/// This class is used when an error occurs, and the handling strategy is to
/// stop further error processing and return a specific response instead.
@immutable
class OnErrorResolve extends OnError {
  /// Constructs an [OnErrorResolve] with the given [response].
  const OnErrorResolve(
    this.response,
  );

  /// The custom response to be returned instead of continuing with the error.
  final StreamedResponse response;
}

/// Represents an action to reject the request and propagate the error.
///
/// This class is used when an error occurs, and the handling strategy is to
/// stop further error processing and propagate the error to the caller.
@immutable
class OnErrorReject extends OnError {
  /// Constructs an [OnErrorReject] with the given [error] and [stackTrace].
  const OnErrorReject(
    this.error, [
    this.stackTrace,
  ]);

  /// The error to be propagated.
  final Object error;

  /// The stack trace to be propagated.
  final StackTrace? stackTrace;
}
