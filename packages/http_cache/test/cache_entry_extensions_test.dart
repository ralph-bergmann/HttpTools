// ignore_for_file: lines_longer_than_80_chars

import 'dart:io';

import 'package:http_cache/src/journal/cache_entry_extensions.dart';
import 'package:http_cache/src/journal/journal.pb.dart';
import 'package:http_cache/src/journal/timestamp.pb.dart';
import 'package:test/test.dart';

void main() {
  group('CacheEntryExtensions', () {
    CacheEntry createCacheEntry({
      DateTime? creationDate,
      String? cacheControl,
      DateTime? expires,
      DateTime? date,
      String? eTag,
      DateTime? lastModified,
    }) =>
        CacheEntry(
          creationDate: creationDate != null
              ? Timestamp.fromDateTime(creationDate)
              : null,
          responseHeaders: {
            if (cacheControl != null) 'cache-control': cacheControl,
            if (expires != null) 'expires': HttpDate.format(expires),
            if (date != null) 'date': HttpDate.format(date),
            if (eTag != null) 'etag': eTag,
            if (lastModified != null)
              'last-modified': HttpDate.format(lastModified),
          },
        );

    test('isExpired returns true when max-age is exceeded', () {
      final entry = createCacheEntry(
        creationDate: _now().subtract(const Duration(seconds: 70)),
        cacheControl: 'max-age=60',
      );
      expect(entry.isExpired, isTrue);
    });

    test('isExpired returns false when max-age is not exceeded', () {
      final entry = createCacheEntry(
        creationDate: _now().subtract(const Duration(seconds: 50)),
        cacheControl: 'max-age=60',
      );
      expect(entry.isExpired, isFalse);
    });

    test('isExpired returns true when expires is exceeded', () {
      final expiresDate = _now().subtract(const Duration(seconds: 10)).toUtc();
      final entry = createCacheEntry(
        creationDate: _now().subtract(const Duration(seconds: 70)),
        expires: expiresDate,
      );
      expect(entry.isExpired, isTrue);
    });

    test('isExpired returns false when expires is not exceeded', () {
      final expiresDate = _now().add(const Duration(seconds: 50)).toUtc();
      final entry = createCacheEntry(
        creationDate: _now().subtract(const Duration(seconds: 70)),
        expires: expiresDate,
      );
      expect(entry.isExpired, isFalse);
    });

    test(
        'isStaleWhileRevalidate returns true within stale-while-revalidate period',
        () {
      final entry = createCacheEntry(
        creationDate: _now().subtract(const Duration(seconds: 70)),
        cacheControl: 'max-age=60, stale-while-revalidate=30',
      );
      expect(entry.isStaleWhileRevalidate, isTrue);
    });

    test(
        'isStaleWhileRevalidate returns false outside stale-while-revalidate period',
        () {
      final entry = createCacheEntry(
        creationDate: _now().subtract(const Duration(seconds: 100)),
        cacheControl: 'max-age=60, stale-while-revalidate=30',
      );
      expect(entry.isStaleWhileRevalidate, isFalse);
    });

    test('isStaleIfError returns true within stale-if-error period', () {
      final entry = createCacheEntry(
        creationDate: _now().subtract(const Duration(seconds: 70)),
        cacheControl: 'max-age=60, stale-if-error=30',
      );
      expect(entry.isStaleIfError, isTrue);
    });

    test('isStaleIfError returns false outside stale-if-error period', () {
      final entry = createCacheEntry(
        creationDate: _now().subtract(const Duration(seconds: 100)),
        cacheControl: 'max-age=60, stale-if-error=30',
      );
      expect(entry.isStaleIfError, isFalse);
    });

    test('age is calculated correctly', () {
      final date = _now().subtract(const Duration(seconds: 80));
      final entry = createCacheEntry(
        creationDate: date.add(const Duration(seconds: 5)),
        date: date,
      );
      expect(entry.age.inSeconds, closeTo(80, 1));
    });

    test('expires is parsed correctly', () {
      final expiresDate = _now().add(const Duration(seconds: 60)).toUtc();
      final entry = createCacheEntry(
        expires: expiresDate,
      );
      expect(entry.expires, expiresDate);
    });

    test('eTag is parsed correctly', () {
      final entry = createCacheEntry(
        eTag: 'test-etag',
      );
      expect(entry.eTag, 'test-etag');
    });

    test('lastModified is parsed correctly', () {
      final lastModifiedDate = _now().subtract(const Duration(days: 1)).toUtc();
      final entry = createCacheEntry(
        lastModified: lastModifiedDate,
      );
      expect(entry.lastModified, lastModifiedDate);
    });

    test('date is parsed correctly', () {
      final date = _now().subtract(const Duration(days: 1)).toUtc();
      final entry = createCacheEntry(
        date: date,
      );
      expect(entry.date, date);
    });

    test('isPrivate returns true when Cache-Control is private', () {
      final entry = createCacheEntry(
        cacheControl: 'private, max-age=60',
      );
      expect(entry.isPrivate, isTrue);
    });

    test('isPrivate returns false when Cache-Control is not private', () {
      final entry = createCacheEntry(
        cacheControl: 'public, max-age=60',
      );
      expect(entry.isPrivate, isFalse);
    });

    test(
        'isPrivate returns false when Cache-Control does not contain private directive',
        () {
      final entry = createCacheEntry(
        cacheControl: 'max-age=60',
      );
      expect(entry.isPrivate, isFalse);
    });

    test('cacheControl is parsed correctly', () {
      final entry = createCacheEntry(
        cacheControl: 'max-age=60, private',
      );
      expect(entry.cacheControl?.maxAge, const Duration(seconds: 60));
      expect(entry.cacheControl?.private, isTrue);
    });

    test('responseTime uses date if present', () {
      final date = _now().subtract(const Duration(days: 1)).toUtc();
      final entry = createCacheEntry(
        date: date,
        creationDate: _now(),
      );
      expect(entry.responseTime, date);
    });

    test('responseTime uses creationDate if date is not present', () {
      final creationDate = _now().subtract(const Duration(days: 1));
      final entry = createCacheEntry(
        creationDate: creationDate,
      );
      expect(entry.responseTime, creationDate.toUtc());
    });

    test('calculateExpirationTime uses max-age if available', () {
      final entry = createCacheEntry(
        creationDate: _now(),
        cacheControl: 'max-age=60',
      );
      final expirationTime = entry.calculateExpirationTime();
      expect(expirationTime, isNotNull);
      expect(
        expirationTime,
        entry.creationDate.toDateTime().add(const Duration(seconds: 60)),
      );
    });

    test('calculateExpirationTime uses expires if max-age is not available',
        () {
      final expiresDate = _now().add(const Duration(seconds: 60)).toUtc();
      final entry = createCacheEntry(
        creationDate: _now(),
        expires: expiresDate,
      );
      final expirationTime = entry.calculateExpirationTime();
      expect(expirationTime, isNotNull);
      expect(expirationTime, expiresDate);
    });

    test('calculateExpirationTime prefers max-age over expires', () {
      final expiresDate = _now().add(const Duration(seconds: 120)).toUtc();
      final entry = createCacheEntry(
        creationDate: _now(),
        cacheControl: 'max-age=60',
        expires: expiresDate,
      );
      final expirationTime = entry.calculateExpirationTime();
      expect(expirationTime, isNotNull);
      expect(
        expirationTime,
        entry.creationDate.toDateTime().add(const Duration(seconds: 60)),
      );
    });
  });
}

DateTime _now() => DateTime.now().copyWith(millisecond: 0, microsecond: 0);
