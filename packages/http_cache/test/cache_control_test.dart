import 'package:http_cache/src/cache_control.dart';
import 'package:test/test.dart';

void main() {
  group('CacheControl', () {
    test('parses max-age directive', () {
      final cacheControl = CacheControl.parse('max-age=3600');
      expect(cacheControl.maxAge, const Duration(seconds: 3600));
    });

    test('parses no-cache directive', () {
      final cacheControl = CacheControl.parse('no-cache');
      expect(cacheControl.noCache, isTrue);
    });

    test('parses no-store directive', () {
      final cacheControl = CacheControl.parse('no-store');
      expect(cacheControl.noStore, isTrue);
    });

    test('parses must-revalidate directive', () {
      final cacheControl = CacheControl.parse('must-revalidate');
      expect(cacheControl.mustRevalidate, isTrue);
    });

    test('parses private directive', () {
      final cacheControl = CacheControl.parse('private');
      expect(cacheControl.private, isTrue);
    });

    test('parses immutable directive', () {
      final cacheControl = CacheControl.parse('immutable');
      expect(cacheControl.immutable, isTrue);
    });

    test('parses stale-while-revalidate directive', () {
      final cacheControl = CacheControl.parse('stale-while-revalidate=60');
      expect(cacheControl.staleWhileRevalidate, const Duration(seconds: 60));
    });

    test('parses stale-if-error directive', () {
      final cacheControl = CacheControl.parse('stale-if-error=120');
      expect(cacheControl.staleIfError, const Duration(seconds: 120));
    });

    test('parses multiple directives', () {
      final cacheControl = CacheControl.parse(
        'max-age=3600, no-cache, private, stale-while-revalidate=60',
      );
      expect(cacheControl.maxAge, const Duration(seconds: 3600));
      expect(cacheControl.noCache, isTrue);
      expect(cacheControl.private, isTrue);
      expect(cacheControl.staleWhileRevalidate, const Duration(seconds: 60));
    });

    test('handles invalid max-age value gracefully', () {
      final cacheControl = CacheControl.parse('max-age=invalid');
      expect(cacheControl.maxAge, isNull);
    });

    test('handles max-age with negative value gracefully', () {
      final cacheControl = CacheControl.parse('max-age=-1');
      expect(cacheControl.maxAge, isNull);
    });

    test('handles empty header gracefully', () {
      final cacheControl = CacheControl.parse('');
      expect(cacheControl.maxAge, isNull);
      expect(cacheControl.noCache, isNull);
      expect(cacheControl.noStore, isNull);
      expect(cacheControl.mustRevalidate, isNull);
      expect(cacheControl.private, isNull);
      expect(cacheControl.immutable, isNull);
      expect(cacheControl.staleWhileRevalidate, isNull);
      expect(cacheControl.staleIfError, isNull);
    });
  });
}
