import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:collection/collection.dart';
import 'package:file/chroot.dart';
import 'package:file/file.dart' hide Directory;
import 'package:file/local.dart';
import 'package:file/memory.dart';
import 'package:http/http.dart';
import 'package:http_client_interceptor/http_client_interceptor.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import 'base_request_extensions.dart';
import 'base_response_extensions.dart';
import 'cache_control.dart';
import 'cache_status.dart';
import 'journal/cache_entry_extensions.dart';
import 'journal/journal.pb.dart';
import 'journal/journal_extensions.dart';
import 'journal/timestamp.pb.dart';

/// Logger instance for cache logging.
final _logger = Logger('HttpCache');

/// For debugging save Journal in JSON format.
const _jsonJournal = false;

/// Default max cache size in bytes.
const int _defaultMaxCacheSize = 100 * 1024 * 1024;

// Headers that must be updated from a 304 response
const _headersToUpdate = [
  HttpHeaders.cacheControlHeader,
  HttpHeaders.dateHeader,
  HttpHeaders.etagHeader,
  HttpHeaders.expiresHeader,
  HttpHeaders.lastModifiedHeader,
  HttpHeaders.varyHeader,
  HttpHeaders.warningHeader,
];

/// A class that implements HTTP caching using interceptors.
///
/// This class intercepts HTTP GET requests and caches the responses locally
/// either in memory or on the local file system.
class HttpCache extends HttpInterceptor {
  HttpCache();

  /// Name of the cache.
  late final String _cacheName;

  /// File system used for storing cache files.
  late final FileSystem _fs;

  /// Journal for managing cache entries.
  late final Journal _journal;

  /// If true, the cache will also store private content.
  /// Make sure to delete it if the user of the app changes.
  /// If the cache content is stored on an external/public storage,
  /// set it to false to not make private content accessible.
  late final bool _private;

  /// Timer for debouncing journal save operations.
  Timer? _debounceTimer;

  /// Maximum cache size in bytes.
  late final int _maxCacheSize;

  /// Initialize a local file system-based private cache (means it will store
  /// shared as well as private content). You should prune the cache with
  /// [deletePrivateContent()] after the user has logged out.
  /// Default cache size is 100 MB.
  ///
  /// [cacheDir] is the directory where the cache will be stored.
  /// [maxCacheSize] is the maximum size of the cache in bytes.
  /// [private] indicates if the cache stores private content.
  Future<void> initLocal(
    Directory cacheDir, {
    int maxCacheSize = _defaultMaxCacheSize,
    bool private = true,
  }) async {
    // Create the cache directory if it does not exist.
    await cacheDir.create(recursive: true);
    _cacheName = 'HttpToolsLocalCache';
    _fs = ChrootFileSystem(const LocalFileSystem(), cacheDir.absolute.path);
    _journal = await loadJournal(_fs, asJson: _jsonJournal);
    _maxCacheSize = maxCacheSize;
    _private = private;
  }

  /// Initialize an in-memory private cache (means it will store
  /// shared as well as private content). You should prune the cache with
  /// [deletePrivateContent()] after the user has logged out.
  /// Default cache size is 100 MB.
  ///
  /// [maxCacheSize] is the maximum size of the cache in bytes.
  /// [private] indicates if the cache stores private content.
  Future<void> initInMemory({
    int maxCacheSize = _defaultMaxCacheSize,
    bool private = true,
  }) async {
    _cacheName = 'HttpToolsInMemoryCache';
    _fs = MemoryFileSystem();
    _journal = await loadJournal(_fs, asJson: _jsonJournal);
    _maxCacheSize = maxCacheSize;
    _private = private;
  }

