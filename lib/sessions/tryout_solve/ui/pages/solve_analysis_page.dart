import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/content_block.dart';
import 'package:s11/shared/ui/components/content_blocks_view.dart';
import 'package:s11/shared/ui/app_bar/solve_header.dart';
import 'package:s11/sessions/tryout_solve/ui/pages/flow_view_page.dart';
import 'solve_debug_page.dart';

enum SolveAnalysisAction { retry, next, exit }

class SolveAnalysisPage extends StatelessWidget {
  const SolveAnalysisPage({
    super.key,
    required this.userAnswer,
    required this.quest,
    required this.stepCorrectness,
    required this.isCorrect,
    required this.hasNextProblem,
    this.debugSnapshot,
  });

  final String userAnswer;
  final Map<String, dynamic>? quest;
  final List<Map<String, dynamic>> stepCorrectness;
  final bool isCorrect;
  final bool hasNextProblem;
  final SolveDebugSnapshot? debugSnapshot;

  List<List<ContentBlock>> _extractFlowSteps(Map<String, dynamic> quest) {
    final steps = <List<ContentBlock>>[];
    final solves = quest['solves'];
    if (solves is! List) return steps;

    void visit(Map<String, dynamic> step) {
      steps.add(
        normalizeFlowBlocks(parseContentBlocks(step['answer_riddle'])),
      );
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
    final questData = quest == null
        ? null
        : quest!['data'] as Map<String, dynamic>?;
    final questAnswerBlocks = questData == null
        ? <ContentBlock>[]
        : parseContentBlocks(questData['quest_answer']);
    final displayAnswer = questAnswerBlocks.isEmpty
        ? [const ContentBlock(type: 'text', content: '-')]
        : questAnswerBlocks;
    final statusColor = isCorrect
        ? const Color(0xFF1B5E20)
        : const Color(0xFFB71C1C);
    final statusText = isCorrect ? '정답' : '오답'; // '??' → 정답 / 오답
    final flowSteps = quest == null
        ? <List<ContentBlock>>[]
        : _extractFlowSteps(quest!);
    final correctness = _buildCorrectnessList(
      stepCorrectness,
      flowSteps.length,
    );
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
                      '정답 확인', // '??? ?' → 정답 확인
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD5DDE7)),
                      ),
                      child: ContentBlocksView(
                        blocks: displayAnswer,
                        textStyle: const TextStyle(fontSize: 14, height: 1.5),
                        latexStyle: const TextStyle(fontSize: 14, height: 1.5),
                        inline: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '풀이 흐름', // '?? ??' → 풀이 흐름
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (flowSteps.isEmpty)
                      const Text('풀이 단계가 없습니다.') // '?? ??? ????' → 풀이 단계가 없습니다.
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
                    if (isCorrect && hasNextProblem)
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.of(context).pop(SolveAnalysisAction.next),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B402B),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('다음 문제 풀기'), // '?? ?? ??' → 다음 문제 풀기
                      )
                    else
                      ElevatedButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(SolveAnalysisAction.retry),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B402B),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('다시 풀기'), // '?? ?? ??' → 다시 풀기
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(SolveAnalysisAction.exit),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1B402B),
                        side: const BorderSide(color: Color(0xFF1B402B)),
                      ),
                      child: const Text('종료'), // '?? ??' → 종료
                    ),
                    if (quest != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FlowViewPage(
                                quest: quest!,
                                title: '풀이 흐름', // '?? ??' → 풀이 흐름
                                stepCorrectness: stepCorrectness,
                              ),
                            ),
                          );
                        },
                        child: const Text('풀이 흐름 보기'), // '?? ?? ??' → 풀이 흐름 보기
                      ),
                    ],
                    if (debugSnapshot != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  SolveDebugPage(snapshot: debugSnapshot!),
                            ),
                          );
                        },
                        child: const Text(
                          '디버그 정보 보기',
                        ), // '?? ??? ??' → 디버그 정보 보기
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
