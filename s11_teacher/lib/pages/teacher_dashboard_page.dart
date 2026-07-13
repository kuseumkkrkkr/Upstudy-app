import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../shared/theme/app_colors.dart';
import '../shared/ui/ios26/ios26_chrome.dart';
import '../shared/ui/ios26/teacher_studio_shell.dart';
import '../widgets/design_tokens.dart';
import 'course_builder_page.dart';
import 'course_list_page.dart';
import 'exam_paper_builder_page.dart';
import 'group_study/group_study.dart';
import 'problem_editor_page.dart';
import 'teacher_document_center_page.dart';
import 'teacher_operations_page.dart';

class TeacherDashboardPage extends StatelessWidget {
  const TeacherDashboardPage({super.key});

  Future<void> _logout(BuildContext context) async {
    await ApiClient.instance.clearToken();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return TeacherStudioShell(
      currentRoute: '/dashboard',
      eyebrow: 'TEACHER WORKSPACE',
      title: '오늘의 작업',
      description: '자주 쓰는 제작 도구와 수업 관리 기능을 바로 시작하세요.',
      endDrawer: _IosDashboardDrawer(onLogout: () => _logout(context)),
      actions: [
        TeacherStudioAction(
          label: '코스 생성',
          icon: Icons.add_task_rounded,
          primary: true,
          onTap: () => _open(context, const CourseBuilderPage()),
        ),
        TeacherStudioAction(
          label: '문서함',
          icon: Icons.folder_open_rounded,
          onTap: () => _open(context, const TeacherDocumentCenterPage()),
        ),
      ],
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            sliver: _ActionGrid(scaffoldContext: context),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

// ignore: unused_element
class _DashboardBackdrop extends StatelessWidget {
  const _DashboardBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFAFAFB), Color(0xFFEDEDF0)],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

// ignore: unused_element
class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.onCreateCourse,
    required this.onOpenDocuments,
  });

  final VoidCallback onCreateCourse;
  final VoidCallback onOpenDocuments;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 760;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 20,
        compact ? 12 : 18,
        compact ? 12 : 20,
        12,
      ),
      child: Ios26FrostedCard(
        radius: 32,
        padding: EdgeInsets.all(compact ? 18 : 22),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heroCopy(compact: true),
                  const SizedBox(height: 18),
                  _HeroActions(
                    onCreateCourse: onCreateCourse,
                    onOpenDocuments: onOpenDocuments,
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _heroCopy()),
                  const SizedBox(width: 28),
                  SizedBox(
                    width: 360,
                    child: _HeroActions(
                      onCreateCourse: onCreateCourse,
                      onOpenDocuments: onOpenDocuments,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// 필요 변수: 모바일 배치 여부.
  /// 작동 원리: 같은 안내 정보를 유지하면서 작은 화면에서 제목 크기만 낮춘다.
  Widget _heroCopy({bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _GlassChip(icon: Icons.lock_open_rounded, label: '권한 기반 교재'),
            _GlassChip(icon: Icons.auto_stories_rounded, label: '코스 전용 리더'),
            _GlassChip(icon: Icons.timer_rounded, label: '이수 조건 추적'),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          '오늘 수업 흐름을 바로 설계하세요',
          style: TextStyle(
            color: kCourseGreen,
            fontSize: compact ? 28 : 32,
            height: 1.12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '교재는 복사하지 않고 접근 권한만 연결합니다. 코스 생성, 문서함, 문항 제작, 그룹 관리를 한 화면에서 빠르게 시작하세요.',
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.62),
            fontSize: 14,
            height: 1.48,
          ),
        ),
      ],
    );
  }
}

class _HeroActions extends StatelessWidget {
  const _HeroActions({
    required this.onCreateCourse,
    required this.onOpenDocuments,
  });

