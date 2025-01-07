import 'package:http/http.dart';
import 'package:uuid/uuid.dart';

extension BaseRequestExtensions on BaseRequest {
  /// UUID generator for unique identifiers.
  static const _uuid = Uuid();

  /// The cache key, which is derived from the request URL.
  /// This key is used to identify the main entry in the cache.
  ///
  /// The cache key is generated by hashing the URL using UUID v5 to
  /// ensure a unique and consistent identifier.
  ///
  /// Example:
  /// Given the URL: "https://example.com/api/data"
  /// The cache key would be a UUID v5 hash of this URL.
  String get cacheKey => _uuid.v5(Uuid.NAMESPACE_URL, url.toString());
}
