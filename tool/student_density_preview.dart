import 'package:flutter/material.dart';

import 'package:s11/sessions/course/ui/course_catalog_page.dart';
import 'package:s11/sessions/course/ui/course_detail_page.dart';
import 'package:s11/sessions/course/ui/course_html_dialogs.dart';
import 'package:s11/sessions/course/session/course_learning_page.dart';
import 'package:s11/sessions/course/session/teacher_course_textbook_reader_page.dart';
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/daily_test_modal.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/study_mode_modal.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/today_tasks_modal.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/rating_detail_modal.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/social_modal.dart';
import 'package:s11/sessions/student_dashboard/ui/widgets/activity_badges.dart';
import 'package:s11/sessions/textbook/ui/pages/docx_box.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart'
    as textbook_reader;
import 'package:s11/sessions/marketplace/ui/pages/marketplace_page.dart';
import 'package:s11/sessions/exam_paper/session/exam_paper_page.dart';
import 'package:s11/sessions/friend/friend.dart';
import 'package:s11/sessions/auth/ui/pages/login_page.dart';
import 'package:s11/sessions/auth/ui/pages/signup_page.dart';
import 'package:s11/sessions/auth/ui/pages/profile_page.dart';
import 'package:s11/sessions/settings/ui/pages/settings_page.dart';
import 'package:s11/features/wrong_answer/wrong_answer_list_page.dart';
import 'package:s11/features/level_test/level_test_home_page.dart';
import 'package:s11/features/arena/arena_page.dart';
import 'package:s11/features/student_schedule/schedule_page.dart';
import 'package:s11/features/student_runtime/student_runtime_page.dart';
import 'package:s11/features/student_runtime/models.dart';
import 'package:s11/features/course_runtime/course_runtime_page.dart';
import 'package:s11/features/group_study/group_list_page.dart';
import 'package:s11/features/group_study/group_detail_page.dart';
import 'package:s11/features/group_study/student_academy_page.dart';
import 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';
import 'package:s11/sessions/tryout_solve/ui/pages/flow_view_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/student_learning_tools_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/notepad_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/timer_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/focus_mode_page.dart';
import 'package:s11/sessions/friend/ui/student_direct_chat_page.dart';
import 'package:s11/sessions/graph_tools/session/jsx_graph_page.dart';
import 'package:s11/shared/data/models/course.dart';
import 'package:s11/shared/data/models/concept_textbooks.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';

/// 필요한 변수는 HTML 코스 시안에 표시되는 상태·진행률·추천 정보다.
/// 작동 원리: 네트워크 없이도 실제 코스 위젯이 밀도와 반응형을 동일하게 렌더하도록 고정 입력을 만든다.
List<Course> _previewCourses() => const [
  Course(
    id: 'linear-active',
    title: '일차함수 완성',
    description: '그래프 해석과 기울기를 교재·문제·시험 흐름으로 보완합니다.',
    level: '그래프 이해',
    duration: '3주',
    progress: 0.42,
    status: 'in_progress',
    lastAction: '그래프 이해 · 06번째 모듈',
    lessons: 12,
    targetOvr: 91,
    focusTags: ['#일차함수', '#그래프', '#기울기', '#서술형'],
    units: [
      CourseUnit(
        title: '함수의 기초',
        type: 'textbook_view',
        detail: {'type': 'textbook_view', 'min_minutes': 8},
        status: CourseUnitStatus.completed,
        missions: [
          CourseUnitMission(
            title: '함수의 뜻',
            detail: {'type': 'textbook_view'},
            actionLabel: '복습',
          ),
        ],
      ),
      CourseUnit(
        title: '기울기의 의미',
        type: 'textbook_view',
        detail: {'type': 'textbook_view', 'min_minutes': 8},
        status: CourseUnitStatus.active,
        progress: .42,
        missions: [
          CourseUnitMission(
            title: '기울기 교재 이어보기',
            detail: {'type': 'textbook_view'},
          ),
        ],
      ),
      CourseUnit(
        title: '좌표와 그래프',
        type: 'problem_solve',
        detail: {'type': 'problem_solve', 'question_count': 10},
        status: CourseUnitStatus.locked,
      ),
      CourseUnit(
        title: '일차함수 실전',
        type: 'exam_solve',
        detail: {'type': 'exam_solve', 'question_count': 20},
        status: CourseUnitStatus.locked,
      ),
    ],
  ),
  Course(
    id: 'geometry-active',
    title: '도형의 닮음',
    description: '닮음 조건과 닮음비를 문제 중심으로 익힙니다.',
    level: '닮음비',
    duration: '2주',
    progress: 0.18,
    status: 'in_progress',
    lastAction: '닮음비 · 03번째 모듈',
    lessons: 9,
    targetOvr: 84,
  ),
  Course(
    id: 'probability',
    title: '확률 실전',
    description: '경우의 수를 정리하고 실전 문제로 연결합니다.',
    level: '확률',
    duration: '2주',
    lessons: 8,
    targetOvr: 78,
  ),
  Course(
    id: 'foundation',
    title: '수학 기초 회복',
    description: '핵심 개념을 짧은 교재와 반복 문제로 다시 다집니다.',
    level: '기초',
    duration: '4주',
    lessons: 16,
    targetOvr: 72,
  ),
  Course(
    id: 'completed',
    title: '일차방정식 기초',
    description: '완료한 코스의 교재와 문제를 다시 확인할 수 있습니다.',
    level: '기초',
    duration: '완료',
    progress: 1,
    status: 'completed',
    lessons: 8,
    targetOvr: 100,
  ),
];

