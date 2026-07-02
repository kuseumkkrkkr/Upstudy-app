import 'package:flutter/material.dart';
import 'package:s11/shared/theme/app_colors.dart';

/// Level test result page showing score, badge, and home button.
class LevelTestResultPage extends StatelessWidget {
  const LevelTestResultPage({
    super.key,
    required this.correctCount,
    required this.totalCount,
    required this.passed,
  });

  final int correctCount;
  final int totalCount;
  final bool passed;

  double get _percentage {
    if (totalCount == 0) return 0;
    return (correctCount / totalCount) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final pct = _percentage.toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '테스트 결과',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (passed)
                const Icon(
                  Icons.celebration,
                  color: Colors.amber,
                  size: 64,
                )
              else
                const Icon(
                  Icons.sentiment_dissatisfied,
                  color: Colors.grey,
                  size: 64,
                ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: passed
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  passed ? '합격' : '불합격',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: passed ? AppColors.primary : Colors.red,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '$correctCount / $totalCount',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '정답률 $pct%',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 40),
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
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text(
                    '홈으로',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
