import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_intercept/http_intercept.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_test_handler/shelf_test_handler.dart';
import 'package:test/test.dart';

void main() {
  group('HttpClientProxy', () {
    test('simple request-response without interceptors', () async {
      // Create a test server
      final server = await ShelfTestServer.create();
      addTearDown(server.close);

      // Define the server handler
      server.handler.expect(
        'GET',
        '/test',
        (_) => shelf.Response.ok('Response from test server'),
      );

      // Run the test with HttpClientProxy
      await http.runWithClient(
        () async {
          final url = server.url.replace(path: '/test');
          final response = await http.get(url);
          expect(response.statusCode, 200);
          expect(response.body, 'Response from test server');
        },
        HttpClientProxy.new,
      );
    });

    group('with onRequest interceptor', () {
      test('forwards request', () async {
        // Create a test server
        final server = await ShelfTestServer.create();
        addTearDown(server.close);

        // Define the server handler
        server.handler.expect(
          'GET',
          '/test',
          (request) {
            expect(request.headers['Custom-Header'], 'Value');
            return shelf.Response.ok('Response from test server');
          },
        );

        // Define the onRequest interceptor
        final onRequestInterceptor = HttpInterceptorWrapper(
          onRequest: (request) {
            request.headers['Custom-Header'] = 'Value';
            return OnRequest.next(request);
          },
        );

        // Run the test with HttpClientProxy and onRequest interceptor
        await http.runWithClient(
          () async {
            final url = server.url.replace(path: '/test');
            final response = await http.get(url);
            expect(response.statusCode, 200);
            expect(response.body, 'Response from test server');
          },
          () => HttpClientProxy(interceptors: [onRequestInterceptor]),
        );
      });

      test('resolves request with new response', () async {
        // Create a test server
        final server = await ShelfTestServer.create();
        addTearDown(server.close);

        // Define the onRequest interceptor
        final onRequestInterceptor = HttpInterceptorWrapper(
          onRequest: (request) {
            final stream = Stream.value(
              utf8.encode('Response from onRequest interceptor'),
            );
            final resolvedResponse = http.StreamedResponse(stream, 200);
            return OnRequest.resolve(resolvedResponse);
          },
        );

        // Run the test with HttpClientProxy and onRequest interceptor
        await http.runWithClient(
          () async {
            final url = server.url.replace(path: '/test');
            final response = await http.get(url);
            expect(response.statusCode, 200);
            expect(response.body, 'Response from onRequest interceptor');
          },
          () => HttpClientProxy(interceptors: [onRequestInterceptor]),
        );
      });

      test('cancels request with error', () async {
        // Create a test server
        final server = await ShelfTestServer.create();
        addTearDown(server.close);

        // Define the onRequest interceptor
        final onRequestInterceptor = HttpInterceptorWrapper(
          onRequest: (request) => OnRequest.reject(
            Exception('Request canceled by interceptor'),
          ),
        );

        // Run the test with HttpClientProxy and onRequest interceptor
        await http.runWithClient(
          () async {
            final url = server.url.replace(path: '/test');
            try {
              await http.get(url);
              fail('Expected an exception to be thrown');
            } catch (e) {
              expect(e.toString(), contains('Request canceled by interceptor'));
            }
          },
          () => HttpClientProxy(interceptors: [onRequestInterceptor]),
        );
      });
    });

    group('with onResponse interceptor', () {
      test('forwards response', () async {
        // Create a test server
        final server = await ShelfTestServer.create();
        addTearDown(server.close);

        // Define the server handler
        server.handler.expect(
          'GET',
          '/test',
          (_) => shelf.Response.ok('Original response from test server'),
        );

        // Define the onResponse interceptor
        final onResponseInterceptor = HttpInterceptorWrapper(
          onResponse: (response) async {
            final modifiedStream =
                Stream.value(utf8.encode('Modified response from interceptor'));
            final modifiedResponse = http.StreamedResponse(
              modifiedStream,
              response.statusCode,
              headers: response.headers,
            );
            return OnResponse.next(modifiedResponse);
          },
        );

        // Run the test with HttpClientProxy and onResponse interceptor
        await http.runWithClient(
          () async {
            final url = server.url.replace(path: '/test');
            final response = await http.get(url);
            expect(response.statusCode, 200);
            expect(response.body, 'Modified response from interceptor');
          },
          () => HttpClientProxy(interceptors: [onResponseInterceptor]),
        );
      });

      test('resolves response with new response', () async {
        // Create a test server
        final server = await ShelfTestServer.create();
        addTearDown(server.close);

        // Define the server handler
        server.handler.expect(
          'GET',
          '/test',
          (_) => shelf.Response.ok('Original response from test server'),
        );

        // Define the onResponse interceptor
        final onResponseInterceptor = HttpInterceptorWrapper(
          onResponse: (response) async {
            final stream = Stream.value(
              utf8.encode('Response from onResponse interceptor'),
            );
            final resolvedResponse =
                http.StreamedResponse(stream, 200, headers: response.headers);
            return OnResponse.resolve(resolvedResponse);
          },
        );

        // Run the test with HttpClientProxy and onResponse interceptor
        await http.runWithClient(
          () async {
            final url = server.url.replace(path: '/test');
            final response = await http.get(url);
            expect(response.statusCode, 200);
            expect(response.body, 'Response from onResponse interceptor');
          },
          () => HttpClientProxy(interceptors: [onResponseInterceptor]),
        );
      });

      test('cancels response with error', () async {
        // Create a test server
        final server = await ShelfTestServer.create();
        addTearDown(server.close);

        // Define the server handler
        server.handler.expect(
          'GET',
          '/test',
          (_) => shelf.Response.ok('Original response from test server'),
        );

        // Define the onResponse interceptor
        final onResponseInterceptor = HttpInterceptorWrapper(
          onResponse: (response) => OnResponse.reject(
            Exception('Response canceled by interceptor'),
          ),
        );

        // Run the test with HttpClientProxy and onResponse interceptor
        await http.runWithClient(
          () async {
            final url = server.url.replace(path: '/test');
            try {
              await http.get(url);
              fail('Expected an exception to be thrown');
            } catch (e) {
              expect(
                e.toString(),
                contains('Response canceled by interceptor'),
              );
            }
          },
          () => HttpClientProxy(interceptors: [onResponseInterceptor]),
        );
      });
    });

    group('with onError interceptor', () {
      test('forwards error', () async {
        // Define the onError interceptor
        final onErrorInterceptor = HttpInterceptorWrapper(
          onError: (request, error, stackTrace) {
            print('error: $error');
            final modifiedError = Exception('Handled $error');
            return OnError.next(request, modifiedError, stackTrace);
          },
        );

        // Run the test with HttpClientProxy and onError interceptor
        await http.runWithClient(
          () async {
            final url = Uri.https('www.notreacheble.com');
            try {
              await http.get(url);
              fail('Expected an exception to be thrown');
            } catch (e) {
              expect(
                e.toString(),
                contains(
                  'Exception: Handled ClientException with SocketException',
                ),
              );
            }
          },
          () => HttpClientProxy(interceptors: [onErrorInterceptor]),
        );
      });

      test('resolves error with new response', () async {
        // Define the onError interceptor
        final onErrorInterceptor = HttpInterceptorWrapper(
          onError: (request, error, stackTrace) {
            final stream =
                Stream.value(utf8.encode('Response from onError interceptor'));
            final resolvedResponse = http.StreamedResponse(stream, 200);
            return OnError.resolve(resolvedResponse);
          },
        );

        // Run the test with HttpClientProxy and onError interceptor
        await http.runWithClient(
          () async {
            final url = Uri.https('www.notreacheble.com');
            final response = await http.get(url);
            expect(response.statusCode, 200);
            expect(response.body, 'Response from onError interceptor');
          },
          () => HttpClientProxy(interceptors: [onErrorInterceptor]),
        );
      });

      test('cancels error with new error', () async {
        // Define the onError interceptor
        final onErrorInterceptor = HttpInterceptorWrapper(
          onError: (request, error, stackTrace) => OnError.reject(
            Exception('Error canceled by interceptor'),
            stackTrace,
          ),
        );

        // Run the test with HttpClientProxy and onError interceptor
        await http.runWithClient(
          () async {
            final url = Uri.https('www.notreacheble.com');
            try {
              await http.get(url);
              fail('Expected an exception to be thrown');
            } catch (e) {
              expect(e.toString(), contains('Error canceled by interceptor'));
            }
          },
          () => HttpClientProxy(interceptors: [onErrorInterceptor]),
        );
      });
    });
  });

  group('with multiple interceptors', () {
    test('all interceptors forward request', () async {
      // Create a test server
      final server = await ShelfTestServer.create();
      addTearDown(server.close);

      // Define the server handler
      server.handler.expect(
        'GET',
        '/test',
        (request) {
          expect(request.headers['Custom-Header-1'], 'Value1');
          expect(request.headers['Custom-Header-2'], 'Value2');
          expect(request.headers['Custom-Header-3'], 'Value3');
          return shelf.Response.ok('Response from test server');
        },
      );

      // Define the interceptors
      final interceptors = [
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
      ];

      // Run the test with HttpClientProxy and interceptors
      await http.runWithClient(
        () async {
          final url = server.url.replace(path: '/test');
          final response = await http.get(url);
          expect(response.statusCode, 200);
          expect(response.body, 'Response from test server');
        },
        () => HttpClientProxy(interceptors: interceptors),
      );
    });

    test('first interceptor resolves request', () async {
      // Create a test server
      final server = await ShelfTestServer.create();
      addTearDown(server.close);

      // Define the interceptors
      final interceptors = [
        HttpInterceptorWrapper(
          onRequest: (request) {
            final stream =
                Stream.value(utf8.encode('Response from first interceptor'));
            final resolvedResponse = http.StreamedResponse(stream, 200);
            return OnRequest.resolve(resolvedResponse);
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
      ];

      // Run the test with HttpClientProxy and interceptors
      await http.runWithClient(
        () async {
          final url = server.url.replace(path: '/test');
          final response = await http.get(url);
          expect(response.statusCode, 200);
          expect(response.body, 'Response from first interceptor');
        },
        () => HttpClientProxy(interceptors: interceptors),
      );
    });

    test('second interceptor cancels request with error', () async {
      // Create a test server
      final server = await ShelfTestServer.create();
      addTearDown(server.close);

      // Define the interceptors
      final interceptors = [
        HttpInterceptorWrapper(
          onRequest: (request) {
            request.headers['Custom-Header-1'] = 'Value1';
            return OnRequest.next(request);
          },
        ),
        HttpInterceptorWrapper(
          onRequest: (request) => OnRequest.reject(
            Exception('Request canceled by second interceptor'),
          ),
        ),
        HttpInterceptorWrapper(
          onRequest: (request) {
            request.headers['Custom-Header-3'] = 'Value3';
            return OnRequest.next(request);
          },
        ),
      ];

      // Run the test with HttpClientProxy and interceptors
      await http.runWithClient(
        () async {
          final url = server.url.replace(path: '/test');
          try {
            await http.get(url);
            fail('Expected an exception to be thrown');
          } catch (e) {
            expect(
              e.toString(),
              contains('Request canceled by second interceptor'),
            );
          }
        },
        () => HttpClientProxy(interceptors: interceptors),
      );
    });

    test('all interceptors forward response', () async {
      // Create a test server
      final server = await ShelfTestServer.create();
      addTearDown(server.close);

      // Define the server handler
      server.handler.expect(
        'GET',
        '/test',
        (_) => shelf.Response.ok('Original response from test server'),
      );

      // Define the interceptors
      final interceptors = [
        HttpInterceptorWrapper(
          onResponse: (response) async {
            final modifiedStream = Stream.value(
              utf8.encode('Modified response from first interceptor'),
            );
            final modifiedResponse = http.StreamedResponse(
              modifiedStream,
              response.statusCode,
              headers: response.headers,
            );
            return OnResponse.next(modifiedResponse);
          },
        ),
        HttpInterceptorWrapper(
          onResponse: (response) async {
            final modifiedStream = Stream.value(
              utf8.encode('Modified response from second interceptor'),
            );
            final modifiedResponse = http.StreamedResponse(
              modifiedStream,
              response.statusCode,
              headers: response.headers,
            );
            return OnResponse.next(modifiedResponse);
          },
        ),
        HttpInterceptorWrapper(
          onResponse: (response) async {
            final modifiedStream = Stream.value(
              utf8.encode('Modified response from third interceptor'),
            );
            final modifiedResponse = http.StreamedResponse(
              modifiedStream,
              response.statusCode,
              headers: response.headers,
            );
            return OnResponse.next(modifiedResponse);
          },
        ),
      ];

      // Run the test with HttpClientProxy and interceptors
      await http.runWithClient(
        () async {
          final url = server.url.replace(path: '/test');
          final response = await http.get(url);
          expect(response.statusCode, 200);
          expect(response.body, 'Modified response from third interceptor');
        },
        () => HttpClientProxy(interceptors: interceptors),
      );
    });

    test('first interceptor resolves response', () async {
      // Create a test server
      final server = await ShelfTestServer.create();
      addTearDown(server.close);

      // Define the server handler
      server.handler.expect(
        'GET',
        '/test',
        (_) => shelf.Response.ok('Original response from test server'),
      );

      // Define the interceptors
      final interceptors = [
        HttpInterceptorWrapper(
          onResponse: (response) async {
            final stream =
                Stream.value(utf8.encode('Response from first interceptor'));
            final resolvedResponse =
                http.StreamedResponse(stream, 200, headers: response.headers);
            return OnResponse.resolve(resolvedResponse);
          },
        ),
        HttpInterceptorWrapper(
          onResponse: (response) async {
            final modifiedStream = Stream.value(
              utf8.encode('Modified response from second interceptor'),
            );
            final modifiedResponse = http.StreamedResponse(
              modifiedStream,
              response.statusCode,
              headers: response.headers,
            );
            return OnResponse.next(modifiedResponse);
          },
        ),
        HttpInterceptorWrapper(
          onResponse: (response) async {
            final modifiedStream = Stream.value(
              utf8.encode('Modified response from third interceptor'),
            );
            final modifiedResponse = http.StreamedResponse(
              modifiedStream,
              response.statusCode,
              headers: response.headers,
            );
            return OnResponse.next(modifiedResponse);
          },
        ),
      ];

      // Run the test with HttpClientProxy and interceptors
      await http.runWithClient(
        () async {
          final url = server.url.replace(path: '/test');
          final response = await http.get(url);
          expect(response.statusCode, 200);
          expect(response.body, 'Response from first interceptor');
        },
        () => HttpClientProxy(interceptors: interceptors),
      );
    });

    test('second interceptor cancels response with error', () async {
      // Create a test server
      final server = await ShelfTestServer.create();
      addTearDown(server.close);

      // Define the server handler
      server.handler.expect(
        'GET',
        '/test',
        (_) => shelf.Response.ok('Original response from test server'),
      );

      // Define the interceptors
      final interceptors = [
        HttpInterceptorWrapper(
          onResponse: (response) async {
            final modifiedStream = Stream.value(
              utf8.encode('Modified response from first interceptor'),
            );
            final modifiedResponse = http.StreamedResponse(
              modifiedStream,
              response.statusCode,
              headers: response.headers,
            );
            return OnResponse.next(modifiedResponse);
          },
        ),
        HttpInterceptorWrapper(
          onResponse: (response) => OnResponse.reject(
            Exception('Response canceled by second interceptor'),
          ),
        ),
        HttpInterceptorWrapper(
          onResponse: (response) async {
            final modifiedStream = Stream.value(
              utf8.encode('Modified response from third interceptor'),
            );
            final modifiedResponse = http.StreamedResponse(
              modifiedStream,
              response.statusCode,
              headers: response.headers,
            );
            return OnResponse.next(modifiedResponse);
          },
        ),
      ];

      // Run the test with HttpClientProxy and interceptors
      await http.runWithClient(
        () async {
          final url = server.url.replace(path: '/test');
          try {
            await http.get(url);
            fail('Expected an exception to be thrown');
          } catch (e) {
            expect(
              e.toString(),
              contains('Response canceled by second interceptor'),
            );
          }
        },
        () => HttpClientProxy(interceptors: interceptors),
      );
    });

    test('all interceptors forward error', () async {
      // Define the interceptors
      final interceptors = [
        HttpInterceptorWrapper(
          onError: (request, error, stackTrace) {
            final modifiedError =
                Exception('Handled by first interceptor: $error');
            return OnError.next(request, modifiedError, stackTrace);
          },
        ),
        HttpInterceptorWrapper(
          onError: (request, error, stackTrace) {
            final modifiedError =
                Exception('Handled by second interceptor: $error');
            return OnError.next(request, modifiedError, stackTrace);
          },
        ),
        HttpInterceptorWrapper(
          onError: (request, error, stackTrace) {
            final modifiedError =
                Exception('Handled by third interceptor: $error');
            return OnError.next(request, modifiedError, stackTrace);
          },
        ),
      ];

      // Run the test with HttpClientProxy and interceptors
      await http.runWithClient(
        () async {
          final url = Uri.https('www.notreacheble.com');
          try {
            await http.get(url);
            fail('Expected an exception to be thrown');
          } catch (e) {
            expect(e.toString(), contains('Handled by third interceptor'));
          }
        },
        () => HttpClientProxy(interceptors: interceptors),
      );
    });

    test('first interceptor resolves error with new response', () async {
      // Define the interceptors
      final interceptors = [
        HttpInterceptorWrapper(
          onError: (request, error, stackTrace) {
            final stream =
                Stream.value(utf8.encode('Response from first interceptor'));
            final resolvedResponse = http.StreamedResponse(stream, 200);
            return OnError.resolve(resolvedResponse);
          },
        ),
        HttpInterceptorWrapper(
          onError: (request, error, stackTrace) {
            final modifiedError =
                Exception('Handled by second interceptor: $error');
            return OnError.next(request, modifiedError, stackTrace);
          },
        ),
        HttpInterceptorWrapper(
          onError: (request, error, stackTrace) {
            final modifiedError =
                Exception('Handled by third interceptor: $error');
            return OnError.next(request, modifiedError, stackTrace);
          },
        ),
      ];

      // Run the test with HttpClientProxy and interceptors
      await http.runWithClient(
        () async {
          final url = Uri.https('www.notreacheble.com');
          final response = await http.get(url);
          expect(response.statusCode, 200);
          expect(response.body, 'Response from first interceptor');
        },
        () => HttpClientProxy(interceptors: interceptors),
      );
    });

    test('second interceptor cancels error with new error', () async {
      // Define the interceptors
      final interceptors = [
        HttpInterceptorWrapper(
          onError: (request, error, stackTrace) {
            final modifiedError =
                Exception('Handled by first interceptor: $error');
            return OnError.next(request, modifiedError, stackTrace);
          },
        ),
        HttpInterceptorWrapper(
          onError: (request, error, stackTrace) => OnError.reject(
            Exception('Error canceled by second interceptor'),
            stackTrace,
          ),
        ),
        HttpInterceptorWrapper(
          onError: (request, error, stackTrace) {
            final modifiedError =
                Exception('Handled by third interceptor: $error');
            return OnError.next(request, modifiedError, stackTrace);
          },
        ),
      ];

      // Run the test with HttpClientProxy and interceptors
      await http.runWithClient(
        () async {
          final url = Uri.https('www.notreacheble.com');
          try {
            await http.get(url);
            fail('Expected an exception to be thrown');
          } catch (e) {
            expect(
              e.toString(),
              contains('Error canceled by second interceptor'),
            );
          }
        },
        () => HttpClientProxy(interceptors: interceptors),
      );
    });
  });
}
