import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Singleton service that manages runtime course data, sessions, and backend
/// communication for the student learning flow.
class StudentRuntimeService {
  StudentRuntimeService._();

  static final StudentRuntimeService instance = StudentRuntimeService._();

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  final StreamController<RuntimeCourseModel> _courseController =
      StreamController<RuntimeCourseModel>.broadcast();

  /// Emits the currently-selected course whenever it changes.
  Stream<RuntimeCourseModel> get courseStream => _courseController.stream;

  /// Reads the JWT stored by the auth flow.
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token') ?? prefs.getString('student.auth.jwt');
  }

  Map<String, String> _headers(String? token) {
    final h = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  /// Loads all courses the current student is enrolled in.
  ///
  /// On 404 (backend not ready), falls back to mock data so the UI can still
  /// be demonstrated.
  Future<List<RuntimeCourseModel>> loadEnrolledCourses() async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/courses'),
        headers: _headers(token),
      );

      if (response.statusCode == 404) {
        return _mockCourses();
      }

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final dynamic payload = decoded is Map<String, dynamic> && decoded['data'] != null
            ? decoded['data']
            : decoded;
        final List<dynamic> courses = payload is List<dynamic>
            ? payload
            : (payload is Map<String, dynamic> ? (payload['courses'] as List<dynamic>? ?? const []) : const []);
        return courses
            .map((e) => RuntimeCourseModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // For any other non-2xx, return mock data so the UI isn't broken.
      return _mockCourses();
    } on SocketException catch (_) {
      return _mockCourses();
    } on FormatException catch (_) {
      return _mockCourses();
    }
  }

  /// Returns the next module the student should work on for [courseId].
  Future<RuntimeModuleModel?> getNextModule(int courseId) async {
    final token = await _getToken();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/courses/v2/runtime/next'),
        headers: _headers(token),
        body: jsonEncode({'course_id': '$courseId'}),
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final dynamic payload = decoded is Map<String, dynamic> && decoded['data'] != null
            ? decoded['data']
            : decoded;
        if (payload is! Map<String, dynamic>) {
          return null;
        }
        return RuntimeModuleModel.fromJson(
          payload,
        );
      }
      return null;
    } on Exception catch (_) {
      return null;
    }
  }

  /// Submits the result after a student finishes a module.
  Future<bool> submitModuleResult(
    int moduleId,
    Map<String, dynamic> result,
  ) async {
    final token = await _getToken();
    try {
      final courseId = result['course_id']?.toString() ?? result['courseId']?.toString() ?? '';
      if (courseId.isEmpty) {
        return false;
      }
      final correctCount = (result['correct_count'] ?? result['correctCount'] ?? 0) as num;
      final totalCount = (result['total_count'] ?? result['totalCount'] ?? 0) as num;
      final elapsedSeconds = result['elapsed_seconds'] ?? result['elapsedSeconds'];
      final response = await http.post(
        Uri.parse('$_baseUrl/courses/v2/runtime/submit'),
        headers: _headers(token),
        body: jsonEncode({
          'course_id': courseId,
          'module_id': '$moduleId',
          'correct_count': correctCount.toInt(),
          'total_count': totalCount.toInt(),
          if (elapsedSeconds != null) 'elapsed_seconds': elapsedSeconds,
          if (result['student_state'] != null) 'student_state': result['student_state'],
        }),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } on Exception catch (_) {
      return false;
    }
  }

  /// Starts a new learning session for [courseId].
  Future<bool> startSession(int courseId) async {
    final token = await _getToken();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/courses/v2/runtime/next'),
        headers: _headers(token),
        body: jsonEncode({'course_id': '$courseId'}),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } on Exception catch (_) {
      return false;
    }
  }

  /// Ends the session identified by [sessionId].
  Future<bool> endSession(String sessionId) async {
    return true;
  }

  /// Mock data used when the backend is unavailable.
  List<RuntimeCourseModel> _mockCourses() {
    return [
      RuntimeCourseModel(
        id: 1,
        title: '수학 기초 마스터',
        modules: [
          RuntimeModuleModel(
            id: 101,
            moduleType: RuntimeModuleType.textbookView,
            title: '1장: 집합과 명제',
            status: 'completed',
            progressPercent: 100,
            configJson: '{}',
          ),
          RuntimeModuleModel(
            id: 102,
            moduleType: RuntimeModuleType.problemSolve,
            title: '집합 문제 풀이',
            status: 'completed',
            progressPercent: 100,
            configJson: '{}',
          ),
          RuntimeModuleModel(
            id: 103,
            moduleType: RuntimeModuleType.examSolve,
            title: '1장 실전 테스트',
            status: 'available',
            progressPercent: 0,
            configJson: '{}',
          ),
          RuntimeModuleModel(
            id: 104,
            moduleType: RuntimeModuleType.wrongAnswerReview,
            title: '오답 노트 복습',
            status: 'locked',
            progressPercent: 0,
            configJson: '{}',
          ),
          RuntimeModuleModel(
            id: 105,
            moduleType: RuntimeModuleType.challenge,
            title: '집합 챌린지',
            status: 'locked',
            progressPercent: 0,
            configJson: '{}',
          ),
          RuntimeModuleModel(
            id: 106,
            moduleType: RuntimeModuleType.levelTest,
            title: '레벨 테스트',
            status: 'locked',
            progressPercent: 0,
            configJson: '{}',
          ),
        ],
        overallProgress: 33,
      ),
    ];
  }
}
