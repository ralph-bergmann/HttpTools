// ignore_for_file: avoid_setters_without_getters

import 'dart:async';

import 'package:http/http.dart';

import 'http_interceptor.dart';
import 'on_error.dart';
import 'on_request.dart';
import 'on_response.dart';

/// A proxy class that wraps around an existing HTTP client to enable the
/// interception of HTTP requests, responses, and errors. This allows for custom
/// processing or modification of the HTTP transactions as needed.
///
/// The [HttpClientProxy] class implements the [Client] interface from the
/// `http` package, making it compatible with code that uses [Client].
///
/// Example usage:
/// ```dart
/// http.runWithClient(
///   () async {
///     // Example HTTP GET request
///     final response = await http
///         .get(Uri.parse('https://jsonplaceholder.typicode.com/posts/1'));
///     print('Response status: ${response.statusCode}');
///     print('Response body: ${response.body}');
///   },
///   () => HttpClientProxy(
///     interceptors: [
///       HttpInterceptorWrapper(
///         onRequest: (requestOptions) {
///           // Log the outgoing request
///           print('Making request to ${requestOptions.url}');
///           // Add a custom header to the request
///           requestOptions.headers?['Custom-Header'] = 'Value';
///           return OnRequest.next(requestOptions);
///         },
///         onResponse: (response) {
///           // Log the incoming response
///           print('Received response with status: ${response.statusCode}');
///           // Modify the response if necessary
///           if (response.statusCode == 200) {
///             final modifiedBody = 'Modified Body: ${response.body}';
///             return OnResponse.next(http.Response(modifiedBody, 200));
///           }
///           return OnResponse.next(response);
///         },
///         onError: (error, stackTrace) {
///           // Log and handle errors
///           print('Error occurred: $error');
///           // Optionally modify the error before passing it on
///           final modifiedError = 'Handled $error';
///           return OnError.next(modifiedError);
///         },
///       ),
///     ],
///   ),
/// );
/// ```
///
/// [runOnResponseInReverseOrder] determines the order of execution for
/// onResponse interceptors. If set to true, onResponse interceptors are
/// executed in reverse order, which can be useful for unwinding operations
/// performed during the request phase or for maintaining a logical symmetry
/// between request modifications and response handling.
class HttpClientProxy extends BaseClient {
  /// Constructs a [HttpClientProxy] which wraps around an [innerClient].
  /// If no [innerClient] is provided, a new instance of [Client] is used.
  ///
  /// [interceptors] is an optional list of interceptors that can modify
  /// the request, response, or capture errors. Interceptors are applied
  /// in the order they are provided unless [runOnResponseInReverseOrder] is
  /// true.
  HttpClientProxy({
    Client? innerClient,
    this.interceptors,
    this.runOnResponseInReverseOrder = false,
  }) : innerClient = innerClient ?? Client();

  /// The underlying HTTP client that actually sends the requests.
  /// This client is called after the interceptors have processed the request.
  final Client innerClient;

  /// A list of interceptors that can modify requests, responses,
  /// or handle errors.
  /// Each interceptor can perform actions or modify the HTTP transaction before
  /// passing it along to the next interceptor in the chain, or ultimately to
  /// the [innerClient].
  final List<HttpInterceptor>? interceptors;

  /// Determines whether onResponse interceptors should be run in reverse order.
  /// This can be useful for certain scenarios where the last interceptor to
  /// modify the request needs to be the first to inspect the response.
  final bool runOnResponseInReverseOrder;