/// 필요한 변수는 HTML 코스 학습 시안의 현재 모듈·진행률·잠금 상태다.
/// 작동 원리: 실제 StudentRuntimePage에 고정 데이터를 주입해 네트워크 없이 PC·모바일 경로 배열을 캡처한다.
List<RuntimeCourseModel> _previewRuntimeCourses() => [
  RuntimeCourseModel(
    id: 101,
    title: '일차함수 완성',
    overallProgress: 42,
    modules: [
      RuntimeModuleModel(
        id: 1,
        moduleType: RuntimeModuleType.textbookView,
        title: '좌표와 그래프 읽기',
        status: 'completed',
        progressPercent: 100,
        configJson: '{}',
      ),
      RuntimeModuleModel(
        id: 2,
        moduleType: RuntimeModuleType.textbookView,
        title: '기울기의 의미',
        status: 'available',
        progressPercent: 65,
        configJson: '{}',
      ),
      RuntimeModuleModel(
        id: 3,
        moduleType: RuntimeModuleType.problemSolve,
        title: '기울기 문제 풀이',
        status: 'locked',
        progressPercent: 0,
        configJson: '{}',
      ),
      RuntimeModuleModel(
        id: 4,
        moduleType: RuntimeModuleType.levelTest,
        title: '그래프 이해 레벨 테스트',
        status: 'locked',
        progressPercent: 0,
        configJson: '{}',
      ),
      RuntimeModuleModel(
        id: 5,
        moduleType: RuntimeModuleType.examSolve,
        title: '일차함수 실전 시험',
        status: 'locked',
        progressPercent: 0,
        configJson: '{}',
      ),
    ],
  ),
];

/// 필요한 변수는 학습 중인 미리보기 코스다.
/// 작동 원리: 동일 메타와 유닛을 사용하되 등록 상태만 제거해 HTML 상세 화면의 등록 전 행동을 재현한다.
Course _previewDetailCourse(Course source) => Course(
  id: '${source.id}-detail',
  title: source.title,
  description: source.description,
  level: source.level,
  duration: source.duration,
  focusTags: source.focusTags,
  lessons: source.lessons,
  targetOvr: source.targetOvr,
  units: source.units,
);

