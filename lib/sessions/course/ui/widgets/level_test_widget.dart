import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/course_module_config.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/storage/local_db.dart';
import 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';
import 'package:s11/sessions/tryout_solve/ui/pages/ox_quiz_page.dart';
import 'course_runtime_state_view.dart';

/// LevelTestWidget — launches an OX quiz or exam-based level assessment.
///
/// For testType='ox': generates OX quiz questions via ApiClient and routes to OxQuizPage.
/// For testType='exam': creates an exam and routes to BuildpageWidget.
class LevelTestWidget extends StatefulWidget {
  const LevelTestWidget({super.key, required this.config, this.onComplete});

  final LevelTestConfig config;
  final void Function({
    required int correctCount,
    required int totalCount,
    required bool passed,
    int? elapsedSeconds,
  })?
  onComplete;

  @override
  State<LevelTestWidget> createState() => _LevelTestWidgetState();
}

class _LevelTestWidgetState extends State<LevelTestWidget> {
  bool _loading = true;
  String? _error;
  late final String _sessionId;
  final List<Map<String, dynamic>> _problemResults = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _sessionId = 'lt_${DateTime.now().microsecondsSinceEpoch}';
    _launchTest();
  }

  Future<void> _launchTest() async {
    final config = widget.config;
    final scaffold = ScaffoldMessenger.of(context);
    try {
      if (config.testType == 'ox') {
        // Generate OX quiz
        final questions = await ApiClient.instance.generateOxQuiz(
          tags: config.tags,
          perTag:
              (config.questionCount /
                      (config.tags.isEmpty ? 1 : config.tags.length))
                  .ceil()
                  .clamp(1, 10),
        );

        if (questions.isEmpty) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = 'OX 퀴즈 문제를 생성할 수 없습니다.';
          });
          return;
        }

        if (!mounted) return;
        final score = await Navigator.of(context).push<int>(
          MaterialPageRoute(builder: (_) => OxQuizPage(questions: questions)),
        );

        if (!mounted) return;
        Navigator.of(context).pop(score);
      } else {
        // Exam-based level test: use a teacher-selected exam when present.
        var examId = config.examId.trim();
        if (examId.isEmpty) {
          final ranges = config.tags
              .map((tag) => ExamRangeRequest(key: tag, tags: [tag]))
              .toList();

          examId = await ApiClient.instance.createExam(
            ranges: ranges.isNotEmpty
                ? ranges
                : [ExamRangeRequest(key: 'default', tags: [])],
            difficultyTier: config.difficultyTier,
            questionCount: config.questionCount,
            paperType: 'aiflow',
          );
        }

        final status = await ApiClient.instance.getExamStatus(
          examId,
          courseId: config.courseId,
        );
        final items = status.items;

        if (items.isEmpty) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = '레벨 테스트 문제를 불러올 수 없습니다.';
          });
          return;
        }

        final quests = items.map((item) {
          return <String, dynamic>{
            'item_index': item.itemIndex,
            'subject_key': item.subjectKey,
            'hash_tags': item.hashTags,
            'difficulty_tier': item.difficultyTier,
            'solves_count': item.solvesCount,
            'strategy_level': item.strategyLevel,
            'branch_conditions': item.branchConditions,
            'question_type': item.questionType,
            'quest_id': item.questId,
            'flow_count': item.flowCount,
            'codebase_id': item.codebaseId,
            'seed': item.seed,
            'quest_title': item.questTitle,
            'quest_options': item.questOptions,
            'error': item.error,
          };
        }).toList();

        final problemConfig = ProblemSolveConfig(
          questionCount: quests.length,
          hashTags: config.tags,
          gradeImmediately: true,
          minDifficultyTier: config.difficultyTier,
          maxDifficultyTier: config.difficultyTier,
          passRate: config.passRate,
          courseId: config.courseId,
          unitIndex: config.unitIndex,
          quests: quests,
          onProblemGraded:
              ({
                required int itemIndex,
                required Map<String, dynamic>? quest,
                required bool isCorrect,
                required List<Map<String, dynamic>> stepCorrectness,
                int? selectedIndex,
                int? elapsedSeconds,
              }) async {
                _recordProblemResult(
                  itemIndex: itemIndex,
                  quest: quest,
                  isCorrect: isCorrect,
                  stepCorrectness: stepCorrectness,
                  selectedIndex: selectedIndex,
                  elapsedSeconds: elapsedSeconds,
                );
              },
          onComplete:
              ({
                required int correctCount,
                required int totalCount,
                required bool passed,
                int? elapsedSeconds,
              }) {
                unawaited(
                  _finishLevelTest(
                    examId: examId,
                    correctCount: correctCount,
                    totalCount: totalCount,
                    passed: passed,
                    elapsedSeconds: elapsedSeconds,
                  ),
                );
              },
        );

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BuildpageWidget(config: problemConfig),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      scaffold.showSnackBar(SnackBar(content: Text('테스트 로드 실패: $_error')));
    }
  }

  void _recordProblemResult({
    required int itemIndex,
    required Map<String, dynamic>? quest,
    required bool isCorrect,
    required List<Map<String, dynamic>> stepCorrectness,
    int? selectedIndex,
    int? elapsedSeconds,
  }) {
    final result = <String, dynamic>{
      'item_index': itemIndex,
      'quest_id': _questIdOf(quest),
      'is_correct': isCorrect,
      'tags': _tagsOf(quest, fallback: widget.config.tags),
      if (selectedIndex != null) 'selected_index': selectedIndex,
      if (elapsedSeconds != null) 'elapsed_seconds': elapsedSeconds,
      'wrong_points': stepCorrectness
          .where((step) => step['status'] == 'X' || step['is_correct'] == false)
          .map(_compactFlowStep)
          .toList(),
      'flow_minimum': stepCorrectness.map(_compactFlowStep).toList(),
    };
    final existingIndex = _problemResults.indexWhere(
      (item) => item['item_index'] == itemIndex,
    );
    if (existingIndex >= 0) {
      _problemResults[existingIndex] = result;
    } else {
      _problemResults.add(result);
    }
  }

  Future<void> _finishLevelTest({
    required String examId,
    required int correctCount,
    required int totalCount,
    required bool passed,
    int? elapsedSeconds,
  }) async {
    final accuracy = totalCount <= 0 ? 0.0 : correctCount / totalCount * 100;
    final payload = <String, dynamic>{
      'session_id': _sessionId,
      'course_id': widget.config.courseId,
      'module_id': widget.config.moduleId,
      'exam_id': examId,
      'exam_title': widget.config.examTitle,
      'tags': widget.config.tags,
      'correct_count': correctCount,
      'total_count': totalCount,
      'accuracy': accuracy,
      'passed': passed,
      'elapsed_seconds': elapsedSeconds ?? 0,
      'analysis_model': widget.config.analysisModel,
      'analysis_retention_days': widget.config.analysisRetentionDays,
      'problem_results': List<Map<String, dynamic>>.from(_problemResults),
      'ai_summary': _buildLocalAiSummary(accuracy),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _saveLocalAnalysis(payload);
    if (widget.config.analysisEnabled) {
      try {
        await ApiClient.instance.submitLevelTestAnalysis(payload: payload);
      } catch (error) {
        debugPrint('Level test analysis upload failed: $error');
      }
    }
    widget.onComplete?.call(
      correctCount: correctCount,
      totalCount: totalCount,
      passed: passed,
      elapsedSeconds: elapsedSeconds,
    );
  }

  Future<void> _saveLocalAnalysis(Map<String, dynamic> payload) async {
    const key = 'level_test_analysis_local_v1';
    final raw = await LocalDb.instance.getString(key);
    final items = <Map<String, dynamic>>[];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          items.addAll(
            decoded.whereType<Map>().map(
              (item) => Map<String, dynamic>.from(item),
            ),
          );
        }
      } catch (_) {}
    }
    items.insert(0, payload);
    await LocalDb.instance.setString(key, jsonEncode(items.take(50).toList()));
  }

  Map<String, dynamic> _buildLocalAiSummary(double accuracy) {
    final incorrect = _problemResults
        .where((item) => item['is_correct'] == false)
        .toList(growable: false);
    final tagCounts = <String, int>{};
    for (final item in incorrect) {
      for (final tag in (item['tags'] as List? ?? const [])) {
        final key = tag.toString().trim();
        if (key.isEmpty) continue;
        tagCounts[key] = (tagCounts[key] ?? 0) + 1;
      }
    }
    final weakTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return <String, dynamic>{
      'model': widget.config.analysisModel,
      'accuracy': accuracy,
      'incorrect_count': incorrect.length,
      'weak_tags': weakTags
          .take(5)
          .map((entry) => {'tag': entry.key, 'incorrect_count': entry.value})
          .toList(),
    };
  }

  Map<String, dynamic> _compactFlowStep(Map<String, dynamic> step) {
    return <String, dynamic>{
      if (step['flow_number'] != null) 'flow_number': step['flow_number'],
      if (step['status'] != null) 'status': step['status'],
      if (step['is_correct'] != null) 'is_correct': step['is_correct'],
      if (step['flow_text'] != null) 'flow_text': step['flow_text'],
      if (step['reason'] != null) 'reason': step['reason'],
    };
  }

  String _questIdOf(Map<String, dynamic>? quest) {
    if (quest == null) return '';
    return (quest['quest_id'] ?? quest['id'] ?? '').toString();
  }

  List<String> _tagsOf(
    Map<String, dynamic>? quest, {
    List<String> fallback = const <String>[],
  }) {
    final raw = quest?['hash_tags'] ?? quest?['tags'];
    if (raw is List) {
      return raw.map((tag) => tag.toString()).toList();
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final isOx = config.testType == 'ox';
    return CourseRuntimeStateView(
      title: isOx ? 'OX 확인 학습' : '레벨 테스트',
      message: isOx ? 'OX 문항을 준비하고 있어요' : '현재 수준을 확인할 문항을 준비해요',
      icon: isOx ? Icons.rule_rounded : Icons.trending_up_rounded,
      loading: _loading,
      error: _error,
      detail: '${config.questionCount}문제 · 결과는 다음 학습 난이도에 반영됩니다.',
      onRetry: _retry,
    );
  }

  /// 필요 변수: 현재 로딩 및 오류 상태를 사용한다.
  /// 작동 원리: 오류 상태를 초기화하고 레벨 테스트 준비 과정을 다시 실행한다.
  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _launchTest();
  }
}
