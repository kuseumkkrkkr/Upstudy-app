import 'package:flutter/material.dart';

import 'package:s11/sessions/auth/ui/pages/login_page.dart';
import 'package:s11/sessions/auth/ui/pages/profile_page.dart';
import 'package:s11/sessions/auth/ui/pages/signup_page.dart';
import 'package:s11/sessions/landing/ui/pages/landing_about_page.dart';
import 'package:s11/sessions/landing/ui/pages/landing_page.dart';
import 'package:s11/sessions/settings/ui/pages/settings_page.dart';
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
import 'package:s11/shared/services/api/api_client.dart';

import 'package:s11/features/student_runtime/student_runtime.dart';
import 'package:s11/features/level_test/level_test.dart';
import 'package:s11/features/student_schedule/student_schedule.dart';
import 'package:s11/features/wrong_answer/wrong_answer.dart';
import 'package:s11/features/group_study/group_study.dart';
import 'package:s11/features/arena/arena_page.dart';
import 'package:s11/sessions/graph_tools/session/jsx_graph_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/server_chat_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/student_learning_tools_page.dart';
import 'package:s11/sessions/course/ui/course_catalog_page.dart';
import 'package:s11/sessions/friend/friend.dart';
import 'package:s11/sessions/marketplace/ui/pages/marketplace_page.dart';
import 'package:s11/sessions/textbook/ui/pages/docx_box.dart' as docx;
import 'package:s11/features/student_services/student_services_demo_page.dart';
import 'package:s11/features/course_runtime/course_runtime_page.dart';

/// Central route constants and route table for the AIFlow app.
class AppRoutes {
  AppRoutes._();

  // ─── Auth ───
  static const String login = LoginPage.routeName;
  static const String signup = SignupPage.routeName;
  static const String signupLegacy = '/signup/legacy';
  static const String profile = ProfilePage.routeName;
  static const String settingsPage = SettingsPage.routeName;

  // ─── Landing / Shell ───
  static const String landing = '/';
  static const String landingAbout = LandingAboutPage.routeName;
  static const String app = '/app';
  static const String studentDashboard = '/student/dashboard';
  static const String courses = '/courses';
  static const String bookbag = '/bookbag';
  static const String social = '/social';
  static const String marketplace = '/marketplace';
  static const String arena = '/arena';
  static const String learningTools = '/learning-tools';
  static const String graph = '/graph';
  static const String tools = '/tools';

  // ─── Learning ───
  static const String studentRuntime = StudentRuntimePage.routeName;
  static const String courseRuntime = '/course_runtime';

  // ─── Level Test ───
  static const String levelTest = LevelTestHomePage.routeName;
  static const String levelTestResult = '/level_test/result';

  // ─── Schedule ───
  static const String schedule = SchedulePage.routeName;
  static const String scheduleHistory = CurriculumHistoryPage.routeName;

  // ─── Wrong Answers ───
  static const String wrongAnswers = WrongAnswerListPage.routeName;
  static const String wrongAnswerSolve = '/wrong_answer_solve';

  // ─── Group Study ───
  static const String groups = '/groups';
  static const String groupJoin = '/groups/join';
  static const String groupDetail = '/group/detail';
  static const String academyDashboard = '/academy/dashboard';
  static const String academyFind = '/student-services/academy';
  static const String academyProfile = '/student-services/academy/profile';
  static const String privateTutorFind = '/student-services/tutor';
  static const String privateTutorProfile = '/student-services/tutor/profile';
  static const String serviceRequests = '/student-services/requests';
  static const String schoolExamPrep = '/school-exam-prep';
  static const String store = '/store';
}

