import 'package:flutter/material.dart';
import 'shared/theme/teacher_theme.dart';
import 'pages/auth_wrapper.dart';
import 'pages/teacher_login_page.dart';
import 'pages/teacher_register_page.dart';
import 'pages/teacher_dashboard_page.dart';
import 'pages/course_builder_page.dart';
import 'pages/course_list_page.dart';
import 'pages/exam_paper_builder_page.dart';
import 'pages/problem_editor_page.dart';
import 'pages/teacher_social_page.dart';
import 'pages/teacher_store_page.dart';
import 'pages/textbook_builder_page.dart';
import 'pages/group_study/group_study.dart';
import 'pages/teacher_document_center_page.dart';
import 'pages/teacher_operations_page.dart';

void main() {
  runApp(const TeacherApp());
}

class TeacherApp extends StatelessWidget {
  const TeacherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AIFlow 선생님',
      theme: buildTeacherTheme(),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const TeacherLoginPage(),
        '/register': (context) => const TeacherRegisterPage(),
        '/dashboard': (context) => const TeacherDashboardPage(),
        '/course-builder': (context) => const CourseBuilderPage(),
        CourseListPage.routeName: (context) => const CourseListPage(),
        '/exam-builder': (context) => const ExamPaperBuilderPage(),
        '/problem-editor': (context) => const ProblemEditorPage(),
        TeacherSocialPage.routeName: (context) => const TeacherSocialPage(),
        TeacherStorePage.routeName: (context) => const TeacherStorePage(),
        '/textbook-builder': (context) => const TextbookBuilderPage(),
        TeacherDocumentCenterPage.routeName: (context) =>
            const TeacherDocumentCenterPage(),
        TeacherOperationsPage.routeName: (context) =>
            const TeacherOperationsPage(),
        GroupListPage.routeName: (context) => const GroupListPage(),
        AcademyDashboardPage.routeName: (context) =>
            const AcademyDashboardPage(academyId: '', groupId: ''),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/group/detail') {
          final args = settings.arguments;
          if (args is Map<String, dynamic>) {
            final groupName = args['groupName']?.toString() ?? '';
            final groupId = args['groupId']?.toString() ?? '';
            final academyId = args['academyId']?.toString() ?? '';
            return MaterialPageRoute(
              builder: (_) => GroupDetailPage(
                groupId: groupId,
                groupName: groupName,
                academyId: academyId,
              ),
            );
          }
        }
        return null;
      },
    );
  }
}
