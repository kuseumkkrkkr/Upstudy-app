import 'package:flutter/material.dart';

import 'package:s11/sessions/learning_tools/ui/pages/notepad_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/timer_page.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/rating_detail_modal.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/study_mode_modal.dart';
import 'package:s11/shared/services/auth/auth_storage.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/app/student_feature_flags.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

/// 필요한 변수는 현재 학생 라우트와 하단 목적지 목록이다.
/// 작동 원리는 모바일에서 넓은 측면 드로어 대신 자주 쓰는 홈·코스·마켓을 고정하고,
/// 나머지 메뉴만 바텀시트로 축약해 화면 전환 중에도 탐색 동선을 유지하는 것이다.
class MobileStudentBottomAppBar extends StatelessWidget {
  const MobileStudentBottomAppBar({super.key, this.activeRoute});

  final String? activeRoute;

  static const _primaryItems = <_DrawerDestination>[
    _DrawerDestination(
      icon: Icons.home_outlined,
      label: '홈',
      route: '/student/dashboard',
      activeRoutes: ['/student/dashboard', '/app'],
    ),
    _DrawerDestination(
      icon: Icons.route_outlined,
      label: '코스',
      route: '/courses',
      activeRoutes: [
        '/courses',
        '/course_runtime',
        '/wrong_answers',
        '/wrong_answer_solve',
      ],
    ),
    _DrawerDestination(
      icon: Icons.storefront_outlined,
      label: '자료실',
      route: '/marketplace',
      activeRoutes: ['/marketplace'],
    ),
  ];

