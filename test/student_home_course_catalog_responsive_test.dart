import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/course.dart';
import 'package:s11/sessions/course/ui/course_catalog_page.dart';
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';

/// 필요한 값은 코스 상태가 다른 고정 목록이다.
/// 네트워크 없이 수강 중 직행과 완료 코스 미리보기의 반응형 카드 구조를 재현한다.
List<Course> _courses() {
  return const [
    Course(
      id: 'active',
      title: '일차함수 완성',
      description: '그래프와 기울기를 학습하는 진행 코스',
      level: '중2',
      duration: '3주',
      status: 'in_progress',
      progress: .42,
      lessons: 12,
      targetOvr: 22,
      focusTags: ['함수', '그래프'],
    ),
    Course(
      id: 'complete',
      title: '일차방정식 기초',
      description: '완료한 코스는 상세에서만 미리보기 합니다.',
      level: '중2',
      duration: '2주',
      status: 'completed',
      progress: 1,
      lessons: 8,
      focusTags: ['방정식'],
    ),
  ];
}

/// 필요한 값은 논리 화면 크기와 실제 학생 화면이다.
/// 390·500·1280 폭을 직접 주입해 공용 셸 수정 없이 화면 내부 반응형 키와 주요 문구를 검증한다.
Future<void> _pumpAt(WidgetTester tester, Size size, Widget page) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pump();
}

void main() {
  testWidgets('코스 카탈로그는 1280 PC와 390·500 모바일에서 모든 필터와 상태 카드를 유지한다', (
    tester,
  ) async {
    for (final width in [1280.0, 390.0, 500.0]) {
      await _pumpAt(
        tester,
        Size(width, 900),
        CourseCatalogPage(
          courseFeedLoader: ({required keyword, recommend}) async => _courses(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('코스'), findsWidgets);
      expect(find.text('완료 코스'), findsOneWidget);
      expect(find.text('일차함수 완성'), findsWidgets);
      expect(
        find.byKey(
          ValueKey(
            width < 760 ? 'course-catalog-mobile' : 'course-catalog-desktop',
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('학생 홈은 1280 PC와 390·500 모바일에서 학습 시작 흐름을 유지한다', (tester) async {
    for (final width in [1280.0, 390.0, 500.0]) {
      await _pumpAt(
        tester,
        Size(width, 900),
        const MainStudentPage(username: '김학생'),
      );
      await tester.pump();

      expect(find.textContaining('오늘도 시작해 볼까요?'), findsOneWidget);
      expect(
        find.byKey(
          ValueKey(
            width < 760 ? 'student-home-mobile' : 'student-home-desktop',
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
