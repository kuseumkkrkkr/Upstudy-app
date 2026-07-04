import 'dart:convert';

import '../../data/models/course.dart';
import 'api_client.dart';

class CourseService {
  CourseService._();

  static Course courseFromJsonForTest(Map<String, dynamic> json) {
    return _courseFromJson(json);
  }

  static int? parseRecommendedDurationDays(String? value) {
    final text = (value ?? '').trim().toLowerCase().replaceAll(' ', '');
    if (text.isEmpty) return null;
    final plain = int.tryParse(text);
    if (plain != null) return plain;
    final match = RegExp(
      r'(\d+)(일|주|개월|달|day|days|week|weeks|month|months)',
    ).firstMatch(text);
    if (match == null) return null;
    final amount = int.parse(match.group(1)!);
    final unit = match.group(2)!;
    if (unit == '주' || unit.startsWith('week')) return amount * 7;
    if (unit == '개월' || unit == '달' || unit.startsWith('month')) {
      return amount * 30;
    }
    return amount;
  }

  static Future<List<Course>> fetchCourses({
    String? keyword,
    String? tag,
    double? recommendOvr,
  }) async {
    final token = await ApiClient.instance.requireToken();
    final params = <String, String>{};
    if (keyword != null && keyword.trim().isNotEmpty) {
      params['q'] = keyword.trim();
    }
    if (tag != null && tag.trim().isNotEmpty) params['tag'] = tag.trim();
    if (recommendOvr != null) params['recommend_ovr'] = recommendOvr.toString();
    final uri = Uri.parse(
      '${ApiClient.baseUrl}/courses',
    ).replace(queryParameters: params.isEmpty ? null : params);
    final resp = await ApiClient.instance.authedGet(uri, token: token);
    if (resp.statusCode != 200) {
      throw Exception('Failed to load courses: ${resp.statusCode}');
    }
    final payload = jsonDecode(resp.body) as Map<String, dynamic>;
    final courses = (payload['courses'] as List<dynamic>? ?? [])
        .map((item) => _courseFromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return courses;
  }

  static Future<List<Course>> fetchMyCourses() async {
    final token = await ApiClient.instance.requireToken();
    final uri = Uri.parse('${ApiClient.baseUrl}/courses/my');
    final resp = await ApiClient.instance.authedGet(uri, token: token);
    if (resp.statusCode == 200) {
      final payload = jsonDecode(resp.body) as Map<String, dynamic>;
      final courses = (payload['courses'] as List<dynamic>? ?? [])
          .map(
            (item) => _courseFromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      if (courses.isEmpty) {
        final assigned = await _fallbackMyCoursesFromAcademyAssignments(token);
        if (assigned.isNotEmpty) return assigned;
      }
      return courses;
    }

    if (resp.statusCode == 404) {
      // Older/local servers may not expose /courses/my. Try enrollments,
      // then fall back to the generic /courses list (which includes
      // enrollment data in its response).
      final fromEnrollments = await _fallbackMyCoursesFromEnrollments(token);
      if (fromEnrollments.isNotEmpty) return fromEnrollments;
      final fromAssignments = await _fallbackMyCoursesFromAcademyAssignments(
        token,
      );
      if (fromAssignments.isNotEmpty) return fromAssignments;
      final fromCourses = await _fallbackMyCoursesFromCourses(token);
      return fromCourses;
    }

    throw Exception('Failed to load my courses: ${resp.statusCode}');
  }

  static Future<List<Course>> _fallbackMyCoursesFromAcademyAssignments(
    String token,
  ) async {
    final uri = Uri.parse(
      '${ApiClient.baseUrl}/academy/assignments/my',
    ).replace(queryParameters: {'kind': 'course'});
    final resp = await ApiClient.instance.authedGet(uri, token: token);
    if (resp.statusCode != 200) return const <Course>[];
    final payload = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = payload['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : payload;
    final items = data['items'] as List<dynamic>? ?? const [];
    final courseIds = <String>[];
    for (final item in items) {
      if (item is! Map) continue;
      final id = item['ref_id']?.toString() ?? '';
      if (id.isNotEmpty && !courseIds.contains(id)) {
        courseIds.add(id);
      }
    }
    final courses = <Course>[];
    for (final courseId in courseIds) {
      try {
        final courseUri = Uri.parse('${ApiClient.baseUrl}/courses/v2/$courseId');
        final courseResp = await ApiClient.instance.authedGet(
          courseUri,
          token: token,
        );
        if (courseResp.statusCode != 200) continue;
        final body = jsonDecode(courseResp.body) as Map<String, dynamic>;
        final raw = body['data'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(body['data'] as Map)
            : body;
        courses.add(_courseFromJson(raw));
      } catch (_) {
        // Ignore broken assignment records so the rest of the list can render.
      }
    }
    return courses;
  }

  static Future<Course> enroll(String courseId) async {
    final token = await ApiClient.instance.requireToken();
    final uri = Uri.parse('${ApiClient.baseUrl}/courses/$courseId/enroll');
    final resp = await ApiClient.instance.authedPost(uri, token: token);
    if (resp.statusCode != 200) {
      throw Exception('Failed to enroll: ${resp.statusCode}');
    }
    final payload = jsonDecode(resp.body) as Map<String, dynamic>;
    // Enrollment returns progress, but we still need course details separately.
    final course = await fetchCourse(courseId);
    final progressDetail = payload['progress'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(payload['progress'] as Map)
        : const <String, dynamic>{};
    final enrolled = course.copyWith(
      progress: (payload['percent'] as num?)?.toDouble() ?? 0.0,
      progressDetail: progressDetail,
      status: payload['status']?.toString(),
      lastAction: payload['last_action']?.toString(),
    );
    return enrolled;
  }

  static Future<void> unenroll(String courseId) async {
    final token = await ApiClient.instance.requireToken();
    final uri = Uri.parse('${ApiClient.baseUrl}/courses/$courseId/unenroll');
    final resp = await ApiClient.instance.authedPost(uri, token: token);
    if (resp.statusCode != 200) {
      throw Exception('Failed to unenroll: ${resp.statusCode}');
    }
  }

  static Future<void> reorderEnrollments(List<String> courseIds) async {
    final token = await ApiClient.instance.requireToken();
    final uri = Uri.parse('${ApiClient.baseUrl}/courses/enrollments/reorder');
    final body = jsonEncode({'course_ids': courseIds});
    final resp = await ApiClient.instance.authedPost(
      uri,
      token: token,
      body: body,
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to reorder enrollments: ${resp.statusCode}');
    }
  }

  static Future<Course> fetchCourse(String courseId) async {
    final token = await ApiClient.instance.requireToken();
    final uri = Uri.parse('${ApiClient.baseUrl}/courses/$courseId');
    final resp = await ApiClient.instance.authedGet(uri, token: token);
    if (resp.statusCode != 200) {
      throw Exception('Failed to load course: ${resp.statusCode}');
    }
    final payload = jsonDecode(resp.body) as Map<String, dynamic>;
    return _courseFromJson(payload);
  }

  static Future<Map<String, dynamic>> runtimeState(String courseId) async {
    final token = await ApiClient.instance.requireToken();
    final normalizedId = courseId.trim();
    if (normalizedId.isEmpty) {
      return const <String, dynamic>{
        'status': 'in_progress',
        'pause_reason': '',
        'curriculum': <String, dynamic>{
          'enabled': false,
          'schedule': <dynamic>[],
        },
      };
    }

    final candidates = <Uri>[
      Uri.parse('${ApiClient.baseUrl}/courses/$normalizedId/runtime-state'),
      Uri.parse('${ApiClient.baseUrl}/courses/$normalizedId/runtime/state'),
      Uri.parse('${ApiClient.baseUrl}/courses/$normalizedId/state'),
    ];

    for (final uri in candidates) {
      final resp = await ApiClient.instance.authedGet(uri, token: token);
      if (resp.statusCode != 200) {
        continue;
      }
      final decoded = jsonDecode(resp.body);
      final payload = decoded is Map<String, dynamic>
          ? decoded
          : const <String, dynamic>{};
      final curriculum = payload['curriculum'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(payload['curriculum'])
          : const <String, dynamic>{};
      return <String, dynamic>{
        'status': (payload['status'] ?? 'in_progress').toString(),
        'pause_reason': (payload['pause_reason'] ?? '').toString(),
        'curriculum': <String, dynamic>{
          'enabled': curriculum['enabled'] == true,
          'schedule': curriculum['schedule'] is List
              ? List<dynamic>.from(curriculum['schedule'] as List)
              : const <dynamic>[],
        },
      };
    }

    return const <String, dynamic>{
      'status': 'in_progress',
      'pause_reason': '',
      'curriculum': <String, dynamic>{
        'enabled': false,
        'schedule': <dynamic>[],
      },
    };
  }

  static Future<void> updateProgress({
    required String courseId,
    required Map<String, dynamic> progress,
    required double percent,
    String? lastAction,
  }) async {
    final token = await ApiClient.instance.requireToken();
    final uri = Uri.parse('${ApiClient.baseUrl}/courses/$courseId/progress');
    final body = jsonEncode({
      'progress': progress,
      'percent': percent,
      if (lastAction != null) 'last_action': lastAction,
    });
    final resp = await ApiClient.instance.authedPost(
      uri,
      body: body,
      token: token,
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to update progress: ${resp.statusCode}');
    }
  }

  static Future<List<Course>> _fallbackMyCoursesFromEnrollments(
    String token,
  ) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/courses/enrollments');
    final resp = await ApiClient.instance.authedGet(uri, token: token);
    if (resp.statusCode != 200) {
      return const <Course>[];
    }

    final payload = jsonDecode(resp.body) as Map<String, dynamic>;
    final enrollments = payload['items'] as List<dynamic>? ?? const [];

    final courses = <Course>[];
    for (final entry in enrollments) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final courseId = map['course_id']?.toString() ?? '';
      if (courseId.isEmpty) continue;
      try {
        final course = await fetchCourse(courseId);
        final progressDetail = map['progress'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(map['progress'] as Map)
            : const <String, dynamic>{};
        courses.add(
          course.copyWith(
            progress: (map['percent'] as num?)?.toDouble() ?? course.progress,
            progressDetail: progressDetail,
            status: map['status']?.toString(),
            lastAction: map['last_action']?.toString(),
          ),
        );
      } catch (_) {
        // Ignore broken course records so the rest can load.
      }
    }
    return courses;
  }

  static Future<List<Course>> _fallbackMyCoursesFromCourses(
    String token,
  ) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/courses');
    final resp = await ApiClient.instance.authedGet(uri, token: token);
    if (resp.statusCode != 200) {
      return const <Course>[];
    }
    final payload = jsonDecode(resp.body) as Map<String, dynamic>;
    final courses = (payload['courses'] as List<dynamic>? ?? [])
        .map((item) => _courseFromJson(Map<String, dynamic>.from(item as Map)))
        .where((c) => c.progress > 0 || c.status != null || c.progressDetail.isNotEmpty)
        .toList();
    return courses;
  }

  static Course _courseFromJson(Map<String, dynamic> json) {
    final progressRaw = json['percent'] ?? json['progress'];
    final progressValue = progressRaw is num ? progressRaw.toDouble() : 0.0;
    final progressDetail = json['progress'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['progress'] as Map)
        : const <String, dynamic>{};

    final unitsRaw = _normalizedUnits(json);
    final units = <CourseUnit>[];
    final completedUnits = unitsRaw.isEmpty
        ? 0
        : (progressValue.clamp(0.0, 1.0) * unitsRaw.length).floor();

    for (var i = 0; i < unitsRaw.length; i++) {
      final u = Map<String, dynamic>.from(unitsRaw[i] as Map);
      final missionsRaw = u['missions'] as List<dynamic>? ?? [];
      final status = i < completedUnits
          ? CourseUnitStatus.completed
          : (i == completedUnits
                ? CourseUnitStatus.active
                : CourseUnitStatus.locked);
      final unitProgress = status == CourseUnitStatus.completed
          ? 1.0
          : (status == CourseUnitStatus.active
                ? (progressValue.clamp(0.0, 1.0) * unitsRaw.length) -
                      completedUnits
                : 0.0);
      // Parse detail JSON if it is a string
      dynamic detail = u['detail'];
      if (detail is String) {
        try {
          detail = jsonDecode(detail);
        } catch (_) {}
      }
      units.add(
        CourseUnit(
          title: u['title']?.toString() ?? '',
          type: u['type']?.toString() ?? '',
          detail: detail ?? u['detail']?.toString() ?? '',
          status: status,
          progress: unitProgress.clamp(0.0, 1.0),
          estimatedMinutes: (u['estimated_minutes'] as num?)?.toInt() ?? 0,
          missions: missionsRaw
              .map(
                (m) => CourseUnitMission(
                  title: (m as Map<String, dynamic>)['title']?.toString() ?? '',
                  detail: m['detail'] is String
                      ? (jsonDecode(m['detail'] as String) as Object? ??
                            m['detail'])
                      : m['detail'] ?? '',
                  actionLabel: m['action_label']?.toString() ?? 'Start',
                ),
              )
              .toList(),
        ),
      );
    }

    return Course(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      level: json['difficulty']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '',
      progress: progressValue,
      progressDetail: progressDetail,
      status: json['status']?.toString(),
      lastAction: json['last_action']?.toString(),
      benefits: List<String>.from(
        json['benefits'] as List<dynamic>? ?? const [],
      ),
      outline: List<String>.from(json['outline'] as List<dynamic>? ?? const []),
      types: List<String>.from(json['types'] as List<dynamic>? ?? const []),
      units: units,
      focusTags: List<String>.from(
        json['focus_tags'] as List<dynamic>? ?? const [],
      ),
      lessons: (json['lessons'] as num?)?.toInt() ?? units.length,
      isDemo: json['is_demo'] == true,
      targetOvr: (json['target_ovr'] as num?)?.toInt() ?? 0,
      textbookId: json['textbook_id']?.toString() ?? '',
      textbookPages: (json['textbook_pages'] as num?)?.toInt() ?? 0,
    );
  }

  static List<dynamic> _normalizedUnits(Map<String, dynamic> json) {
    final unitsRaw = json['units'] as List<dynamic>? ?? const [];
    if (unitsRaw.isNotEmpty) {
      return unitsRaw;
    }

    final modulesRaw = json['modules'] as List<dynamic>? ?? const [];
    return modulesRaw.whereType<Map>().map((raw) {
      final module = Map<String, dynamic>.from(raw);
      return <String, dynamic>{
        'title': module['title']?.toString() ?? '',
        'type': module['type']?.toString() ?? '',
        'detail': module,
        'estimated_minutes':
            (module['estimated_minutes'] as num?)?.toInt() ??
            (module['exam_duration'] as num?)?.toInt() ??
            (module['min_minutes'] as num?)?.toInt() ??
            0,
        'missions': const <dynamic>[],
      };
    }).toList(growable: false);
  }
}
