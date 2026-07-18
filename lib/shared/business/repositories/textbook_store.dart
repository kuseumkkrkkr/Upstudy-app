import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/data/models/concept_textbooks.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/storage/local_db.dart';

class TextbookStore {
  static const String _libraryKey = 'textbook_library_v1';
  static const String _libraryCacheKey = 'textbook_library_cache_v1';
  static const String _cachePrefix = 'textbook_cache_v1_';
  static const String _seedStateKey = 'textbook_seed_state_v1';
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

  static List<BookData> get cachedBooks =>
      _cache.isNotEmpty ? _cache : fallbackBooks;

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
    final cached = await _loadCachedBook(id);
    if (cached != null) return cached;
    final remote = await _fetchRemoteBook(id);
    if (remote != null) {
      await _saveCachedBook(remote);
      return remote;
    }
    final all = await _loadAll();
    return _firstWhereOrNull<BookData>(all, (book) => book.id == id) ??
        _firstWhereOrNull<BookData>(fallbackBooks, (book) => book.id == id);
  }

  static String displayNumberFor(BookData book) {
    final index = cachedBooks.indexWhere((entry) => entry.id == book.id);
    if (index >= 0) return (index + 1).toString();
    return book.id;
  }

  static Future<BookData> create(BookData draft) async {
    final payload = draft.toCreateJson();
    BookData created;
    try {
      final createdRaw = await ApiClient.instance.createTextbook(payload);
      final remote = BookData.fromJson(createdRaw);
      created = remote.id.trim().isNotEmpty
          ? remote
          : _materializeLocalBook(draft);
    } catch (_) {
      created = _materializeLocalBook(draft);
    }
    _cache = [created, ...cachedBooks.where((book) => book.id != created.id)];
    await _saveBook(created);
    await addToLibrary(created);
    return created;
  }

  static Future<List<BookData>> loadLibrary({bool forceRefresh = false}) async {
    if (!forceRefresh && _libraryCache != null) {
      return _libraryCache!;
    }
    if (_libraryFuture != null && !forceRefresh) {
      return _libraryFuture!;
    }
    _libraryFuture = _fetchLibraryMeta(forceRefresh: forceRefresh).whenComplete(
      () {
        _libraryFuture = null;
      },
    );
    return _libraryFuture!;
  }

  static Future<void> saveLibraryMeta(List<BookData> books) async {
    final payload = jsonEncode(
      books.map((book) => book.toLibraryJson()).toList(),
    );
    try {
      await ApiClient.instance.setUserStorage(_libraryKey, payload);
    } catch (_) {}
    _libraryCache = books;
    await LocalDb.instance.setString(_libraryCacheKey, payload);
  }

  static Future<void> addToLibrary(BookData book) async {
    final items = await loadLibrary();
    if (items.any((entry) => entry.id == book.id)) return;
    final updated = [...items, _stripToLibraryMeta(book)];
    final trimmed = updated.length > maxLibraryItems
        ? updated.sublist(updated.length - maxLibraryItems)
        : updated;
    await saveLibraryMeta(trimmed);
  }

  // 필요 변수: 보관함에서 제거할 교재 ID. 작동 원리: 교재 원본은 지우지 않고
  // 사용자 보관함 메타데이터에서만 제외해 다시 내려받거나 마켓에서 찾을 수 있게 한다.
  static Future<void> removeFromLibrary(String bookId) async {
    final id = bookId.trim();
    if (id.isEmpty) return;
    final items = await loadLibrary();
    await saveLibraryMeta(
      items.where((item) => item.id != id).toList(growable: false),
    );
  }

  static Future<void> download(BookData book) async {
    await addToLibrary(book);
    await _saveBook(book);
  }

  static Future<bool> hasLocalCopy(String id) async {
    final cached = await _loadCachedBook(id);
    return cached != null;
  }

  static Future<List<BookData>> _loadAll({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache.isNotEmpty) {
      return _cache;
    }
    if (_loadFuture != null && !forceRefresh) {
      return _loadFuture!;
    }
    _loadFuture = _fetchRemote().whenComplete(() => _loadFuture = null);
    return _loadFuture!;
  }

  static Future<List<BookData>> _fetchRemote() async {
    try {
      final raw = await ApiClient.instance.listTextbooks();
      final books = raw.map(BookData.fromJson).toList();
      _cache = books;
      return _cache;
    } catch (_) {}
    final local = await _loadStoredBooks();
    if (local.isNotEmpty) {
      _cache = local;
      return _cache;
    }
    await _seedLibrary();
    _cache = fallbackBooks;
    return _cache;
  }

  static Future<BookData?> _fetchRemoteBook(String id) async {
    try {
      final raw = await ApiClient.instance.getTextbook(id);
      final book = BookData.fromJson(raw);
      return book.id.trim().isEmpty ? null : book;
    } catch (_) {
      return null;
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
    );
  }

  static Future<List<BookData>> _fetchLibraryMeta({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _loadLibraryFromStorage();
      if (cached != null && cached.isNotEmpty && _hasLibraryHeaders(cached)) {
        _libraryCache = cached;
        return cached;
      }
      if (cached != null && cached.isNotEmpty) {
        final hydrated = await _hydrateLibraryHeaders(cached);
        if (hydrated.isNotEmpty) {
          await saveLibraryMeta(hydrated);
          return hydrated;
        }
      }
    }

    try {
      final raw = await ApiClient.instance.listTextbooks();
      final books = raw.map(BookData.fromJson).toList();
      final meta = books.map(_stripToLibraryMeta).toList();
      await saveLibraryMeta(meta);
      return meta;
    } catch (_) {}

    if (!forceRefresh) {
      final localFallback = await _loadLibraryFromLocal();
      if (localFallback != null) {
        _libraryCache = localFallback;
        return localFallback;
      }
    }

    await _seedLibrary();
    _libraryCache = _seedBooks.map(_stripToLibraryMeta).toList();
    return _libraryCache!;
  }

  static Future<BookData?> _loadCachedBook(String id) async {
    final raw = await LocalDb.instance.getString('$_cachePrefix$id');
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return BookData.fromJson(decoded);
      }
      if (decoded is Map) {
        return BookData.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _saveCachedBook(BookData book) async {
    final payload = jsonEncode(book.toJson());
    await LocalDb.instance.setString('$_cachePrefix${book.id}', payload);
  }

  static Future<void> _saveBook(BookData book) async {
    await _saveCachedBook(book);
    final library = await _loadLibraryMetaEntries();
    if (!library.any((entry) => entry.id == book.id)) {
      final updated = [...library, _stripToLibraryMeta(book)];
      await saveLibraryMeta(_trimLibrary(updated));
    }
  }

  static Future<List<BookData>?> _loadLibraryFromStorage() async {
    List<BookData>? items;
    try {
      final raw = await ApiClient.instance.getUserStorage(_libraryKey);
      items = _parseLibraryMeta(raw);
    } catch (_) {
      items = null;
    }
    if (items != null) {
      await LocalDb.instance.setString(
        _libraryCacheKey,
        jsonEncode(items.map((book) => book.toLibraryJson()).toList()),
      );
    }
    return items;
  }

  static Future<List<BookData>?> _loadLibraryFromLocal() async {
    final raw = await LocalDb.instance.getString(_libraryCacheKey);
    return _parseLibraryMeta(raw);
  }

  static Future<List<BookData>> _loadStoredBooks() async {
    final library = await _loadLibraryMetaEntries();
    if (library.isEmpty) return <BookData>[];
    final result = <BookData>[];
    for (final entry in library) {
      final cached = await _loadCachedBook(entry.id);
      if (cached != null) {
        result.add(cached);
        continue;
      }
      if (entry.chapters.isNotEmpty) {
        result.add(entry);
        continue;
      }
      final remote = await _fetchRemoteBook(entry.id);
      if (remote != null) {
        result.add(remote);
        continue;
      }
      result.add(entry);
    }
    return result.isEmpty ? fallbackBooks : result;
  }

  static Future<List<BookData>> _loadLibraryMetaEntries() async {
    final storage = await _loadLibraryFromStorage();
    if (storage != null && storage.isNotEmpty) return storage;
    final local = await _loadLibraryFromLocal();
    if (local != null && local.isNotEmpty) return local;
    return const <BookData>[];
  }

  static List<BookData> _trimLibrary(List<BookData> books) {
    if (books.length <= maxLibraryItems) return books;
    return books.sublist(books.length - maxLibraryItems);
  }

  static BookData _materializeLocalBook(BookData draft) {
    final now = DateTime.now();
    final id = 'textbook_${now.millisecondsSinceEpoch}';
    return BookData(
      id: id,
      title: draft.title,
      subtitle: draft.subtitle,
      chapters: draft.chapters,
      progress: draft.progress,
      progressLabel: draft.progressLabel,
      coverColor: draft.coverColor,
      tags: draft.tags,
      category: draft.category,
      createdAt: now,
      updatedAt: now,
      createdBy: draft.createdBy,
    );
  }

  static Future<void> _seedLibrary() async {
    final library = await _loadLibraryMetaEntries();
    if (library.isNotEmpty) return;
    final seededMeta = _seedBooks.map(_stripToLibraryMeta).toList();
    await saveLibraryMeta(seededMeta);
    for (final book in _seedBooks) {
      await _saveCachedBook(book);
    }
    try {
      await LocalDb.instance.setString(_seedStateKey, '1');
    } catch (_) {}
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
    } catch (_) {}
    return null;
  }

  static bool _hasLibraryHeaders(List<BookData> books) {
    if (books.isEmpty) return false;
    return books.every((book) => book.title.trim().isNotEmpty);
  }

  static Future<List<BookData>> _hydrateLibraryHeaders(
    List<BookData> items,
  ) async {
    final result = <BookData>[];
    for (final item in items) {
      if (item.title.trim().isNotEmpty) {
        result.add(item);
        continue;
      }
      final fetched = await _fetchRemoteBook(item.id);
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
