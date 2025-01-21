/// Represents the Cache-Control HTTP header directives that control caching
/// behavior.
///
/// This class parses and manages standard Cache-Control directives including:
/// - Time-based controls (max-age, stale-while-revalidate, stale-if-error)
/// - Cache visibility (public, private)
/// - Cache behavior flags (no-cache, no-store, must-revalidate, immutable)
class CacheControl {
  CacheControl._({
    this.maxAge,
    this.noCache,
    this.noStore,
    this.mustRevalidate,
    this.private,
    this.public,
    this.immutable,
    this.staleWhileRevalidate,
    this.staleIfError,
  });

  /// Creates a CacheControl instance by parsing a Cache-Control header string.
  ///
  /// Handles both value-based directives like 'max-age=3600' and flag
  /// directives like 'public'.
  /// Duration values are parsed from seconds into Duration objects.
  ///
  /// Example header: 'max-age=3600, public, no-cache'
  factory CacheControl.parse(String header) {
    Duration? maxAge;
    bool? noCache;
    bool? noStore;
    bool? mustRevalidate;
    bool? private;
    bool? public;
    bool? immutable;
    Duration? staleWhileRevalidate;
    Duration? staleIfError;

    final directives = header.split(',');
    for (final directive in directives) {
      final parts = directive.trim().split('=');
      final key = parts[0].trim();
      final value = parts.length > 1 ? parts[1].trim() : null;

      switch (key) {
        case _maxAgeDirective:
          if (value != null) {
            final seconds = int.tryParse(value);
            if (seconds != null && seconds >= 0) {
              maxAge = Duration(seconds: seconds);
            }
          }
        case _noCacheDirective:
          noCache = true;
        case _noStoreDirective:
          noStore = true;
        case _mustRevalidateDirective:
          mustRevalidate = true;
        case _privateDirective:
          private = true;
        case _publicDirective:
          public = true;
        case _immutableDirective:
          immutable = true;
        case _staleWhileRevalidateDirective:
          if (value != null) {
            final seconds = int.tryParse(value);
            if (seconds != null) {
              staleWhileRevalidate = Duration(seconds: seconds);
            }
          }
        case _staleIfErrorDirective:
          if (value != null) {
            final seconds = int.tryParse(value);
            if (seconds != null) {
              staleIfError = Duration(seconds: seconds);
            }
          }
      }
    }

    return CacheControl._(
      maxAge: maxAge,
      noCache: noCache,
      noStore: noStore,
      mustRevalidate: mustRevalidate,
      private: private,
      public: public,
      immutable: immutable,
      staleWhileRevalidate: staleWhileRevalidate,
      staleIfError: staleIfError,
    );
  }

  /// Creates a Cache-Control header for static assets like images
  /// that rarely change. Uses max-age with immutable flag for optimal caching.
  factory CacheControl.staticAsset({
    Duration maxAge = const Duration(days: 365),
    Duration? staleWhileRevalidate,
    Duration? staleIfError,
  }) =>
      CacheControl._(
        maxAge: maxAge,
        immutable: true,
        public: true,
        staleWhileRevalidate: staleWhileRevalidate,
        staleIfError: staleIfError,
      );

  /// Creates a Cache-Control header for dynamic but cacheable API responses
  /// with background revalidation for optimal performance.
  factory CacheControl.dynamicContent({
    required Duration maxAge,
    Duration staleWhileRevalidate = const Duration(minutes: 5),
    Duration? staleIfError,
  }) =>
      CacheControl._(
        maxAge: maxAge,
        staleWhileRevalidate: staleWhileRevalidate,
        staleIfError: staleIfError,
        public: true,
      );

  /// Creates a Cache-Control header that requires revalidation with the origin
  /// server before using cached content. The response CAN be stored in caches,
  /// but MUST be validated on each use.
  ///
  /// Use this when content might change and clients need fresh data, but storing
  /// in cache is acceptable and (like API responses that update frequently).
  ///
  /// Performance benefit: Allows caches to store the response and send a
  /// conditional request (If-None-Match/If-Modified-Since) to validate.
  /// When content hasn't changed, the server responds with 304 Not Modified
  /// without sending the full response body, saving bandwidth.
  factory CacheControl.noCache() =>
      CacheControl._(noCache: true, mustRevalidate: true);

  /// Creates a Cache-Control header that prevents storing the response in any cache.
  /// The response MUST NOT be stored in any cache (private or shared).
  ///
  /// Use this for sensitive data like personal information, authentication
  /// tokens, or banking details that should never persist in any cache.
  factory CacheControl.noStore() => CacheControl._(noStore: true);

