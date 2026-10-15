import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show ImageFilter;

import 'package:s11/sessions/learning_tools/ui/pages/notepad_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/timer_page.dart';
import 'package:s11/sessions/student_dashboard/ui/modals/rating_detail_modal.dart';
import 'package:s11/app/student_route_registry.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/app/student_feature_flags.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';

class MobileStudentBottomAppBar extends StatelessWidget {
  const MobileStudentBottomAppBar({super.key, this.activeRoute});

  final String? activeRoute;

  static const _primaryItems = <_DrawerDestination>[
    _DrawerDestination(
      icon: Icons.home_outlined,
      navIcon: StudentHtmlIcon.home,
      label: '홈',
      route: '/student/dashboard',
      activeRoutes: ['/student/dashboard', '/app'],
    ),
    _DrawerDestination(
      icon: Icons.route_outlined,
      navIcon: StudentHtmlIcon.courses,
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
      navIcon: StudentHtmlIcon.market,
      label: '자료실',
      route: '/bookbag',
      activeRoutes: ['/bookbag'],
    ),
  ];

  /// 필요한 변수는 현재 Navigator와 드로어 전체 메뉴다.
  /// 작동 원리는 메뉴 수에 맞는 사각 시트를 하단 탭 위에 올리고,
  /// 학습·도구·내 메뉴를 같은 그리드에서 전환하게 하는 것이다.
  static Future<void> openMore(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      barrierLabel: '더보기 닫기',
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (sheetContext, animation, secondaryAnimation) =>
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  Navigator.of(sheetContext).pop(),
            },
            child: Focus(
              autofocus: true,
              child: _MobileMoreOverlay(
                onClose: () => Navigator.of(sheetContext).pop(),
                onEntrySelected: (entry) =>
                    _handleMobileMoreEntry(context, sheetContext, entry),
              ),
            ),
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
        _goToRoute(pageContext, StudentRouteRegistry.byId('study-mode')!.route);
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
    // Preserve the 66px reference bar without squeezing enlarged labels.
    final labelHeight = MediaQuery.textScalerOf(context).scale(10) * 1.5;
    final iconSize = 20 * StudentDensityTokens.mobileIconMultiplier;
    final requiredHeight = 3 + iconSize + 5 + labelHeight + 1 + 3;
    final barHeight = requiredHeight > 66 ? requiredHeight : 66.0;
    final topPadding = (barHeight - 3 - iconSize - 5 - labelHeight - 1).clamp(
      3.0,
      19.0,
    );
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0x1409090B))),
        ),
        child: SizedBox(
          height: barHeight,
          child: Padding(
            padding: EdgeInsets.fromLTRB(10, topPadding, 10, 3),
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
                      navIcon: StudentHtmlIcon.more,
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
      child: SizedBox.expand(
        key: ValueKey('student-mobile-nav-item-${item.label}'),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            if (active)
              Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  widthFactor: .44,
                  child: SizedBox(
                    height: 3,
                    child: ColoredBox(
                      key: ValueKey(
                        'student-mobile-nav-active-${item.navIcon?.name ?? item.label}',
                      ),
                      color: const Color(0xFF09090B),
                    ),
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  item.navIcon == null
                      ? Icon(item.icon, color: color, size: 25)
                      : StudentHtmlGlyph(
                          key: ValueKey(
                            'student-nav-glyph-${item.navIcon!.name}',
                          ),
                          icon: item.navIcon!,
                          color: color,
                          size: 20,
                          scaleForMobile: false,
                        ),
                  const SizedBox(height: 5),
                  Text(
                    item.label,
                    maxLines: 1,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      height: 1.5,
                      fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    final size = MediaQuery.sizeOf(context);
    final mobile = size.width <= 720;
    final bottom = mobile ? 66.0 : 0.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          bottom: bottom,
          child: GestureDetector(
            key: const ValueKey('mobile-more-scrim'),
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: const ColoredBox(color: Color(0x8509090B)),
              ),
            ),
          ),
        ),
        Positioned(
          left: mobile ? 0 : null,
          right: 0,
          bottom: bottom,
          width: mobile ? null : (size.width - 24).clamp(0, 560).toDouble(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (size.height - bottom - 20).clamp(0, double.infinity),
            ),
            child: _MobileMoreSheet(onEntrySelected: onEntrySelected),
          ),
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
    final mobile = MediaQuery.sizeOf(context).width <= 720;
    final padding = mobile ? 14.0 : 17.0;
    return Material(
      key: const ValueKey('mobile-more-sheet'),
      color: StudentDensityTokens.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: 17,
            child: Center(
              child: SizedBox(
                width: 44,
                height: 4,
                child: ColoredBox(color: Colors.transparent),
              ),
            ),
          ),
          SizedBox(
            height: mobile ? 56 : 60,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '더보기',
                      style: TextStyle(
                        color: Color(0xFF09090B),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: '더보기 닫기',
                    child: InkWell(
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
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(padding, mobile ? 2 : 8, padding, 0),
            child: SizedBox(
              height: 49,
              child: Row(
                children: [
                  for (final tab in _MobileMoreTab.values)
                    Expanded(child: _buildTab(tab)),
                ],
              ),
            ),
          ),
          Flexible(
            child: Padding(
              padding: EdgeInsets.only(
                top: mobile ? 10 : 12,
                bottom: mobile ? 16 : 15,
              ),
              child: GridView.builder(
                key: const ValueKey('mobile-more-menu-list'),
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(horizontal: padding),
                physics: const BouncingScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 1,
                  mainAxisSpacing: 1,
                  mainAxisExtent: mobile ? 56 : 60,
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
          color: StudentDensityTokens.surface,
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
              fontSize: 11,
              fontWeight: FontWeight.w900,
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
    label: '내신 대비',
    icon: Icons.assignment_outlined,
    route: '/school-exam-prep',
  ),
  _MobileMoreEntry(
    label: '학습 지표',
    icon: Icons.insights_outlined,
    action: _MobileMoreAction.ratingDetail,
  ),
  _MobileMoreEntry(
    label: '자료실',
    icon: Icons.menu_book_outlined,
    route: '/marketplace',
  ),
  _MobileMoreEntry(
    label: '일정',
    icon: Icons.calendar_today_outlined,
    route: '/schedule',
  ),
  _MobileMoreEntry(
    label: '친구·그룹',
    icon: Icons.chat_bubble_outline,
    route: '/social',
  ),
  _MobileMoreEntry(
    label: '대결장',
    icon: Icons.emoji_events_outlined,
    route: '/arena',
  ),
];

const _mobileToolEntries = <_MobileMoreEntry>[
  _MobileMoreEntry(
    label: 'AI 튜터',
    icon: Icons.auto_awesome_outlined,
    route: '/tools',
  ),
  _MobileMoreEntry(
    label: '제한 모드',
    icon: Icons.lock_outline,
    action: _MobileMoreAction.studyMode,
  ),
  _MobileMoreEntry(
    label: '검색',
    icon: Icons.search_rounded,
    action: _MobileMoreAction.search,
  ),
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
  _MobileMoreEntry(
    label: '튜토리얼',
    icon: Icons.auto_awesome_outlined,
    route: '/landing/about',
  ),
];

const _mobileMyMenuEntries = <_MobileMoreEntry>[
  _MobileMoreEntry(
    label: '알림',
    icon: Icons.notifications_none_rounded,
    action: _MobileMoreAction.notifications,
  ),
  _MobileMoreEntry(label: '프로필', icon: Icons.person_outline, route: '/profile'),
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
    label: '로그아웃',
    icon: Icons.logout_outlined,
    action: _MobileMoreAction.logout,
  ),
];

class _DrawerDestination {
  const _DrawerDestination({
    required this.icon,
    this.navIcon,
    required this.label,
    required this.route,
    this.activeRoutes = const <String>[],
  });

  final IconData icon;
  final StudentHtmlIcon? navIcon;
  final String label;
  final String route;
  final List<String> activeRoutes;
}
