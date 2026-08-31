import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/sessions/student_dashboard/ui/widgets/activity_badges.dart';

/// 필요한 변수는 논리 화면 크기와 업적 보관함을 여는 버튼이다.
/// 작동 원리: 실제 모바일·PC 크기를 주입한 뒤 공개 진입 함수를 호출해 반응형
/// 표시 방식과 12단계 카드 상호작용을 네트워크 없이 검증한다.
Future<void> _pumpLauncher(
  WidgetTester tester,
  Size size, {
  ActivitySnapshot? snapshot,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showActivityBadgeDialog(
                context: context,
                snapshot: snapshot ?? ActivitySnapshot.empty(),
              ),
              child: const Text('업적 열기'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('390 세로 화면은 최고 트로피 중심 세로 카드와 12단계 상세를 사용한다', (tester) async {
    await _pumpLauncher(tester, const Size(390, 844));

    await tester.tap(find.text('업적 열기'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('activity-badge-mobile-sheet')),
      findsOneWidget,
    );
    expect(find.text('업적 보관함'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    expect(
      find.byKey(const ValueKey('activity-badge-mobile-grid-solve')),
      findsNothing,
    );
    expect(find.textContaining('12개 중 아직 해금 전'), findsWidgets);

    final solveCard = find.byKey(
      const ValueKey('activity-badge-mobile-group-solve'),
    );
    await tester.tap(solveCard);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: solveCard, matching: find.text('해금 단계 0 / 12')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: solveCard,
        matching: find.byKey(const ValueKey('activity-badge-stage-solve-12')),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('해금된 최고 트로피와 12개 중 현재 순서를 표시한다', (tester) async {
    const snapshot = ActivitySnapshot(
      days: <String, ActivityDayRecord>{},
      totalSolvedCount: 20,
      totalIncorrectCount: 0,
      lastDateKey: '',
    );
    await _pumpLauncher(tester, const Size(390, 844), snapshot: snapshot);

    await tester.tap(find.text('업적 열기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('12개 중 4번째까지 해금'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('activity-badge-mobile-group-solve')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('해금 단계 4 / 12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('넓은 화면은 기존 중앙 업적 다이얼로그를 유지한다', (tester) async {
    await _pumpLauncher(tester, const Size(1280, 900));

    await tester.tap(find.text('업적 열기'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(
      find.byKey(const ValueKey('activity-badge-mobile-sheet')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('activity-badge-desktop-group-solve')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