/// Static [routes] map for [MaterialApp.routes].
///
/// Only routes that do **not** require constructor arguments should be
/// registered here. Argument-bearing pages are handled by
/// [onGenerateAppRoute].
/// 필요한 변수는 현재 JWT 상태와 정적 학생 화면 빌더다.
/// 작동 원리: 모바일 드로어와 PC 상단 메뉴가 같은 명명 라우트를 공유하고, 학생 홈은 생성 시점의 인증 상태를 확인한다.
Map<String, WidgetBuilder> appRoutes() {
  /// 필요한 변수는 현재 API 클라이언트의 JWT 상태다.
  /// 작동 원리: 라우트 생성 시점의 세션을 확인해 로그인·로그아웃 결과를 오래된 시작 플래그 없이 즉시 반영한다.
  WidgetBuilder authedStudentDashboard() {
    return (_) {
      final hasSession = ApiClient.instance.hasAuthenticatedSession;
      return hasSession ? const MainStudentPage() : const LandingPage();
    };
  }

  return {
    // Auth
    AppRoutes.login: (_) => const LoginPage(),
    AppRoutes.signup: (_) => const SignupPage(),
    // 필요한 변수는 과거 회원가입 경로다.
    // 작동 원리: 이전 링크도 정식 SignupPage로 연결해 가입 폼·검증·API가 분기되지 않게 한다.
    AppRoutes.signupLegacy: (_) => const SignupPage(),
    AppRoutes.profile: (_) => const ProfilePage(),
    AppRoutes.settingsPage: (_) => const SettingsPage(),

    // Landing / Shell
    AppRoutes.landing: (_) => const LandingPage(),
    AppRoutes.landingAbout: (_) => const LandingAboutPage(),
    AppRoutes.app: authedStudentDashboard(),
    AppRoutes.studentDashboard: authedStudentDashboard(),
    AppRoutes.courses: (_) => const CourseCatalogPage(),
    AppRoutes.bookbag: (_) => const docx.BookWidget(),
    AppRoutes.social: (_) => const SoWidget(),
    AppRoutes.marketplace: (_) => const MarketplacePage(),
    AppRoutes.arena: (_) => const ArenaPage(),
    // 필요한 변수는 노트·타이머·집중 모드를 여는 도구 허브다.
    // 작동 원리: 학생 내비게이션의 학습 도구는 시안의 모달형 도구 목록으로 연결한다.
    AppRoutes.learningTools: (_) => const StudentLearningToolsPage(),
    // 필요한 변수는 독립적인 함수 그래프 작업 공간이다.
    // 작동 원리: 홈 카드 외에도 전체 메뉴에서 실제 그래프 도구로 도달하게 한다.
    AppRoutes.graph: (_) => const JsxGraphPage(),
    // 필요한 변수는 서버 AI 챗봇과 전체 화면 표시 여부다.
    // 작동 원리: 기존 /tools 딥링크는 AI 학습 튜터로 유지해 기존 공유 링크와 문제 풀이 동선을 끊지 않는다.
    AppRoutes.tools: (_) => const ServerChatPage(standalone: true),

    // Learning
    AppRoutes.studentRuntime: (_) => const StudentRuntimePage(),
    // 필요한 변수는 레거시 코스 런타임 경로다.
    // 작동 원리: 인자가 없는 과거 경로는 런타임 상태를 가진 CourseLearningPage를 직접 만들 수 없으므로,
    // 실제 학습 진입을 결정하는 코스 목록으로 연결해 개발 중 플레이스홀더를 노출하지 않는다.
    AppRoutes.courseRuntime: (_) => const CourseRuntimePage(),

    // Level Test
    AppRoutes.levelTest: (_) => const LevelTestHomePage(),

    // Schedule
    AppRoutes.schedule: (_) => const SchedulePage(),
    AppRoutes.scheduleHistory: (_) => const CurriculumHistoryPage(),

    // Wrong Answers
    AppRoutes.wrongAnswers: (_) => const WrongAnswerListPage(),

    // Group Study
    AppRoutes.groups: (_) => const GroupListPage(),
    AppRoutes.academyFind: (_) => const StudentServicesDemoPage(),
    AppRoutes.privateTutorFind: (_) =>
        const StudentServicesDemoPage(kind: StudentServiceKind.tutor),
    AppRoutes.serviceRequests: (_) => const StudentServiceRequestsPage(),
    AppRoutes.schoolExamPrep: (_) => const SchoolExamPrepPage(),
    AppRoutes.store: (_) => const StudentStoreDemoPage(),
  };
}

