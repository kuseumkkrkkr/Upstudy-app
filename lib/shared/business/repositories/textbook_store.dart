import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/data/models/concept_textbooks.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/storage/local_db.dart';

class TextbookStore {
  static const String _libraryKey = 'textbook_library_v1';
  static const String _cachePrefix = 'textbook_cache_v1_';
  static const int maxLibraryItems = 10;

  static const List<BookData> _seedBooks = [
    BookData(
      id: 'seed_textbook_math',
      title: '기초 수학 교재',
      subtitle: '연산과 식의 기본을 익히는 샘플 교재',
      coverColor: Color(0xFF1B402B),
      category: 'common',
      tags: ['수학', '기초', '샘플'],
      chapters: [
        BookChapter(
          title: '1. 수의 구조',
          intro: ['교재가 DB와 연결되었는지 확인할 수 있는 샘플 교재입니다.'],
          sections: [
            BookSection(
              title: '1-1. 자연수와 정수',
              paragraphs: [
                '자연수는 셀 수 있는 수, 정수는 음수와 0을 포함한 수입니다.',
                '학습터에서 로드되는지 확인하는 더미 데이터로 사용할 수 있습니다.',
              ],
            ),
            BookSection(
              title: '1-2. 식의 계산',
              paragraphs: [
                '같은 항끼리 더하고 빼는 과정을 연습합니다.',
                'DB에 저장된 교재는 앱을 다시 열어도 유지됩니다.',
              ],
            ),
          ],
        ),
      ],
    ),
    BookData(
      id: 'seed_textbook_korean',
      title: '문장 독해 교재',
      subtitle: '짧은 글을 읽고 핵심을 찾는 샘플 교재',
      coverColor: Color(0xFF2D6A4F),
      category: 'common',
      tags: ['국어', '독해', '샘플'],
      chapters: [
        BookChapter(
          title: '1. 글의 중심 생각',
          intro: ['짧은 문단에서 핵심 문장을 찾는 연습을 합니다.'],
          sections: [
            BookSection(
              title: '1-1. 주제문 찾기',
              paragraphs: [
                '주제문은 글 전체를 대표하는 문장입니다.',
                '샘플 데이터이지만 실제 교재처럼 목록과 본문이 분리됩니다.',
              ],
            ),
            BookSection(
              title: '1-2. 요약하기',
              paragraphs: ['긴 글을 짧게 줄이는 연습을 합니다.'],
            ),
          ],
        ),
      ],
    ),
    BookData(
      id: 'seed_textbook_science',
      title: '과학 개념 교재',
      subtitle: '탐구 흐름을 익히는 샘플 교재',
      coverColor: Color(0xFF3A7CA5),
      category: 'common',
      tags: ['과학', '개념', '샘플'],
      chapters: [
        BookChapter(
          title: '1. 관찰과 실험',
          intro: ['실험 과정을 순서대로 이해하는 교재입니다.'],
          sections: [
            BookSection(
              title: '1-1. 변인 통제',
              paragraphs: ['실험에서는 한 번에 한 가지 변수만 바꾸는 것이 중요합니다.'],
            ),
            BookSection(
              title: '1-2. 결과 정리',
              paragraphs: ['관찰한 내용을 표와 문장으로 정리합니다.'],
            ),
          ],
        ),
      ],
    ),
  ];

  static const List<BookData> fallbackBooks = _seedBooks;

  static List<BookData> _cache = <BookData>[];
  static Future<List<BookData>>? _loadFuture;
  static List<BookData>? _libraryCache;
  static Future<List<BookData>>? _libraryFuture;
  static bool _sessionListenerAttached = false;
  static ApiSessionScope? _scope;

  static void _listenForSessionChanges() {
    if (_sessionListenerAttached) return;
    _sessionListenerAttached = true;
    ApiClient.instance.sessionChanges.addListener(() {
      _scope = null;
      _cache = <BookData>[];
      _libraryCache = null;
      _loadFuture = null;
      _libraryFuture = null;
    });
  }

