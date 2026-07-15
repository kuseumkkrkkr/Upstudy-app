import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:s11/shared/services/storage/local_db.dart';

class BookmarkItem {
  const BookmarkItem({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.entryIndex,
    required this.entryTitle,
    required this.createdAt,
  });

  final String id;
  final String bookId;
  final String bookTitle;
  final int entryIndex;
  final String entryTitle;
  final int createdAt;

  factory BookmarkItem.fromJson(Map<String, dynamic> json) {
    return BookmarkItem(
      id: json['id']?.toString() ?? '',
      bookId: json['book_id']?.toString() ?? '',
      bookTitle: json['book_title']?.toString() ?? '',
      entryIndex: (json['entry_index'] as num?)?.toInt() ?? 0,
      entryTitle: json['entry_title']?.toString() ?? '',
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book_id': bookId,
      'book_title': bookTitle,
      'entry_index': entryIndex,
      'entry_title': entryTitle,
      'created_at': createdAt,
    };
  }
}

class BookmarkStore {
  static const _key = 'bookmarks_v1';

  static Future<List<BookmarkItem>> load() async {
    final raw = await _loadRaw();
    if (raw == null || raw.isEmpty) return <BookmarkItem>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <BookmarkItem>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(BookmarkItem.fromJson)
          .toList();
    } catch (_) {
      return <BookmarkItem>[];
    }
  }

  // 필요 변수: 북마크 목록. 작동 원리: 로컬 DB를 우선 사용하고 지원되지 않는 테스트 환경은 SharedPreferences로 안전하게 대체한다.
  static Future<void> save(List<BookmarkItem> items) async {
    final payload = jsonEncode(items.map((item) => item.toJson()).toList());
    try {
      await LocalDb.instance.setString(_key, payload);
    } catch (_) {
      if (!kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_key, payload);
      }
    }
  }

  // 필요 변수: 로컬 DB와 이전 SharedPreferences 값. 작동 원리: DB를 우선 읽고 사용할 수 없거나 비어 있으면 이전 저장소를 복원한다.
  static Future<String?> _loadRaw() async {
    final db = LocalDb.instance;
    String? cached;
    try {
      cached = await db.getString(_key);
    } catch (_) {
      cached = null;
    }
    if (cached != null && cached.isNotEmpty) return cached;
    if (kIsWeb) return cached;
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_key);
    if (legacy != null && legacy.isNotEmpty) {
      try {
        await db.setString(_key, legacy);
      } catch (_) {
        // 테스트처럼 DB 플러그인이 없는 환경은 이전 저장소 값을 그대로 사용한다.
      }
      return legacy;
    }
    return cached;
  }

  static Future<List<BookmarkItem>> add(BookmarkItem item) async {
    final items = await load();
    final exists = items.any(
      (existing) =>
          existing.bookId == item.bookId &&
          existing.entryIndex == item.entryIndex,
    );
    if (!exists) {
      items.insert(0, item);
      await save(items);
    }
    return items;
  }

  static Future<List<BookmarkItem>> remove(String id) async {
    final items = await load();
    items.removeWhere((item) => item.id == id);
    await save(items);
    return items;
  }
}