  /// Intercepts HTTP requests.
  ///
  /// If the request method is GET, it checks the cache for a stored response.
  /// If a cached response is found, it returns the cached response.
  /// Otherwise, it forwards the request to the next interceptor.
  @override
  FutureOr<OnRequest> onRequest(BaseRequest request) async {
    // Handle invalidation for PUT, DELETE, POST, and PATCH requests.
    if (['PUT', 'DELETE', 'POST', 'PATCH'].contains(request.method.toUpperCase())) {
      await invalidateCacheForRequest(request);
      return OnRequest.next(request);
    }

    // Only intercept GET requests.
    if (request.method.toUpperCase() != 'GET') {
      return OnRequest.next(request);
    }

    // Retrieve the cache entry from the journal.
    final cacheEntry = getCacheEntryForRequest(request);

    // Load the response from the cache if it exists.
    final response = cacheEntry != null ? getCachedResponse(request) : null;

    // If the cache entry is not found or the response is null,
    // forward the request to the next interceptor.
    if (cacheEntry == null || response == null) {
      _logger.info('Cache miss for ${request.url}');
      return OnRequest.next(request);
    }

    // Add ETag and Last-Modified headers if available.
    final eTag = cacheEntry.eTag;
    if (eTag != null) {
      request.headers[HttpHeaders.ifNoneMatchHeader] = eTag;
    }
    final lastModified = cacheEntry.lastModified;
    if (lastModified != null) {
      request.headers[HttpHeaders.ifModifiedSinceHeader] = HttpDate.format(lastModified);
    }

    // Check if the cache entry is expired, must be revalidated,
    // or has immutable / no-cache / no-store directive.
    if (cacheEntry.needsRevalidation) {
      _logger.info('Cache entry expired for ${request.url}');

      // If the cache entry is within the stale-while-revalidate period,
      // resolve and forward the request.
      if (cacheEntry.isStaleWhileRevalidate) {
        return OnRequest.resolveAndNext(request, response);
      } else {
        // Otherwise, forward the request to the next interceptor.
        return OnRequest.next(request);
      }
    }

    _logger.info('Cache hit for ${request.url}');

    // Resolve the request with the cached response.
    return OnRequest.resolve(
      response,
      skipFollowingResponseInterceptors: false,
    );
  }

  /// Intercepts HTTP responses.
  ///
  /// If the request method is GET and the response status code is 200,
  /// it caches the response body.
  @override
  FutureOr<OnResponse> onResponse(StreamedResponse response) async {
    final request = response.request;
    // Handle non-GET requests.
    if (request == null || request.method.toUpperCase() != 'GET') {
      return OnResponse.next(response);
    }

    // Parse Cache-Control header.
    final cacheControlHeader = response.headers[HttpHeaders.cacheControlHeader];
    final cacheControl = cacheControlHeader != null ? CacheControl.parse(cacheControlHeader) : null;

    // If the response is private and _private is false, skip caching.
    if (response.isPrivate && !_private) {
      _logger.info('Skipping cache for private response: ${request.url}');
      return OnResponse.next(response);
    }

    // If the response has no-store directive, skip caching.
    if (cacheControl?.noStore ?? false) {
      _logger.info('Skipping cache due to no-store directive: ${request.url}');
      return OnResponse.next(response);
    }

    // Check if the response has a Cache-Status header.
    final cacheStatusHeader = response.headers[CacheStatus.headerName];
    if (cacheStatusHeader != null) {
      final cacheStatus = CacheStatus.fromHeader(cacheStatusHeader);
      if (cacheStatus.hit ?? false) {
        // Return the response if it is a cache hit.
        // This means that the response comes from the cache and not from the
        // web and we should not handle it here to prevent loops.
        return OnResponse.next(response);
      }
    }

    // Check if the response has a Vary: * header using hasVaryAll() method.
    // Such responses are not cached because they are not specific to any
    // particular set of request headers.
    if (response.hasVaryAll()) {
      _logger.info('Skipping cache due to Vary: * header: ${request.url}');
      return OnResponse.next(response);
    }

    // Handle 304 Not Modified response.
    if (response.statusCode == 304) {
      final cachedResponse = getCachedResponse(request);
      if (cachedResponse != null) {
        await addOrUpdateCacheEntryForResponse(response);
        return OnResponse.resolve(cachedResponse);
      }
    }

    // Handle non-200 responses.
    if (response.statusCode != 200) {
      return OnResponse.next(response);
    }

    // Split the response stream for caching.
    final streams = StreamSplitter.splitFrom(response.stream);
    try {
      final secondaryCacheKey = response.secondaryCacheKey;
      if (secondaryCacheKey != null) {
        await addOrUpdateCacheEntryForResponse(response);
        await addResponseToCache(secondaryCacheKey, streams[0]);
      }
    } catch (e, s) {
      _logger.severe('Failed to write cache file for ${request.url}', e, s);
    }

    // Add Cache-Status header for cached responses.
    final headers = Map<String, String>.from(response.headers);
    headers[CacheStatus.headerName] = CacheStatus(
      cacheName: _cacheName,
      fwd: FwdParameter.uriMiss,
      fwdStatus: response.statusCode,
      key: request.cacheKey,
    ).toHeader();

    return OnResponse.next(
      StreamedResponse(
        streams[1],
        response.statusCode,
        contentLength: response.contentLength,
        request: request,
        headers: headers,
        reasonPhrase: response.reasonPhrase,
      ),
    );
  }

