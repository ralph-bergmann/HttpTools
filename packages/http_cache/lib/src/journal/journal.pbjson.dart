//
//  Generated code. Do not modify.
//  source: journal.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use journalDescriptor instead')
const Journal$json = {
  '1': 'Journal',
  '2': [
    {'1': 'entries', '3': 1, '4': 3, '5': 11, '6': '.journal.Journal.EntriesEntry', '10': 'entries'},
  ],
  '3': [Journal_EntriesEntry$json],
};

@$core.Deprecated('Use journalDescriptor instead')
const Journal_EntriesEntry$json = {
  '1': 'EntriesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.journal.JournalEntry', '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Journal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List journalDescriptor = $convert.base64Decode(
    'CgdKb3VybmFsEjcKB2VudHJpZXMYASADKAsyHS5qb3VybmFsLkpvdXJuYWwuRW50cmllc0VudH'
    'J5UgdlbnRyaWVzGlEKDEVudHJpZXNFbnRyeRIQCgNrZXkYASABKAlSA2tleRIrCgV2YWx1ZRgC'
    'IAEoCzIVLmpvdXJuYWwuSm91cm5hbEVudHJ5UgV2YWx1ZToCOAE=');

@$core.Deprecated('Use journalEntryDescriptor instead')
const JournalEntry$json = {
  '1': 'JournalEntry',
  '2': [
    {'1': 'cacheKey', '3': 1, '4': 1, '5': 9, '10': 'cacheKey'},
    {'1': 'cacheEntries', '3': 2, '4': 3, '5': 11, '6': '.journal.JournalEntry.CacheEntriesEntry', '10': 'cacheEntries'},
  ],
  '3': [JournalEntry_CacheEntriesEntry$json],
};

@$core.Deprecated('Use journalEntryDescriptor instead')
const JournalEntry_CacheEntriesEntry$json = {
  '1': 'CacheEntriesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.journal.CacheEntry', '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `JournalEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List journalEntryDescriptor = $convert.base64Decode(
    'CgxKb3VybmFsRW50cnkSGgoIY2FjaGVLZXkYASABKAlSCGNhY2hlS2V5EksKDGNhY2hlRW50cm'
    'llcxgCIAMoCzInLmpvdXJuYWwuSm91cm5hbEVudHJ5LkNhY2hlRW50cmllc0VudHJ5UgxjYWNo'
    'ZUVudHJpZXMaVAoRQ2FjaGVFbnRyaWVzRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSKQoFdmFsdW'
    'UYAiABKAsyEy5qb3VybmFsLkNhY2hlRW50cnlSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use cacheEntryDescriptor instead')
const CacheEntry$json = {
  '1': 'CacheEntry',
  '2': [
    {'1': 'cacheKey', '3': 1, '4': 1, '5': 9, '10': 'cacheKey'},
    {'1': 'creationDate', '3': 2, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'creationDate'},
    {'1': 'reasonPhrase', '3': 4, '4': 1, '5': 9, '10': 'reasonPhrase'},
    {'1': 'contentLength', '3': 5, '4': 1, '5': 5, '10': 'contentLength'},
    {'1': 'responseHeaders', '3': 6, '4': 3, '5': 11, '6': '.journal.CacheEntry.ResponseHeadersEntry', '10': 'responseHeaders'},
    {'1': 'varyHeaders', '3': 7, '4': 3, '5': 11, '6': '.journal.CacheEntry.VaryHeadersEntry', '10': 'varyHeaders'},
    {'1': 'hitCount', '3': 8, '4': 1, '5': 5, '10': 'hitCount'},
    {'1': 'lastAccessDate', '3': 9, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'lastAccessDate'},
    {'1': 'persistedResponseSize', '3': 10, '4': 1, '5': 5, '10': 'persistedResponseSize'},
  ],
  '3': [CacheEntry_ResponseHeadersEntry$json, CacheEntry_VaryHeadersEntry$json],
};

@$core.Deprecated('Use cacheEntryDescriptor instead')
const CacheEntry_ResponseHeadersEntry$json = {
  '1': 'ResponseHeadersEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use cacheEntryDescriptor instead')
const CacheEntry_VaryHeadersEntry$json = {
  '1': 'VaryHeadersEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `CacheEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cacheEntryDescriptor = $convert.base64Decode(
    'CgpDYWNoZUVudHJ5EhoKCGNhY2hlS2V5GAEgASgJUghjYWNoZUtleRI+CgxjcmVhdGlvbkRhdG'
    'UYAiABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgxjcmVhdGlvbkRhdGUSIgoMcmVh'
    'c29uUGhyYXNlGAQgASgJUgxyZWFzb25QaHJhc2USJAoNY29udGVudExlbmd0aBgFIAEoBVINY2'
    '9udGVudExlbmd0aBJSCg9yZXNwb25zZUhlYWRlcnMYBiADKAsyKC5qb3VybmFsLkNhY2hlRW50'
    'cnkuUmVzcG9uc2VIZWFkZXJzRW50cnlSD3Jlc3BvbnNlSGVhZGVycxJGCgt2YXJ5SGVhZGVycx'
    'gHIAMoCzIkLmpvdXJuYWwuQ2FjaGVFbnRyeS5WYXJ5SGVhZGVyc0VudHJ5Ugt2YXJ5SGVhZGVy'
    'cxIaCghoaXRDb3VudBgIIAEoBVIIaGl0Q291bnQSQgoObGFzdEFjY2Vzc0RhdGUYCSABKAsyGi'
    '5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUg5sYXN0QWNjZXNzRGF0ZRI0ChVwZXJzaXN0ZWRS'
    'ZXNwb25zZVNpemUYCiABKAVSFXBlcnNpc3RlZFJlc3BvbnNlU2l6ZRpCChRSZXNwb25zZUhlYW'
    'RlcnNFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgBGj4K'
    'EFZhcnlIZWFkZXJzRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbH'
    'VlOgI4AQ==');