/// 필요한 변수는 HTML 문제 풀이 화면의 지문·선택지·태그다.
/// 작동 원리는 서버 요청 없이 실제 필기 캔버스와 답안 도구가 즉시 렌더되도록 한 문제 설정을 만든다.
ProblemSolveConfig _previewSolveConfig() => const ProblemSolveConfig(
  questionCount: 1,
  hashTags: ['일차함수'],
  gradeImmediately: true,
  ratingEnabled: false,
  quests: [
    {
      'header': {'quest_id': 'preview-linear-04'},
      'info': {
        'hash_tag': ['일차함수'],
        'difficulty_tier': 3,
      },
      'data': {
        'quest_title': '두 점 (1, 3), (3, 7)을 지나는 일차함수의 식을 구하세요.',
        'quest_options': ['y = 2x + 1', 'y = x + 2', 'y = 3x', 'y = 4x - 1'],
      },
    },
  ],
);

/// 필요한 변수는 HTML Flow 시안의 문제·풀이 단계·분기다.
/// 작동 원리는 실제 Flow 그래프가 정답·오답·후속 노드를 네트워크 없이 렌더하도록 고정 문제를 만든다.
Map<String, dynamic> _previewFlowQuest() => {
  'data': {
    'quest_id': 'preview-flow-linear',
    'quest_title': '두 점을 지나는 일차함수의 식을 구하세요.',
    'codebase_id': 21,
    'seed': 2407,
    'hash_tag': ['일차함수', '기울기'],
    'answer_riddle': 'y = 2x + 1',
    'all_formulas': 'a = (7-3)/(3-1) = 2, b = 1',
  },
  'solves': [
    {
      'flow': 'STEP 01\n조건 해석\n(1, 3), (3, 7)',
      'hash_tag': ['좌표'],
      'hint_riddle': 'x와 y의 변화량을 각각 표시해 보세요.',
      'branches': [
        [
          {
            'flow': 'STEP 02-A\n변화량 순서 확인\nΔy / Δx = 2 / 4',
            'hash_tag': ['부호'],
          },
        ],
        [
          {
            'flow': 'STEP 02-B\n기울기 계산\n(7-3) / (3-1) = 2',
            'hash_tag': ['기울기'],
          },
        ],
      ],
    },
    {
      'flow': 'STEP 03\n절편 구하기\n3 = 2 × 1 + b',
      'hash_tag': ['y절편'],
      'answer_riddle': 'y = 2x + 1',
    },
    {
      'flow': 'STEP 04\n다른 점으로 검산\n7 = 2 × 3 + 1',
      'hash_tag': ['검산'],
    },
  ],
};

/// 필요한 변수는 HTML 교재 리더에 표시할 장·절·본문이다.
/// 작동 원리는 실제 교재 모델을 고정 입력으로 만들어 페이지 이동·필기·북마크 UI를 네트워크 없이 검증하는 것이다.
BookData _previewTextbook() => kConceptTextbooks['두점을지나는직선']!;

/// 필요한 변수는 아레나 프로필과 네 대결 큐다.
/// 작동 원리는 실제 아레나 위젯에 운영 응답과 같은 맵을 주입해 네트워크 없이 랭크 화면을 검증하는 것이다.
Map<String, dynamic> _previewArenaSummary() => {
  'profile': {'tier': 'B', 'rating': 1580, 'wins': 18, 'losses': 9, 'draws': 2},
  'queues': [
    for (final queue in [
      ('duel_exam', 'B', 1580, 18),
      ('duel_ox', 'A', 1810, 9),
      ('team_exam', 'C', 1420, 24),
      ('team_ox', 'B', 1550, 12),
    ])
      {
        'queue_type': queue.$1,
        'tier': queue.$2,
        'rating': queue.$3,
        'wins': 18,
        'losses': 9,
        'draws': 2,
        'estimated_wait_seconds': queue.$4,
      },
  ],
};

/// 필요한 변수는 브라우저 viewport와 선택적인 width/height 쿼리다.
/// 작동 원리: 실제 학생 홈을 그대로 실행하고 논리 화면 크기만 고정해 HTML 시안과 같은 좌표계로 캡처한다.
void main() {
  runApp(const StudentDensityPreviewApp());
}

class StudentDensityPreviewApp extends StatelessWidget {
  const StudentDensityPreviewApp({super.key});

