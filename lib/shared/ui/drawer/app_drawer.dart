import 'package:flutter/material.dart';

import 'package:s11/sessions/auth/ui/pages/profile_page.dart';
import 'package:s11/sessions/landing/ui/pages/landing_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/server_chat_page.dart';
import 'package:s11/sessions/settings/ui/pages/settings_page.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/theme/app_colors.dart';
import 'package:s11/shared/ui/modal/level_detail_modal.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  static const Color _drawerBg = Colors.white;
  static const Color _surface = Color(0xFFF5F7F1);

  /// 필요한 변수는 현재 화면 문맥과 학생 목적지 경로다.
  /// 드로어를 먼저 닫고 루트 내비게이터의 명명 라우트로 이동해 모바일에서도 모든 상단 메뉴를 제공한다.
  void _openRoute(BuildContext context, String route) {
    final navigator = Navigator.of(context, rootNavigator: true);
    Navigator.of(context).pop();
    navigator.pushNamed(route);
  }

  /// 필요한 변수는 인증된 학생 문맥과 공용 명명 라우트다.
  /// 핵심 학습·소셜 메뉴는 스크롤 영역에 두고 로그아웃은 하단에 고정한다.
  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 360,
      backgroundColor: _drawerBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      semanticLabel: 'AIFlow 로고',
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'AIFlow',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 30,
                      height: 1.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '학습을 더 깔끔하게 관리하세요.',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.55),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _DrawerAccountSummary(),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 14),
                children: [
                  _DrawerItem(
                    icon: Icons.home_outlined,
                    title: '학습터',
                    subtitle: '오늘 학습과 학습 도구',
                    onTap: () => _openRoute(context, '/study-center'),
                  ),
                  _DrawerItem(
                    icon: Icons.route_outlined,
                    title: '코스',
                    subtitle: '수강 코스와 새 코스 탐색',
                    onTap: () => _openRoute(context, '/courses'),
                  ),
                  _DrawerItem(
                    icon: Icons.menu_book_outlined,
                    title: '책가방',
                    subtitle: '교재와 시험지 모아보기',
                    onTap: () => _openRoute(context, '/bookbag'),
                  ),
                  _DrawerItem(
                    icon: Icons.people_outline_rounded,
                    title: '친구/소셜',
                    subtitle: '친구, 그룹, 학원 커뮤니티',
                    onTap: () => _openRoute(context, '/social'),
                  ),
                  _DrawerItem(
                    icon: Icons.storefront_outlined,
                    title: '마켓플레이스',
                    subtitle: '검색과 필터로 상품 찾기',
                    onTap: () => _openRoute(context, '/marketplace'),
                  ),
                  const Divider(height: 22, indent: 24, endIndent: 24),
                  _DrawerItem(
                    icon: Icons.smart_toy_outlined,
                    title: 'AI 챗봇',
                    subtitle: '짧게 묻고 바로 답을 받습니다',
                    onTap: () {
                      final navigator = Navigator.of(
                        context,
                        rootNavigator: true,
                      );
                      Navigator.of(context).pop();
                      navigator.push(
                        PageRouteBuilder(
                          opaque: false,
                          barrierDismissible: true,
                          barrierLabel: '닫기',
                          barrierColor: Colors.transparent,
                          pageBuilder: (_, __, ___) => const ServerChatPage(),
                          transitionsBuilder: (_, animation, __, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                        ),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.person_outline_rounded,
                    title: '프로필',
                    subtitle: '회원정보 수정, ID/PW 변경',
                    onTap: () {
                      final navigator = Navigator.of(
                        context,
                        rootNavigator: true,
                      );
                      Navigator.of(context).pop();
                      navigator.push(
                        MaterialPageRoute(builder: (_) => const ProfilePage()),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    title: '설정',
                    subtitle: '알림과 라이선스를 정리합니다',
                    onTap: () {
                      final navigator = Navigator.of(
                        context,
                        rootNavigator: true,
                      );
                      Navigator.of(context).pop();
                      navigator.push(
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Material(
                color: _surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: const BorderSide(color: Color(0xFFE2E7DE)),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    '로그아웃',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  onTap: () async {
                    final navigator = Navigator.of(
                      context,
                      rootNavigator: true,
                    );
                    Navigator.of(context).pop();
                    await ApiClient.instance.clearToken();
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LandingPage()),
                      (route) => false,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerAccountSummary extends StatefulWidget {
  const _DrawerAccountSummary();

  @override
  State<_DrawerAccountSummary> createState() => _DrawerAccountSummaryState();
}

class _DrawerAccountSummaryState extends State<_DrawerAccountSummary> {
  late final Future<AccountSummary> _summary = ApiClient.instance
      .fetchAccountSummary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AccountSummary>(
      future: _summary,
      builder: (context, snapshot) {
        final account = snapshot.data;
        if (account == null) {
          return const SizedBox(height: 54);
        }

        return InkWell(
          onTap: () => LevelDetailModal.show(context, account),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppDrawer._surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E7DE)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: account.levelProgress,
                          minHeight: 8,
                          backgroundColor: Colors.white,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.success,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'lv. ${account.level}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      color: Color(0xFFD59B19),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${account.totalPoints}',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAF7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEAECE2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF6D756D),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
