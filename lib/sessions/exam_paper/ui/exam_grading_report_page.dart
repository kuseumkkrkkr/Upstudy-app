part of 'package:s11/sessions/exam_paper/session/exam_paper_page.dart';

class _ExamGradingReportPage extends StatelessWidget {
  const _ExamGradingReportPage({
    required this.results,
    required this.totalQuestions,
    required this.passRate,
    required this.passed,
    this.examId,
  });

  final List<_GradeResult> results;
  final int totalQuestions;
  final int passRate;
  final bool passed;
  final String? examId;

  /// 채점 결과를 성취도와 문항별 검토 흐름으로 묶어 보여줍니다.
  ///
  /// [results]의 채점 상태를 집계해 상단 요약과 아래 문항 목록에 같은
  /// 색상 체계를 적용하므로, 사용자가 전체 결과와 개별 원인을 빠르게 연결합니다.
  @override
  Widget build(BuildContext context) {
    final total = totalQuestions > 0 ? totalQuestions : results.length;
    final emptyCount = results.where((result) => result.empty).length;
    final errorCount = results.where((result) => result.error != null).length;
    final correctCount = results
        .where((result) => result.isCorrect == true)
        .length;
    final incorrectCount = results
        .where((result) => result.isCorrect == false)
        .length;
    final gradedCount = results
        .where((result) => !result.empty && result.error == null)
        .length;
    final ungraded = math.max(0, total - results.length);
    final processed = results.length;
    final progress = total > 0 ? processed / total : 0.0;
    final score = total > 0 ? correctCount / total : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('시험 결과'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHero(
            total: total,
            correct: correctCount,
            incorrect: incorrectCount,
            score: score,
            examId: examId,
            passRate: passRate,
            passed: passed,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressSection(
                  total: total,
                  processed: processed,
                  progress: progress,
                  graded: gradedCount,
                  empty: emptyCount,
                  errors: errorCount,
                  ungraded: ungraded,
                ),
                const SizedBox(height: 28),
                Text(
                  '문항별 결과',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '문항을 눌러 채점 상세와 풀이 흐름을 확인하세요.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                if (results.isEmpty)
                  _buildEmptyState()
                else
                  ...results.map(
                    (result) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildResultTile(context, result),
                    ),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: passed
                        ? () => Navigator.of(context).pop(true)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE3E8E3),
                      disabledForegroundColor: Colors.black38,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(passed ? '완료' : '통과 후 완료할 수 있어요'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 시험의 핵심 점수를 한눈에 전달하는 상단 영역입니다.
  ///
  /// 정답률을 큰 숫자와 보조 지표로 제한해, 채점 정보가 과도하게 분산되지 않도록 합니다.
  Widget _buildHero({
    required int total,
    required int correct,
    required int incorrect,
    required double score,
    required int passRate,
    required bool passed,
    String? examId,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '채점이 완료되었어요',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            '${(score * 100).round()}점',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$total문제 중 $correct문제 정답',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            passed ? '통과 · 기준 $passRate점' : '미통과 · 기준 $passRate점',
            style: TextStyle(
              color: passed ? const Color(0xFF9DE7AE) : const Color(0xFFFFB1A8),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (examId != null && examId.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '시험 ID ${examId.substring(0, math.min(8, examId.length))}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHeroStat('정답', correct, const Color(0xFF9DE7AE)),
              Container(width: 1, height: 26, color: Colors.white24),
              _buildHeroStat('오답', incorrect, const Color(0xFFFFB1A8)),
            ],
          ),
        ],
      ),
    );
  }

  /// 상단의 정답·오답 지표를 동일한 폭으로 배치합니다.
  Widget _buildHeroStat(String label, int count, Color color) {
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// 처리 상태를 진행 막대와 간결한 지표로 표시합니다.
  Widget _buildProgressSection({
    required int total,
    required int processed,
    required double progress,
    required int graded,
    required int empty,
    required int errors,
    required int ungraded,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '채점 현황',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                '$processed / $total',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: const Color(0xFFE9EEE9),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryLight,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _buildStatusText('채점 완료', graded, AppColors.primary),
              if (empty > 0)
                _buildStatusText('미응답', empty, const Color(0xFFE08C1A)),
              if (errors > 0)
                _buildStatusText('오류', errors, const Color(0xFFD94B42)),
              if (ungraded > 0)
                _buildStatusText('미채점', ungraded, Colors.blueGrey),
            ],
          ),
        ],
      ),
    );
  }

  /// 보조 상태를 점과 텍스트로 표현해 칩 형태의 시각적 분절을 줄입니다.
  Widget _buildStatusText(String label, int count, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        '$label $count',
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  /// 채점 결과가 없을 때 목록의 빈 이유를 명확히 안내합니다.
  Widget _buildEmptyState() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 40),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: const Text(
      '표시할 문항별 결과가 없습니다.',
      style: TextStyle(color: Colors.black54),
    ),
  );

  /// 문항 상태에 맞는 색상과 상세 정보를 하나의 확장 행에 제공합니다.
  Widget _buildResultTile(BuildContext context, _GradeResult result) {
    final statusLabel = result.empty
        ? '미응답'
        : result.error != null
        ? '오류'
        : '채점 완료';
    final statusColor = result.empty
        ? Colors.orange
        : result.error != null
        ? Colors.redAccent
        : const Color(0xFF1B402B);
    final gradingStatus = result.empty
        ? '미응답'
        : result.error != null
        ? '채점 실패'
        : '채점 성공';
    final gradingColor = result.empty
        ? Colors.orange
        : result.error != null
        ? Colors.redAccent
        : const Color(0xFF1B402B);
    final correctnessLabel = result.isCorrect == true
        ? '정답'
        : result.isCorrect == false
        ? '오답'
        : '판정 불가';
    final correctnessColor = result.isCorrect == true
        ? const Color(0xFF2E7D32)
        : result.isCorrect == false
        ? const Color(0xFFD32F2F)
        : Colors.black45;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: AppColors.primary,
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(
            result.isCorrect == true
                ? Icons.check_rounded
                : Icons.remove_rounded,
            color: statusColor,
          ),
        ),
        title: Text(
          '문제 ${result.itemIndex}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          statusLabel,
          style: TextStyle(color: statusColor, fontSize: 12),
        ),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip('채점', gradingStatus, gradingColor),
              _buildStatusChip('결과', correctnessLabel, correctnessColor),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: const SizedBox.shrink(),
          ),
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '경고: ${result.warnings.join(', ')}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ],
          if (result.quest != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FlowViewPage(
                        quest: result.quest!,
                        title: '문제 ${result.itemIndex} 풀이 흐름',
                        stepCorrectness: result.stepCorrectness,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.account_tree_outlined, size: 18),
                label: const Text('플로우 차트 보기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1B402B),
                  side: const BorderSide(color: Color(0xFF1B402B)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 펼친 문항의 상태 값을 읽기 쉬운 작은 배지로 표시합니다.
  Widget _buildStatusChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