  static Future<ApiSessionScope> _requireScope([
    ApiSessionScope? expected,
  ]) async {
    _listenForSessionChanges();
    final scope = expected ?? await ApiClient.instance.requireSessionScope();
    ApiClient.instance.assertSessionScope(scope);
    _scope = scope;
    return scope;
  }

  /// 현재 세션에서 실제로 읽은 교재만 반환한다.
  /// 네트워크·저장소가 비어 있을 때 샘플 교재를 상용 데이터처럼 노출하지 않는다.
  static List<BookData> get cachedBooks {
    _listenForSessionChanges();
    return _scope != null && ApiClient.instance.isCurrentSessionScope(_scope!)
        ? List.unmodifiable(_cache)
        : const <BookData>[];
  }

  static Future<List<BookData>> load({
    String? category,
    List<String> tags = const [],
    bool forceRefresh = false,
  }) async {
    if (category == 'common' && tags.isNotEmpty) {
      return [buildConceptBook(tags)];
    }
    final all = await _loadAll(forceRefresh: forceRefresh);
    var filtered = all;
    if (category != null && category.trim().isNotEmpty) {
      final target = category.trim();
      filtered = filtered.where((book) => book.category == target).toList();
    }
    // 기본 공통교재는 서버 상태와 무관하게 앱에 내장된 개념서 목록을 함께 제공한다.
    // 원격 교재와 ID가 겹치면 원격 교재를 우선해 교사 제작 교재를 덮어쓰지 않는다.
    if ((category == null || category == 'common') && tags.isEmpty) {
      final conceptIds = kConceptTextbooks.keys.toSet();
      filtered = filtered
          .where((book) => !conceptIds.contains(book.id))
          .toList(growable: false);
      final existingIds = filtered.map((book) => book.id).toSet();
      final conceptBook = kAllConceptBook;
      filtered = [
        ...filtered,
        if (!existingIds.contains(conceptBook.id)) conceptBook,
      ];
    }
    if (tags.isNotEmpty) {
      filtered = filtered
          .where((book) => _matchesTags(book.tags, tags))
          .toList();
    }
    return filtered;
  }

  static Future<BookData?> getById(String id) async {
    // 내장 개념서는 네트워크와 로컬 캐시를 거치지 않고 즉시 반환한다.
    // 교재보기에서 기본 개념서를 열 때 불필요한 DB/API 요청을 만들지 않는다.
    final concept = kConceptTextbooks[id];
    if (concept != null) return concept;
    if (id == 'concept_book_common') return kAllConceptBook;
    final scope = await _requireScope();
    final cached = await _loadCachedBook(id, scope);
    ApiClient.instance.assertSessionScope(scope);
    if (cached != null) return cached;
    final remote = await _fetchRemoteBook(id, scope);
    ApiClient.instance.assertSessionScope(scope);
    if (remote != null) {
      await _saveCachedBook(remote, scope);
      ApiClient.instance.assertSessionScope(scope);
      return remote;
    }
    final all = await _loadAll();
    ApiClient.instance.assertSessionScope(scope);
    return _firstWhereOrNull<BookData>(all, (book) => book.id == id);
  }

  static String displayNumberFor(BookData book) {
    final index = cachedBooks.indexWhere((entry) => entry.id == book.id);
    if (index >= 0) return (index + 1).toString();
    return book.id;
  }

  static Future<BookData> create(BookData draft) async {
    final scope = await _requireScope();
    final payload = draft.toCreateJson();
    final createdRaw = await ApiClient.instance.createTextbook(
      payload,
      expectedScope: scope,
    );
    return _rememberCreatedBook(createdRaw, scope);
  }

  static Future<BookData> importSource(String source, String sha256, {
    required ApiSessionScope expectedScope,
  }) async {
    final scope = await _requireScope(expectedScope);
    final raw = await ApiClient.instance.importTextbookSource(source, sha256, expectedScope: scope);
    return _rememberCreatedBook(raw, scope);
  }

