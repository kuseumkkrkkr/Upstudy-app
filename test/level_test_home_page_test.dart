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
  gradeBands: [
    LevelTestGradeBand(
      grade: '고1',
      sampleSize: 8,
      averageCorrect: 15.4,
      averageOvr: 1320.5,
    ),
  ],
);

void main() {
  testWidgets('모바일 레벨 테스트는 30분 계약과 실제 등급 통계를 안내한다', (tester) async {
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
    expect(find.text('평균 15.4개 · OVR 1320.5'), findsOneWidget);
  });
}
