import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/sessions/student_dashboard/ui/widgets/activity_badges.dart';

/// 필요한 변수는 논리 화면 크기와 업적 보관함을 여는 버튼이다.
/// 작동 원리: 실제 모바일·PC 크기를 주입한 뒤 공개 진입 함수를 호출해 반응형
/// 표시 방식과 모바일 트로피 열 수를 네트워크 없이 검증한다.
Future<void> _pumpLauncher(WidgetTester tester, Size size) async {
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
                snapshot: ActivitySnapshot.empty(),
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
  testWidgets('390 세로 화면은 전폭 업적 시트와 4열 트로피를 사용한다', (tester) async {
    await _pumpLauncher(tester, const Size(390, 844));

    await tester.tap(find.text('업적 열기'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('activity-badge-mobile-sheet')),
      findsOneWidget,
    );
    expect(find.text('업적 보관함'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    final solveGrid = tester.widget<GridView>(
      find.byKey(const ValueKey('activity-badge-mobile-grid-solve')),
    );
    final delegate =
        solveGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 4);
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
    expect(tester.takeException(), isNull);
  });
}