  /// Sends an HTTP request and returns the streamed response after processing
  /// it through a series of interceptors.
  ///
  /// This method overrides the `send` method from the `BaseClient` class. It
  /// allows for the interception of HTTP requests, responses, and errors by
  /// applying a series of interceptors. The interceptors can modify the
  /// request, response, or handle errors before the request is sent or the
  /// response is returned.
  ///
  /// The method uses a `Completer` to manage the asynchronous operation and
  /// ensure that the response or error is returned only after all interceptors
  /// have been processed.
  ///
  /// The interceptors are processed in the following order:
  /// 1. `onRequest` interceptors: Modify the request before it is sent.
  /// 2. `onResponse` interceptors: Modify the response before it is returned.
  /// 3. `onError` interceptors: Handle any errors that occur during the
  /// request.
  ///
  /// If an interceptor resolves the request or response, the remaining
  /// interceptors are skipped unless specified otherwise.
  ///
  /// If an interceptor rejects the request or response, the error is propagated
  /// and the remaining interceptors are skipped unless specified otherwise.
  ///
  /// The method also supports running `onResponse` interceptors in reverse
  /// order if the `runOnResponseInReverseOrder` flag is set.
  ///
  /// [request] The HTTP request to be sent.
  ///
  /// Returns a `Future<StreamedResponse>` that completes with the streamed
  /// response or an error if the request fails.
  @override
  Future<StreamedResponse> send(BaseRequest request) {
    final completer = Completer<StreamedResponse>();

    // Start an asynchronous operation to handle the request
    unawaited(
      Future(() async {
        // The request that will be modified by interceptors
        var modifiedRequest = request;

        // The response that will be returned, if any
        StreamedResponse? response;

        // If true, the request will proceed through the interceptor chain even
        // if resolved. Needed for package:http_cache
        var proceedAfterResolve = false;

        try {
          // Process onRequest interceptors
          loop:
          {
            for (final interceptor in interceptors ?? <HttpInterceptor>[]) {
              final onRequest =
                  await interceptor.onRequest.call(modifiedRequest);
              switch (onRequest) {
                case OnRequestNext(request: final request):
                  // Update the request with modifications from the interceptor
                  modifiedRequest = request;
                case OnRequestResolve(
                    response: final resolvedResponse,
                    skipFollowingResponseInterceptors: final bool skipFollowing,
                  ):
                  if (skipFollowing) {
                    // Complete the request with the resolved response and break
                    // the loop
                    completer.complete(resolvedResponse);
                    break loop;
                  } else {
                    // Set the response but continue processing interceptors
                    response = resolvedResponse;
                  }
                case OnRequestResolveAndNext(
                    request: final request,
                    response: final resolvedResponse,
                    skipFollowingResponseInterceptors: final bool skipFollowing,
                  ):
                  // Update the request with modifications from the interceptor
                  modifiedRequest = request;
                  proceedAfterResolve = true;
                  if (skipFollowing) {
                    // Complete the request with the resolved response and break
                    // the loop
                    completer.complete(resolvedResponse);
                    break loop;
                  } else {
                    // Set the response but continue processing interceptors
                    response = resolvedResponse;
                  }
                case OnRequestReject(
                    error: final error,
                    skipFollowingErrorInterceptors: final bool skipFollowing,
                  ):
                  if (skipFollowing) {
                    // Complete the request with an error and break the loop
                    completer.completeError(error);
                    break loop;
                  } else {
                    // Throw the error to be caught by the catch block
                    throw error;
                  }
              }
            }
          }

          // If the request has been completed and no further processing is
          // needed, return
          if (completer.isCompleted && !proceedAfterResolve) {
            return;
          }

          // If response is not yet set, send the request using the inner client
          response ??= await innerClient.send(modifiedRequest);

          // Process onResponse interceptors
          loop:
          {
            final chain = (runOnResponseInReverseOrder
                    ? interceptors?.reversed
                    : interceptors) ??
                <HttpInterceptor>[];
            for (final interceptor in chain) {
              final onResponse = await interceptor.onResponse.call(response!);
              switch (onResponse) {
                case OnResponseNext(response: final newResponse):
                  // Update the response with modifications from the interceptor
                  response = newResponse;
                case OnResponseResolve(response: final response):
                  // Complete the request with the resolved response and break
                  // the loop
                  completer.complete(response);
                  break loop;
                case OnResponseReject(error: final error):
                  // Complete the request with an error and break the loop
                  completer.completeError(error);
                  break loop;
              }
            }
          }

          // If no interceptor has completed the response, complete it now
          if (!completer.isCompleted) {
            completer.complete(response);
          }
        } catch (e, s) {
          // Process onError interceptors
          var error = e;
          StackTrace? stackTrace = s;
          loop:
          {
            for (final interceptor in interceptors ?? []) {
              final onError =
                  await interceptor.onError?.call(request, error, stackTrace);
              switch (onError) {
                case OnErrorNext(
                    error: final newError,
                    stackTrace: final newStackTrace,
                  ):
                  // Update the error and stack trace with modifications from
                  // the interceptor
                  error = newError;
                  stackTrace = newStackTrace;
                case OnErrorResolve(response: final response):
                  // Complete the request with the resolved response and break
                  // the loop
                  completer.complete(response);
                  break loop;
                case OnErrorReject(
                    error: final error,
                    stackTrace: final stackTrace,
                  ):
                  // Complete the request with an error and break the loop
                  completer.completeError(error, stackTrace);
                  break loop;
              }
            }
          }
          // If no interceptor has handled the error, rethrow it
          if (!completer.isCompleted) {
            completer.completeError(error, s);
          }
        }
      }),
    );

    return completer.future;
  }

  /// see [Client.close]
  @override
  Future<void> close() async {
    for (final interceptor in interceptors ?? <HttpInterceptor>[]) {
      interceptor.dispose();
    }
    innerClient.close();
  }
}
