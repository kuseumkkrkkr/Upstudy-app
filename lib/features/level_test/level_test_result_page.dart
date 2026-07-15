import 'package:flutter/material.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/theme/app_colors.dart';

/// Level test result page showing score, badge, and home button.
class LevelTestResultPage extends StatelessWidget {
  const LevelTestResultPage({
    super.key,
    this.correctCount = 0,
    this.totalCount = 0,
    this.passed = false,
    this.placementResult,
  });

  final int correctCount;
  final int totalCount;
  final bool passed;
  final LevelTestPlacementResult? placementResult;

  double get _percentage {
    if (totalCount == 0) return 0;
    return (correctCount / totalCount) * 100;
  }

  @override
  Widget build(BuildContext context) {
    if (placementResult != null) {
      return _PlacementResultView(result: placementResult!);
    }
    final pct = _percentage.toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '테스트 결과',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (passed)
                const Icon(Icons.celebration, color: Colors.amber, size: 64)
              else
                const Icon(
                  Icons.sentiment_dissatisfied,
                  color: Colors.grey,
                  size: 64,
                ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: passed
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  passed ? '합격' : '불합격',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: passed ? AppColors.primary : Colors.red,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '$correctCount / $totalCount',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '정답률 $pct%',
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text(
                    '홈으로',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlacementResultView extends StatelessWidget {
  const _PlacementResultView({required this.result});

  final LevelTestPlacementResult result;

  static const String _difficultyLabel = '중상~상';
  static const String _durationLabel = '약 60~90분';

  String get _ovrText {
    return result.ovr > 0 ? result.ovr.round().toString() : '--';
  }

  String get _confidenceText => '${(result.confidence * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '레벨테스트 결과',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(
            Icons.insights_rounded,
            color: AppColors.primary,
            size: 64,
          ),
          const SizedBox(height: 18),
          const Text(
            '레이팅 추정 완료',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          Text(
            _ovrText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 58,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'raw ${result.rating.toStringAsFixed(0)} · 신뢰도 $_confidenceText',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Column(
              children: [
                Text(
                  '난이도 $_difficultyLabel · 예상 소요시간 $_durationLabel',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '이것은 추정 레이팅이며, 변동 가능성이 있습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _TagSection(title: '강한 태그', tags: result.strongTags),
          const SizedBox(height: 14),
          _TagSection(title: '보완 태그', tags: result.weakTags),
          const SizedBox(height: 34),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text(
              '홈으로',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagSection extends StatelessWidget {
  const _TagSection({required this.title, required this.tags});

  final String title;
  final List<Map<String, dynamic>> tags;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (tags.isEmpty)
            const Text('분석할 태그가 없습니다.', style: TextStyle(color: Colors.black54))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags)
                  Chip(
                    label: Text(
                      '#${tag['tag']} ${((tag['rating'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
