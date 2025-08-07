import 'dart:io';

import 'package:meta/meta.dart';

import '../cache_control.dart';
import 'journal.pb.dart';

/// Extension methods for the [CacheEntry] class.
extension CacheEntryExtensions on CacheEntry {
  /// Parses the `expires` header to get the expiration date of the cache entry.
  ///
  /// Returns `null` if the `expires` header is not present or cannot be parsed.
  DateTime? get expires => responseHeaders['expires']?._parseHttpDate();

  /// Gets the ETag of the cache entry from the `etag` header.
  ///
  /// Returns `null` if the `etag` header is not present.
  String? get eTag => responseHeaders['etag'];

  /// Parses the `last-modified` header to get the last modified date of the
  /// cache entry.
  ///
  /// Returns `null` if the `last-modified` header is not present or cannot
  /// be parsed.
  DateTime? get lastModified => responseHeaders['last-modified']?._parseHttpDate();

  /// Parses the `date` header to get the date when the response was generated.
  ///
  /// Returns `null` if the `date` header is not present or cannot be parsed.
  DateTime? get date => responseHeaders['date']?._parseHttpDate();

  /// Determines if the cache entry is private based on the `Cache-Control`
  /// header.
  ///
  /// Returns `true` if the `Cache-Control` header contains the `private`
  /// directive.
  /// Returns `false` if the `Cache-Control` header is not present or does not
  /// contain the `private` directive.
  bool get isPrivate => cacheControl?.private ?? false;

  /// Determines if the cache entry is immutable based on the `Cache-Control`
  /// header.
  ///
  /// Returns `true` if the `Cache-Control` header contains the `immutable`
  /// directive.
  /// Returns `false` if the `Cache-Control` header is not present or does not
  /// contain the `immutable` directive.
  bool get isImmutable => cacheControl?.immutable ?? false;

  /// Determines if the cache entry must be revalidated based on the
  /// `Cache-Control` header.
  ///
  /// Returns `true` if the `Cache-Control` header contains the
  /// `must-revalidate` directive.
  /// Returns `false` if the `Cache-Control` header is not present or does not
  /// contain the `must-revalidate` directive.
  bool get mustRevalidate => cacheControl?.mustRevalidate ?? false;

  /// Determines if the cache entry should not be cached based on the
  /// `Cache-Control` header.
  ///
  /// Returns `true` if the `Cache-Control` header contains the `no-cache`
  /// directive.
  /// Returns `false` if the `Cache-Control` header is not present or does not
  /// contain the `no-cache` directive.
  bool get noCache => cacheControl?.noCache ?? false;

  /// Determines if the cache entry should not be stored based on the
  /// `Cache-Control` header.
  ///
  /// Returns `true` if the `Cache-Control` header contains the `no-store`
  /// directive.
  /// Returns `false` if the `Cache-Control` header is not present or does not
  /// contain the `no-store` directive.
  bool get noStore => cacheControl?.noStore ?? false;

  /// Parses the `Cache-Control` header to get the cache control directives.
  ///
  /// Returns `null` if the `Cache-Control` header is not present.
  CacheControl? get cacheControl {
    final cacheControlHeader = responseHeaders['cache-control'];
    if (cacheControlHeader != null) {
      return CacheControl.parse(cacheControlHeader);
    }
    return null;
  }

  /// Gets the response time based on the `date` header or the creation date if
  /// the `date` header is not present.
  DateTime get responseTime => date ?? creationDate.toDateTime();

  /// Calculates the age of the response based on the response time and the
  /// current time.
  ///
  /// Returns the duration representing the age of the response.
  Duration get age => DateTime.now().toUtc().difference(responseTime);

  /// Determines if the cache entry is expired.
  ///
  /// The criterion for determining when a response is fresh and when it is
  /// stale is age.
  /// In HTTP, age is the time elapsed since the response was generated.
  /// If both `Expires` and `Cache-Control: max-age` are available, `max-age`
  /// is preferred.
  ///
  /// Returns `true` if the cache entry is expired, otherwise `false`.
  bool get isExpired {
    final expirationTime = calculateExpirationTime();
    return expirationTime != null && DateTime.now().toUtc().isAfter(expirationTime);
  }

