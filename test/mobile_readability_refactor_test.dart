import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/settings/ui/pages/settings_page.dart';

/// 필요한 변수는 모바일 설정 화면과 390px 세로 뷰포트다.
/// 작동 원리: 축약 문구·프로필 링크·무테 카드가 함께 렌더링되는지 확인한다.
void main() {
  testWidgets('모바일 설정은 짧은 문구와 무테 설정 카드를 사용한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: SettingsPage(preview: true)),
    );
    await tester.pump();

    expect(find.text('학습 화면을 내 방식에 맞게 조정하세요.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-mobile-profile-link')),
      findsOneWidget,
    );
    final panel = tester.widget<Container>(
      find.byKey(const ValueKey('settings-mobile-panel-01')),
    );
    final decoration = panel.decoration! as BoxDecoration;
    expect(decoration.border, isNull);
    expect(find.text('교재를 페이지처럼 볼 수 있어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
