import 'package:flutter/material.dart';

import 'package:s11/sessions/auth/ui/pages/login_page.dart';
import 'package:s11/sessions/auth/ui/pages/profile_page.dart';
import 'package:s11/sessions/auth/ui/pages/signup_page.dart';
import 'package:s11/sessions/landing/ui/pages/landing_about_page.dart';
import 'package:s11/sessions/landing/ui/pages/landing_page.dart';
import 'package:s11/sessions/settings/ui/pages/settings_page.dart';
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';

import 'package:s11/features/student_runtime/student_runtime.dart';
import 'package:s11/features/level_test/level_test.dart';
import 'package:s11/features/student_schedule/student_schedule.dart';
import 'package:s11/features/wrong_answer/wrong_answer.dart';
import 'package:s11/features/group_study/group_study.dart';
import 'package:s11/features/flow_access/flow_access_page.dart';
import 'package:s11/features/arena/arena_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/student_learning_tools_page.dart';
import 'package:s11/sessions/course/ui/course_catalog_page.dart';
import 'package:s11/sessions/friend/friend.dart';
import 'package:s11/sessions/legacy_cleanup/session/study_center.dart'
    as study_center;
import 'package:s11/sessions/marketplace/ui/pages/marketplace_page.dart';
import 'package:s11/sessions/textbook/ui/pages/docx_box.dart' as docx;

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
  static const String studyCenter = '/study-center';
  static const String courses = '/courses';
  static const String bookbag = '/bookbag';
  static const String social = '/social';
  static const String marketplace = '/marketplace';
  static const String arena = '/arena';
  static const String tools = '/tools';

  // ─── Learning ───
  static const String studentRuntime = StudentRuntimePage.routeName;
  static const String courseRuntime = '/course_runtime';
  static const String flowAccess = FlowAccessPage.routeName;

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
}

/// Static [routes] map for [MaterialApp.routes].
///
/// Only routes that do **not** require constructor arguments should be
/// registered here. Argument-bearing pages are handled by
/// [onGenerateAppRoute].
/// 필요한 변수는 인증 여부이며, 작동 원리는 모바일 드로어와 PC 상단 메뉴가 같은 명명 라우트를 공유하는 것이다.
Map<String, WidgetBuilder> appRoutes(
  BuildContext context, {
  required bool isAuthenticated,
}) {
  WidgetBuilder authedStudentDashboard() {
    return (_) =>
        isAuthenticated ? const MainStudentPage() : const LandingPage();
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
    AppRoutes.studyCenter: (_) => const study_center.SoWidget(),
    AppRoutes.courses: (_) => const CourseCatalogPage(),
    AppRoutes.bookbag: (_) => const docx.BookWidget(),
    AppRoutes.social: (_) => const SoWidget(),
    AppRoutes.marketplace: (_) => const MarketplacePage(),
    AppRoutes.arena: (_) => const ArenaPage(),
    AppRoutes.tools: (_) => const StudentLearningToolsPage(),

    // Learning
    AppRoutes.studentRuntime: (_) => const StudentRuntimePage(),
    // 필요한 변수는 레거시 코스 런타임 경로다.
    // 작동 원리: 인자가 없는 과거 경로는 런타임 상태를 가진 CourseLearningPage를 직접 만들 수 없으므로,
    // 실제 학습 진입을 결정하는 코스 목록으로 연결해 개발 중 플레이스홀더를 노출하지 않는다.
    AppRoutes.courseRuntime: (_) => const CourseCatalogPage(),
    AppRoutes.flowAccess: (_) => const FlowAccessPage(),

    // Level Test
    AppRoutes.levelTest: (_) => const LevelTestHomePage(),

    // Schedule
    AppRoutes.schedule: (_) => const SchedulePage(),
    AppRoutes.scheduleHistory: (_) => const CurriculumHistoryPage(),

    // Wrong Answers
    AppRoutes.wrongAnswers: (_) => const WrongAnswerListPage(),

    // Group Study
    AppRoutes.groups: (_) => const GroupListPage(),
  };
}

/// [onGenerateRoute] handler for pages that require constructor arguments.
///
/// Falls back to `null` for unknown routes so that [MaterialApp] can show
/// the default [_unknownRoute] builder or the user can handle it upstream.
Route<dynamic>? onGenerateAppRoute(RouteSettings settings) {
  final name = settings.name;
  final uri = name == null ? null : Uri.tryParse(name);

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

  // Wrong answer solve (needs sourceType)
  if (name == AppRoutes.wrongAnswerSolve) {
    final args = settings.arguments;
    if (args is String) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => WrongAnswerSolvePage(sourceType: args),
      );
    }
    return _badArgumentsRoute(settings, expected: 'String (sourceType)');
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

  // Academy dashboard (needs academyId)
  if (name == AppRoutes.academyDashboard) {
    final args = settings.arguments;
    if (args is String) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => StudentAcademyPage(academyId: args),
      );
    }
    return _badArgumentsRoute(settings, expected: 'String (academyId)');
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
