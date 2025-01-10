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

  /// Returns a new instance of CacheControl with the specified
  /// properties updated.
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

  /// Converts the CacheControl object into a string representation that matches
  /// the Cache-Control HTTP header format.
  ///
  /// The output includes all set directives joined by commas. Duration values
  /// are converted to seconds. For example:
  /// ```dart
  /// max-age=3600, public, stale-while-revalidate=60
  /// ```
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
