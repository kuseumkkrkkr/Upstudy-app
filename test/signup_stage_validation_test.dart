import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/auth/ui/pages/signup_page.dart';

void main() {
  testWidgets('빈 기본 정보로는 회원가입 다음 단계를 열 수 없다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SignupPage()));
    await tester.pump();

    await tester.ensureVisible(find.text('계정 정보 입력하기'));
    await tester.tap(find.text('계정 정보 입력하기'));
    await tester.pumpAndSettle();

    expect(find.text('닉네임'), findsOneWidget);
    expect(find.text('STEP 02 · ACCOUNT'), findsNothing);
    expect(find.text('닉네임을(를) 입력하세요'), findsOneWidget);
    expect(find.text('학교명을(를) 입력하세요'), findsNothing);

    await tester.tap(find.text('계정 정보 입력하기'));
    await tester.pumpAndSettle();
    expect(find.text('닉네임을(를) 입력하세요'), findsOneWidget);
  });

  testWidgets('아이디 형식 안내는 HTML 가입 계정 단계에 표시된다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: SignupPage(initialStage: 1)),
    );
    await tester.pump();

    expect(find.text('영문과 숫자 4–16자'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'student01');
    await tester.pump();
    expect(find.text('영문과 숫자 4–16자'), findsOneWidget);
  });

  testWidgets('유효한 미리보기 정보는 세 단계 이동을 허용한다', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SignupPage(preview: true)));
    await tester.pump();

    await tester.tap(find.text('계정 정보 입력하기'));
    await tester.pumpAndSettle();
    expect(find.text('계정 정보를 입력해 주세요'), findsOneWidget);

    await tester.tap(find.text('입력 정보 확인하기'));
    await tester.pumpAndSettle();
    expect(find.text('입력 정보를 확인해 주세요'), findsOneWidget);
  });

  testWidgets('가입 패널은 HTML 기준 640px 데스크톱·스크롤바 여백 모바일 구조를 사용한다', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SignupPage()));
    await tester.pump();

    final panel = find.byKey(const ValueKey('signup-html-panel'));
    expect(tester.getSize(panel).width, 640);
    expect(tester.getTopLeft(panel).dx, closeTo(312.5, .1));
    expect(tester.getTopLeft(panel).dy, 64);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    expect(tester.getSize(panel).width, 375);
    expect(tester.getTopLeft(panel).dx, 0);
  });
}