  static Future<BookData> _rememberCreatedBook(Map<String, dynamic> raw, ApiSessionScope scope) async {
    ApiClient.instance.assertSessionScope(scope);
    final previous = _firstWhereOrNull<BookData>(
      [...(_libraryCache ?? const <BookData>[]), ...cachedBooks],
      (book) => book.id == raw['textbook_id'],
    );
    final merged = Map<String, dynamic>.from(raw);
    if (previous != null && previous.progress > ((raw['progress'] as num?)?.toDouble() ?? 0)) {
      merged['progress'] = previous.progress;
      merged['progress_label'] = previous.progressLabel;
    }
    final created = BookData.fromJson(merged);
    if (created.id.trim().isEmpty) {
      throw const FormatException('textbook_create_missing_id');
    }
    _cache = [created, ...cachedBooks.where((book) => book.id != created.id)];
    await _saveBook(created, scope);
    ApiClient.instance.assertSessionScope(scope);
    await addToLibrary(created, scope: scope);
    ApiClient.instance.assertSessionScope(scope);
    return created;
  }

  static Future<List<BookData>> loadLibrary({bool forceRefresh = false}) async {
    final scope = await _requireScope();
    if (!forceRefresh && _libraryCache != null) {
      return _libraryCache!;
    }
    if (_libraryFuture != null && !forceRefresh) {
      return _libraryFuture!;
    }
    final future = _fetchLibraryMeta(forceRefresh: forceRefresh);
    _libraryFuture = future;
    try {
      final books = await future;
      ApiClient.instance.assertSessionScope(scope);
      return books;
    } finally {
      if (identical(_libraryFuture, future)) _libraryFuture = null;
    }
  }

  static Future<void> saveLibraryMeta(
    List<BookData> books, {
    ApiSessionScope? scope,
  }) async {
    scope = await _requireScope(scope);
    final payload = jsonEncode(
      books.map((book) => book.toLibraryJson()).toList(),
    );
    if (!kIsWeb) {
      await ApiClient.instance.setUserStorage(
        _libraryKey,
        payload,
        scope: scope,
      );
      ApiClient.instance.assertSessionScope(scope);
    }
    await LocalDb.instance.setString(_libraryKey, payload, scope: scope);
    ApiClient.instance.assertSessionScope(scope);
    _libraryCache = List<BookData>.from(books);
  }

  static Future<void> addToLibrary(
    BookData book, {
    ApiSessionScope? scope,
  }) async {
    scope = await _requireScope(scope);
    final items = await loadLibrary();
    ApiClient.instance.assertSessionScope(scope);
    if (items.any((entry) => entry.id == book.id)) return;
    final updated = [...items, _stripToLibraryMeta(book)];
    final trimmed = updated.length > maxLibraryItems
        ? updated.sublist(updated.length - maxLibraryItems)
        : updated;
    await saveLibraryMeta(trimmed, scope: scope);
  }

  // 필요 변수: 보관함에서 제거할 교재 ID. 작동 원리: 교재 원본은 지우지 않고
  // 사용자 보관함 메타데이터에서만 제외해 다시 내려받거나 마켓에서 찾을 수 있게 한다.
  static Future<void> removeFromLibrary(String bookId) async {
    final scope = await _requireScope();
    final id = bookId.trim();
    if (id.isEmpty) return;
    final items = await loadLibrary();
    ApiClient.instance.assertSessionScope(scope);
    await saveLibraryMeta(
      items.where((item) => item.id != id).toList(growable: false),
      scope: scope,
    );
  }

  static Future<void> download(BookData book) async {
    final scope = await _requireScope();
    await addToLibrary(book, scope: scope);
    ApiClient.instance.assertSessionScope(scope);
    await _saveBook(book, scope);
  }

  static Future<bool> hasLocalCopy(String id) async {
    final cached = await _loadCachedBook(id);
    return cached != null;
  }

  static Future<List<BookData>> _loadAll({bool forceRefresh = false}) async {
    final scope = await _requireScope();
    if (!forceRefresh && _cache.isNotEmpty) {
      return _cache;
    }
    if (_loadFuture != null && !forceRefresh) {
      return _loadFuture!;
    }
    final future = _fetchRemote();
    _loadFuture = future;
    try {
      final books = await future;
      ApiClient.instance.assertSessionScope(scope);
      return books;
    } finally {
      if (identical(_loadFuture, future)) _loadFuture = null;
    }
  }

