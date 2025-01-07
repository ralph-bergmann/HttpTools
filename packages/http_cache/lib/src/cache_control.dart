/// Represents the parsed directives from the Cache-Control HTTP header.
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

  /// Parses the Cache-Control header and extracts the directives.
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
        case 'max-age':
          if (value != null) {
            final seconds = int.tryParse(value);
            if (seconds != null && seconds >= 0) {
              maxAge = Duration(seconds: seconds);
            }
          }
        case 'no-cache':
          noCache = true;
        case 'no-store':
          noStore = true;
        case 'must-revalidate':
          mustRevalidate = true;
        case 'private':
          private = true;
        case 'public':
          public = true;
        case 'immutable':
          immutable = true;
        case 'stale-while-revalidate':
          if (value != null) {
            final seconds = int.tryParse(value);
            if (seconds != null) {
              staleWhileRevalidate = Duration(seconds: seconds);
            }
          }
        case 'stale-if-error':
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

  /// Specifies the maximum amount of time a resource is considered fresh.
  final Duration? maxAge;

  /// Indicates that the response must not be cached.
  final bool? noCache;

  /// Indicates that the response must not be stored in any cache.
  final bool? noStore;

  /// Indicates that the response must be revalidated by the origin server
  /// before being served from the cache.
  final bool? mustRevalidate;

  /// Indicates that the response is intended for a single user and must not
  /// be stored by shared caches.
  final bool? private;

  /// Indicates that the response may be stored by any cache.
  final bool? public;

  /// Indicates that the response will not be updated while it is fresh.
  final bool? immutable;

  /// Indicates the time during which the cache can serve stale content while
  /// revalidating in the background.
  final Duration? staleWhileRevalidate;

  /// Indicates the time during which the cache can serve stale content if
  /// an error occurs during revalidation.
  final Duration? staleIfError;
}
