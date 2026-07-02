import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:s11/shared/services/storage/local_db.dart';

class ExamPaperEntry {
  const ExamPaperEntry({
    required this.examId,
    required this.questionCount,
    required this.createdAt,
    required this.paperType,
  });

  final String examId;
  final int questionCount;
  final int createdAt;
  final String paperType;

  factory ExamPaperEntry.fromJson(Map<String, dynamic> json) {
    return ExamPaperEntry(
      examId: json['exam_id']?.toString() ?? '',
      questionCount: (json['question_count'] as num?)?.toInt() ?? 0,
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      paperType: json['paper_type']?.toString() ?? 'csat',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exam_id': examId,
      'question_count': questionCount,
      'created_at': createdAt,
      'paper_type': paperType,
    };
  }
}

class ExamPaperStore {
  static const _key = 'exam_papers_v1';
  static const int maxItems = 30;
  static final ValueNotifier<List<ExamPaperEntry>> notifier =
      ValueNotifier<List<ExamPaperEntry>>(<ExamPaperEntry>[]);
  static bool _loaded = false;

  static Future<List<ExamPaperEntry>> load() async {
    if (_loaded) return notifier.value;
    final raw = await _loadRaw();
    if (raw == null || raw.isEmpty) {
      _loaded = true;
      return notifier.value;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final items = decoded
            .whereType<Map>()
            .map((item) => ExamPaperEntry.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList();
        notifier.value = items;
      }
    } catch (_) {
      // Ignore corrupted payloads.
    }
    _loaded = true;
    return notifier.value;
  }

  static Future<List<ExamPaperEntry>> add(ExamPaperEntry entry) async {
    final items = await load();
    final updated = <ExamPaperEntry>[
      entry,
      for (final item in items)
        if (item.examId != entry.examId) item,
    ].take(maxItems).toList(growable: false);
    await _persist(updated);
    return updated;
  }

  static Future<List<ExamPaperEntry>> remove(String examId) async {
    final items = await load();
    final updated =
        items.where((item) => item.examId != examId).toList(growable: false);
    await _persist(updated);
    return updated;
  }

  static Future<void> _persist(List<ExamPaperEntry> items) async {
    notifier.value = List<ExamPaperEntry>.from(items);
    _loaded = true;
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
}
