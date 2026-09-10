import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:s11/app/router.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpTutorial(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: AppRoutes.landingAbout,
        routes: appRoutes(),
        onGenerateRoute: onGenerateAppRoute,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('HTML 튜토리얼은 모바일에서 5단계와 진행 동작을 제공한다', (tester) async {
    await pumpTutorial(tester, const Size(390, 844));

    expect(find.text('튜토리얼'), findsOneWidget);
    expect(find.text('오늘 학습 시작하기'), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-step-home')), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-next')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tutorial-practice-home')));
    await tester.pump();
    expect(find.text('확인했어요. 다음 단계로 이동하세요.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tutorial-next')));
    await tester.pump();
    expect(find.text('코스에서 단원 고르기'), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-previous')), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('HTML 튜토리얼은 데스크톱에서 단계 레일과 완료 버튼을 제공한다', (tester) async {
    await pumpTutorial(tester, const Size(1280, 900));

    expect(find.byKey(const ValueKey('tutorial-step-home')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tutorial-step-tutor')));
    await tester.pump();
    expect(find.text('막히면 AI 튜터에게 묻기'), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-finish')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });
}
