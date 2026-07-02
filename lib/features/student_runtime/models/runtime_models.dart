// Domain models for the student runtime feature.

/// Types of learning modules available in a course.
enum RuntimeModuleType {
  textbookView,
  problemSolve,
  examSolve,
  wrongAnswerReview,
  challenge,
  levelTest,
}

/// A single module inside a course.
class RuntimeModuleModel {
  RuntimeModuleModel({
    required this.id,
    required this.moduleType,
    required this.title,
    required this.status,
    required this.progressPercent,
    required this.configJson,
  });

  final int id;
  final RuntimeModuleType moduleType;
  final String title;

  /// `'locked'`, `'available'`, or `'completed'`.
  final String status;
  final int progressPercent;
  final String configJson;

  factory RuntimeModuleModel.fromJson(Map<String, dynamic> json) {
    return RuntimeModuleModel(
      id: json['id'] as int,
      moduleType: _parseModuleType(json['module_type'] as String? ?? ''),
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'locked',
      progressPercent: json['progress_percent'] as int? ?? 0,
      configJson: json['config_json'] as String? ?? '{}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'module_type': _moduleTypeToString(moduleType),
      'title': title,
      'status': status,
      'progress_percent': progressPercent,
      'config_json': configJson,
    };
  }
}

/// A course containing multiple modules.
class RuntimeCourseModel {
  RuntimeCourseModel({
    required this.id,
    required this.title,
    required this.modules,
    required this.overallProgress,
  });

  final int id;
  final String title;
  final List<RuntimeModuleModel> modules;
  final int overallProgress;

  factory RuntimeCourseModel.fromJson(Map<String, dynamic> json) {
    return RuntimeCourseModel(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      modules: (json['modules'] as List<dynamic>? ?? [])
          .map((e) => RuntimeModuleModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      overallProgress: json['overall_progress'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'modules': modules.map((m) => m.toJson()).toList(),
      'overall_progress': overallProgress,
    };
  }
}

/// An active learning session.
class RuntimeSessionModel {
  RuntimeSessionModel({
    required this.sessionId,
    required this.courseId,
    required this.currentModuleId,
    required this.startTime,
    required this.elapsedSeconds,
  });

  final String sessionId;
  final int courseId;
  final int currentModuleId;
  final String startTime;
  final int elapsedSeconds;

  factory RuntimeSessionModel.fromJson(Map<String, dynamic> json) {
    return RuntimeSessionModel(
      sessionId: json['session_id'] as String? ?? '',
      courseId: json['course_id'] as int,
      currentModuleId: json['current_module_id'] as int? ?? 0,
      startTime: json['start_time'] as String? ?? '',
      elapsedSeconds: json['elapsed_seconds'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'course_id': courseId,
      'current_module_id': currentModuleId,
      'start_time': startTime,
      'elapsed_seconds': elapsedSeconds,
    };
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

RuntimeModuleType _parseModuleType(String value) {
  switch (value) {
    case 'textbookView':
      return RuntimeModuleType.textbookView;
    case 'problemSolve':
      return RuntimeModuleType.problemSolve;
    case 'examSolve':
      return RuntimeModuleType.examSolve;
    case 'wrongAnswerReview':
      return RuntimeModuleType.wrongAnswerReview;
    case 'challenge':
      return RuntimeModuleType.challenge;
    case 'levelTest':
      return RuntimeModuleType.levelTest;
    default:
      return RuntimeModuleType.textbookView;
  }
}

String _moduleTypeToString(RuntimeModuleType type) {
  switch (type) {
    case RuntimeModuleType.textbookView:
      return 'textbookView';
    case RuntimeModuleType.problemSolve:
      return 'problemSolve';
    case RuntimeModuleType.examSolve:
      return 'examSolve';
    case RuntimeModuleType.wrongAnswerReview:
      return 'wrongAnswerReview';
    case RuntimeModuleType.challenge:
      return 'challenge';
    case RuntimeModuleType.levelTest:
      return 'levelTest';
  }
}
