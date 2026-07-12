import 'package:flutter/material.dart';
import 'package:s11/features/level_test/level_test_result_page.dart';
import 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';
import 'package:s11/shared/business/repositories/rating_store.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/theme/app_colors.dart';

class LevelTestHomePage extends StatefulWidget {
  const LevelTestHomePage({super.key});

  static const routeName = '/level_test';

  @override
  State<LevelTestHomePage> createState() => _LevelTestHomePageState();
}

class _LevelTestHomePageState extends State<LevelTestHomePage> {
  static const int _questionCount = 50;
  static const String _difficultyLabel = '중상~상';
  static const String _durationLabel = '약 60~90분';

  bool _loading = false;
  String? _error;

  Future<void> _startPlacement() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await ApiClient.instance.startLevelTestPlacement();
      if (!mounted) return;
      final questions = session.questions;
      if (questions.isEmpty) {
        throw Exception('레벨테스트 문제를 불러오지 못했어요');
      }
      final byIndex = {
        for (final question in questions) question.itemIndex: question,
      };
      final config = ProblemSolveConfig(
        questionCount: questions.length,
        hashTags: questions.expand((q) => q.hashTags).toSet().toList(),
        gradeImmediately: true,
        minDifficultyTier: 2,
        maxDifficultyTier: 5,
        passRate: 1,
        ratingEnabled: false,
        quests: questions.map((q) => q.quest).toList(),
        onProblemGraded:
            ({
              required int itemIndex,
              required Map<String, dynamic>? quest,
              required bool isCorrect,
              required List<Map<String, dynamic>> stepCorrectness,
              int? selectedIndex,
              int? elapsedSeconds,
            }) async {
              final question = byIndex[itemIndex];
              final questId = question?.questId ?? _questIdOf(quest);
              if (questId.isEmpty) return;
              await ApiClient.instance.submitLevelTestPlacementAnswer(
                sessionId: session.sessionId,
                itemIndex: itemIndex,
                questId: questId,
                isCorrect: isCorrect,
                answerTime: elapsedSeconds,
                stepCorrectness: stepCorrectness,
                tags: question?.hashTags ?? _tagsOf(quest),
              );
            },
        onComplete:
            ({
              required int correctCount,
              required int totalCount,
              required bool passed,
              int? elapsedSeconds,
            }) {
              _finishPlacement(session.sessionId);
            },
      );
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BuildpageWidget(config: config)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _finishPlacement(String sessionId) async {
    try {
      final result = await ApiClient.instance.submitLevelTestPlacement(
        sessionId,
      );
      RatingStore.updateFromRating(result.toUserRating());
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LevelTestResultPage(placementResult: result),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '레벨테스트 결과 반영 실패: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  String _questIdOf(Map<String, dynamic>? quest) {
    final header = quest?['header'];
    if (header is Map) return (header['quest_id'] ?? '').toString();
    return '';
  }

  List<String> _tagsOf(Map<String, dynamic>? quest) {
    final info = quest?['info'];
    if (info is! Map) return const <String>[];
    return (info['hash_tag'] as List<dynamic>? ?? const [])
        .map((tag) => tag.toString())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '레벨 테스트',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.assignment_outlined,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '레이팅 추정 레벨테스트',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '시험지 후보군에서 선별된 50문항으로 현재 실력을 추정합니다.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      Expanded(
                        child: _LevelTestInfoTile(
                          icon: Icons.format_list_numbered_rounded,
                          label: '문항 수',
                          value: '$_questionCount문항',
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _LevelTestInfoTile(
                          icon: Icons.speed_rounded,
                          label: '난이도',
                          value: _difficultyLabel,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _LevelTestInfoTile(
                          icon: Icons.schedule_rounded,
                          label: '예상 소요시간',
                          value: _durationLabel,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Text(
                      '이것은 추정 레이팅이며, 변동 가능성이 있습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  ElevatedButton(
                    onPressed: _loading ? null : _startPlacement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '레벨테스트 시작',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  if (_loading) ...[
                    const SizedBox(height: 12),
                    const Text(
                      '레벨테스트 준비 중',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelTestInfoTile extends StatelessWidget {
  const _LevelTestInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
