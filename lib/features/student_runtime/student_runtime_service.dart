import 'dart:async';
import 'dart:convert';

import '../../shared/services/api/api_client.dart';
import '../../shared/services/api/api_contract.dart';
import 'models.dart';

/// 학생 학습 화면에서 런타임 코스 데이터와 세션 API 호출을 담당한다.
class StudentRuntimeService {
  StudentRuntimeService._();

  static final StudentRuntimeService instance = StudentRuntimeService._();

  final StreamController<RuntimeCourseModel> _courseController =
      StreamController<RuntimeCourseModel>.broadcast();

  /// 현재 선택된 코스를 스트림으로 노출한다.
  Stream<RuntimeCourseModel> get courseStream => _courseController.stream;

  /// 현재 사용자 수강 중인 코스 목록을 조회한다.
  ///
  /// 필요 변수: 없음
  /// 동작: /courses를 캐시 TTL 20초로 조회해 재입장 시 동일 조회 트래픽을 줄인다.
  Future<List<RuntimeCourseModel>> loadEnrolledCourses() async {
    try {
      final payload = await ApiClient.instance.authedGetJson(
        ApiContract.uri(ApiPaths.courses),
        useCache: true,
        cacheTtl: const Duration(seconds: 20),
        parser: (d) {
          if (d is Map<String, dynamic>) return d;
          if (d is Map) return Map<String, dynamic>.from(d);
          return const <String, dynamic>{};
        },
      );

      final dynamic decoded = payload.data ?? const <String, dynamic>{};
      final dynamic normalizedPayload = decoded is Map<String, dynamic> &&
              decoded['data'] != null
          ? decoded['data']
          : decoded;
      final List<dynamic> courses = normalizedPayload is List<dynamic>
          ? normalizedPayload
          : (normalizedPayload is Map<String, dynamic>
              ? (normalizedPayload['courses'] as List<dynamic>? ?? const [])
              : const []);

      return courses
          .map((e) => RuntimeCourseModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on Exception catch (_) {
      // API 실패 시에도 UI가 깨지지 않도록 샘플 데이터 반환.
      return _mockCourses();
    }
  }

  /// 다음 학습 모듈 정보를 조회한다.
  ///
  /// 필요 변수: courseId
  /// 동작: POST 호출이므로 캐시는 사용하지 않고 200 응답만 파싱한다.
  Future<RuntimeModuleModel?> getNextModule(int courseId) async {
    try {
      final response = await ApiClient.instance.authedPost(
        ApiContract.uri(ApiPaths.courseRuntimeNext),
        body: {'course_id': '$courseId'},
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final dynamic payload = decoded is Map<String, dynamic> &&
                decoded['data'] != null
            ? decoded['data']
            : decoded;
        if (payload is! Map<String, dynamic>) {
          return null;
        }
        return RuntimeModuleModel.fromJson(payload);
      }
      return null;
    } on Exception catch (_) {
      return null;
    }
  }

  /// 모듈 완료 결과를 제출한다.
  ///
  /// 필요 변수: moduleId, result
  /// 동작: 제출 성공/실패 여부를 bool로 반환한다.
  Future<bool> submitModuleResult(
    int moduleId,
    Map<String, dynamic> result,
  ) async {
    try {
      final courseId =
          result['course_id']?.toString() ??
          result['courseId']?.toString() ??
          '';
      if (courseId.isEmpty) {
        return false;
      }
      final correctCount =
          (result['correct_count'] ?? result['correctCount'] ?? 0) as num;
      final totalCount = (result['total_count'] ?? result['totalCount'] ?? 0) as num;
      final elapsedSeconds = result['elapsed_seconds'] ?? result['elapsedSeconds'];
      final response = await ApiClient.instance.authedPost(
        ApiContract.uri(ApiPaths.courseRuntimeSubmit),
        body: {
          'course_id': courseId,
          'module_id': '$moduleId',
          'correct_count': correctCount.toInt(),
          'total_count': totalCount.toInt(),
          if (elapsedSeconds != null) 'elapsed_seconds': elapsedSeconds,
          if (result['student_state'] != null)
            'student_state': result['student_state'],
        },
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } on Exception catch (_) {
      return false;
    }
  }

  /// 세션 시작 API.
  ///
  /// 필요 변수: courseId
  /// 동작: 시작 요청 성공 여부만 bool로 반환한다.
  Future<bool> startSession(int courseId) async {
    try {
      final response = await ApiClient.instance.authedPost(
        ApiContract.uri(ApiPaths.courseRuntimeNext),
        body: {'course_id': '$courseId'},
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } on Exception catch (_) {
      return false;
    }
  }

  /// 세션 종료는 현재 백엔드 미구현으로 임시 true 처리.
  Future<bool> endSession(String sessionId) async {
    return true;
  }

  /// API 장애 시 화면 렌더링을 보장하기 위한 더미 데이터.
  List<RuntimeCourseModel> _mockCourses() {
    return [
      RuntimeCourseModel(
        id: 1,
        title: '샘플 강의',
        modules: [
          RuntimeModuleModel(
            id: 101,
            moduleType: RuntimeModuleType.textbookView,
            title: '1단계 교재 강의',
            status: 'completed',
            progressPercent: 100,
            configJson: '{}',
          ),
          RuntimeModuleModel(
            id: 102,
            moduleType: RuntimeModuleType.problemSolve,
            title: '1단계 문제 풀이',
            status: 'completed',
            progressPercent: 100,
            configJson: '{}',
          ),
          RuntimeModuleModel(
            id: 103,
            moduleType: RuntimeModuleType.examSolve,
            title: '1단계 모의고사',
            status: 'available',
            progressPercent: 0,
            configJson: '{}',
          ),
          RuntimeModuleModel(
            id: 104,
            moduleType: RuntimeModuleType.wrongAnswerReview,
            title: '오답 노트',
            status: 'locked',
            progressPercent: 0,
            configJson: '{}',
          ),
          RuntimeModuleModel(
            id: 105,
            moduleType: RuntimeModuleType.challenge,
            title: '챌린지 모드',
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
