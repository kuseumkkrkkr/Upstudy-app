import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';
import 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/daily_test_modal.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/today_tasks_modal.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/features/wrong_answer/wrong_answer_list_page.dart';
import 'package:s11/features/level_test/level_test_home_page.dart';
import 'package:s11/sessions/exam_paper/session/exam_paper_page.dart';
import 'package:s11/features/arena/arena_page.dart';

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

/// 필요한 변수는 검증할 논리 화면 크기와 모바일 여부다.
/// 지정 크기로 공용 학생 셸을 렌더하고 HTML 시안의 햄버거·탭 노출 규칙을 확인한다.
Future<void> _verifyViewport(
  WidgetTester tester,
  Size size, {
  required bool mobile,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_responsiveFixture());
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('student-mobile-menu')), findsOneWidget);
  expect(find.text('학습터'), mobile ? findsNothing : findsOneWidget);
  expect(find.byType(BottomNavigationBar), findsNothing);
  expect(find.byType(NavigationRail), findsNothing);
}

/// 필요한 변수는 계획에 명시된 390px·500px·1280×900 화면 크기다.
/// 모바일 두 크기와 데스크톱 한 크기를 독립 렌더하여 셸 회귀를 차단한다.
void main() {
  testWidgets('390px 모바일은 햄버거만 표시한다', (tester) async {
    await _verifyViewport(tester, const Size(390, 844), mobile: true);
  });

  testWidgets('500px 모바일은 햄버거와 단일 열을 유지한다', (tester) async {
    await _verifyViewport(tester, const Size(500, 1000), mobile: true);
  });

  testWidgets('1280×900 PC는 햄버거와 상단 메뉴를 함께 표시한다', (tester) async {
    await _verifyViewport(tester, const Size(1280, 900), mobile: false);
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

  testWidgets('복습 화면은 500px에서 히어로와 문제 행동을 세로 배치한다', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: WrongAnswerListPage()));
    await tester.pumpAndSettle();

    expect(find.text('오늘은 6문제만\n다시 보면 돼요.'), findsOneWidget);
    expect(find.text('두 직선의 교점 구하기'), findsOneWidget);
    expect(find.text('해설 보기'), findsWidgets);
    expect(find.text('다시 풀기'), findsWidgets);
  });

  testWidgets('레벨 테스트는 390px에서 OVR 히어로와 시작 행동을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LevelTestHomePage()));
    await tester.pumpAndSettle();

    expect(find.text('처음 만나는\n나의 실력.'), findsOneWidget);
    expect(find.text('50'), findsWidgets);
    expect(find.text('레벨 테스트 시작 →'), findsOneWidget);
  });

  testWidgets('500px 문제 풀이는 HTML 집중 헤더와 2열 선택지를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: BuildpageWidget(
          config: ProblemSolveConfig(
            hashTags: ['일차함수'],
            ratingEnabled: false,
            quests: [
              {
                'header': {'quest_id': 'responsive-solve'},
                'data': {
                  'quest_title': '두 점을 지나는 일차함수의 식을 구하세요.',
                  'quest_options': [
                    'y = 2x + 1',
                    'y = x + 2',
                    'y = 3x',
                    'y = 4x - 1',
                  ],
                },
              },
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('PROBLEM SESSION'), findsOneWidget);
    expect(find.text('오늘의 문제'), findsOneWidget);
    expect(find.text('SAVED'), findsOneWidget);
    expect(find.text('y = 2x + 1'), findsOneWidget);
    expect(find.text('y = 4x - 1'), findsOneWidget);
    expect(find.byTooltip('펜'), findsOneWidget);
    expect(find.byTooltip('제출'), findsOneWidget);
  });

  testWidgets('500px 홈 액션 패널은 일일 테스트와 오늘 할 일 구조를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = DateUtils.dateOnly(DateTime.now());

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DailyTestModal(
            initialBundle: DailyQuestBundle(
              account: AccountSummary(),
              items: [
                DailyQuestItem(
                  id: 'one',
                  questType: 'problem',
                  title: '일차함수 기본',
                  target: 10,
                  progress: 4,
                  status: 'in_progress',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('DAILY QUEST'), findsOneWidget);
    expect(find.text('일차함수 기본'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodayTasksModal(
            initialTasksByDate: {
              today: const ['개인 복습 20분'],
            },
            lockedTasksByDate: {
              today: const ['문제 12개', '교재 3장 읽기'],
            },
            onTasksChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('TODAY TASKS'), findsOneWidget);
    expect(find.text('문제 12개'), findsOneWidget);
    expect(find.text('교재 3장 읽기'), findsOneWidget);
    expect(find.text('개인 복습 20분'), findsOneWidget);
    await tester.tap(find.text('일정 달력에서 보기'));
    await tester.pump();
    expect(find.text('${today.year}년 ${today.month}월'), findsOneWidget);
  });

  testWidgets('500px 시험지는 HTML 페이지 배지와 통합 도구 레일을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ExamPaperPage(
          pageCountHint: 5,
          initialPageIndex: 1,
          timeLimitMinutes: 43,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.byTooltip('펜'), findsOneWidget);
    expect(find.byTooltip('지우개'), findsOneWidget);
    expect(find.byTooltip('이동'), findsOneWidget);
    expect(find.byTooltip('팔레트'), findsOneWidget);
    expect(find.byTooltip('시험 종료'), findsOneWidget);

    await tester.tap(find.text('2 / 5'));
    await tester.pumpAndSettle();
    expect(find.text('페이지 미리보기'), findsOneWidget);
  });

  testWidgets('500px 아레나는 HTML 랭크 프로필과 네 대결 큐를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ArenaPage(
          initialSummary: {
            'profile': {
              'tier': 'B',
              'rating': 1580,
              'wins': 18,
              'losses': 9,
              'draws': 2,
            },
            'queues': [
              for (final type in [
                'duel_exam',
                'duel_ox',
                'team_exam',
                'team_ox',
              ])
                {
                  'queue_type': type,
                  'tier': 'B',
                  'rating': 1580,
                  'wins': 18,
                  'losses': 9,
                  'draws': 2,
                  'estimated_wait_seconds': 12,
                },
            ],
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('RANKED MATCH'), findsOneWidget);
    expect(find.text('실력으로 증명하는\n20분.'), findsOneWidget);
    expect(find.text('1,580'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pump();
    expect(find.text('대결 방식 선택'), findsOneWidget);
    expect(find.text('1v1 시험 대결'), findsOneWidget);
    expect(find.text('2v2 OX 대결'), findsOneWidget);
  });
}
