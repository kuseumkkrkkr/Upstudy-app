import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/course_module_config.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';
import 'course_runtime_state_view.dart';

/// WrongAnswerReviewWidget — loads weakness/habit problems then routes to BuildpageWidget.
///
/// This widget fetches problems based on the student's weakness tags or problem habits,
/// then launches BuildpageWidget with the loaded quests.
class WrongAnswerReviewWidget extends StatefulWidget {
  const WrongAnswerReviewWidget({
    super.key,
    required this.config,
    this.onComplete,
  });

  final WrongAnswerReviewConfig config;
  final void Function({
    required int correctCount,
    required int totalCount,
    required bool passed,
    int? elapsedSeconds,
  })?
  onComplete;

  @override
  State<WrongAnswerReviewWidget> createState() =>
      _WrongAnswerReviewWidgetState();
}

class _WrongAnswerReviewWidgetState extends State<WrongAnswerReviewWidget> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAndLaunch();
    });
  }

  Future<void> _loadAndLaunch() async {
    final config = widget.config;
    try {
      List<Map<String, dynamic>> quests = [];

      if (config.sourceType == 'weakness') {
        // Fetch weakness tags and convert to quests via searchQuests
        final tags = config.tags.isNotEmpty
            ? config.tags
            : (await ApiClient.instance.fetchWeaknessTags())
                  .map((t) => t.tag)
                  .toList();
        if (tags.isNotEmpty) {
          final results = await ApiClient.instance.searchQuests(
            hashTag: tags.first,
            pageSize: config.questionCount,
          );
          quests = results;
        }
      } else if (config.sourceType == 'habit') {
        // Fetch problem habits and replay them
        final habits = await ApiClient.instance.fetchProblemHabits(
          days: 60,
          limit: config.questionCount,
        );
        for (final habit in habits.take(config.questionCount)) {
          try {
            final quest = await ApiClient.instance.replayProblemHabit(
              codebaseId: habit.codebaseId,
              seed: habit.seed.toString(),
              questId: habit.questTitle,
            );
            quests.add(quest);
          } catch (_) {
            // Skip individual failures
          }
        }
      }

      if (quests.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = '복습할 문제를 찾을 수 없습니다.';
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
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('문제 로드 실패: $_error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CourseRuntimeStateView(
      title: '오답 복습',
      message: '복습할 문제를 찾고 있어요',
      icon: Icons.replay_rounded,
      loading: _loading,
      error: _error,
      detail: '${widget.config.questionCount}문제 · 최근 취약점과 풀이 기록을 반영합니다.',
      onRetry: _retry,
      embedded: true,
    );
  }

  /// 필요 변수: 현재 로딩 및 오류 상태를 사용한다.
  /// 작동 원리: 이전 오류를 제거하고 복습 문제 조회를 다시 요청한다.
  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _loadAndLaunch();
  }
}
