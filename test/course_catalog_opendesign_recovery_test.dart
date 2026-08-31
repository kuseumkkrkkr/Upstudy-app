import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/course/ui/course_catalog_page.dart';
import 'package:s11/shared/data/models/course.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';

List<Course> _openDesignCourses() => const [
  Course(
    id: 'calculus',
    title: '미적분 핵심 완성',
    description: '도함수와 조건 해석',
    level: '4단원',
    duration: '도함수',
    progress: .68,
    status: 'in_progress',
    lastAction: '4단원 · 도함수 · 조건 해석 보완',
  ),
  Course(
    id: 'probability',
    title: '확률과 통계 개념',
    description: '조건부확률',
    level: '2단원',
    duration: '조건부확률',
    progress: .34,
    status: 'in_progress',
    lastAction: '2단원 · 조건부확률 · 표본공간 복습',
  ),
  Course(
    id: 'geometry',
    title: '기하 벡터 입문',
    description: '벡터의 연산',
    level: '1단원',
    duration: '벡터의 연산',
    progress: .18,
    status: 'in_progress',
    lastAction: '1단원 · 벡터의 연산 · 내적 전 개념',
  ),
];

Future<void> _pump(WidgetTester tester, {required double width}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: CourseCatalogPage(
        courseFeedLoader: ({required keyword, recommend}) async =>
            _openDesignCourses(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('OpenDesign 나의 코스 구조를 390 모바일에서 유지한다', (tester) async {
    await _pump(tester, width: 390);

    expect(find.text('나의 코스'), findsOneWidget);
    expect(find.text('학습 중'), findsOneWidget);
    expect(find.text('코스 관리'), findsOneWidget);
    expect(find.text('미적분 핵심 완성'), findsOneWidget);
    expect(find.text('확률과 통계 개념'), findsOneWidget);
    expect(find.text('기하 벡터 입문'), findsOneWidget);
    expect(find.byType(MobileStudentBottomAppBar), findsOneWidget);
    expect(find.text('이어서 학습'), findsNothing);
    expect(find.textContaining('OVR'), findsNothing);
    expect(
      find.byKey(const ValueKey('course-mobile-group-active')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('course-mobile-group-manage')),
      findsOneWidget,
    );
    final discoverAction = find.text('새 코스 찾기');
    await tester.ensureVisible(discoverAction);
    await tester.tap(discoverAction);
    await tester.pumpAndSettle();
    final discovery = find.byKey(
      const ValueKey('course-mobile-discovery-sheet'),
    );
    expect(discovery, findsOneWidget);
    final discoveryRect = tester.getRect(discovery);
    expect(discoveryRect.width, closeTo(390, 1));
    expect(discoveryRect.height, closeTo(412, 1));
    expect(
      find.byKey(const ValueKey('course-mobile-discovery-cta')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('OpenDesign 나의 코스 구조를 1280 데스크톱에서 유지한다', (tester) async {
    await _pump(tester, width: 1280);

    expect(find.byKey(const ValueKey('course-desktop-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('course-desktop-rail')), findsOneWidget);
    expect(find.text('나의 코스'), findsOneWidget);
    expect(find.text('학습 중'), findsOneWidget);
    expect(find.text('코스 관리'), findsOneWidget);
    expect(find.text('새 코스 찾기'), findsOneWidget);
    expect(find.text('코스 진행 분석'), findsOneWidget);
    expect(find.text('미적분 핵심 완성'), findsOneWidget);
    expect(find.text('확률과 통계 개념'), findsOneWidget);
    expect(find.text('기하 벡터 입문'), findsOneWidget);
    expect(find.byType(MobileStudentBottomAppBar), findsNothing);
    expect(find.text('이어서 학습'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
