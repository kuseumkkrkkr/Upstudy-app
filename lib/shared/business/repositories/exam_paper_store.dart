import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:s11/shared/services/api/api_client.dart';

import 'package:s11/shared/services/storage/local_db.dart';

class ExamPaperEntry {
  const ExamPaperEntry({
    required this.examId,
    required this.questionCount,
    required this.createdAt,
    required this.paperType,
    this.searchIndex = '',
  });

  final String examId;
  final int questionCount;
  final int createdAt;
  final String paperType;
  final String searchIndex;

  factory ExamPaperEntry.fromJson(Map<String, dynamic> json) {
    return ExamPaperEntry(
      examId: json['exam_id']?.toString() ?? '',
      questionCount: (json['question_count'] as num?)?.toInt() ?? 0,
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      paperType: json['paper_type']?.toString() ?? 'csat',
      searchIndex: json['search_index']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exam_id': examId,
      'question_count': questionCount,
      'created_at': createdAt,
      'paper_type': paperType,
      'search_index': searchIndex,
    };
  }

  ExamPaperEntry copyWith({
    String? examId,
    int? questionCount,
    int? createdAt,
    String? paperType,
    String? searchIndex,
  }) {
    return ExamPaperEntry(
      examId: examId ?? this.examId,
      questionCount: questionCount ?? this.questionCount,
      createdAt: createdAt ?? this.createdAt,
      paperType: paperType ?? this.paperType,
      searchIndex: searchIndex ?? this.searchIndex,
    );
  }
}

class ExamPaperStore {
  static const _key = 'exam_papers_v1';
  static const int maxItems = 30;
  static final ValueNotifier<List<ExamPaperEntry>> _notifier =
      ValueNotifier<List<ExamPaperEntry>>(<ExamPaperEntry>[]);
  static bool _loaded = false;
  static bool _listening = false;

  static ValueNotifier<List<ExamPaperEntry>> get notifier {
    if (!_listening) {
      _listening = true;
      ApiClient.instance.sessionChanges.addListener(() {
        _loaded = false;
        _notifier.value = <ExamPaperEntry>[];
      });
    }
    return _notifier;
  }

  static Future<List<ExamPaperEntry>> load() async {
    final signal = notifier;
    final scope = await ApiClient.instance.requireSessionScope();
    if (_loaded) return signal.value;
    final raw = await _loadRaw(scope);
    ApiClient.instance.assertSessionScope(scope);
    if (raw == null || raw.isEmpty) {
      _loaded = true;
      return notifier.value;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List)
      throw const FormatException('Invalid exam paper list');
    final items = decoded
        .whereType<Map>()
        .map((item) => ExamPaperEntry.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    notifier.value = items;
    _loaded = true;
    return notifier.value;
  }

  static Future<List<ExamPaperEntry>> add(ExamPaperEntry entry) async {
    final scope = await ApiClient.instance.requireSessionScope();
    final items = await load();
    ApiClient.instance.assertSessionScope(scope);
    final updated = <ExamPaperEntry>[
      entry,
      for (final item in items)
        if (item.examId != entry.examId) item,
    ].take(maxItems).toList(growable: false);
    await _persist(updated, scope);
    return updated;
  }

  static Future<List<ExamPaperEntry>> remove(String examId) async {
    final scope = await ApiClient.instance.requireSessionScope();
    final items = await load();
    ApiClient.instance.assertSessionScope(scope);
    final updated = items
        .where((item) => item.examId != examId)
        .toList(growable: false);
    await _persist(updated, scope);
    return updated;
  }

  static Future<List<ExamPaperEntry>> updateSearchIndex({
    required String examId,
    required String searchIndex,
  }) async {
    final scope = await ApiClient.instance.requireSessionScope();
    final id = examId.trim();
    if (id.isEmpty || searchIndex.trim().isEmpty) return load();
    final items = await load();
    ApiClient.instance.assertSessionScope(scope);
    var changed = false;
    final updated = items
        .map((item) {
          if (item.examId != id) return item;
          if (item.searchIndex == searchIndex) return item;
          changed = true;
          return item.copyWith(searchIndex: searchIndex);
        })
        .toList(growable: false);
    if (changed) {
      await _persist(updated, scope);
      return updated;
    }
    return items;
  }

  static Future<void> _persist(
    List<ExamPaperEntry> items,
    ApiSessionScope scope,
  ) async {
    ApiClient.instance.assertSessionScope(scope);
    final payload = jsonEncode(items.map((item) => item.toJson()).toList());
    await LocalDb.instance.setString(_key, payload, scope: scope);
    ApiClient.instance.assertSessionScope(scope);
    notifier.value = List<ExamPaperEntry>.from(items);
    _loaded = true;
  }

  static Future<String?> _loadRaw(ApiSessionScope scope) async {
    return LocalDb.instance.getString(_key, scope: scope);
  }
}
