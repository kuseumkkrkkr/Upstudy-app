import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/app/router.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';

/// 필요한 변수는 드로어에 노출하는 메뉴 이름과 명명 라우트다.
/// 작동 원리: 실제 전체 메뉴의 각 항목을 같은 순서로 순회해 누락·오타 난 라우트를 한 번에 검증한다.
const _drawerDestinations = <String, String>{
  '홈': '/student/dashboard',
  '일정': '/schedule',
  '코스': '/courses',
  '책가방': '/bookbag',
  '오답 노트': '/wrong_answers',
  '레벨 테스트': '/level_test',
  '대결': '/arena',
  '친구/소셜': '/social',
  '스터디 그룹': '/groups',
  '마켓플레이스': '/marketplace',
  '학습 도구': '/tools',
  '설정': '/settings',
};

/// 필요한 변수는 테스트할 메뉴 항목의 목적지다.
/// 작동 원리: 실제 화면 대신 도착 경로를 표시하는 가벼운 화면을 사용해 메뉴 탭의 명명 라우트 전달만 독립 검증한다.
Widget _drawerFixture(Map<String, WidgetBuilder> routes, {required Key key}) {
  return MaterialApp(
    key: key,
    routes: routes,
    home: Scaffold(
      drawer: const AppDrawer(),
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => Scaffold.of(context).openDrawer(),
          child: const Text('메뉴 열기'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('전체 메뉴의 모든 항목이 등록된 화면으로 이동한다', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final routes = <String, WidgetBuilder>{
      for (final entry in _drawerDestinations.entries)
        entry.value: (_) => Scaffold(body: Text('${entry.value} 도착')),
    };

    for (final entry in _drawerDestinations.entries) {
      await tester.pumpWidget(
        _drawerFixture(routes, key: ValueKey(entry.value)),
      );
      await tester.tap(find.text('메뉴 열기'));
      await tester.pumpAndSettle();

      final menu = find.text(entry.key);
      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();

      expect(find.text('${entry.value} 도착'), findsOneWidget);
    }
  });

  testWidgets('전체 메뉴는 부모의 Scaffold 바깥 문맥이 전달돼도 열린다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (outerContext) => Scaffold(
            drawer: const AppDrawer(),
            body: Ios26TopBar(
              brandColor: StudentDensityTokens.dark,
              showLevelIndicator: false,
              showUtilityActions: false,
              onMenu: () => toggleAppDrawer(outerContext),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('student-mobile-menu')));
    await tester.pumpAndSettle();

    expect(find.byType(AppDrawer), findsOneWidget);
    expect(find.text('오답 노트'), findsOneWidget);
  });

  test('전체 메뉴 목적지가 학생 앱 중앙 라우트에 모두 등록돼 있다', () {
    final registeredRoutes = appRoutes();

    expect(registeredRoutes.keys, containsAll(_drawerDestinations.values));
  });
}
