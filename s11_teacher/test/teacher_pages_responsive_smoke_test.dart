import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11_teacher/pages/course_list_page.dart';
import 'package:s11_teacher/pages/exam_paper_builder_page.dart';
import 'package:s11_teacher/pages/group_study/academy_dashboard_page.dart';
import 'package:s11_teacher/pages/group_study/group_list_page.dart';
import 'package:s11_teacher/pages/teacher_chat_page.dart';
import 'package:s11_teacher/pages/teacher_dashboard_page.dart';
import 'package:s11_teacher/pages/teacher_document_center_page.dart';
import 'package:s11_teacher/pages/teacher_login_page.dart';
import 'package:s11_teacher/pages/teacher_operations_page.dart';
import 'package:s11_teacher/pages/teacher_register_page.dart';
import 'package:s11_teacher/pages/teacher_social_page.dart';
import 'package:s11_teacher/pages/teacher_store_page.dart';
import 'package:s11_teacher/pages/textbook_builder_page.dart';

/// 필요 변수: 390×844 모바일 화면과 독립 교사용 페이지 목록.
/// 작동 원리: API가 연결되지 않은 초기 상태에서도 각 페이지를 모바일 제약으로
/// 렌더링해 재구성된 카드와 조작부에 오버플로우가 없는지 확인한다.
void main() {
  final pages = <String, Widget>{
    '로그인': const TeacherLoginPage(),
    '회원가입': const TeacherRegisterPage(),
    '운영 관리': const TeacherOperationsPage(),
    '스토어': const TeacherStorePage(),
    '친구·채팅': const TeacherSocialPage(),
    '대화': const TeacherChatPage(peerUsername: 'test_teacher'),
    '교사용 홈': const TeacherDashboardPage(),
    '코스 목록': const CourseListPage(),
    '빠른 시험지': const ExamPaperBuilderPage(),
    '교재 작성': const TextbookBuilderPage(),
    '문서함': const TeacherDocumentCenterPage(),
    '그룹 관리': const GroupListPage(),
    '학원 운영': const AcademyDashboardPage(academyId: '', groupId: ''),
  };

  for (final entry in pages.entries) {
    testWidgets('${entry.key} 페이지는 모바일 폭에서 오버플로우 없이 열린다', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(MaterialApp(home: entry.value));
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
    });
  }
}