  /// 필요한 변수는 현재 Navigator와 드로어 전체 메뉴다.
  /// 작동 원리는 레퍼런스와 같은 320px 사각 시트를 하단 탭 위에 올리고,
  /// 학습·도구·내 메뉴를 같은 그리드에서 전환하게 하는 것이다.
  static Future<void> openMore(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      barrierLabel: '더보기 닫기',
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (sheetContext, animation, secondaryAnimation) =>
          _MobileMoreOverlay(
            onClose: () => Navigator.of(sheetContext).pop(),
            onEntrySelected: (entry) =>
                _handleMobileMoreEntry(context, sheetContext, entry),
          ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  /// 필요한 변수는 레퍼런스 메뉴 항목과 실제 앱 동작이다.
  /// 작동 원리는 지원되는 화면은 기존 라우트·모달을 재사용하고, 아직 연결되지 않은
  /// 시안 전용 기능은 가짜 화면 대신 사용자에게 연결 상태를 알리는 것이다.
  static Future<void> _handleMobileMoreEntry(
    BuildContext pageContext,
    BuildContext sheetContext,
    _MobileMoreEntry entry,
  ) async {
    Navigator.of(sheetContext).pop();
    switch (entry.action) {
      case _MobileMoreAction.route:
        _goToRoute(pageContext, entry.route!);
      case _MobileMoreAction.graph:
        _goToRoute(pageContext, '/graph');
      case _MobileMoreAction.timer:
        Navigator.of(
          pageContext,
        ).push(MaterialPageRoute(builder: (_) => const TimerPage()));
      case _MobileMoreAction.notepad:
        Navigator.of(
          pageContext,
        ).push(MaterialPageRoute(builder: (_) => const NotepadPage()));
      case _MobileMoreAction.studyMode:
        await showStudyModeModal(context: pageContext);
      case _MobileMoreAction.ratingDetail:
        await showRatingDetailModal(context: pageContext);
      case _MobileMoreAction.search:
        showStudentQuickSearch(pageContext);
      case _MobileMoreAction.notifications:
        showStudentNotifications(pageContext);
      case _MobileMoreAction.unavailable:
        if (!pageContext.mounted) return;
        ScaffoldMessenger.of(pageContext)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text('${entry.label} 기능은 준비 중입니다.')),
          );
      case _MobileMoreAction.logout:
        await ApiClient.instance.clearToken();
        if (!pageContext.mounted) return;
        Navigator.of(
          pageContext,
          rootNavigator: true,
        ).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  /// 필요한 변수는 선택한 명명 라우트다.
  /// 작동 원리는 중복 탭에서는 현재 화면을 보존하고 다른 탭은 루트 위에 한 번만 쌓아
  /// 모바일 하단 탭을 반복해도 뒤로가기 스택이 길어지지 않게 하는 것이다.
  static void _goToRoute(BuildContext context, String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      route,
      (entry) =>
          entry.settings.name == '/student/dashboard' ||
          entry.settings.name == '/app' ||
          entry.isFirst,
    );
  }

  bool _isActive(_DrawerDestination item, String route) {
    return item.activeRoutes.any(
      (candidate) => route == candidate || route.startsWith('$candidate/'),
    );
  }

  /// 필요한 변수는 현재 라우트와 고정 탭 목록이다.
  /// 작동 원리는 보조 화면에서는 더보기를 선택 상태로 표시하고 주요 화면은 해당 탭만 강조한다.
  @override
  Widget build(BuildContext context) {
    final route = activeRoute ?? ModalRoute.of(context)?.settings.name ?? '';
    final moreActive =
        route.isNotEmpty &&
        !_primaryItems.any((item) => _isActive(item, route));
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0x1409090B))),
        ),
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (final item in _primaryItems)
                Expanded(
                  child: _MobileBottomDestination(
                    item: item,
                    active: _isActive(item, route),
                    onTap: () => _goToRoute(context, item.route),
                  ),
                ),
              Expanded(
                child: _MobileBottomDestination(
                  item: const _DrawerDestination(
                    icon: Icons.more_horiz_rounded,
                    label: '더보기',
                    route: '',
                  ),
                  active: moreActive,
                  onTap: () => openMore(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileBottomDestination extends StatelessWidget {
  const _MobileBottomDestination({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _DrawerDestination item;
  final bool active;
  final VoidCallback onTap;

  /// 필요한 변수는 탭 아이콘·라벨, 선택 여부와 탭 콜백이다.
  /// 작동 원리는 기준 HTML처럼 선택 탭의 상단 선만 강조하고 하단 셀은
  /// 흰색으로 유지해 화면과 내비게이션의 경계를 보존하는 것이다.
  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF09090B) : const Color(0xFF626269);
    return InkWell(
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: active ? const Color(0xFF09090B) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: color, size: 24),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 필요한 변수는 시트의 표시 영역과 탭·선택 콜백이다.
/// 작동 원리는 하단 탭 위에만 시트를 배치해 레퍼런스의 body/nav 경계를 보존하는 것이다.
class _MobileMoreOverlay extends StatelessWidget {
  const _MobileMoreOverlay({
    required this.onClose,
    required this.onEntrySelected,
  });

  final VoidCallback onClose;
  final ValueChanged<_MobileMoreEntry> onEntrySelected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          bottom: 68,
          child: GestureDetector(
            key: const ValueKey('mobile-more-scrim'),
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: const ColoredBox(color: Color(0x66000000)),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 68,
          height: 320,
          child: _MobileMoreSheet(onEntrySelected: onEntrySelected),
        ),
      ],
    );
  }
}

class _MobileMoreSheet extends StatefulWidget {
  const _MobileMoreSheet({required this.onEntrySelected});

  final ValueChanged<_MobileMoreEntry> onEntrySelected;

  @override
  State<_MobileMoreSheet> createState() => _MobileMoreSheetState();
}

class _MobileMoreSheetState extends State<_MobileMoreSheet> {
  _MobileMoreTab _selectedTab = _MobileMoreTab.learning;

  List<_MobileMoreEntry> get _entries =>
      (switch (_selectedTab) {
            _MobileMoreTab.learning => _mobileLearningEntries,
            _MobileMoreTab.tools => _mobileToolEntries,
            _MobileMoreTab.myMenu => _mobileMyMenuEntries,
          })
          .where((entry) {
            if (!entry.demoOnly) return true;
            return entry.demoKind == _DemoKind.services
                ? StudentFeatureFlags.servicesDemo
                : StudentFeatureFlags.storeDemo;
          })
          .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('mobile-more-sheet'),
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(
            height: 16,
            child: Center(
              child: SizedBox(
                width: 44,
                height: 4,
                child: ColoredBox(color: Color(0xFF2B2B2E)),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '더보기',
                      style: TextStyle(
                        color: Color(0xFF09090B),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                    ),
                  ),
                  InkWell(
                    key: const ValueKey('mobile-more-close'),
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.fromBorderSide(
                            BorderSide(color: Color(0x1A09090B)),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.close,
                            color: Color(0xFF09090B),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 49,
            child: Row(
              children: [
                for (final tab in _MobileMoreTab.values)
                  Expanded(child: _buildTab(tab)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 13, bottom: 18),
              child: GridView.builder(
                key: const ValueKey('mobile-more-menu-list'),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 1,
                  mainAxisSpacing: 1,
                  mainAxisExtent: 56,
                ),
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return _MobileMoreDestination(
                    entry: entry,
                    onTap: () => widget.onEntrySelected(entry),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(_MobileMoreTab tab) {
    final selected = tab == _selectedTab;
    return InkWell(
      key: ValueKey('mobile-more-tab-${tab.label}'),
      onTap: () => setState(() => _selectedTab = tab),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF6F6F7) : Colors.white,
          border: Border(
            bottom: BorderSide(
              color: selected ? const Color(0xFF09090B) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Center(
          child: Text(
            tab.label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF09090B)
                  : const Color(0xFF77777F),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileMoreDestination extends StatelessWidget {
  const _MobileMoreDestination({required this.entry, required this.onTap});

  final _MobileMoreEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('mobile-more-${entry.keyPart}'),
      onTap: onTap,
      child: Container(
        color: const Color(0xFFF3F3F5),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Icon(entry.icon, color: const Color(0xFF18181B), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF18181B),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward, color: Color(0xFF77777F), size: 17),
          ],
        ),
      ),
    );
  }
}

enum _MobileMoreTab {
  learning('학습'),
  tools('도구'),
  myMenu('내 메뉴');

  const _MobileMoreTab(this.label);

  final String label;
}

enum _MobileMoreAction {
  route,
  graph,
  timer,
  notepad,
  studyMode,
  ratingDetail,
  search,
  notifications,
  unavailable,
  logout,
}

class _MobileMoreEntry {
  const _MobileMoreEntry({
    required this.label,
    required this.icon,
    this.route,
    this.action = _MobileMoreAction.route,
    this.demoOnly = false,
    this.demoKind,
  });

  final String label;
  final IconData icon;
  final String? route;
  final _MobileMoreAction action;
  final bool demoOnly;
  final _DemoKind? demoKind;

  String get keyPart {
    if (route != null) return route == '/profile' ? 'profile' : route!;
    return switch (label) {
      '검색' => 'search',
      '알림' => 'notifications',
      _ => label,
    };
  }
}

enum _DemoKind { services, store }

const _mobileLearningEntries = <_MobileMoreEntry>[
  _MobileMoreEntry(
    label: '현재 코스',
    icon: Icons.route_outlined,
    route: '/courses',
  ),
  _MobileMoreEntry(
    label: '레벨 테스트',
    icon: Icons.speed_outlined,
    route: '/level_test',
  ),
  _MobileMoreEntry(
    label: '제한 모드',
    icon: Icons.lock_outline,
    action: _MobileMoreAction.studyMode,
  ),
  _MobileMoreEntry(
    label: 'AI 튜터',
    icon: Icons.auto_awesome_outlined,
    route: '/tools',
  ),
  _MobileMoreEntry(
    label: '내신 대비',
    icon: Icons.assignment_outlined,
    route: '/school-exam-prep',
  ),
  _MobileMoreEntry(
    label: '학습 지표',
    icon: Icons.insights_outlined,
    action: _MobileMoreAction.ratingDetail,
  ),
];

const _mobileToolEntries = <_MobileMoreEntry>[
  _MobileMoreEntry(
    label: '그래프',
    icon: Icons.account_tree_outlined,
    action: _MobileMoreAction.graph,
  ),
  _MobileMoreEntry(
    label: '노트패드',
    icon: Icons.note_alt_outlined,
    action: _MobileMoreAction.notepad,
  ),
  _MobileMoreEntry(
    label: '타이머',
    icon: Icons.timer_outlined,
    action: _MobileMoreAction.timer,
  ),
];

const _mobileMyMenuEntries = <_MobileMoreEntry>[
  _MobileMoreEntry(
    label: '검색',
    icon: Icons.search_rounded,
    action: _MobileMoreAction.search,
  ),
  _MobileMoreEntry(
    label: '알림',
    icon: Icons.notifications_none_rounded,
    action: _MobileMoreAction.notifications,
  ),
  _MobileMoreEntry(
    label: '자료실',
    icon: Icons.menu_book_outlined,
    route: '/bookbag',
  ),
  _MobileMoreEntry(
    label: '일정',
    icon: Icons.calendar_today_outlined,
    route: '/schedule',
  ),
  _MobileMoreEntry(label: '프로필', icon: Icons.person_outline, route: '/profile'),
  _MobileMoreEntry(
    label: '친구·그룹',
    icon: Icons.chat_bubble_outline,
    route: '/social',
  ),
  _MobileMoreEntry(
    label: 'AIFlow 학원 찾기',
    icon: Icons.school_outlined,
    route: '/student-services/academy',
    demoOnly: true,
    demoKind: _DemoKind.services,
  ),
  _MobileMoreEntry(
    label: '과외 찾기',
    icon: Icons.person_search_outlined,
    route: '/student-services/tutor',
    demoOnly: true,
    demoKind: _DemoKind.services,
  ),
  _MobileMoreEntry(
    label: '대결장',
    icon: Icons.emoji_events_outlined,
    route: '/arena',
  ),
  _MobileMoreEntry(
    label: '마켓플레이스',
    icon: Icons.storefront_outlined,
    route: '/store',
    demoOnly: true,
    demoKind: _DemoKind.store,
  ),
  _MobileMoreEntry(
    label: '설정',
    icon: Icons.settings_outlined,
    route: '/settings',
  ),
  _MobileMoreEntry(
    label: '튜토리얼',
    icon: Icons.auto_awesome_outlined,
    route: '/landing/about',
  ),
  _MobileMoreEntry(
    label: '로그아웃',
    icon: Icons.logout_outlined,
    action: _MobileMoreAction.logout,
  ),
];

class _AppDrawerState extends State<AppDrawer> {
  static const Color _background = Color(0xFFF4F4F6);
  static const Color _ink = Color(0xFF09090B);
  static const Color _muted = Color(0xFF71717A);
  static const Color _faint = Color(0xFFA1A1AA);
  static const Color _line = Color(0x1A09090B);

  late final Future<_DrawerProfileData> _profile = _loadProfile();

  /// 필요한 변수는 UTF-8로 저장된 로컬 사용자명이다.
  /// 드로어를 열 때 서버·DB를 추가 조회하지 않고 저장값만 읽으며 실패하면 기본 학생명으로 복구한다.
  Future<_DrawerProfileData> _loadProfile() async {
    final username = (await AuthStorage.instance.readUsername().catchError(
      (_) => null,
    ))?.trim();
    return _DrawerProfileData(
      username: username == null || username.isEmpty ? '학생' : username,
    );
  }

  /// 필요한 변수는 현재 드로어 문맥과 이동할 학생 화면 경로다.
  /// 드로어를 먼저 닫은 뒤 현재 화면이 아닐 때만 루트 내비게이터에 명명 라우트를 추가한다.
  void _openRoute(String route) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final navigator = Navigator.of(context, rootNavigator: true);
    Navigator.of(context).pop();
    if (currentRoute != route) {
      navigator.pushNamed(route);
    }
  }

  /// 필요한 변수는 현재 라우트와 메뉴가 담당하는 경로 목록이다.
  /// 상세 화면에서도 해당 상위 메뉴를 검게 강조할 수 있도록 접두 경로까지 함께 비교한다.
  bool _isActive(_DrawerDestination item) {
    final route = ModalRoute.of(context)?.settings.name ?? '';
    return item.activeRoutes.any(
      (candidate) => route == candidate || route.startsWith('$candidate/'),
    );
  }

  bool _isDemoVisible(_DrawerDestination item) {
    if (!item.demoOnly) return true;
    return switch (item.demoKind) {
      _DemoKind.services => StudentFeatureFlags.servicesDemo,
      _DemoKind.store => StudentFeatureFlags.storeDemo,
      null => false,
    };
  }

  /// 필요한 변수는 화면 너비, 현재 라우트, 프로필 요약이다.
  /// 최신 학생 시안의 작은 브랜드·이어 학습·그룹형 메뉴·하단 프로필 칩 순서로 드로어를 구성한다.
  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <=
        StudentDensityTokens.mobileBreakpoint;
    final drawerWidth = mobile
        ? (MediaQuery.sizeOf(context).width - 16).clamp(0, 420).toDouble()
        : (MediaQuery.sizeOf(context).width - 40).clamp(0, 310).toDouble();

    return Drawer(
      width: drawerWidth,
      elevation: 24,
      backgroundColor: _background.withValues(alpha: 0.97),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            mobile ? 16 : 14,
            mobile ? 16 : 20,
            mobile ? 16 : 14,
            mobile ? 16 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DrawerBrand(
                onTap: () => _openRoute('/student/dashboard'),
                onClose: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _ResumeCard(onTap: () => _openRoute('/courses')),
                    for (final group
                        in _navigationGroups
                            .map(
                              (group) => _DrawerNavigationGroup(
                                label: group.label,
                                items: group.items
                                    .where(_isDemoVisible)
                                    .toList(),
                              ),
                            )
                            .where((group) => group.items.isNotEmpty))
                      _DrawerGroup(
                        group: group,
                        isActive: _isActive,
                        onTap: (item) => _openRoute(item.route),
                      ),
                  ],
                ),
              ),
              FutureBuilder<_DrawerProfileData>(
                future: _profile,
                builder: (context, snapshot) => _ProfileChip(
                  data: snapshot.data ?? const _DrawerProfileData(),
                  onTap: () => _openRoute('/profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerBrand extends StatelessWidget {
  const _DrawerBrand({required this.onTap, required this.onClose});

  final VoidCallback onTap;
  final VoidCallback onClose;

  /// 필요한 변수는 홈 이동과 드로어 닫기 콜백이다.
  /// 최신 시안의 34px 검정 브랜드 마크와 STUDENT 보조 라벨을 한 줄 헤더로 표시한다.
  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <=
        StudentDensityTokens.mobileBreakpoint;
    return Stack(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, 6, mobile ? 58 : 48, 18),
            child: Row(
              children: [
                const _SquareIcon(icon: null, label: 'A'),
                SizedBox(width: mobile ? 14 : 11),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AIFlow',
                      style: TextStyle(
                        color: _AppDrawerState._ink,
                        fontSize: mobile ? 22 : 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'STUDENT',
                      style: TextStyle(
                        color: _AppDrawerState._muted,
                        fontSize: mobile ? 11 : 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            tooltip: '메뉴 닫기',
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, size: mobile ? 25 : 20),
            style: IconButton.styleFrom(
              fixedSize: Size.square(mobile ? 48 : 38),
              backgroundColor: Colors.white.withValues(alpha: 0.76),
              side: const BorderSide(color: _AppDrawerState._line),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.onTap});

  final VoidCallback onTap;

  /// 필요한 변수는 코스 화면 이동 콜백이다.
  /// 별도 DB 조회 없이 최신 시안의 검정 이어 학습 카드를 제공해 드로어를 열 때 추가 부하를 만들지 않는다.
  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <=
        StudentDensityTokens.mobileBreakpoint;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 9),
      child: Material(
        color: _AppDrawerState._ink,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: SizedBox(
            height: mobile ? 112 : 82,
            child: Padding(
              padding: EdgeInsets.all(mobile ? 16 : 12),
              child: Row(
                children: [
                  const _SquareIcon(icon: Icons.play_arrow_rounded),
                  SizedBox(width: mobile ? 14 : 11),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '이어 학습',
                          style: const TextStyle(
                            color: Color(0xFF8F8F98),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '최근 코스에서 계속하기',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: mobile ? 17 : 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '코스 선택 후 학습을 이어갑니다',
                          style: TextStyle(
                            color: const Color(0xFFA1A1AA),
                            fontSize: mobile ? 12 : 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF92929A),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerGroup extends StatelessWidget {
  const _DrawerGroup({
    required this.group,
    required this.isActive,
    required this.onTap,
  });

  final _DrawerNavigationGroup group;
  final bool Function(_DrawerDestination item) isActive;
  final ValueChanged<_DrawerDestination> onTap;

  /// 필요한 변수는 그룹 라벨, 메뉴 목록, 현재 경로 판별기다.
  /// 메뉴를 42px 슬림 행으로 쌓고 현재 화면만 검정 캡슐로 강조한다.
  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <=
        StudentDensityTokens.mobileBreakpoint;
    return Padding(
      padding: EdgeInsets.only(top: mobile ? 10 : 5, bottom: mobile ? 5 : 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 5),
            child: Text(
              group.label,
              style: TextStyle(
                color: _AppDrawerState._faint,
                fontSize: mobile ? 12 : 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ),
          for (final item in group.items)
            _DrawerNavItem(
              item: item,
              active: isActive(item),
              onTap: () => onTap(item),
            ),
        ],
      ),
    );
  }
}

class _DrawerNavItem extends StatelessWidget {
  const _DrawerNavItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _DrawerDestination item;
  final bool active;
  final VoidCallback onTap;

  /// 필요한 변수는 메뉴 아이콘·라벨·활성 상태와 이동 콜백이다.
  /// 비활성 메뉴는 투명 배경, 활성 메뉴는 최신 시안과 같은 검정 배경과 흰 글자로 렌더한다.
  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <=
        StudentDensityTokens.mobileBreakpoint;
    final foreground = active ? Colors.white : const Color(0xFF505057);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: active ? _AppDrawerState._ink : Colors.transparent,
        borderRadius: BorderRadius.circular(mobile ? 18 : 14),
        child: InkWell(
          borderRadius: BorderRadius.circular(mobile ? 18 : 14),
          onTap: onTap,
          child: SizedBox(
            height: mobile ? 58 : 42,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: mobile ? 16 : 11),
              child: Row(
                children: [
                  SizedBox(
                    width: mobile ? 28 : 21,
                    child: Icon(
                      item.icon,
                      size: mobile ? 24 : 19,
                      color: foreground,
                    ),
                  ),
                  SizedBox(width: mobile ? 14 : 10),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: mobile ? 17 : 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.data, required this.onTap});

  final _DrawerProfileData data;
  final VoidCallback onTap;

  /// 필요한 변수는 로컬 사용자명과 프로필 이동 콜백이다.
  /// 구형 로그아웃 버튼 대신 최신 시안의 원형 아바타와 학생 요약 칩을 드로어 하단에 고정한다.
  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <=
        StudentDensityTokens.mobileBreakpoint;
    final initial = data.username.characters.first.toUpperCase();
    return Material(
      color: Colors.white.withValues(alpha: 0.76),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(mobile ? 12 : 9),
          decoration: BoxDecoration(
            border: Border.all(color: _AppDrawerState._line),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: mobile ? 22 : 16,
                backgroundColor: _AppDrawerState._ink,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: mobile ? 16 : 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _AppDrawerState._ink,
                        fontSize: mobile ? 16 : 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'AIFlow STUDENT',
                      style: TextStyle(
                        color: _AppDrawerState._muted,
                        fontSize: mobile ? 12 : 10,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _AppDrawerState._muted,
                size: mobile ? 25 : 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SquareIcon extends StatelessWidget {
  const _SquareIcon({this.icon, this.label});

  final IconData? icon;
  final String? label;

  /// 필요한 변수는 선택적 아이콘 또는 한 글자 라벨이다.
  /// 브랜드에는 검정 바탕을, 이어 학습 카드에는 흰 바탕을 적용하는 공용 34~38px 마크를 만든다.
  @override
  Widget build(BuildContext context) {
    final isBrand = label != null;
    final mobile =
        MediaQuery.sizeOf(context).width <=
        StudentDensityTokens.mobileBreakpoint;
    final size = isBrand
        ? mobile
              ? 44.0
              : 34.0
        : mobile
        ? 48.0
        : 38.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isBrand ? _AppDrawerState._ink : Colors.white,
        borderRadius: BorderRadius.circular(
          mobile
              ? 15
              : isBrand
              ? 12
              : 13,
        ),
      ),
      child: icon != null
          ? Icon(icon, color: _AppDrawerState._ink, size: mobile ? 23 : 18)
          : Text(
              label!,
              style: TextStyle(
                color: Colors.white,
                fontSize: mobile ? 20 : 16,
                fontWeight: FontWeight.w900,
              ),
            ),
    );
  }
}

class _DrawerProfileData {
  const _DrawerProfileData({this.username = '학생'});

  final String username;
}

class _DrawerNavigationGroup {
  const _DrawerNavigationGroup({required this.label, required this.items});

  final String label;
  final List<_DrawerDestination> items;
}

class _DrawerDestination {
  const _DrawerDestination({
    required this.icon,
    required this.label,
    required this.route,
    this.activeRoutes = const <String>[],
    this.demoOnly = false,
    this.demoKind,
  });

  final IconData icon;
  final String label;
  final String route;
  final List<String> activeRoutes;
  final bool demoOnly;
  final _DemoKind? demoKind;
}

const _navigationGroups = <_DrawerNavigationGroup>[
  _DrawerNavigationGroup(
    label: '오늘',
    items: [
      _DrawerDestination(
        icon: Icons.home_outlined,
        label: '홈',
        route: '/student/dashboard',
        activeRoutes: ['/student/dashboard', '/app'],
      ),
      _DrawerDestination(
        icon: Icons.calendar_today_outlined,
        label: '일정',
        route: '/schedule',
        activeRoutes: ['/schedule'],
      ),
    ],
  ),
  _DrawerNavigationGroup(
    label: '학습',
    items: [
      _DrawerDestination(
        icon: Icons.route_outlined,
        label: '코스',
        route: '/courses',
        activeRoutes: ['/courses', '/course_runtime'],
      ),
      _DrawerDestination(
        icon: Icons.menu_book_outlined,
        label: '자료실',
        route: '/bookbag',
        activeRoutes: ['/bookbag'],
      ),
      _DrawerDestination(
        icon: Icons.replay_rounded,
        label: '오답 노트',
        route: '/wrong_answers',
        activeRoutes: ['/wrong_answers', '/wrong_answer_solve'],
      ),
      _DrawerDestination(
        icon: Icons.speed_outlined,
        label: '레벨 테스트',
        route: '/level_test',
        activeRoutes: ['/level_test'],
      ),
    ],
  ),
  _DrawerNavigationGroup(
    label: '경쟁',
    items: [
      _DrawerDestination(
        icon: Icons.emoji_events_outlined,
        label: '대결',
        route: '/arena',
        activeRoutes: ['/arena'],
      ),
    ],
  ),
  _DrawerNavigationGroup(
    label: '커뮤니티',
    items: [
      _DrawerDestination(
        icon: Icons.people_outline_rounded,
        label: '친구/소셜',
        route: '/social',
        activeRoutes: ['/social'],
      ),
      _DrawerDestination(
        icon: Icons.groups_outlined,
        label: '스터디 그룹',
        route: '/groups',
        activeRoutes: ['/groups', '/group'],
      ),
      _DrawerDestination(
        icon: Icons.storefront_outlined,
        label: '마켓플레이스',
        route: '/marketplace',
        activeRoutes: ['/marketplace'],
      ),
      _DrawerDestination(
        icon: Icons.school_outlined,
        label: 'AIFlow 학원 찾기',
        route: '/student-services/academy',
        activeRoutes: ['/student-services/academy'],
        demoOnly: true,
        demoKind: _DemoKind.services,
      ),
      _DrawerDestination(
        icon: Icons.person_search_outlined,
        label: '과외 찾기',
        route: '/student-services/tutor',
        activeRoutes: ['/student-services/tutor'],
        demoOnly: true,
        demoKind: _DemoKind.services,
      ),
      _DrawerDestination(
        icon: Icons.local_mall_outlined,
        label: '포인트 상점',
        route: '/store',
        activeRoutes: ['/store'],
        demoOnly: true,
        demoKind: _DemoKind.store,
      ),
    ],
  ),
  _DrawerNavigationGroup(
    label: '도구·설정',
    items: [
      _DrawerDestination(
        icon: Icons.grid_view_outlined,
        label: '학습 도구',
        route: '/tools',
        activeRoutes: ['/tools'],
      ),
      _DrawerDestination(
        icon: Icons.settings_outlined,
        label: '설정',
        route: '/settings',
        activeRoutes: ['/settings'],
      ),
    ],
  ),
];

/// 필요한 변수는 드로어를 포함한 현재 Scaffold 문맥이다.
/// 열림 상태면 닫고 닫힘 상태면 열어 공용 햄버거 버튼의 동작을 한곳에서 처리한다.
void toggleAppDrawer(BuildContext context) {
  final scaffoldState = Scaffold.maybeOf(context);
  if (scaffoldState == null) {
    return;
  }
  if (scaffoldState.isDrawerOpen) {
    Navigator.of(context).pop();
  } else {
    scaffoldState.openDrawer();
  }
}
