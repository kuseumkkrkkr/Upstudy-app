import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/settings/ui/pages/settings_page.dart';

/// 필요한 변수는 모바일 설정 화면과 390px 세로 뷰포트다.
/// 작동 원리: 상단바·프로필 행동·계층형 설정 카드가 함께 렌더링되는지 확인한다.
void main() {
  testWidgets('모바일 설정은 기준 시안의 계층형 설정 카드를 사용한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: SettingsPage(preview: true)),
    );
    await tester.pump();

    expect(find.text('PREFERENCES'), findsOneWidget);
    expect(find.text('LOCAL PREFERENCES'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-mobile-profile-link')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-mobile-flat-list')),
      findsNothing,
    );
    for (final panel in ['01', '02', '03', '04']) {
      expect(
        find.byKey(ValueKey('settings-mobile-panel-$panel')),
        findsOneWidget,
      );
    }
    expect(find.text('PDF형 페이지 보기'), findsOneWidget);
    expect(find.text('모바일 간편풀이'), findsOneWidget);
    expect(find.text('모든 알림'), findsOneWidget);
    expect(find.text('라이선스 보기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
