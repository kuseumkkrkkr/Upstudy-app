import 'package:flutter/material.dart';
import 'package:s11/shared/theme/app_colors.dart';

/// 오답 재풀이 실행 페이지.
///
/// 실제 문제 풀이 세션은 WrongAnswerReviewWidget → BuildpageWidget 연동을 통해
/// 제공될 예정이다. 이 페이지는 해당 흐름으로 진입하기 전의 플레이스홀더 화면이다.
class WrongAnswerSolvePage extends StatelessWidget {
  const WrongAnswerSolvePage({
    super.key,
    required this.sourceType,
  });

  final String sourceType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '오답 재풀이',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '재풀이 세션이 여기에서 실행됩니다. (WrongAnswerReviewWidget 연동 예정)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
