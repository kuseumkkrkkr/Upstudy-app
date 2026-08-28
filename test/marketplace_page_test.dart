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
    expect(find.text('코스 · 시험지 · 문제세트 검색'), findsOneWidget);
    expect(find.text('공통수학 기초 진단 A'), findsOneWidget);
    expect(find.text('다항식 기본기 5'), findsOneWidget);
    expect(find.text('공통수학 기초 완성'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('market-corner-시험지')));
    await tester.pump();
    expect(find.text('공통수학 기초 진단 A'), findsOneWidget);
    expect(find.text('다항식 기본기 5'), findsNothing);
    expect(find.text('공통수학 기초 완성'), findsNothing);
  });

  testWidgets('720px 이하 세로 화면은 간결한 무료 코스 목록과 단계 미리보기를 쓴다', (tester) async {
    // 필요 변수는 612px 세로 화면과 무료 코스다.
    // 작동 원리는 기존 태블릿 코너가 숨겨지고 단일 열 카드와 오류 없는 단계 미리보기가 나타나는지 검증한다.
    tester.view.physicalSize = const Size(612, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MarketplacePage(
          initialData: [
            {
              'id': 'course-free',
              'kind': 'course',
              'title': '난이도 3 · 유형 훈련 코스',
              'description': '단계별 실전 코스',
              'grade_band': '고1-2',
              'difficulty': '난이도 3',
              'item_count': 10,
              'price_points': 0,
            },
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('마켓플레이스'), findsOneWidget);
    expect(find.text('MARKET CORNERS'), findsNothing);
    expect(find.text('난이도 3 · 유형 훈련 코스'), findsOneWidget);
    expect(find.text('무료'), findsOneWidget);

    await tester.tap(find.text('난이도 3 · 유형 훈련 코스'));
    await tester.pumpAndSettle();
    expect(find.text('핵심 개념 확인'), findsOneWidget);
    expect(find.text('유형 문제 훈련'), findsOneWidget);
    expect(find.text('코스에 포함된 문제를 불러오지 못했습니다.'), findsNothing);
    expect(find.text('무료로 내 학습에 담기'), findsOneWidget);
  });

  testWidgets('내 학습 담기 성공 안내는 바로가기 동작을 제공한다', (tester) async {
    String? purchasedId;
    String? openedId;
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MarketplacePage(
          initialData: const [
            {
              'id': 'exam-shortcut',
              'kind': 'exam',
              'title': '미적분 | 실전모의 B',
              'item_count': 10,
              'price_points': 0,
              'asset_id': 'exam-shortcut',
            },
          ],
          purchaseHandler: (listingId) async => purchasedId = listingId,
          openHandler: (listingId) => openedId = listingId,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('미적분 | 실전모의 B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('무료로 내 학습에 담기'));
    await tester.pumpAndSettle();

    expect(purchasedId, 'exam-shortcut');
    expect(find.text('내 학습 자료에 담았습니다.'), findsOneWidget);
    expect(find.text('바로가기'), findsOneWidget);

    await tester.tap(find.text('바로가기'));
    await tester.pump();
    expect(openedId, 'exam-shortcut');
  });
}
