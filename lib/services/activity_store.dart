import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_db.dart';

const _activityStoreKey = 'activity_log_v1';

class ActivityEventType {
  static const String problem = 'problem';
  static const String book = 'book';
  static const String course = 'course';
}

class ActivityEvent {
  const ActivityEvent({
    required this.type,
    required this.id,
    required this.timestamp,
    this.number,
    this.meta,
  });

  final String type;
  final String id;
  final int timestamp;
  final String? number;
  final Map<String, dynamic>? meta;

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    final metaRaw = json['meta'];
    return ActivityEvent(
      type: json['type']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      number: json['number']?.toString(),
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      meta: metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'id': id,
      'number': number,
      'timestamp': timestamp,
      if (meta != null) 'meta': meta,
    };
  }
}

class ActivityDayRecord {
  ActivityDayRecord({
    required this.dateKey,
    List<String>? problemNumbers,
    List<String>? bookNumbers,
    List<String>? courseNumbers,
  })  : problemNumbers = problemNumbers ?? <String>[],
        bookNumbers = bookNumbers ?? <String>[],
        courseNumbers = courseNumbers ?? <String>[];

  final String dateKey;
  final List<String> problemNumbers;
  final List<String> bookNumbers;
  final List<String> courseNumbers;

  factory ActivityDayRecord.fromJson(
    String dateKey,
    Map<String, dynamic> json,
  ) {
    List<String> toStringList(dynamic raw) {
      if (raw is! List) return <String>[];
      return raw.map((e) => e.toString()).toList();
    }

    return ActivityDayRecord(
      dateKey: dateKey,
      problemNumbers: toStringList(json['problems']),
      bookNumbers: toStringList(json['books']),
      courseNumbers: toStringList(json['courses']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'problems': problemNumbers,
      'books': bookNumbers,
      'courses': courseNumbers,
    };
  }
}

class ActivitySnapshot {
  const ActivitySnapshot({
    required this.days,
    required this.totalSolvedCount,
    required this.totalIncorrectCount,
    this.lastEvent,
    this.lastProblemConfig,
  });

  final Map<String, ActivityDayRecord> days;
  final int totalSolvedCount;
  final int totalIncorrectCount;
  final ActivityEvent? lastEvent;
  final Map<String, dynamic>? lastProblemConfig;

  factory ActivitySnapshot.empty() {
    return const ActivitySnapshot(
      days: <String, ActivityDayRecord>{},
      totalSolvedCount: 0,
      totalIncorrectCount: 0,
    );
  }