  /// Intercepts HTTP errors.
  ///
  /// If an error occurs during the HTTP request, this method checks if a
  /// cached response is available and returns it if the cache entry is within
  /// the stale-if-error period. Otherwise, it forwards the error.
  ///
  /// [request] is the HTTP request that caused the error.
  /// [error] is the error that occurred.
  /// [stackTrace] is the stack trace of the error.
  @override
  FutureOr<OnError> onError(
    BaseRequest request,
    Object error,
    StackTrace? stackTrace,
  ) async {
    // Retrieve the cache entry from the journal.
    final cacheEntry = getCacheEntryForRequest(request);

    // If no cache entry is found, forward the error.
    if (cacheEntry == null) {
      return OnError.next(request, error, stackTrace);
    }

    // Check if the cache entry is within the stale-if-error period.
    if (cacheEntry.isStaleIfError) {
      final cachedResponse = getCachedResponse(request);
      if (cachedResponse != null) {
        return OnError.resolve(cachedResponse);
      }
    }

    // Forward the error if no valid cache entry is found.
    return OnError.next(request, error, stackTrace);
  }

  /// Disposes of the HttpCache instance, ensuring that all pending journal
  /// save operations are completed.
  @override
  FutureOr<void> dispose() async {
    _debounceTimer?.cancel();
    await _journal.writeJournal(_fs, asJson: _jsonJournal);
  }

  /// Retrieves a cache entry from the journal based on the request.
  ///
  /// [request] is the HTTP request for which the cache entry is to
  /// be retrieved.
  /// Returns the cache entry if found, otherwise null.
  @visibleForTesting
  CacheEntry? getCacheEntryForRequest(BaseRequest request) {
    final primaryCacheKey = request.cacheKey;
    final journalEntry = _journal.entries[primaryCacheKey];

    if (journalEntry == null) {
      return null;
    }

    // Check if any cache entry matches the request based on vary headers.
    for (final cacheEntry in journalEntry.cacheEntries.values) {
      if (isMatchingCacheEntry(request, cacheEntry)) {
        return cacheEntry;
      }
    }

    return null;
  }

