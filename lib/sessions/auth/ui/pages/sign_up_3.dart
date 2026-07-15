import 'package:flutter/material.dart';

import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
import 'package:s11/sessions/auth/session/signup_flow.dart';
import 'package:s11/sessions/auth/ui/widgets/auth_design.dart';

class BuildpageCopyCopyWidget extends StatefulWidget {
  const BuildpageCopyCopyWidget({
    super.key,
    required this.draft,
    required this.completedSteps,
    required this.totalSteps,
    required this.username,
  });

  final SignupDraft draft;
  final int completedSteps;
  final int totalSteps;
  final String username;

  @override
  State<BuildpageCopyCopyWidget> createState() =>
      _BuildpageCopyCopyWidgetState();
}

class _BuildpageCopyCopyWidgetState extends State<BuildpageCopyCopyWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  double get _startPercent {
    final total = widget.totalSteps;
    if (total <= 0) return 0;
    final value = widget.completedSteps / total;
    return value.clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _progress = Tween<double>(
      begin: _startPercent,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _goToStudent();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToStudent() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainStudentPage(username: widget.draft.displayName),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, child) => AuthFlowScaffold(
          eyebrow: 'New account · Complete',
          title: '학습 공간을\n준비하고 있어요.',
          description: '프로필과 추천 커리큘럼을 연결한 뒤 자동으로 학생 홈으로 이동합니다.',
          progress: _progress.value,
          stepLabel: '3 / 3',
          child: const _CompletionCard(),
        ),
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard();

  /// 필요한 변수는 없으며 가입 완료 대기 상태를 표시합니다.
  /// 작동 원리는 회전 인디케이터와 짧은 안내로 자동 이동 중임을 명확히 전달하는 것입니다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
    decoration: BoxDecoration(
      color: AuthDesignTokens.surfaceMuted,
      border: Border.all(color: AuthDesignTokens.line),
      borderRadius: BorderRadius.circular(22),
    ),
    child: const Column(
      children: [
        SizedBox.square(
          dimension: 34,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AuthDesignTokens.ink,
          ),
        ),
        SizedBox(height: 24),
        Text(
          '거의 다 되었습니다',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AuthDesignTokens.ink,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '잠시만 기다려주세요. 안전하게 계정을 연결하고 있습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AuthDesignTokens.muted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}
