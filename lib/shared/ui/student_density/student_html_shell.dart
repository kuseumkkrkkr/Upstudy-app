import 'package:flutter/material.dart';

import 'package:s11/app/router.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
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
    this.includeHeader = true,
  });

  final String title;
  final Widget child;
  final String activeRoute;
  final bool showContextAside;
  final VoidCallback? onSearch;
  final VoidCallback? onNotifications;
  final VoidCallback? onMenu;
  final bool includeHeader;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final wide =
        MediaQuery.sizeOf(context).width >
        StudentDensityTokens.desktopBreakpoint;
    final menu = onMenu ?? () => toggleAppDrawer(context);
    final search = onSearch ?? () {};
    final notifications = onNotifications ?? () {};

    return Scaffold(
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
                    ),
                  Expanded(child: child),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StudentHtmlRail(activeRoute: activeRoute),
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
  });

  final String title;
  final VoidCallback onMenu;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;

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
            '검색' => 'student-search-action',
            '알림' => 'student-notifications-action',
            _ => 'student-action-$label',
          }),
          width: 44,
          height: 44,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: StudentDensityTokens.ink,
              side: const BorderSide(color: StudentDensityTokens.line),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            child: Icon(icon, size: 19),
          ),
        ),
      );
    }

    return Container(
      height: 64,
      color: StudentDensityTokens.surface,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          action(label: '학생 메뉴', icon: Icons.arrow_back, onTap: onMenu),
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
  const StudentHtmlRail({super.key, required this.activeRoute});

  final String activeRoute;

  @override
  Widget build(BuildContext context) {
    final width =
        MediaQuery.sizeOf(context).width >
            StudentDensityTokens.desktopBreakpoint
        ? 84.0
        : 72.0;

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
          (route == AppRoutes.bookbag && activeRoute == AppRoutes.marketplace);
      return Semantics(
        button: true,
        label: label,
        selected: active,
        child: SizedBox(
          width: width - 20,
          height: 62,
          child: InkWell(
            onTap: () {
              if (active) return;
              Navigator.of(context).pushNamed(route);
            },
            child: Container(
              color: active ? StudentDensityTokens.dark : Colors.transparent,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 19,
                    color: active ? Colors.white : StudentDensityTokens.ink,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: active ? Colors.white : StudentDensityTokens.ink,
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
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
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
          const SizedBox(height: 30),
          item(
            label: '홈',
            icon: Icons.home_outlined,
            route: AppRoutes.studentDashboard,
          ),
          item(
            label: '코스',
            icon: Icons.view_list_outlined,
            route: AppRoutes.courses,
          ),
          item(
            label: '자료실',
            icon: Icons.archive_outlined,
            route: AppRoutes.bookbag,
          ),
          item(
            label: '더보기',
            icon: Icons.more_horiz,
            route: AppRoutes.learningTools,
          ),
          const Spacer(),
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
    padding: const EdgeInsets.fromLTRB(12, 20, 12, 18),
    decoration: const BoxDecoration(
      color: StudentDensityTokens.surface,
      border: Border(left: BorderSide(color: StudentDensityTokens.line)),
    ),
    child: const SizedBox.shrink(),
  );
}
