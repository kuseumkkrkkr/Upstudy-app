import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../shared/ui/ios26/ios26_chrome.dart';
import '../widgets/design_tokens.dart';
import 'course_builder_page.dart';
import 'course_list_page.dart';
import 'exam_paper_builder_page.dart';
import 'group_study/group_study.dart';
import 'problem_editor_page.dart';
import 'teacher_document_center_page.dart';

class TeacherDashboardPage extends StatelessWidget {
  const TeacherDashboardPage({super.key});

  Future<void> _logout(BuildContext context) async {
    await ApiClient.instance.clearToken();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F4),
      endDrawer: _IosDashboardDrawer(onLogout: () => _logout(context)),
      body: Builder(
        builder: (scaffoldContext) {
          return Stack(
            children: [
              const _DashboardBackdrop(),
              SafeArea(
                child: Column(
                  children: [
                    Ios26TopBar(
                      brandColor: kCourseGreen,
                      title: '교사용 홈',
                      onMenu: () =>
                          Scaffold.of(scaffoldContext).openEndDrawer(),
                      items: [
                        const Ios26NavItem(label: '홈', active: true),
                        Ios26NavItem(
                          label: '문서함',
                          onTap: () => _open(
                            scaffoldContext,
                            const TeacherDocumentCenterPage(),
                          ),
                        ),
                        Ios26NavItem(
                          label: '코스',
                          onTap: () =>
                              _open(scaffoldContext, const CourseListPage()),
                        ),
                        Ios26NavItem(
                          label: '문항 제작',
                          onTap: () =>
                              _open(scaffoldContext, const ProblemEditorPage()),
                        ),
                      ],
                      trailingIcons: [
                        Ios26ActionIcon(
                          icon: Icons.add_task_rounded,
                          label: '코스 생성',
                          onTap: () =>
                              _open(scaffoldContext, const CourseBuilderPage()),
                        ),
                        Ios26ActionIcon(
                          icon: Icons.folder_open_rounded,
                          label: '문서함',
                          onTap: () => _open(
                            scaffoldContext,
                            const TeacherDocumentCenterPage(),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: _HeroPanel(
                              onCreateCourse: () => _open(
                                scaffoldContext,
                                const CourseBuilderPage(),
                              ),
                              onOpenDocuments: () => _open(
                                scaffoldContext,
                                const TeacherDocumentCenterPage(),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                            sliver: _ActionGrid(
                              scaffoldContext: scaffoldContext,
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                            sliver: SliverToBoxAdapter(
                              child: _LowerPanels(
                                scaffoldContext: scaffoldContext,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _DashboardBackdrop extends StatelessWidget {
  const _DashboardBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: Color(0xFFF3F7F4)),
      child: SizedBox.expand(),
    );
  }
}

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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Ios26FrostedCard(
        radius: 32,
        padding: const EdgeInsets.all(22),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heroCopy(),
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

  Widget _heroCopy() {
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
        const Text(
          '오늘 수업 흐름을 바로 설계하세요',
          style: TextStyle(
            color: kCourseGreen,
            fontSize: 32,
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
      color: quiet ? Colors.white.withValues(alpha: 0.78) : kCourseGreen,
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final columns = width >= 1180
        ? 4
        : width >= 860
        ? 3
        : width >= 620
        ? 2
        : 1;
    final ratio = width < 620 ? 2.85 : 1.24;
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: ratio,
      ),
      delegate: SliverChildListDelegate.fixed([
        _FeatureTile(
          icon: Icons.add_task_rounded,
          title: '코스 생성',
          subtitle: '페이지 범위, 최소 시간, 교재 권한을 설정합니다.',
          tint: kCourseLightGreen,
          onTap: () => _push(const CourseBuilderPage()),
        ),
        _FeatureTile(
          icon: Icons.folder_open_rounded,
          title: '문서함',
          subtitle: '교재만 선별해서 코스에 연결합니다.',
          tint: const Color(0xFF4C8D67),
          onTap: () => _push(const TeacherDocumentCenterPage()),
        ),
        _FeatureTile(
          icon: Icons.menu_book_rounded,
          title: '코스 관리',
          subtitle: '배포한 코스와 연결된 교재를 확인합니다.',
          tint: const Color(0xFF347252),
          onTap: () => _push(const CourseListPage()),
        ),
        _FeatureTile(
          icon: Icons.assignment_rounded,
          title: '시험지 생성',
          subtitle: '문항을 묶어 평가 자료를 만듭니다.',
          tint: const Color(0xFF2E6847),
          onTap: () => _push(const ExamPaperBuilderPage()),
        ),
        _FeatureTile(
          icon: Icons.edit_note_rounded,
          title: '문항 제작',
          subtitle: '문항 초안과 변형을 정리합니다.',
          tint: const Color(0xFF235A3B),
          onTap: () => _push(const ProblemEditorPage()),
        ),
        _FeatureTile(
          icon: Icons.groups_rounded,
          title: '그룹 관리',
          subtitle: '학생 그룹과 수업 운영 상태를 봅니다.',
          tint: const Color(0xFF214F37),
          onTap: () =>
              Navigator.of(scaffoldContext).pushNamed(GroupListPage.routeName),
        ),
        _FeatureTile(
          icon: Icons.analytics_rounded,
          title: '학습 분석',
          subtitle: '현재는 그룹 관리 화면으로 이동합니다.',
          tint: kCourseGreen,
          onTap: () => Navigator.of(
            scaffoldContext,
          ).pushNamed(GroupListPage.routeName),
        ),
      ]),
    );
  }

  void _push(Widget page) {
    Navigator.of(scaffoldContext).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ios26FrostedCard(
          radius: 22,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: tint),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: tint),
                ],
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kCourseGreen,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.58),
                  fontSize: 12,
                  height: 1.34,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LowerPanels extends StatelessWidget {
  const _LowerPanels({required this.scaffoldContext});

  final BuildContext scaffoldContext;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 860;
    final panels = [
      _StatusPanel(
        title: '코스 교재 흐름',
        icon: Icons.auto_stories_rounded,
        rows: const [
          _StatusRow(label: '저장 방식', value: '교재 복사 없음'),
          _StatusRow(label: '접근 방식', value: 'textbook_id 권한 연결'),
          _StatusRow(label: '학생 화면', value: '코스 전용 리더'),
        ],
      ),
      _StatusPanel(
        title: '빠른 점검',
        icon: Icons.check_circle_outline_rounded,
        rows: const [
          _StatusRow(label: '문서함 필터', value: 'type=textbook'),
          _StatusRow(label: '이수율', value: '페이지 + 누적 시간'),
          _StatusRow(label: '일반 교재 UI', value: '기존 화면 유지'),
        ],
      ),
    ];
    if (compact) {
      return Column(
        children: [
          for (final panel in panels) ...[panel, const SizedBox(height: 12)],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < panels.length; index++) ...[
          Expanded(child: panels[index]),
          if (index != panels.length - 1) const SizedBox(width: 14),
        ],
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<_StatusRow> rows;

  @override
  Widget build(BuildContext context) {
    return Ios26FrostedCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: kCourseGreen),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: kCourseGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final row in rows) row,
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.56),
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: kCourseGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
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
      backgroundColor: const Color(0xFFF3F7F4),
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
                        color: kCourseLightGreen.withValues(alpha: 0.16),
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
