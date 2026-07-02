import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:s11/shared/data/models/course_module_config.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';

/// WrongAnswerReviewWidget — loads weakness/habit problems then routes to BuildpageWidget.
///
/// This widget fetches problems based on the student's weakness tags or problem habits,
/// then launches BuildpageWidget with the loaded quests.
class WrongAnswerReviewWidget extends StatefulWidget {
  const WrongAnswerReviewWidget({super.key, required this.config, this.onComplete});

  final WrongAnswerReviewConfig config;
  final void Function({required int correctCount, required int totalCount, required bool passed, int? elapsedSeconds})? onComplete;

  @override
  State<WrongAnswerReviewWidget> createState() => _WrongAnswerReviewWidgetState();
}

class _WrongAnswerReviewWidgetState extends State<WrongAnswerReviewWidget> {
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
      scaffold.showSnackBar(
        SnackBar(content: Text('문제 로드 실패: $_error')),
      );
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
                  const CircularProgressIndicator(
                    color: Color(0xFF1B402B),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '틀린 문제를 불러오는 중...',
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
                          _loadAndLaunch();
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
