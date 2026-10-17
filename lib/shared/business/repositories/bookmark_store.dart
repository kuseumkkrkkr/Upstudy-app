import 'dart:convert';

import 'package:s11/shared/services/api/api_client.dart';

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
    final scope = await ApiClient.instance.requireSessionScope();
    final raw = await _loadRaw(scope);
    ApiClient.instance.assertSessionScope(scope);
    if (raw == null || raw.isEmpty) return <BookmarkItem>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) throw const FormatException('Invalid bookmark list');
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(BookmarkItem.fromJson)
        .toList();
  }

  /// 인증 계정의 저장소에 저장한다. 서버 실패를 성공으로 숨기지 않는다.
  static Future<void> save(
    List<BookmarkItem> items, {
    ApiSessionScope? scope,
  }) async {
    scope ??= await ApiClient.instance.requireSessionScope();
    ApiClient.instance.assertSessionScope(scope);
    final payload = jsonEncode(items.map((item) => item.toJson()).toList());
    await LocalDb.instance.setString(_key, payload, scope: scope);
    ApiClient.instance.assertSessionScope(scope);
  }

  /// 소유자를 증명할 수 없는 generic legacy 값은 보존하되 자동 이관하지 않는다.
  static Future<String?> _loadRaw(ApiSessionScope scope) async {
    return LocalDb.instance.getString(_key, scope: scope);
  }

  static Future<List<BookmarkItem>> add(BookmarkItem item) async {
    final scope = await ApiClient.instance.requireSessionScope();
    final items = await load();
    ApiClient.instance.assertSessionScope(scope);
    final exists = items.any(
      (existing) =>
          existing.bookId == item.bookId &&
          existing.entryIndex == item.entryIndex,
    );
    if (!exists) {
      items.insert(0, item);
      await save(items, scope: scope);
    }
    return items;
  }

  static Future<List<BookmarkItem>> remove(String id) async {
    final scope = await ApiClient.instance.requireSessionScope();
    final items = await load();
    ApiClient.instance.assertSessionScope(scope);
    items.removeWhere((item) => item.id == id);
    await save(items, scope: scope);
    return items;
  }
}
