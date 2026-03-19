import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppShell extends StatelessWidget {
  static const routeName = '/app';

  const AppShell({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AIFlow 홈'),
        actions: [
          if (token.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Chip(
                label: Text(
                  'JWT 확보',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                backgroundColor: theme.colorScheme.primaryContainer,
              ),
            ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '로그인에 성공했습니다.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (token.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '토큰 앞부분: ${token.substring(0, math.min(token.length, 12))}...',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              '기능 통합 전 임시 페이지입니다.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
