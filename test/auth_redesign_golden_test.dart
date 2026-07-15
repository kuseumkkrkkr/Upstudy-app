import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/auth/ui/pages/login_page.dart';
import 'package:s11/sessions/auth/ui/pages/sign_up.dart';
import 'package:s11/sessions/landing/ui/pages/landing_page.dart';

/// 필요한 변수는 테스트 화면 크기와 표시할 인증 화면입니다.
/// 작동 원리는 실제 MaterialApp을 지정 크기로 렌더링해 반응형 분기와 픽셀 결과를 함께 검증하는 것입니다.
Future<void> _pumpAuthPage(
  WidgetTester tester, {
  required Size size,
  required Widget page,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Arial'),
      home: RepaintBoundary(key: const Key('auth-golden'), child: page),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('실제 초기 랜딩 데스크톱 시안 이미지', (tester) async {
    await _pumpAuthPage(
      tester,
      size: const Size(1440, 1000),
      page: const LandingPage(),
    );

    expect(
      find.byKey(const Key('auth-golden')),
      matchesGoldenFile('goldens/auth_landing_desktop.png'),
    );
  });

  testWidgets('랜딩 로그인 모달 시안 이미지', (tester) async {
    await _pumpAuthPage(
      tester,
      size: const Size(1024, 900),
      page: const LandingPage(),
    );
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
    expect(find.text('학습을 이어가세요.'), findsOneWidget);

    expect(
      find.byType(Dialog),
      matchesGoldenFile('goldens/auth_landing_login_dialog.png'),
    );
  });

  testWidgets('랜딩 회원가입 버튼은 정식 가입 화면을 연다', (tester) async {
    await _pumpAuthPage(
      tester,
      size: const Size(390, 844),
      page: const LandingPage(),
    );
    await tester.ensureVisible(find.text('새 계정 만들기'));
    await tester.pump();
    await tester.tap(find.text('새 계정 만들기'));
    await tester.pumpAndSettle();

    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
  });

  testWidgets('로그인 데스크톱 시안 이미지', (tester) async {
    await _pumpAuthPage(
      tester,
      size: const Size(1440, 1000),
      page: const LoginPage(
        initialUsername: 'student01',
        initialPassword: 'password123',
      ),
    );

    expect(
      find.byKey(const Key('auth-golden')),
      matchesGoldenFile('goldens/auth_login_desktop.png'),
    );
  });

  testWidgets('회원가입 모바일 시안 이미지', (tester) async {
    await _pumpAuthPage(
      tester,
      size: const Size(390, 844),
      page: const BuildpageWidget(),
    );

    expect(
      find.byKey(const Key('auth-golden')),
      matchesGoldenFile('goldens/auth_signup_mobile.png'),
    );
  });
}