  factory ActivitySnapshot.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'];
    final map = <String, ActivityDayRecord>{};
    if (rawDays is Map) {
      for (final entry in rawDays.entries) {
        if (entry.value is Map) {
          map[entry.key.toString()] = ActivityDayRecord.fromJson(
            entry.key.toString(),
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }
    final lastEventRaw = json['last_event'];
    final problemConfigRaw = json['problem_config'];
    return ActivitySnapshot(
      days: map,
      totalSolvedCount: (json['total_solved'] as num?)?.toInt() ?? 0,
      totalIncorrectCount: (json['total_incorrect'] as num?)?.toInt() ?? 0,
      lastEvent: lastEventRaw is Map
          ? ActivityEvent.fromJson(Map<String, dynamic>.from(lastEventRaw))
          : null,
      lastProblemConfig: problemConfigRaw is Map
          ? Map<String, dynamic>.from(problemConfigRaw)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'days': {
        for (final entry in days.entries) entry.key: entry.value.toJson(),
      },
      'total_solved': totalSolvedCount,
      'total_incorrect': totalIncorrectCount,
      if (lastEvent != null) 'last_event': lastEvent!.toJson(),
      if (lastProblemConfig != null) 'problem_config': lastProblemConfig,
    };
  }

  List<ActivityDayRecord> sortedDays({int? limit}) {
    final entries = days.values.toList()
      ..sort((a, b) => b.dateKey.compareTo(a.dateKey));
    if (limit == null || entries.length <= limit) return entries;
    return entries.take(limit).toList();
  }
}

class ActivityStore {
  static final ValueNotifier<ActivitySnapshot> notifier =
      ValueNotifier<ActivitySnapshot>(ActivitySnapshot.empty());
  static bool _loaded = false;

  static Future<ActivitySnapshot> load() async {
    if (_loaded) return notifier.value;
    final raw = await _loadRaw();
    if (raw == null || raw.isEmpty) {
      _loaded = true;
      return notifier.value;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final snapshot = ActivitySnapshot.fromJson(decoded);
        notifier.value = snapshot;
      }
    } catch (_) {
      // Ignore corrupted payloads.
    }
    _loaded = true;
    return notifier.value;
  }

  static Future<void> recordProblemSession({
    required Map<String, dynamic> config,
  }) async {
    final snapshot = await load();
    final event = ActivityEvent(
      type: ActivityEventType.problem,
      id: 'session',
      number: null,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      meta: {'config': config},
    );
    await _persist(
      ActivitySnapshot(
        days: snapshot.days,
        totalSolvedCount: snapshot.totalSolvedCount,
        totalIncorrectCount: snapshot.totalIncorrectCount,
        lastEvent: event,
        lastProblemConfig: Map<String, dynamic>.from(config),
      ),
    );
  }

  static Future<void> recordProblemSolve({
    required String problemId,
    required String problemNumber,
  }) async {
    final snapshot = await load();
    final todayKey = _todayKey();
    final existing = snapshot.days[todayKey] ??
        ActivityDayRecord(dateKey: todayKey);
    final updatedProblems = _addUnique(existing.problemNumbers, problemNumber);
    final updatedDay = ActivityDayRecord(
      dateKey: todayKey,
      problemNumbers: updatedProblems,
      bookNumbers: List<String>.from(existing.bookNumbers),
      courseNumbers: List<String>.from(existing.courseNumbers),
    );
    final updatedDays = Map<String, ActivityDayRecord>.from(snapshot.days)
      ..[todayKey] = updatedDay;
    final priorConfigRaw =
        snapshot.lastProblemConfig ?? snapshot.lastEvent?.meta?['config'];
    final priorConfig =
        priorConfigRaw is Map ? Map<String, dynamic>.from(priorConfigRaw) : null;
    final event = ActivityEvent(
      type: ActivityEventType.problem,
      id: problemId,
      number: problemNumber,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      meta: priorConfig == null ? null : {'config': priorConfig},
    );
    await _persist(
      ActivitySnapshot(
        days: updatedDays,
        totalSolvedCount: snapshot.totalSolvedCount + 1,
        totalIncorrectCount: snapshot.totalIncorrectCount,
        lastEvent: event,
        lastProblemConfig: priorConfig,
      ),
    );
  }

  static Future<void> recordProblemIncorrect({
    required String problemId,
    required String problemNumber,
  }) async {
    final snapshot = await load();
    final priorConfigRaw =
        snapshot.lastProblemConfig ?? snapshot.lastEvent?.meta?['config'];
    final priorConfig =
        priorConfigRaw is Map ? Map<String, dynamic>.from(priorConfigRaw) : null;
    final event = ActivityEvent(
      type: ActivityEventType.problem,
      id: problemId,
      number: problemNumber,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      meta: priorConfig == null ? null : {'config': priorConfig},
    );
    await _persist(
      ActivitySnapshot(
        days: snapshot.days,
        totalSolvedCount: snapshot.totalSolvedCount,
        totalIncorrectCount: snapshot.totalIncorrectCount + 1,
        lastEvent: event,
        lastProblemConfig: priorConfig,
      ),
    );
  }

  static Future<void> recordBookView({
    required String bookId,
    required String bookNumber,
  }) async {
    final snapshot = await load();
    final todayKey = _todayKey();
    final existing = snapshot.days[todayKey] ??
        ActivityDayRecord(dateKey: todayKey);
    final updatedBooks = _addUnique(existing.bookNumbers, bookNumber);
    final updatedDay = ActivityDayRecord(
      dateKey: todayKey,
      problemNumbers: List<String>.from(existing.problemNumbers),
      bookNumbers: updatedBooks,
      courseNumbers: List<String>.from(existing.courseNumbers),
    );
    final updatedDays = Map<String, ActivityDayRecord>.from(snapshot.days)
      ..[todayKey] = updatedDay;
    final event = ActivityEvent(
      type: ActivityEventType.book,
      id: bookId,
      number: bookNumber,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await _persist(
      ActivitySnapshot(
        days: updatedDays,
        totalSolvedCount: snapshot.totalSolvedCount,
        totalIncorrectCount: snapshot.totalIncorrectCount,
        lastEvent: event,
        lastProblemConfig: snapshot.lastProblemConfig,
      ),
    );
  }

  static Future<void> recordCourseView({
    required String courseId,
    required String courseNumber,
    String? screen,
  }) async {
    final snapshot = await load();
    final todayKey = _todayKey();
    final existing = snapshot.days[todayKey] ??
        ActivityDayRecord(dateKey: todayKey);
    final updatedCourses = _addUnique(existing.courseNumbers, courseNumber);
    final updatedDay = ActivityDayRecord(
      dateKey: todayKey,
      problemNumbers: List<String>.from(existing.problemNumbers),
      bookNumbers: List<String>.from(existing.bookNumbers),
      courseNumbers: updatedCourses,
    );
    final updatedDays = Map<String, ActivityDayRecord>.from(snapshot.days)
      ..[todayKey] = updatedDay;
    final event = ActivityEvent(
      type: ActivityEventType.course,
      id: courseId,
      number: courseNumber,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      meta: screen == null ? null : {'screen': screen},
    );
    await _persist(
      ActivitySnapshot(
        days: updatedDays,
        totalSolvedCount: snapshot.totalSolvedCount,
        totalIncorrectCount: snapshot.totalIncorrectCount,
        lastEvent: event,
        lastProblemConfig: snapshot.lastProblemConfig,
      ),
    );
  }

  static Future<void> _persist(ActivitySnapshot snapshot) async {
    notifier.value = snapshot;
    _loaded = true;
    await LocalDb.instance
        .setString(_activityStoreKey, jsonEncode(snapshot.toJson()));
  }

  static Future<String?> _loadRaw() async {
    final db = LocalDb.instance;
    final cached = await db.getString(_activityStoreKey);
    if (cached != null && cached.isNotEmpty) return cached;
    if (kIsWeb) return cached;
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_activityStoreKey);
    if (legacy != null && legacy.isNotEmpty) {
      await db.setString(_activityStoreKey, legacy);
      return legacy;
    }
    return cached;
  }

  static List<String> _addUnique(List<String> source, String value) {
    if (value.trim().isEmpty) return List<String>.from(source);
    if (source.contains(value)) return List<String>.from(source);
    return <String>[value, ...source];
  }

  static String _todayKey() {
    final now = DateTime.now();
    return _formatDateKey(now);
  }

  static String _formatDateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
