import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/features/arena/arena_page.dart';
import 'package:s11/features/group_study/group_list_page.dart';
import 'package:s11/features/student_schedule/schedule_page.dart';
import 'package:s11/sessions/course/ui/course_catalog_page.dart';
import 'package:s11/sessions/friend/friend.dart';
import 'package:s11/sessions/graph_tools/session/jsx_graph_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/student_learning_tools_page.dart';
import 'package:s11/sessions/marketplace/ui/pages/marketplace_page.dart';
import 'package:s11/sessions/settings/ui/pages/settings_page.dart';
import 'package:s11/sessions/textbook/ui/pages/docx_box.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';

class _NamedRouteProbe extends StatelessWidget {
  const _NamedRouteProbe({required this.route});

  final String route;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text('route:$route'));
}

/// 필요한 변수는 페이지와 홈의 명명 라우트다.
/// 작동 원리는 공용 AIFlow 브랜드 CTA가 위젯을 직접 만들지 않고,
/// 드로어의 활성 목적지 판별에 쓸 수 있는 학생 홈 명명 라우트로 돌아가는지 확인한다.
Future<void> _expectTitleToOpenNamedHome(
  WidgetTester tester,
  Widget page,
  String testId,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey('named-home-$testId'),
      initialRoute: '/',
      routes: {
        '/': (_) => page,
        '/student/dashboard': (_) =>
            const _NamedRouteProbe(route: '/student/dashboard'),
      },
    ),
  );
  await tester.pump();

  final headers = find.byType(Ios26TopBar);
  expect(headers, findsAtLeastNWidgets(1));
  final onTitleTap = tester.widget<Ios26TopBar>(headers.first).onTitleTap;
  expect(onTitleTap, isNotNull);
  onTitleTap!();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  expect(find.text('route:/student/dashboard'), findsOneWidget);
}

void main() {
  testWidgets('공용 AIFlow 브랜드 버튼은 전달된 홈 동작을 호출한다', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Ios26TopBar(
            brandColor: Colors.black,
            onTitleTap: () => calls += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('student-brand-home')));
    expect(calls, 1);
  });

  testWidgets('학생 상위 화면의 브랜드 CTA는 명명된 학생 홈으로 돌아간다', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _expectTitleToOpenNamedHome(
      tester,
      GroupListPage(initialGroups: const <Object>[]),
      'group-list',
    );
    await _expectTitleToOpenNamedHome(
      tester,
      const SchedulePage(initialSchedule: <Map<String, dynamic>>[]),
      'schedule',
    );
    await _expectTitleToOpenNamedHome(
      tester,
      const SoWidget(preview: true),
      'social',
    );
    await _expectTitleToOpenNamedHome(
      tester,
      const MarketplacePage(initialData: <Map<String, dynamic>>[]),
      'market',
    );
    await _expectTitleToOpenNamedHome(
      tester,
      const BookWidget(previewMode: true),
      'bookbag',
    );
  });

  testWidgets('공용·도구·계정 셸도 같은 명명 홈 계약을 사용한다', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _expectTitleToOpenNamedHome(
      tester,
      const CourseCatalogPage(),
      'courses',
    );
    await _expectTitleToOpenNamedHome(
      tester,
      const ArenaPage(initialSummary: <String, dynamic>{}),
      'arena',
    );
    await _expectTitleToOpenNamedHome(
      tester,
      const StudentLearningToolsPage(),
      'tools',
    );
    await _expectTitleToOpenNamedHome(
      tester,
      const JsxGraphPage(embedEnabled: false),
      'graph',
    );
    await _expectTitleToOpenNamedHome(
      tester,
      const SettingsPage(preview: true),
      'settings',
    );
  });
}
