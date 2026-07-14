import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

/// 필요한 변수는 공용 상단 바와 밀도 축소 카드에 표시할 고정 검증 데이터다.
/// 네트워크 상태와 무관한 동일 화면을 만들어 해상도별 반응형 결과를 비교한다.
Widget _responsiveFixture() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: StudentDensityTokens.background,
      body: SafeArea(
        child: Column(
          children: [
            Ios26TopBar(
              brandColor: StudentDensityTokens.dark,
              showLevelIndicator: false,
              onMenu: () {},
              items: const [
                Ios26NavItem(label: '학습터', active: true),
                Ios26NavItem(label: '책가방'),
                Ios26NavItem(label: '친구/소셜'),
                Ios26NavItem(label: '마켓플레이스'),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                child: StudentDensityPage(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const StudentDensityPageHeader(
                        eyebrow: 'STUDENT HOME',
                        title: '오늘의 학습',
                        description: '현재 코스와 일일 퀘스트를 한눈에 확인합니다.',
                      ),
                      const SizedBox(height: 24),
                      StudentDensitySurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const StudentDensityEyebrow('ACTIVE COURSE'),
                            const SizedBox(height: 10),
                            const Text(
                              '중2 일차함수 집중 코스',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 16),
                            LinearProgressIndicator(
                              value: 0.62,
                              color: StudentDensityTokens.dark,
                              backgroundColor: StudentDensityTokens.line,
                            ),
                            const SizedBox(height: 18),
                            StudentDensityButton(
                              label: '이어서 학습',
                              primary: true,
                              icon: Icons.play_arrow_rounded,
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 필요한 변수는 검증할 논리 화면 크기와 golden 파일명이다.
/// 지정 크기로 공용 학생 셸을 렌더하고 메뉴 노출 규칙 및 픽셀 결과를 함께 확인한다.
Future<void> _verifyViewport(
  WidgetTester tester,
  Size size,
  String goldenName, {
  required bool mobile,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_responsiveFixture());
  await tester.pumpAndSettle();

  expect(
    find.byKey(const ValueKey('student-mobile-menu')),
    mobile ? findsOneWidget : findsNothing,
  );
  expect(find.text('학습터'), mobile ? findsNothing : findsOneWidget);
  expect(find.byType(BottomNavigationBar), findsNothing);
  expect(find.byType(NavigationRail), findsNothing);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$goldenName.png'),
  );
}

/// 필요한 변수는 계획에 명시된 390px·500px·1280×900 화면 크기다.
/// 모바일 두 크기와 데스크톱 한 크기를 독립 렌더하여 셸 회귀를 차단한다.
void main() {
  testWidgets('390px 모바일은 햄버거만 표시한다', (tester) async {
    await _verifyViewport(
      tester,
      const Size(390, 844),
      'student-shell-390',
      mobile: true,
    );
  });

  testWidgets('500px 모바일은 햄버거와 단일 열을 유지한다', (tester) async {
    await _verifyViewport(
      tester,
      const Size(500, 1000),
      'student-shell-500',
      mobile: true,
    );
  });

  testWidgets('1280×900 PC는 상단 메뉴만 표시한다', (tester) async {
    await _verifyViewport(
      tester,
      const Size(1280, 900),
      'student-shell-1280',
      mobile: false,
    );
  });

  testWidgets('모바일 드로어에서 코스·책가방·소셜·마켓으로 이동한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        routes: {'/marketplace': (_) => const Scaffold(body: Text('마켓 도착'))},
        home: Scaffold(
          drawer: const AppDrawer(),
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              child: const Text('메뉴 열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('메뉴 열기'));
    await tester.pumpAndSettle();

    expect(find.text('학습터'), findsOneWidget);
    expect(find.text('코스'), findsOneWidget);
    expect(find.text('책가방'), findsOneWidget);
    expect(find.text('친구/소셜'), findsOneWidget);
    expect(find.text('마켓플레이스'), findsOneWidget);

    await tester.tap(find.text('마켓플레이스'));
    await tester.pumpAndSettle();
    expect(find.text('마켓 도착'), findsOneWidget);
  });

  testWidgets('PC 공용 상단 메뉴는 다섯 목적지와 명명 라우트를 공유한다', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        routes: {'/marketplace': (_) => const Scaffold(body: Text('상단 마켓 도착'))},
        home: Builder(
          builder: (context) => Scaffold(
            body: Ios26TopBar(
              brandColor: StudentDensityTokens.dark,
              showLevelIndicator: false,
              items: studentTopNavItems(
                context,
                active: StudentTopDestination.learning,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('학습터'), findsOneWidget);
    expect(find.text('코스'), findsOneWidget);
    expect(find.text('책가방'), findsOneWidget);
    expect(find.text('친구/소셜'), findsOneWidget);
    expect(find.text('마켓플레이스'), findsOneWidget);
    await tester.tap(find.text('마켓플레이스'));
    await tester.pumpAndSettle();
    expect(find.text('상단 마켓 도착'), findsOneWidget);
  });
}
