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
import 'package:s11/sessions/marketplace/ui/pages/marketplace_page.dart';
import 'package:s11/features/student_schedule/schedule_page.dart';
import 'package:s11/features/group_study/group_list_page.dart';
import 'package:s11/features/group_study/group_detail_page.dart';
import 'package:s11/features/group_study/student_academy_page.dart';
import 'package:s11/sessions/friend/friend.dart';
import 'package:s11/sessions/auth/ui/pages/login_page.dart';
import 'package:s11/sessions/auth/ui/pages/signup_page.dart';
import 'package:s11/sessions/auth/ui/pages/profile_page.dart';
import 'package:s11/sessions/settings/ui/pages/settings_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/student_learning_tools_page.dart';
import 'package:s11/sessions/friend/ui/student_direct_chat_page.dart';

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

  testWidgets('500px 마켓은 HTML 검색·필터·추천 상세 흐름을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: MarketplacePage(
          initialData: [
            {
              'id': 'q1',
              'type': 'quest',
              'title': '중2 함수 실전 100제',
              'subtitle': '평점 4.9 · 1,200P',
            },
            {
              'id': 'b1',
              'type': 'textbook',
              'title': '개념이 보이는 그래프',
              'subtitle': '무료 · 42쪽',
            },
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('COMMUNITY'), findsOneWidget);
    expect(find.text('마켓'), findsOneWidget);
    expect(find.text('문제 · 교재 · 태그 검색'), findsOneWidget);
    expect(find.text('중2 함수 실전 100제'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '교재'));
    await tester.pump();
    expect(find.text('중2 함수 실전 100제'), findsNothing);
    await tester.tap(find.text('개념이 보이는 그래프'));
    await tester.pumpAndSettle();
    expect(find.text('확인'), findsOneWidget);
  });

  testWidgets('500px 일정은 HTML 주간 타임라인과 월간 전환을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SchedulePage(
          initialDate: DateTime(2026, 7, 16),
          initialSchedule: const [
            {
              'time': '16:00',
              'type': '교재',
              'title': '교재 3장 읽기',
              'detail': '최소 학습 8분',
              'status': '미시작',
              'completed': false,
            },
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('JULY 2026'), findsOneWidget);
    expect(find.text('교재 3장 읽기'), findsOneWidget);
    await tester.tap(find.text('월간'));
    await tester.pump();
    expect(find.text('July 2026'), findsOneWidget);
  });

  testWidgets('500px 그룹 허브와 상세는 탐색·채팅 상호작을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final group = AcademyGroup(
      groupId: 'g1',
      academyId: 'a1',
      name: '중2 심화 스터디',
      subject: '함수와 도형을 함께 공부합니다.',
      maxMembers: 20,
    );

    await tester.pumpWidget(
      MaterialApp(home: GroupListPage(initialGroups: [group])),
    );
    await tester.pump();
    expect(find.text('GROUP STUDY'), findsOneWidget);
    expect(find.text('중2 심화 스터디'), findsOneWidget);
    await tester.tap(find.text('그룹 찾기 · 코드 참가'));
    await tester.pumpAndSettle();
    expect(find.text('그룹 찾기'), findsWidgets);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        home: GroupDetailPage(
          groupId: 'g1',
          initialGroup: group,
          initialMembers: [
            AcademyGroupMember(
              memberId: 'm1',
              groupId: 'g1',
              userId: '이수학',
              role: 'leader',
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('GROUP SPACE'), findsOneWidget);
    await tester.tap(find.textContaining('채팅 열기'));
    await tester.pumpAndSettle();
    expect(find.text('중2 심화 스터디 채팅'), findsOneWidget);
  });

  testWidgets('500px 학원은 HTML 정보·오늘 할 일·시간표 구조를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: StudentAcademyPage(
          academyId: 'a1',
          initialAcademy: {
            'name': 'AIFlow 수학학원',
            'subtitle': '중2 심화반',
            'teacher': '담당 김선생',
          },
          initialTasks: [
            {
              'title': '일차함수 실전 12문제',
              'detail': '오늘 22:00 마감',
              'completed': false,
            },
          ],
          initialSchedule: [
            {'day': '목', 'time': '19:30', 'title': '함수 심화 수업'},
          ],
          initialAttendancePresent: true,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('ACADEMY'), findsOneWidget);
    expect(find.text('AIFlow 수학학원'), findsOneWidget);
    expect(find.text('오늘 할 일'), findsOneWidget);
    expect(find.text('이번 주 수업'), findsOneWidget);
  });

  testWidgets('500px 친구/소셜은 HTML 소식·대화·친구 순서를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SoWidget(preview: true)));
    await tester.pump();
    expect(find.text('FRIENDS & SOCIAL'), findsOneWidget);
    expect(find.text('친구 요청'), findsOneWidget);
    expect(find.text('최근 대화'), findsOneWidget);
    expect(find.text('이수학'), findsWidgets);
    await tester.drag(find.byType(ListView).first, const Offset(0, -650));
    await tester.pump();
    expect(find.text('친구 상태'), findsOneWidget);
  });

  testWidgets('500px 학습 도구는 HTML 세 모달 카드와 타이머 실행을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        routes: {'/study-center': (_) => const SizedBox.shrink()},
        home: const StudentLearningToolsPage(),
      ),
    );
    await tester.pump();
    expect(find.text('LEARNING TOOLS'), findsOneWidget);
    expect(find.text('빠른 노트'), findsOneWidget);
    expect(find.text('집중 타이머'), findsOneWidget);
    expect(find.text('집중 모드'), findsOneWidget);
    await tester.tap(find.text('집중 타이머'));
    await tester.pumpAndSettle();
    expect(find.text('스톱워치'), findsOneWidget);
    expect(find.text('타이머'), findsWidgets);
  });

  testWidgets('500px 채팅은 HTML 실시간 대화 카드와 전송 입력을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: StudentDirectChatPage(peerUsername: '이수학', preview: true),
      ),
    );
    await tester.pump();
    expect(find.text('SOCIAL'), findsOneWidget);
    expect(find.text('채팅'), findsOneWidget);
    expect(find.text('오늘 일차함수 챌린지 같이 풀래?'), findsOneWidget);
    expect(find.text('좋아! 8시에 시작하자.'), findsOneWidget);
    expect(find.text('메시지 입력'), findsOneWidget);
    expect(find.text('전송'), findsOneWidget);
  });

  testWidgets('500px 로그인은 HTML 복원 히어로와 학생 폼을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginPage(
          initialUsername: 'student01',
          initialPassword: 'password123',
        ),
      ),
    );
    await tester.pump();
    expect(find.text('WELCOME BACK'), findsOneWidget);
    expect(find.text('멈춘 곳에서\n다시 시작해요.'), findsOneWidget);
    expect(find.text('STUDENT LOGIN'), findsOneWidget);
    expect(find.text('로그인'), findsWidgets);
  });

  testWidgets('500px 회원가입은 HTML 세 단계와 학생 기본 폼을 유지한다', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: SignupPage(preview: true)));
    await tester.pump();
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    expect(find.text('나에게 맞는 학습을\n설정해 볼까요?'), findsOneWidget);
    expect(find.text('01  기본 정보'), findsOneWidget);
    expect(find.text('계정 정보 입력하기 →'), findsOneWidget);
    await tester.tap(find.text('02  계정 만들기'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 02 · ACCOUNT'), findsOneWidget);
    expect(find.text('입력 정보 확인하기 →'), findsOneWidget);
    await tester.tap(find.text('03  최종 확인'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 03 · CONFIRM'), findsOneWidget);
    expect(find.text('가입하고 학습 시작하기'), findsOneWidget);
  });

  testWidgets('500px 프로필은 HTML 학생 히어로와 학습 정보를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          initialProfile: UserProfile(
            userId: 's1',
            username: 'student01',
            name: '김학생',
            grade: '2학년',
            track: '중학교',
            subject: '수학',
            school: 'AIFlow 중학교',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('MY ACCOUNT'), findsOneWidget);
    expect(find.text('STUDENT PROFILE'), findsOneWidget);
    expect(find.text('18.6'), findsOneWidget);
    expect(find.text('LEARNING PROFILE'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -720));
    await tester.pumpAndSettle();
    expect(find.text('SECURITY'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -720));
    await tester.pumpAndSettle();
    expect(find.text('DANGER ZONE'), findsOneWidget);
    final deleteButton = find.widgetWithText(OutlinedButton, '계정 삭제');
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.text('계정 삭제'), findsWidgets);
    expect(find.text('현재 비밀번호'), findsOneWidget);
  });

  testWidgets('500px 설정은 HTML 로컬 히어로와 세 설정 카드를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: SettingsPage(preview: true)),
    );
    await tester.pump();
    expect(find.text('PREFERENCES'), findsOneWidget);
    expect(find.text('LOCAL PREFERENCES'), findsOneWidget);
    expect(find.text('교재 보기'), findsOneWidget);
    expect(find.text('알림'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('STORAGE CONTRACT'), findsOneWidget);
    expect(find.text('settings.notifications_enabled'), findsOneWidget);
  });
}
