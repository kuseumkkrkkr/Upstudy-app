import 'dart:convert';

import 'package:s11/shared/services/storage/local_db.dart';

class ProblemBookmarkItem {
  const ProblemBookmarkItem({
    required this.id,
    required this.title,
    required this.source,
    required this.createdAt,
    this.questId,
    this.codebaseId,
    this.seed,
    this.flowStepCount,
  });

  final String id;
  final String title;
  final String source;
  final int createdAt;
  final String? questId;
  final int? codebaseId;
  final int? seed;
  final int? flowStepCount;

  factory ProblemBookmarkItem.fromJson(Map<String, dynamic> json) {
    return ProblemBookmarkItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      questId: json['quest_id']?.toString(),
      codebaseId: (json['codebase_id'] as num?)?.toInt(),
      seed: (json['seed'] as num?)?.toInt(),
      flowStepCount: (json['flow_step_count'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'source': source,
      'created_at': createdAt,
      'quest_id': questId,
      'codebase_id': codebaseId,
      'seed': seed,
      'flow_step_count': flowStepCount,
    };
  }
}

class ProblemBookmarkSnapshot {
  const ProblemBookmarkSnapshot({
    required this.serverItems,
    required this.localOverflowItems,
  });

  final List<ProblemBookmarkItem> serverItems;
  final List<ProblemBookmarkItem> localOverflowItems;

  List<ProblemBookmarkItem> get allItems => [
    ...serverItems,
    ...localOverflowItems,
  ];
}

class ProblemBookmarkStore {
  static const int maxServerBookmarks = 300;
  static const String _serverKey = 'problem_bookmarks_server_cache_v1';
  static const String _overflowKey = 'problem_bookmarks_local_overflow_v1';

  static Future<ProblemBookmarkSnapshot> load() async {
    final server = await _loadList(_serverKey);
    final overflow = await _loadList(_overflowKey);
    return ProblemBookmarkSnapshot(
      serverItems: server,
      localOverflowItems: overflow,
    );
  }

  static Future<ProblemBookmarkSnapshot> add(ProblemBookmarkItem item) async {
    final snapshot = await load();
    final all = snapshot.allItems;
    final exists = all.any(
      (it) =>
          (item.questId != null &&
              item.questId!.isNotEmpty &&
              it.questId == item.questId) ||
          (it.codebaseId == item.codebaseId && it.seed == item.seed),
    );
    if (exists) return snapshot;

    final server = List<ProblemBookmarkItem>.from(snapshot.serverItems);
    final overflow = List<ProblemBookmarkItem>.from(snapshot.localOverflowItems);

    if (server.length < maxServerBookmarks) {
      server.insert(0, item);
    } else {
      overflow.insert(0, item);
    }

    await _saveList(_serverKey, server);
    await _saveList(_overflowKey, overflow);
    return ProblemBookmarkSnapshot(
      serverItems: server,
      localOverflowItems: overflow,
    );
  }

  static Future<ProblemBookmarkSnapshot> remove(String id) async {
    final snapshot = await load();
    final server = List<ProblemBookmarkItem>.from(snapshot.serverItems)
      ..removeWhere((it) => it.id == id);
    final overflow = List<ProblemBookmarkItem>.from(snapshot.localOverflowItems)
      ..removeWhere((it) => it.id == id);
    await _saveList(_serverKey, server);
    await _saveList(_overflowKey, overflow);
    return ProblemBookmarkSnapshot(
      serverItems: server,
      localOverflowItems: overflow,
    );
  }

  static Future<List<ProblemBookmarkItem>> _loadList(String key) async {
    final raw = await LocalDb.instance.getString(key);
    if (raw == null || raw.isEmpty) return <ProblemBookmarkItem>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <ProblemBookmarkItem>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ProblemBookmarkItem.fromJson)
          .toList();
    } catch (_) {
      return <ProblemBookmarkItem>[];
    }
  }

  static Future<void> _saveList(String key, List<ProblemBookmarkItem> items) async {
    final payload = jsonEncode(items.map((e) => e.toJson()).toList());
    await LocalDb.instance.setString(key, payload);
  }
}
