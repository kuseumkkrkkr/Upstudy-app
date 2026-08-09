import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/features/level_test/level_test_home_page.dart';
import 'package:s11/shared/services/api/api_client.dart';

const _stats = LevelTestPlacementStats(
  questionCount: 25,
  difficultyBands: [
    LevelTestDifficultyBand(tier: 2, label: '기초', questionCount: 5),
    LevelTestDifficultyBand(tier: 3, label: '기본', questionCount: 10),
    LevelTestDifficultyBand(tier: 4, label: '응용', questionCount: 7),
    LevelTestDifficultyBand(tier: 5, label: '심화', questionCount: 3),
  ],
  estimatedBands: [
    LevelTestEstimatedBand(
      grade: '1등급',
      ovrMin: 1607,
      ovrMax: 2200,
      expectedCorrect: 22.6,
    ),
  ],
);

void main() {
  testWidgets('모바일 레벨 테스트는 30분 계약과 0명에서도 추정 그래프를 안내한다', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: LevelTestHomePage(initialStats: _stats)),
    );
    await tester.pumpAndSettle();

    expect(find.text('30분 · 자유 이동 · 마지막에 한 번 채점'), findsOneWidget);
    expect(find.text('진행 방식'), findsNothing);
    expect(find.text('기초 5'), findsOneWidget);
    expect(find.text('심화 3'), findsOneWidget);
    expect(find.text('등급대별 추정 결과'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('level-test-estimated-ovr-line-chart')),
      findsOneWidget,
    );
  });
}
