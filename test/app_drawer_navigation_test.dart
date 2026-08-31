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
  '자료실': '/bookbag',
  '오답 노트': '/wrong_answers',
  '레벨 테스트': '/level_test',
  '대결': '/arena',
  '친구/소셜': '/social',
  '스터디 그룹': '/groups',
  '마켓플레이스': '/marketplace',
  '학습 도구': '/tools',
  '설정': '/settings',
};

const _mobilePrimaryDestinations = <String, String>{
  '홈': '/student/dashboard',
  '코스': '/courses',
  '마켓': '/marketplace',
};

const _mobileMoreDestinations = <String, String>{
  '현재 코스': '/courses',
  '일정': '/schedule',
  '자료실': '/bookbag',
  '레벨 테스트': '/level_test',
};

const _mobileMoreTabs = <String, String>{
  '현재 코스': '학습',
  '일정': '내 메뉴',
  '자료실': '내 메뉴',
  '레벨 테스트': '학습',
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

/// 필요한 변수는 테스트할 명명 라우트와 위젯 재생성용 키다.
/// 작동 원리는 실제 모바일 하단 앱바를 화면 아래에 고정하고 도착 경로만 가벼운 화면으로 대체한다.
Widget _mobileBottomFixture(
  Map<String, WidgetBuilder> routes, {
  required Key key,
}) {
  return MaterialApp(
    key: key,
    routes: routes,
    home: const Scaffold(
      body: SizedBox.expand(),
      bottomNavigationBar: MobileStudentBottomAppBar(),
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
    expect(tester.getSize(find.byType(AppDrawer)).width, 374);
    expect(
      tester.widget<Text>(find.text('오답 노트')).style?.fontSize,
      greaterThanOrEqualTo(17),
    );
  });

  test('전체 메뉴 목적지가 학생 앱 중앙 라우트에 모두 등록돼 있다', () {
    final registeredRoutes = appRoutes();

    expect(registeredRoutes.keys, containsAll(_drawerDestinations.values));
  });

  testWidgets('모바일 하단 고정 탭의 모든 버튼이 등록된 화면으로 이동한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final routes = <String, WidgetBuilder>{
      for (final entry in _mobilePrimaryDestinations.entries)
        entry.value: (_) => Scaffold(body: Text('${entry.value} 도착')),
    };

    for (final entry in _mobilePrimaryDestinations.entries) {
      await tester.pumpWidget(
        _mobileBottomFixture(routes, key: ValueKey('primary-${entry.value}')),
      );
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();

      expect(find.text('${entry.value} 도착'), findsOneWidget);
    }
  });

  testWidgets('모바일 더보기의 모든 기능 행과 내 정보 버튼이 등록된 화면으로 이동한다', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final routes = <String, WidgetBuilder>{
      for (final entry in _mobileMoreDestinations.entries)
        entry.value: (_) => Scaffold(body: Text('${entry.value} 도착')),
      '/profile': (_) => const Scaffold(body: Text('/profile 도착')),
    };

    final mobileEntries = _mobileMoreDestinations.entries.toList();
    for (var entryIndex = 0; entryIndex < mobileEntries.length; entryIndex++) {
      final entry = mobileEntries[entryIndex];
      await tester.pumpWidget(
        _mobileBottomFixture(routes, key: ValueKey('more-${entry.value}')),
      );
      await tester.tap(find.text('더보기'));
      await tester.pumpAndSettle();

      final tab = _mobileMoreTabs[entry.key]!;
      await tester.tap(find.byKey(ValueKey('mobile-more-tab-$tab')));
      await tester.pump();
      if (tab == '내 메뉴' && entryIndex >= 6) {
        await tester.drag(
          find.byKey(const ValueKey('mobile-more-menu-list')),
          const Offset(0, -500),
        );
        await tester.pump();
      }
      final destination = find.byKey(ValueKey('mobile-more-${entry.value}'));
      await tester.ensureVisible(destination);
      await tester.pumpAndSettle();
      await tester.tap(destination);
      await tester.pumpAndSettle();

      expect(find.text('${entry.value} 도착'), findsOneWidget);
    }

    await tester.pumpWidget(
      _mobileBottomFixture(routes, key: const ValueKey('more-profile')),
    );
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mobile-more-tab-내 메뉴')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('mobile-more-/profile')));
    await tester.pumpAndSettle();
    expect(find.text('/profile 도착'), findsOneWidget);
  });

  testWidgets('모바일 더보기는 시안의 세 분류와 메뉴 항목을 표시한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _mobileBottomFixture(const {}, key: const ValueKey('more-search')),
    );
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mobile-more-tab-학습')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-more-tab-도구')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-more-tab-내 메뉴')), findsOneWidget);
    expect(find.text('현재 코스'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mobile-more-tab-도구')));
    await tester.pump();
    expect(find.text('그래프'), findsOneWidget);
    expect(find.text('노트패드'), findsOneWidget);
    expect(find.text('타이머'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mobile-more-tab-내 메뉴')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('AIFlow 학원 찾기'),
      120,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('mobile-more-menu-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('AIFlow 학원 찾기'), findsOneWidget);
    expect(find.text('과외 찾기'), findsOneWidget);
    expect(find.text('스터디 그룹'), findsNothing);
    expect(find.text('학습 이력'), findsNothing);
  });

  testWidgets('모바일 더보기의 시안 전용 기능은 가짜 화면을 열지 않는다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _mobileBottomFixture(const {}, key: const ValueKey('search-math')),
    );
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mobile-more-tab-내 메뉴')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('mobile-more-AIFlow 학원 찾기')),
      120,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('mobile-more-menu-list')),
        matching: find.byType(Scrollable),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('mobile-more-AIFlow 학원 찾기')));
    await tester.pumpAndSettle();
    expect(find.text('AIFlow 학원 찾기 기능은 준비 중입니다.'), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-more-sheet')), findsNothing);
  });

  testWidgets('모바일 탐색은 큰 글꼴·터치 높이와 선택 대비를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(),
          bottomNavigationBar: MobileStudentBottomAppBar(
            activeRoute: '/student/dashboard',
          ),
        ),
      ),
    );

    final selectedLabel = tester.widget<Text>(find.text('홈'));
    final selectedCapsule = tester.widget<AnimatedContainer>(
      find.ancestor(
        of: find.text('홈'),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final selectedDecoration = selectedCapsule.decoration! as BoxDecoration;

    expect(selectedLabel.style?.color, Colors.white);
    expect(selectedLabel.style?.fontSize, greaterThanOrEqualTo(12));
    expect(selectedDecoration.color, const Color(0xFF101012));

    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();

    final moreTitles = tester
        .widgetList<Text>(find.text('더보기'))
        .where((widget) => widget.style?.fontSize == 22);
    final scheduleLabel = tester.widget<Text>(find.text('현재 코스'));

    expect(moreTitles, hasLength(1));
    expect(scheduleLabel.style?.fontSize, greaterThanOrEqualTo(13));
    expect(
      tester.getSize(find.byKey(const ValueKey('mobile-more-/courses'))).height,
      closeTo(56, 1),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('mobile-more-close'))).height,
      closeTo(48, 1),
    );
  });

  testWidgets('모바일 더보기 시트는 하단 탭 위에서 닫힌다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _mobileBottomFixture(const {}, key: const ValueKey('more-geometry')),
    );
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();

    final sheet = tester.getRect(
      find.byKey(const ValueKey('mobile-more-sheet')),
    );
    final nav = tester.getRect(find.byType(MobileStudentBottomAppBar));
    expect(sheet.top, closeTo(456, 2));
    expect(sheet.height, closeTo(320, 2));
    expect(sheet.bottom, closeTo(nav.top, 2));
    expect(find.byKey(const ValueKey('mobile-more-scrim')), findsOneWidget);

    await tester.tapAt(const Offset(8, 250));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mobile-more-sheet')), findsNothing);
  });
}
