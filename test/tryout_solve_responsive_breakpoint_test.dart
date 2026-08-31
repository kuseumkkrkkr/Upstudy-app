import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';

Widget _solveFixture() {
  return MaterialApp(
    home: BuildpageWidget(
      config: const ProblemSolveConfig(
        ratingEnabled: false,
        quests: [
          {
            'header': {'quest_id': 'solve-responsive-boundary'},
            'data': {
              'quest_title': '두 점을 지나는 일차함수의 식을 구하세요.',
              'quest_options': ['y = 2x + 1', 'y = x + 2'],
            },
          },
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('문제 풀이는 780px까지 모바일 셸을 유지한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in const [601.0, 720.0, 780.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpWidget(_solveFixture());
      await tester.pump();

      expect(
        find.byKey(const ValueKey('mobile-solve-problem-card')),
        findsOneWidget,
        reason: '$width px is within the shared mobile breakpoint.',
      );
      expect(find.text('문제 풀이'), findsOneWidget);
      expect(find.text('PROBLEM SESSION'), findsNothing);
    }

    tester.view.physicalSize = const Size(781, 1000);
    await tester.pumpWidget(_solveFixture());
    await tester.pump();

    expect(
      find.byKey(const ValueKey('mobile-solve-problem-card')),
      findsNothing,
    );
    expect(find.text('PROBLEM SESSION'), findsOneWidget);
  });
}