  /// Determines if the cache entry is within the stale-while-revalidate period.
  ///
  /// The stale-while-revalidate period is a period during which a stale
  /// response can be used while a new response is being revalidated in the
  /// background. This period is determined based on the `max-age` directive in
  /// the `Cache-Control` header and the `stale-while-revalidate` directive.
  ///
  /// If the `stale-while-revalidate` directive is not present, the entry is
  /// considered not within the stale-while-revalidate period.
  ///
  /// Example:
  /// ```dart
  /// Cache-Control: max-age=60, stale-while-revalidate=30
  /// ```
  /// In this example, the response is considered fresh for 60 seconds. After 60
  /// seconds, the response becomes stale, but it can still be used for an
  /// additional 30 seconds while a new response is being fetched in the
  /// background.
  ///
  /// Returns `true` if the cache entry is within the stale-while-revalidate
  /// period, otherwise `false`.
  bool get isStaleWhileRevalidate {
    final expirationTime = calculateExpirationTime();
    if (expirationTime != null) {
      final staleWhileRevalidateDuration = cacheControl?.staleWhileRevalidate;
      if (staleWhileRevalidateDuration != null) {
        return DateTime.now().toUtc().isBefore(expirationTime.add(staleWhileRevalidateDuration));
      }
    }
    return false;
  }

  /// Determines if the cache entry is within the stale-if-error period.
  ///
  /// The stale-if-error period is a period during which a stale response can be
  /// used if an error occurs while fetching a new response. This period is
  /// determined based on the `max-age` directive in the `Cache-Control` header
  /// and the `stale-if-error` directive.
  ///
  /// If the `stale-if-error` directive is not present, the entry is considered
  /// not within the stale-if-error period.
  ///
  /// Example:
  /// ```dart
  /// Cache-Control: max-age=60, stale-if-error=30
  /// ```
  /// In this example, the response is considered fresh for 60 seconds. After 60
  /// seconds, the response becomes stale, but it can still be used for an
  /// additional 30 seconds if an error occurs while fetching a new response.
  ///
  /// Returns `true` if the cache entry is within the stale-if-error period,
  /// otherwise `false`.
  bool get isStaleIfError {
    final expirationTime = calculateExpirationTime();
    if (expirationTime != null) {
      final staleIfErrorDuration = cacheControl?.staleIfError;
      if (staleIfErrorDuration != null) {
        return DateTime.now().toUtc().isBefore(expirationTime.add(staleIfErrorDuration));
      }
    }
    return false;
  }

  /// Determines if a cached response needs revalidation with the origin server.
  ///
  /// Returns true when:
  /// - no-store is set
  /// - no-cache is set
  /// - No expiration time is set
  /// - must-revalidate is set
  /// - Content is expired
  ///
  /// Returns false when:
  /// - Content is fresh and has immutable flag
  bool get needsRevalidation {
    if (noStore) {
      return true;
    }
    if (noCache) {
      return true;
    }

    final expirationTime = calculateExpirationTime();
    if (expirationTime == null) {
      return true;
    }

    // Fresh content with immutable flag never needs revalidation
    if (!isExpired && isImmutable) {
      return false;
    }

    return mustRevalidate || isExpired;
  }

  /// Calculates the expiration time of the response based on the
  /// `Cache-Control: max-age` directive or the `Expires` header.
  ///
  /// Returns the expiration time as a [DateTime] object, or `null` if neither
  /// `max-age` nor `Expires` is present.
  @visibleForTesting
  DateTime? calculateExpirationTime() {
    final maxAgeDuration = cacheControl?.maxAge;
    if (maxAgeDuration != null) {
      return responseTime.add(maxAgeDuration);
    }
    return expires;
  }
}

/// Extension methods for parsing HTTP date strings.
extension _StringHttpDateParsing on String {
  /// Parses an HTTP date string to a [DateTime] object.
  ///
  /// Returns `null` if the date string cannot be parsed.
  DateTime? _parseHttpDate() {
    try {
      return HttpDate.parse(this);
    } catch (e) {
      print('failed to parse date time $this: $e');
      rethrow;
    }
  }
}
