import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/course_module_config.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';
import 'course_runtime_state_view.dart';

/// ChallengeGroupWidget — loads challenge problems then routes to BuildpageWidget.
///
/// This widget generates a problem set based on challenge tags and difficulty,
/// then launches BuildpageWidget with a time-limited problem solve session.
class ChallengeGroupWidget extends StatefulWidget {
  const ChallengeGroupWidget({
    super.key,
    required this.config,
    this.onComplete,
  });

  final ChallengeGroupConfig config;
  final void Function({
    required int correctCount,
    required int totalCount,
    required bool passed,
    int? elapsedSeconds,
  })?
  onComplete;

  @override
  State<ChallengeGroupWidget> createState() => _ChallengeGroupWidgetState();
}

class _ChallengeGroupWidgetState extends State<ChallengeGroupWidget> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAndLaunch();
  }

  Future<void> _loadAndLaunch() async {
    final config = widget.config;
    final scaffold = ScaffoldMessenger.of(context);
    try {
      // Generate problem set via streaming API
      final stream = ApiClient.instance.generateProblemSetStream(
        hashTags: config.tags,
        questionCount: config.questionCount,
        minDifficultyTier: config.difficultyTier,
        maxDifficultyTier: config.difficultyTier,
      );

      final quests = <Map<String, dynamic>>[];
      await for (final problem in stream) {
        quests.add(problem);
      }

      if (quests.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = '도전 문제를 생성할 수 없습니다.';
        });
        return;
      }

      final problemConfig = ProblemSolveConfig(
        questionCount: quests.length,
        hashTags: config.tags,
        gradeImmediately: true,
        minDifficultyTier: config.difficultyTier,
        maxDifficultyTier: config.difficultyTier,
        passRate: 100,
        courseId: config.courseId,
        unitIndex: config.unitIndex,
        quests: quests,
        onComplete: widget.onComplete,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BuildpageWidget(config: problemConfig),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      scaffold.showSnackBar(SnackBar(content: Text('도전 문제 로드 실패: $_error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return CourseRuntimeStateView(
      title: '도전 학습',
      message: '도전 문제를 준비하고 있어요',
      icon: Icons.emoji_events_outlined,
      loading: _loading,
      error: _error,
      detail: config.timeLimitMinutes > 0
          ? '총 ${config.questionCount}문제 · 제한 시간 ${config.timeLimitMinutes}분'
          : '총 ${config.questionCount}문제 · 나에게 맞는 난이도로 구성 중입니다.',
      onRetry: _retry,
    );
  }

  /// 필요 변수: 현재 로딩 및 오류 상태를 사용한다.
  /// 작동 원리: 이전 오류를 비우고 도전 문제 생성 요청을 다시 시작한다.
  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _loadAndLaunch();
  }
}
