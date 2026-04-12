part of s11.tryout;

class ProblemSolveConfig {
  const ProblemSolveConfig({
    this.questionCount = 4,
    this.hashTags = const <String>[],
    this.gradeImmediately = true,
    this.minDifficultyTier = 3,
    this.maxDifficultyTier = 3,
  });

  final int questionCount;
  final List<String> hashTags;
  final bool gradeImmediately;
  final int minDifficultyTier;
  final int maxDifficultyTier;

  ProblemSolveConfig copyWith({
    int? questionCount,
    List<String>? hashTags,
    bool? gradeImmediately,
    int? minDifficultyTier,
    int? maxDifficultyTier,
  }) {
    return ProblemSolveConfig(
      questionCount: questionCount ?? this.questionCount,
      hashTags: hashTags ?? this.hashTags,
      gradeImmediately: gradeImmediately ?? this.gradeImmediately,
      minDifficultyTier: minDifficultyTier ?? this.minDifficultyTier,
      maxDifficultyTier: maxDifficultyTier ?? this.maxDifficultyTier,
    );
  }

  factory ProblemSolveConfig.fromJson(Map<String, dynamic> json) {
    List<String> toStringList(dynamic raw) {
      if (raw is! List) return const <String>[];
      return raw.map((entry) => entry.toString()).toList();
    }
    final parsedCount = (json['question_count'] as num?)?.toInt() ?? 4;
    final clampedCount = parsedCount.clamp(4, 40);

    return ProblemSolveConfig(
      questionCount: clampedCount.toInt(),
      hashTags: toStringList(json['hash_tags']),
      gradeImmediately: json['grade_immediately'] as bool? ?? true,
      minDifficultyTier: (json['min_difficulty_tier'] as num?)?.toInt() ?? 3,
      maxDifficultyTier: (json['max_difficulty_tier'] as num?)?.toInt() ?? 3,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_count': questionCount,
      'hash_tags': hashTags,
      'grade_immediately': gradeImmediately,
      'min_difficulty_tier': minDifficultyTier,
      'max_difficulty_tier': maxDifficultyTier,
    };
  }
}
