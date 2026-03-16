import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
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
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(items.map((item) => item.toJson()).toList());
    await prefs.setString(_key, payload);
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
