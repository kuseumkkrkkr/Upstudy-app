class Course {
  const Course({
    required this.id,
    required this.title,
    required this.description,
    required this.level,
    required this.duration,
    this.progress = 0.0,
    this.progressDetail = const {},
    this.status,
    this.lastAction,
    this.benefits = const [],
    this.outline = const [],
    this.types = const [],
    this.units = const [],
    this.focusTags = const [],
    this.lessons = 0,
    this.isDemo = false,
    this.targetOvr = 0,
    this.textbookId = '',
    this.textbookPages = 0,
  });

  final String id;
  final String title;
  final String description;
  final String level;
  final String duration;
  final double progress;
  final Map<String, dynamic> progressDetail;
  final String? status;
  final String? lastAction;
  final List<String> benefits;
  final List<String> outline;
  final List<String> types;
  final List<CourseUnit> units;
  final List<String> focusTags;
  final int lessons;
  final bool isDemo;
  final int targetOvr;
  final String textbookId;
  final int textbookPages;

  bool get isEnrolled =>
      status != null || progress > 0 || progressDetail.isNotEmpty;

  Course copyWith({
    double? progress,
    List<CourseUnit>? units,
    Map<String, dynamic>? progressDetail,
    String? status,
    String? lastAction,
    String? textbookId,
    int? textbookPages,
  }) {
    return Course(
      id: id,
      title: title,
      description: description,
      level: level,
      duration: duration,
      progress: progress ?? this.progress,
      progressDetail: progressDetail ?? this.progressDetail,
      status: status ?? this.status,
      lastAction: lastAction ?? this.lastAction,
      benefits: benefits,
      outline: outline,
      types: types,
      units: units ?? this.units,
      focusTags: focusTags,
      lessons: lessons,
      isDemo: isDemo,
      targetOvr: targetOvr,
      textbookId: textbookId ?? this.textbookId,
      textbookPages: textbookPages ?? this.textbookPages,
    );
  }
}

enum CourseUnitStatus { locked, active, completed }

class CourseUnit {
  const CourseUnit({
    required this.title,
    required this.type,
    required this.detail,
    required this.status,
    this.progress,
    this.estimatedMinutes = 0,
    this.missions = const [],
  });

  final String title;
  final String type;
  final dynamic detail;
  final CourseUnitStatus status;
  final double? progress;
  final int estimatedMinutes;
  final List<CourseUnitMission> missions;
}

class CourseUnitMission {
  const CourseUnitMission({
    required this.title,
    required this.detail,
    this.actionLabel = '시작',
  });

  final String title;
  final dynamic detail;
  final String actionLabel;
}

const List<Course> kSampleCourses = [];
