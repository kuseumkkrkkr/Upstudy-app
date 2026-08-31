import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:s11/shared/data/models/course.dart';
import 'package:s11/shared/data/models/course_module_config.dart';
import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/shared/services/api/course_service.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/course/ui/widgets/level_test_widget.dart';
import 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';
import 'package:s11/sessions/exam_paper/session/exam_paper_page.dart';
import 'package:s11/sessions/course/ui/course_catalog_page.dart';
import 'package:s11/sessions/course/ui/course_html_dialogs.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';
import 'teacher_course_textbook_reader_page.dart';

const _green = StudentDensityTokens.ink;
const _lightGreen = StudentDensityTokens.dark;
const _bgGrey = StudentDensityTokens.surfaceMuted;
const _shadow = BoxShadow(
  blurRadius: 6,
  color: Color(0x1A000000),
  offset: Offset(0, 3),
);

int _courseNumber(Course course) => course.id.hashCode & 0xFFFF;

/// 780px 모바일 셸과 넓은 PC 셸 사이에서는 표면 내부만 압축한다.
/// 상단 PC 네비게이션과 실제 코스·미션 상태는 그대로 유지한다.
bool _isCourseLearningCompactDesktop(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width > StudentDensityTokens.mobileBreakpoint && width < 1024;
}

/// 필요한 변수는 숫자 또는 문자열 형태로 온 서버 값과 기본값이다.
/// 작동 원리: 비정상 값을 기본값으로 바꾸고 음수 시간을 막아 화면 계산이 안전하게 유지되도록 한다.
int _runtimeSeconds(dynamic value, {int fallback = 0}) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  return parsed == null || parsed < 0 ? fallback : parsed;
}

/// 필요한 변수는 코스의 진행 상태에 저장된 교재 열람·문제 풀이 시간이다.
/// 작동 원리: 서로 다른 모듈 유형의 누적 초를 안전하게 더해 현재 코스의 실제 학습 시간을 만든다.
int _courseElapsedSeconds(Course course) {
  final state = course.progressDetail;
  var total = 0;
  final textbookViews = state['textbook_view'];
  if (textbookViews is Map) {
    for (final entry in textbookViews.values) {
      if (entry is Map) {
        total += _runtimeSeconds(entry['total_open_seconds']);
      }
    }
  }
  final moduleResults = state['module_results'];
  if (moduleResults is Map) {
    for (final result in moduleResults.values) {
      if (result is Map) {
        total += _runtimeSeconds(result['latest_elapsed_seconds']);
      }
    }
  }
  return total;
}

/// 필요한 변수는 초 단위의 누적 학습 시간이다.
/// 작동 원리: 서버가 보관한 시간을 0 이상으로 보정한 뒤 화면에서 읽기 쉬운 시:분:초로 변환한다.
String _formatCourseElapsedTime(int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  final remainingSeconds = safeSeconds % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
}

