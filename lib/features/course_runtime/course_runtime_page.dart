import 'package:flutter/material.dart';
import 'package:s11/shared/theme/app_colors.dart';

/// 코스 런타임 플레이스홀더 페이지.
///
/// 실제 구현 전까지 임시로 표시되는 화면입니다.
class CourseRuntimePage extends StatelessWidget {
  const CourseRuntimePage({super.key});

  static const String routeName = '/course_runtime';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('코스 런타임'),
      ),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '코스 런타임 기능은 현재 개발 중입니다.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
