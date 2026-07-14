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

class CourseLearningPage extends StatefulWidget {
  const CourseLearningPage({super.key, required this.course});

  final Course course;

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
      final full = await CourseService.fetchCourse(widget.course.id);
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
    return Scaffold(
      key: const ValueKey('course-learning-screen'),
      backgroundColor: StudentDensityTokens.background,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (context) => Ios26TopBar(
                brandColor: StudentDensityTokens.dark,
                onMenu: () => Scaffold.of(context).openDrawer(),
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

class _LearningHero extends StatelessWidget {
  const _LearningHero({required this.course});

  final Course course;

  /// 필요한 변수는 코스 설명·태그·전체 진행률과 화면 폭이다.
  /// 데스크톱은 1fr/300px, 모바일은 본문/118px 비율로 HTML 진행 히어로를 구성한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final tags = course.focusTags.isEmpty
        ? const ['중학교 2학년', '수학', '#일차함수', '#그래프']
        : ['중학교 2학년', '수학', ...course.focusTags];
    return ClipRRect(
      borderRadius: BorderRadius.circular(mobile ? 22 : 28),
      child: Container(
        height: mobile ? 130 : 252,
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
                padding: EdgeInsets.all(mobile ? 17 : 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in tags.take(mobile ? 2 : 4))
                          _LearningPill(tag),
                      ],
                    ),
                    SizedBox(height: mobile ? 9 : 16),
                    Text(
                      '일차함수의 개념부터\n그래프 실전까지',
                      style: TextStyle(
                        fontSize: mobile ? 22 : 40,
                        height: .98,
                        letterSpacing: -1.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (!mobile) ...[
                      const SizedBox(height: 28),
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
              width: mobile ? 118 : 300,
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
                const Expanded(child: _ProgressMeta('18.6', 'MY OVR')),
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
    final activeIndex = course.units.indexWhere(
      (unit) => unit.status == CourseUnitStatus.active,
    );
    final index = activeIndex < 0 ? 0 : activeIndex;
    final unit = course.units.isEmpty ? null : course.units[index];
    final mission = unit == null || unit.missions.isEmpty
        ? null
        : unit.missions.first;
    final detail = unit?.detail;
    final rawDescription = detail is Map
        ? detail['description']?.toString().trim()
        : null;
    final description = rawDescription == null || rawDescription.isEmpty
        ? '두 점의 변화량을 비교해 직선의 기울기를 이해합니다. 중단한 위치부터 이어집니다.'
        : rawDescription;
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
                  'UNIT ${(index + 1).toString().padLeft(2, '0')} · 그래프 이해',
                ),
                const SizedBox(height: 10),
                Text(
                  unit?.title ?? '기울기의 의미',
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
          if (!mobile) ...[
            FilledButton(
              onPressed: mission == null
                  ? null
                  : () => onMissionTap(unit!, mission),
              style: FilledButton.styleFrom(
                backgroundColor: StudentDensityTokens.dark,
                minimumSize: const Size(108, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text(
                '교재 이어보기',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => showCoursePolicyDialog(context),
              child: const Text('완료 조건'),
            ),
          ],
        ],
      ),
    );
    final time = Container(
      width: mobile ? double.infinity : 280,
      padding: EdgeInsets.all(mobile ? 18 : 26),
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
          const Text(
            '05:12',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          const LinearProgressIndicator(
            value: .62,
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
                          child: const Text('교재 이어보기'),
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
