import 'package:flutter/material.dart';
import 'package:s11_teacher/pages/course_list_page.dart';
import 'package:s11_teacher/pages/group_study/group_study.dart';
import 'package:s11_teacher/pages/problem_editor_page.dart';
import 'package:s11_teacher/pages/teacher_social_page.dart';
import 'package:s11_teacher/services/api_client.dart';
import 'package:s11_teacher/widgets/design_tokens.dart';
import 'package:s11_teacher/shared/ui/ios26/ios26_chrome.dart';

class TeacherAppDrawer extends StatelessWidget {
  const TeacherAppDrawer({
    super.key,
    this.currentRoute,
    this.onOpenProfile,
    this.onOpenSettings,
    this.onConfirmLogout,
  });

  final String? currentRoute;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenSettings;
  final Future<void> Function()? onConfirmLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF6FAF8),
      child: SafeArea(
        child: FutureBuilder<UserProfile>(
          future: ApiClient.instance.getMyProfile(),
          builder: (context, snapshot) {
            final profile = snapshot.data;
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Ios26FrostedCard(
                    radius: 28,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: kCourseGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: kCourseGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '교사용 메뉴',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: kCourseGreen,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isLoading || profile == null
                                    ? '프로필을 불러오는 중입니다.'
                                    : '${profile.username} · ${profile.name}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black.withValues(alpha: 0.58),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _TeacherDrawerNavAction(
                        icon: Icons.dashboard_customize_outlined,
                        title: '대시보드',
                        subtitle: '교사용 홈으로 이동합니다.',
                        selected: currentRoute == '/dashboard',
                        onTap: () {
                          Navigator.pop(context);
                          if (currentRoute == '/dashboard') return;
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/dashboard',
                            (route) => false,
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _TeacherDrawerNavAction(
                        icon: Icons.groups_rounded,
                        title: '그룹스터디',
                        subtitle: '교사 그룹 생성, 공유, 멤버 관리를 엽니다.',
                        selected: currentRoute == GroupListPage.routeName,
                        onTap: () {
                          Navigator.pop(context);
                          if (currentRoute == GroupListPage.routeName) return;
                          Navigator.of(
                            context,
                          ).pushNamed(GroupListPage.routeName);
                        },
                      ),
                      const SizedBox(height: 10),
                      _TeacherDrawerNavAction(
                        icon: Icons.menu_book_outlined,
                        title: '교재',
                        subtitle: '교재 목록과 코스 자료를 관리합니다.',
                        selected: currentRoute == CourseListPage.routeName,
                        onTap: () {
                          Navigator.pop(context);
                          if (currentRoute == CourseListPage.routeName) return;
                          Navigator.of(
                            context,
                          ).pushNamed(CourseListPage.routeName);
                        },
                      ),
                      const SizedBox(height: 10),
                      _TeacherDrawerNavAction(
                        icon: Icons.forum_outlined,
                        title: '친구/채팅',
                        subtitle: '교사용 친구 목록과 1:1 채팅으로 이동합니다.',
                        selected: currentRoute == TeacherSocialPage.routeName,
                        onTap: () {
                          Navigator.pop(context);
                          if (currentRoute == TeacherSocialPage.routeName) {
                            return;
                          }
                          Navigator.of(
                            context,
                          ).pushNamed(TeacherSocialPage.routeName);
                        },
                      ),
                      const SizedBox(height: 10),
                      _TeacherDrawerNavAction(
                        icon: Icons.edit_note_rounded,
                        title: '문항 제작',
                        subtitle: '문항 초안과 변형 화면으로 이동합니다.',
                        selected: currentRoute == '/problem-editor',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ProblemEditorPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      if (onOpenProfile != null) ...[
                        _TeacherDrawerNavAction(
                          icon: Icons.person_outline,
                          title: '프로필',
                          subtitle: '회원 정보와 계정 상태를 수정합니다.',
                          onTap: () {
                            Navigator.pop(context);
                            onOpenProfile?.call();
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (onOpenSettings != null) ...[
                        _TeacherDrawerNavAction(
                          icon: Icons.settings_outlined,
                          title: '설정',
                          subtitle: '앱 환경과 계정 옵션을 조정합니다.',
                          onTap: () {
                            Navigator.pop(context);
                            onOpenSettings?.call();
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      _TeacherDrawerNavAction(
                        icon: Icons.logout_rounded,
                        title: '로그아웃',
                        subtitle: '현재 계정에서 안전하게 로그아웃합니다.',
                        onTap: () async {
                          Navigator.pop(context);
                          if (onConfirmLogout != null) {
                            await onConfirmLogout!.call();
                            return;
                          }
                          await ApiClient.instance.clearToken();
                          if (!context.mounted) return;
                          Navigator.of(
                            context,
                          ).pushNamedAndRemoveUntil('/login', (route) => false);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TeacherDrawerNavAction extends StatelessWidget {
  const _TeacherDrawerNavAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final bgColor = selected
        ? kCourseGreen.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.82);
    final borderColor = selected
        ? kCourseGreen.withValues(alpha: 0.22)
        : Colors.black.withValues(alpha: 0.05);
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kCourseGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: kCourseGreen),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kCourseGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.56),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: kCourseGreen),
            ],
          ),
        ),
      ),
    );
  }
}
