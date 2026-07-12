import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:s11/shared/data/models/course_module_config.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';

/// ExamSolveWidget — creates an exam via ApiClient then routes to BuildpageWidget.
///
/// This widget is a launcher: it shows a loading state while creating the exam,
/// then automatically navigates to BuildpageWidget with the exam items as quests.
class ExamSolveWidget extends StatefulWidget {
  const ExamSolveWidget({super.key, required this.config, this.onComplete});

  final ExamSolveConfig config;
  final void Function({
    required int correctCount,
    required int totalCount,
    required bool passed,
    int? elapsedSeconds,
  })?
  onComplete;

  @override
  State<ExamSolveWidget> createState() => _ExamSolveWidgetState();
}

class _ExamSolveWidgetState extends State<ExamSolveWidget> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _createAndLaunchExam();
  }

  Future<void> _createAndLaunchExam() async {
    final config = widget.config;
    final scaffold = ScaffoldMessenger.of(context);
    try {
      // If examId is already provided, skip creation
      String examId = config.examId;
      if (examId.isEmpty) {
        final ranges = config.ranges
            .map((r) => ExamRangeRequest(key: r.key, tags: r.tags))
            .toList();
        examId = await ApiClient.instance.createExam(
          ranges: ranges,
          difficultyTier: config.difficultyTier,
          questionCount: config.questionCount,
          paperType: config.paperType,
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
          _error = '시험에 출제된 문제가 없습니다.';
        });
        return;
      }

      // Convert ExamItem list to quest maps for BuildpageWidget
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
        hashTags: [],
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
      scaffold.showSnackBar(SnackBar(content: Text('시험 생성 실패: $_error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Center(
        child: _loading
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF1B402B)),
                  const SizedBox(height: 20),
                  Text(
                    '시험지를 생성하는 중...',
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
                      _createAndLaunchExam();
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
