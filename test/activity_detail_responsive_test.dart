import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
import 'package:s11/sessions/student_dashboard/ui/widgets/activity_badges.dart';

void _setViewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, width <= 780 ? 844 : 900);
  tester.view.devicePixelRatio = 1;
}

Widget _badgeLauncher(double width) => MaterialApp(
  key: ValueKey('activity-badge-launcher-$width'),
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
);

Widget _historyLauncher(double width) => MaterialApp(
  key: ValueKey('activity-history-launcher-$width'),
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: FilledButton(
          onPressed: () => showActivityHistoryDetail(context),
          child: const Text('전체 일정 열기'),
        ),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ActivityStore.notifier.value = ActivitySnapshot.empty();
    ActivityStore.accountSummaryNotifier.value = null;
  });

  testWidgets('활동 배지 상세는 780px까지 바텀시트를 쓰고 PC 다이얼로그를 보존한다', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in const [390.0, 720.0, 780.0, 1280.0]) {
      _setViewport(tester, width);
      await tester.pumpWidget(_badgeLauncher(width));
      await tester.tap(find.text('업적 열기'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('activity-badge-mobile-sheet')),
        width <= 780 ? findsOneWidget : findsNothing,
      );
      expect(find.byType(Dialog), width <= 780 ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('홈 활동 이력 상세는 780px까지 바텀시트를 쓰고 PC 다이얼로그를 보존한다', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in const [390.0, 720.0, 780.0, 1280.0]) {
      _setViewport(tester, width);
      await tester.pumpWidget(_historyLauncher(width));
      await tester.tap(find.text('전체 일정 열기'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('activity-history-mobile-sheet')),
        width <= 780 ? findsOneWidget : findsNothing,
      );
      expect(find.byType(Dialog), width <= 780 ? findsNothing : findsOneWidget);
      if (width > 780) {
        final size = tester.getSize(
          find.byKey(const ValueKey('activity-history-desktop-dialog')),
        );
        expect(size.width, lessThanOrEqualTo(560));
        expect(size.height, lessThanOrEqualTo(620));
      }
      expect(find.text('매일 출석'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
