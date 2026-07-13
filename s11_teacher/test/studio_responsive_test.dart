import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11_teacher/pages/exam_paper_editor_page.dart';
import 'package:s11_teacher/pages/problem_editor_page.dart';
import 'package:s11_teacher/shared/ui/ios26/teacher_full_face_panel.dart';

/// 필요 변수: 390×844 모바일 테스트 화면.
/// 작동 원리: 제작 스튜디오와 풀페이스 패널을 실제 모바일 제약으로 렌더링해
/// 핵심 탭과 액션이 사라지거나 RenderFlex 오버플로우가 발생하지 않는지 확인한다.
void main() {
  Future<void> setMobileSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('문항 제작 스튜디오는 모바일에서 세 작업 탭을 유지한다', (tester) async {
    await setMobileSurface(tester);
    await tester.pumpWidget(
      const MaterialApp(home: ProblemEditorPage(initialTags: ['#함수'])),
    );
    await tester.pump();

    expect(find.text('입력'), findsWidgets);
    expect(find.text('흐름'), findsOneWidget);
    expect(find.text('설정'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('시험지 편집기는 모바일에서 검색·시험지·설정 탭을 유지한다', (tester) async {
    await setMobileSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: ExamPaperEditorPage()));
    await tester.pump();

    expect(find.text('문제 검색'), findsWidgets);
    expect(find.text('시험지'), findsOneWidget);
    expect(find.text('편집 설정'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('풀페이스 패널은 모바일에서 고정 액션을 노출한다', (tester) async {
    await setMobileSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TeacherFullFacePanel(
          eyebrow: 'STUDIO',
          title: '태그 선택',
          description: '설명',
          actions: const [FilledButton(onPressed: null, child: Text('완료'))],
          content: const Center(child: Text('작업 내용')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('태그 선택'), findsOneWidget);
    expect(find.text('작업 내용'), findsOneWidget);
    expect(find.text('완료'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
