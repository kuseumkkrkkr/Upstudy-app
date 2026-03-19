import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_db.dart';

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

  static Future<void> save(List<BookmarkItem> items) async {
    final payload = jsonEncode(items.map((item) => item.toJson()).toList());
    await LocalDb.instance.setString(_key, payload);
  }

  static Future<String?> _loadRaw() async {
    final db = LocalDb.instance;
    final cached = await db.getString(_key);
    if (cached != null && cached.isNotEmpty) return cached;
    if (kIsWeb) return cached;
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_key);
    if (legacy != null && legacy.isNotEmpty) {
      await db.setString(_key, legacy);
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
