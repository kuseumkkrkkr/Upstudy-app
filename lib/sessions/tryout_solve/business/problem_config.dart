part of 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';

class PlacementExamAnswer {
  const PlacementExamAnswer({
    required this.itemIndex,
    required this.questId,
    this.userAnswer,
    this.selectedIndex,
  });

  final int itemIndex;
  final String questId;
  final String? userAnswer;
  final int? selectedIndex;
}

class ProblemSolveConfig {
  const ProblemSolveConfig({
    this.questionCount = 3,
    this.hashTags = const <String>[],
    this.gradeImmediately = true,
    this.minDifficultyTier = 3,
    this.maxDifficultyTier = 3,
    this.passRate = 100,
    this.courseId = '',
    this.unitIndex,
    this.quests = const <Map<String, dynamic>>[],
    this.onComplete,
    this.ratingEnabled = true,
    this.mobileQuickSolve = false,
    this.timeLimitSeconds,
    this.onProblemGraded,
    this.placementExam = false,
    this.onPlacementSubmit,
  });

  final int questionCount;
  final List<String> hashTags;
  final bool gradeImmediately;
  final int minDifficultyTier;
  final int maxDifficultyTier;
  final int passRate;
  final String courseId;
  final int? unitIndex;
  final List<Map<String, dynamic>> quests;
  final bool ratingEnabled;
  final bool mobileQuickSolve;
  final int? timeLimitSeconds;
  final bool placementExam;

  /// Called when all problems are graded with [correctCount], [totalCount],
  /// and whether the student [passed] the module.
  final void Function({
    required int correctCount,
    required int totalCount,
    required bool passed,
    int? elapsedSeconds,
  })?
  onComplete;
  final FutureOr<void> Function({
    required int itemIndex,
    required Map<String, dynamic>? quest,
    required bool isCorrect,
    required List<Map<String, dynamic>> stepCorrectness,
    int? selectedIndex,
    int? elapsedSeconds,
  })?
  onProblemGraded;
  final FutureOr<void> Function({
    required List<PlacementExamAnswer> answers,
    required int elapsedSeconds,
  })?
  onPlacementSubmit;

  ProblemSolveConfig copyWith({
    int? questionCount,
    List<String>? hashTags,
    bool? gradeImmediately,
    int? minDifficultyTier,
    int? maxDifficultyTier,
    int? passRate,
    String? courseId,
    int? unitIndex,
    List<Map<String, dynamic>>? quests,
    void Function({
      required int correctCount,
      required int totalCount,
      required bool passed,
      int? elapsedSeconds,
    })?
    onComplete,
    bool? ratingEnabled,
    bool? mobileQuickSolve,
    int? timeLimitSeconds,
    FutureOr<void> Function({
      required int itemIndex,
      required Map<String, dynamic>? quest,
      required bool isCorrect,
      required List<Map<String, dynamic>> stepCorrectness,
      int? selectedIndex,
      int? elapsedSeconds,
    })?
    onProblemGraded,
    bool? placementExam,
    FutureOr<void> Function({
      required List<PlacementExamAnswer> answers,
      required int elapsedSeconds,
    })?
    onPlacementSubmit,
  }) {
    return ProblemSolveConfig(
      questionCount: questionCount ?? this.questionCount,
      hashTags: hashTags ?? this.hashTags,
      gradeImmediately: gradeImmediately ?? this.gradeImmediately,
      minDifficultyTier: minDifficultyTier ?? this.minDifficultyTier,
      maxDifficultyTier: maxDifficultyTier ?? this.maxDifficultyTier,
      passRate: passRate ?? this.passRate,
      courseId: courseId ?? this.courseId,
      unitIndex: unitIndex ?? this.unitIndex,
      quests: quests ?? this.quests,
      onComplete: onComplete ?? this.onComplete,
      ratingEnabled: ratingEnabled ?? this.ratingEnabled,
      mobileQuickSolve: mobileQuickSolve ?? this.mobileQuickSolve,
      timeLimitSeconds: timeLimitSeconds ?? this.timeLimitSeconds,
      onProblemGraded: onProblemGraded ?? this.onProblemGraded,
      placementExam: placementExam ?? this.placementExam,
      onPlacementSubmit: onPlacementSubmit ?? this.onPlacementSubmit,
    );
  }

  factory ProblemSolveConfig.fromJson(Map<String, dynamic> json) {
    List<String> toStringList(dynamic raw) {
      if (raw is! List) return const <String>[];
      return raw.map((entry) => entry.toString()).toList();
    }

    final parsedCount = (json['question_count'] as num?)?.toInt() ?? 3;
    final clampedCount = parsedCount.clamp(1, 40);

    return ProblemSolveConfig(
      questionCount: clampedCount.toInt(),
      hashTags: toStringList(json['hash_tags']),
      gradeImmediately: json['grade_immediately'] as bool? ?? true,
      minDifficultyTier: (json['min_difficulty_tier'] as num?)?.toInt() ?? 3,
      maxDifficultyTier: (json['max_difficulty_tier'] as num?)?.toInt() ?? 3,
      passRate: (json['pass_rate'] as num?)?.toInt() ?? 100,
      courseId: json['course_id']?.toString() ?? '',
      unitIndex: (json['unit_index'] as num?)?.toInt(),
      ratingEnabled: json['rating_enabled'] as bool? ?? true,
      mobileQuickSolve: json['mobile_quick_solve'] as bool? ?? false,
      timeLimitSeconds: (json['time_limit_seconds'] as num?)?.toInt(),
      placementExam: json['placement_exam'] as bool? ?? false,
      quests: (json['quests'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_count': questionCount,
      'hash_tags': hashTags,
      'grade_immediately': gradeImmediately,
      'min_difficulty_tier': minDifficultyTier,
      'max_difficulty_tier': maxDifficultyTier,
      'pass_rate': passRate,
      'course_id': courseId,
      if (unitIndex != null) 'unit_index': unitIndex,
      'rating_enabled': ratingEnabled,
      'mobile_quick_solve': mobileQuickSolve,
      if (timeLimitSeconds != null) 'time_limit_seconds': timeLimitSeconds,
      'placement_exam': placementExam,
      'quests': quests,
    };
  }
}
