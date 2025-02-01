import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_client_interceptor/http_client_interceptor.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_test_handler/shelf_test_handler.dart';
import 'package:test/test.dart';

void main() {
  group('HttpClientProxy', () {
    test('simple request-response without interceptors', () async {
      final server = await _createTestServer(
        (_) => shelf.Response.ok('Response from test server'),
      );
      final client = _createClient([]);

      final response = await client.get(server.testUrl);
      expect(response.statusCode, 200);
      expect(response.body, 'Response from test server');
    });

    group('with onRequest interceptor', () {
      test(
        'OnRequest.next',
        () async {
          // Tests that the interceptor modifies the request
          // before it reaches the test server.
          //
          // Test will fail when:
          // - test server does not receive the request with the custom header
          // - test server does not return the custom response

          final server = await _createTestServer(
            (request) {
              expect(request.headers['Custom-Header'], 'Value');
              return shelf.Response.ok('Response from test server');
            },
          );
          final client = _createClient([
            HttpInterceptorWrapper(
              onRequest: (request) {
                request.headers['Custom-Header'] = 'Value';
                return OnRequest.next(request);
              },
            ),
          ]);

          final response = await client.get(server.testUrl);
          expect(response.statusCode, 200);
          expect(response.body, 'Response from test server');
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );

      test(
        'OnRequest.resolve',
        () async {
          // Tests that the interceptor resolves the request with a custom
          // response without reaching the test server.
          //
          // Test will fail when:
          // - test server receives a request
          // - client does not get the response from the interceptor

          final server = await _createTestServerExpectNoRequests();
          final client = _createClient([
            HttpInterceptorWrapper(
              onRequest: (_) => OnRequest.resolve(
                _createResponse('Response from onRequest interceptor'),
              ),
            ),
          ]);

          final response = await client.get(server.testUrl);
          expect(response.statusCode, 200);
          expect(response.body, 'Response from onRequest interceptor');
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );

      test(
        'OnRequest.resolveAndNext',
        () async {
          // Tests that the interceptor resolves the request with a custom
          // response and forwards the request to the test server.
          //
          // Test will fail when:
          // - test server does not receive the request
          // - client does not get the response from the interceptor

          final server = await _createTestServer(
            (request) => shelf.Response.ok('Response from test server'),
          );
          final client = _createClient([
            HttpInterceptorWrapper(
              onRequest: (request) => OnRequest.resolveAndNext(
                request,
                _createResponse('Response from onRequest interceptor'),
              ),
            ),
          ]);

          final response = await client.get(server.testUrl);
          expect(response.statusCode, 200);
          expect(response.body, 'Response from onRequest interceptor');
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );

      test(
        'OnRequest.reject',
        () async {
          // Tests that the interceptor rejects the request with a custom
          // error without reaching the test server.
          //
          // Test will fail when:
          // - test server receives a request
          // - client does not get the error response from the interceptor

          final server = await _createTestServerExpectNoRequests();
          final client = _createClient([
            HttpInterceptorWrapper(
              onRequest: (_) => OnRequest.reject(
                Exception('Request canceled by interceptor'),
              ),
            ),
          ]);

          try {
            await client.get(server.testUrl);
            fail('Expected an exception to be thrown');
          } catch (e) {
            expect(e.toString(), contains('Request canceled by interceptor'));
          }
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );
    });

    group('with onResponse interceptor', () {
      test(
        'OnResponse.next',
        () async {
          // Test that the interceptor modifies the response from the test server
          //
          // Test will fail when:
          // - test server does not receive the request
          // - client does not get the modified response from the interceptor

          final server = await _createTestServer(
            (request) =>
                shelf.Response.ok('Original response from test server'),
          );
          final client = _createClient([
            HttpInterceptorWrapper(
              onResponse: (response) async {
                final body = await response.stream.bytesToString();
                return OnResponse.next(_createResponse('Modified $body'));
              },
            ),
          ]);

          final response = await client.get(server.testUrl);
          expect(response.statusCode, 200);
          expect(response.body, 'Modified Original response from test server');
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );

      test(
        'OnResponse.resolve',
        () async {
          // Test that the interceptor resolves the response with a new response
          //
          // Test will fail when:
          // - test server does not receive the request
          // - client does not get the response from the interceptor

          final server = await _createTestServer(
            (_) => shelf.Response.ok('Original response from test server'),
          );
          final client = _createClient([
            HttpInterceptorWrapper(
              onResponse: (_) => OnResponse.resolve(
                _createResponse('Response from onResponse interceptor'),
              ),
            ),
          ]);

          final response = await client.get(server.testUrl);
          expect(response.statusCode, 200);
          expect(response.body, 'Response from onResponse interceptor');
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );

      test(
        'OnResponse.reject',
        () async {
          // Test that the interceptor cancels the response with an error
          //
          // Test will fail when:
          // - test server receives a request
          // - client does not get the error response from the interceptor

          final server = await _createTestServer(
            (_) => shelf.Response.ok('Original response from test server'),
          );
          final client = _createClient([
            HttpInterceptorWrapper(
              onResponse: (_) => OnResponse.reject(
                Exception('Response canceled by interceptor'),
              ),
            ),
          ]);

          try {
            await client.get(server.testUrl);
            fail('Expected an exception to be thrown');
          } catch (e) {
            expect(
              e.toString(),
              contains('Response canceled by interceptor'),
            );
          }
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );
    });

    group('with onError interceptor', () {
      test(
        'OnError.next',
        () async {
          // Test that the interceptor forwards the error to the host.
          // Making a request to an unreachable host should throw an error
          // which is then handled by the interceptor.
          //
          // Test will fail when:
          // - client does not get the error from the interceptor

          final client = _createClient([
            HttpInterceptorWrapper(
              onError: (request, _, __) => OnError.next(
                request,
                Exception('Handled error to host: ${request.url}'),
              ),
            ),
          ]);

          try {
            await client.get(Uri.https('www.not_reachable.com'));
            fail('Expected an exception to be thrown');
          } catch (e) {
            expect(
              e.toString(),
              contains(
                'Exception: Handled error to host: https://www.not_reachable.com',
              ),
            );
          }
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );

      test(
        'OnError.resolve',
        () async {
          // Test that the interceptor resolves the error with a new response.
          // Making a request to an unreachable host should throw an error
          // which is then handled by the interceptor and resolved with a
          // new response.
          //
          // Test will fail when:
          // - client does not get the response from the interceptor

          final client = _createClient([
            HttpInterceptorWrapper(
              onError: (_, __, ___) => OnError.resolve(
                _createResponse('Response from onError interceptor'),
              ),
            ),
          ]);

          final response = await client.get(Uri.https('www.not_reachable.com'));
          expect(response.statusCode, 200);
          expect(response.body, 'Response from onError interceptor');
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );

      test(
        'OnError.reject',
        () async {
          // Test that the interceptor cancels the error with an error.
          // Making a request to an unreachable host should throw an error
          // which is then handled by the interceptor and canceled with an other error.
          //
          // Test will fail when:
          // - client does not get the error from the interceptor

          final client = _createClient([
            HttpInterceptorWrapper(
              onError: (_, __, ___) =>
                  OnError.reject(Exception('Error canceled by interceptor')),
            ),
          ]);

          try {
            await client.get(Uri.https('www.not_reachable.com'));
            fail('Expected an exception to be thrown');
          } catch (e) {
            expect(e.toString(), contains('Error canceled by interceptor'));
          }
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );
    });
  });

  group('with multiple interceptors', () {
    group('multiple onRequest interceptors', () {
      test(
        'all interceptors forward request',
        () async {
          // Test that all interceptors are modifying the request.
          // Starting with a request with no custom headers, the request should
          // be modified by all interceptors and the final request should
          // contain all headers.
          //
          // Test will fail when:
          // - test server does not receive the request with all headers
          // - client does not get the response from the test server

          final server = await _createTestServer(
            (request) {
              expect(request.headers['Custom-Header-1'], 'Value1');
              expect(request.headers['Custom-Header-2'], 'Value2');
              expect(request.headers['Custom-Header-3'], 'Value3');
              return shelf.Response.ok('Response from test server');
            },
          );
          final client = _createClient([
            HttpInterceptorWrapper(
              onRequest: (request) {
                request.headers['Custom-Header-1'] = 'Value1';
                return OnRequest.next(request);
              },
            ),
            HttpInterceptorWrapper(
              onRequest: (request) {
                request.headers['Custom-Header-2'] = 'Value2';
                return OnRequest.next(request);
              },
            ),
            HttpInterceptorWrapper(
              onRequest: (request) {
                request.headers['Custom-Header-3'] = 'Value3';
                return OnRequest.next(request);
              },
            ),
          ]);

          final response = await client.get(server.testUrl);
          expect(response.statusCode, 200);
          expect(response.body, 'Response from test server');
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );

      test(
        'first interceptor resolves request',
        () async {
          // Tests that the first interceptor resolves the request with a custom
          // response without reaching the test server.
          //
          // Test will fail when:
          // - test server receives the request
          // - client does not get the response from the first interceptor
          // - second interceptor is called

          final server = await _createTestServerExpectNoRequests();
          final client = _createClient([
            HttpInterceptorWrapper(
              onRequest: (_) => OnRequest.resolve(
                _createResponse('Response from first interceptor'),
              ),
            ),
            HttpInterceptorWrapper(
              onRequest: (_) {
                fail('this interceptor should not be called');
              },
            ),
          ]);

          final response = await client.get(server.testUrl);
          expect(response.statusCode, 200);
          expect(response.body, 'Response from first interceptor');
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );

      test(
        'first interceptor resolves request and forwards it to the second interceptor',
        () async {
          // Tests that the first interceptor resolves the request with a custom
          // response and forwards it to the second interceptor.
          // Second interceptor should receive the response from the first
          // interceptor and should modify it.
          //
          // Test will fail when:
          // - test server does not receive the request
          // - client does not get the response from the first interceptor
          //   modified by the second interceptor

          final server = await _createTestServerExpectNoRequests();
          final client = _createClient([
            HttpInterceptorWrapper(
              onRequest: (_) => OnRequest.resolve(
                _createResponse('Response from first interceptor'),
                skipFollowingResponseInterceptors: false,
              ),
            ),
            HttpInterceptorWrapper(
              onResponse: (response) async {
                final body = await response.stream.bytesToString();
                return OnResponse.next(_createResponse('Modified $body'));
              },
            ),
          ]);

          final response = await client.get(server.testUrl);
          expect(response.statusCode, 200);
          expect(response.body, 'Modified Response from first interceptor');
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );

      test(
        'first interceptor rejects request',
        () async {
          // Tests that the first interceptor rejects the request with an exception
          // and the second interceptor is not called.
          //
          // Test will fail when:
          // - test server receives the request
          // - client does not get exception from the first interceptor
          // - second interceptor is called

          final server = await _createTestServerExpectNoRequests();
          final client = _createClient([
            HttpInterceptorWrapper(
              onRequest: (_) => OnRequest.reject(
                Exception('Request canceled by interceptor'),
              ),
            ),
            HttpInterceptorWrapper(
              onRequest: (_) {
                fail('this interceptor should not be called');
              },
            ),
          ]);

          try {
            await client.get(server.testUrl);
            fail('Expected an exception to be thrown');
          } catch (e) {
            expect(
              e.toString(),
              contains('Request canceled by interceptor'),
            );
          }
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );

      test(
        'first interceptor rejects request and forwards the exception to the next interceptor',
        () async {
          // Tests that the first interceptor rejects the request with an
          // exception and the second interceptor resolves the exception
          // with an custom response.
          //
          // Test will fail when:
          // - test server receives the request
          // - client receives exception from the first interceptor
          // - second interceptor does not receive the exception
          // - second interceptor does not resolve the exception with an custom response

          final server = await _createTestServerExpectNoRequests();
          final client = _createClient([
            HttpInterceptorWrapper(
              onRequest: (_) => OnRequest.reject(
                Exception('Request canceled by interceptor'),
                skipFollowingErrorInterceptors: false,
              ),
            ),
            HttpInterceptorWrapper(
              onError: (_, error, __) =>
                  OnError.resolve(_createResponse('An error occurred. $error')),
            ),
          ]);

          final response = await client.get(server.testUrl);
          expect(response.statusCode, 200);
          expect(
            response.body,
            'An error occurred. Exception: Request canceled by interceptor',
          );
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );
    });

    group('multiple onResponse interceptors', () {
      test(
        'all interceptors forward response',
        () async {
          // Tests that all interceptors forward the response to the next interceptor
          // and all interceptors are modifying the response.
          //
          // Test will fail when:
          // - test server does not receive the request
          // - response is not modified by all interceptors

          final server = await _createTestServer(
            (request) => shelf.Response.ok('original'),
          );
          final client = _createClient([
            HttpInterceptorWrapper(
              onResponse: (response) async {
                final body = await response.stream.bytesToString();
                return OnResponse.next(_createResponse('$body first'));
              },
            ),
            HttpInterceptorWrapper(
              onResponse: (response) async {
                final body = await response.stream.bytesToString();
                return OnResponse.next(_createResponse('$body second'));
              },
            ),
            HttpInterceptorWrapper(
              onResponse: (response) async {
                final body = await response.stream.bytesToString();
                return OnResponse.next(_createResponse('$body third'));
              },
            ),
          ]);

          final response = await client.get(server.testUrl);
          expect(response.statusCode, 200);
          expect(response.body, 'original first second third');
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );

      test(
        'first interceptor resolves response',
        () async {
          // Tests that the first interceptor resolves the response with a
          // custom response and the second interceptor is not called.
          //
          // Test will fail when:
          // - test server does not receive the request
          // - client does not get response from the first interceptor
          // - second interceptor is called

          final server = await _createTestServer(
            (request) =>
                shelf.Response.ok('Original response from test server'),
          );
          final client = _createClient([
            HttpInterceptorWrapper(
              onResponse: (_) => OnResponse.resolve(
                _createResponse('Response from first interceptor'),
              ),
            ),
            HttpInterceptorWrapper(
              onResponse: (_) {
                fail('This interceptor should not be called');
              },
            ),
          ]);

          final response = await client.get(server.testUrl);
          expect(response.statusCode, 200);
          expect(response.body, 'Response from first interceptor');
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );

      test(
        'first interceptor rejects response',
        () async {
          // Tests that the first interceptor rejects the response with an
          // custom error and the second interceptor is not called.
          //
          // Test will fail when:
          // - test server does not receives the request
          // - client does not get exception from the first interceptor
          // - second interceptor is called

          final server = await _createTestServer(
            (_) => shelf.Response.ok('Original response from test server'),
          );
          final client = _createClient([
            HttpInterceptorWrapper(
              onResponse: (_) => OnResponse.reject(
                Exception('Response canceled by interceptor'),
              ),
            ),
            HttpInterceptorWrapper(
              onResponse: (_) {
                fail('This interceptor should not be called');
              },
            ),
          ]);

          try {
            await client.get(server.testUrl);
            fail('Expected an exception to be thrown');
          } catch (e) {
            expect(
              e.toString(),
              contains('Exception: Response canceled by interceptor'),
            );
          }
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );

      test(
        'first interceptor rejects response and forwards the exception to the next interceptor',
        () async {
          // Tests that the first interceptor rejects the response with an
          // exception and the second interceptor resolves the exception
          // with an custom response.
          //
          // Test will fail when:
          // - test server does not receive the request
          // - client receives exception from the first interceptor
          // - second interceptor does not receive the exception
          // - second interceptor does not resolve the exception with an custom
          //   response

          final server = await _createTestServer(
            (_) => shelf.Response.ok('Original response from test server'),
          );
          final client = _createClient([
            HttpInterceptorWrapper(
              onResponse: (_) => OnResponse.reject(
                Exception('Response canceled by interceptor'),
                skipFollowingErrorInterceptors: false,
              ),
            ),
            HttpInterceptorWrapper(
              onError: (_, error, __) =>
                  OnError.resolve(_createResponse('An error occurred. $error')),
            ),
          ]);

          try {
            final response = await client.get(server.testUrl);
            expect(response.statusCode, 200);
          } catch (e) {
            expect(
              e.toString(),
              contains(
                'An error occurred. Exception: Request canceled by interceptor',
              ),
            );
          }
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );
    });

    group('multiple onError interceptors', () {
      test(
        'all interceptors forward error',
        () async {
          // Tests that all interceptors are modifying the error.
          //
          // Test will fail when:
          // - client does not get modified error

          final client = _createClient([
            HttpInterceptorWrapper(
              onError: (request, _, __) =>
                  OnError.next(request, Exception('first')),
            ),
            HttpInterceptorWrapper(
              onError: (request, error, _) =>
                  OnError.next(request, Exception('$error second')),
            ),
            HttpInterceptorWrapper(
              onError: (request, error, _) =>
                  OnError.next(request, Exception('$error third')),
            ),
          ]);

          try {
            await client.get(Uri.https('www.not_reachable.com'));
            fail('Expected an exception to be thrown');
          } catch (e) {
            expect(
              e.toString(),
              'Exception: Exception: Exception: first second third',
            );
          }
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );

      test(
        'first interceptor resolves error',
        () async {
          // Tests that the first interceptor resolves the error with a
          // custom response and the second interceptor is not called.
          //
          // Test will fail when:
          // - client does not get response from the first interceptor
          // - second interceptor is called

          final client = _createClient([
            HttpInterceptorWrapper(
              onError: (_, __, ___) => OnError.resolve(
                _createResponse('Response from first interceptor'),
              ),
            ),
            HttpInterceptorWrapper(
              onError: (_, __, ___) {
                fail('This interceptor should not be called');
              },
            ),
          ]);

          final response = await client.get(Uri.https('www.not_reachable.com'));
          expect(response.statusCode, 200);
          expect(response.body, 'Response from first interceptor');
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );

      test(
        'first interceptor rejects error',
        () async {
          // Tests that the first interceptor rejects the error with an
          // custom error and the second interceptor is not called.
          //
          // Test will fail when:
          // - client does not get exception from the first interceptor
          // - second interceptor is called

          final client = _createClient([
            HttpInterceptorWrapper(
              onError: (_, error, __) =>
                  OnError.reject(Exception('Error canceled by interceptor')),
            ),
            HttpInterceptorWrapper(
              onError: (_, __, ___) {
                fail('This interceptor should not be called');
              },
            ),
          ]);

          try {
            await client.get(Uri.https('www.not_reachable.com'));
            fail('Expected an exception to be thrown');
          } catch (e) {
            expect(
              e.toString(),
              contains(
                'Exception: Error canceled by interceptor',
              ),
            );
          }
        },
        timeout: const Timeout(Duration(seconds: 2)),
      );
    });
  });
}

/// Creates and configures a [ShelfTestServer] for testing HTTP interactions.
///
/// Takes a [callback] that returns the [shelf.Response] to be send when the
/// server receives a request.
///
/// Parameters:
/// - [callback]: The shelf.Response to return for matching requests
///
/// The server is automatically closed during test teardown.
/// Uses [expectAsync1] to ensure the callback is called during testing.
///
/// Returns a [Future] that completes with the configured [ShelfTestServer].
Future<ShelfTestServer> _createTestServer(
  FutureOr<shelf.Response> Function(shelf.Request request) callback,
) async {
  final server = await ShelfTestServer.create();
  addTearDown(server.close);
  server.handler.expect('GET', '/test', expectAsync1(callback));
  return server;
}

/// Creates a [ShelfTestServer] that fails the test if it receives any request.
///
/// Useful for verifying that no unexpected HTTP requests are made during a test.
/// The server is automatically closed during test teardown.
///
/// Returns a [Future] that completes with the configured [ShelfTestServer].
Future<ShelfTestServer> _createTestServerExpectNoRequests() async {
  final server = await ShelfTestServer.create();
  addTearDown(server.close);
  server.handler.expectAnything((request) {
    fail(
      'Unexpected request received: ${request.method} ${request.url}',
    );
  });
  return server;
}

/// Creates a [HttpClientProxy] with the provided [interceptors].
///
/// The client is automatically closed during test teardown.
http.Client _createClient(List<HttpInterceptor> interceptors) {
  final client = HttpClientProxy(interceptors: interceptors);
  addTearDown(client.close);
  return client;
}

/// Creates a [http.Response] with the provided [body], [statusCode], and [headers].
http.StreamedResponse _createResponse(
  String body, {
  int statusCode = 200,
  Map<String, String> headers = const {},
}) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      statusCode,
      headers: headers,
    );

/// Extension on [ShelfTestServer] to provide a convenience method for creating the test URL.
extension _TestUrl on ShelfTestServer {
  /// Returns a [Uri] for the '/test' path on the test server.
  Uri get testUrl => url.replace(path: '/test');
}
