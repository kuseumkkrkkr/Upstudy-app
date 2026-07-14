import 'package:flutter/material.dart';

import 'package:s11/sessions/auth/ui/pages/login_page.dart';
import 'package:s11/sessions/auth/ui/pages/profile_page.dart';
import 'package:s11/sessions/auth/ui/pages/signup_page.dart';
import 'package:s11/sessions/auth/ui/pages/sign_up.dart';
import 'package:s11/sessions/landing/ui/pages/landing_about_page.dart';
import 'package:s11/sessions/landing/ui/pages/landing_page.dart';
import 'package:s11/sessions/settings/ui/pages/settings_page.dart';
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';

import 'package:s11/features/student_runtime/student_runtime.dart';
import 'package:s11/features/level_test/level_test.dart';
import 'package:s11/features/student_schedule/student_schedule.dart';
import 'package:s11/features/wrong_answer/wrong_answer.dart';
import 'package:s11/features/group_study/group_study.dart';
import 'package:s11/features/course_runtime/course_runtime_page.dart';
import 'package:s11/features/flow_access/flow_access_page.dart';

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

  // ─── Learning ───
  static const String studentRuntime = StudentRuntimePage.routeName;
  static const String courseRuntime = CourseRuntimePage.routeName;
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
    AppRoutes.signupLegacy: (_) => const BuildpageWidget(),
    AppRoutes.profile: (_) => const ProfilePage(),
    AppRoutes.settingsPage: (_) => const SettingsPage(),

    // Landing / Shell
    AppRoutes.landing: (_) => const LandingPage(),
    AppRoutes.landingAbout: (_) => const LandingAboutPage(),
    AppRoutes.app: authedStudentDashboard(),
    AppRoutes.studentDashboard: authedStudentDashboard(),

    // Learning
    AppRoutes.studentRuntime: (_) => const StudentRuntimePage(),
    AppRoutes.courseRuntime: (_) => const CourseRuntimePage(),
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
