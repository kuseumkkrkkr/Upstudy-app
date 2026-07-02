/// Config for exam_solve module — creates an exam via API then routes to exam widget.
class ExamSolveConfig {
  const ExamSolveConfig({
    this.examId = '',
    this.ranges = const <ExamRangeConfig>[],
    this.difficultyTier = 3,
    this.questionCount = 20,
    this.paperType = 'aiflow',
    this.courseId = '',
    this.unitIndex,
  });

  final String examId;
  final List<ExamRangeConfig> ranges;
  final int difficultyTier;
  final int questionCount;
  final String paperType;
  final String courseId;
  final int? unitIndex;

  ExamSolveConfig copyWith({
    String? examId,
    List<ExamRangeConfig>? ranges,
    int? difficultyTier,
    int? questionCount,
    String? paperType,
    String? courseId,
    int? unitIndex,
  }) {
    return ExamSolveConfig(
      examId: examId ?? this.examId,
      ranges: ranges ?? this.ranges,
      difficultyTier: difficultyTier ?? this.difficultyTier,
      questionCount: questionCount ?? this.questionCount,
      paperType: paperType ?? this.paperType,
      courseId: courseId ?? this.courseId,
      unitIndex: unitIndex ?? this.unitIndex,
    );
  }

  factory ExamSolveConfig.fromJson(Map<String, dynamic> json) {
    List<ExamRangeConfig> parseRanges(dynamic raw) {
      if (raw is! List) return const <ExamRangeConfig>[];
      return raw
          .whereType<Map>()
          .map((e) => ExamRangeConfig.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return ExamSolveConfig(
      examId: json['exam_id']?.toString() ?? '',
      ranges: parseRanges(json['ranges']),
      difficultyTier: (json['difficulty_tier'] as num?)?.toInt() ?? 3,
      questionCount: (json['question_count'] as num?)?.toInt() ?? 20,
      paperType: json['paper_type']?.toString() ?? 'aiflow',
      courseId: json['course_id']?.toString() ?? '',
      unitIndex: (json['unit_index'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exam_id': examId,
      'ranges': ranges.map((r) => r.toJson()).toList(),
      'difficulty_tier': difficultyTier,
      'question_count': questionCount,
      'paper_type': paperType,
      'course_id': courseId,
      if (unitIndex != null) 'unit_index': unitIndex,
    };
  }
}

class ExamRangeConfig {
  const ExamRangeConfig({this.key = '', this.tags = const <String>[] });

  final String key;
  final List<String> tags;

  Map<String, dynamic> toJson() => {'key': key, 'tags': tags};

  factory ExamRangeConfig.fromJson(Map<String, dynamic> json) {
    List<String> parseTags(dynamic raw) {
      if (raw is! List) return const <String>[];
      return raw.map((e) => e.toString()).toList();
    }
    return ExamRangeConfig(
      key: json['key']?.toString() ?? '',
      tags: parseTags(json['tags']),
    );
  }
}

/// Config for wrong_answer_review module — routes to BuildpageWidget with weakness/habit tags.
class WrongAnswerReviewConfig {
  const WrongAnswerReviewConfig({
    this.tags = const <String>[],
    this.difficultyTier = 3,
    this.questionCount = 10,
    this.sourceType = 'weakness',
    this.courseId = '',
    this.unitIndex,
  });

  final List<String> tags;
  final int difficultyTier;
  final int questionCount;
  final String sourceType; // 'weakness' | 'habit'
  final String courseId;
  final int? unitIndex;

  WrongAnswerReviewConfig copyWith({
    List<String>? tags,
    int? difficultyTier,
    int? questionCount,
    String? sourceType,
    String? courseId,
    int? unitIndex,
  }) {
    return WrongAnswerReviewConfig(
      tags: tags ?? this.tags,
      difficultyTier: difficultyTier ?? this.difficultyTier,
      questionCount: questionCount ?? this.questionCount,
      sourceType: sourceType ?? this.sourceType,
      courseId: courseId ?? this.courseId,
      unitIndex: unitIndex ?? this.unitIndex,
    );
  }

  factory WrongAnswerReviewConfig.fromJson(Map<String, dynamic> json) {
    List<String> parseTags(dynamic raw) {
      if (raw is! List) return const <String>[];
      return raw.map((e) => e.toString()).toList();
    }

    return WrongAnswerReviewConfig(
      tags: parseTags(json['tags']),
      difficultyTier: (json['difficulty_tier'] as num?)?.toInt() ?? 3,
      questionCount: (json['question_count'] as num?)?.toInt() ?? 10,
      sourceType: json['source_type']?.toString() ?? 'weakness',
      courseId: json['course_id']?.toString() ?? '',
      unitIndex: (json['unit_index'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tags': tags,
      'difficulty_tier': difficultyTier,
      'question_count': questionCount,
      'source_type': sourceType,
      'course_id': courseId,
      if (unitIndex != null) 'unit_index': unitIndex,
    };
  }
}

/// Config for curriculum_group module — standalone group launcher UI.
class CurriculumGroupConfig {
  const CurriculumGroupConfig({
    this.groupId = '',
    this.title = '',
    this.items = const <CurriculumItemConfig>[],
    this.courseId = '',
    this.unitIndex,
  });

  final String groupId;
  final String title;
  final List<CurriculumItemConfig> items;
  final String courseId;
  final int? unitIndex;

  CurriculumGroupConfig copyWith({
    String? groupId,
    String? title,
    List<CurriculumItemConfig>? items,
    String? courseId,
    int? unitIndex,
  }) {
    return CurriculumGroupConfig(
      groupId: groupId ?? this.groupId,
      title: title ?? this.title,
      items: items ?? this.items,
      courseId: courseId ?? this.courseId,
      unitIndex: unitIndex ?? this.unitIndex,
    );
  }

  factory CurriculumGroupConfig.fromJson(Map<String, dynamic> json) {
    List<CurriculumItemConfig> parseItems(dynamic raw) {
      if (raw is! List) return const <CurriculumItemConfig>[];
      return raw
          .whereType<Map>()
          .map((e) => CurriculumItemConfig.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return CurriculumGroupConfig(
      groupId: json['group_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      items: parseItems(json['items']),
      courseId: json['course_id']?.toString() ?? '',
      unitIndex: (json['unit_index'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'title': title,
      'items': items.map((i) => i.toJson()).toList(),
      'course_id': courseId,
      if (unitIndex != null) 'unit_index': unitIndex,
    };
  }
}

class CurriculumItemConfig {
  const CurriculumItemConfig({
    this.missionType = '',
    this.title = '',
    this.detail = const <String, dynamic>{},
  });

  final String missionType;
  final String title;
  final Map<String, dynamic> detail;

  CurriculumItemConfig copyWith({
    String? missionType,
    String? title,
    Map<String, dynamic>? detail,
  }) {
    return CurriculumItemConfig(
      missionType: missionType ?? this.missionType,
      title: title ?? this.title,
      detail: detail ?? this.detail,
    );
  }

  factory CurriculumItemConfig.fromJson(Map<String, dynamic> json) {
    return CurriculumItemConfig(
      missionType: json['mission_type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      detail: json['detail'] is Map
          ? Map<String, dynamic>.from(json['detail'] as Map)
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() => {
        'mission_type': missionType,
        'title': title,
        'detail': detail,
      };
}

/// Config for challenge_group module — routes to BuildpageWidget with challenge tags.
class ChallengeGroupConfig {
  const ChallengeGroupConfig({
    this.challengeId = '',
    this.tags = const <String>[],
    this.difficultyTier = 3,
    this.questionCount = 10,
    this.timeLimitMinutes = 30,
    this.courseId = '',
    this.unitIndex,
  });

  final String challengeId;
  final List<String> tags;
  final int difficultyTier;
  final int questionCount;
  final int timeLimitMinutes;
  final String courseId;
  final int? unitIndex;

  ChallengeGroupConfig copyWith({
    String? challengeId,
    List<String>? tags,
    int? difficultyTier,
    int? questionCount,
    int? timeLimitMinutes,
    String? courseId,
    int? unitIndex,
  }) {
    return ChallengeGroupConfig(
      challengeId: challengeId ?? this.challengeId,
      tags: tags ?? this.tags,
      difficultyTier: difficultyTier ?? this.difficultyTier,
      questionCount: questionCount ?? this.questionCount,
      timeLimitMinutes: timeLimitMinutes ?? this.timeLimitMinutes,
      courseId: courseId ?? this.courseId,
      unitIndex: unitIndex ?? this.unitIndex,
    );
  }

  factory ChallengeGroupConfig.fromJson(Map<String, dynamic> json) {
    List<String> parseTags(dynamic raw) {
      if (raw is! List) return const <String>[];
      return raw.map((e) => e.toString()).toList();
    }

    return ChallengeGroupConfig(
      challengeId: json['challenge_id']?.toString() ?? '',
      tags: parseTags(json['tags']),
      difficultyTier: (json['difficulty_tier'] as num?)?.toInt() ?? 3,
      questionCount: (json['question_count'] as num?)?.toInt() ?? 10,
      timeLimitMinutes: (json['time_limit_minutes'] as num?)?.toInt() ?? 30,
      courseId: json['course_id']?.toString() ?? '',
      unitIndex: (json['unit_index'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'challenge_id': challengeId,
      'tags': tags,
      'difficulty_tier': difficultyTier,
      'question_count': questionCount,
      'time_limit_minutes': timeLimitMinutes,
      'course_id': courseId,
      if (unitIndex != null) 'unit_index': unitIndex,
    };
  }
}

/// Config for level_test module — OX quiz or exam-based assessment widget.
class LevelTestConfig {
  const LevelTestConfig({
    this.testType = 'ox',
    this.tags = const <String>[],
    this.questionCount = 10,
    this.difficultyTier = 3,
    this.courseId = '',
    this.unitIndex,
  });

  final String testType; // 'ox' | 'exam'
  final List<String> tags;
  final int questionCount;
  final int difficultyTier;
  final String courseId;
  final int? unitIndex;

  LevelTestConfig copyWith({
    String? testType,
    List<String>? tags,
    int? questionCount,
    int? difficultyTier,
    String? courseId,
    int? unitIndex,
  }) {
    return LevelTestConfig(
      testType: testType ?? this.testType,
      tags: tags ?? this.tags,
      questionCount: questionCount ?? this.questionCount,
      difficultyTier: difficultyTier ?? this.difficultyTier,
      courseId: courseId ?? this.courseId,
      unitIndex: unitIndex ?? this.unitIndex,
    );
  }

  factory LevelTestConfig.fromJson(Map<String, dynamic> json) {
    List<String> parseTags(dynamic raw) {
      if (raw is! List) return const <String>[];
      return raw.map((e) => e.toString()).toList();
    }

    return LevelTestConfig(
      testType: json['test_type']?.toString() ?? 'ox',
      tags: parseTags(json['tags']),
      questionCount: (json['question_count'] as num?)?.toInt() ?? 10,
      difficultyTier: (json['difficulty_tier'] as num?)?.toInt() ?? 3,
      courseId: json['course_id']?.toString() ?? '',
      unitIndex: (json['unit_index'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'test_type': testType,
      'tags': tags,
      'question_count': questionCount,
      'difficulty_tier': difficultyTier,
      'course_id': courseId,
      if (unitIndex != null) 'unit_index': unitIndex,
    };
  }
}
