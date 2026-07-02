import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:s11/shared/data/models/course_module_config.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';
import 'package:s11/sessions/tryout_solve/ui/pages/ox_quiz_page.dart';

/// LevelTestWidget — launches an OX quiz or exam-based level assessment.
///
/// For testType='ox': generates OX quiz questions via ApiClient and routes to OxQuizPage.
/// For testType='exam': creates an exam and routes to BuildpageWidget.
class LevelTestWidget extends StatefulWidget {
  const LevelTestWidget({super.key, required this.config, this.onComplete});

  final LevelTestConfig config;
  final void Function({required int correctCount, required int totalCount, required bool passed, int? elapsedSeconds})? onComplete;

  @override
  State<LevelTestWidget> createState() => _LevelTestWidgetState();
}

class _LevelTestWidgetState extends State<LevelTestWidget> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
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
          perTag: (config.questionCount / (config.tags.isEmpty ? 1 : config.tags.length))
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
          MaterialPageRoute(
            builder: (_) => OxQuizPage(questions: questions),
          ),
        );

        if (!mounted) return;
        Navigator.of(context).pop(score);
      } else {
        // Exam-based level test: create exam then route to BuildpageWidget
        final ranges = config.tags
            .map((tag) => ExamRangeRequest(key: tag, tags: [tag]))
            .toList();

        final examId = await ApiClient.instance.createExam(
          ranges: ranges.isNotEmpty
              ? ranges
              : [ExamRangeRequest(key: 'default', tags: [])],
          difficultyTier: config.difficultyTier,
          questionCount: config.questionCount,
          paperType: 'aiflow',
        );

        final status = await ApiClient.instance.getExamStatus(examId);
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
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      scaffold.showSnackBar(
        SnackBar(content: Text('테스트 로드 실패: $_error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Center(
        child: _loading
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF1B402B),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    config.testType == 'ox'
                        ? 'OX 퀴즈를 준비하는 중...'
                        : '레벨 테스트를 준비하는 중...',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1B402B),
                    ),
                  ),
                ],
              )
            : _error != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '오류가 발생했습니다',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _launchTest();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B402B),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('다시 시도'),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
      ),
    );
  }
}