  /// Creates a new CacheControl instance with updated directive values.
  ///
  /// Useful for modifying specific directives while preserving others.
  /// Returns a new instance, keeping the original immutable.
  ///
  /// Example:
  /// ```dart
  /// final newControl = originalControl.copyWith(maxAge: Duration(hours: 1));
  /// ```
  CacheControl copyWith({
    Duration? maxAge,
    bool? noCache,
    bool? noStore,
    bool? mustRevalidate,
    bool? private,
    bool? public,
    bool? immutable,
    Duration? staleWhileRevalidate,
    Duration? staleIfError,
  }) =>
      CacheControl._(
        maxAge: maxAge ?? this.maxAge,
        noCache: noCache ?? this.noCache,
        noStore: noStore ?? this.noStore,
        mustRevalidate: mustRevalidate ?? this.mustRevalidate,
        private: private ?? this.private,
        public: public ?? this.public,
        immutable: immutable ?? this.immutable,
        staleWhileRevalidate: staleWhileRevalidate ?? this.staleWhileRevalidate,
        staleIfError: staleIfError ?? this.staleIfError,
      );

  /// Generates a valid Cache-Control header string from the current directives.
  ///
  /// Includes only the directives that are explicitly set.
  /// Duration values are converted back to seconds.
  ///
  /// Example output: 'max-age=3600, public, stale-while-revalidate=60'
  @override
  String toString() {
    final directives = <String>[];

    if (maxAge != null) {
      directives.add('$_maxAgeDirective=${maxAge!.inSeconds}');
    }
    if (noCache ?? false) {
      directives.add(_noCacheDirective);
    }
    if (noStore ?? false) {
      directives.add(_noStoreDirective);
    }
    if (mustRevalidate ?? false) {
      directives.add(_mustRevalidateDirective);
    }
    if (private ?? false) {
      directives.add(_privateDirective);
    }
    if (public ?? false) {
      directives.add(_publicDirective);
    }
    if (immutable ?? false) {
      directives.add(_immutableDirective);
    }
    if (staleWhileRevalidate != null) {
      directives.add(
        '$_staleWhileRevalidateDirective=${staleWhileRevalidate!.inSeconds}',
      );
    }
    if (staleIfError != null) {
      directives.add('$_staleIfErrorDirective=${staleIfError!.inSeconds}');
    }

    return directives.join(', ');
  }

  /// Maximum time in seconds the resource is considered fresh
  final Duration? maxAge;

  /// Forces validation with origin server before using cached response
  final bool? noCache;

  /// Prevents storing the response in any cache
  final bool? noStore;

  /// Requires origin server validation when resource becomes stale
  final bool? mustRevalidate;

  /// Response is specific to a user and not for shared caches
  final bool? private;

  /// Response may be cached by any cache (shared or private)
  final bool? public;

  /// Response content will not change during its freshness lifetime
  final bool? immutable;

  /// Time window during which a cache can serve stale content while fetching
  /// a fresh version in the background. This enables "background revalidation"
  /// where users get fast responses while updates happen asynchronously.
  ///
  /// Example: stale-while-revalidate=60 allows serving cached content for up
  /// to 60 seconds while a fresh version is being fetched, eliminating user
  /// wait time.
  ///
  /// Timeline example with max-age=60, stale-while-revalidate=30, stale-if-error=300:
  /// - 0-60s: Content is fresh, served directly
  /// - 60-90s: Content is stale but can be served while revalidating
  /// - 60-360s: If server errors occur during revalidation, stale content can be served
  /// - >90s: Must serve fresh content (unless there's an error within the stale-if-error window)
  /// - >360s: Must serve error response
  final Duration? staleWhileRevalidate;

  /// Time window during which a cache can serve stale content when the origin
  /// server returns errors. Acts as a fallback mechanism during outages or
  /// network issues to maintain service availability.
  ///
  /// Example: stale-if-error=3600 allows using cached content for up to 1 hour
  /// when the server is unavailable, preventing error pages during downtime.
  ///
  /// Timeline example with max-age=60, stale-while-revalidate=30, stale-if-error=300:
  /// - 0-60s: Content is fresh, served directly
  /// - 60-90s: Content is stale but can be served while revalidating
  /// - 60-360s: If server errors occur during revalidation, stale content can be served
  /// - >90s: Must serve fresh content (unless there's an error within the stale-if-error window)
  /// - >360s: Must serve error response
  final Duration? staleIfError;
}

/// String constants for Cache-Control directives
const String _maxAgeDirective = 'max-age';
const String _noCacheDirective = 'no-cache';
const String _noStoreDirective = 'no-store';
const String _mustRevalidateDirective = 'must-revalidate';
const String _privateDirective = 'private';
const String _publicDirective = 'public';
const String _immutableDirective = 'immutable';
const String _staleWhileRevalidateDirective = 'stale-while-revalidate';
const String _staleIfErrorDirective = 'stale-if-error';
