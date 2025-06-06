import 'dart:collection';
import 'dart:io';

import 'package:http/http.dart';
import 'package:uuid/uuid.dart';

import 'base_request_extensions.dart';
import 'cache_control.dart';

/// Extension methods for the [BaseResponse] class to provide additional
/// functionality related to caching.
extension BaseResponseExtensions on BaseResponse {
  /// UUID generator for unique identifiers.
  static const _uuid = Uuid();

  /// The primary cache key, which is derived from the request URL.
  /// This key is used to identify the main entry in the cache.
  ///
  /// The primary cache key is generated by hashing the URL using UUID v5 to
  /// ensure a unique and consistent identifier.
  ///
  /// Example:
  /// Given the URL: "https://example.com/api/data"
  /// The primary cache key would be a UUID v5 hash of this URL.
  String? get primaryCacheKey => request?.cacheKey;

  /// The secondary cache key, which is constructed from the URL and vary
  /// headers. This key is used to uniquely identify different variations of
  /// the same URL based on the request headers that affect the response.
  ///
  /// The secondary cache key is built by normalizing the URL and concatenating
  /// it with a serialized representation of the vary headers. The vary headers
  /// are sorted by name and concatenated in a key-value format. This combined
  /// string is then hashed using UUID v5 to generate a unique identifier.
  ///
  /// Example:
  /// Given the URL: "https://example.com/api/data"
  /// And vary headers: { "Accept": "application/json", "Authorization": "Bearer token" }
  /// The combined string would be:
  /// "https://example.com/api/data|Accept:application/json,Authorization:Bearer token"
  /// The secondary cache key would be a UUID v5 hash of this string.
  String? get secondaryCacheKey {
    final url = request?.url.toString();
    if (url == null) {
      return null;
    }

    final vary = varyHeaders.entries
        .map((entry) => '${entry.key}:${entry.value}')
        .join(',');
    final combinedString = '$url|$vary';
    return _uuid.v5(Namespace.url.value, combinedString);
  }

  /// Returns the names of the request headers that need to be checked for
  /// equality when caching.
  ///
  /// This method uses a [SplayTreeSet] from the `package:collection` to ensure
  /// that the header names are stored in a sorted order, which helps in
  /// consistent comparison and retrieval.
  ///
  /// This method uses a [SplayTreeSet] from the `package:collection` to ensure
  /// that the header names are stored in a sorted order, which helps in
  /// consistent comparison and retrieval.
  Set<String> get varyFields {
    final varyHeader = headers[HttpHeaders.varyHeader];
    if (varyHeader == null || varyHeader.isEmpty) {
      return {};
    }
    return SplayTreeSet<String>.from(
      varyHeader.split(',').map((field) => field.trim().toLowerCase()),
    );
  }

  /// Returns a map of the vary headers and their values from the request.
  ///
  /// This map is constructed by iterating over the vary fields and retrieving
  /// their corresponding values from the request headers.
  ///
  /// Example:
  /// Given the vary fields: {"accept", "authorization"}
  /// And request headers: { "accept": "application/json", "authorization": "Bearer token" }
  /// The returned map would be: { "accept": "application/json", "authorization": "Bearer token" }
  Map<String, String> get varyHeaders => Map.fromEntries(
        varyFields
            .where((field) => request?.headers.containsKey(field) ?? false)
            .map((field) => MapEntry(field, request?.headers[field] ?? '')),
      );

  /// Checks if the response has a 'Vary' header with a value of '*'.
  ///
  /// The 'Vary' header in HTTP responses indicates which headers a cache
  /// should consider when deciding if a cached response can be used for
  /// subsequent requests. A 'Vary' header with a value of '*' means that
  /// the response varies based on all request headers, making it essentially
  /// uncacheable.
  ///
  /// Returns `true` if the 'Vary' header contains '*', indicating that the
  /// response varies based on all request headers. Otherwise, returns `false`.
  bool hasVaryAll() => varyFields.contains('*');

  CacheControl? get cacheControl {
    final cacheControlHeader = headers[HttpHeaders.cacheControlHeader];
    if (cacheControlHeader != null) {
      return CacheControl.parse(cacheControlHeader);
    }
    return null;
  }

  bool get isPrivate => cacheControl?.private ?? false;
}
