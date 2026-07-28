import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/marketplace/ui/pages/marketplace_page.dart';

void main() {
  testWidgets('마켓 세 코너가 실제 목록을 필터링한다', (tester) async {
    // 필요 변수는 세 종류의 고정 마켓 목록이다.
    // 작동 원리는 네트워크 없이 코너 카드 선택과 로컬 필터 결과를 검증한다.
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MarketplacePage(
          initialData: [
            {
              'id': 'exam-1',
              'kind': 'exam',
              'title': '공통수학 기초 진단 A',
              'item_count': 10,
              'price_points': 0,
            },
            {
              'id': 'set-1',
              'kind': 'problem_set',
              'title': '다항식 기본기 5',
              'item_count': 5,
              'price_points': 120,
            },
            {
              'id': 'course-1',
              'kind': 'course',
              'title': '공통수학 기초 완성',
              'item_count': 20,
              'price_points': 900,
            },
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('market-mobile-body')), findsOneWidget);
    expect(find.byKey(const ValueKey('market-mobile-grid')), findsOneWidget);
    expect(find.text('코스 · 시험지 검색'), findsOneWidget);
    expect(find.text('공통수학 기초 진단 A'), findsOneWidget);
    expect(find.text('다항식 기본기 5'), findsOneWidget);
    expect(find.text('공통수학 기초 완성'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('market-corner-시험지')));
    await tester.pump();
    expect(find.text('공통수학 기초 진단 A'), findsOneWidget);
    expect(find.text('다항식 기본기 5'), findsNothing);
    expect(find.text('공통수학 기초 완성'), findsNothing);
  });
}
