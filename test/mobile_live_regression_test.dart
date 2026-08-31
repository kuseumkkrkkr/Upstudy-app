import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/sessions/auth/ui/pages/profile_page.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/owned_marketplace_modal.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';

final _profile = UserProfile(
  userId: 'student-1',
  username: 'mobile_student',
  name: '모바일 학생',
  grade: '고1',
  track: '고등학교',
  subject: '수학',
  school: 'AIFlow고',
);

/// 필요한 변수는 390×844 모바일 테스트 화면이다.
/// 작동 원리: 각 테스트가 동일한 DPR과 실제 앱형 세로 크기를 사용하고 종료 시 원래 뷰포트로 복원한다.
void _setMobileView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// 필요한 변수는 900px PC 테스트 화면이다.
/// 작동 원리: 모바일 전용 분기가 넓은 화면의 기존 AppBar와 목록을 바꾸지 않는지 독립 검증한다.
void _setDesktopView(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    ApiClient.instance.setHttpClientForTest(http.Client());
    await ApiClient.instance.clearToken();
  });

  testWidgets('프로필은 모바일 하단 앱 셸을 사용하고 햄버거를 숨긴다', (tester) async {
    _setMobileView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          initialProfile: _profile,
          initialTextbookPageMode: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(MobileStudentBottomAppBar), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
    expect(find.byKey(const ValueKey('student-mobile-menu')), findsNothing);
    expect(find.text('프로필'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('프로필 조회 실패도 모바일 앱 셸과 재시도 동작을 유지한다', (tester) async {
    // 필요한 변수는 HTML 응답 파싱 실패를 반환하는 프로필 로더다.
    // 작동 원리는 원시 예외를 숨기고 큰 오류 카드·하단 탐색·재시도 버튼을 제공하는지 확인한다.
    _setMobileView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          loadProfile: () async =>
              throw const FormatException('Unexpected token <'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MobileStudentBottomAppBar), findsOneWidget);
    expect(find.text('프로필을 열지 못했어요'), findsOneWidget);
    expect(find.textContaining('프로필을 불러오지 못했어요.'), findsOneWidget);
    expect(find.textContaining('Unexpected token'), findsNothing);
    expect(
      find.byKey(const ValueKey('profile-mobile-retry-button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('계정 삭제 확인창은 빈 비밀번호에서 닫히지 않는다', (tester) async {
    _setMobileView(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          initialProfile: _profile,
          initialTextbookPageMode: false,
          showDeleteDialogOnStart: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '계정 삭제'));
    await tester.pump();

    expect(find.text('현재 비밀번호를 입력해 주세요.'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('보유 자료 선택은 모바일 앱형 큰 헤더와 빈 상태 행동을 표시한다', (tester) async {
    _setMobileView(tester);
    await ApiClient.instance.setToken('mobile-owned-items-token');
    ApiClient.instance.setHttpClientForTest(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': {'items': <Object>[]},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/marketplace': (_) => const Scaffold(body: Text('마켓플레이스 도착')),
        },
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showOwnedMarketplaceModal(
                context: context,
                kind: 'problem_set',
              ),
              child: const Text('문제세트 열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('문제세트 열기'));
    await tester.pumpAndSettle();

    expect(find.text('문제세트 학습'), findsOneWidget);
    expect(find.text('보유한 문제세트가 없어요'), findsOneWidget);
    expect(find.text('마켓 둘러보기'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('보유 자료 선택의 PC AppBar와 기존 빈 상태는 유지한다', (tester) async {
    _setDesktopView(tester);
    await ApiClient.instance.setToken('desktop-owned-items-token');
    ApiClient.instance.setHttpClientForTest(
      MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': {'items': <Object>[]},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showOwnedMarketplaceModal(context: context, kind: 'exam'),
              child: const Text('시험지 열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('시험지 열기'));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('시험지 학습하기'), findsOneWidget);
    expect(find.text('보유한 시험지가 없습니다.\n마켓에서 먼저 담아주세요.'), findsOneWidget);
    expect(find.text('시험지 학습'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
