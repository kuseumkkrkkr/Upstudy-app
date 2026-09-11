import 'package:flutter/material.dart';

import 'package:s11/app/router.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
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
    this.onSearch,
    this.onNotifications,
    this.onMenu,
    this.mobileBackButton = false,
    this.includeHeader = true,
    this.railWidth,
  });

  final String title;
  final Widget child;
  final String activeRoute;
  final bool showContextAside;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onMenu;
  final bool mobileBackButton;
  final bool includeHeader;

  /// Optional screen-specific desktop rail width from the reference CSS.
  final double? railWidth;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width > StudentDensityTokens.desktopBreakpoint;
    final desktopRailWidth = railWidth ?? (wide ? 76.0 : 72.0);
    // The build context above Scaffold cannot resolve Scaffold.maybeOf.
    // Keep the fallback action bound to the actual Scaffold state instead.
    final scaffoldKey = GlobalKey<ScaffoldState>();
    final menu =
        onMenu ??
        () {
          final state = scaffoldKey.currentState;
          if (state == null) return;
          state.isDrawerOpen ? state.closeDrawer() : state.openDrawer();
        };
    final search = onSearch ?? () => showStudentQuickSearch(context);
    final notifications =
        onNotifications ?? () => showStudentNotifications(context);

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: StudentDensityTokens.background,
      drawer: const AppDrawer(),
      bottomNavigationBar: mobile
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
                          ),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                  if (wide && showContextAside) const StudentHtmlContextAside(),
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
  });

  final String title;
  final VoidCallback onMenu;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final bool mobileBackButton;

  @override
  Widget build(BuildContext context) {
    Widget action({
      required String label,
      required IconData icon,
      required VoidCallback onTap,
    }) {
      return Semantics(
        button: true,
        label: label,
        child: SizedBox(
          key: ValueKey(switch (label) {
            '학생 메뉴' => 'student-mobile-menu',
            '뒤로가기' => 'student-mobile-back',
            '검색' => 'student-search-action',
            '알림' => 'student-notifications-action',
            _ => 'student-action-$label',
          }),
          width: 38,
          height: 38,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: StudentDensityTokens.ink,
              side: const BorderSide(color: StudentDensityTokens.line),
              shape: const CircleBorder(),
            ),
            child: Icon(icon, size: 19),
          ),
        ),
      );
    }

    final topBarHeight = 64.0;
    final mobile = isStudentDensityMobile(context);
    final menuLabel = mobile && mobileBackButton ? '뒤로가기' : '학생 메뉴';
    return Container(
      height: topBarHeight,
      color: StudentDensityTokens.surface,
      padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 22),
      child: Row(
        children: [
          action(
            label: menuLabel,
            icon: mobile && !mobileBackButton
                ? Icons.menu_rounded
                : Icons.arrow_back,
            onTap: onMenu,
          ),
          const SizedBox(width: 10),
          KeyedSubtree(
            key: const ValueKey('student-brand-home'),
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
          const Spacer(),
          action(label: '검색', icon: Icons.search, onTap: onSearch),
          const SizedBox(width: 8),
          action(
            label: '알림',
            icon: Icons.notifications_none,
            onTap: onNotifications,
          ),
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
    final railWidth =
        width ??
        (MediaQuery.sizeOf(context).width >
                StudentDensityTokens.desktopBreakpoint
            ? 84.0
            : 72.0);

    Widget item({
      required String label,
      required IconData icon,
      required String route,
    }) {
      // 자료실은 HTML에서 교재 보관함과 마켓을 하나의 정보 구조로 묶지만,
      // 실제 데이터 화면은 두 개의 명명 라우트를 유지한다. 두 목적지 모두
      // 같은 레일 항목을 강조해 현재 위치를 잃지 않게 한다.
      final active =
          activeRoute == route ||
          (route == AppRoutes.bookbag && activeRoute == AppRoutes.marketplace) ||
          (route == AppRoutes.learningTools &&
              (activeRoute == AppRoutes.store ||
                  activeRoute == AppRoutes.tools ||
                  activeRoute.startsWith('/student-services/') ||
                  activeRoute == AppRoutes.schoolExamPrep));
      return Semantics(
        button: true,
        label: label,
        selected: active,
        child: SizedBox(
          width: railWidth - 20,
          height: 58,
          child: InkWell(
            onTap: () {
              if (active) return;
              Navigator.of(context).pushNamed(route);
            },
            child: Container(
            decoration: BoxDecoration(
                color: active ? StudentDensityTokens.surface : Colors.transparent,
                borderRadius: BorderRadius.zero,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 19,
                    color: active ? StudentDensityTokens.ink : StudentDensityTokens.muted,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: active ? StudentDensityTokens.ink : StudentDensityTokens.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: railWidth,
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 14),
      decoration: const BoxDecoration(
        color: StudentDensityTokens.surface,
        border: Border(right: BorderSide(color: StudentDensityTokens.line)),
      ),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            color: StudentDensityTokens.dark,
            child: const Text(
              'A',
              style: TextStyle(
                color: Colors.white,
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
                    icon: Icons.home_outlined,
                    route: AppRoutes.studentDashboard,
                  ),
                  const SizedBox(height: 6),
                  item(
                    label: '코스',
                    icon: Icons.view_list_outlined,
                    route: AppRoutes.courses,
                  ),
                  const SizedBox(height: 6),
                  item(
                    label: '자료실',
                    icon: Icons.archive_outlined,
                    route: AppRoutes.bookbag,
                  ),
                  const SizedBox(height: 6),
                  item(
                    label: '더보기',
                    icon: Icons.more_horiz,
                    route: AppRoutes.learningTools,
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            color: StudentDensityTokens.dark,
            child: const Text(
              '학',
              style: TextStyle(
                color: Colors.white,
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

  @override
  Widget build(BuildContext context) => Container(
    width: 244,
    padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
    decoration: const BoxDecoration(
      color: StudentDensityTokens.surface,
      border: Border(left: BorderSide(color: StudentDensityTokens.line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'CONTEXT',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w900,
            color: StudentDensityTokens.muted,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          color: StudentDensityTokens.dark,
          padding: const EdgeInsets.all(14),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '오늘의 학습',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '학습 흐름을\n이어가세요.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        const Text(
          '빠른 이동',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          '검색과 알림은 상단 버튼에서\n언제든지 열 수 있어요.',
          style: TextStyle(color: StudentDensityTokens.muted, height: 1.45),
        ),
      ],
    ),
  );
}
