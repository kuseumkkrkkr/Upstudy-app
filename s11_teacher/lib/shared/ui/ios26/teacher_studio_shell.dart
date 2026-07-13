import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'ios26_chrome.dart';

/// 필요 변수: 액션명, 아이콘, 기존 기능 콜백, 강조 여부.
/// 작동 원리: 스튜디오의 핵심 기능을 화면 크기와 무관하게 같은 콜백으로 노출한다.
class TeacherStudioAction {
  const TeacherStudioAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;
}

/// 필요 변수: 현재 DefaultTabController와 표시할 탭 이름.
/// 작동 원리: 각 탭에 동일한 가로 폭을 강제하고 기존 TabController로 화면 전환과 스와이프 상태를 동기화한다.
class TeacherStudioTabStrip extends StatelessWidget {
  const TeacherStudioTabStrip({super.key, required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => SizedBox(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < labels.length; index++)
              Expanded(
                child: InkWell(
                  onTap: () => controller.animateTo(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            labels[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: controller.index == index
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: controller.index == index
                                  ? Colors.black
                                  : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: controller.index == index ? 28 : 0,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 필요 변수: 현재 경로, 화면 제목·설명, 기존 Drawer와 실제 작업 화면.
/// 작동 원리: PC에서는 고정 사이드바, 모바일에서는 하단 탐색을 사용하고
/// 실제 제작 기능은 전달받은 [child]와 [actions]의 기존 콜백을 그대로 실행한다.
class TeacherStudioShell extends StatelessWidget {
  const TeacherStudioShell({
    super.key,
    required this.currentRoute,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.child,
    this.endDrawer,
    this.actions = const <TeacherStudioAction>[],
    this.topItems = const <Ios26NavItem>[],
    this.trailingIcons = const <Ios26ActionIcon>[],
    this.onBack,
    this.sidebarInitiallyExpanded = true,
  });

  final String currentRoute;
  final String eyebrow;
  final String title;
  final String description;
  final Widget child;
  final Widget? endDrawer;
  final List<TeacherStudioAction> actions;
  final List<Ios26NavItem> topItems;
  final List<Ios26ActionIcon> trailingIcons;
  final VoidCallback? onBack;
  final bool sidebarInitiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: endDrawer,
      backgroundColor: const Color(0xFFEDEDEF),
      body: Builder(
        builder: (scaffoldContext) => SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 1080;
              final mobile = constraints.maxWidth < 720;
              final workspace = _buildWorkspace(
                context,
                scaffoldContext,
                desktop: desktop,
                mobile: mobile,
              );

              if (!desktop) return workspace;
              return _CollapsibleDesktopFrame(
                currentRoute: currentRoute,
                workspace: workspace,
                initiallyExpanded: sidebarInitiallyExpanded,
              );
            },
          ),
        ),
      ),
    );
  }

  /// 필요 변수: Scaffold 문맥과 PC·모바일 판정값.
  /// 작동 원리: 공통 상단 바와 소개 영역 아래에 원본 작업 위젯을 배치한다.
  Widget _buildWorkspace(
    BuildContext context,
    BuildContext scaffoldContext, {
    required bool desktop,
    required bool mobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Ios26TopBar(
          brandColor: AppColors.primary,
          title: desktop ? 'AIFlow Teacher' : 'AIFlow',
          onBack: onBack,
          onMenu: desktop
              ? null
              : () => Scaffold.of(scaffoldContext).openEndDrawer(),
          items: topItems,
          trailingIcons: trailingIcons,
        ),
        _StudioHero(
          eyebrow: eyebrow,
          title: title,
          description: description,
          actions: actions,
          mobile: mobile,
        ),
        Expanded(child: child),
        if (mobile)
          _StudioBottomNavigation(
            currentRoute: currentRoute,
            onMenu: () => Scaffold.of(scaffoldContext).openEndDrawer(),
          ),
      ],
    );
  }
}

/// 필요 변수: 현재 경로와 실제 페이지 작업공간.
/// 작동 원리: 데스크톱 사이드바의 열림 상태만 로컬로 관리해 넓은 작업 화면이 필요할 때 즉시 접는다.
class _CollapsibleDesktopFrame extends StatefulWidget {
  const _CollapsibleDesktopFrame({
    required this.currentRoute,
    required this.workspace,
    required this.initiallyExpanded,
  });

