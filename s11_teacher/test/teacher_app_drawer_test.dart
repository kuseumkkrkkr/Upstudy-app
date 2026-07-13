import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11_teacher/widgets/teacher_app_drawer.dart';

/// 필요 변수: 390×600 테스트 화면과 프로필/설정 콜백이 있는 교사용 Drawer.
/// 작동 원리: 작은 높이에서 렌더링 예외가 없는지 확인하고 목록 끝까지 스크롤한다.
void main() {
  testWidgets('낮은 화면에서 교사용 메뉴가 오버플로우 없이 스크롤된다', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherAppDrawer(onOpenProfile: () {}, onOpenSettings: () {}),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.text('로그아웃'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
