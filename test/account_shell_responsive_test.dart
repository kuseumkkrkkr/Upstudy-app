import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/sessions/auth/ui/pages/profile_page.dart';
import 'package:s11/sessions/settings/ui/pages/settings_page.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';

final _profile = UserProfile(
  userId: 'account-shell-student',
  username: 'student01',
  name: '김학생',
  grade: '2학년',
  track: '중학교',
  subject: '수학',
  school: 'AIFlow 중학교',
);

void _setViewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('프로필은 390·760·780px에서 같은 상단바와 오버레이 드로어를 사용한다', (tester) async {
    for (final width in [390.0, 760.0, 780.0]) {
      _setViewport(tester, width);
      await tester.pumpWidget(
        MaterialApp(
          home: ProfilePage(
            initialProfile: _profile,
            initialTextbookPageMode: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Ios26TopBar), findsOneWidget);
      expect(find.byKey(const ValueKey('student-mobile-menu')), findsOneWidget);
      expect(
        tester.state<ScaffoldState>(find.byType(Scaffold).first).hasDrawer,
        isTrue,
      );
      expect(find.byType(MobileStudentBottomAppBar), findsNothing);
      expect(find.text('MY ACCOUNT'), findsOneWidget);
      expect(find.text('LEARNING PROFILE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('프로필 모바일 메뉴는 실제 Drawer를 연다', (tester) async {
    _setViewport(tester, 390);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          initialProfile: _profile,
          initialTextbookPageMode: false,
        ),
      ),
    );
    await tester.pump();

    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
    expect(scaffold.hasDrawer, isTrue);
    expect(scaffold.isDrawerOpen, isFalse);
    await tester.tap(find.byKey(const ValueKey('student-mobile-menu')));
    await tester.pumpAndSettle();
    expect(scaffold.isDrawerOpen, isTrue);
  });

  testWidgets('설정은 390·760·780px에서 계층형 설정 패널을 유지한다', (tester) async {
    for (final width in [390.0, 760.0, 780.0]) {
      _setViewport(tester, width);
      await tester.pumpWidget(
        const MaterialApp(home: SettingsPage(preview: true)),
      );
      await tester.pump();

      expect(find.byType(Ios26TopBar), findsOneWidget);
      expect(find.byKey(const ValueKey('student-mobile-menu')), findsOneWidget);
      expect(
        tester.state<ScaffoldState>(find.byType(Scaffold).first).hasDrawer,
        isTrue,
      );
      expect(find.byType(MobileStudentBottomAppBar), findsNothing);
      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('LOCAL PREFERENCES'), findsOneWidget);
      for (final panel in ['01', '02', '03', '04']) {
        expect(
          find.byKey(ValueKey('settings-mobile-panel-$panel')),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('계정 화면은 1280px에서 글래스 상단바와 기존 PC 구성을 보존한다', (tester) async {
    _setViewport(tester, 1280);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          initialProfile: _profile,
          initialTextbookPageMode: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Ios26TopBar), findsOneWidget);
    expect(
      tester.state<ScaffoldState>(find.byType(Scaffold).first).hasDrawer,
      isTrue,
    );
    expect(find.byType(MobileStudentBottomAppBar), findsNothing);
    expect(find.text('MY ACCOUNT'), findsOneWidget);
    expect(find.text('STUDENT PROFILE'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(home: SettingsPage(preview: true)),
    );
    await tester.pump();

    expect(find.byType(Ios26TopBar), findsOneWidget);
    expect(
      tester.state<ScaffoldState>(find.byType(Scaffold).first).hasDrawer,
      isTrue,
    );
    expect(find.byType(MobileStudentBottomAppBar), findsNothing);
    expect(find.text('PREFERENCES'), findsOneWidget);
    expect(find.text('LOCAL PREFERENCES'), findsOneWidget);
    expect(find.text('변경 내용은\n바로 적용돼요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('프로필의 설정 버튼은 실제 설정 페이지로 이동한다', (tester) async {
    _setViewport(tester, 390);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          initialProfile: _profile,
          initialTextbookPageMode: false,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('profile-mobile-settings')),
        matching: find.byType(OutlinedButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
  });
}
