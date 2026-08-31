import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/auth/ui/pages/signup_page.dart';

void main() {
  testWidgets('가입 화면은 780px 이하에서 단일열, 781px부터 데스크톱 조합을 쓴다', (tester) async {
    for (final width in [720.0, 780.0, 781.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: SignupPage(preview: true)),
      );
      await tester.pumpAndSettle();

      final nameField = find.widgetWithText(TextFormField, '이름');
      final trackField = find.widgetWithText(
        DropdownButtonFormField<String>,
        '중학교',
      );
      final copyTitle = find.text('먼저 학생 정보를\n알려주세요.');
      final nameRect = tester.getRect(nameField);
      final trackRect = tester.getRect(trackField);
      final copyRect = tester.getRect(copyTitle);
      final mobile = width <= 780;

      if (mobile) {
        expect(trackRect.top, greaterThan(nameRect.bottom));
        expect(copyRect.top, greaterThan(nameRect.bottom));
      } else {
        expect(trackRect.top, closeTo(nameRect.top, 0.1));
        expect(trackRect.left, greaterThan(nameRect.left));
        expect(copyRect.left, lessThan(nameRect.left));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('빈 기본 정보로는 회원가입 다음 단계를 열 수 없다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SignupPage()));
    await tester.pump();

    await tester.tap(find.text('계정 정보 입력하기 →'));
    await tester.pumpAndSettle();

    expect(find.text('STEP 01 · PROFILE'), findsOneWidget);
    expect(find.text('STEP 02 · ACCOUNT'), findsNothing);
    expect(find.text('이름을(를) 입력하세요'), findsOneWidget);
    expect(find.text('학년을(를) 입력하세요'), findsOneWidget);
    expect(find.text('학교을(를) 입력하세요'), findsOneWidget);

    await tester.tap(find.text('03  최종 확인'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 01 · PROFILE'), findsOneWidget);
  });

  testWidgets('아이디 형식 안내는 실제 유효한 값에만 표시된다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: SignupPage(initialStage: 1)),
    );
    await tester.pump();

    expect(find.text('사용 가능한 형식입니다.'), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, '아이디'), 'abc');
    await tester.pump();
    expect(find.text('사용 가능한 형식입니다.'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, '아이디'),
      'student01',
    );
    await tester.pump();
    expect(find.text('사용 가능한 형식입니다.'), findsOneWidget);
  });

  testWidgets('유효한 미리보기 정보는 세 단계 이동을 허용한다', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SignupPage(preview: true)));
    await tester.pump();

    await tester.tap(find.text('02  계정 만들기'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 02 · ACCOUNT'), findsOneWidget);

    await tester.tap(find.text('03  최종 확인'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 03 · CONFIRM'), findsOneWidget);
  });
}
