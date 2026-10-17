import 'package:flutter/material.dart';
import 'solve_analysis_page.dart';

/// A completed multi-question practice grading result, including its Flow review data.
class BatchSolveGradeItem {
  const BatchSolveGradeItem({
    required this.problemIndex,
    required this.quest,
    required this.stepCorrectness,
    required this.empty,
    required this.isCorrect,
    required this.userAnswer,
    this.flowEvaluated = false,
    this.error,
  });

  final int problemIndex;
  final Map<String, dynamic>? quest;
  final List<Map<String, dynamic>> stepCorrectness;
  final bool empty;
  final bool? isCorrect;
  final String userAnswer;
  final bool flowEvaluated;
  final String? error;
}

/// Shows the aggregate result after batch grading and links each graded item to Flow analysis.
class BatchGradingReportPage extends StatelessWidget {
  const BatchGradingReportPage({
    super.key,
    required this.results,
    required this.totalCount,
  });

  final List<BatchSolveGradeItem> results;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final correct = results.where((item) => item.isCorrect == true).length;
    final empty = results.where((item) => item.empty).length;
    final errors = results.where((item) => item.error != null).length;
    final incorrect = results.where((item) => item.isCorrect == false).length;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F2),
      appBar: AppBar(
        title: const Text('일괄 채점 결과'),
        backgroundColor: const Color(0xFFFDFDFE),
        foregroundColor: const Color(0xFF09090B),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _SummaryCard(
              correct: correct,
              incorrect: incorrect,
              empty: empty,
              errors: errors,
              total: totalCount,
            ),
            const SizedBox(height: 16),
            const Text(
              '문항별 결과와 풀이 흐름',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...results.map(
              (item) => _ResultTile(item: item, total: totalCount),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.correct,
    required this.incorrect,
    required this.empty,
    required this.errors,
    required this.total,
  });

  final int correct;
  final int incorrect;
  final int empty;
  final int errors;
  final int total;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(color: Color(0xFFFDFDFE)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('채점 요약', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          '$correct / $total 정답',
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: total == 0 ? 0 : (correct / total).clamp(0.0, 1.0),
          color: const Color(0xFF09090B),
          backgroundColor: const Color(0xFFE5E5E7),
        ),
        const SizedBox(height: 12),
        Text('오답 $incorrect · 미응답 $empty · 채점 오류 $errors'),
      ],
    ),
  );
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.item, required this.total});

  final BatchSolveGradeItem item;
  final int total;

  @override
  Widget build(BuildContext context) {
    final label = item.error != null
        ? '채점 오류'
        : item.empty
        ? '미응답'
        : item.isCorrect == true
        ? '정답'
        : '오답';
    final enabled = item.quest != null && !item.empty && item.error == null;
    return Card(
      color: const Color(0xFFFDFDFE),
      elevation: 0,
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        minVerticalPadding: 12,
        title: Text('문제 ${item.problemIndex} · $label'),
        subtitle: Text(item.error ?? item.userAnswer),
        trailing: enabled ? const Icon(Icons.chevron_right) : null,
        onTap: enabled
            ? () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SolveAnalysisPage(
                    problemIndex: item.problemIndex,
                    problemCount: total,
                    userAnswer: item.userAnswer,
                    quest: item.quest,
                    stepCorrectness: item.stepCorrectness,
                    flowEvaluated: item.flowEvaluated,
                    isCorrect: item.isCorrect == true,
                    hasNextProblem: item.problemIndex < total,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
