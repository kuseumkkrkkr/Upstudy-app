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
  testWidgets('모바일 레벨 테스트는 HTML 진입 구조와 실제 문항 수를 표시한다', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: LevelTestHomePage(initialStats: _stats)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('level-test-entry')), findsOneWidget);
    expect(find.text('현재 학습 위치를 측정하는 기준점 진단입니다.'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('60분'), findsOneWidget);
    expect(find.text('자동'), findsOneWidget);
    expect(find.text('테스트 시작'), findsOneWidget);
  });
}
