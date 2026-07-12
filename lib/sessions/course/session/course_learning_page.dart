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
import 'package:s11/sessions/legacy_cleanup/session/study_center.dart'
    show StudyCenterNavBar;
import 'teacher_course_textbook_reader_page.dart';

const _green = Color(0xFF1B402B);
const _lightGreen = Color(0xFF45BF63);
const _bgGrey = Color(0xFFF7F7F7);
const _shadow = BoxShadow(
  blurRadius: 6,
  color: Color(0x1A000000),
  offset: Offset(0, 3),
);

double _uiScale(BuildContext context, {double min = 0.6, double max = 1.0}) {
  final width = MediaQuery.of(context).size.width;
  final scale = width / 1100;
  if (scale < min) return min;
  if (scale > max) return max;
  return scale;
}

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

  void _startLearning() {
    if (widget.course.isDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('체험용 코스입니다. 진행률은 기록되지 않습니다.')),
      );
    }
    final index = _course.units.indexWhere(
      (unit) => unit.status != CourseUnitStatus.locked,
    );
    if (index == -1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('수강 가능한 유닛이 아직 없습니다.')));
      return;
    }
    setState(() => _expandedUnits.add(index));
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
    if (examId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExamPaperPage(
            examId: examId,
            courseId: _course.id,
            timeLimitMinutes: (duration != null && duration > 0)
                ? duration
                : null,
          ),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    final course = _course;
    final progressPercent = (course.progress * 100).round();
    final isDemo = course.isDemo;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loadingCourse
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const StudyCenterNavBar(),
                    _LearningHero(
                      course: course,
                      scale: scale,
                      progressPercent: progressPercent,
                      onPrimaryAction: isDemo ? null : _startLearning,
                      isDemo: isDemo,
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        30 * scale,
                        24 * scale,
                        30 * scale,
                        40 * scale,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '코스 진행 경로',
                            style: GoogleFonts.inter(
                              fontSize: 28 * scale,
                              fontWeight: FontWeight.w700,
                              color: _green,
                            ),
                          ),
                          SizedBox(height: 10 * scale),
                          Text(
                            '유닛을 펼쳐 상세 미션을 확인하고 차례대로 수강하세요.',
                            style: GoogleFonts.inter(
                              fontSize: 14 * scale,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: 18 * scale),
                          for (var i = 0; i < course.units.length; i++)
                            _LearningUnitCard(
                              unit: course.units[i],
                              scale: scale,
                              isExpanded: _expandedUnits.contains(i),
                              onToggle: () => _toggleUnit(i),
                              onMissionTap: (mission) =>
                                  _handleMissionTap(course.units[i], mission),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _LearningHero extends StatelessWidget {
  const _LearningHero({
    required this.course,
    required this.scale,
    required this.progressPercent,
    required this.onPrimaryAction,
    required this.isDemo,
  });

  final Course course;
  final double scale;
  final int progressPercent;
  final VoidCallback? onPrimaryAction;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        final heroHeight = isNarrow ? 420 * scale : 320 * scale;
        final detailBlock = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              course.title,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 38 * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 10 * scale),
            Text(
              course.description,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 16 * scale,
                height: 1.4,
              ),
            ),
            SizedBox(height: 18 * scale),
            Wrap(
              spacing: 8 * scale,
              runSpacing: 6 * scale,
              children: course.focusTags
                  .map(
                    (tag) => Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10 * scale,
                        vertical: 4 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16 * scale),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11 * scale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
        final progressCard = Container(
          width: isNarrow ? double.infinity : 240 * scale,
          padding: EdgeInsets.all(18 * scale),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18 * scale),
            boxShadow: const [_shadow],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '전체 진행률',
                style: GoogleFonts.inter(
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w600,
                  color: _green,
                ),
              ),
              SizedBox(height: 12 * scale),
              ClipRRect(
                borderRadius: BorderRadius.circular(8 * scale),
                child: LinearProgressIndicator(
                  value: course.progress,
                  minHeight: 10 * scale,
                  backgroundColor: const Color(0xFFE4E4E4),
                  color: _lightGreen,
                ),
              ),
              SizedBox(height: 8 * scale),
              Text(
                '$progressPercent% 완료',
                style: GoogleFonts.inter(
                  fontSize: 12 * scale,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: 16 * scale),
              ElevatedButton(
                onPressed: onPrimaryAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 46 * scale),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12 * scale),
                  ),
                ),
                child: Text(
                  isDemo ? '체험 모드' : '학습 계속하기',
                  style: GoogleFonts.inter(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

        return SizedBox(
          height: heroHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF183D2B), Color(0xFF2A6B4B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 30 * scale),
                child: isNarrow
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          detailBlock,
                          SizedBox(height: 20 * scale),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 420 * scale),
                            child: progressCard,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: detailBlock),
                          SizedBox(width: 20 * scale),
                          progressCard,
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
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
        badgeColor: Color(0xFF2EAD62),
        icon: Icons.check_circle,
      );
    case CourseUnitStatus.active:
      return const _StatusData(
        label: '진행 중',
        badgeColor: Color(0xFFF3A43A),
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
