import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/auth/auth_storage.dart';
import 'package:s11/shared/services/storage/local_db.dart';

enum ReviewCourseType { daily, weekly, monthly, manual }

enum ReviewCourseStatus { available, completed }

enum ReviewTaskKind {
  redoProblems,
  conceptProblems,
  conceptReading,
  tagSummary,
  memoryCheck,
  advancedProblems,
  stats,
  timedMock,
}

extension ReviewCourseTypeLabel on ReviewCourseType {
  String get storageName {
    switch (this) {
      case ReviewCourseType.daily:
        return 'daily';
      case ReviewCourseType.weekly:
        return 'weekly';
      case ReviewCourseType.monthly:
        return 'monthly';
      case ReviewCourseType.manual:
        return 'manual';
    }
  }

  String get label {
    switch (this) {
      case ReviewCourseType.daily:
        return '1일 복습';
      case ReviewCourseType.weekly:
        return '주간 복습';
      case ReviewCourseType.monthly:
        return '월간 복습';
      case ReviewCourseType.manual:
        return '중간복습';
    }
  }
}

extension ReviewTaskKindLabel on ReviewTaskKind {
  String get storageName {
    switch (this) {
      case ReviewTaskKind.redoProblems:
        return 'redoProblems';
      case ReviewTaskKind.conceptProblems:
        return 'conceptProblems';
      case ReviewTaskKind.conceptReading:
        return 'conceptReading';
      case ReviewTaskKind.tagSummary:
        return 'tagSummary';
      case ReviewTaskKind.memoryCheck:
        return 'memoryCheck';
      case ReviewTaskKind.advancedProblems:
        return 'advancedProblems';
      case ReviewTaskKind.stats:
        return 'stats';
      case ReviewTaskKind.timedMock:
        return 'timedMock';
    }
  }
}

class ReviewProblemRef {
  const ReviewProblemRef({
    this.questId,
    this.codebaseId,
    this.seed,
    this.title,
    this.tags = const <String>[],
  });

  final String? questId;
  final int? codebaseId;
  final int? seed;
  final String? title;
  final List<String> tags;

  factory ReviewProblemRef.fromJson(Map<String, dynamic> json) {
    return ReviewProblemRef(
      questId: _nonEmpty(json['quest_id']),
      codebaseId: (json['codebase_id'] as num?)?.toInt(),
      seed: (json['seed'] as num?)?.toInt(),
      title: _nonEmpty(json['title']),
      tags: _stringList(json['tags']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (questId != null) 'quest_id': questId,
      if (codebaseId != null) 'codebase_id': codebaseId,
      if (seed != null) 'seed': seed,
      if (title != null) 'title': title,
      'tags': tags,
    };
  }
}

class ReviewTask {
  const ReviewTask({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.required,
    this.completed = false,
    this.completedAt,
    this.tags = const <String>[],
    this.problemRefs = const <ReviewProblemRef>[],
    this.targetQuestionCount = 0,
    this.correctCount = 0,
    this.totalCount = 0,
  });

  final String id;
  final ReviewTaskKind kind;
  final String title;
  final String description;
  final bool required;
  final bool completed;
  final int? completedAt;
  final List<String> tags;
  final List<ReviewProblemRef> problemRefs;
  final int targetQuestionCount;
  final int correctCount;
  final int totalCount;

  bool get isProblemTask {
    switch (kind) {
      case ReviewTaskKind.redoProblems:
      case ReviewTaskKind.conceptProblems:
      case ReviewTaskKind.memoryCheck:
      case ReviewTaskKind.advancedProblems:
      case ReviewTaskKind.timedMock:
        return true;
      case ReviewTaskKind.conceptReading:
      case ReviewTaskKind.tagSummary:
      case ReviewTaskKind.stats:
        return false;
    }
  }

