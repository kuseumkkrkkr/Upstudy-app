import 'dart:async';

import 'package:flutter/material.dart';

import 'package:s11/sessions/course/session/course_learning_page.dart';
import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/shared/data/models/course.dart';
import 'package:s11/shared/services/api/course_service.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

/// HTML 시안의 코스 상세 구조와 실제 수강 상태를 결합하는 화면이다.
class CourseDetailPage extends StatefulWidget {
  const CourseDetailPage({super.key, required this.course});

  final Course course;

  /// 필요한 변수는 최초 코스 요약이다.
  /// 요약을 즉시 표시하고 서버 상세를 덮어쓸 상태 객체를 생성한다.
  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  late Course _course;
  bool _loadingCourse = false;
  bool _enrolling = false;

  /// 필요한 변수는 최초 코스와 코스 식별자다.
  /// 화면 조회 활동을 비동기로 남기고 유닛이 없을 때만 로딩 표시와 함께 상세를 조회한다.
  @override
  void initState() {
    super.initState();
    _course = widget.course;
    unawaited(
      ActivityStore.recordCourseView(
        courseId: widget.course.id,
        courseNumber: (widget.course.id.hashCode & 0xFFFF).toString(),
        screen: 'detail',
      ).catchError((_) {}),
    );
    unawaited(_loadCourseDetail(showLoading: _course.units.isEmpty));
  }

  /// 필요한 변수는 코스 ID와 로딩 표시 여부다.
  /// 최신 상세를 한 번 조회해 등록·완료·유닛 상태를 화면의 단일 코스 객체에 반영한다.
  Future<void> _loadCourseDetail({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loadingCourse = true);
    try {
      final full = await CourseService.fetchCourse(widget.course.id);
      if (!mounted) return;
      setState(() => _course = full);
    } finally {
      if (mounted && showLoading) setState(() => _loadingCourse = false);
    }
  }

  /// 필요한 변수는 현재 코스의 등록·완료·데모 상태다.
  /// 등록된 코스는 즉시 학습으로 이동하고 미등록 코스만 등록 API를 한 번 호출한다.
  Future<void> _enrollAndGo() async {
    if (_course.isDemo || _course.isCompleted || _enrolling) return;
    if (_course.isEnrolled) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CourseLearningPage(course: _course)),
      );
      return;
    }
    setState(() => _enrolling = true);
    try {
      final enrolled = await CourseService.enroll(_course.id);
      if (!mounted) return;
      setState(() => _course = enrolled);
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CourseLearningPage(course: enrolled)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('수강 신청에 실패했습니다.')));
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  /// 필요한 변수는 첫 코스 유닛과 현재 화면 문맥이다.
  /// 등록 전 미리보기에서는 서버 상태를 변경하지 않고 첫 학습 구성만 대화상자로 보여준다.
  void _showPreview() {
    final first = _course.units.isEmpty ? null : _course.units.first;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('코스 미리보기'),
        content: Text(
          first == null
              ? '공개된 학습 구성이 아직 없습니다.'
              : '${first.title}\n${_unitSubtitle(first)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  /// 필요한 변수는 최신 코스와 화면 폭이다.
  /// HTML의 제목·행동·4분할 지표·학습 흐름·정보 순서를 데스크톱과 모바일에 그대로 배치한다.
  @override
  Widget build(BuildContext context) {
    final course = _course;
    final completed = course.isCompleted;
    final canStart = !course.isDemo && !completed;
    final actionLabel = completed
        ? '완료한 코스 · 미리보기'
        : course.isEnrolled
        ? '코스 계속하기'
        : '코스 등록';
    return Scaffold(
      key: const ValueKey('course-detail-screen'),
      backgroundColor: StudentDensityTokens.background,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (context) => Ios26TopBar(
                brandColor: StudentDensityTokens.dark,
                onMenu: () => Scaffold.of(context).openDrawer(),
                onTitleTap: () => Navigator.of(context).pushNamedAndRemoveUntil(
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
                  : SingleChildScrollView(
                      child: StudentDensityPage(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _DetailHeading(
                              course: course,
                              actionLabel: actionLabel,
                              actionEnabled: canStart,
                              enrolling: _enrolling,
                              onAction: _enrollAndGo,
                              onPreview: _showPreview,
                            ),
                            const SizedBox(height: 16),
                            _MetricGrid(course: course),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final mobile = constraints.maxWidth <= 780;
                                final flow = _LearningFlow(course: course);
                                final info = _CourseInfo(course: course);
                                if (mobile) {
                                  return Column(
                                    children: [
                                      flow,
                                      const SizedBox(height: 14),
                                      info,
                                    ],
                                  );
                                }
                                return IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(flex: 7, child: flow),
                                      const SizedBox(width: 14),
                                      Expanded(flex: 3, child: info),
                                    ],
                                  ),
                                );
                              },
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

class _DetailHeading extends StatelessWidget {
  const _DetailHeading({
    required this.course,
    required this.actionLabel,
    required this.actionEnabled,
    required this.enrolling,
    required this.onAction,
    required this.onPreview,
  });

  final Course course;
  final String actionLabel;
  final bool actionEnabled;
  final bool enrolling;
  final VoidCallback onAction;
  final VoidCallback onPreview;

  /// 필요한 변수는 코스 제목·설명·행동 상태와 화면 폭이다.
  /// 데스크톱은 행동을 제목 우측에, 모바일은 제목 아래 두 개의 전체 폭 버튼으로 표시한다.
  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= 780;
    final description = course.description.trim().isEmpty
        ? '개념 교재부터 실전 시험, 오답 복습까지 하나의 상태 머신으로 이어지는 코스입니다.'
        : course.description;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StudentDensityEyebrow('COURSE 01'),
        const SizedBox(height: 8),
        Text(
          course.title,
          style: TextStyle(
            fontSize: mobile ? 32 : 52,
            height: .96,
            letterSpacing: -2,
            fontWeight: FontWeight.w900,
            color: StudentDensityTokens.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(
            fontSize: mobile ? 12 : 14,
            color: StudentDensityTokens.muted,
          ),
        ),
      ],
    );
    final buttons = mobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _DetailButton(
                label: actionLabel,
                dark: true,
                busy: enrolling,
                onPressed: actionEnabled ? onAction : onPreview,
              ),
              const SizedBox(height: 8),
              _DetailButton(label: '미리보기', onPressed: onPreview),
            ],
          )
        : Row(
            children: [
              _DetailButton(
                label: actionLabel,
                dark: true,
                busy: enrolling,
                onPressed: actionEnabled ? onAction : onPreview,
              ),
              const SizedBox(width: 10),
              _DetailButton(label: '미리보기', onPressed: onPreview),
            ],
          );
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [copy, buttons],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: copy),
        buttons,
      ],
    );
  }
}

