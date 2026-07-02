import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:s11/shared/data/models/course_module_config.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';

/// ChallengeGroupWidget — loads challenge problems then routes to BuildpageWidget.
///
/// This widget generates a problem set based on challenge tags and difficulty,
/// then launches BuildpageWidget with a time-limited problem solve session.
class ChallengeGroupWidget extends StatefulWidget {
  const ChallengeGroupWidget({super.key, required this.config, this.onComplete});

  final ChallengeGroupConfig config;
  final void Function({required int correctCount, required int totalCount, required bool passed, int? elapsedSeconds})? onComplete;

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
      scaffold.showSnackBar(
        SnackBar(content: Text('도전 문제 로드 실패: $_error')),
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
                    '도전 문제를 생성하는 중...',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1B402B),
                    ),
                  ),
                  if (config.timeLimitMinutes > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '제한 시간: ${config.timeLimitMinutes}분',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
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
