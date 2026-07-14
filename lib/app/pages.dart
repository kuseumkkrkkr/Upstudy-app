import 'package:flutter/material.dart';

import 'package:s11/shared/theme/app_colors.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';

/// The post-login navigation hub of the AIFlow app.
class AppShell extends StatelessWidget {
  static const routeName = '/app';

  const AppShell({super.key, this.token = ''});

  final String token;

  void _push(BuildContext context, String route) {
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(
        icon: Icons.menu_book,
        label: '학습 시작',
        color: AppColors.primary,
        route: '/student/runtime',
      ),
      _NavItem(
        icon: Icons.speed,
        label: '레벨 테스트',
        color: Colors.green,
        route: '/level_test',
      ),
      _NavItem(
        icon: Icons.calendar_month,
        label: '학습 일정',
        color: Colors.purple,
        route: '/schedule',
      ),
      _NavItem(
        icon: Icons.error_outline,
        label: '오답 노트',
        color: Colors.redAccent,
        route: '/wrong_answers',
      ),
      _NavItem(
        icon: Icons.group,
        label: '그룹 스터디',
        color: Colors.teal,
        route: '/groups',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('AIFlow'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: items
              .map(
                (item) => _FeatureCard(
                  item: item,
                  onTap: () => _push(context, item.route),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String route;
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.item, required this.onTap});

  final _NavItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 40, color: item.color),
              const SizedBox(height: 12),
              Text(
                item.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