  /// 필요한 변수는 캡처용 논리 크기와 실제 학생 홈 라우트다.
  /// 작동 원리: API 실패가 화면 구조를 바꾸지 않도록 실제 홈의 빈 상태를 사용하고 디버그 배너를 숨긴다.
  @override
  Widget build(BuildContext context) {
    final previewWidth = double.tryParse(
      Uri.base.queryParameters['width'] ?? '',
    );
    final previewHeight = double.tryParse(
      Uri.base.queryParameters['height'] ?? '',
    );
    final screen = Uri.base.queryParameters['screen'] ?? 'dashboard';
    final action = Uri.base.queryParameters['action'] ?? '';
    final courses = _previewCourses();
    final screenHome = switch (screen) {
      'dashboard' => const MainStudentPage(username: '김학생'),
      'courses' => CourseCatalogPage(
        courseFeedLoader: ({required keyword, recommend}) async {
          if (keyword.trim().isEmpty) return courses;
          final query = keyword.trim().toLowerCase();
          return courses
              .where(
                (course) =>
                    course.title.toLowerCase().contains(query) ||
                    course.description.toLowerCase().contains(query),
              )
              .toList(growable: false);
        },
      ),
      'course-detail' => CourseDetailPage(
        course: _previewDetailCourse(courses.first),
      ),
      'course-learning' => CourseLearningPage(course: courses.first),
      'student-runtime' => StudentRuntimePage(
        initialCourses: _previewRuntimeCourses(),
      ),
      'course-runtime' => const CourseRuntimePage(),
      'wrong-answers' => const WrongAnswerListPage(),
      'level-test' => const LevelTestHomePage(),
      'solve' => BuildpageWidget(config: _previewSolveConfig()),
      'flow' => FlowViewPage(
        quest: _previewFlowQuest(),
        title: '일차함수 Flow 분석',
        stepCorrectness: const [
          {'correct': true},
          {'correct': false},
          {'correct': true},
          {'correct': true},
          {'correct': false},
        ],
      ),
      'tools' => const StudentLearningToolsPage(),
      'graph' => const JsxGraphPage(embedEnabled: false),
      'chat' => const StudentDirectChatPage(peerUsername: '이수학', preview: true),
      'textbooks' => const BookWidget(previewMode: true),
      'textbook-library' => const _TextbookLibraryPreview(),
      'textbook-reader-library' => textbook_reader.BookWidget(
        book: _previewTextbook(),
      ),
      'textbook-reader' => TeacherCourseTextbookReaderPage(
        courseId: 'preview-course',
        moduleId: 'preview-module',
        textbookId: 'preview-linear-textbook',
        pageFrom: 1,
        pageTo: 4,
        minMinutes: 8,
        previewBook: _previewTextbook(),
        previewElapsedSeconds: 5 * 60 + 12,
      ),
      'exam-paper' => const ExamPaperPage(
        timeLimitMinutes: 43,
        pageCountHint: 5,
        initialPageIndex: 1,
      ),
      'arena' => ArenaPage(initialSummary: _previewArenaSummary()),
      'marketplace' => const MarketplacePage(
        initialData: [
          {
            'id': 'market-exam-1',
            'kind': 'exam',
            'title': '공통수학 기초 진단 A',
            'price_points': 0,
            'item_count': 10,
          },
          {
            'id': 'market-course-1',
            'kind': 'course',
            'title': '공통수학 기초 완성',
            'price_points': 900,
            'item_count': 20,
          },
          {
            'id': 'market-set-1',
            'kind': 'problem_set',
            'title': '다항식 기본기 5',
            'price_points': 120,
            'item_count': 5,
          },
        ],
      ),
      'schedule' => SchedulePage(
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
          {
            'time': '19:30',
            'type': '개인',
            'title': '개인 복습',
            'detail': '기울기와 그래프 · 20분',
            'status': '예정',
            'completed': true,
          },
          {
            'time': '22:00',
            'type': '과제',
            'title': '일차함수 12문제',
            'detail': '진행 4/12 · 오늘 마감',
            'status': '진행 중',
            'completed': false,
          },
        ],
      ),
      'groups' => GroupListPage(
        initialGroups: [
          AcademyGroup(
            groupId: 'group-1',
            academyId: 'academy-1',
            name: '중2 심화 스터디',
            subject: '함수와 도형을 함께 공부하는 2학년 스터디',
            searchable: true,
            maxMembers: 20,
          ),
          AcademyGroup(
            groupId: 'group-2',
            academyId: 'academy-1',
            name: '수학 아레나 팀',
            subject: '매주 화·목 팀 대결을 준비합니다.',
            maxMembers: 4,
          ),
          AcademyGroup(
            groupId: 'group-3',
            academyId: 'academy-1',
            name: 'AIFlow 학교 그룹',
            subject: '선생님 과제와 공지를 확인하는 학교 그룹',
            maxMembers: 86,
          ),
        ],
      ),
      'group-detail' => GroupDetailPage(
        groupId: 'group-1',
        initialGroup: AcademyGroup(
          groupId: 'group-1',
          academyId: 'academy-1',
          name: '중2 심화 스터디',
          subject: '함수와 도형을 함께 공부하는 중학교 2학년 스터디',
          grade: '그룹장 이수학',
          searchable: true,
          maxMembers: 20,
        ),
        initialMembers: [
          AcademyGroupMember(
            memberId: 'member-1',
            groupId: 'group-1',
            userId: '이수학',
            role: 'leader',
          ),
          AcademyGroupMember(
            memberId: 'member-2',
            groupId: 'group-1',
            userId: '김학생',
          ),
          AcademyGroupMember(
            memberId: 'member-3',
            groupId: 'group-1',
            userId: '박함수',
          ),
        ],
      ),
      'academy' => const StudentAcademyPage(
        academyId: 'academy-1',
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
          {'title': '그래프 개념 교재 3장', 'detail': '최소 학습 8분', 'completed': false},
        ],
        initialSchedule: [
          {'day': '목', 'time': '목 19:30', 'title': '함수 심화 수업'},
          {'day': '목', 'time': '19:30', 'title': '도형과 그래프'},
          {'day': '토', 'time': '14:00', 'title': '주간 테스트'},
        ],
        initialAttendancePresent: true,
      ),
      'friends' => const SoWidget(preview: true),
      'auth' => const LoginPage(
        initialUsername: 'student01',
        initialPassword: 'password123',
      ),
      'signup' => SignupPage(
        preview: true,
        initialStage: action == 'signup-account'
            ? 1
            : action == 'signup-confirm'
            ? 2
            : 0,
      ),
      'profile' => ProfilePage(
        initialProfile: UserProfile(
          userId: 'student-1',
          username: 'student01',
          name: '김학생',
          grade: '2학년',
          track: '중학교',
          subject: '수학',
          school: 'AIFlow 중학교',
          email: 'student@example.com',
        ),
        initialTextbookPageMode: true,
        showDeleteDialogOnStart: action == 'profile-delete',
      ),
      'settings' => SettingsPage(
        preview: true,
        showLicensesOnStart: action == 'licenses',
      ),
      _ => const MainStudentPage(username: '김학생'),
    };
    final handledInScreen =
        action == 'signup-account' ||
        action == 'signup-confirm' ||
        action == 'profile-delete' ||
        action == 'licenses';
    final home = action.isEmpty || handledInScreen
        ? screenHome
        : _PreviewActionLauncher(action: action, child: screenHome);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        if (previewWidth == null || previewHeight == null || child == null) {
          return child ?? const SizedBox.shrink();
        }
        final media = MediaQuery.of(context);
        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: previewWidth,
            height: previewHeight,
            child: MediaQuery(
              data: media.copyWith(size: Size(previewWidth, previewHeight)),
              child: child,
            ),
          ),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: StudentDensityTokens.background,
        colorScheme: const ColorScheme.light(
          primary: StudentDensityTokens.dark,
          surface: StudentDensityTokens.surface,
          onSurface: StudentDensityTokens.ink,
        ),
        fontFamilyFallback: const [
          'Pretendard',
          'Noto Sans KR',
          'Malgun Gothic',
          'Arial',
        ],
      ),
      routes: {
        '/profile': (_) => const Scaffold(body: SizedBox.shrink()),
        '/study-center': (_) => const Scaffold(body: SizedBox.shrink()),
        '/courses': (_) => const Scaffold(body: SizedBox.shrink()),
        '/bookbag': (_) => const Scaffold(body: SizedBox.shrink()),
        '/social': (_) => const Scaffold(body: SizedBox.shrink()),
        '/marketplace': (_) => const Scaffold(body: SizedBox.shrink()),
      },
      home: home,
    );
  }
}

