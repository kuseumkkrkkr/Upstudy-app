import 'package:flutter/material.dart';

import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

import 'models.dart';
import 'student_runtime_service.dart';

/// 학생 런타임의 레거시 명명 경로를 HTML 코스 학습 시안과 같은 쉘로 제공한다.
class StudentRuntimePage extends StatefulWidget {
  const StudentRuntimePage({super.key, this.initialCourses});

  static const routeName = '/student/runtime';

  /// 캡처·위젯 검증에서만 주입하는 고정 런타임 데이터다.
  /// null이면 실제 서비스의 캐시·API 경로를 그대로 사용한다.
  final List<RuntimeCourseModel>? initialCourses;

  @override
  State<StudentRuntimePage> createState() => _StudentRuntimePageState();
}

class _StudentRuntimePageState extends State<StudentRuntimePage> {
  List<RuntimeCourseModel> _courses = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialCourses != null) {
      _courses = List<RuntimeCourseModel>.unmodifiable(widget.initialCourses!);
      _loading = false;
      return;
    }
    _loadCourses();
  }

  /// 필요한 변수는 런타임 코스 API 응답이다.
  /// 작동 원리: 기존 서비스의 20초 캐시·장애 시 샘플 데이터 정책을 그대로 사용하고 화면 상태만 갱신한다.
  Future<void> _loadCourses() async {
    final courses = await StudentRuntimeService.instance.loadEnrolledCourses();
    if (!mounted) return;
    setState(() {
      _courses = courses;
      _loading = false;
    });
  }

  /// 필요한 변수는 수강 코스 모듈의 상태 순서다.
  /// 작동 원리: HTML의 현재 학습 카드에는 첫 번째 수강 가능 모듈을 우선 표시하고 없으면 첫 모듈을 사용한다.
  RuntimeModuleModel? _currentModule(RuntimeCourseModel? course) {
    if (course == null || course.modules.isEmpty) return null;
    return course.modules.cast<RuntimeModuleModel?>().firstWhere(
      (module) => module?.status == 'available',
      orElse: () => course.modules.first,
    );
  }

  /// 필요한 변수는 선택한 코스·모듈과 기존 런타임 시작 서비스다.
  /// 작동 원리: 시작 전 설명 시트를 열고, 확인 시에만 기존 next-module 요청을 수행해 레거시 계약을 보존한다.
  void _openModule(RuntimeCourseModel course, RuntimeModuleModel module) {
    if (module.status == 'locked') return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _RuntimeModuleSheet(
        course: course,
        module: module,
        onStart: () async {
          Navigator.of(sheetContext).pop();
          final started = await StudentRuntimeService.instance.startSession(
            course.id,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                started
                    ? '${module.title} 학습을 시작했습니다.'
                    : '학습을 시작하지 못했습니다. 잠시 후 다시 시도해 주세요.',
              ),
            ),
          );
        },
      ),
    );
  }

  /// 필요한 변수는 현재 Navigator와 코스 명명 라우트다.
  /// 작동 원리: 상세 런타임 데이터가 없는 레거시 진입은 실제 CourseLearningPage로 이어지는 코스 목록으로 보낸다.
  void _openCourseCatalog() => Navigator.of(context).pushNamed('/courses');

  @override
  Widget build(BuildContext context) {
    final course = _courses.isEmpty ? null : _courses.first;
    final current = _currentModule(course);
    return Scaffold(
      key: const ValueKey('student-runtime-screen'),
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
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: StudentDensityPage(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _RuntimeHeading(onOpenCatalog: _openCourseCatalog),
                            const SizedBox(height: 16),
                            _RuntimeHero(course: course),
                            const SizedBox(height: 10),
                            _CurrentRuntimeCard(
                              course: course,
                              module: current,
                              onOpen: current == null || course == null
                                  ? _openCourseCatalog
                                  : () => _openModule(course, current),
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
                            const SizedBox(height: 8),
                            const Text(
                              '현재 학습은 먼저 표시하고, 잠긴 미션은 이전 미션 완료 후 열립니다.',
                              style: TextStyle(
                                color: StudentDensityTokens.muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (course == null)
                              _EmptyRuntime(onOpenCatalog: _openCourseCatalog)
                            else
                              _RuntimeModuleList(
                                course: course,
                                onOpen: (module) => _openModule(course, module),
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

class _RuntimeHeading extends StatelessWidget {
  const _RuntimeHeading({required this.onOpenCatalog});

  final VoidCallback onOpenCatalog;

  /// 필요한 변수는 코스 탐색 이동 콜백과 화면 폭이다.
  /// 작동 원리: HTML 학습 화면의 ACTIVE COURSE 제목과 우측 코스 목록 행동을 모바일에서 세로 배치한다.
  @override
  Widget build(BuildContext context) => StudentDensityPageHeader(
    eyebrow: 'ACTIVE COURSE',
    title: '코스 학습',
    description: '현재 학습 위치에서 이어가고 단원별 미션과 잠금 조건을 확인하세요.',
    action: StudentDensityButton(
      label: '코스 목록',
      icon: Icons.grid_view_rounded,
      onPressed: onOpenCatalog,
    ),
  );
}

class _RuntimeHero extends StatelessWidget {
  const _RuntimeHero({required this.course});

  final RuntimeCourseModel? course;

  /// 필요한 변수는 코스 제목·완료율·현재 화면 폭이다.
  /// 작동 원리: PC는 설명과 진행률을 2열, 모바일은 118px 진행 패널로 압축해 HTML의 런타임 헤더 비율을 맞춘다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final progress = ((course?.overallProgress ?? 0) / 100).clamp(0.0, 1.0);
    final copy = Padding(
      padding: EdgeInsets.all(mobile ? 17 : 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            children: const [_RuntimePill('수강 중'), _RuntimePill('학습 경로')],
          ),
          SizedBox(height: mobile ? 9 : 16),
          Text(
            course?.title ?? '진행 중인 코스가 없습니다',
            maxLines: mobile ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: mobile ? 22 : 40,
              height: .98,
              letterSpacing: mobile ? -1.5 : -2.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (!mobile) ...[
            const SizedBox(height: 12),
            const Text(
              '교재, 문제, 시험과 복습을 정해진 학습 순서로 이어갑니다.',
              style: TextStyle(color: StudentDensityTokens.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
    final progressPanel = Container(
      width: mobile ? 118 : 300,
      padding: EdgeInsets.all(mobile ? 15 : 24),
      decoration: const BoxDecoration(
        color: StudentDensityTokens.dark,
        border: Border(left: BorderSide(color: StudentDensityTokens.line)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mobile)
            const StudentDensityEyebrow(
              'COURSE PROGRESS',
              color: Colors.white70,
            ),
          Text(
            '${(progress * 100).round()}%',
            style: TextStyle(
              color: Colors.white,
              fontSize: mobile ? 40 : 58,
              height: 1,
              letterSpacing: mobile ? -2 : -3,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: Colors.white,
              backgroundColor: Colors.white24,
            ),
          ),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(mobile ? 22 : 28),
      child: SizedBox(
        height: mobile ? 126 : 190,
        child: Row(
          children: [
            Expanded(child: copy),
            progressPanel,
          ],
        ),
      ),
    );
  }
}

class _RuntimePill extends StatelessWidget {
  const _RuntimePill(this.label);

  final String label;

  /// 필요한 변수는 짧은 코스 문맥 라벨이다.
  /// 작동 원리: 런타임 헤더의 작은 회색 캡슐을 공용 토큰으로 표시한다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: StudentDensityTokens.surfaceMuted,
      border: Border.all(color: StudentDensityTokens.line),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
    ),
  );
}

class _CurrentRuntimeCard extends StatelessWidget {
  const _CurrentRuntimeCard({
    required this.course,
    required this.module,
    required this.onOpen,
  });

  final RuntimeCourseModel? course;
  final RuntimeModuleModel? module;
  final VoidCallback onOpen;

  /// 필요한 변수는 현재 모듈·코스 진행률·시작 콜백이다.
  /// 작동 원리: HTML의 현재 학습 카드에서 현재 미션을 먼저 보여 주고, 모듈이 없으면 코스 탐색 행동으로 안전하게 바꾼다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final hasModule = module != null && course != null;
    return StudentDensitySurface(
      padding: EdgeInsets.all(mobile ? 17 : 24),
      color: StudentDensityTokens.dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StudentDensityEyebrow(
            'CURRENT LEARNING',
            color: Colors.white70,
          ),
          const SizedBox(height: 8),
          Text(
            hasModule ? module!.title : '학습할 코스를 선택하세요',
            style: TextStyle(
              color: Colors.white,
              fontSize: mobile ? 25 : 34,
              letterSpacing: -1.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasModule
                ? '${_moduleLabel(module!.moduleType)} · ${_statusLabel(module!.status)}'
                : '코스 목록에서 수강 중인 코스를 선택하면 현재 단원이 자동으로 열립니다.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onOpen,
              icon: Icon(
                hasModule ? Icons.play_arrow_rounded : Icons.grid_view_rounded,
              ),
              label: Text(hasModule ? '현재 학습 이어보기' : '코스 목록 보기'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: StudentDensityTokens.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRuntime extends StatelessWidget {
  const _EmptyRuntime({required this.onOpenCatalog});

  final VoidCallback onOpenCatalog;

  /// 필요한 변수는 코스 탐색 이동 콜백이다.
  /// 작동 원리: 수강 데이터가 없는 경우에도 빈 목록 대신 다음 행동을 하나만 노출한다.
  @override
  Widget build(BuildContext context) => StudentDensitySurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '아직 수강 중인 코스가 없습니다.',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          '코스 탐색에서 내 학습 경로를 선택해 보세요.',
          style: TextStyle(color: StudentDensityTokens.muted),
        ),
        const SizedBox(height: 16),
        StudentDensityButton(
          label: '코스 탐색',
          primary: true,
          onPressed: onOpenCatalog,
        ),
      ],
    ),
  );
}

class _RuntimeModuleList extends StatelessWidget {
  const _RuntimeModuleList({required this.course, required this.onOpen});

  final RuntimeCourseModel course;
  final ValueChanged<RuntimeModuleModel> onOpen;

  /// 필요한 변수는 코스의 정렬된 모듈과 선택 콜백이다.
  /// 작동 원리: 모듈별 완료·진행·잠금 상태를 HTML의 세로 경로 카드로 유지하고 잠긴 모듈은 탭을 차단한다.
  @override
  Widget build(BuildContext context) => StudentDensitySurface(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var index = 0; index < course.modules.length; index++) ...[
          _RuntimeModuleRow(
            index: index,
            module: course.modules[index],
            onTap: () => onOpen(course.modules[index]),
          ),
          if (index != course.modules.length - 1)
            const Divider(height: 1, color: StudentDensityTokens.line),
        ],
      ],
    ),
  );
}

class _RuntimeModuleRow extends StatelessWidget {
  const _RuntimeModuleRow({
    required this.index,
    required this.module,
    required this.onTap,
  });

  final int index;
  final RuntimeModuleModel module;
  final VoidCallback onTap;

  /// 필요한 변수는 순번·모듈 상태·선택 콜백이다.
  /// 작동 원리: 상태 색상 대신 흑백 번호 배지와 텍스트를 사용하고, 잠김 상태에는 열기 행동을 숨긴다.
  @override
  Widget build(BuildContext context) {
    final locked = module.status == 'locked';
    final completed = module.status == 'completed';
    return InkWell(
      onTap: locked ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: completed
                    ? StudentDensityTokens.dark
                    : StudentDensityTokens.surfaceMuted,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                completed
                    ? Icons.check_rounded
                    : _moduleIcon(module.moduleType),
                size: 18,
                color: completed
                    ? Colors.white
                    : (locked
                          ? StudentDensityTokens.faint
                          : StudentDensityTokens.ink),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${(index + 1).toString().padLeft(2, '0')} · ${module.title}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: locked
                          ? StudentDensityTokens.muted
                          : StudentDensityTokens.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_moduleLabel(module.moduleType)} · ${_statusLabel(module.status)}',
                    style: const TextStyle(
                      color: StudentDensityTokens.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _statusLabel(module.status),
              style: TextStyle(
                color: locked
                    ? StudentDensityTokens.faint
                    : StudentDensityTokens.ink,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
              color: locked
                  ? StudentDensityTokens.faint
                  : StudentDensityTokens.ink,
            ),
          ],
        ),
      ),
    );
  }
}

class _RuntimeModuleSheet extends StatelessWidget {
  const _RuntimeModuleSheet({
    required this.course,
    required this.module,
    required this.onStart,
  });

  final RuntimeCourseModel course;
  final RuntimeModuleModel module;
  final VoidCallback onStart;

  /// 필요한 변수는 선택 코스·모듈·시작 콜백이다.
  /// 작동 원리: HTML의 빠른 선택은 모달에서 확인하고 실제 시작 요청은 확인 버튼 하나로 제한한다.
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      decoration: const BoxDecoration(
        color: StudentDensityTokens.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: StudentDensityTokens.lineStrong,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 22),
          StudentDensityEyebrow(
            '${course.title} · ${_moduleLabel(module.moduleType)}',
          ),
          const SizedBox(height: 8),
          Text(
            module.title,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '학습을 시작하면 현재 런타임 상태를 다시 확인해 다음 미션을 준비합니다.',
            style: TextStyle(color: StudentDensityTokens.muted, fontSize: 13),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: StudentDensityButton(
              label: '학습 시작',
              primary: true,
              icon: Icons.play_arrow_rounded,
              onPressed: onStart,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 필요한 변수는 런타임 모듈 종류다.
/// 작동 원리: 각 유형의 실제 진입 계약을 짧은 사용자 문구로 변환해 목록과 모달에서 일관되게 사용한다.
String _moduleLabel(RuntimeModuleType type) => switch (type) {
  RuntimeModuleType.textbookView => '교재 학습',
  RuntimeModuleType.problemSolve => '문제 풀이',
  RuntimeModuleType.examSolve => '시험 풀이',
  RuntimeModuleType.wrongAnswerReview => '오답 복습',
  RuntimeModuleType.challenge => '코스 챌린지',
  RuntimeModuleType.levelTest => '레벨 테스트',
};

/// 필요한 변수는 서버 런타임 상태 문자열이다.
/// 작동 원리: 서버의 영문 상태를 시안에 사용하는 짧은 한국어 상태로만 변환하며 상태 전이 자체는 변경하지 않는다.
String _statusLabel(String status) => switch (status) {
  'completed' => '완료',
  'available' => '학습 중',
  _ => '잠김',
};

/// 필요한 변수는 모듈 유형이다.
/// 작동 원리: 목록의 40px 아이콘은 유형별 콘텐츠를 구분하는 보조 표현이며 실제 라우팅 판단에는 사용하지 않는다.
IconData _moduleIcon(RuntimeModuleType type) => switch (type) {
  RuntimeModuleType.textbookView => Icons.menu_book_outlined,
  RuntimeModuleType.problemSolve => Icons.edit_note_rounded,
  RuntimeModuleType.examSolve => Icons.assignment_outlined,
  RuntimeModuleType.wrongAnswerReview => Icons.replay_rounded,
  RuntimeModuleType.challenge => Icons.emoji_events_outlined,
  RuntimeModuleType.levelTest => Icons.query_stats_rounded,
};
