import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/features/level_test/level_test_result_page.dart';
import 'package:s11/shared/services/api/api_client.dart';

/// 필요한 값은 지정한 논리 화면 폭과 결과 위젯이다.
/// PC·모바일 폭을 직접 주입해 결과 카드가 두 환경 모두에서 렌더링되는지 확인한다.
Future<void> _pumpResult(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: child,
      routes: {
        '/student/dashboard': (_) => const Scaffold(body: Text('학생 홈 도착')),
      },
    ),
  );
  await tester.pumpAndSettle();
}

/// 필요한 값은 배치 API가 반환하는 OVR·태그·신뢰도다.
/// 네트워크 없이 시안형 결과 리포트의 모든 분석 섹션을 고정된 데이터로 검증한다.
const _placement = LevelTestPlacementResult(
  sessionId: 'placement-test',
  rating: 1830,
  ovr: 18.6,
  ovrDelta: .3,
  recentAccuracy: .82,
  loseStreak: 0,
  confidence: .91,
  strongTags: [
    {'tag': '일차함수', 'rating': 19.2},
  ],
  weakTags: [
    {'tag': '기하', 'rating': 16.4},
  ],
);

void main() {
  testWidgets('레벨 테스트 배치 결과는 1280 PC에서 분석 카드와 OVR을 표시한다', (tester) async {
    await _pumpResult(
      tester,
      const Size(1280, 900),
      const LevelTestResultPage(placementResult: _placement),
    );

    expect(find.text('18.6'), findsOneWidget);
    expect(find.text('OVR 배정 결과'), findsOneWidget);
    expect(find.text('21 / 25'), findsWidgets);
    expect(find.text('30분'), findsWidgets);
    expect(find.text('강점 태그'), findsNothing);
    expect(find.byKey(const ValueKey('level-result-overview')), findsOneWidget);
    expect(find.byKey(const ValueKey('level-result-analysis')), findsOneWidget);
  });

  testWidgets('레벨 테스트 배치 결과는 390과 500 모바일 폭에서 다음 행동을 유지한다', (tester) async {
    for (final width in [390.0, 500.0]) {
      await _pumpResult(
        tester,
        Size(width, 1000),
        const LevelTestResultPage(placementResult: _placement),
      );

      expect(find.text('나의 학습 기준점이\n완성됐어요.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('level-result-next-button')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('레벨 결과는 780px 이하에서 모바일 단일 열을, 781px부터 PC 2열을 유지한다', (
    tester,
  ) async {
    for (final width in [760.0, 780.0, 781.0, 1280.0]) {
      await _pumpResult(
        tester,
        Size(width, 1000),
        const LevelTestResultPage(placementResult: _placement),
      );

      final overview = tester.getRect(
        find.byKey(const ValueKey('level-result-overview')),
      );
      final analysis = tester.getRect(
        find.byKey(const ValueKey('level-result-analysis')),
      );
      final mobile = width <= 780;

      if (mobile) {
        expect(find.text('홈'), findsWidgets);
        expect(find.text('학습 홈으로'), findsNothing);
        expect(analysis.left, closeTo(overview.left, 0.1));
        expect(analysis.top, greaterThan(overview.bottom));
      } else {
        expect(find.text('홈'), findsNothing);
        expect(find.text('학습 홈으로'), findsOneWidget);
        expect(analysis.top, closeTo(overview.top, 0.1));
        expect(analysis.left, greaterThan(overview.left));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('일반 결과도 기존 정답 수와 통과 상태를 시안형 리포트에 보존한다', (tester) async {
    await _pumpResult(
      tester,
      const Size(500, 1000),
      const LevelTestResultPage(correctCount: 8, totalCount: 10, passed: true),
    );

    expect(find.text('80%'), findsOneWidget);
    expect(find.text('8 / 10 문항 정답'), findsOneWidget);
    expect(find.text('PASS'), findsOneWidget);
  });

  testWidgets('결과 홈 버튼은 최초 랜딩이 아니라 학생 홈으로 이동한다', (tester) async {
    await _pumpResult(
      tester,
      const Size(390, 844),
      const LevelTestResultPage(placementResult: _placement),
    );

    await tester.tap(find.byKey(const ValueKey('level-result-home-button')));
    await tester.pumpAndSettle();

    expect(find.text('학생 홈 도착'), findsOneWidget);
  });
}
