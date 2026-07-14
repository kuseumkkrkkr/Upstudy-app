import 'package:flutter/material.dart';

import 'package:s11/sessions/course/ui/course_catalog_page.dart';
import 'package:s11/sessions/course/ui/course_detail_page.dart';
import 'package:s11/sessions/course/session/course_learning_page.dart';
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/daily_test_modal.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/study_mode_modal.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/today_tasks_modal.dart';
import 'package:s11/features/wrong_answer/wrong_answer_list_page.dart';
import 'package:s11/features/level_test/level_test_home_page.dart';
import 'package:s11/shared/data/models/course.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';

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
    final courses = _previewCourses();
    final screenHome = switch (screen) {
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
      'wrong-answers' => const WrongAnswerListPage(),
      'level-test' => const LevelTestHomePage(),
      _ => const MainStudentPage(username: '김학생'),
    };
    final action = Uri.base.queryParameters['action'] ?? '';
    final home = action.isEmpty
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
      case 'study-mode':
        await showStudyModeModal<void>(context: context);
      case 'daily-test':
        await showDailyTestModal<void>(context: context);
      case 'today-tasks':
        final today = DateUtils.dateOnly(DateTime.now());
        await showTodayTasksModal<void>(
          context: context,
          tasksByDate: {
            today: const ['개인 복습 20분'],
          },
          lockedTasksByDate: {
            today: const ['문제 12개', '교재 3장 읽기'],
          },
          onTasksChanged: (_) {},
        );
    }
  }

  /// 필요한 변수는 감사 대상 실제 화면이다. 작동 원리는 모달의 배경으로 원래 화면을 그대로 유지한다.
  @override
  Widget build(BuildContext context) => widget.child;
}
