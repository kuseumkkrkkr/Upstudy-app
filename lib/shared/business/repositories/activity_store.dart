import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/auth/auth_storage.dart';
import 'package:s11/shared/services/storage/local_db.dart';

const _activityStoreKey = 'activity_log_v1';
const int _activityMaxStoredDays = 60;
const int _activityScoreCap = 2000;

class ActivityEventType {
  static const String problem = 'problem';
  static const String book = 'book';
  static const String course = 'course';
  static const String exam = 'exam';
  static const String graph = 'graph';
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
    List<String>? examNumbers,
    List<String>? graphNumbers,
    int? score,
  }) : problemNumbers = problemNumbers ?? <String>[],
       bookNumbers = bookNumbers ?? <String>[],
       courseNumbers = courseNumbers ?? <String>[],
       examNumbers = examNumbers ?? <String>[],
       graphNumbers = graphNumbers ?? <String>[],
       score = score ?? 0;

  final String dateKey;
  final List<String> problemNumbers;
  final List<String> bookNumbers;
  final List<String> courseNumbers;
  final List<String> examNumbers;
  final List<String> graphNumbers;
  final int score;

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
      examNumbers: toStringList(json['exams']),
      graphNumbers: toStringList(json['graphs']),
      score: (json['score'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'problems': problemNumbers,
      'books': bookNumbers,
      'courses': courseNumbers,
      'exams': examNumbers,
      'graphs': graphNumbers,
      'score': score,
    };
  }

  ActivityDayRecord copyWith({
    List<String>? problemNumbers,
    List<String>? bookNumbers,
    List<String>? courseNumbers,
    List<String>? examNumbers,
    List<String>? graphNumbers,
    int? score,
  }) {
    return ActivityDayRecord(
      dateKey: dateKey,
      problemNumbers: problemNumbers ?? this.problemNumbers,
      bookNumbers: bookNumbers ?? this.bookNumbers,
      courseNumbers: courseNumbers ?? this.courseNumbers,
      examNumbers: examNumbers ?? this.examNumbers,
      graphNumbers: graphNumbers ?? this.graphNumbers,
      score: score ?? this.score,
    );
  }
}

class ActivitySnapshot {
  const ActivitySnapshot({
    required this.days,
    required this.totalSolvedCount,
    required this.totalIncorrectCount,
    required this.lastDateKey,
    this.lastEvent,
    this.lastProblemConfig,
  });

  final Map<String, ActivityDayRecord> days;
  final int totalSolvedCount;
  final int totalIncorrectCount;
  final String lastDateKey;
  final ActivityEvent? lastEvent;
  final Map<String, dynamic>? lastProblemConfig;

