import 'package:flutter/material.dart';
import 'package:s11/shared/theme/app_colors.dart';
import 'package:s11/shared/data/models/course_module_config.dart';

/// Challenge detail page showing metadata and a start button.
class ChallengeDetailPage extends StatelessWidget {
  const ChallengeDetailPage({super.key, required this.config});

  final ChallengeGroupConfig config;

  void _showStartDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('도전 시작'),
          content: const Text(
            '실제 도전 과제는 ChallengeGroupWidget을 통해 시작됩니다.\n'
            '현재는 데모 화면입니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '도전과제 상세',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '도전 ID: ${config.challengeId}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '설명: 이 도전 과제는 ${config.questionCount}문제, '
              '난이도 ${config.difficultyTier}로 구성되어 있습니다.',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            if (config.timeLimitMinutes > 0)
              Text(
                '제한 시간: ${config.timeLimitMinutes}분',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            const SizedBox(height: 8),
            const Text(
              '보상: 경험치 +50, 포인트 +10',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                onPressed: () => _showStartDialog(context),
                child: const Text(
                  '과제 풀기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