  static Future<List<BookData>> _fetchRemote() async {
    final scope = await _requireScope();
    final raw = await ApiClient.instance.listTextbooks();
    ApiClient.instance.assertSessionScope(scope);
    final books = raw.map(BookData.fromJson).toList();
    _cache = books;
    return books;
  }

  static Future<BookData?> _fetchRemoteBook(
    String id, [
    ApiSessionScope? expected,
  ]) async {
    final scope = await _requireScope(expected);
    try {
      final raw = await ApiClient.instance.getTextbook(id);
      ApiClient.instance.assertSessionScope(scope);
      final book = BookData.fromJson(raw);
      return book.id.trim().isEmpty ? null : book;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) rethrow;
      ApiClient.instance.assertSessionScope(scope);
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  static BookData _stripToLibraryMeta(BookData book) {
    return BookData(
      id: book.id,
      title: book.title,
      subtitle: book.subtitle,
      chapters: const [],
      progress: book.progress,
      progressLabel: book.progressLabel,
      coverColor: book.coverColor,
      tags: book.tags,
      category: book.category,
      createdAt: book.createdAt,
      updatedAt: book.updatedAt,
      createdBy: book.createdBy,
      curriculumVersion: book.curriculumVersion,
      standardCodes: book.standardCodes,
      sourceSha256: book.sourceSha256,
      schemaVersion: book.schemaVersion,
      candidateStandardCodes: book.candidateStandardCodes,
    );
  }

  static Future<List<BookData>> _fetchLibraryMeta({
    bool forceRefresh = false,
  }) async {
    final scope = await _requireScope();
    final stored =
        await _loadLibraryFromStorage(forceRefresh: forceRefresh) ??
        const <BookData>[];
    ApiClient.instance.assertSessionScope(scope);
    final books = _hasLibraryHeaders(stored)
        ? stored
        : await _hydrateLibraryHeaders(stored);
    ApiClient.instance.assertSessionScope(scope);
    final List<Map<String, dynamic>> published;
    try {
      published = await ApiClient.instance.listPublicTextbooks(
        ownedOnly: true,
        expectedScope: scope,
      );
    } catch (error) {
      ApiClient.instance.assertSessionScope(scope);
      final transient =
          (error is ApiException && error.statusCode >= 500) ||
          error is http.ClientException || error is TimeoutException;
      // Preserve the existing native offline contract, but never turn auth
      // errors or an unknown/empty library into a successful empty response.
      if (kIsWeb || books.isEmpty || !transient) rethrow;
      _libraryCache = books;
      return books;
    }
    ApiClient.instance.assertSessionScope(scope);
    // Public acquisitions are server-owned, not subject to the personal ten-item
    // cache limit. Existing local reading progress wins for a matching ID.
    final merged = <String, BookData>{
      for (final item in published)
        item['textbook_id'].toString(): BookData.fromJson(item),
      for (final book in books) book.id: book,
    }.values.toList(growable: false);
    _libraryCache = merged;
    return merged;
  }

  static Future<BookData?> _loadCachedBook(
    String id, [
    ApiSessionScope? expected,
  ]) async {
    final scope = await _requireScope(expected);
    final raw = await LocalDb.instance.getString(
      '$_cachePrefix$id',
      scope: scope,
    );
    ApiClient.instance.assertSessionScope(scope);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return BookData.fromJson(decoded);
    }
    if (decoded is Map) {
      return BookData.fromJson(Map<String, dynamic>.from(decoded));
    }
    throw const FormatException('Invalid cached textbook');
  }

  static Future<void> _saveCachedBook(
    BookData book,
    ApiSessionScope scope,
  ) async {
    final payload = jsonEncode(book.toJson());
    await LocalDb.instance.setString(
      '$_cachePrefix${book.id}',
      payload,
      scope: scope,
    );
  }

