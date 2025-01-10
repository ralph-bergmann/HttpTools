import 'package:http/http.dart' as http;

/// Extension to add copyWith method to StreamedResponse
extension StreamedResponseExtension on http.StreamedResponse {
  /// Create a copy of the [http.StreamedResponse] with modified headers.
  /// Useful if you want to modify cache-control headers.
  /// You can change the cache-control headers to make not cacheable responses
  /// cacheable, for example.
  http.StreamedResponse copyWith({Map<String, String>? headers}) =>
      http.StreamedResponse(
        stream,
        statusCode,
        contentLength: contentLength,
        request: request,
        headers: headers ?? this.headers,
        isRedirect: isRedirect,
        persistentConnection: persistentConnection,
        reasonPhrase: reasonPhrase,
      );
}
