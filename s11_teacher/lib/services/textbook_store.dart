import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/textbook.dart';
import '../models/concept_textbooks.dart';
import 'api_client.dart';
import 'local_db.dart';

class TextbookStore {
  static const String _libraryKey = 'textbook_library_v1';
  static const String _libraryCacheKey = 'textbook_library_cache_v1';
  static const String _cachePrefix = 'textbook_cache_v1_';
  static const int maxLibraryItems = 10;

  static const BookData _testBook = BookData(
    id: 'test_textbook',
    title: '테스트 교재',
    subtitle: '교재 사용법 안내',
    coverColor: Color(0xFF0A0A0A),
    category: 'common',
    tags: ['테스트', '안내'],
    chapters: [
      BookChapter(
        title: '1. 교재 사용법',
        intro: [
          '이 교재는 테스트용 더미입니다.',
          '실제 교재는 서버의 textbook.db에서 불러옵니다.',
        ],
        sections: [
          BookSection(
            title: '1-1. 교재 보기',
            paragraphs: [
              '학습 모달에서 교재보기를 누르면 교재 목록이 열립니다.',
              '목차에서 대제목/소주제를 선택해 빠르게 이동할 수 있습니다.',
            ],
          ),
          BookSection(
            title: '1-2. 교재 만들기',
            paragraphs: [
              '학습터에서 교재 만들기를 선택하면 직접 집필 에디터가 열립니다.',
              '대제목과 소주제를 추가하고 소주제 단위로 내용을 입력하세요.',
            ],
          ),
          BookSection(
            title: '1-3. 이미지 추가',
            paragraphs: [
              '소주제 하단에 이미지 URL을 추가하면 본문에 표시됩니다.',
              '예: https://... 또는 /assets/... 형식을 사용할 수 있습니다.',
            ],
          ),
        ],
      ),
    ],
  );

  static const List<BookData> fallbackBooks = [_testBook];

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
    if (tags.isNotEmpty) {
      filtered = filtered
          .where((book) => _matchesTags(book.tags, tags))
          .toList();
    }
    return filtered;
  }

  static Future<BookData?> getById(String id) async {
    if (!kIsWeb) {
      final cached = await _loadCachedBook(id);
      if (cached != null) return cached;
    }
    final remote = await _fetchRemoteBook(id);
    if (remote != null) {
      if (!kIsWeb) {
        await _saveCachedBook(remote);
      }
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
    final createdRaw = await ApiClient.instance.createTextbook(payload);
    final created = BookData.fromJson(createdRaw);
    _cache = [created, ...cachedBooks.where((book) => book.id != created.id)];
    await addToLibrary(created);
    if (!kIsWeb) {
      await _saveCachedBook(created);
    }
    return created;
  }

  static Future<List<BookData>> loadLibrary({bool forceRefresh = false}) async {
    if (!forceRefresh && _libraryCache != null) {
      return _libraryCache!;
    }
    if (_libraryFuture != null && !forceRefresh) {
      return _libraryFuture!;
    }
    _libraryFuture = _fetchLibraryMeta(forceRefresh: forceRefresh).whenComplete(() {
      _libraryFuture = null;
    });
    return _libraryFuture!;
  }

  static Future<void> saveLibraryMeta(List<BookData> books) async {
    final payload = jsonEncode(books.map((book) => book.toLibraryJson()).toList());
    await ApiClient.instance.setUserStorage(_libraryKey, payload);
    _libraryCache = books;
    if (!kIsWeb) {
      await LocalDb.instance.setString(_libraryCacheKey, payload);
    }
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

  static Future<void> download(BookData book) async {
    await addToLibrary(book);
    if (!kIsWeb) {
      await _saveCachedBook(book);
    }
  }

  static Future<bool> hasLocalCopy(String id) async {
    if (kIsWeb) return false;
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
      if (books.isNotEmpty) {
        _cache = books;
        return _cache;
      }
    } catch (_) {}
    if (_cache.isEmpty) {
      _cache = fallbackBooks;
    }
    return _cache;
  }

  static Future<BookData?> _fetchRemoteBook(String id) async {
    try {
      final raw = await ApiClient.instance.getTextbook(id);
      return BookData.fromJson(raw);
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
      if (meta.isNotEmpty) {
        await saveLibraryMeta(meta);
        return meta;
      }
    } catch (_) {}

    if (!forceRefresh) {
      final localFallback = await _loadLibraryFromLocal();
      if (localFallback != null) {
        _libraryCache = localFallback;
        return localFallback;
      }
    }

    _libraryCache = <BookData>[];
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

  static Future<List<BookData>?> _loadLibraryFromStorage() async {
    List<BookData>? items;
    try {
      final raw = await ApiClient.instance.getUserStorage(_libraryKey);
      items = _parseLibraryMeta(raw);
    } catch (_) {
      items = null;
    }
    if (items != null && !kIsWeb) {
      await LocalDb.instance.setString(
        _libraryCacheKey,
        jsonEncode(items.map((book) => book.toLibraryJson()).toList()),
      );
    }
    return items;
  }

  static Future<List<BookData>?> _loadLibraryFromLocal() async {
    if (kIsWeb) return null;
    final raw = await LocalDb.instance.getString(_libraryCacheKey);
    return _parseLibraryMeta(raw);
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
              BookData(
                id: id,
                title: '',
                subtitle: '',
                chapters: const [],
              ),
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
  final tagSet = bookTags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty);
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