  factory ActivitySnapshot.empty() {
    return const ActivitySnapshot(
      days: <String, ActivityDayRecord>{},
      totalSolvedCount: 0,
      totalIncorrectCount: 0,
      lastDateKey: '',
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
      lastDateKey: json['last_date']?.toString() ?? '',
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
      'last_date': lastDateKey,
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

  ActivitySnapshot copyWith({
    Map<String, ActivityDayRecord>? days,
    int? totalSolvedCount,
    int? totalIncorrectCount,
    String? lastDateKey,
    ActivityEvent? lastEvent,
    Map<String, dynamic>? lastProblemConfig,
  }) {
    return ActivitySnapshot(
      days: days ?? this.days,
      totalSolvedCount: totalSolvedCount ?? this.totalSolvedCount,
      totalIncorrectCount: totalIncorrectCount ?? this.totalIncorrectCount,
      lastDateKey: lastDateKey ?? this.lastDateKey,
      lastEvent: lastEvent ?? this.lastEvent,
      lastProblemConfig: lastProblemConfig ?? this.lastProblemConfig,
    );
  }
}

class ActivityStore {
  static final ValueNotifier<ActivitySnapshot> notifier =
      ValueNotifier<ActivitySnapshot>(ActivitySnapshot.empty());
  static final ValueNotifier<AccountSummary?> accountSummaryNotifier =
      ValueNotifier<AccountSummary?>(null);
  static bool _loaded = false;
  static String _storageKey = _activityStoreKey;
  static String? _activeUsername;

  /// Make sure the storage key follows the currently signed-in user.
  /// When the user changes we reset the in-memory snapshot so each account
  /// sees only its own activity data.
  static Future<void> _syncUserScope() async {
    final scopedFromAuth = (await AuthStorage.instance.readUsername())?.trim();
    final prefs = await SharedPreferences.getInstance();
    final scopedFromLegacy = prefs.getString('username')?.trim();
    final username = (scopedFromAuth != null && scopedFromAuth.isNotEmpty)
        ? scopedFromAuth
        : scopedFromLegacy;
    final scopedKey = (username == null || username.isEmpty)
        ? _activityStoreKey
        : '$_activityStoreKey::$username';
    if (_activeUsername == username && _storageKey == scopedKey) return;
    _activeUsername = username;
    _storageKey = scopedKey;
    _loaded = false;
    notifier.value = ActivitySnapshot.empty();
  }

  static Future<ActivitySnapshot> load() async {
    await _syncUserScope();
    if (_loaded) return notifier.value;
    final raw = await _loadRaw();
    if (raw == null || raw.isEmpty) {
      final normalized = _normalizeSnapshot(
        ActivitySnapshot.empty(),
        DateTime.now(),
      );
      await _persist(normalized);
      _loaded = true;
      return notifier.value;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final snapshot = ActivitySnapshot.fromJson(decoded);
        final normalized = _normalizeSnapshot(snapshot, DateTime.now());
        if (normalized != snapshot) {
          await _persist(normalized);
        } else {
          notifier.value = snapshot;
        }
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
    final snapshot = await _ensureUpToDate();
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
        lastDateKey: snapshot.lastDateKey,
        lastEvent: event,
        lastProblemConfig: Map<String, dynamic>.from(config),
      ),
    );
  }

  static Future<void> recordProblemSolve({
    required String problemId,
    required String problemNumber,
    int? difficultyTier,
    Map<String, dynamic>? meta,
  }) async {
    final snapshot = await _ensureUpToDate();
    final todayKey = _todayKey();
    final existing =
        snapshot.days[todayKey] ?? ActivityDayRecord(dateKey: todayKey);
    final isValid = problemNumber.trim().isNotEmpty;
    final isDuplicate =
        !isValid || existing.problemNumbers.contains(problemNumber);
    final updatedProblems = _addUnique(existing.problemNumbers, problemNumber);
    var updatedDay = existing.copyWith(problemNumbers: updatedProblems);
    var nextSolvedTotal = snapshot.totalSolvedCount;
    var deltaScore = 0;
    if (!isDuplicate) {
      nextSolvedTotal += 1;
      final updatedCount = updatedProblems.length;
      final basePoints = _problemBasePointsForIndex(updatedCount);
      final weight = _problemDifficultyWeight(difficultyTier ?? 3);
      deltaScore = (basePoints * weight).round();
      updatedDay = updatedDay.copyWith(score: updatedDay.score + deltaScore);
    }
    final updatedDays = Map<String, ActivityDayRecord>.from(snapshot.days)
      ..[todayKey] = updatedDay;
    final priorConfigRaw =
        snapshot.lastProblemConfig ?? snapshot.lastEvent?.meta?['config'];
    final priorConfig = priorConfigRaw is Map
        ? Map<String, dynamic>.from(priorConfigRaw)
        : null;
    final mergedMeta = <String, dynamic>{};
    if (priorConfig != null) mergedMeta['config'] = priorConfig;
    if (meta != null) mergedMeta.addAll(meta);

    final event = ActivityEvent(
      type: ActivityEventType.problem,
      id: problemId,
      number: problemNumber,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      meta: mergedMeta.isEmpty ? null : mergedMeta,
    );
    await _persist(
      ActivitySnapshot(
        days: updatedDays,
        totalSolvedCount: nextSolvedTotal,
        totalIncorrectCount: snapshot.totalIncorrectCount,
        lastDateKey: snapshot.lastDateKey,
        lastEvent: event,
        lastProblemConfig: priorConfig,
      ),
    );
    if (!isDuplicate) {
      unawaited(
        _syncActivityScoreDelta(
          deltaScore: deltaScore,
          refId: _activityScoreRef(
            ActivityEventType.problem,
            todayKey,
            problemId,
            problemNumber,
          ),
          reason: 'problem_solve',
          dateKey: todayKey,
        ),
      );
    }
  }

  static Future<void> recordProblemIncorrect({
    required String problemId,
    required String problemNumber,
    Map<String, dynamic>? meta,
  }) async {
    final snapshot = await _ensureUpToDate();
    final priorConfigRaw =
        snapshot.lastProblemConfig ?? snapshot.lastEvent?.meta?['config'];
    final priorConfig = priorConfigRaw is Map
        ? Map<String, dynamic>.from(priorConfigRaw)
        : null;
    final mergedMeta = <String, dynamic>{};
    if (priorConfig != null) mergedMeta['config'] = priorConfig;
    if (meta != null) mergedMeta.addAll(meta);

    final event = ActivityEvent(
      type: ActivityEventType.problem,
      id: problemId,
      number: problemNumber,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      meta: mergedMeta.isEmpty ? null : mergedMeta,
    );
    await _persist(
      ActivitySnapshot(
        days: snapshot.days,
        totalSolvedCount: snapshot.totalSolvedCount,
        totalIncorrectCount: snapshot.totalIncorrectCount + 1,
        lastDateKey: snapshot.lastDateKey,
        lastEvent: event,
        lastProblemConfig: priorConfig,
      ),
    );
  }

  static Future<void> recordBookView({
    required String bookId,
    required String bookNumber,
  }) async {
    final snapshot = await _ensureUpToDate();
    final todayKey = _todayKey();
    final existing =
        snapshot.days[todayKey] ?? ActivityDayRecord(dateKey: todayKey);
    final isValid = bookNumber.trim().isNotEmpty;
    final isDuplicate = !isValid || existing.bookNumbers.contains(bookNumber);
    final updatedBooks = _addUnique(existing.bookNumbers, bookNumber);
    var updatedDay = existing.copyWith(bookNumbers: updatedBooks);
    var deltaScore = 0;
    if (!isDuplicate) {
      final priorCount = existing.bookNumbers.length;
      if (priorCount < 2) {
        deltaScore = 100;
        updatedDay = updatedDay.copyWith(score: updatedDay.score + deltaScore);
      }
    }
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
        lastDateKey: snapshot.lastDateKey,
        lastEvent: event,
        lastProblemConfig: snapshot.lastProblemConfig,
      ),
    );
    if (deltaScore > 0) {
      unawaited(
        _syncActivityScoreDelta(
          deltaScore: deltaScore,
          refId: _activityScoreRef(
            ActivityEventType.book,
            todayKey,
            bookId,
            bookNumber,
          ),
          reason: 'book_view',
          dateKey: todayKey,
        ),
      );
    }
  }

  static Future<void> recordCourseView({
    required String courseId,
    required String courseNumber,
    String? screen,
  }) async {
    final snapshot = await _ensureUpToDate();
    final todayKey = _todayKey();
    final existing =
        snapshot.days[todayKey] ?? ActivityDayRecord(dateKey: todayKey);
    final updatedCourses = _addUnique(existing.courseNumbers, courseNumber);
    final updatedDay = existing.copyWith(courseNumbers: updatedCourses);
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
        lastDateKey: snapshot.lastDateKey,
        lastEvent: event,
        lastProblemConfig: snapshot.lastProblemConfig,
      ),
    );
  }

  static Future<void> recordExamCompletion({
    required String examId,
    required String examNumber,
    required int questionCount,
    int? difficultyTier,
  }) async {
    final snapshot = await _ensureUpToDate();
    final todayKey = _todayKey();
    final existing =
        snapshot.days[todayKey] ?? ActivityDayRecord(dateKey: todayKey);
    final resolvedNumber = examNumber.trim().isNotEmpty
        ? examNumber
        : examId.trim();
    final isValid = resolvedNumber.trim().isNotEmpty;
    final isDuplicate =
        !isValid || existing.examNumbers.contains(resolvedNumber);
    final updatedExams = _addUnique(existing.examNumbers, resolvedNumber);
    var updatedDay = existing.copyWith(examNumbers: updatedExams);
    var deltaScore = 0;
    if (!isDuplicate) {
      final basePoints = _examBasePoints(questionCount);
      final weight = _examDifficultyWeight(difficultyTier ?? 3);
      deltaScore = (basePoints * weight).round();
      updatedDay = updatedDay.copyWith(score: updatedDay.score + deltaScore);
    }
    final updatedDays = Map<String, ActivityDayRecord>.from(snapshot.days)
      ..[todayKey] = updatedDay;
    await _persist(
      ActivitySnapshot(
        days: updatedDays,
        totalSolvedCount: snapshot.totalSolvedCount,
        totalIncorrectCount: snapshot.totalIncorrectCount,
        lastDateKey: snapshot.lastDateKey,
        lastEvent: snapshot.lastEvent,
        lastProblemConfig: snapshot.lastProblemConfig,
      ),
    );
    if (deltaScore > 0) {
      unawaited(
        _syncActivityScoreDelta(
          deltaScore: deltaScore,
          refId: _activityScoreRef(
            ActivityEventType.exam,
            todayKey,
            examId,
            resolvedNumber,
          ),
          reason: 'exam_completion',
          dateKey: todayKey,
        ),
      );
    }
  }

  static Future<void> recordExamSession({
    required String examId,
    required int questionCount,
  }) async {
    final snapshot = await _ensureUpToDate();
    final event = ActivityEvent(
      type: ActivityEventType.exam,
      id: examId,
      number: examId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      meta: {'questionCount': questionCount},
    );
    await _persist(
      ActivitySnapshot(
        days: snapshot.days,
        totalSolvedCount: snapshot.totalSolvedCount,
        totalIncorrectCount: snapshot.totalIncorrectCount,
        lastDateKey: snapshot.lastDateKey,
        lastEvent: event,
        lastProblemConfig: snapshot.lastProblemConfig,
      ),
    );
  }

  static Future<void> recordGraphPractice({
    required String graphId,
    String? graphNumber,
    Map<String, dynamic>? meta,
  }) async {
    final snapshot = await _ensureUpToDate();
    final todayKey = _todayKey();
    final existing =
        snapshot.days[todayKey] ?? ActivityDayRecord(dateKey: todayKey);
    final resolvedNumber = graphNumber?.trim().isNotEmpty == true
        ? graphNumber!.trim()
        : DateTime.now().millisecondsSinceEpoch.toString();
    final updatedGraphs = _addUnique(existing.graphNumbers, resolvedNumber);
    final updatedDay = existing.copyWith(graphNumbers: updatedGraphs);
    final updatedDays = Map<String, ActivityDayRecord>.from(snapshot.days)
      ..[todayKey] = updatedDay;
    final event = ActivityEvent(
      type: ActivityEventType.graph,
      id: graphId,
      number: resolvedNumber,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      meta: meta,
    );
    await _persist(
      ActivitySnapshot(
        days: updatedDays,
        totalSolvedCount: snapshot.totalSolvedCount,
        totalIncorrectCount: snapshot.totalIncorrectCount,
        lastDateKey: snapshot.lastDateKey,
        lastEvent: event,
        lastProblemConfig: snapshot.lastProblemConfig,
      ),
    );
  }

  static Future<void> _persist(ActivitySnapshot snapshot) async {
    await _syncUserScope();
    notifier.value = snapshot;
    _loaded = true;
    await LocalDb.instance.setString(
      _storageKey,
      jsonEncode(snapshot.toJson()),
    );
  }

  static Future<String?> _loadRaw() async {
    // load uses the user-scoped key prepared in _syncUserScope
    final db = LocalDb.instance;
    final cached = await db.getString(_storageKey);
    if (cached != null && cached.isNotEmpty) return cached;
    if (kIsWeb) return cached;
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_storageKey);
    if (legacy != null && legacy.isNotEmpty) {
      await db.setString(_storageKey, legacy);
      return legacy;
    }
    return cached;
  }

  static Future<void> _syncActivityScoreDelta({
    required int deltaScore,
    required String refId,
    required String reason,
    required String dateKey,
  }) async {
    if (deltaScore <= 0) return;
    try {
      final summary = await ApiClient.instance.recordActivityScore(
        deltaScore: deltaScore,
        refId: refId,
        reason: reason,
        dateKey: dateKey,
      );
      accountSummaryNotifier.value = summary;
    } catch (error) {
      debugPrint('Activity score sync failed: $error');
    }
  }

  static String _activityScoreRef(
    String type,
    String dateKey,
    String id,
    String number,
  ) {
    final raw = '$type:$dateKey:${id.trim()}:${number.trim()}';
    if (raw.length <= 200) return raw;
    return raw.substring(0, 200);
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

  static ActivitySnapshot _normalizeSnapshot(
    ActivitySnapshot snapshot,
    DateTime now,
  ) {
    final todayKey = _formatDateKey(now);
    var lastDateKey = snapshot.lastDateKey;
    var changed = false;
    if (lastDateKey.isEmpty && snapshot.days.isNotEmpty) {
      lastDateKey = _latestDateKey(snapshot.days.keys);
      changed = true;
    }
    final updatedDays = Map<String, ActivityDayRecord>.from(snapshot.days);
    if (lastDateKey.isEmpty) {
      updatedDays.putIfAbsent(
        todayKey,
        () => ActivityDayRecord(dateKey: todayKey),
      );
      lastDateKey = todayKey;
      changed = true;
    } else {
      final lastDate = _parseDateKey(lastDateKey) ?? now;
      if (!updatedDays.containsKey(lastDateKey)) {
        updatedDays[lastDateKey] = ActivityDayRecord(dateKey: lastDateKey);
        changed = true;
      }
      final today = DateTime(now.year, now.month, now.day);
      var cursor = DateTime(lastDate.year, lastDate.month, lastDate.day);
      while (cursor.isBefore(today)) {
        cursor = cursor.add(const Duration(days: 1));
        final key = _formatDateKey(cursor);
        if (!updatedDays.containsKey(key)) {
          updatedDays[key] = ActivityDayRecord(dateKey: key);
          changed = true;
        }
      }
      lastDateKey = todayKey;
      if (snapshot.lastDateKey != lastDateKey) {
        changed = true;
      }
    }
    final trimmedDays = _trimDays(updatedDays, _activityMaxStoredDays);
    if (trimmedDays.length != updatedDays.length) {
      changed = true;
    }
    if (!changed) return snapshot;
    return snapshot.copyWith(days: trimmedDays, lastDateKey: lastDateKey);
  }

  static Future<ActivitySnapshot> _ensureUpToDate() async {
    await _syncUserScope();
    final snapshot = _loaded ? notifier.value : await load();
    final normalized = _normalizeSnapshot(snapshot, DateTime.now());
    if (normalized != snapshot) {
      await _persist(normalized);
      return notifier.value;
    }
    return snapshot;
  }

  static DateTime? _parseDateKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  static String _latestDateKey(Iterable<String> keys) {
    final list = keys.toList()..sort();
    return list.isEmpty ? '' : list.last;
  }

  static Map<String, ActivityDayRecord> _trimDays(
    Map<String, ActivityDayRecord> days,
    int maxCount,
  ) {
    if (days.length <= maxCount) return days;
    final keys = days.keys.toList()..sort();
    final removeCount = days.length - maxCount;
    final toRemove = keys.take(removeCount).toSet();
    final trimmed = <String, ActivityDayRecord>{};
    for (final entry in days.entries) {
      if (!toRemove.contains(entry.key)) {
        trimmed[entry.key] = entry.value;
      }
    }
    return trimmed;
  }

  static int scoreCap() => _activityScoreCap;

  static double activityPercentFromScore(int score) {
    if (_activityScoreCap <= 0) return 0.0;
    final capped = score.clamp(0, _activityScoreCap).toDouble();
    return capped / _activityScoreCap;
  }

  static int activityLevelForScore(int score) {
    if (score <= 0) return 0;
    if (score <= 100) return 1;
    if (score <= 250) return 2;
    if (score <= 600) return 3;
    if (score <= 1000) return 4;
    return 5;
  }

  static int scoreForDate(ActivitySnapshot snapshot, DateTime date) {
    final key = _formatDateKey(date);
    return snapshot.days[key]?.score ?? 0;
  }

  static List<ActivityDayRecord> recentDays(
    ActivitySnapshot snapshot,
    int count,
  ) {
    if (count <= 0) return const <ActivityDayRecord>[];
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: count - 1));
    final results = <ActivityDayRecord>[];
    for (var i = 0; i < count; i++) {
      final date = start.add(Duration(days: i));
      final key = _formatDateKey(date);
      results.add(snapshot.days[key] ?? ActivityDayRecord(dateKey: key));
    }
    return results;
  }

  static int _problemBasePointsForIndex(int index) {
    if (index <= 5) return 2;
    if (index <= 20) return 3;
    if (index <= 50) return 4;
    if (index <= 100) return 5;
    return 7;
  }

  static double _problemDifficultyWeight(int tier) {
    switch (tier.clamp(1, 5)) {
      case 1:
        return 0.5;
      case 2:
        return 1.0;
      case 3:
        return 1.5;
      case 4:
        return 3.0;
      case 5:
      default:
        return 5.0;
    }
  }

  static int _examBasePoints(int questionCount) {
    if (questionCount >= 50) return 700;
    if (questionCount >= 30) return 500;
    return 200;
  }

  static double _examDifficultyWeight(int tier) {
    switch (tier.clamp(1, 5)) {
      case 1:
        return 0.4;
      case 2:
        return 0.7;
      case 3:
        return 1.0;
      case 4:
        return 1.5;
      case 5:
      default:
        return 2.0;
    }
  }
}
