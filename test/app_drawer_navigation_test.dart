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

const _mobilePrimaryDestinations = <String, String>{
  '홈': '/student/dashboard',
  '코스': '/courses',
  '마켓': '/marketplace',
};

const _mobileMoreDestinations = <String, String>{
  '일정': '/schedule',
  '책가방': '/bookbag',
  '오답 노트': '/wrong_answers',
  '레벨 테스트': '/level_test',
  '대결': '/arena',
  '친구/소셜': '/social',
  '스터디 그룹': '/groups',
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

    for (final entry in _mobileMoreDestinations.entries) {
      await tester.pumpWidget(
        _mobileBottomFixture(routes, key: ValueKey('more-${entry.value}')),
      );
      await tester.tap(find.text('더보기'));
      await tester.pumpAndSettle();

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
    await tester.tap(find.byKey(const ValueKey('mobile-more-profile')));
    await tester.pumpAndSettle();
    expect(find.text('/profile 도착'), findsOneWidget);
  });

  testWidgets('모바일 더보기의 검색과 알림 버튼이 전용 패널을 연다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _mobileBottomFixture(const {}, key: const ValueKey('more-search')),
    );
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mobile-more-search')));
    await tester.pump();
    expect(find.text('전체 검색'), findsOneWidget);

    await tester.pumpWidget(
      _mobileBottomFixture(const {}, key: const ValueKey('more-notifications')),
    );
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mobile-more-notifications')));
    await tester.pump();
    expect(find.text('알림 센터'), findsOneWidget);
  });

  testWidgets('내 정보 저장 후 로그인 화면이 아닌 학생 홈으로 돌아간다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/student/dashboard',
        routes: {
          '/': (_) => const Scaffold(body: Text('로그인 화면')),
          '/student/dashboard': (_) => const Scaffold(
            body: Text('학생 홈'),
            bottomNavigationBar: MobileStudentBottomAppBar(),
          ),
          '/profile': (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('저장하기'),
            ),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mobile-more-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장하기'));
    await tester.pumpAndSettle();

    expect(find.text('학생 홈'), findsOneWidget);
    expect(find.text('로그인 화면'), findsNothing);
  });

  testWidgets('모바일 전체 검색은 수학 키워드를 실제 학습 화면과 연결한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _mobileBottomFixture(const {}, key: const ValueKey('search-math')),
    );
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mobile-more-search')));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '수학');
    await tester.pump();

    expect(find.text('코스'), findsAtLeastNWidgets(1));
    expect(find.text('AI 학습 튜터'), findsOneWidget);
    expect(find.text('마켓플레이스'), findsOneWidget);
    expect(find.text('연결할 검색 화면이 없습니다.'), findsNothing);
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
        .where((widget) => widget.style?.fontSize == 28);
    final scheduleLabel = tester.widget<Text>(find.text('일정'));
    final searchLabel = tester.widget<Text>(find.text('검색'));

    expect(moreTitles, hasLength(1));
    expect(find.text('학습과 계정 기능을 한곳에서 열어요'), findsNothing);
    expect(find.byKey(const ValueKey('mobile-more-close')), findsNothing);
    expect(scheduleLabel.style?.fontSize, greaterThanOrEqualTo(17));
    expect(searchLabel.style?.fontSize, greaterThanOrEqualTo(15));
    expect(searchLabel.style?.color, Colors.white);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('mobile-more-/schedule')))
          .height,
      greaterThanOrEqualTo(64),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('mobile-more-search'))).height,
      greaterThanOrEqualTo(76),
    );
  });
}
