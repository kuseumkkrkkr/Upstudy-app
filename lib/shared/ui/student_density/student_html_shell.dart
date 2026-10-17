import 'package:flutter/material.dart';

import 'package:s11/app/router.dart';
import 'package:s11/shared/ui/drawer/student_navigation.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';

/// HTML 학생 제품 셸을 실제 Flutter 화면에서 재사용하기 위한 얇은 레이아웃입니다.
/// 화면 본문과 데이터 계약은 호출자가 유지하고, 레일·상단바·모바일 탭만 공통화합니다.
class StudentHtmlShell extends StatelessWidget {
  const StudentHtmlShell({
    super.key,
    required this.title,
    required this.child,
    this.activeRoute = AppRoutes.studentDashboard,
    this.showContextAside = false,
    this.contextAside,
    this.onSearch,
    this.onNotifications,
    this.onMenu,
    this.mobileBackButton = false,
    this.includeHeader = true,
    this.railWidth,
    this.reserveContextTrack = false,
    this.showHeaderActions = true,
    this.showHeaderNotifications = true,
    this.showBottomNavigation = true,
    this.headerTrailing,
  });

  final String title;
  final Widget child;
  final String activeRoute;
  final bool showContextAside;
  final Widget? contextAside;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onMenu;
  final bool mobileBackButton;
  final bool includeHeader;

  /// Optional screen-specific desktop rail width from the reference CSS.
  final double? railWidth;
  final bool reserveContextTrack;

  /// Some reference screens deliberately omit search and notifications.
  final bool showHeaderActions;
  final bool showHeaderNotifications;

  /// Mobile task pages may omit tabs in the final reference cascade.
  /// Desktop/tablet rail behavior is unchanged.
  final bool showBottomNavigation;

  /// Screen-specific controls replace the default search/notification actions.
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width > StudentDensityTokens.desktopBreakpoint;
    final desktopRailWidth = railWidth ?? (wide ? 76.0 : 72.0);
    final menu = onMenu ?? () => MobileStudentBottomAppBar.openMore(context);
    final search = onSearch ?? () => showStudentQuickSearch(context);
    final notifications =
        onNotifications ?? () => showStudentNotifications(context);

    return Scaffold(
      backgroundColor: StudentDensityTokens.background,
      bottomNavigationBar: mobile && showBottomNavigation
          ? MobileStudentBottomAppBar(activeRoute: activeRoute)
          : null,
      body: SafeArea(
        child: mobile
            ? Column(
                children: [
                  if (includeHeader)
                    StudentHtmlTopBar(
                      title: title,
                      onMenu: menu,
                      onSearch: search,
                      onNotifications: notifications,
                      mobileBackButton: mobileBackButton,
                      showActions: showHeaderActions,
                      showNotifications: showHeaderNotifications,
                      trailing: headerTrailing,
                    ),
                  Expanded(child: child),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StudentHtmlRail(
                    activeRoute: activeRoute,
                    width: desktopRailWidth,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        if (includeHeader)
                          StudentHtmlTopBar(
                            title: title,
                            onMenu: menu,
                            onSearch: search,
                            onNotifications: notifications,
                            mobileBackButton: mobileBackButton,
                            showActions: showHeaderActions,
                            showNotifications: showHeaderNotifications,
                            trailing: headerTrailing,
                          ),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                  if (wide && showContextAside)
                    contextAside ?? const StudentHtmlContextAside(),
                  if (!mobile && reserveContextTrack)
                    SizedBox(width: wide ? 244 : 200),
                ],
              ),
      ),
    );
  }
}

class StudentHtmlTopBar extends StatelessWidget {
  const StudentHtmlTopBar({
    super.key,
    required this.title,
    required this.onMenu,
    required this.onSearch,
    required this.onNotifications,
    this.mobileBackButton = false,
    this.showActions = true,
    this.showNotifications = true,
    this.trailing,
  });

  final String title;
  final VoidCallback onMenu;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final bool mobileBackButton;
  final bool showActions;
  final bool showNotifications;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);

    Widget action({
      required String label,
      required StudentHtmlIcon icon,
      required double iconSize,
      required VoidCallback onTap,
    }) {
      final size = label == '검색' || label == '알림' ? 48.0 : 44.0;
      return Semantics(
        button: true,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: SizedBox(
          key: ValueKey(switch (label) {
            '학생 메뉴' => 'student-mobile-menu',
            '뒤로가기' => 'student-mobile-back',
            '검색' => 'student-search-action',
            '알림' => 'student-notifications-action',
            _ => 'student-action-$label',
          }),
          width: size,
          height: size,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: StudentDensityTokens.ink,
              side: const BorderSide(color: StudentDensityTokens.line),
              shape: const RoundedRectangleBorder(),
            ),
            child: StudentHtmlGlyph(
              icon: icon,
              size: iconSize,
              color: StudentDensityTokens.ink,
              scaleForMobile: false,
            ),
          ),
        ),
      );
    }

    final topBarHeight = mobile ? 64.0 : 62.0;
    final menuLabel = mobileBackButton ? '뒤로가기' : '학생 메뉴';
    return Container(
      height: topBarHeight,
      decoration: BoxDecoration(
        color: StudentDensityTokens.surface,
        border: Border(bottom: BorderSide(color: StudentDensityTokens.line)),
      ),
      padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 22),
      child: Row(
        children: [
          action(
            label: menuLabel,
            icon: mobileBackButton
                ? StudentHtmlIcon.back
                : StudentHtmlIcon.menu,
            iconSize: 20,
            onTap: onMenu,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: KeyedSubtree(
              key: const ValueKey('student-brand-home'),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          if (trailing != null)
            trailing!
          else if (showActions) ...[
            action(
              label: '검색',
              icon: StudentHtmlIcon.search,
              iconSize: 19,
              onTap: onSearch,
            ),
            if (showNotifications) const SizedBox(width: 7),
            if (showNotifications)
              action(
                label: '알림',
                icon: StudentHtmlIcon.bell,
                iconSize: 19,
                onTap: onNotifications,
              ),
          ],
        ],
      ),
    );
  }
}

