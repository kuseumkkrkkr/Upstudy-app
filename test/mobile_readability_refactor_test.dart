import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/settings/ui/pages/settings_page.dart';

/// 필요한 변수는 모바일 설정 화면과 390px 세로 뷰포트다.
/// 작동 원리: HTML 기준 직각 설정 패널과 다섯 개 설정 행이 렌더링되는지 확인한다.
void main() {
  testWidgets('모바일 설정은 HTML 직각 패널과 설정 행을 사용한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: SettingsPage(preview: true)),
    );
    await tester.pump();

    expect(find.text('PREFERENCES'), findsNothing);
    expect(find.text('학습 화면을 내 방식에 맞게 조정하세요.'), findsNothing);
    final panel = tester.widget<Container>(
      find.byKey(const ValueKey('html-settings-panel')),
    );
    final decoration = panel.decoration! as BoxDecoration;
    expect(decoration.border, isNotNull);
    expect(find.text('교재 페이지'), findsOneWidget);
    expect(find.text('모바일 간편풀이'), findsOneWidget);
    expect(find.text('전체 알림'), findsOneWidget);
    expect(find.text('오픈소스 라이선스'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