  final String currentRoute;
  final Widget workspace;
  final bool initiallyExpanded;

  @override
  State<_CollapsibleDesktopFrame> createState() =>
      _CollapsibleDesktopFrameState();
}

class _CollapsibleDesktopFrameState extends State<_CollapsibleDesktopFrame> {
  late bool _expanded;

  /// 필요 변수: 화면별 초기 사이드바 상태 [widget.initiallyExpanded].
  /// 작동 원리: 일반 페이지는 펼치고 제작 스튜디오는 접힌 상태로 최초 작업 폭을 결정한다.
  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          width: _expanded ? 224 : 82,
          child: _StudioSidebar(
            currentRoute: widget.currentRoute,
            expanded: _expanded,
            onToggle: () => setState(() => _expanded = !_expanded),
          ),
        ),
        Expanded(child: widget.workspace),
      ],
    );
  }
}

class _StudioHero extends StatelessWidget {
  const _StudioHero({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.actions,
    required this.mobile,
  });

  final String eyebrow;
  final String title;
  final String description;
  final List<TeacherStudioAction> actions;
  final bool mobile;

  /// 필요 변수: 소개 문구, 핵심 액션, 모바일 여부.
  /// 작동 원리: 설명은 짧게 유지하고 기존 기능 콜백을 큰 핵심 버튼으로 승격한다.
  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
            color: Color(0xFF66666C),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: mobile ? 28 : 36,
            height: 1.05,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          maxLines: mobile ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, height: 1.45),
        ),
      ],
    );
    final actionBar = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < actions.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            _StudioActionButton(action: actions[index]),
          ],
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        mobile ? 18 : 30,
        mobile ? 22 : 28,
        mobile ? 18 : 30,
        mobile ? 16 : 22,
      ),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, const SizedBox(height: 18), actionBar],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: copy),
                const SizedBox(width: 24),
                Flexible(child: actionBar),
              ],
            ),
    );
  }
}

class _StudioActionButton extends StatelessWidget {
  const _StudioActionButton({required this.action});

  final TeacherStudioAction action;

