/// Represents the Cache-Status header as described in RFC 9211.
class CacheStatus {
  /// Constructs a [CacheStatus] instance with the given parameters.
  ///
  /// Asserts that only [hit] or [fwd] is set, but not both.
  const CacheStatus({
    required this.cacheName,
    this.hit,
    this.fwd,
    this.fwdStatus,
    this.ttl,
    this.stored,
    this.collapsed,
    this.key,
    this.detail,
  }) : assert(
          hit == null || fwd == null,
          'Only one of hit or fwd can be set, but not both.',
        );

  /// Parses a Cache-Status header string.
  ///
  /// Takes a [header] string and returns a [CacheStatus] instance.
  factory CacheStatus.fromHeader(String header) {
    final parts = header.split(';').map((part) => part.trim()).toList();
    final cacheName = parts.removeAt(0);

    bool? hit;
    FwdParameter? fwd;
    int? fwdStatus;
    int? ttl;
    bool? stored;
    bool? collapsed;
    String? key;
    String? detail;

    for (final part in parts) {
      if (part == 'hit') {
        hit = true;
      } else if (part.startsWith('fwd=')) {
        fwd =
            FwdParameter.values.firstWhere((e) => e.value == part.substring(4));
      } else if (part.startsWith('fwd-status=')) {
        fwdStatus = int.tryParse(part.substring(11));
      } else if (part.startsWith('ttl=')) {
        ttl = int.tryParse(part.substring(4));
      } else if (part == 'stored') {
        stored = true;
      } else if (part == 'collapsed') {
        collapsed = true;
      } else if (part.startsWith('key=')) {
        key = part.substring(4);
      } else if (part.startsWith('detail=')) {
        detail = part.substring(7);
      }
    }

    return CacheStatus(
      cacheName: cacheName,
      hit: hit,
      fwd: fwd,
      fwdStatus: fwdStatus,
      ttl: ttl,
      stored: stored,
      collapsed: collapsed,
      key: key,
      detail: detail,
    );
  }

  /// The name of the Cache-Status header.
  static const headerName = 'Cache-Status';

  /// The name of the cache.
  final String cacheName;

  /// Indicates if the cache was a hit.
  final bool? hit;

  /// The reason why the request was forwarded.
  final FwdParameter? fwd;

  /// The status code of the forwarded request.
  final int? fwdStatus;

  /// The time-to-live of the cached response.
  final int? ttl;

  /// Indicates if the response was stored in the cache.
  final bool? stored;

  /// Indicates if the request was collapsed.
  final bool? collapsed;

  /// The key used for the cache lookup.
  final String? key;

  /// Additional details about the cache status.
  final String? detail;

  /// Creates a Cache-Status header string.
  ///
  /// Returns a string representation of the Cache-Status header.
  String toHeader() {
    final parts = <String>[cacheName];

    if (hit ?? false) {
      parts.add('hit');
    }
    if (fwd != null) {
      parts.add('fwd=${fwd!.value}');
    }
    if (fwdStatus != null) {
      parts.add('fwd-status=$fwdStatus');
    }
    if (ttl != null) {
      parts.add('ttl=$ttl');
    }
    if (stored ?? false) {
      parts.add('stored');
    }
    if (collapsed ?? false) {
      parts.add('collapsed');
    }
    if (key != null) {
      parts.add('key=$key');
    }
    if (detail != null) {
      parts.add('detail=$detail');
    }

    return parts.join('; ');
  }
}

/// Enum representing the possible reasons for forwarding a request.
enum FwdParameter {
  /// The cache was configured to not handle this request.
  bypass('bypass'),

  /// The request method's semantics require the request to be forwarded.
  method('method'),

  /// The cache did not contain any responses that matched the request URI.
  uriMiss('uri-miss'),

  /// The cache contained a response that matched the request URI, but it could
  /// not select a response based upon this request's header fields and stored
  /// Vary header fields.
  varyMiss('vary-miss'),

  /// The cache did not contain any responses that could be used to satisfy this
  /// request (to be used when an implementation cannot distinguish between
  /// uri-miss and vary-miss).
  miss('miss'),

  /// The cache was able to select a fresh response for the request, but the
  /// request's semantics (e.g., Cache-Control request directives) did not
  /// allow its use.
  request('request'),

  /// The cache was able to select a response for the request, but it was stale.
  stale('stale'),

  /// The cache was able to select a partial response for the request, but it
  /// did not contain all of the requested ranges (or the request was for the
  /// complete response).
  partial('partial');

  /// Constructs a [FwdParameter] with the given value.
  const FwdParameter(this.value);

  /// The string representation of the forwarding parameter.
  final String value;
}
