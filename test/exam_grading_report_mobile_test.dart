import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/exam_paper/session/exam_paper_page.dart';

const _results = <ExamGradeResult>[];

Widget _report({List<ExamGradeResult> results = _results}) => MaterialApp(
  home: ExamGradingReportPage(
    results: results,
    totalQuestions: 5,
    passRate: 60,
    passed: true,
    moduleSubmissionRequired: false,
    moduleSubmissionSucceeded: true,
    examId: 'exam-mobile-01',
  ),
);

List<ExamGradeResult> _sampleResults() => [
  ExamGradeResult.success(
    1,
    analysis: '정답입니다.',
    warnings: const [],
    isCorrect: true,
  ),
  ExamGradeResult.success(
    2,
    analysis: '오답입니다.',
    warnings: const [],
    isCorrect: false,
  ),
  ExamGradeResult.success(
    3,
    analysis: '정답입니다.',
    warnings: const [],
    isCorrect: true,
  ),
  ExamGradeResult.empty(4),
  ExamGradeResult.failure(5, '채점 실패'),
];

void main() {
  testWidgets('세로형 휴대전화는 모바일 시험 결과 UI를 사용한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_report(results: _sampleResults()));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('exam-result-portrait-mobile')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('exam-result-mobile-score'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('exam-result-mobile-footer')),
      findsOneWidget,
    );
    expect(find.text('40', skipOffstage: false), findsOneWidget);
    await expectLater(
      find.byKey(const ValueKey('exam-result-portrait-mobile')),
      matchesGoldenFile('goldens/exam_grading_report_portrait_mobile.png'),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pump();
    expect(find.text('정답 2 / 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('가로형 휴대전화는 기존 시험 결과 UI를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_report());
    await tester.pump();

    expect(
      find.byKey(const ValueKey('exam-result-portrait-mobile')),
      findsNothing,
    );
    expect(find.text('시험을 통과했어요.'), findsOneWidget);
  });

  testWidgets('세로형 태블릿은 모바일 전용 리디자인을 적용하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(700, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_report());
    await tester.pump();

    expect(
      find.byKey(const ValueKey('exam-result-portrait-mobile')),
      findsNothing,
    );
    expect(find.text('시험을 통과했어요.'), findsOneWidget);
  });
}
