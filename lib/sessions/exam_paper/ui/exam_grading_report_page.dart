part of 'package:s11/sessions/exam_paper/session/exam_paper_page.dart';

class _ExamGradingReportPage extends StatelessWidget {
  const _ExamGradingReportPage({
    required this.results,
    required this.totalQuestions,
    this.examId,
  });

  final List<_GradeResult> results;
  final int totalQuestions;
  final String? examId;

  @override
  Widget build(BuildContext context) {
    final total = totalQuestions > 0 ? totalQuestions : results.length;
    final emptyCount = results.where((result) => result.empty).length;
    final errorCount = results.where((result) => result.error != null).length;
    final correctCount =
        results.where((result) => result.isCorrect == true).length;
    final incorrectCount =
        results.where((result) => result.isCorrect == false).length;
    final gradedCount = results
        .where((result) => !result.empty && result.error == null)
        .length;
    final ungraded = math.max(0, total - results.length);
    final processed = results.length;
    final progress = total > 0 ? processed / total : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('채점 결과'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1B402B),
        elevation: 1,
      ),
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _buildSummaryCard(
                total: total,
                graded: gradedCount,
                empty: emptyCount,
                errors: errorCount,
                correct: correctCount,
                incorrect: incorrectCount,
                ungraded: ungraded,
                processed: processed,
                progress: progress,
                examId: examId,
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                itemCount: results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _buildResultTile(context, results[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required int total,
    required int graded,
    required int empty,
    required int errors,
    required int correct,
    required int incorrect,
    required int ungraded,
    required int processed,
    required double progress,
    String? examId,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            color: Color(0x14000000),
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_turned_in_outlined,
                  color: Color(0xFF1B402B)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '채점 요약',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (examId != null && examId.isNotEmpty)
                Text(
                  'ID ${examId.substring(0, math.min(6, examId.length))}',
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0xFFE0E0E0),
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF1B402B)),
          ),
          const SizedBox(height: 10),
          Text(
            '총 $total문제 중 $processed문제 처리 완료',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatChip('채점 완료', graded, const Color(0xFF1B402B)),
              _buildStatChip('미응답', empty, Colors.orange),
              _buildStatChip('오류', errors, Colors.redAccent),
              if (correct > 0)
                _buildStatChip('정답', correct, const Color(0xFF2E7D32)),
              if (incorrect > 0)
                _buildStatChip('오답', incorrect, const Color(0xFFD32F2F)),
              if (ungraded > 0)
                _buildStatChip('미채점', ungraded, Colors.blueGrey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

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
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            color: Color(0x14000000),
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Icon(Icons.check_circle, color: statusColor),
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
              _buildStatusChip('정오', correctnessLabel, correctnessColor),
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