/// 필요한 변수는 활성 단원의 상세 정보와 코스 태그·제목이다.
/// 작동 원리: 단원에 명시된 주제를 우선 표시하고, 없을 때만 코스 태그와 제목 순으로 자연스럽게 대체한다.
String _currentLearningTopic(Course course, CourseUnit? unit) {
  final detail = unit?.detail;
  if (detail is Map) {
    for (final key in const ['topic', 'section_title', 'subject', 'category']) {
      final value = detail[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
  }
  if (course.focusTags.isNotEmpty && course.focusTags.first.trim().isNotEmpty) {
    return course.focusTags.first.trim();
  }
  return course.title.trim().isNotEmpty ? course.title.trim() : '학습 과정';
}

/// 필요한 변수는 코스의 레벨·기간·유형·집중 태그다.
/// 작동 원리: 서버가 실제로 제공한 값만 중복 없이 모아 화면 문맥 라벨로 사용하며,
/// 특정 학년이나 과목을 임의로 채우지 않는다.
List<String> _courseContextLabels(Course course, {int limit = 4}) {
  final labels = <String>[];
  void add(String value) {
    final normalized = value.trim();
    if (normalized.isNotEmpty && !labels.contains(normalized)) {
      labels.add(normalized);
    }
  }

  add(course.level);
  add(course.duration);
  for (final type in course.types) {
    add(type);
  }
  for (final tag in course.focusTags) {
    add(tag);
  }
  return labels.take(limit).toList(growable: false);
}

/// 필요한 변수는 코스 설명·제목·단원 수다.
/// 작동 원리: 서버 설명을 우선 사용하고 설명이 없을 때만 현재 코스의 실제 단원 수로
/// 짧은 대체 문구를 만들어 다른 코스의 내용이 섞이지 않게 한다.
String _courseDisplaySummary(Course course) {
  final description = course.description.trim();
  if (description.isNotEmpty) return description;
  if (course.units.isNotEmpty) return '${course.units.length}단계로 구성된 학습 코스';
  return '${course.title} 학습 코스';
}

/// 필요한 변수는 단원 상태가 포함된 코스다.
/// 작동 원리: 진행 중 단원, 수강 가능한 첫 단원, 첫 단원 순서로 현재 위치를 결정한다.
int _currentCourseUnitIndex(Course course) {
  if (course.units.isEmpty) return -1;
  var index = course.units.indexWhere(
    (unit) => unit.status == CourseUnitStatus.active,
  );
  if (index >= 0) return index;
  index = course.units.indexWhere(
    (unit) => unit.status != CourseUnitStatus.locked,
  );
  return index >= 0 ? index : 0;
}

/// 필요한 변수는 미션 행동명과 미션 상세 유형이다.
/// 작동 원리: 서버가 제공한 행동명을 우선하고 비어 있을 때만 모듈 종류에 맞는
/// 일반 행동명을 사용해 모든 미션을 교재로 오인하지 않게 한다.
String _missionActionLabel(CourseUnitMission? mission) {
  if (mission == null) return '학습 준비 중';
  final explicit = mission.actionLabel.trim();
  if (explicit.isNotEmpty && explicit != '시작') return explicit;
  final detail = mission.detail;
  final type = detail is Map ? detail['type']?.toString() ?? '' : '';
  switch (type) {
    case 'textbook_view':
      return '교재 이어보기';
    case 'problem_solve':
      return '문제 풀기';
    case 'exam_solve':
      return '시험 시작';
    case 'level_test':
      return '레벨 테스트';
    default:
      return explicit.isEmpty ? '학습 시작' : explicit;
  }
}

class CourseLearningPage extends StatefulWidget {
  const CourseLearningPage({
    super.key,
    required this.course,
    this.courseLoader,
  });

  final Course course;
  final Future<Course> Function(String courseId)? courseLoader;

  @override
  State<CourseLearningPage> createState() => _CourseLearningPageState();
}

class _CourseLearningPageState extends State<CourseLearningPage> {
  final Set<int> _expandedUnits = {};
  late Course _course;
  bool _loadingCourse = false;

  @override
  void initState() {
    super.initState();
    _course = widget.course;
    _expandCurrentUnit(_course);
    unawaited(_loadCourseDetail(showLoading: _course.units.isEmpty));
    final number = _courseNumber(widget.course);
    unawaited(
      ActivityStore.recordCourseView(
        courseId: widget.course.id,
        courseNumber: number > 0 ? number.toString() : widget.course.id,
        screen: 'learning',
      ).catchError((_) {}),
    );
  }

  Future<void> _loadCourseDetail({bool showLoading = true}) async {
    if (showLoading) setState(() => _loadingCourse = true);
    try {
      final loader = widget.courseLoader ?? CourseService.fetchCourse;
      final full = await loader(widget.course.id);
      if (!mounted) return;
      setState(() {
        _course = full;
        _expandCurrentUnit(full);
      });
    } finally {
      if (mounted && showLoading) setState(() => _loadingCourse = false);
    }
  }

  void _toggleUnit(int index) {
    setState(() {
      if (_expandedUnits.contains(index)) {
        _expandedUnits.remove(index);
      } else {
        _expandedUnits.add(index);
      }
    });
  }

  /// 필요 변수: 최신 [course]의 유닛 상태를 사용한다.
  /// 작동 원리: 진행 중인 유닛을 우선 펼치고, 없으면 첫 수강 가능 유닛을 열어 현재 위치를 즉시 보여준다.
  void _expandCurrentUnit(Course course) {
    if (course.units.isEmpty) return;
    var index = course.units.indexWhere(
      (unit) => unit.status == CourseUnitStatus.active,
    );
    if (index < 0) {
      index = course.units.indexWhere(
        (unit) => unit.status != CourseUnitStatus.locked,
      );
    }
    if (index >= 0) _expandedUnits.add(index);
  }

  Future<void> _handleMissionTap(
    CourseUnit unit,
    CourseUnitMission mission,
  ) async {
    final detail = mission.detail;
    if (detail is Map && detail['type'] == 'textbook_view') {
      final bookId = detail['textbook_id']?.toString() ?? '';
      final from = _safeInt(detail['page_from'], fallback: 1);
      final to = _safeInt(detail['page_to'], fallback: from);
      final minMinutes = _safeInt(detail['min_minutes'], fallback: 0);
      final enforceMinMinutes = detail['enforce_min_minutes'] == true;
      final moduleId = _resolveModuleId(
        detail,
        _course.id,
        bookId,
        from,
        to,
        mission.title,
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TeacherCourseTextbookReaderPage(
            courseId: widget.course.id,
            moduleId: moduleId,
            textbookId: bookId,
            pageFrom: from,
            pageTo: to,
            minMinutes: minMinutes,
            enforceMinMinutes: enforceMinMinutes,
          ),
        ),
      );
      if (mounted) {
        unawaited(_loadCourseDetail(showLoading: false));
      }
      return;
    }
    if (detail is Map && detail['type'] == 'problem_solve') {
      _startProblemSolve(unit, detail);
      return;
    }
    if (detail is Map && detail['type'] == 'exam_solve') {
      _startExamSolve(unit, detail);
      return;
    }
    if (detail is Map && detail['type'] == 'level_test') {
      _startLevelTest(unit, detail);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${unit.title} · ${mission.title} 학습을 시작합니다.')),
    );
  }

  int _safeInt(dynamic value, {required int fallback}) {
    try {
      if (value == null) return fallback;
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value.toString());
      return parsed ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  String _resolveModuleId(
    Map detail,
    String courseId,
    String textbookId,
    int pageFrom,
    int pageTo,
    String missionTitle,
  ) {
    final direct = detail['module_id']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final detailId = detail['moduleId']?.toString().trim();
    if (detailId != null && detailId.isNotEmpty) return detailId;
    final mission = detail['mission_id']?.toString().trim();
    if (mission != null && mission.isNotEmpty) return mission;
    return '${courseId}_${textbookId}_${pageFrom}_${pageTo}_${missionTitle.hashCode}';
  }

  Future<void> _startProblemSolve(CourseUnit unit, Map detail) async {
    final scaffold = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final moduleId =
          (detail['id'] ?? detail['module_id'] ?? detail['moduleId'] ?? '')
              .toString();
      final problems = moduleId.isNotEmpty
          ? await ApiClient.instance.loadCourseProblemSolve(
              courseId: _course.id,
              moduleId: moduleId,
            )
          : await ApiClient.instance.fetchUnitProblems(
              courseId: _course.id,
              unitIndex: _course.units.indexOf(unit),
            );
      final quests = (problems['quests'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (quests.isEmpty) {
        scaffold.showSnackBar(const SnackBar(content: Text('문제를 불러오지 못했습니다.')));
        return;
      }
      final passRate =
          (problems['pass_rate'] as num?)?.toInt() ??
          (detail['pass_rate'] as num?)?.toInt() ??
          90;
      final hashTags = (detail['hash_tags'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      final config = ProblemSolveConfig(
        questionCount: quests.length,
        hashTags: hashTags,
        gradeImmediately: true,
        minDifficultyTier: (detail['difficulty_tier'] as num?)?.toInt() ?? 3,
        maxDifficultyTier: (detail['difficulty_tier'] as num?)?.toInt() ?? 3,
        passRate: passRate,
        courseId: _course.id,
        unitIndex: _course.units.indexOf(unit),
        quests: quests,
        onComplete:
            ({
              required int correctCount,
              required int totalCount,
              required bool passed,
              int? elapsedSeconds,
            }) async {
              if (moduleId.isEmpty) return;
              await ApiClient.instance.submitCourseRuntimeModule(
                courseId: _course.id,
                moduleId: moduleId,
                correctCount: correctCount,
                totalCount: totalCount,
                elapsedSeconds: elapsedSeconds ?? 0,
              );
              if (mounted) {
                unawaited(_loadCourseDetail(showLoading: false));
              }
            },
      );
      await navigator.push(
        MaterialPageRoute(builder: (_) => BuildpageWidget(config: config)),
      );
      if (mounted) {
        unawaited(_loadCourseDetail(showLoading: false));
      }
    } catch (e) {
      scaffold.showSnackBar(SnackBar(content: Text('문제 로드 실패: $e')));
    }
  }

  Future<void> _startExamSolve(CourseUnit unit, Map detail) async {
    final examId = detail['exam_id']?.toString() ?? '';
    final duration = (detail['exam_duration'] as num?)?.toInt();
    final moduleId =
        (detail['id'] ?? detail['module_id'] ?? detail['moduleId'] ?? '')
            .toString();
    final passRate = _safeInt(detail['pass_rate'], fallback: 100).clamp(0, 100);
    if (examId.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExamPaperPage(
            examId: examId,
            courseId: _course.id,
            moduleId: moduleId,
            passRate: passRate,
            timeLimitMinutes: (duration != null && duration > 0)
                ? duration
                : null,
          ),
        ),
      );
      if (mounted) {
        unawaited(_loadCourseDetail(showLoading: false));
      }
      return;
    }
    final scaffold = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final problems = await ApiClient.instance.fetchUnitProblems(
        courseId: _course.id,
        unitIndex: _course.units.indexOf(unit),
      );
      final quests = (problems['quests'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (quests.isEmpty) {
        scaffold.showSnackBar(
          const SnackBar(content: Text('시험 문제를 불러오지 못했습니다.')),
        );
        return;
      }
      final config = ProblemSolveConfig(
        questionCount: quests.length,
        hashTags: const <String>[],
        gradeImmediately: true,
        minDifficultyTier: 1,
        maxDifficultyTier: 5,
        passRate: 100,
        courseId: _course.id,
        unitIndex: _course.units.indexOf(unit),
        quests: quests,
      );
      navigator.push(
        MaterialPageRoute(builder: (_) => BuildpageWidget(config: config)),
      );
    } catch (e) {
      scaffold.showSnackBar(SnackBar(content: Text('시험 문제 로드 실패: $e')));
    }
  }

  Future<void> _startLevelTest(CourseUnit unit, Map detail) async {
    final moduleId =
        (detail['id'] ?? detail['module_id'] ?? detail['moduleId'] ?? '')
            .toString();
    final config = LevelTestConfig.fromJson(Map<String, dynamic>.from(detail))
        .copyWith(
          testType: 'exam',
          moduleId: moduleId,
          courseId: _course.id,
          unitIndex: _course.units.indexOf(unit),
        );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LevelTestWidget(
          config: config,
          onComplete:
              ({
                required int correctCount,
                required int totalCount,
                required bool passed,
                int? elapsedSeconds,
              }) async {
                if (moduleId.isEmpty) return;
                await ApiClient.instance.submitCourseRuntimeModule(
                  courseId: _course.id,
                  moduleId: moduleId,
                  correctCount: correctCount,
                  totalCount: totalCount,
                  elapsedSeconds: elapsedSeconds ?? 0,
                );
              },
        ),
      ),
    );
  }

  /// 필요 변수: 현재 Navigator의 이전 경로 존재 여부를 사용한다.
  /// 작동 원리: 이전 코스 화면으로 돌아가며, 단독 진입인 경우 코스 목록을 대체 경로로 제공한다.
  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const CourseCatalogPage()),
    );
  }

  /// 필요한 변수는 최신 코스·펼친 단원·화면 폭이다.
  /// HTML 순서인 제목, 전체 진행, 현재 학습, 코스 경로를 유지하면서 기존 미션 라우팅을 연결한다.
  @override
  Widget build(BuildContext context) {
    final course = _course;
    final mobile = isStudentDensityMobile(context);
    return Scaffold(
      key: const ValueKey('course-learning-screen'),
      backgroundColor: StudentDensityTokens.background,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            if (!mobile)
              Builder(
                builder: (context) => Ios26TopBar(
                  brandColor: StudentDensityTokens.dark,
                  onMenu: () => Scaffold.of(context).openDrawer(),
                  onTitleTap: () =>
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/student/dashboard',
                        (route) => false,
                      ),
                  showLevelIndicator: false,
                  items: studentTopNavItems(
                    context,
                    active: StudentTopDestination.courses,
                  ),
                ),
              ),
            Expanded(
              child: _loadingCourse
                  ? const Center(child: CircularProgressIndicator())
                  : mobile
                  ? _MobileCourseLearningBody(
                      course: course,
                      expandedUnits: _expandedUnits,
                      onBack: _goBack,
                      onToggleUnit: _toggleUnit,
                      onMissionTap: _handleMissionTap,
                    )
                  : SingleChildScrollView(
                      child: StudentDensityPage(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _LearningHeading(course: course, onBack: _goBack),
                            const SizedBox(height: 16),
                            _LearningHero(course: course),
                            const SizedBox(height: 10),
                            _CurrentLearning(
                              course: course,
                              onMissionTap: _handleMissionTap,
                            ),
                            const SizedBox(height: 42),
                            const StudentDensityEyebrow('COURSE ROUTE'),
                            const SizedBox(height: 10),
                            const Text(
                              '코스 진행 경로',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.2,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              '현재 단원은 자동으로 펼쳐집니다. 단원을 눌러 미션을 확인하세요.',
                              style: TextStyle(
                                fontSize: 12,
                                color: StudentDensityTokens.muted,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _RouteLegend(),
                            const SizedBox(height: 12),
                            for (
                              var index = 0;
                              index < course.units.length;
                              index++
                            )
                              _LearningUnitCard(
                                unit: course.units[index],
                                scale: 1,
                                isExpanded: _expandedUnits.contains(index),
                                onToggle: () => _toggleUnit(index),
                                onMissionTap: (mission) => _handleMissionTap(
                                  course.units[index],
                                  mission,
                                ),
                              ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileCourseLearningBody extends StatelessWidget {
  const _MobileCourseLearningBody({
    required this.course,
    required this.expandedUnits,
    required this.onBack,
    required this.onToggleUnit,
    required this.onMissionTap,
  });

  final Course course;
  final Set<int> expandedUnits;
  final VoidCallback onBack;
  final ValueChanged<int> onToggleUnit;
  final Future<void> Function(CourseUnit, CourseUnitMission) onMissionTap;

  /// 필요한 변수는 최신 코스, 펼친 단원, 이동·미션 콜백이다.
  /// 작동 원리: 모바일에서는 브랜드 앱바를 제거하고 실제 코스 데이터로 만든 개요,
  /// 현재 학습, 학습 기록, 단일 경로 목록을 한 손 스크롤 순서로 배치한다.
  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentCourseUnitIndex(course);
    final currentUnit = currentIndex < 0 ? null : course.units[currentIndex];
    final currentMission = currentUnit == null || currentUnit.missions.isEmpty
        ? null
        : currentUnit.missions.first;

    return SingleChildScrollView(
      key: const ValueKey('course-learning-mobile'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MobileLearningNavigation(onBack: onBack),
          const SizedBox(height: 24),
          _MobileCourseOverview(course: course),
          const SizedBox(height: 14),
          _MobileCurrentLearningCard(
            course: course,
            unit: currentUnit,
            mission: currentMission,
            unitIndex: currentIndex,
            onStart: currentUnit == null || currentMission == null
                ? null
                : () => onMissionTap(currentUnit, currentMission),
          ),
          const SizedBox(height: 14),
          _MobileCourseStats(course: course),
          const SizedBox(height: 30),
          const Text(
            '학습 순서',
            style: TextStyle(
              fontSize: 27,
              height: 1.12,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            '완료한 단계와 다음 학습을 한눈에 확인하세요.',
            style: TextStyle(
              color: StudentDensityTokens.muted,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            key: const ValueKey('course-learning-mobile-route'),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: course.units.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(22),
                    child: Text(
                      '등록된 학습 단계가 없습니다.',
                      style: TextStyle(
                        color: StudentDensityTokens.muted,
                        fontSize: 14,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (
                        var index = 0;
                        index < course.units.length;
                        index++
                      ) ...[
                        _MobileCourseUnitTile(
                          index: index,
                          unit: course.units[index],
                          expanded: expandedUnits.contains(index),
                          onToggle: () => onToggleUnit(index),
                          onMissionTap: (mission) =>
                              onMissionTap(course.units[index], mission),
                        ),
                        if (index != course.units.length - 1)
                          const Divider(
                            height: 1,
                            indent: 72,
                            color: StudentDensityTokens.line,
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _MobileLearningNavigation extends StatelessWidget {
  const _MobileLearningNavigation({required this.onBack});

  final VoidCallback onBack;

  /// 필요한 변수는 코스 목록 복귀 콜백이다.
  /// 작동 원리: 모바일 상세 화면에 필요한 뒤로가기와 목록 행동만 48px 터치 영역으로
  /// 남겨 큰 브랜드 앱바와 중복 목록 버튼을 대체한다.
  @override
  Widget build(BuildContext context) {
    Widget action({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 48, height: 48, child: Icon(icon, size: 24)),
          ),
        ),
      );
    }

    return Row(
      children: [
        action(icon: Icons.arrow_back_rounded, label: '이전 화면', onTap: onBack),
        const SizedBox(width: 13),
        const Expanded(
          child: Text(
            '코스 학습',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
        ),
        action(icon: Icons.grid_view_rounded, label: '코스 목록', onTap: onBack),
      ],
    );
  }
}

class _MobileCourseOverview extends StatelessWidget {
  const _MobileCourseOverview({required this.course});

  final Course course;

  /// 필요한 변수는 코스 제목·설명·문맥 라벨·전체 진행률이다.
  /// 작동 원리: 서버 응답만 사용해 코스를 소개하고 큰 진행 숫자 대신 제목과 설명을
  /// 먼저 읽은 뒤 현재 진도를 확인하도록 정보 순서를 정리한다.
  @override
  Widget build(BuildContext context) {
    final labels = _courseContextLabels(course, limit: 3);
    final progress = course.progress.clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    final completed = course.units
        .where((unit) => unit.status == CourseUnitStatus.completed)
        .length;

    return Container(
      key: const ValueKey('course-learning-mobile-overview'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (labels.isNotEmpty) ...[
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [for (final label in labels) _LearningPill(label)],
            ),
            const SizedBox(height: 17),
          ],
          Text(
            course.title,
            style: const TextStyle(
              fontSize: 31,
              height: 1.08,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.3,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            _courseDisplaySummary(course),
            style: const TextStyle(
              color: StudentDensityTokens.muted,
              fontSize: 14,
              height: 1.5,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const Spacer(),
              Text(
                '$completed/${course.units.length}단계 완료',
                style: const TextStyle(
                  color: StudentDensityTokens.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: StudentDensityTokens.surfaceMuted,
              color: StudentDensityTokens.dark,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileCurrentLearningCard extends StatelessWidget {
  const _MobileCurrentLearningCard({
    required this.course,
    required this.unit,
    required this.mission,
    required this.unitIndex,
    required this.onStart,
  });

  final Course course;
  final CourseUnit? unit;
  final CourseUnitMission? mission;
  final int unitIndex;
  final VoidCallback? onStart;

  /// 필요한 변수는 현재 단원·첫 미션·실행 콜백이다.
  /// 작동 원리: 현재 해야 할 학습 하나만 어두운 고대비 카드에 표시하고 미션 유형에
  /// 맞는 서버 행동명을 사용해 교재·문제·시험을 같은 문구로 부르지 않는다.
  @override
  Widget build(BuildContext context) {
    final detail = mission?.detail;
    final type = detail is Map ? detail['type']?.toString() ?? '' : '';
    final topic = _currentLearningTopic(course, unit);
    final title = unit?.title.trim().isNotEmpty == true
        ? unit!.title.trim()
        : course.title;
    final missionTitle = mission?.title.trim() ?? '';

    return Container(
      key: const ValueKey('course-learning-mobile-current'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: StudentDensityTokens.dark,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            unitIndex < 0
                ? '다음 학습'
                : '현재 학습 ${unitIndex + 1}/${course.units.length}',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              height: 1.15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            missionTitle.isEmpty
                ? topic
                : '$topic · $missionTitle${type.isEmpty ? '' : ' · ${_moduleTypeLabel(type)}'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(_missionActionLabel(mission)),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: Colors.white,
                foregroundColor: StudentDensityTokens.ink,
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () => showCoursePolicyDialog(context),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: const Text('완료 조건 확인'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileCourseStats extends StatelessWidget {
  const _MobileCourseStats({required this.course});

  final Course course;

  /// 필요한 변수는 서버 누적 시간과 단원 완료 상태다.
  /// 작동 원리: 별도 대형 카드 대신 같은 면 안의 두 지표로 압축해 현재 학습 행동보다
  /// 기록이 먼저 보이지 않도록 한다.
  @override
  Widget build(BuildContext context) {
    final completed = course.units
        .where((unit) => unit.status == CourseUnitStatus.completed)
        .length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MobileCourseStat(
              label: '학습 시간',
              value: _formatCourseElapsedTime(_courseElapsedSeconds(course)),
            ),
          ),
          Container(width: 1, height: 40, color: StudentDensityTokens.line),
          Expanded(
            child: _MobileCourseStat(
              label: '완료한 단계',
              value: '$completed/${course.units.length}',
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileCourseStat extends StatelessWidget {
  const _MobileCourseStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(
          color: StudentDensityTokens.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        value,
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
    ],
  );
}

class _MobileCourseUnitTile extends StatelessWidget {
  const _MobileCourseUnitTile({
    required this.index,
    required this.unit,
    required this.expanded,
    required this.onToggle,
    required this.onMissionTap,
  });

  final int index;
  final CourseUnit unit;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<CourseUnitMission> onMissionTap;

  /// 필요한 변수는 단원 순번·상태·미션과 펼침 콜백이다.
  /// 작동 원리: 단원을 하나의 그룹 행으로 표시하고 펼쳤을 때만 실제 미션 행동을
  /// 노출하며 잠긴 단원의 실행은 차단한다.
  @override
  Widget build(BuildContext context) {
    final status = _statusFor(unit.status);
    final canExpand = unit.missions.isNotEmpty;
    final locked = unit.status == CourseUnitStatus.locked;
    return Column(
      children: [
        InkWell(
          onTap: canExpand ? onToggle : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 17, 14, 17),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: locked
                        ? StudentDensityTokens.surfaceMuted
                        : StudentDensityTokens.dark,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: locked
                      ? const Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: StudentDensityTokens.muted,
                        )
                      : Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unit.title,
                        style: TextStyle(
                          color: locked
                              ? StudentDensityTokens.muted
                              : StudentDensityTokens.ink,
                          fontSize: 15,
                          height: 1.25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_moduleTypeLabel(unit.type)} · ${status.label}${unit.estimatedMinutes > 0 ? ' · ${unit.estimatedMinutes}분' : ''}',
                        style: const TextStyle(
                          color: StudentDensityTokens.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canExpand)
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: StudentDensityTokens.muted,
                  ),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              children: [
                for (final mission in unit.missions)
                  _MobileMissionRow(
                    mission: mission,
                    locked: locked,
                    onTap: () => onMissionTap(mission),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MobileMissionRow extends StatelessWidget {
  const _MobileMissionRow({
    required this.mission,
    required this.locked,
    required this.onTap,
  });

  final CourseUnitMission mission;
  final bool locked;
  final VoidCallback onTap;

  /// 필요한 변수는 미션 제목·유형·잠금 상태와 실행 콜백이다.
  /// 작동 원리: 미션 정보를 넓은 터치 행 하나로 묶고 서버 행동명을 오른쪽에 표시한다.
  @override
  Widget build(BuildContext context) {
    final detail = mission.detail;
    final type = detail is Map ? detail['type']?.toString() ?? '' : '';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: StudentDensityTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: locked ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (type.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          _moduleTypeLabel(type),
                          style: const TextStyle(
                            color: StudentDensityTokens.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  locked ? '잠김' : _missionActionLabel(mission),
                  style: TextStyle(
                    color: locked
                        ? StudentDensityTokens.muted
                        : StudentDensityTokens.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.chevron_right_rounded, size: 19),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LearningHero extends StatelessWidget {
  const _LearningHero({required this.course});

  final Course course;

  /// 필요한 변수는 코스 설명·태그·전체 진행률과 화면 폭이다.
  /// 데스크톱은 1fr/300px, 모바일은 본문/118px 비율로 HTML 진행 히어로를 구성한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final compactDesktop = _isCourseLearningCompactDesktop(context);
    final tags = _courseContextLabels(course);
    return ClipRRect(
      borderRadius: BorderRadius.circular(mobile ? 22 : 28),
      child: Container(
        height: mobile ? 130 : (compactDesktop ? 300 : 252),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(
                  mobile ? 17 : (compactDesktop ? 24 : 30),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in tags.take(
                          mobile ? 2 : (compactDesktop ? 3 : 4),
                        ))
                          _LearningPill(tag),
                      ],
                    ),
                    SizedBox(height: mobile ? 9 : (compactDesktop ? 12 : 16)),
                    Text(
                      _courseDisplaySummary(course),
                      maxLines: mobile ? 3 : (compactDesktop ? 3 : 4),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: mobile ? 22 : (compactDesktop ? 34 : 40),
                        height: .98,
                        letterSpacing: -1.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (!mobile) ...[
                      SizedBox(height: compactDesktop ? 18 : 28),
                      const Text(
                        '교재, 문제, 레벨 테스트와 시험을 정해진 학습 순서로 이어갑니다.',
                        style: TextStyle(
                          fontSize: 12,
                          color: StudentDensityTokens.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(
              width: mobile ? 118 : (compactDesktop ? 240 : 300),
              child: _LearningProgress(course: course, mobile: mobile),
            ),
          ],
        ),
      ),
    );
  }
}

class _LearningHeading extends StatelessWidget {
  const _LearningHeading({required this.course, required this.onBack});

  final Course course;
  final VoidCallback onBack;

  /// 필요한 변수는 코스 제목과 목록 복귀 콜백이다.
  /// HTML 페이지 헤더에서 모바일 버튼은 아래 전체 폭, 데스크톱 버튼은 우측에 배치한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final copy = StudentDensityPageHeader(
      eyebrow: 'ACTIVE COURSE',
      title: course.title,
      description: '현재 학습 위치에서 이어가고, 단원별 미션과 잠금 조건을 원래 흐름대로 확인하세요.',
    );
    final button = OutlinedButton(
      onPressed: onBack,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(mobile ? double.infinity : 88, 44),
        foregroundColor: StudentDensityTokens.ink,
        side: const BorderSide(color: StudentDensityTokens.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: const Text('코스 목록', style: TextStyle(fontWeight: FontWeight.w800)),
    );
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [copy, const SizedBox(height: 16), button],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: copy),
        button,
      ],
    );
  }
}

class _LearningProgress extends StatelessWidget {
  const _LearningProgress({required this.course, required this.mobile});

  final Course course;
  final bool mobile;

  /// 필요한 변수는 전체 진행률·유닛 상태·모바일 여부다.
  /// 진행률 숫자와 막대를 표시하고 PC에서만 완료 미션·현재 단원·OVR 지표를 추가한다.
  @override
  Widget build(BuildContext context) {
    final percent = (course.progress * 100).round();
    final completed = course.units
        .where((unit) => unit.status == CourseUnitStatus.completed)
        .length;
    final active = course.units.indexWhere(
      (unit) => unit.status == CourseUnitStatus.active,
    );
    return Container(
      padding: EdgeInsets.all(mobile ? 15 : 24),
      color: StudentDensityTokens.surfaceMuted,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mobile) const StudentDensityEyebrow('COURSE PROGRESS'),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$percent',
                  style: TextStyle(
                    fontSize: mobile ? 40 : 58,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -3,
                  ),
                ),
                TextSpan(
                  text: '%',
                  style: TextStyle(
                    fontSize: mobile ? 18 : 22,
                    color: StudentDensityTokens.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: course.progress,
              minHeight: 7,
              backgroundColor: StudentDensityTokens.line,
              color: StudentDensityTokens.dark,
            ),
          ),
          if (!mobile) ...[
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ProgressMeta(
                    '$completed / ${course.units.length}',
                    '완료 미션',
                  ),
                ),
                Expanded(
                  child: _ProgressMeta(
                    '${(active < 0 ? 0 : active + 1).toString().padLeft(2, '0')} / ${course.units.length.toString().padLeft(2, '0')}',
                    '현재 단원',
                  ),
                ),
                Expanded(
                  child: _ProgressMeta(
                    course.targetOvr > 0 ? '${course.targetOvr}' : '미설정',
                    '목표 OVR',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressMeta extends StatelessWidget {
  const _ProgressMeta(this.value, this.label);

  final String value;
  final String label;

  /// 필요한 변수는 진행 지표 값과 이름이다.
  /// PC 히어로 하단의 세 가지 소형 지표를 동일한 열로 표시한다.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 5),
      Text(
        label,
        style: const TextStyle(fontSize: 8, color: StudentDensityTokens.muted),
      ),
    ],
  );
}

class _LearningPill extends StatelessWidget {
  const _LearningPill(this.label);

  final String label;

  /// 필요한 변수는 학년·과목·태그 문구다.
  /// HTML 학습 히어로의 작은 연회색 캡슐로 표시한다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: StudentDensityTokens.surfaceMuted,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
    ),
  );
}

class _CurrentLearning extends StatelessWidget {
  const _CurrentLearning({required this.course, required this.onMissionTap});

  final Course course;
  final Future<void> Function(CourseUnit, CourseUnitMission) onMissionTap;

  /// 필요한 변수는 활성 유닛·첫 미션·미션 이동 콜백이다.
  /// 현재 학습의 제목·행동과 학습 시간을 PC 가로, 모바일 세로 카드로 재배치한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final compactDesktop = _isCourseLearningCompactDesktop(context);
    final currentIndex = _currentCourseUnitIndex(course);
    final index = currentIndex < 0 ? 0 : currentIndex;
    final unit = currentIndex < 0 ? null : course.units[currentIndex];
    final mission = unit == null || unit.missions.isEmpty
        ? null
        : unit.missions.first;
    final detail = unit?.detail;
    final rawDescription = detail is Map
        ? detail['description']?.toString().trim()
        : null;
    final description = rawDescription == null || rawDescription.isEmpty
        ? (course.description.trim().isNotEmpty
              ? course.description.trim()
              : '중단한 현재 학습 위치부터 이어서 진행합니다.')
        : rawDescription;
    final elapsedSeconds = _courseElapsedSeconds(course);
    final progress = course.progress.clamp(0.0, 1.0);
    final missionButton = FilledButton(
      onPressed: mission == null ? null : () => onMissionTap(unit!, mission),
      style: FilledButton.styleFrom(
        backgroundColor: StudentDensityTokens.dark,
        minimumSize: const Size(108, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(
        _missionActionLabel(mission),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
    final policyButton = OutlinedButton(
      onPressed: () => showCoursePolicyDialog(context),
      child: const Text('완료 조건'),
    );
    final main = Padding(
      padding: EdgeInsets.all(mobile ? 18 : 30),
      child: Row(
        children: [
          Container(
            width: mobile ? 54 : 78,
            height: mobile ? 54 : 78,
            decoration: BoxDecoration(
              color: StudentDensityTokens.dark,
              borderRadius: BorderRadius.circular(mobile ? 18 : 24),
            ),
            alignment: Alignment.center,
            child: Text(
              '현재 학습 · ${(index + 1).toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StudentDensityEyebrow(
                  'UNIT ${(index + 1).toString().padLeft(2, '0')} · ${_currentLearningTopic(course, unit)}',
                ),
                const SizedBox(height: 10),
                Text(
                  unit?.title.isNotEmpty == true ? unit!.title : course.title,
                  style: TextStyle(
                    fontSize: mobile ? 24 : 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                SizedBox(height: mobile ? 12 : 20),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: mobile ? 10 : 12,
                    height: 1.5,
                    color: StudentDensityTokens.muted,
                  ),
                ),
              ],
            ),
          ),
          if (!mobile && !compactDesktop) ...[
            missionButton,
            const SizedBox(width: 8),
            policyButton,
          ],
        ],
      ),
    );
    final time = Container(
      width: mobile || compactDesktop ? double.infinity : 280,
      padding: EdgeInsets.all(mobile ? 18 : (compactDesktop ? 22 : 26)),
      color: StudentDensityTokens.surfaceMuted,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '학습 시간',
            style: TextStyle(
              fontSize: 10,
              color: StudentDensityTokens.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            _formatCourseElapsedTime(elapsedSeconds),
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            color: StudentDensityTokens.dark,
            backgroundColor: StudentDensityTokens.line,
          ),
          const SizedBox(height: 9),
          const Text(
            '중단해도 마지막 위치와 시간이 보존됩니다.',
            style: TextStyle(fontSize: 9, color: StudentDensityTokens.muted),
          ),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(mobile ? 22 : 28),
      child: Container(
        color: Colors.white,
        child: mobile
            ? Column(
                children: [
                  main,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: mission == null
                              ? null
                              : () => onMissionTap(unit!, mission),
                          style: FilledButton.styleFrom(
                            backgroundColor: StudentDensityTokens.dark,
                            minimumSize: const Size.fromHeight(44),
                          ),
                          child: Text(_missionActionLabel(mission)),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => showCoursePolicyDialog(context),
                          child: const Text('완료 조건'),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  time,
                ],
              )
            : compactDesktop
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  main,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(30, 0, 30, 22),
                    child: Row(
                      children: [
                        Expanded(child: missionButton),
                        const SizedBox(width: 8),
                        policyButton,
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  time,
                ],
              )
            : SizedBox(
                height: 190,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: main),
                    time,
                  ],
                ),
              ),
      ),
    );
  }
}

class _RouteLegend extends StatelessWidget {
  /// 필요한 변수는 고정된 완료·진행·잠금 상태다.
  /// 코스 경로 위에 HTML과 동일한 세 점 범례를 오른쪽 정렬한다.
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Wrap(
      spacing: 12,
      children: const [
        _LegendDot(Color(0xFF8A8A90), '완료'),
        _LegendDot(StudentDensityTokens.dark, '진행'),
        _LegendDot(Color(0xFFD4D4D8), '잠금'),
      ],
    ),
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.color, this.label);

  final Color color;
  final String label;

  /// 필요한 변수는 상태 색상과 이름이다.
  /// 8px 원과 짧은 상태 문구를 한 행으로 표시한다.
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(fontSize: 9, color: StudentDensityTokens.muted),
      ),
    ],
  );
}

class _LearningUnitCard extends StatelessWidget {
  const _LearningUnitCard({
    required this.unit,
    required this.scale,
    required this.isExpanded,
    required this.onToggle,
    required this.onMissionTap,
  });

  final CourseUnit unit;
  final double scale;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ValueChanged<CourseUnitMission> onMissionTap;

  @override
  Widget build(BuildContext context) {
    final status = _statusFor(unit.status);
    final detail = unit.detail;
    String subtitle = _moduleTypeLabel(unit.type);
    if (detail is Map) {
      if (detail['type'] == 'textbook_view') {
        subtitle = _textbookRangeLabel(detail);
      } else if (detail['type'] == 'problem_solve') {
        final tags = (detail['hash_tags'] as List?)?.join(', ') ?? '';
        subtitle = '문제 풀이 · 태그: $tags';
      } else if (detail['type'] == 'exam_solve') {
        final duration = (detail['exam_duration'] as num?)?.toInt();
        subtitle = duration == null || duration <= 0
            ? '문제풀이 예상 시간 미제공'
            : '문제풀이 예상: $duration분';
      }
    }
    final canExpand = unit.missions.isNotEmpty;
    final arrowIcon = isExpanded
        ? Icons.keyboard_arrow_up_rounded
        : Icons.keyboard_arrow_down_rounded;

    return Container(
      margin: EdgeInsets.only(bottom: 12 * scale),
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * scale),
        boxShadow: const [_shadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38 * scale,
                height: 38 * scale,
                decoration: BoxDecoration(
                  color: status.badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12 * scale),
                ),
                child: Icon(
                  status.icon,
                  color: status.badgeColor,
                  size: 20 * scale,
                ),
              ),
              SizedBox(width: 12 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            unit.title,
                            style: GoogleFonts.inter(
                              fontSize: 16 * scale,
                              fontWeight: FontWeight.w600,
                              color: _green,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10 * scale,
                            vertical: 4 * scale,
                          ),
                          decoration: BoxDecoration(
                            color: status.badgeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14 * scale),
                          ),
                          child: Text(
                            status.label,
                            style: GoogleFonts.inter(
                              fontSize: 11 * scale,
                              color: status.badgeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6 * scale),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13 * scale,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8 * scale),
                    Row(
                      children: [
                        _MetaPill(
                          label: _moduleTypeLabel(unit.type),
                          icon: Icons.category_outlined,
                          scale: scale,
                        ),
                        SizedBox(width: 8 * scale),
                        if (unit.estimatedMinutes > 0)
                          _MetaPill(
                            label: '${unit.estimatedMinutes}분',
                            icon: Icons.timer_outlined,
                            scale: scale,
                          ),
                      ],
                    ),
                    if (unit.progress != null) ...[
                      SizedBox(height: 10 * scale),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6 * scale),
                        child: LinearProgressIndicator(
                          value: unit.progress,
                          minHeight: 6 * scale,
                          backgroundColor: const Color(0xFFE2E2E2),
                          color: _lightGreen,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8 * scale),
              IconButton(
                icon: Icon(arrowIcon, color: canExpand ? _green : Colors.grey),
                onPressed: canExpand ? onToggle : null,
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: EdgeInsets.only(top: 16 * scale),
              child: _MissionList(
                unit: unit,
                scale: scale,
                onMissionTap: onMissionTap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _textbookRangeLabel(Map detail) {
    final from = _positivePage(detail['page_from']);
    final to = _positivePage(detail['page_to']);
    if (from != null && to != null) {
      if (from == to) return '교재 열람 ${from.toString()}P';
      return '교재 열람 ${from.toString()}~${to.toString()}P';
    }
    if (from != null) return '교재 열람 ${from.toString()}P부터';
    if (to != null) return '교재 열람 ${to.toString()}P까지';
    return '교재 열람';
  }

  int? _positivePage(dynamic value) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }
}

class _MissionList extends StatelessWidget {
  const _MissionList({
    required this.unit,
    required this.scale,
    required this.onMissionTap,
  });

  final CourseUnit unit;
  final double scale;
  final ValueChanged<CourseUnitMission> onMissionTap;

  @override
  Widget build(BuildContext context) {
    if (unit.missions.isEmpty) {
      return Text(
        '등록된 미션이 없습니다.',
        style: GoogleFonts.inter(fontSize: 13 * scale, color: Colors.black54),
      );
    }

    final isLocked = unit.status == CourseUnitStatus.locked;
    return Column(
      children: [
        for (final mission in unit.missions)
          Container(
            margin: EdgeInsets.only(bottom: 10 * scale),
            padding: EdgeInsets.all(14 * scale),
            decoration: BoxDecoration(
              color: _bgGrey,
              borderRadius: BorderRadius.circular(14 * scale),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission.title,
                        style: GoogleFonts.inter(
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.w600,
                          color: _green,
                        ),
                      ),
                      SizedBox(height: 4 * scale),
                      Text(
                        mission.detail is Map
                            ? _moduleTypeLabel(
                                mission.detail['type']?.toString() ?? '',
                              )
                            : mission.detail.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 12 * scale,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12 * scale),
                ElevatedButton(
                  onPressed: isLocked ? null : () => onMissionTap(mission),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    minimumSize: Size(110 * scale, 38 * scale),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12 * scale),
                    ),
                  ),
                  child: Text(
                    mission.actionLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    required this.icon,
    required this.scale,
  });

  final String label;
  final IconData icon;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 6 * scale,
      ),
      decoration: BoxDecoration(
        color: _bgGrey,
        borderRadius: BorderRadius.circular(16 * scale),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14 * scale, color: Colors.black54),
          SizedBox(width: 6 * scale),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11 * scale,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusData {
  const _StatusData({
    required this.label,
    required this.badgeColor,
    required this.icon,
  });

  final String label;
  final Color badgeColor;
  final IconData icon;
}

_StatusData _statusFor(CourseUnitStatus status) {
  switch (status) {
    case CourseUnitStatus.completed:
      return const _StatusData(
        label: '완료',
        badgeColor: Color(0xFF8A8A90),
        icon: Icons.check_circle,
      );
    case CourseUnitStatus.active:
      return const _StatusData(
        label: '진행 중',
        badgeColor: StudentDensityTokens.dark,
        icon: Icons.play_circle_fill,
      );
    case CourseUnitStatus.locked:
      return const _StatusData(
        label: '잠금',
        badgeColor: Color(0xFF9A9A9A),
        icon: Icons.lock,
      );
  }
}

String _moduleTypeLabel(String type) {
  switch (type) {
    case 'textbook_view':
      return '교재 열람';
    case 'problem_solve':
      return '문제 풀이';
    case 'exam_solve':
      return '시험지 풀이';
    case 'level_test':
      return '레벨 테스트';
    case 'wrong_answer_review':
      return '오답 복습';
    case 'challenge_group':
      return '도전 학습';
    case 'curriculum_group':
      return '커리큘럼';
    default:
      return type.trim().isEmpty ? '학습 모듈' : type;
  }
}
