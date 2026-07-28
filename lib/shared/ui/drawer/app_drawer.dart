import 'package:flutter/material.dart';

import 'package:s11/shared/services/auth/auth_storage.dart';

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
      activeRoutes: ['/courses', '/course_runtime'],
    ),
    _DrawerDestination(
      icon: Icons.storefront_outlined,
      label: '마켓',
      route: '/marketplace',
      activeRoutes: ['/marketplace'],
    ),
  ];

  /// 필요한 변수는 현재 Navigator와 드로어 전체 메뉴다.
  /// 작동 원리는 측면 패널을 열지 않고 바텀시트에 보조 목적지만 담아 한 손 탐색을 유지한다.
  static Future<void> openMore(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF6F6F4),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            const Text(
              '더보기',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            for (final group in _navigationGroups)
              for (final item in group.items)
                if (!_primaryItems.any(
                  (primary) => primary.route == item.route,
                ))
                  ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.label),
                    minVerticalPadding: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _goToRoute(context, item.route);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  /// 필요한 변수는 선택한 명명 라우트다.
  /// 작동 원리는 중복 탭에서는 현재 화면을 보존하고 다른 탭은 루트 위에 한 번만 쌓아
  /// 모바일 하단 탭을 반복해도 뒤로가기 스택이 길어지지 않게 하는 것이다.
  static void _goToRoute(BuildContext context, String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(route, (entry) => entry.isFirst);
  }

  bool _isActive(_DrawerDestination item, String route) {
    return item.activeRoutes.any(
      (candidate) => route == candidate || route.startsWith('$candidate/'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = activeRoute ?? ModalRoute.of(context)?.settings.name ?? '';
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
                  active: false,
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

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF09090B) : const Color(0xFF76767D);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

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

  /// 필요한 변수는 화면 너비, 현재 라우트, 프로필 요약이다.
  /// 최신 학생 시안의 작은 브랜드·이어 학습·그룹형 메뉴·하단 프로필 칩 순서로 드로어를 구성한다.
  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= 780;
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
                    for (final group in _navigationGroups)
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
    final mobile = MediaQuery.sizeOf(context).width <= 780;
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
    final mobile = MediaQuery.sizeOf(context).width <= 780;
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
    final mobile = MediaQuery.sizeOf(context).width <= 780;
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
    final mobile = MediaQuery.sizeOf(context).width <= 780;
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
    final mobile = MediaQuery.sizeOf(context).width <= 780;
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
    final mobile = MediaQuery.sizeOf(context).width <= 780;
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
  });

  final IconData icon;
  final String label;
  final String route;
  final List<String> activeRoutes;
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
        label: '책가방',
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