  /// Adds or updates a response in the journal.
  ///
  /// If the response already exists in the journal, it updates the entry.
  /// Otherwise, it adds a new entry.
  ///
  /// [response] is the HTTP response to be added or updated in the journal.
  @visibleForTesting
  Future<void> addOrUpdateCacheEntryForResponse(BaseResponse response) async {
    // cacheKey for the response based on the request url.
    final primaryCacheKey = response.primaryCacheKey;
    // cacheKey for the response based on the request url and vary headers.
    final secondaryCacheKey = response.secondaryCacheKey;

    if (primaryCacheKey == null || secondaryCacheKey == null) {
      final requestUrl = response.request?.url.toString() ?? 'unknown';
      _logger.warning('Failed to generate cache keys for response: $requestUrl');
      return;
    }

    // Retrieve or create a new journal entry.
    final journalEntry = _journal.entries.putIfAbsent(
      primaryCacheKey,
      () => JournalEntry(cacheKey: primaryCacheKey),
    );

    // Get existing cache entry if any
    final existingEntry = journalEntry.cacheEntries[secondaryCacheKey];

    final CacheEntry cacheEntry;
    if (existingEntry != null && response.statusCode == 304) {
      // For 304 responses, update headers but keep original content
      final updatedHeaders = Map<String, String>.from(existingEntry.responseHeaders);

      // Update headers based on the response headers
      for (final header in _headersToUpdate) {
        if (response.headers.containsKey(header)) {
          updatedHeaders[header] = response.headers[header]!;
        }
      }

      cacheEntry = CacheEntry(
        cacheKey: secondaryCacheKey,
        reasonPhrase: existingEntry.reasonPhrase,
        contentLength: existingEntry.contentLength,
        responseHeaders: updatedHeaders.entries,
        varyHeaders: existingEntry.varyHeaders.entries,
        hitCount: existingEntry.hitCount,
        lastAccessDate: Timestamp.fromDateTime(DateTime.now()),
      );
    } else {
      // For new responses or non-304 status codes, create new cache entry
      cacheEntry = CacheEntry(
        cacheKey: secondaryCacheKey,
        reasonPhrase: response.reasonPhrase,
        contentLength: response.contentLength,
        responseHeaders: response.headers.toLowerCaseKeys().entries,
        varyHeaders: response.varyHeaders.toLowerCaseKeys().entries,
        hitCount: existingEntry?.hitCount ?? 0,
        lastAccessDate: Timestamp.fromDateTime(DateTime.now()),
      );
    }

    // Add or update the cache entry in the journal.
    journalEntry.cacheEntries[secondaryCacheKey] = cacheEntry;

    // Debounce the journal save operation.
    _debounceJournalSave();
  }

  /// Checks if the cache entry matches the request based on vary headers.
  ///
  /// [request] is the HTTP request.
  /// [cacheEntry] is the cache entry to be checked.
  /// Returns true if the cache entry matches the request, otherwise false.
  @visibleForTesting
  bool isMatchingCacheEntry(BaseRequest request, CacheEntry cacheEntry) {
    for (final field in cacheEntry.varyHeaders.entries) {
      if (request.headers[field.key] != field.value) {
        return false;
      }
    }
    return true;
  }

  /// Handles the logic for retrieving a cached response from the file system.
  ///
  /// If a cached file exists for the given [request], the response is read from
  /// the file and returned as StreamedResponse. If no cached file exists, it
  /// returns null.
  ///
  /// [request] is the HTTP request for which the cached response is to
  /// be retrieved.
  /// Returns the cached response if found, otherwise null.
  @visibleForTesting
  StreamedResponse? getCachedResponse(BaseRequest request) {
    final cacheEntry = getCacheEntryForRequest(request);
    if (cacheEntry == null) {
      return null;
    }

    // Retrieve the cached file from the file system.
    final cachedFile = _fs.file(cacheEntry.cacheKey);
    if (cachedFile.existsSync()) {
      // Update hit count and last access date.
      cacheEntry
        ..hitCount += 1
        ..lastAccessDate = Timestamp.fromDateTime(DateTime.now());

      // Debounce the journal save operation.
      _debounceJournalSave();

      // Add Cache-Status header.
      final headers = Map<String, String>.from(cacheEntry.responseHeaders);
      headers[CacheStatus.headerName] = CacheStatus(
        cacheName: _cacheName,
        hit: true,
        key: request.cacheKey,
        detail: 'hit-count=${cacheEntry.hitCount}',
      ).toHeader();

      return StreamedResponse(
        cachedFile.openRead(),
        200,
        contentLength: cacheEntry.contentLength,
        request: request,
        headers: headers,
        reasonPhrase: cacheEntry.reasonPhrase,
      );
    }

    return null;
  }

  /// Writes the response body to a cache file with the given [cacheKey].
  ///
  /// [cacheKey] is the key for the cache file.
  /// [body] is the response body stream to be written to the cache file.
  @visibleForTesting
  Future<void> addResponseToCache(
    String cacheKey,
    Stream<List<int>> body,
  ) async {
    final cacheFile = _fs.file(cacheKey);
    final sink = cacheFile.openWrite();
    try {
      // Write the response body to the cache file.
      await sink.addStream(body);
      await sink.flush();
    } catch (e) {
      rethrow;
    } finally {
      await sink.close();
    }

    // Update the persistedResponseSize in the journal entry
    _journal.entries.values
        .expand((entry) => entry.cacheEntries.values)
        .firstWhereOrNull((entry) => entry.cacheKey == cacheKey)
        ?.persistedResponseSize = await cacheFile.length();

    // Check the cache size and clean if necessary.
    await _checkCacheSizeAndClean();

    _debounceJournalSave();
  }

