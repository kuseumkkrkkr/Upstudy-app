import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/features/group_study/group_join_page.dart';
import 'package:s11/features/student_runtime/models.dart';
import 'package:s11/features/student_runtime/student_runtime_page.dart';
import 'package:s11/features/student_schedule/curriculum_history_page.dart';
import 'package:s11/features/wrong_answer/wrong_answer_solve_page.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ApiClient.instance.setHttpClientForTest(
      MockClient((request) async {
        if (request.url.path == '/social/study-groups/invite/ABC123') {
          return http.Response(
            jsonEncode(<String, Object>{
              'group_id': 'group-1',
              'name': '중등 수학 챌린지',
              'description': '매일 한 문제씩 함께 풀어요',
              'max_members': 12,
              'members': 3,
              'lock_enabled': false,
              'invite_code': 'ABC123',
            }),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{}', 200);
      }),
    );
  });

  tearDown(() async {
    ApiClient.instance.setHttpClientForTest(http.Client());
    await ApiClient.instance.clearToken();
  });

  testWidgets('커리큘럼 이력은 모바일 공용 셸과 명명 홈 이동을 쓴다', (tester) async {
    _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(_withRoutes(const CurriculumHistoryPage()));
    await tester.pump();

    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const ValueKey('student-mobile-menu')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('curriculum-history-filter-실패')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('curriculum-history-filter-실패')),
    );
    await tester.pump();
    expect(find.text('영어 독해 연습 (3지문)'), findsOneWidget);

    final onTitleTap = tester
        .widget<Ios26TopBar>(find.byType(Ios26TopBar).first)
        .onTitleTap;
    expect(onTitleTap, isNotNull);
    onTitleTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('route:/student/dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('그룹 초대 직접 경로는 PC 공용 내비게이션과 실제 뒤로가기를 쓴다', (tester) async {
    _setViewport(tester, const Size(1280, 900));
    await ApiClient.instance.setToken('secondary-route-shell-token');
    await tester.pumpWidget(
      _withRoutes(const GroupJoinPage(inviteCode: 'ABC123')),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const ValueKey('student-top-nav-친구/소셜')), findsOneWidget);
    expect(find.text('중등 수학 챌린지'), findsOneWidget);
    expect(find.byTooltip('뒤로가기'), findsOneWidget);
    expect(find.byTooltip('검색'), findsOneWidget);

    final onBack = tester
        .widget<Ios26TopBar>(find.byType(Ios26TopBar).first)
        .onBack;
    expect(onBack, isNotNull);
    onBack!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('route:/groups'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('그룹 초대 직접 경로는 390px에서도 공용 모바일 셸을 유지한다', (tester) async {
    _setViewport(tester, const Size(390, 844));
    await ApiClient.instance.setToken('secondary-route-shell-token');
    await tester.pumpWidget(
      _withRoutes(const GroupJoinPage(inviteCode: 'ABC123')),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const ValueKey('student-mobile-menu')), findsOneWidget);
    expect(find.byTooltip('뒤로가기'), findsOneWidget);
    expect(find.text('중등 수학 챌린지'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('오답 재풀이 직접 경로는 모바일 셸과 오답 노트 복귀를 유지한다', (tester) async {
    _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      _withRoutes(const WrongAnswerSolvePage(sourceType: 'review')),
    );
    await tester.pump();

    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const ValueKey('student-mobile-menu')), findsOneWidget);
    expect(find.byTooltip('뒤로가기'), findsOneWidget);
    expect(find.text('오답 노트로 돌아가기'), findsOneWidget);

    final onBack = tester
        .widget<Ios26TopBar>(find.byType(Ios26TopBar).first)
        .onBack;
    expect(onBack, isNotNull);
    onBack!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('route:/wrong_answers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('학생 런타임은 PC 공용 코스 내비게이션과 명명 홈 이동을 쓴다', (tester) async {
    _setViewport(tester, const Size(1280, 900));
    await tester.pumpWidget(
      _withRoutes(
        StudentRuntimePage(
          initialCourses: [
            RuntimeCourseModel(
              id: 1,
              title: '개념 완성 코스',
              overallProgress: 25,
              modules: [
                RuntimeModuleModel(
                  id: 1,
                  moduleType: RuntimeModuleType.problemSolve,
                  title: '함수 개념',
                  status: 'available',
                  progressPercent: 25,
                  configJson: '{}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const ValueKey('student-top-nav-코스')), findsOneWidget);
    expect(find.byTooltip('검색'), findsOneWidget);
    expect(find.text('개념 완성 코스'), findsOneWidget);

    final onTitleTap = tester
        .widget<Ios26TopBar>(find.byType(Ios26TopBar).first)
        .onTitleTap;
    expect(onTitleTap, isNotNull);
    onTitleTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('route:/student/dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _withRoutes(Widget child) => MaterialApp(
  initialRoute: '/',
  routes: {
    '/': (_) => child,
    '/student/dashboard': (_) => const _RouteProbe('/student/dashboard'),
    '/groups': (_) => const _RouteProbe('/groups'),
    '/wrong_answers': (_) => const _RouteProbe('/wrong_answers'),
  },
);

class _RouteProbe extends StatelessWidget {
  const _RouteProbe(this.route);

  final String route;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('route:$route')));
}
