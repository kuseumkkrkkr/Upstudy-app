import 'package:flutter/material.dart';
import '../models/content_block.dart';
import '../widgets/content_blocks_view.dart';
import '../widgets/solve_header.dart';
import 'flow_view_page.dart';

enum SolveAnalysisAction { retry, next, exit }

class SolveAnalysisPage extends StatelessWidget {
  const SolveAnalysisPage({
    super.key,
    required this.analysisText,
    required this.quest,
    required this.stepCorrectness,
    required this.isCorrect,
    required this.hasNextProblem,
  });

  final String analysisText;
  final Map<String, dynamic>? quest;
  final List<Map<String, dynamic>> stepCorrectness;
  final bool isCorrect;
  final bool hasNextProblem;

  List<List<ContentBlock>> _extractFlowSteps(Map<String, dynamic> quest) {
    final steps = <List<ContentBlock>>[];
    final solves = quest['solves'];
    if (solves is! List) return steps;

    void visit(Map<String, dynamic> step) {
      steps.add(parseContentBlocks(step['flow']));
      final branches = step['branches'];
      if (branches is List) {
        for (final branch in branches) {
          if (branch is Map<String, dynamic>) {
            visit(branch);
          }
        }
      }
    }

    for (final entry in solves) {
      if (entry is Map<String, dynamic>) {
        visit(entry);
      }
    }
    return steps;
  }

  List<bool> _buildCorrectnessList(
    List<Map<String, dynamic>> stepCorrectness,
    int count,
  ) {
    final results = <bool>[];
    for (final entry in stepCorrectness) {
      results.add(entry['correct'] == true);
    }
    if (results.length < count) {
      results.addAll(List<bool>.filled(count - results.length, false));
    }
    if (results.length > count) {
      return results.take(count).toList();
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = analysisText.trim();
    final blocks = parseTextWithLatex(trimmed);
    final displayBlocks = blocks.isEmpty
        ? [const ContentBlock(type: 'text', content: '분석 결과가 없습니다.')]
        : blocks;
    final statusColor =
        isCorrect ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C);
    final statusText = isCorrect ? '정답' : '오답';
    final flowSteps = quest == null ? <List<ContentBlock>>[] : _extractFlowSteps(quest!);
    final correctness = _buildCorrectnessList(stepCorrectness, flowSteps.length);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SolveHeader(title: 'AIFlow'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.6)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCorrect ? Icons.check_circle : Icons.cancel,
                            color: statusColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '분석',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFB7D7C0)),
                      ),
                      child: ContentBlocksView(
                        blocks: displayBlocks,
                        textStyle: const TextStyle(fontSize: 14, height: 1.5),
                        latexStyle: const TextStyle(fontSize: 14, height: 1.5),
                        inline: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '풀이 단계',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (flowSteps.isEmpty)
                      const Text('표시할 풀이 단계가 없습니다.')
                    else
                      ...List.generate(flowSteps.length, (index) {
                        final blocks = flowSteps[index];
                        final display = blocks.isEmpty
                            ? [const ContentBlock(type: 'text', content: '-')]
                            : blocks;
                        final isOk = correctness[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isOk
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFD32F2F),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                alignment: Alignment.center,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: isOk
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFD32F2F),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  isOk ? 'O' : 'X',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ContentBlocksView(
                                  blocks: display,
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                  latexStyle: const TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                  inline: true,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 12),
                    const SizedBox(height: 12),
                    if (isCorrect && hasNextProblem)
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.of(context).pop(SolveAnalysisAction.next),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B402B),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('다음 문제 풀기'),
                      )
                    else
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.of(context).pop(SolveAnalysisAction.retry),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B402B),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('문제로 돌아가기'),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(SolveAnalysisAction.exit),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1B402B),
                        side: const BorderSide(color: Color(0xFF1B402B)),
                      ),
                      child: const Text('풀이 종료'),
                    ),
                    if (quest != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FlowViewPage(
                                quest: quest!,
                                title: '풀이 흐름',
                                analysisText: analysisText,
                                stepCorrectness: stepCorrectness,
                              ),
                            ),
                          );
                        },
                        child: const Text('풀이 흐름 보기'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
