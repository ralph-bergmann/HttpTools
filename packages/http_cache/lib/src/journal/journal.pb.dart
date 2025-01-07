//
//  Generated code. Do not modify.
//  source: journal.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'timestamp.pb.dart' as $0;

class Journal extends $pb.GeneratedMessage {
  factory Journal({
    $core.Map<$core.String, JournalEntry>? entries,
  }) {
    final $result = create();
    if (entries != null) {
      $result.entries.addAll(entries);
    }
    return $result;
  }
  Journal._() : super();
  factory Journal.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Journal.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Journal', package: const $pb.PackageName(_omitMessageNames ? '' : 'journal'), createEmptyInstance: create)
    ..m<$core.String, JournalEntry>(1, _omitFieldNames ? '' : 'entries', entryClassName: 'Journal.EntriesEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OM, valueCreator: JournalEntry.create, valueDefaultOrMaker: JournalEntry.getDefault, packageName: const $pb.PackageName('journal'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Journal clone() => Journal()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Journal copyWith(void Function(Journal) updates) => super.copyWith((message) => updates(message as Journal)) as Journal;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Journal create() => Journal._();
  Journal createEmptyInstance() => create();
  static $pb.PbList<Journal> createRepeated() => $pb.PbList<Journal>();
  @$core.pragma('dart2js:noInline')
  static Journal getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Journal>(create);
  static Journal? _defaultInstance;

  /// A map that associates a primary cache key with a JournalEntry.
  @$pb.TagNumber(1)
  $core.Map<$core.String, JournalEntry> get entries => $_getMap(0);
}

/// Represents a cache entry in the journal for a specific URL.
class JournalEntry extends $pb.GeneratedMessage {
  factory JournalEntry({
    $core.String? cacheKey,
    $core.Map<$core.String, CacheEntry>? cacheEntries,
  }) {
    final $result = create();
    if (cacheKey != null) {
      $result.cacheKey = cacheKey;
    }
    if (cacheEntries != null) {
      $result.cacheEntries.addAll(cacheEntries);
    }
    return $result;
  }
  JournalEntry._() : super();
  factory JournalEntry.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory JournalEntry.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'JournalEntry', package: const $pb.PackageName(_omitMessageNames ? '' : 'journal'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'cacheKey', protoName: 'cacheKey')
    ..m<$core.String, CacheEntry>(2, _omitFieldNames ? '' : 'cacheEntries', protoName: 'cacheEntries', entryClassName: 'JournalEntry.CacheEntriesEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OM, valueCreator: CacheEntry.create, valueDefaultOrMaker: CacheEntry.getDefault, packageName: const $pb.PackageName('journal'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  JournalEntry clone() => JournalEntry()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  JournalEntry copyWith(void Function(JournalEntry) updates) => super.copyWith((message) => updates(message as JournalEntry)) as JournalEntry;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static JournalEntry create() => JournalEntry._();
  JournalEntry createEmptyInstance() => create();
  static $pb.PbList<JournalEntry> createRepeated() => $pb.PbList<JournalEntry>();
  @$core.pragma('dart2js:noInline')
  static JournalEntry getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<JournalEntry>(create);
  static JournalEntry? _defaultInstance;

  /// The primary cache key.
  /// The primary cache key is derived from the target URI.
  /// Since only GET requests are handled, the key is simply the URL.
  @$pb.TagNumber(1)
  $core.String get cacheKey => $_getSZ(0);
  @$pb.TagNumber(1)
  set cacheKey($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCacheKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearCacheKey() => clearField(1);

  /// A map that associates a secondary cache key with a CacheEntry.
  /// Each JournalEntry is for a specific URL and can have multiple CacheEntry
  /// instances depending on the vary response headers.
  /// The secondary cache key is constructed from the URL and vary headers.
  /// This ensures that different variations of the same URL can be cached separately.
  @$pb.TagNumber(2)
  $core.Map<$core.String, CacheEntry> get cacheEntries => $_getMap(1);
}

/// Represents the actual cached response.
class CacheEntry extends $pb.GeneratedMessage {
  factory CacheEntry({
    $core.String? cacheKey,
    $0.Timestamp? creationDate,
    $core.String? reasonPhrase,
    $core.int? contentLength,
    $core.Map<$core.String, $core.String>? responseHeaders,
    $core.Map<$core.String, $core.String>? varyHeaders,
    $core.int? hitCount,
    $0.Timestamp? lastAccessDate,
    $core.int? persistedResponseSize,
  }) {
    final $result = create();
    if (cacheKey != null) {
      $result.cacheKey = cacheKey;
    }
    if (creationDate != null) {
      $result.creationDate = creationDate;
    }
    if (reasonPhrase != null) {
      $result.reasonPhrase = reasonPhrase;
    }
    if (contentLength != null) {
      $result.contentLength = contentLength;
    }
    if (responseHeaders != null) {
      $result.responseHeaders.addAll(responseHeaders);
    }
    if (varyHeaders != null) {
      $result.varyHeaders.addAll(varyHeaders);
    }
    if (hitCount != null) {
      $result.hitCount = hitCount;
    }
    if (lastAccessDate != null) {
      $result.lastAccessDate = lastAccessDate;
    }
    if (persistedResponseSize != null) {
      $result.persistedResponseSize = persistedResponseSize;
    }
    return $result;
  }
  CacheEntry._() : super();
  factory CacheEntry.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory CacheEntry.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'CacheEntry', package: const $pb.PackageName(_omitMessageNames ? '' : 'journal'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'cacheKey', protoName: 'cacheKey')
    ..aOM<$0.Timestamp>(2, _omitFieldNames ? '' : 'creationDate', protoName: 'creationDate', subBuilder: $0.Timestamp.create)
    ..aOS(4, _omitFieldNames ? '' : 'reasonPhrase', protoName: 'reasonPhrase')
    ..a<$core.int>(5, _omitFieldNames ? '' : 'contentLength', $pb.PbFieldType.O3, protoName: 'contentLength')
    ..m<$core.String, $core.String>(6, _omitFieldNames ? '' : 'responseHeaders', protoName: 'responseHeaders', entryClassName: 'CacheEntry.ResponseHeadersEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('journal'))
    ..m<$core.String, $core.String>(7, _omitFieldNames ? '' : 'varyHeaders', protoName: 'varyHeaders', entryClassName: 'CacheEntry.VaryHeadersEntry', keyFieldType: $pb.PbFieldType.OS, valueFieldType: $pb.PbFieldType.OS, packageName: const $pb.PackageName('journal'))
    ..a<$core.int>(8, _omitFieldNames ? '' : 'hitCount', $pb.PbFieldType.O3, protoName: 'hitCount')
    ..aOM<$0.Timestamp>(9, _omitFieldNames ? '' : 'lastAccessDate', protoName: 'lastAccessDate', subBuilder: $0.Timestamp.create)
    ..a<$core.int>(10, _omitFieldNames ? '' : 'persistedResponseSize', $pb.PbFieldType.O3, protoName: 'persistedResponseSize')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  CacheEntry clone() => CacheEntry()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  CacheEntry copyWith(void Function(CacheEntry) updates) => super.copyWith((message) => updates(message as CacheEntry)) as CacheEntry;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CacheEntry create() => CacheEntry._();
  CacheEntry createEmptyInstance() => create();
  static $pb.PbList<CacheEntry> createRepeated() => $pb.PbList<CacheEntry>();
  @$core.pragma('dart2js:noInline')
  static CacheEntry getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CacheEntry>(create);
  static CacheEntry? _defaultInstance;

  ///  The secondary cache key.
  ///  Like the primary cache key, this key is constructed from the URL.
  ///  Additionally, it includes all vary headers.
  ///  The vary headers are used to determine how the response varies based on
  ///  different request headers, ensuring that the correct cached response is
  ///  served for requests with different headers.
  ///  This cache key is also used as the file name for storing the cached responses.
  ///
  ///  The secondary cache key is built by normalizing the URL and concatenating it
  ///  with a serialized representation of the vary headers. The vary headers are
  ///  sorted by name and concatenated in a key-value format.
  ///
  ///  Example:
  ///  Given the URL: "https://example.com/api/data"
  ///  And vary headers: { "Accept": "application/json", "Authorization": "Bearer token" }
  ///  The secondary cache key would be:
  ///  "https://example.com/api/data|Accept:application/json,Authorization:Bearer token"
  @$pb.TagNumber(1)
  $core.String get cacheKey => $_getSZ(0);
  @$pb.TagNumber(1)
  set cacheKey($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasCacheKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearCacheKey() => clearField(1);

  /// The date and time when the cache entry was cached.
  @$pb.TagNumber(2)
  $0.Timestamp get creationDate => $_getN(1);
  @$pb.TagNumber(2)
  set creationDate($0.Timestamp v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasCreationDate() => $_has(1);
  @$pb.TagNumber(2)
  void clearCreationDate() => clearField(2);
  @$pb.TagNumber(2)
  $0.Timestamp ensureCreationDate() => $_ensure(1);

  /// The reason phrase associated with the status code.
  @$pb.TagNumber(4)
  $core.String get reasonPhrase => $_getSZ(2);
  @$pb.TagNumber(4)
  set reasonPhrase($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(4)
  $core.bool hasReasonPhrase() => $_has(2);
  @$pb.TagNumber(4)
  void clearReasonPhrase() => clearField(4);

  ///  The size of the response body, in bytes.
  ///
  ///  If the size of the request is not known in advance, this is `null`.
  @$pb.TagNumber(5)
  $core.int get contentLength => $_getIZ(3);
  @$pb.TagNumber(5)
  set contentLength($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(5)
  $core.bool hasContentLength() => $_has(3);
  @$pb.TagNumber(5)
  void clearContentLength() => clearField(5);

  /// The headers of the cached response.
  /// These headers are stored as key-value pairs.
  @$pb.TagNumber(6)
  $core.Map<$core.String, $core.String> get responseHeaders => $_getMap(4);

  /// The vary headers used to determine the cache key.
  /// These headers are stored as key-value pairs.
  @$pb.TagNumber(7)
  $core.Map<$core.String, $core.String> get varyHeaders => $_getMap(5);

  /// The number of times this cache entry has been accessed.
  @$pb.TagNumber(8)
  $core.int get hitCount => $_getIZ(6);
  @$pb.TagNumber(8)
  set hitCount($core.int v) { $_setSignedInt32(6, v); }
  @$pb.TagNumber(8)
  $core.bool hasHitCount() => $_has(6);
  @$pb.TagNumber(8)
  void clearHitCount() => clearField(8);

  /// The date and time when this cache entry was last accessed.
  @$pb.TagNumber(9)
  $0.Timestamp get lastAccessDate => $_getN(7);
  @$pb.TagNumber(9)
  set lastAccessDate($0.Timestamp v) { setField(9, v); }
  @$pb.TagNumber(9)
  $core.bool hasLastAccessDate() => $_has(7);
  @$pb.TagNumber(9)
  void clearLastAccessDate() => clearField(9);
  @$pb.TagNumber(9)
  $0.Timestamp ensureLastAccessDate() => $_ensure(7);

  /// The size of the persisted response, in bytes.
  @$pb.TagNumber(10)
  $core.int get persistedResponseSize => $_getIZ(8);
  @$pb.TagNumber(10)
  set persistedResponseSize($core.int v) { $_setSignedInt32(8, v); }
  @$pb.TagNumber(10)
  $core.bool hasPersistedResponseSize() => $_has(8);
  @$pb.TagNumber(10)
  void clearPersistedResponseSize() => clearField(10);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