class _DetailButton extends StatelessWidget {
  const _DetailButton({
    required this.label,
    required this.onPressed,
    this.dark = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool dark;
  final bool busy;

  /// 필요한 변수는 버튼 문구·강조 상태·로딩 상태다.
  /// HTML의 44px 캡슐 행동을 흑백 표면과 1px 테두리로 재현한다.
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: dark ? StudentDensityTokens.dark : Colors.white,
          foregroundColor: dark ? Colors.white : StudentDensityTokens.ink,
          disabledBackgroundColor: StudentDensityTokens.dark,
          side: dark
              ? BorderSide.none
              : const BorderSide(color: StudentDensityTokens.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: busy
            ? const SizedBox.square(
                dimension: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.course});

  final Course course;

  /// 필요한 변수는 코스 추천도·모듈 수·기간·완료 통계다.
  /// 데스크톱 4열과 모바일 2×2의 경계를 하나의 흰 카드 안에서 만든다.
  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= 780;
    final metrics = <({String label, String value, String note})>[
      (label: '추천 적합도', value: '91%', note: 'OVR 16–22'),
      (
        label: '모듈',
        value: '${course.units.isEmpty ? 12 : course.units.length}',
        note: '교재 4 · 문제 6 · 시험 2',
      ),
      (
        label: '예상 기간',
        value: course.duration.isEmpty ? '3주' : course.duration,
        note: '주 4회 기준',
      ),
      (label: '완료 학생', value: '1,284', note: '평균 4.8점'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = mobile ? 2 : 4;
        final aspectRatio = mobile ? 2.1 : 2.3;
        // 390과 desktop 전환 직후 폭에서는 기존 비율이 텍스트보다 낮은 셀을 만든다.
        // 넓은 화면의 기존 비율은 유지하고, 필요한 경우에만 최소 높이를 보장한다.
        final naturalExtent = constraints.maxWidth / columns / aspectRatio;
        final mainAxisExtent = mobile
            ? (naturalExtent < 120 ? 120.0 : null)
            : (constraints.maxWidth < 900 ? 168.0 : null);
        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border.fromBorderSide(
                BorderSide(color: StudentDensityTokens.line),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 28,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                childAspectRatio: aspectRatio,
                mainAxisExtent: mainAxisExtent,
              ),
              itemCount: metrics.length,
              itemBuilder: (context, index) {
                final item = metrics[index];
                return Container(
                  padding: EdgeInsets.all(mobile ? 14 : 20),
                  decoration: BoxDecoration(
                    border: Border(
                      left: index % columns == 0
                          ? BorderSide.none
                          : const BorderSide(color: StudentDensityTokens.line),
                      top: mobile && index >= 2
                          ? const BorderSide(color: StudentDensityTokens.line)
                          : BorderSide.none,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: StudentDensityTokens.muted,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        item.value,
                        style: TextStyle(
                          fontSize: mobile ? 30 : 40,
                          height: .95,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        item.note,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _LearningFlow extends StatelessWidget {
  const _LearningFlow({required this.course});

  final Course course;

  /// 필요한 변수는 코스 유닛 목록과 화면 폭이다.
  /// 최대 네 개의 대표 모듈을 HTML의 첫 행 강조 목록으로 표시한다.
  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= 780;
    final units = course.units.isEmpty
        ? _fallbackUnits()
        : course.units.take(4).toList();
    return StudentDensitySurface(
      radius: mobile ? 24 : 28,
      padding: EdgeInsets.all(mobile ? 20 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '학습 흐름',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                ),
              ),
              _Pill(
                '${course.units.isEmpty ? 12 : course.units.length} modules',
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < units.length; index++) ...[
            _UnitRow(unit: units[index], index: index, active: index == 0),
            if (index != units.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _UnitRow extends StatelessWidget {
  const _UnitRow({
    required this.unit,
    required this.index,
    required this.active,
  });

  final CourseUnit unit;
  final int index;
  final bool active;

  /// 필요한 변수는 유닛·순번·강조 여부다.
  /// 첫 학습만 검은 배경과 재생 아이콘을 사용하고 나머지는 흰 테두리 행으로 표시한다.
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: active ? StudentDensityTokens.dark : Colors.white,
        border: active ? null : Border.all(color: StudentDensityTokens.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: active ? Colors.white : StudentDensityTokens.surfaceMuted,
              border: Border.all(color: StudentDensityTokens.line),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: active
                ? const Icon(
                    Icons.play_arrow_rounded,
                    size: 30,
                    color: StudentDensityTokens.ink,
                  )
                : const Text(
                    '·',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${(index + 1).toString().padLeft(2, '0')} · ${unit.title}',
                  style: TextStyle(
                    color: active ? Colors.white : StudentDensityTokens.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _unitSubtitle(unit),
                  style: TextStyle(
                    color: active ? Colors.white60 : StudentDensityTokens.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: active ? Colors.white : StudentDensityTokens.ink,
          ),
        ],
      ),
    );
  }
}

class _CourseInfo extends StatelessWidget {
  const _CourseInfo({required this.course});

  final Course course;

  /// 필요한 변수는 코스 태그와 학년·과목 메타다.
  /// HTML 오른쪽 정보 카드의 설명·태그·runtime 안내를 작은 세로 묶음으로 표시한다.
  @override
  Widget build(BuildContext context) {
    final tags = course.focusTags.isEmpty
        ? const ['#일차함수', '#그래프', '#기울기', '#서술형']
        : course.focusTags
              .take(4)
              .map((tag) => tag.startsWith('#') ? tag : '#$tag')
              .toList();
    return StudentDensitySurface(
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '코스 정보',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Text(
            'AIFlow 수학 연구팀 · 중학교 2학년 · 수학',
            style: TextStyle(fontSize: 12, color: StudentDensityTokens.muted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [for (final tag in tags) _Pill(tag)],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: StudentDensityTokens.surfaceMuted,
              border: Border.all(color: StudentDensityTokens.line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              '등록 전 공개 메타와 등록 후 runtime state를 분리 조회합니다.',
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color: StudentDensityTokens.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);

  final String label;

  /// 필요한 변수는 짧은 상태 문구다.
  /// 흐름 수와 태그를 동일한 연회색 캡슐로 표시한다.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: StudentDensityTokens.surfaceMuted,
        border: Border.all(color: StudentDensityTokens.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: StudentDensityTokens.muted,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// 필요한 변수는 코스 유닛의 상세 type과 설정값이다.
/// 교재·문제·레벨 테스트·시험을 HTML 목록의 짧은 보조 문구로 변환한다.
String _unitSubtitle(CourseUnit unit) {
  final detail = unit.detail;
  final type = detail is Map
      ? detail['type']?.toString() ?? unit.type
      : unit.type;
  switch (type) {
    case 'textbook_view':
      return '교재 · 최소 ${(detail is Map ? detail['min_minutes'] : null) ?? 8}분';
    case 'problem_solve':
      return '문제 풀이 · ${(detail is Map ? detail['question_count'] : null) ?? 10}문항';
    case 'level_test':
      return '레벨 테스트 · 통과 ${(detail is Map ? detail['pass_rate'] : null) ?? 80}%';
    case 'exam_solve':
      return '시험 · ${(detail is Map ? detail['question_count'] : null) ?? 20}문항';
    default:
      return type.trim().isEmpty ? '학습 모듈' : type;
  }
}

/// 필요한 변수는 실제 유닛이 없는 미리보기 상태다.
/// HTML 시안과 동일한 네 가지 대표 타입을 읽기 전용 CourseUnit으로 생성한다.
List<CourseUnit> _fallbackUnits() {
  return const [
    CourseUnit(
      title: '함수의 뜻',
      type: 'textbook_view',
      detail: {'type': 'textbook_view', 'min_minutes': 8},
      status: CourseUnitStatus.active,
      missions: [],
    ),
    CourseUnit(
      title: '좌표와 그래프',
      type: 'problem_solve',
      detail: {'type': 'problem_solve', 'question_count': 10},
      status: CourseUnitStatus.locked,
      missions: [],
    ),
    CourseUnit(
      title: '기울기',
      type: 'level_test',
      detail: {'type': 'level_test', 'pass_rate': 80},
      status: CourseUnitStatus.locked,
      missions: [],
    ),
    CourseUnit(
      title: '일차함수 실전',
      type: 'exam_solve',
      detail: {'type': 'exam_solve', 'question_count': 20},
      status: CourseUnitStatus.locked,
      missions: [],
    ),
  ];
}