  final VoidCallback onCreateCourse;
  final VoidCallback onOpenDocuments;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PrimaryAction(
          icon: Icons.add_task_rounded,
          title: '코스 생성',
          subtitle: '교재 보기 모듈과 학습 조건을 구성합니다.',
          onTap: onCreateCourse,
        ),
        const SizedBox(height: 10),
        _PrimaryAction(
          icon: Icons.folder_open_rounded,
          title: '문서함 열기',
          subtitle: '교사가 가진 교재만 조회합니다.',
          onTap: onOpenDocuments,
          quiet: true,
        ),
      ],
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.quiet = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final color = quiet ? kCourseGreen : kCourseLightGreen;
    return Material(
      color: quiet ? Colors.white : kCourseGreen,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: quiet
                  ? Colors.black.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: quiet ? color : Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: quiet ? kCourseGreen : Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: quiet
                            ? Colors.black.withValues(alpha: 0.58)
                            : Colors.white.withValues(alpha: 0.76),
                        fontSize: 12,
                        height: 1.32,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: quiet ? kCourseGreen : Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.scaffoldContext});

  final BuildContext scaffoldContext;

  /// 필요 변수: 교사용 화면의 Navigator 문맥.
  /// 작동 원리: 기능을 같은 크기의 카드로 나열하지 않고 실제 작업 순서인 제작·준비·
  /// 운영 단계로 묶어 다음 행동을 빠르게 판단하도록 한다. 각 항목은 기존 경로만 호출한다.
  @override
  Widget build(BuildContext context) {
    final phases = <_WorkflowPhase>[
      _WorkflowPhase(
        index: '01',
        title: '제작 시작',
        description: '수업에 필요한 핵심 콘텐츠를 먼저 만듭니다.',
        actions: [
          _WorkflowAction(
            icon: Icons.add_task_rounded,
            title: '코스 설계',
            detail: '교재와 이수 조건 구성',
            onTap: () => _push(const CourseBuilderPage()),
          ),
          _WorkflowAction(
            icon: Icons.assignment_rounded,
            title: '시험지 만들기',
            detail: '난이도와 문항 범위 설정',
            onTap: () => _push(const ExamPaperBuilderPage()),
          ),
          _WorkflowAction(
            icon: Icons.edit_note_rounded,
            title: '문항 제작',
            detail: '초안과 변형 문항 작성',
            onTap: () => _push(const ProblemEditorPage()),
          ),
        ],
      ),
      _WorkflowPhase(
        index: '02',
        title: '수업 준비',
        description: '만든 자료를 찾아 수업 흐름에 연결합니다.',
        actions: [
          _WorkflowAction(
            icon: Icons.folder_open_rounded,
            title: '문서함 열기',
            detail: '보유 교재 확인 및 연결',
            onTap: () => _push(const TeacherDocumentCenterPage()),
          ),
          _WorkflowAction(
            icon: Icons.menu_book_rounded,
            title: '코스 관리',
            detail: '공개 상태와 구성 검토',
            onTap: () => _push(const CourseListPage()),
          ),
        ],
      ),
      _WorkflowPhase(
        index: '03',
        title: '운영 확인',
        description: '학생 배정과 수업 진행 상태를 점검합니다.',
        actions: [
          _WorkflowAction(
            icon: Icons.groups_rounded,
            title: '그룹 운영',
            detail: '학생·과제·공지 관리',
            onTap: () => Navigator.of(
              scaffoldContext,
            ).pushNamed(GroupListPage.routeName),
          ),
          _WorkflowAction(
            icon: Icons.analytics_rounded,
            title: '학습 분석',
            detail: '그룹별 진행 현황 확인',
            onTap: () => Navigator.of(
              scaffoldContext,
            ).pushNamed(GroupListPage.routeName),
          ),
          _WorkflowAction(
            icon: Icons.account_balance_wallet_rounded,
            title: '운영 기록',
            detail: '일정과 회계 기록 관리',
            onTap: () => _push(const TeacherOperationsPage()),
          ),
        ],
      ),
    ];

    return SliverToBoxAdapter(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 920;
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFE2E2E6)),
            ),
            child: horizontal
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var index = 0; index < phases.length; index++) ...[
                        Expanded(
                          child: _WorkflowPhaseView(phase: phases[index]),
                        ),
                        if (index != phases.length - 1)
                          const _WorkflowConnector(),
                      ],
                    ],
                  )
                : Column(
                    children: [
                      for (var index = 0; index < phases.length; index++) ...[
                        _WorkflowPhaseView(phase: phases[index]),
                        if (index != phases.length - 1)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Icon(Icons.keyboard_arrow_down_rounded),
                          ),
                      ],
                    ],
                  ),
          );
        },
      ),
    );
  }

  void _push(Widget page) {
    Navigator.of(scaffoldContext).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _WorkflowPhase {
  const _WorkflowPhase({
    required this.index,
    required this.title,
    required this.description,
    required this.actions,
  });

  final String index;
  final String title;
  final String description;
  final List<_WorkflowAction> actions;
}

class _WorkflowAction {
  const _WorkflowAction({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
}

class _WorkflowPhaseView extends StatelessWidget {
  const _WorkflowPhaseView({required this.phase});

  final _WorkflowPhase phase;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                phase.index,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    phase.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    phase.description,
                    style: const TextStyle(color: Colors.black54, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        for (final action in phase.actions) _WorkflowActionRow(action: action),
      ],
    );
  }
}

class _WorkflowActionRow extends StatelessWidget {
  const _WorkflowActionRow({required this.action});

  final _WorkflowAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
          child: Row(
            children: [
              Icon(action.icon, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.detail,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkflowConnector extends StatelessWidget {
  const _WorkflowConnector();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Icon(Icons.arrow_forward_rounded, color: Colors.black26),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: kCourseGreen),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: kCourseGreen,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _IosDashboardDrawer extends StatelessWidget {
  const _IosDashboardDrawer({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Ios26FrostedCard(
                radius: 24,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: kCourseGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '교사용 메뉴',
                            style: TextStyle(
                              color: kCourseGreen,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text('수업 운영 도구'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Ios26FrostedCard(
                  radius: 24,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView(
                    children: [
                      _DrawerAction(
                        icon: Icons.home_rounded,
                        title: '홈',
                        onTap: () => Navigator.pop(context),
                      ),
                      _DrawerAction(
                        icon: Icons.add_task_rounded,
                        title: '코스 생성',
                        onTap: () => _push(context, const CourseBuilderPage()),
                      ),
                      _DrawerAction(
                        icon: Icons.folder_open_rounded,
                        title: '문서함',
                        onTap: () =>
                            _push(context, const TeacherDocumentCenterPage()),
                      ),
                      _DrawerAction(
                        icon: Icons.menu_book_rounded,
                        title: '코스 관리',
                        onTap: () => _push(context, const CourseListPage()),
                      ),
                      _DrawerAction(
                        icon: Icons.edit_note_rounded,
                        title: '문항 제작',
                        onTap: () => _push(context, const ProblemEditorPage()),
                      ),
                      _DrawerAction(
                        icon: Icons.groups_rounded,
                        title: '그룹 관리',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(GroupListPage.routeName),
                      ),
                      _DrawerAction(
                        icon: Icons.logout_rounded,
                        title: '로그아웃',
                        onTap: onLogout,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _DrawerAction extends StatelessWidget {
  const _DrawerAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: kCourseGreen),
      title: Text(
        title,
        style: const TextStyle(
          color: kCourseGreen,
          fontWeight: FontWeight.w800,
        ),
      ),
      onTap: onTap,
    );
  }
}
