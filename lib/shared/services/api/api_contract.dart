/// Central API contract and URI builder.
///
/// Keep backend path changes here. Callers should build URLs through
/// [ApiContract.uri] or [ApiContract.url] instead of concatenating strings.
class ApiContract {
  ApiContract._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// Optional deployment prefix such as `/api/v1`.
  static const String pathPrefix = String.fromEnvironment(
    'API_PATH_PREFIX',
    defaultValue: '',
  );

  /// Path-level compatibility overrides for backend contract changes.
  static const Map<String, String> pathOverrides = <String, String>{};

  static Uri uri(String path, {Map<String, String>? query}) {
    final resolved = _withPrefix(resolvePath(path));
    final parsed = Uri.parse('$baseUrl$resolved');
    if (query == null || query.isEmpty) return parsed;
    final mergedQuery = <String, String>{...parsed.queryParameters, ...query};
    return parsed.replace(queryParameters: mergedQuery);
  }

  static String url(String path, {Map<String, String>? query}) {
    return uri(path, query: query).toString();
  }

  static Uri webSocketUri(String path, {Map<String, String>? query}) {
    final httpUri = uri(path, query: query);
    final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    return httpUri.replace(scheme: scheme);
  }

  static String resolvePath(String path) {
    final normalized = _normalizePath(path);
    return pathOverrides[normalized] ?? normalized;
  }

  static String _normalizePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return '/';
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }

  static String _withPrefix(String path) {
    final prefix = _normalizePrefix(pathPrefix);
    if (prefix.isEmpty) return path;
    return '$prefix${_normalizePath(path)}';
  }

  static String _normalizePrefix(String prefix) {
    final trimmed = prefix.trim();
    if (trimmed.isEmpty || trimmed == '/') return '';
    final withoutTrailing = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    return withoutTrailing.startsWith('/')
        ? withoutTrailing
        : '/$withoutTrailing';
  }
}

class ApiPaths {
  ApiPaths._();

  static const authAnonymous = '/auth/anonymous';
  static const authMe = '/auth/me';
  static const authTeacherLogin = '/auth/teacher/login';
  static const authTeacherRegister = '/auth/teacher/register';

  static const courses = '/courses';
  static const coursesEnrolled = '/courses/enrolled';
  static const coursesEnrollments = '/courses/enrolled';
  static const coursesEnrollmentReorder = '/courses/enrollments/reorder';
  static const coursesHashTags = '/courses/hash-tags';
  static const questGenerationTags = '/quests/generation-tags';
  static const coursesV2 = '/courses/v2';
  static const courseRuntimeNext = '/courses/v2/runtime/next';
  static const courseRuntimeSubmit = '/courses/v2/runtime/submit';
  static const courseProblemSolveLoad =
      '/courses/v2/runtime/problem-solve/load';
  static const courseTextbookViewStart =
      '/courses/v2/runtime/textbook-view/start';
  static const courseTextbookViewHeartbeat =
      '/courses/v2/runtime/textbook-view/heartbeat';
  static const courseTextbookViewComplete =
      '/courses/v2/runtime/textbook-view/complete';

  static const quests = '/quests';
  static const questsGenerate = '/quests/generate';
  static const questsGenerateCancel = '/quests/generate/cancel';
  static const questsGenerateStatus = '/quests/generate/status';
  static const questsGenerateStream = '/quests/generate/stream';
  static const questsTray = '/quests/tray';
  static const variantFromFlowDraft = '/quests/variants/from-flow-draft';
  static const variantFromPromptNote = '/quests/variants/from-prompt-note';
  static const variantConvertMcq = '/quests/variants/convert-mcq';

  static const analysisSolve = '/analysis/solve';
  static const analysisOcr = '/analysis/ocr';
  static const analysisVariantGrade = '/analysis/solve/variant-grade';

  static const exams = '/exams';
  static const oxQuiz = '/ox_quiz';
  static const oxQuizGenerate = '/ox_quiz/generate';
  static const serverChatConfig = '/serverchat/config';
  static const serverChatMessage = '/serverchat/message';
  static const socialWs = '/ws/social';

  static String userStorage(String key) =>
      '/user/storage/${Uri.encodeComponent(key)}';

  static String course(String courseId) => '$courses/$courseId';
  static String courseEnroll(String courseId) => '${course(courseId)}/enroll';
  static String courseUnenroll(String courseId) =>
      '${course(courseId)}/unenroll';
  static String courseProgress(String courseId) =>
      '${course(courseId)}/progress';
  static String courseV2(String courseId) => '$coursesV2/$courseId';
  static String courseV2BindAcademyGroup(String courseId) =>
      '${courseV2(courseId)}/bind-academy-group';
  static String exam(String examId) => '$exams/$examId';
  static String examPdf(String examId) => '${exam(examId)}/pdf';
}