  factory ReviewTask.fromJson(Map<String, dynamic> json) {
    return ReviewTask(
      id: json['id']?.toString() ?? '',
      kind: _parseTaskKind(json['kind']?.toString()),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      required: json['required'] == true,
      completed: json['completed'] == true,
      completedAt: (json['completed_at'] as num?)?.toInt(),
      tags: _stringList(json['tags']),
      problemRefs: (json['problem_refs'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (entry) =>
                ReviewProblemRef.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList(),
      targetQuestionCount:
          (json['target_question_count'] as num?)?.toInt() ?? 0,
      correctCount: (json['correct_count'] as num?)?.toInt() ?? 0,
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.storageName,
      'title': title,
      'description': description,
      'required': required,
      'completed': completed,
      if (completedAt != null) 'completed_at': completedAt,
      'tags': tags,
      'problem_refs': problemRefs.map((entry) => entry.toJson()).toList(),
      'target_question_count': targetQuestionCount,
      'correct_count': correctCount,
      'total_count': totalCount,
    };
  }

  ReviewTask copyWith({
    bool? completed,
    int? completedAt,
    int? correctCount,
    int? totalCount,
  }) {
    return ReviewTask(
      id: id,
      kind: kind,
      title: title,
      description: description,
      required: required,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      tags: tags,
      problemRefs: problemRefs,
      targetQuestionCount: targetQuestionCount,
      correctCount: correctCount ?? this.correctCount,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

class ReviewCourse {
  const ReviewCourse({
    required this.id,
    required this.type,
    required this.title,
    required this.dateKey,
    required this.dueDateKey,
    required this.createdAt,
    required this.status,
    required this.tasks,
    this.completedAt,
    this.summaryTags = const <String, int>{},
    this.estimatedMinutes = 15,
  });

  final String id;
  final ReviewCourseType type;
  final String title;
  final String dateKey;
  final String dueDateKey;
  final int createdAt;
  final ReviewCourseStatus status;
  final List<ReviewTask> tasks;
  final int? completedAt;
  final Map<String, int> summaryTags;
  final int estimatedMinutes;

  int get completedRequiredCount =>
      tasks.where((task) => task.required && task.completed).length;

  int get requiredCount => tasks.where((task) => task.required).length;

  int get correctCount => tasks.fold(0, (sum, task) => sum + task.correctCount);

  int get totalCount => tasks.fold(0, (sum, task) => sum + task.totalCount);

  int get accuracyPercent {
    if (totalCount <= 0) return 0;
    return (correctCount / totalCount * 100).round();
  }

  bool get allRequiredTasksDone =>
      tasks.where((task) => task.required).every((task) => task.completed);

  bool get canComplete => allRequiredTasksDone && accuracyPercent >= 80;

  factory ReviewCourse.fromJson(Map<String, dynamic> json) {
    return ReviewCourse(
      id: json['id']?.toString() ?? '',
      type: _parseCourseType(json['type']?.toString()),
      title: json['title']?.toString() ?? '',
      dateKey: json['date_key']?.toString() ?? '',
      dueDateKey: json['due_date_key']?.toString() ?? '',
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      status: _parseCourseStatus(json['status']?.toString()),
      tasks: (json['tasks'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((entry) => ReviewTask.fromJson(Map<String, dynamic>.from(entry)))
          .toList(),
      completedAt: (json['completed_at'] as num?)?.toInt(),
      summaryTags: _intMap(json['summary_tags']),
      estimatedMinutes: (json['estimated_minutes'] as num?)?.toInt() ?? 15,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.storageName,
      'title': title,
      'date_key': dateKey,
      'due_date_key': dueDateKey,
      'created_at': createdAt,
      'status': status.name,
      'tasks': tasks.map((task) => task.toJson()).toList(),
      if (completedAt != null) 'completed_at': completedAt,
      'summary_tags': summaryTags,
      'estimated_minutes': estimatedMinutes,
    };
  }

  ReviewCourse copyWith({
    ReviewCourseStatus? status,
    List<ReviewTask>? tasks,
    int? completedAt,
  }) {
    return ReviewCourse(
      id: id,
      type: type,
      title: title,
      dateKey: dateKey,
      dueDateKey: dueDateKey,
      createdAt: createdAt,
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      completedAt: completedAt ?? this.completedAt,
      summaryTags: summaryTags,
      estimatedMinutes: estimatedMinutes,
    );
  }
}

class ReviewStats {
  const ReviewStats({
    this.completedTotal = 0,
    this.completedDaily = 0,
    this.completedWeekly = 0,
    this.completedMonthly = 0,
    this.completedManual = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.totalReviewSeconds = 0,
    this.lastCompletedDateKey = '',
  });

  final int completedTotal;
  final int completedDaily;
  final int completedWeekly;
  final int completedMonthly;
  final int completedManual;
  final int currentStreak;
  final int bestStreak;
  final int totalReviewSeconds;
  final String lastCompletedDateKey;

  factory ReviewStats.fromJson(Map<String, dynamic> json) {
    return ReviewStats(
      completedTotal: (json['completed_total'] as num?)?.toInt() ?? 0,
      completedDaily: (json['completed_daily'] as num?)?.toInt() ?? 0,
      completedWeekly: (json['completed_weekly'] as num?)?.toInt() ?? 0,
      completedMonthly: (json['completed_monthly'] as num?)?.toInt() ?? 0,
      completedManual:
          (json['completed_manual'] as num?)?.toInt() ??
          (json['completed_exam'] as num?)?.toInt() ??
          0,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      bestStreak: (json['best_streak'] as num?)?.toInt() ?? 0,
      totalReviewSeconds: (json['total_review_seconds'] as num?)?.toInt() ?? 0,
      lastCompletedDateKey: json['last_completed_date_key']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'completed_total': completedTotal,
      'completed_daily': completedDaily,
      'completed_weekly': completedWeekly,
      'completed_monthly': completedMonthly,
      'completed_manual': completedManual,
      'current_streak': currentStreak,
      'best_streak': bestStreak,
      'total_review_seconds': totalReviewSeconds,
      'last_completed_date_key': lastCompletedDateKey,
    };
  }
}

class ReviewCourseSnapshot {
  const ReviewCourseSnapshot({required this.courses, required this.stats});

  final List<ReviewCourse> courses;
  final ReviewStats stats;

  List<ReviewCourse> get visibleCourses {
    final items = courses.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }
}

class ReviewCourseStore {
  ReviewCourseStore._();

  static final ReviewCourseStore instance = ReviewCourseStore._();

  static const int maxActivityStoredDays = 60;
  static const int courseExpiryDays = 7;
  static const int completedVisibleDays = 1;
  static const int requiredAccuracyPercent = 80;
  static const int _maxHistoryItems = 200;

  Future<ReviewCourseSnapshot> load() async {
    return ReviewCourseSnapshot(
      courses: await _loadCourses(),
      stats: await _loadStats(),
    );
  }

  Future<ReviewCourseSnapshot> generateMissingCourses() async {
    final now = DateTime.now();
    final scope = await _scope();
    var courses = _pruneCourses(await _loadCourses(), now);
    final stats = await _loadStats();
    final activity = await ActivityStore.load();

    if (!_canGenerateNow(now, scope)) {
      await _saveCourses(courses);
      return ReviewCourseSnapshot(courses: courses, stats: stats);
    }

    final todayKey = _formatDateKey(now);
    final weekKey = _weekKey(now);
    final monthKey = _monthKey(now);
    final weaknessTags = await _safeWeaknessTags();
    final additions = <ReviewCourse>[];

    final dailyHistory = await _safeHistory(days: 1, limit: _maxHistoryItems);
    if (!_hasCourse(courses, ReviewCourseType.daily, todayKey) &&
        _hasLearningInRange(activity, _dateOnly(now), _dateOnly(now)) &&
        dailyHistory.isNotEmpty) {
      final course = _buildDailyCourse(
        now,
        todayKey,
        dailyHistory,
        weaknessTags,
      );
      if (course != null) additions.add(course);
    }

    final weekStart = _startOfWeek(now);
    final weeklyHistory = await _safeHistory(days: 7, limit: _maxHistoryItems);
    if (!_hasCourse(courses, ReviewCourseType.weekly, weekKey) &&
        _hasLearningInRange(activity, weekStart, _dateOnly(now)) &&
        weeklyHistory.isNotEmpty) {
      final course = _buildWeeklyCourse(
        now,
        weekKey,
        weeklyHistory,
        weaknessTags,
      );
      if (course != null) additions.add(course);
    }

    final monthStart = DateTime(now.year, now.month);
    final monthlyHistory = await _safeHistory(
      days: 30,
      limit: _maxHistoryItems,
    );
    if (!_hasCourse(courses, ReviewCourseType.monthly, monthKey) &&
        _hasLearningInRange(activity, monthStart, _dateOnly(now)) &&
        monthlyHistory.isNotEmpty) {
      final course = _buildMonthlyCourse(
        now,
        monthKey,
        monthlyHistory,
        weaknessTags,
      );
      if (course != null) additions.add(course);
    }

    if (additions.isNotEmpty) courses = [...additions, ...courses];
    await _saveCourses(courses);
    return ReviewCourseSnapshot(courses: courses, stats: stats);
  }

  Future<ReviewCourseSnapshot> addManualCourse({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final minDate = today.subtract(
      const Duration(days: maxActivityStoredDays - 1),
    );
    var start = _dateOnly(startDate);
    var end = _dateOnly(endDate);
    if (start.isBefore(minDate)) start = minDate;
    if (end.isAfter(today)) end = today;
    if (end.isBefore(start)) end = start;

    final days = end.difference(start).inDays + 1;
    final history = await _safeHistory(
      days: days.clamp(1, maxActivityStoredDays),
      limit: _maxHistoryItems,
    );
    final weaknessTags = await _safeWeaknessTags();
    final idKey = '${_formatDateKey(start)}_${_formatDateKey(end)}';
    final course = _buildManualCourse(
      now,
      idKey,
      start,
      end,
      history,
      weaknessTags,
    );
    if (course == null) return generateMissingCourses();

    final courses = [
      course,
      ...(await _loadCourses()).where((entry) => entry.id != course.id),
    ];
    await _saveCourses(_pruneCourses(courses, now));
    return load();
  }

  Future<ReviewCourseSnapshot> markTaskComplete({
    required String courseId,
    required String taskId,
    int elapsedSeconds = 0,
    int correctCount = 0,
    int totalCount = 0,
  }) async {
    final courses = await _loadCourses();
    final index = courses.indexWhere((course) => course.id == courseId);
    if (index < 0) return load();

    final now = DateTime.now();
    final course = courses[index];
    final tasks = course.tasks.map((task) {
      if (task.id != taskId) return task;
      return task.copyWith(
        completed: true,
        completedAt: now.millisecondsSinceEpoch,
        correctCount: correctCount,
        totalCount: totalCount,
      );
    }).toList();

    var updatedCourse = course.copyWith(tasks: tasks);
    var stats = await _loadStats();
    if (updatedCourse.status == ReviewCourseStatus.available &&
        updatedCourse.canComplete) {
      updatedCourse = updatedCourse.copyWith(
        status: ReviewCourseStatus.completed,
        completedAt: now.millisecondsSinceEpoch,
      );
      stats = _completeStats(stats, updatedCourse, elapsedSeconds);
      await _saveStats(stats);
    }

    final updatedCourses = List<ReviewCourse>.from(courses)
      ..[index] = updatedCourse;
    await _saveCourses(updatedCourses);
    return ReviewCourseSnapshot(courses: updatedCourses, stats: stats);
  }

  Future<List<Map<String, dynamic>>> loadQuestsForTask(ReviewTask task) async {
    final quests = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final ref in task.problemRefs) {
      Map<String, dynamic>? quest;
      if (ref.questId != null && ref.questId!.isNotEmpty) {
        final found = await _safeSearch(questId: ref.questId, pageSize: 1);
        if (found.isNotEmpty) quest = found.first;
      }
      if (quest == null && ref.codebaseId != null && ref.seed != null) {
        final replay = await _safeReplay(ref);
        if (replay.isNotEmpty) quest = replay;
      }
      if (quest == null) continue;
      final key = _questKey(quest, quests.length);
      if (seen.add(key)) quests.add(quest);
    }

    final target = task.targetQuestionCount > 0
        ? task.targetQuestionCount
        : math.max(quests.length, 3);
    if (quests.length < target) {
      for (final tag in task.tags) {
        final found = await _safeSearch(hashTag: tag, pageSize: target);
        for (final quest in found) {
          final key = _questKey(quest, quests.length);
          if (seen.add(key)) quests.add(quest);
          if (quests.length >= target) break;
        }
        if (quests.length >= target) break;
      }
    }
    return quests.take(target).toList();
  }

  ReviewCourse? _buildDailyCourse(
    DateTime now,
    String dateKey,
    List<SolveHistoryItem> history,
    List<WeaknessTag> weaknessTags,
  ) {
    final refs = _refsFromHistory(_incorrectOrAll(history)).take(30).toList();
    final tagCounts = _tagCounts(history, weaknessTags);
    final topTags = _topTags(tagCounts, 5);
    if (refs.isEmpty && topTags.isEmpty) return null;
    return _course(
      now: now,
      id: 'daily_$dateKey',
      type: ReviewCourseType.daily,
      title: '${now.month}월 ${now.day}일 복습',
      dateKey: dateKey,
      estimatedMinutes: 25,
      summaryTags: tagCounts,
      tasks: [
        _problemTask(
          'daily_wrong_$dateKey',
          '오늘 틀린 문제 다시 풀기',
          refs,
          topTags,
          refs.length,
        ),
        _tagProblemTask('daily_concept_$dateKey', '많이 틀린 개념 복습', topTags, 6),
        _readingTask('daily_read_$dateKey', '개념서 읽기', topTags),
        _summaryTask('daily_summary_$dateKey', '취약 태그 요약 보기', topTags),
      ],
    );
  }

  ReviewCourse? _buildWeeklyCourse(
    DateTime now,
    String weekKey,
    List<SolveHistoryItem> history,
    List<WeaknessTag> weaknessTags,
  ) {
    final refs = _refsFromHistory(_incorrectOrAll(history)).take(10).toList();
    final tagCounts = _tagCounts(history, weaknessTags);
    final topTags = _topTags(tagCounts, 5);
    if (refs.isEmpty && topTags.isEmpty) return null;
    final start = _startOfWeek(now);
    final end = start.add(const Duration(days: 6));
    return _course(
      now: now,
      id: 'weekly_$weekKey',
      type: ReviewCourseType.weekly,
      title: '${start.month}월 ${start.day}일~${end.month}월 ${end.day}일 복습',
      dateKey: weekKey,
      estimatedMinutes: 30,
      summaryTags: tagCounts,
      tasks: [
        _problemTask(
          'weekly_wrong_$weekKey',
          '주간 오답 랜덤 10개',
          refs,
          topTags,
          10,
        ),
        _tagProblemTask('weekly_tag_$weekKey', '주간 취약 태그 복습', topTags, 5),
      ],
    );
  }

  ReviewCourse? _buildMonthlyCourse(
    DateTime now,
    String monthKey,
    List<SolveHistoryItem> history,
    List<WeaknessTag> weaknessTags,
  ) {
    final refs = _refsFromHistory(_incorrectOrAll(history)).take(15).toList();
    final tagCounts = _tagCounts(history, weaknessTags);
    final topTags = _topTags(tagCounts, 6);
    if (refs.isEmpty && topTags.isEmpty) return null;
    return _course(
      now: now,
      id: 'monthly_$monthKey',
      type: ReviewCourseType.monthly,
      title: '${now.month}월 다시보기',
      dateKey: monthKey,
      estimatedMinutes: 45,
      summaryTags: tagCounts,
      tasks: [
        _problemTask('monthly_wrong_$monthKey', '월간 오답 복습', refs, topTags, 10),
        _tagProblemTask('monthly_memory_$monthKey', '장기 기억 확인 문제', topTags, 5),
        _readingTask('monthly_read_$monthKey', '주요 취약 개념 재학습', topTags),
        _tagProblemTask('monthly_advanced_$monthKey', '난이도 상승 문제', topTags, 5),
        _statsTask('monthly_stats_$monthKey', '월간 통계 확인', topTags),
      ],
    );
  }

  ReviewCourse? _buildManualCourse(
    DateTime now,
    String idKey,
    DateTime start,
    DateTime end,
    List<SolveHistoryItem> history,
    List<WeaknessTag> weaknessTags,
  ) {
    final refs = _refsFromHistory(_incorrectOrAll(history)).take(20).toList();
    final tagCounts = _tagCounts(history, weaknessTags);
    final topTags = _topTags(tagCounts, 8);
    if (refs.isEmpty && topTags.isEmpty) return null;
    return _course(
      now: now,
      id: 'manual_$idKey',
      type: ReviewCourseType.manual,
      title: '${start.month}월 ${start.day}일~${end.month}월 ${end.day}일 중간복습',
      dateKey: idKey,
      estimatedMinutes: 40,
      summaryTags: tagCounts,
      tasks: [
        _problemTask(
          'manual_wrong_$idKey',
          '선택 기간 누적 오답 문제',
          refs,
          topTags,
          12,
        ),
        _tagProblemTask('manual_tag_$idKey', '취약 태그 집중 문제', topTags, 8),
        _tagProblemTask('manual_mock_$idKey', '실전 랜덤 문제', topTags, 10),
      ],
    );
  }

  ReviewCourse _course({
    required DateTime now,
    required String id,
    required ReviewCourseType type,
    required String title,
    required String dateKey,
    required int estimatedMinutes,
    required Map<String, int> summaryTags,
    required List<ReviewTask> tasks,
  }) {
    return ReviewCourse(
      id: id,
      type: type,
      title: title,
      dateKey: dateKey,
      dueDateKey: _formatDateKey(
        _dateOnly(now).add(const Duration(days: courseExpiryDays)),
      ),
      createdAt: now.millisecondsSinceEpoch,
      status: ReviewCourseStatus.available,
      summaryTags: summaryTags,
      estimatedMinutes: estimatedMinutes,
      tasks: tasks,
    );
  }

  ReviewTask _problemTask(
    String id,
    String title,
    List<ReviewProblemRef> refs,
    List<String> tags,
    int count,
  ) {
    return ReviewTask(
      id: id,
      kind: ReviewTaskKind.redoProblems,
      title: title,
      description: '최종 정답률 80% 이상을 받아야 이수됩니다.',
      required: true,
      problemRefs: refs,
      tags: tags,
      targetQuestionCount: count,
    );
  }

  ReviewTask _tagProblemTask(
    String id,
    String title,
    List<String> tags,
    int count,
  ) {
    return ReviewTask(
      id: id,
      kind: ReviewTaskKind.conceptProblems,
      title: title,
      description: '태그 기반 문제를 풀고 80% 이상을 받아야 합니다.',
      required: true,
      tags: tags,
      targetQuestionCount: count,
    );
  }

  ReviewTask _readingTask(String id, String title, List<String> tags) {
    return ReviewTask(
      id: id,
      kind: ReviewTaskKind.conceptReading,
      title: title,
      description: '추천 개념서를 읽으면 완료됩니다.',
      required: true,
      tags: tags,
    );
  }

  ReviewTask _summaryTask(String id, String title, List<String> tags) {
    return ReviewTask(
      id: id,
      kind: ReviewTaskKind.tagSummary,
      title: title,
      description: '취약 태그 순위를 확인합니다.',
      required: false,
      tags: tags,
    );
  }

  ReviewTask _statsTask(String id, String title, List<String> tags) {
    return ReviewTask(
      id: id,
      kind: ReviewTaskKind.stats,
      title: title,
      description: '복습 통계를 확인합니다.',
      required: true,
      tags: tags,
    );
  }

  Future<List<ReviewCourse>> _loadCourses() async {
    final raw = await LocalDb.instance.getString(await _coursesKey());
    if (raw == null || raw.isEmpty) return <ReviewCourse>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <ReviewCourse>[];
      return decoded
          .whereType<Map>()
          .map(
            (entry) => ReviewCourse.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList();
    } catch (_) {
      return <ReviewCourse>[];
    }
  }

  Future<void> _saveCourses(List<ReviewCourse> courses) async {
    await LocalDb.instance.setString(
      await _coursesKey(),
      jsonEncode(courses.map((course) => course.toJson()).toList()),
    );
  }

  Future<ReviewStats> _loadStats() async {
    final raw = await LocalDb.instance.getString(await _statsKey());
    if (raw == null || raw.isEmpty) return const ReviewStats();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return ReviewStats.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return const ReviewStats();
  }

  Future<void> _saveStats(ReviewStats stats) async {
    await LocalDb.instance.setString(
      await _statsKey(),
      jsonEncode(stats.toJson()),
    );
  }

  Future<String> _coursesKey() async => 'review_courses_v1::${await _scope()}';

  Future<String> _statsKey() async => 'review_stats_v1::${await _scope()}';

  Future<String> _scope() async {
    final fromAuth = (await AuthStorage.instance.readUsername())?.trim();
    if (fromAuth != null && fromAuth.isNotEmpty) return fromAuth;
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString('username')?.trim();
    if (legacy != null && legacy.isNotEmpty) return legacy;
    return 'guest';
  }

  List<ReviewCourse> _pruneCourses(List<ReviewCourse> courses, DateTime now) {
    final today = _dateOnly(now);
    return courses.where((course) {
      final due = _parseDateKey(course.dueDateKey);
      if (due != null && today.isAfter(due)) return false;
      if (course.status == ReviewCourseStatus.completed &&
          course.completedAt != null) {
        final completed = DateTime.fromMillisecondsSinceEpoch(
          course.completedAt!,
        );
        return now.difference(completed).inDays < completedVisibleDays;
      }
      return true;
    }).toList();
  }

  bool _hasCourse(
    List<ReviewCourse> courses,
    ReviewCourseType type,
    String dateKey,
  ) {
    return courses.any(
      (course) => course.type == type && course.dateKey == dateKey,
    );
  }

  bool _canGenerateNow(DateTime now, String scope) {
    final threshold = _dateOnly(now).add(_userMidnightOffset(scope));
    return !now.isBefore(threshold);
  }

  Duration _userMidnightOffset(String scope) {
    final hash = scope.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return Duration(minutes: hash % 180);
  }

  bool _hasLearningInRange(
    ActivitySnapshot activity,
    DateTime start,
    DateTime end,
  ) {
    var cursor = _dateOnly(start);
    final last = _dateOnly(end);
    while (!cursor.isAfter(last)) {
      final day = activity.days[_formatDateKey(cursor)];
      if (day != null &&
          (day.problemNumbers.isNotEmpty ||
              day.bookNumbers.isNotEmpty ||
              day.courseNumbers.isNotEmpty ||
              day.examNumbers.isNotEmpty)) {
        return true;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return false;
  }

  Future<List<SolveHistoryItem>> _safeHistory({
    required int days,
    required int limit,
  }) async {
    try {
      return await ApiClient.instance.fetchSolveHistory(
        days: days,
        limit: limit,
        kind: 'problem',
      );
    } catch (_) {
      return const <SolveHistoryItem>[];
    }
  }

  Future<List<WeaknessTag>> _safeWeaknessTags() async {
    try {
      return await ApiClient.instance.fetchWeaknessTags();
    } catch (_) {
      return const <WeaknessTag>[];
    }
  }

  Future<List<Map<String, dynamic>>> _safeSearch({
    String? hashTag,
    String? questId,
    int pageSize = 10,
  }) async {
    try {
      return await ApiClient.instance.searchQuests(
        hashTag: hashTag,
        questId: questId,
        pageSize: pageSize,
      );
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>> _safeReplay(ReviewProblemRef ref) async {
    try {
      return await ApiClient.instance.replayProblemHabit(
        questId: ref.questId,
        codebaseId: ref.codebaseId,
        seed: ref.seed,
      );
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  List<SolveHistoryItem> _incorrectOrAll(List<SolveHistoryItem> history) {
    final incorrect = history.where(_looksIncorrect).toList();
    return incorrect.isNotEmpty ? incorrect : history;
  }

  bool _looksIncorrect(SolveHistoryItem item) {
    final data = item.data ?? const <String, dynamic>{};
    final raw =
        data['is_correct'] ??
        data['correct'] ??
        data['raw_correct'] ??
        data['pass'];
    if (raw is bool) return raw == false;
    final status = (data['status'] ?? data['result'] ?? '').toString();
    return status == 'incorrect' || status == 'wrong' || status == 'fail';
  }

  List<ReviewProblemRef> _refsFromHistory(List<SolveHistoryItem> items) {
    final refs = <ReviewProblemRef>[];
    final seen = <String>{};
    for (final item in items) {
      final ref = ReviewProblemRef(
        questId: _nonEmpty(item.questId),
        codebaseId: item.codebaseId,
        seed: item.seed,
        title: item.questTitleRaw,
        tags: item.hashTags,
      );
      if ((ref.questId == null || ref.questId!.isEmpty) &&
          (ref.codebaseId == null || ref.seed == null)) {
        continue;
      }
      final key =
          '${ref.questId ?? ''}:${ref.codebaseId ?? ''}:${ref.seed ?? ''}';
      if (seen.add(key)) refs.add(ref);
    }
    return refs;
  }

  Map<String, int> _tagCounts(
    List<SolveHistoryItem> history,
    List<WeaknessTag> weaknessTags,
  ) {
    final counts = <String, int>{};
    for (final item in history) {
      for (final tag in item.hashTags) {
        final cleaned = tag.trim();
        if (cleaned.isEmpty) continue;
        counts[cleaned] = (counts[cleaned] ?? 0) + 1;
      }
    }
    for (final tag in weaknessTags) {
      final cleaned = tag.tag.trim();
      if (cleaned.isEmpty) continue;
      counts[cleaned] = math.max(counts[cleaned] ?? 0, tag.count);
    }
    return counts;
  }

  List<String> _topTags(Map<String, int> counts, int limit) {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).map((entry) => entry.key).toList();
  }

  ReviewStats _completeStats(
    ReviewStats stats,
    ReviewCourse course,
    int elapsedSeconds,
  ) {
    final todayKey = _formatDateKey(DateTime.now());
    final yesterdayKey = _formatDateKey(
      _dateOnly(DateTime.now()).subtract(const Duration(days: 1)),
    );
    final nextStreak = stats.lastCompletedDateKey == todayKey
        ? stats.currentStreak
        : stats.lastCompletedDateKey == yesterdayKey
        ? stats.currentStreak + 1
        : 1;
    return ReviewStats(
      completedTotal: stats.completedTotal + 1,
      completedDaily:
          stats.completedDaily +
          (course.type == ReviewCourseType.daily ? 1 : 0),
      completedWeekly:
          stats.completedWeekly +
          (course.type == ReviewCourseType.weekly ? 1 : 0),
      completedMonthly:
          stats.completedMonthly +
          (course.type == ReviewCourseType.monthly ? 1 : 0),
      completedManual:
          stats.completedManual +
          (course.type == ReviewCourseType.manual ? 1 : 0),
      currentStreak: nextStreak,
      bestStreak: math.max(stats.bestStreak, nextStreak),
      totalReviewSeconds:
          stats.totalReviewSeconds + math.max(elapsedSeconds, 0),
      lastCompletedDateKey: todayKey,
    );
  }
}

ReviewCourseType _parseCourseType(String? value) {
  switch (value) {
    case 'weekly':
      return ReviewCourseType.weekly;
    case 'monthly':
      return ReviewCourseType.monthly;
    case 'manual':
    case 'exam':
      return ReviewCourseType.manual;
    case 'daily':
    default:
      return ReviewCourseType.daily;
  }
}

ReviewCourseStatus _parseCourseStatus(String? value) {
  switch (value) {
    case 'completed':
      return ReviewCourseStatus.completed;
    case 'available':
    case 'expired':
    default:
      return ReviewCourseStatus.available;
  }
}

ReviewTaskKind _parseTaskKind(String? value) {
  for (final kind in ReviewTaskKind.values) {
    if (kind.storageName == value) return kind;
  }
  return ReviewTaskKind.redoProblems;
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const <String>[];
  return raw.map((entry) => entry.toString()).toList();
}

Map<String, int> _intMap(dynamic raw) {
  if (raw is! Map) return const <String, int>{};
  return raw.map(
    (key, value) => MapEntry(
      key.toString(),
      (value as num?)?.toInt() ?? int.tryParse(value.toString()) ?? 0,
    ),
  );
}

String? _nonEmpty(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _startOfWeek(DateTime date) {
  final d = _dateOnly(date);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

String _weekKey(DateTime date) => _formatDateKey(_startOfWeek(date));

String _monthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

DateTime? _parseDateKey(String key) {
  final parts = key.split('-');
  if (parts.length < 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

String _formatDateKey(DateTime date) {
  final d = _dateOnly(date);
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

String _questKey(Map<String, dynamic> quest, int fallbackIndex) {
  final questId = quest['quest_id'] ?? quest['id'];
  final codebaseId = quest['codebase_id'];
  final seed = quest['seed'];
  return '${questId ?? ''}:${codebaseId ?? ''}:${seed ?? ''}:$fallbackIndex';
}