/// [onGenerateRoute] handler for pages that require constructor arguments.
///
/// Falls back to `null` for unknown routes so that [MaterialApp] can show
/// the default [_unknownRoute] builder or the user can handle it upstream.
Route<dynamic>? onGenerateAppRoute(RouteSettings settings) {
  final name = settings.name;
  final uri = name == null ? null : Uri.tryParse(name);

  if (name == AppRoutes.academyProfile ||
      name == AppRoutes.privateTutorProfile) {
    final args = settings.arguments;
    if (args is StudentServiceProvider) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => StudentServiceProfilePage(
          kind: name == AppRoutes.academyProfile
              ? StudentServiceKind.academy
              : StudentServiceKind.tutor,
          provider: args,
        ),
      );
    }
    return _badArgumentsRoute(settings, expected: 'StudentServiceProvider');
  }

  if (uri != null && uri.path == AppRoutes.groupJoin) {
    final code = uri.queryParameters['code'] ?? '';
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => GroupJoinPage(inviteCode: code),
    );
  }

  // Level test result (needs correctCount, totalCount, passed)
  if (name == AppRoutes.levelTestResult) {
    final args = settings.arguments;
    if (args is Map<String, dynamic>) {
      final correctCount = args['correctCount'] as int? ?? 0;
      final totalCount = args['totalCount'] as int? ?? 0;
      final passed = args['passed'] as bool? ?? false;
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => LevelTestResultPage(
          correctCount: correctCount,
          totalCount: totalCount,
          passed: passed,
        ),
      );
    }
    return _badArgumentsRoute(settings, expected: 'Map<String, dynamic>');
  }

  // Legacy wrong-answer solve deep link.
  //
  // Preserve the old path while entering the real review widget. The query
  // source is deliberately narrow because the widget only supports weakness
  // and habit-backed sessions; unknown values use the weakness flow.
  if (uri != null && uri.path == AppRoutes.wrongAnswerSolve) {
    final source = uri.queryParameters['source'] == 'habit'
        ? 'habit'
        : 'weakness';
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => WrongAnswerSolvePage(sourceType: source),
    );
  }

  // Course runtime deep links carry the real course identifier in the query.
  // An identifier is required before starting a learning session; without it
  // the static route above intentionally shows the catalog.
  if (uri != null && uri.path == AppRoutes.courseRuntime) {
    final courseId =
        uri.queryParameters['courseId'] ?? uri.queryParameters['course_id'];
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => CourseRuntimePage(courseId: courseId),
    );
  }

  // Group detail (needs groupId)
  if (name == AppRoutes.groupDetail) {
    final args = settings.arguments;
    if (args is String) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => GroupDetailPage(groupId: args),
      );
    }
    return _badArgumentsRoute(settings, expected: 'String (groupId)');
  }

  // Academy dashboard (needs academyId). Deep links may carry `id` or
  // `academyId` because browser launches cannot populate RouteSettings.args.
  if (name == AppRoutes.academyDashboard ||
      (uri != null && uri.path == AppRoutes.academyDashboard)) {
    final args = settings.arguments;
    final academyId = args is String
        ? args
        : uri?.queryParameters['academyId'] ?? uri?.queryParameters['id'];
    if (academyId != null && academyId.trim().isNotEmpty) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => StudentAcademyPage(academyId: academyId),
      );
    }
    return _badArgumentsRoute(
      settings,
      expected: 'String (academyId) or ?id=...',
    );
  }

  return null;
}

/// Builds a fallback route when arguments are missing or of the wrong type.
Route<dynamic> _badArgumentsRoute(
  RouteSettings settings, {
  required String expected,
}) {
  return MaterialPageRoute(
    settings: settings,
    builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('오류')),
      body: Center(
        child: Text(
          '잘못된 인수입니다.\n'
          '경로: ${settings.name}\n'
          '필요한 인수: $expected',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
