import 'package:flutter/material.dart';

import 'package:s11/sessions/auth/ui/pages/profile_page.dart';
import 'package:s11/sessions/landing/ui/pages/landing_page.dart';
import 'package:s11/sessions/settings/ui/pages/settings_page.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/theme/app_colors.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  static const Color _drawerBg = Colors.white;
  static const Color _surface = Color(0xFFF5F7F1);

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
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.school_outlined,
                      color: AppColors.primary,
                      size: 30,
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
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 14),
            _DrawerItem(
              icon: Icons.person_outline_rounded,
              title: '프로필',
              subtitle: '회원정보 수정, ID/PW 변경',
              onTap: () {
                final navigator = Navigator.of(context, rootNavigator: true);
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
                final navigator = Navigator.of(context, rootNavigator: true);
                Navigator.of(context).pop();
                navigator.push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE2E7DE)),
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
