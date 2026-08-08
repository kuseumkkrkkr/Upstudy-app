import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/features/level_test/level_test_home_page.dart';

void main() {
  testWidgets('레벨 테스트는 25문항과 60분 제한을 안내한다', (tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LevelTestHomePage()));
    await tester.pumpAndSettle();

    expect(find.text('25문항 · 제한 시간 60분'), findsOneWidget);
    expect(find.textContaining('50문항'), findsNothing);
  });
}
