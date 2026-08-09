import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';

Map<String, dynamic> _quest(int index) => {
  'header': {'quest_id': 'placement-$index'},
  'data': {
    'quest_title': '$index + 1의 값을 입력하세요.',
    'quest_options': <dynamic>[],
    'quest_answer': '${index + 1}',
  },
  'solves': [
    {'flow': '레벨 테스트에서는 보이면 안 되는 Flow'},
  ],
};

void main() {
  testWidgets('레벨 테스트는 Flow 없이 빈 답 이동 후 마지막에 일괄 제출한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    List<PlacementExamAnswer>? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: BuildpageWidget(
          config: ProblemSolveConfig(
            questionCount: 25,
            timeLimitSeconds: 30 * 60,
            placementExam: true,
            gradeImmediately: false,
            passRate: 0,
            quests: List.generate(25, (index) => _quest(index + 1)),
            onPlacementSubmit:
                ({
                  required List<PlacementExamAnswer> answers,
                  required int elapsedSeconds,
                }) {
                  submitted = answers;
                },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('placement-exam-screen')), findsOneWidget);
    expect(find.text('30:00'), findsOneWidget);
    expect(find.textContaining('보이면 안 되는 Flow'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('placement-next')));
    await tester.pump();
    expect(find.text('2번'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('placement-answer-2')),
      '3',
    );

    await tester.tap(find.byKey(const ValueKey('placement-question-grid')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('placement-question-25')));
    await tester.pumpAndSettle();
    expect(find.text('25번'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('placement-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('빈 답 24개'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('placement-confirm-submit')));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted, hasLength(25));
    expect(submitted!.first.questId, 'placement-1');
    expect(submitted!.first.userAnswer, isNull);
    expect(submitted![1].userAnswer, '3');
    expect(tester.takeException(), isNull);
  });
}
