import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/ui/drawer/student_navigation.dart';

void main() {
  testWidgets(
    'primary material tab opens bookbag; more library opens marketplace',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final destinations = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            destinations.add(settings.name!);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(
                bottomNavigationBar: MobileStudentBottomAppBar(),
              ),
            );
          },
        ),
      );
      await tester.tap(find.text('자료실'));
      await tester.pumpAndSettle();
      expect(destinations.last, '/bookbag');
      await tester.tap(find.text('더보기'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('더보기 닫기'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mobile-more-sheet')), findsNothing);
      await tester.tap(find.text('더보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('더보기 닫기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mobile-more-sheet')), findsNothing);
      await tester.tap(find.text('더보기'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('mobile-more-/marketplace')),
        findsOneWidget,
      );
      final learningHeight = tester
          .getSize(find.byKey(const ValueKey('mobile-more-sheet')))
          .height;
      final grid = tester.widget<GridView>(
        find.byKey(const ValueKey('mobile-more-menu-list')),
      );
      expect(grid.shrinkWrap, isTrue);
      await tester.tap(find.byKey(const ValueKey('mobile-more-tab-도구')));
      await tester.pumpAndSettle();
      expect(find.text('AI 튜터'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mobile-more-tab-내 메뉴')));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('mobile-more-sheet'))).height,
        lessThan(learningHeight),
      );
      expect(find.text('친구·그룹'), findsNothing);
      expect(find.text('프로필'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mobile-more-tab-학습')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mobile-more-/marketplace')));
      await tester.pumpAndSettle();
      expect(destinations.last, '/marketplace');
      expect(tester.takeException(), isNull);
    },
  );
}