  static Future<void> _saveBook(BookData book, ApiSessionScope scope) async {
    ApiClient.instance.assertSessionScope(scope);
    await _saveCachedBook(book, scope);
    ApiClient.instance.assertSessionScope(scope);
    final library = await _loadLibraryMetaEntries();
    ApiClient.instance.assertSessionScope(scope);
    if (!library.any((entry) => entry.id == book.id)) {
      final updated = [...library, _stripToLibraryMeta(book)];
      await saveLibraryMeta(_trimLibrary(updated), scope: scope);
    }
  }

  static Future<List<BookData>?> _loadLibraryFromStorage({
    bool forceRefresh = false,
  }) async {
    final scope = await _requireScope();
    String? raw;
    if (kIsWeb) {
      raw = await LocalDb.instance.getString(
        _libraryKey,
        scope: scope,
        forceRefresh: forceRefresh,
      );
    } else {
      try {
        raw = await ApiClient.instance.getUserStorage(
          _libraryKey,
          scope: scope,
          forceRefresh: forceRefresh,
        );
        ApiClient.instance.assertSessionScope(scope);
        if (raw == null) {
          await LocalDb.instance.delete(_libraryKey, scope: scope);
        } else {
          await LocalDb.instance.setString(_libraryKey, raw, scope: scope);
        }
      } on ApiException catch (error) {
        if (error.statusCode == 401 || error.statusCode == 403) rethrow;
        ApiClient.instance.assertSessionScope(scope);
        if (error.statusCode == 404) {
          await LocalDb.instance.delete(_libraryKey, scope: scope);
          return null;
        }
        if (error.statusCode < 500) rethrow;
        raw = await LocalDb.instance.getString(_libraryKey, scope: scope);
        if (raw == null) rethrow;
      } on http.ClientException {
        ApiClient.instance.assertSessionScope(scope);
        raw = await LocalDb.instance.getString(_libraryKey, scope: scope);
        if (raw == null) rethrow;
      } on TimeoutException {
        ApiClient.instance.assertSessionScope(scope);
        raw = await LocalDb.instance.getString(_libraryKey, scope: scope);
        if (raw == null) rethrow;
      }
    }
    ApiClient.instance.assertSessionScope(scope);
    return _parseLibraryMeta(raw);
  }

  static Future<List<BookData>> _loadLibraryMetaEntries() async {
    final storage = await _loadLibraryFromStorage();
    return storage ?? const <BookData>[];
  }

  static List<BookData> _trimLibrary(List<BookData> books) {
    if (books.length <= maxLibraryItems) return books;
    return books.sublist(books.length - maxLibraryItems);
  }

  static List<BookData>? _parseLibraryMeta(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final items = <BookData>[];
        for (final entry in decoded) {
          if (entry is Map) {
            items.add(BookData.fromJson(Map<String, dynamic>.from(entry)));
          } else if (entry != null) {
            final id = entry.toString().trim();
            if (id.isEmpty) continue;
            items.add(
              BookData(id: id, title: '', subtitle: '', chapters: const []),
            );
          }
        }
        return items;
      }
    } on FormatException {
      rethrow;
    }
    throw const FormatException('Invalid textbook library');
  }

  static bool _hasLibraryHeaders(List<BookData> books) {
    if (books.isEmpty) return false;
    return books.every((book) => book.title.trim().isNotEmpty);
  }

  static Future<List<BookData>> _hydrateLibraryHeaders(
    List<BookData> items,
  ) async {
    final scope = await _requireScope();
    final result = <BookData>[];
    for (final item in items) {
      if (item.title.trim().isNotEmpty) {
        result.add(item);
        continue;
      }
      final fetched = await _fetchRemoteBook(item.id, scope);
      ApiClient.instance.assertSessionScope(scope);
      if (fetched != null) {
        result.add(_stripToLibraryMeta(fetched));
      }
    }
    return result;
  }
}

bool _matchesTags(List<String> bookTags, List<String> selected) {
  if (bookTags.isEmpty || selected.isEmpty) return false;
  final tagSet = bookTags
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty);
  final selectedSet = selected
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toSet();
  for (final tag in tagSet) {
    if (selectedSet.contains(tag)) return true;
  }
  return false;
}

T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}