class _TextbookLibraryPreview extends StatefulWidget {
  const _TextbookLibraryPreview();

  /// 필요한 변수는 다이얼로그의 표시 여부다.
  /// 작동 원리는 실제 교재함 모달을 첫 프레임 이후 한 번 열어 브라우저 캡처가 운영 경로와 같은 위젯을 기록하게 하는 것이다.
  @override
  State<_TextbookLibraryPreview> createState() =>
      _TextbookLibraryPreviewState();
}

class _TextbookLibraryPreviewState extends State<_TextbookLibraryPreview> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openLibrary());
  }

  /// 필요한 변수는 공개 교재에 사용할 고정 장·절 데이터다.
  /// 작동 원리는 네트워크 없이 세 가지 진행 상태를 주입해 목록 카드와 진행률 표시를 반복 가능하게 검증하는 것이다.
  Future<void> _openLibrary() => textbook_reader.showBookLibraryModal<void>(
    context: context,
    books: [
      BookData(
        id: 'preview-linear',
        title: '두 점을 지나는 직선',
        subtitle: '좌표와 기울기를 연결하는 개념 교재',
        chapters: _previewTextbook().chapters,
        progress: .65,
        progressLabel: '65% 완료 · 4쪽에서 이어 읽기',
        coverColor: const Color(0xFF1F6B4F),
      ),
      BookData(
        id: 'preview-graph',
        title: '그래프를 읽는 법',
        subtitle: '좌표평면과 변화량의 기초',
        chapters: _previewTextbook().chapters,
        progress: .24,
        progressLabel: '24% 완료',
        coverColor: const Color(0xFF2F8062),
      ),
      BookData(
        id: 'preview-review',
        title: '함수 개념 다시보기',
        subtitle: '핵심 정의와 예제로 복습하기',
        chapters: _previewTextbook().chapters,
        progress: 0,
        progressLabel: '새 교재',
        coverColor: const Color(0xFF5B8E77),
      ),
    ],
  );

  /// 필요한 변수는 모달 뒤에 보일 배경이다.
  /// 작동 원리는 실제 사용 환경처럼 교재함을 독립된 모달로 읽을 수 있도록 차분한 학습 대시보드 표면을 제공하는 것이다.
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xFFF1F5F1),
    body: Center(
      child: Text(
        'AIFlow 학습 공간',
        style: TextStyle(
          color: Color(0xFF1F4D38),
          fontSize: 28,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _PreviewActionLauncher extends StatefulWidget {
  const _PreviewActionLauncher({required this.action, required this.child});

  final String action;
  final Widget child;

  // 필요한 변수: 감사 액션과 실제 화면이다. 작동 원리: 첫 렌더 뒤 실제 모달을 여는 상태를 생성한다.
  @override
  State<_PreviewActionLauncher> createState() => _PreviewActionLauncherState();
}

class _PreviewActionLauncherState extends State<_PreviewActionLauncher> {
  // 필요한 변수: URL에서 전달된 모달 액션이다. 작동 원리: 실제 화면이 그려진 다음 한 번만 해당 홈 모달을 호출한다.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openAction());
  }

  /// 필요한 변수는 현재 context와 감사 액션 이름이다.
  /// 작동 원리는 실제 공개 모달 함수를 호출해 좌표 클릭 없이 동일한 상태를 반복 캡처하는 것이다.
  Future<void> _openAction() async {
    if (!mounted) return;
    switch (widget.action) {
      case 'search':
        showStudentQuickSearch(context);
      case 'notifications':
        showStudentNotifications(context);
      case 'system-notices':
        showStudentNotifications(context);
      case 'social-home':
        await showSocialModal<void>(context: context);
      case 'rating-detail':
        await showRatingDetailModal<void>(
          context: context,
          initialRatings: _previewTagRatings(),
        );
      case 'achievements':
        showActivityBadgeDialog(
          context: context,
          snapshot: ActivityStore.notifier.value,
          accountLevel: 7,
        );
      case 'tool-note':
        await showStudentToolModal(context, const NotepadPage());
      case 'tool-timer':
        await showStudentToolModal(context, const TimerPage());
      case 'tool-focus':
        await showStudentToolModal(context, const FocusModePage());
      case 'course-reorder':
        await showCourseReorderDialog(
          context,
          courses: _previewCourses().take(2).toList(growable: false),
          onSaved: () {},
        );
      case 'course-compare':
        await showCourseCompareDialog(
          context,
          courses: _previewCourses().take(2).toList(growable: false),
        );
      case 'course-policy':
        await showCoursePolicyDialog(context);
      case 'study-mode':
        await showStudyModeModal<void>(context: context);
      case 'daily-test':
        await showDailyTestModal<void>(
          context: context,
          initialBundle: const DailyQuestBundle(
            account: AccountSummary(),
            items: [
              DailyQuestItem(
                id: 'daily-1',
                questType: 'problem',
                title: '일차함수 기본',
                target: 10,
                progress: 4,
                status: 'in_progress',
                rewardPoints: 80,
              ),
              DailyQuestItem(
                id: 'daily-2',
                questType: 'graph',
                title: '그래프 해석',
                target: 1,
                progress: 0,
                status: 'pending',
                rewardPoints: 60,
              ),
              DailyQuestItem(
                id: 'daily-3',
                questType: 'ox',
                title: '오늘의 OX',
                target: 1,
                progress: 1,
                status: 'completed',
                rewardPoints: 40,
                rewardClaimed: true,
              ),
            ],
          ),
        );
      case 'today-tasks':
        await showTodayTasksModal<void>(
          context: context,
          tasks: const [
            TodayTaskEntry(
              title: '개인 복습 20분',
              caption: '오늘 학습 계획',
              icon: Icons.auto_stories_rounded,
            ),
            TodayTaskEntry(
              title: '문제 12개',
              caption: '코스 학습',
              icon: Icons.edit_note_rounded,
            ),
            TodayTaskEntry(
              title: '교재 3장 읽기',
              caption: '읽기 목표',
              icon: Icons.menu_book_rounded,
            ),
          ],
          onTaskTap: (_) {},
        );
    }
  }

  /// 필요한 변수는 감사 대상 실제 화면이다. 작동 원리는 모달의 배경으로 원래 화면을 그대로 유지한다.
  @override
  Widget build(BuildContext context) => widget.child;
}

/// 필요한 변수는 HTML 레이팅 상세 시안의 4개 축과 변화 태그다.
/// 작동 원리: 브라우저 감사에서만 고정 레이팅을 주입해 API 없이도 그래프·태그 시각 품질을 반복 캡처한다.
Map<String, TagRating> _previewTagRatings() {
  TagRating rating(String tag, double ovr, double deltaOvr, int attempts) {
    return TagRating(
      tag: tag,
      rating: 1200 + ovr * 128,
      delta: deltaOvr * 128,
      attempts: attempts,
    );
  }

  return {
    '공통수학1': rating('공통수학1', 19.2, .8, 42),
    '공통수학2': rating('공통수학2', 18.1, .3, 35),
    '대수': rating('대수', 17.4, .1, 29),
    '미적분Ⅰ': rating('미적분Ⅰ', 16.9, -.2, 22),
    '그래프': rating('그래프', 19.4, .8, 18),
    '확률': rating('확률', 15.8, -.4, 13),
    '일차함수': rating('일차함수', 19.6, .5, 24),
    '기하': rating('기하', 16.4, -.1, 15),
  };
}