class StudentHtmlRail extends StatelessWidget {
  const StudentHtmlRail({super.key, required this.activeRoute, this.width});

  final String activeRoute;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final activePath = Uri.tryParse(activeRoute)?.path ?? activeRoute;
    final railWidth =
        width ??
        (MediaQuery.sizeOf(context).width >
                StudentDensityTokens.desktopBreakpoint
            ? 84.0
            : 72.0);

    Widget item({
      required String label,
      required String route,
      required StudentHtmlIcon navIcon,
    }) {
      // 기본 자료 탭은 책가방, 마켓 자료실은 더보기 아래에 둔다.
      final active =
          activeRoute == route ||
          (route == AppRoutes.learningTools &&
              (activeRoute == AppRoutes.marketplace ||
                  activeRoute == AppRoutes.store ||
                  activePath == AppRoutes.social ||
                  activePath.startsWith('${AppRoutes.social}/') ||
                  activePath == AppRoutes.groups ||
                  activePath.startsWith('${AppRoutes.groups}/') ||
                  activePath == AppRoutes.groupDetail ||
                  activeRoute == AppRoutes.tools ||
                  activeRoute.startsWith('/student-services/') ||
                  activeRoute == AppRoutes.schoolExamPrep));
      return Semantics(
        button: true,
        label: label,
        selected: active,
        child: SizedBox(
          width: railWidth - 20,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: InkWell(
              onTap: () {
                if (label == '더보기') {
                  MobileStudentBottomAppBar.openMore(context);
                  return;
                }
                if (active) return;
                Navigator.of(context).pushNamed(route);
              },
              child: Container(
                key: active ? ValueKey('student-rail-active-$route') : null,
                decoration: BoxDecoration(
                  color: active
                      ? StudentDensityTokens.dark
                      : Colors.transparent,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StudentHtmlGlyph(
                      key: ValueKey('student-nav-glyph-${navIcon.name}'),
                      icon: navIcon,
                      size: 17,
                      color: active
                          ? StudentDensityTokens.surface
                          : StudentDensityTokens.muted,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color: active
                            ? StudentDensityTokens.surface
                            : StudentDensityTokens.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
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

    return Container(
      key: const ValueKey('student-html-rail'),
      width: railWidth,
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 14),
      decoration: const BoxDecoration(
        color: StudentDensityTokens.surface,
        border: Border(right: BorderSide(color: StudentDensityTokens.line)),
      ),
      child: Column(
        children: [
          Container(
            key: const ValueKey('student-rail-brand'),
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: StudentDensityTokens.dark),
            child: const Text(
              'A',
              style: TextStyle(
                color: StudentDensityTokens.surface,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  item(
                    label: '홈',
                    navIcon: StudentHtmlIcon.home,
                    route: AppRoutes.studentDashboard,
                  ),
                  const SizedBox(height: 6),
                  item(
                    label: '코스',
                    navIcon: StudentHtmlIcon.courses,
                    route: AppRoutes.courses,
                  ),
                  const SizedBox(height: 6),
                  item(
                    label: '자료실',
                    navIcon: StudentHtmlIcon.market,
                    route: AppRoutes.bookbag,
                  ),
                  const SizedBox(height: 6),
                  item(
                    label: '더보기',
                    navIcon: StudentHtmlIcon.more,
                    route: AppRoutes.learningTools,
                  ),
                ],
              ),
            ),
          ),
          Container(
            key: const ValueKey('student-rail-avatar'),
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: StudentDensityTokens.dark),
            child: const Text(
              '학',
              style: TextStyle(
                color: StudentDensityTokens.surface,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StudentHtmlContextAside extends StatelessWidget {
  const StudentHtmlContextAside({super.key});

  Widget _metric(String label) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 32),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: StudentDensityTokens.muted,
            ),
          ),
        ),
        const Text(
          '—',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('student-context-aside'),
    width: 244,
    padding: const EdgeInsets.fromLTRB(18, 28, 18, 22),
    decoration: const BoxDecoration(
      color: StudentDensityTokens.surfaceMuted,
      border: Border(left: BorderSide(color: StudentDensityTokens.line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              color: StudentDensityTokens.dark,
              alignment: Alignment.center,
              child: const StudentHtmlGlyph(
                icon: StudentHtmlIcon.spark,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '오늘의 학습',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 19),
        const Divider(height: 1, color: StudentDensityTokens.line),
        const SizedBox(height: 14),
        // Daily totals have no verified data contract here; do not substitute
        // the prototype's sample totals or a page-local counter for them.
        _metric('오늘 집중'),
        const SizedBox(height: 14),
        _metric('연속 학습'),
        const Spacer(),
        SizedBox(
          height: 44,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/tools'),
            icon: const StudentHtmlGlyph(
              icon: StudentHtmlIcon.spark,
              color: Colors.white,
              size: 17,
            ),
            label: const Text('튜터에게 묻기'),
            style: FilledButton.styleFrom(
              backgroundColor: StudentDensityTokens.dark,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(),
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
