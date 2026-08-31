import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/friend/friend.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';

void main() {
  testWidgets('390 친구 허브는 대화·친구 탭과 실제 요청 관리를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SoWidget(preview: true)));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('mobile-social-messages')),
      findsOneWidget,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('mobile-social-topbar'))),
      const Rect.fromLTWH(0, 0, 390, 64),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('mobile-social-tabs'))),
      const Rect.fromLTWH(0, 64, 390, 52),
    );
    expect(
      tester.getRect(find.byType(MobileStudentBottomAppBar)).top,
      closeTo(778, 2),
    );

    await tester.tap(find.byKey(const ValueKey('mobile-social-tab-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mobile-social-friends')), findsOneWidget);
    expect(find.byTooltip('친구 찾기'), findsOneWidget);
    expect(find.text('친구 추가'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('mobile-friend-requests-open')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mobile-friend-requests-sheet')),
      findsOneWidget,
    );
    expect(find.text('받은 요청 2'), findsOneWidget);
  });

  testWidgets('FriendScreen initialTab 1은 친구 탭을 직접 연다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: FriendScreen(preview: true, initialTab: 1)),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('mobile-social-friends')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-social-messages')), findsNothing);
  });

  testWidgets('모바일 그룹 탭은 구형 중간 행 없이 groups route로 이동한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        routes: {'/groups': (_) => const Scaffold(body: Text('그룹 허브'))},
        home: const SoWidget(preview: true),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('mobile-social-tab-2')));
    await tester.pumpAndSettle();

    expect(find.text('그룹 허브'), findsOneWidget);
    expect(find.text('내 스터디 그룹'), findsNothing);
  });
}