  /// Invalidates the cache for the given request by removing the corresponding
  /// cache entry from the journal and deleting the associated cache file.
  ///
  /// [request] is the HTTP request for which the cache should be invalidated.
  @visibleForTesting
  Future<void> invalidateCacheForRequest(BaseRequest request) async {
    final primaryCacheKey = request.cacheKey;
    final journalEntry = _journal.entries[primaryCacheKey];

    if (journalEntry != null) {
      for (final cacheEntry in journalEntry.cacheEntries.values) {
        // Delete the cache file.
        await _fs.file(cacheEntry.cacheKey).delete();
      }
      // Remove the journal entry.
      _journal.entries.remove(primaryCacheKey);
      await _journal.writeJournal(_fs, asJson: _jsonJournal);
    }
  }

  @visibleForTesting
  int getCacheSize() => _journal.entries.values.expand((entry) => entry.cacheEntries.values).fold(
        0,
        (sum, cacheEntry) => sum + (cacheEntry.persistedResponseSize),
      );

  /// Clears the entire cache.
  Future<void> clearCache() async {
    await _fs.directory('/').delete(recursive: true);
    _journal.entries.clear();
    await _journal.writeJournal(_fs, asJson: _jsonJournal);
  }

  /// Deletes private content from the cache.
  Future<void> deletePrivateContent() async {
    final privateEntries = _journal.entries.values
        .expand((entry) => entry.cacheEntries.values)
        .where((cacheEntry) => cacheEntry.isPrivate);

    for (final cacheEntry in privateEntries) {
      await _fs.file(cacheEntry.cacheKey).delete();
    }

    _journal.entries.removeWhere(
      (key, entry) => entry.cacheEntries.values.any((cacheEntry) => cacheEntry.isPrivate),
    );

    await _journal.writeJournal(_fs, asJson: _jsonJournal);
  }

  Future<void> _checkCacheSizeAndClean() async {
    var currentCacheSize = getCacheSize();
    if (currentCacheSize < _maxCacheSize) {
      return;
    }

    // Sort entries by Frecency (frequency and recency).
    final entries = _journal.entries.values.expand((entry) => entry.cacheEntries.values).toList()
      ..sort((a, b) {
        final aScore = a.hitCount / (DateTime.now().difference(a.lastAccessDate.toDateTime()).inSeconds + 1);
        final bScore = b.hitCount / (DateTime.now().difference(b.lastAccessDate.toDateTime()).inSeconds + 1);
        return aScore.compareTo(bScore);
      });

    for (final entry in entries) {
      if (currentCacheSize <= _maxCacheSize) {
        break;
      }

      final cacheFile = _fs.file(entry.cacheKey);
      final fileSize = entry.persistedResponseSize;

      if (cacheFile.existsSync()) {
        await cacheFile.delete();
        currentCacheSize -= fileSize;
      }

      // Remove the cache entry from the journal entry.
      final journalEntry = _journal.entries.values.firstWhereOrNull(
        (journalEntry) => journalEntry.cacheEntries.containsKey(entry.cacheKey),
      );

      if (journalEntry != null) {
        journalEntry.cacheEntries.remove(entry.cacheKey);
        if (journalEntry.cacheEntries.isEmpty) {
          _journal.entries.remove(journalEntry.cacheKey);
        }
      }
    }

    _debounceJournalSave();
  }

  /// Debounce the journal save operation to reduce the number of I/O operations.
  void _debounceJournalSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () async {
      await _journal.writeJournal(_fs, asJson: _jsonJournal);
    });
  }
}

extension _MapExtension on Map<String, String> {
  Map<String, String> toLowerCaseKeys() => map((key, value) => MapEntry(key.toLowerCase(), value));
}
