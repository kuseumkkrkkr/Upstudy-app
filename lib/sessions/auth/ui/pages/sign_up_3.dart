import 'package:s11/shared/services/api/auth_service.dart';
import 'package:flutter/material.dart';
// ignore_for_file: unused_import
import 'package:percent_indicator/percent_indicator.dart';

import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
import 'package:s11/sessions/auth/session/signup_flow.dart';

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
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // 헤더
              _buildHeader(),

              // 진행률 표시
              AnimatedBuilder(
                animation: _progress,
                builder: (context, child) {
                  return LinearPercentIndicator(
                    percent: _progress.value,
                    lineHeight: 8,
                    animation: false,
                    progressColor: const Color(0xFF1B402B),
                    backgroundColor: const Color(0xFFE6E6E6),
                    padding: EdgeInsets.zero,
                  );
                },
              ),

              // 중앙 메시지
              const Expanded(
                child: Center(
                  child: Text(
                    '거의 다 되었습니다\n조금만 기다려주세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 100,
                      fontWeight: FontWeight.w900,
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 70,
      color: Colors.white,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: Color(0xFF3B3B3B),
                size: 50,
              ),
              onPressed: () {
                Navigator.of(context).maybePop();
              },
            ),
          ),
          const Text(
            'AIFlow',
            style: TextStyle(
              color: Color(0xFF1B402B),
              fontSize: 50,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