  /// 필요 변수: 기존 액션 정의.
  /// 작동 원리: 강조 여부만 시각적으로 구분하며 탭 시 원본 콜백을 호출한다.
  @override
  Widget build(BuildContext context) {
    final foreground = action.primary ? Colors.white : Colors.black;
    return Material(
      color: action.primary ? Colors.black : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: action.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFD7D7DB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 17, color: foreground),
              const SizedBox(width: 7),
              Text(
                action.label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioSidebar extends StatelessWidget {
  const _StudioSidebar({
    required this.currentRoute,
    required this.expanded,
    required this.onToggle,
  });

  final String currentRoute;
  final bool expanded;
  final VoidCallback onToggle;

  static const _items = <(String, IconData, String)>[
    ('/dashboard', Icons.home_rounded, '교사용 홈'),
    ('/problem-editor', Icons.diamond_outlined, '문항 제작'),
    ('/exam-editor', Icons.view_column_outlined, '시험지 편집'),
    ('/course-list', Icons.grid_view_rounded, '코스 관리'),
    ('/teacher-documents', Icons.folder_outlined, '문서함'),
    ('/groups', Icons.groups_2_outlined, '그룹 관리'),
    ('/teacher-operations', Icons.calendar_month_outlined, '운영 관리'),
    ('/teacher-social', Icons.forum_outlined, '친구·채팅'),
    ('/teacher-store', Icons.storefront_outlined, '스토어'),
  ];

  /// 필요 변수: 현재 경로.
  /// 작동 원리: 주요 교사용 경로를 고정 노출하고 기존 named route로 이동한다.
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 0, 14),
      padding: EdgeInsets.fromLTRB(
        expanded ? 14 : 10,
        18,
        expanded ? 14 : 10,
        16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF111113),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 36,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              expanded ? 8 : 2,
              4,
              expanded ? 2 : 2,
              22,
            ),
            child: expanded
                ? Row(
                    children: [
                      const _BrandMark(),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AIFlow',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              'Teacher workspace',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _SidebarToggle(expanded: true, onTap: onToggle),
                    ],
                  )
                : Column(
                    children: [
                      const _BrandMark(),
                      const SizedBox(height: 10),
                      _SidebarToggle(expanded: false, onTap: onToggle),
                    ],
                  ),
          ),
          if (expanded)
            const Padding(
              padding: EdgeInsets.fromLTRB(9, 0, 9, 8),
              child: Text(
                '제작 및 관리',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          for (final item in _items)
            _SidebarItem(
              route: item.$1,
              icon: item.$2,
              label: item.$3,
              selected: currentRoute == item.$1,
              expanded: expanded,
            ),
          const Spacer(),
          Container(
            padding: EdgeInsets.all(expanded ? 12 : 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: expanded ? 17 : 15,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person_rounded,
                    size: expanded ? 24 : 21,
                    color: Colors.black,
                  ),
                ),
                if (expanded) ...[
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '교사 계정',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.more_horiz_rounded, color: Colors.white54),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Text(
        'A',
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _SidebarToggle extends StatelessWidget {
  const _SidebarToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  /// 필요 변수: 현재 펼침 상태와 토글 콜백.
  /// 작동 원리: 사이드바 폭만 전환하며 페이지 내부 상태와 기능에는 관여하지 않는다.
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: expanded ? '사이드바 접기' : '사이드바 펼치기',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            expanded
                ? Icons.keyboard_double_arrow_left_rounded
                : Icons.keyboard_double_arrow_right_rounded,
            size: 17,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.route,
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
  });

  final String route;
  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;

  /// 필요 변수: 이동 경로와 선택 상태.
  /// 작동 원리: 선택한 메뉴만 밝은 면으로 표시하고 기존 named route를 호출한다.
  @override
  Widget build(BuildContext context) {
    final item = Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: selected
              ? null
              : () => Navigator.of(context).pushReplacementNamed(route),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 12 : 8,
              vertical: 11,
            ),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.black : Colors.white60,
                ),
                if (expanded) ...[
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.black : Colors.white60,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w900
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return expanded ? item : Tooltip(message: label, child: item);
  }
}

class _StudioBottomNavigation extends StatelessWidget {
  const _StudioBottomNavigation({
    required this.currentRoute,
    required this.onMenu,
  });

  final String currentRoute;
  final VoidCallback onMenu;

  /// 필요 변수: 현재 경로와 전체 메뉴 콜백.
  /// 작동 원리: 모바일 핵심 화면은 하단에서 이동하고 나머지는 기존 Drawer로 연다.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: 66,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xEE171719),
              borderRadius: BorderRadius.circular(27),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                _BottomItem(
                  route: '/dashboard',
                  label: '홈',
                  icon: Icons.home_outlined,
                  selected: currentRoute == '/dashboard',
                ),
                _BottomItem(
                  route: '/problem-editor',
                  label: '문항',
                  icon: Icons.diamond_outlined,
                  selected: currentRoute == '/problem-editor',
                ),
                _BottomItem(
                  route: '/exam-editor',
                  label: '편집',
                  icon: Icons.view_column_outlined,
                  selected: currentRoute == '/exam-editor',
                ),
                _BottomItem(
                  route: '/groups',
                  label: '그룹',
                  icon: Icons.groups_2_outlined,
                  selected: currentRoute == '/groups',
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: onMenu,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.more_horiz_rounded, color: Colors.white60),
                        SizedBox(height: 3),
                        Text(
                          '전체',
                          style: TextStyle(color: Colors.white60, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.route,
    required this.label,
    required this.icon,
    required this.selected,
  });

  final String route;
  final String label;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Material(
          color: selected
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: selected
                ? null
                : () => Navigator.of(context).pushReplacementNamed(route),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
