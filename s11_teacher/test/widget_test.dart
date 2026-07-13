// This is a basic Flutter widget test.
//
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:s11_teacher/main.dart';
import 'package:s11_teacher/pages/problem_editor_page.dart';

void main() {
  testWidgets('Teacher app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TeacherApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Problem editor renders advanced canvas controls', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: ProblemEditorPage(initialTags: ['#함수'])),
    );
    await tester.pump();

    expect(find.text('문항 제작 스튜디오'), findsOneWidget);
    expect(find.byTooltip('설명서'), findsOneWidget);

    await tester.tap(find.byTooltip('설명서'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('문제 생성 설명서'), findsOneWidget);
    expect(find.text('시작하기 (3)'), findsOneWidget);
    expect(find.text('고급 문제 생성 개요'), findsWidgets);

    await tester.tap(find.byTooltip('설명서 닫기'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('고급'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('풀이 논리 캔버스'), findsOneWidget);
    expect(find.text('고급 설정'), findsOneWidget);
    expect(find.text('고급 생성 설정'), findsNothing);
    expect(find.text('파라미터'), findsOneWidget);
    expect(find.text('설명서'), findsNothing);
    expect(find.byTooltip('노드 추가'), findsOneWidget);
    expect(find.byTooltip('화면 옮기기'), findsOneWidget);
    expect(find.byTooltip('노드 편집 및 이동'), findsOneWidget);
    expect(find.byTooltip('노드 연결'), findsOneWidget);
    expect(find.byTooltip('노드 연결 해제'), findsOneWidget);
    expect(find.byTooltip('캔버스 전체화면'), findsOneWidget);
    expect(find.text('문항 생성'), findsOneWidget);
    expect(find.text('선택: 참고문항 없음'), findsOneWidget);
    expect(find.text('시드 체험값'), findsNothing);
    expect(find.text('전체 태그'), findsNothing);

    await tester.tap(find.byTooltip('캔버스 확장'));
    await tester.pump();
    expect(find.text('2200 × 1400'), findsOneWidget);

    await tester.tap(find.byTooltip('노드 연결'));
    await tester.pump();
    await tester.tap(find.text('조건 정리').first);
    await tester.pump();
    await tester.tap(find.text('정답 검증').first);
    await tester.pump();
    expect(find.textContaining('조건 정리 → 정답 검증 연결 완료'), findsOneWidget);

    await tester.tap(find.byTooltip('노드 연결 해제'));
    await tester.pump();
    await tester.tap(find.text('조건 정리').first);
    await tester.pump();
    await tester.tap(find.text('정답 검증').first);
    await tester.pump();
    expect(find.textContaining('조건 정리 → 정답 검증 연결 해제'), findsOneWidget);

    await tester.tap(find.byTooltip('캔버스 전체화면'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('전체화면 닫기'), findsOneWidget);
    await tester.tap(find.byTooltip('전체화면 닫기'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('노드 추가'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('병합'), findsOneWidget);
  });
}
