import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/content_block.dart';
import 'package:s11/shared/ui/components/content_blocks_view.dart';
import 'package:s11/sessions/tryout_solve/ui/pages/flow_view_page.dart';
import 'solve_debug_page.dart';

enum SolveAnalysisAction { retry, next, exit }

const _ink = Color(0xFF111113),
    _paper = Color(0xFFFDFDFE),
    _muted = Color(0xFF71717A),
    _line = Color(0xFFDEDEE2),
    _success = Color(0xFF2E7D57),
    _wrong = Color(0xFFA33434);

/// 채점된 실제 문제/단계를 표시한다. 이 화면은 채점·진도 API를 다시 호출하지 않는다.
class SolveAnalysisPage extends StatelessWidget {
  const SolveAnalysisPage({
    super.key,
    required this.userAnswer,
    required this.quest,
    required this.stepCorrectness,
    required this.isCorrect,
    required this.hasNextProblem,
    this.flowEvaluated = true,
    this.allowRetry = true,
    this.debugSnapshot,
    this.problemIndex,
    this.problemCount,
  });
  final String userAnswer;
  final Map<String, dynamic>? quest;
  final List<Map<String, dynamic>> stepCorrectness;
  final bool isCorrect, hasNextProblem;
  final bool flowEvaluated, allowRetry;
  final SolveDebugSnapshot? debugSnapshot;

  /// 호출자의 실제 1-based 번호/전체 개수. 미전달 값은 샘플 번호로 대체하지 않는다.
  final int? problemIndex, problemCount;

  List<List<ContentBlock>> _extractFlowSteps() {
    final result = <List<ContentBlock>>[];
    final solves = quest?['solves'];
    if (solves is! List) return result;
    void visit(Map<String, dynamic> step) {
      result.add(
        normalizeFlowBlocks(parseContentBlocks(step['answer_riddle'])),
      );
      final branches = step['branches'];
      if (branches is List) {
        for (final branch in branches) {
          if (branch is Map<String, dynamic>) visit(branch);
        }
      }
    }

    for (final step in solves) {
      if (step is Map<String, dynamic>) visit(step);
    }
    return result;
  }

  /// 기존 단계 대응 정책을 유지한다. 누락→false 보정은 별도 정책 검수 항목이다.
  List<bool?> _correctness(int count) {
    if (!flowEvaluated) return List<bool?>.filled(count, null);
    final values = stepCorrectness
        .map((entry) => entry['correct'] == true)
        .cast<bool?>()
        .toList();
    if (values.length < count) {
      values.addAll(List<bool?>.filled(count - values.length, false));
    }
    return values.take(count).toList();
  }

  void _openFlow(BuildContext context) {
    final actual = quest;
    if (actual == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FlowViewPage(
          quest: actual,
          title: '풀이 흐름',
          stepCorrectness: stepCorrectness,
          problemIndex: problemIndex,
          problemCount: problemCount,
        ),
      ),
    );
  }

  Widget _button(
    BuildContext context, {
    required String label,
    required VoidCallback? onPressed,
    bool primary = false,
  }) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      visualDensity: VisualDensity.standard,
      minimumSize: const Size(0, 48),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: primary ? Colors.white : _ink,
      backgroundColor: primary ? _ink : _paper,
      shape: const RoundedRectangleBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      side: const BorderSide(color: _ink),
      textStyle: Theme.of(context).textTheme.labelLarge!.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    ),
    child: Text(label),
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context), compact = media.size.height <= 680;
    final steps = _extractFlowSteps(), correctness = _correctness(steps.length);
    final data = quest?['data'];
    final answers = data is Map
        ? parseContentBlocks(data['quest_answer'])
        : <ContentBlock>[];
    final numbered =
        problemIndex != null &&
        problemCount != null &&
        problemIndex! > 0 &&
        problemCount! >= problemIndex!;
    return Scaffold(
      backgroundColor: const Color(0xFFE7E7E9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ColoredBox(
              color: _paper,
              child: Column(
                key: const ValueKey('solve-analysis-root'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    key: const ValueKey('solve-analysis-header'),
                    height: 64,
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: _line)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 58,
                          child: IconButton(
                            tooltip: '문제 풀이로',
                            onPressed: () => Navigator.of(
                              context,
                            ).pop(SolveAnalysisAction.retry),
                            icon: const Icon(Icons.chevron_left, size: 20),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            '풀이 분석',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 58,
                          child: TextButton(
                            onPressed: () => Navigator.of(
                              context,
                            ).pop(SolveAnalysisAction.exit),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.standard,
                              foregroundColor: _ink,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(48, 48),
                              textStyle: Theme.of(context).textTheme.labelLarge!
                                  .copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0,
                                  ),
                            ),
                            child: const Text('끝내기'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _AnalysisHero(
                                correct: isCorrect,
                                flowEvaluated: flowEvaluated,
                                number: numbered
                                    ? '문제 $problemIndex / $problemCount'
                                    : '문제',
                                compact: compact,
                              ),
                              _AnalysisAnswers(
                                userAnswer: userAnswer,
                                answers: answers,
                              ),
                              const SizedBox(height: 12),
                              _AnalysisSteps(
                                steps: steps,
                                correctness: correctness,
                                flowEvaluated: flowEvaluated,
                                compact: compact,
                                onFlow: quest == null
                                    ? null
                                    : () => _openFlow(context),
                              ),
                              if (debugSnapshot != null)
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: _button(
                                    context,
                                    label: '디버그 정보',
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => SolveDebugPage(
                                          snapshot: debugSnapshot!,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    key: const ValueKey('solve-analysis-actions'),
                    height: 78,
                    decoration: const BoxDecoration(
                      color: _paper,
                      border: Border(top: BorderSide(color: _line)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x0D111113),
                          blurRadius: 24,
                          offset: Offset(0, -8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 100,
                          child: _button(
                            context,
                            label: '해설 보기',
                            onPressed: quest == null
                                ? null
                                : () => _openFlow(context),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          flex: 135,
                          child: _button(
                            context,
                            label: hasNextProblem
                                ? (isCorrect || !allowRetry
                                      ? '다음 문제 풀기  →'
                                      : '다시 풀기  →')
                                : (allowRetry ? '다시 풀기  →' : '끝내기'),
                            primary: true,
                            onPressed: () => Navigator.of(context).pop(
                              hasNextProblem && (isCorrect || !allowRetry)
                                  ? SolveAnalysisAction.next
                                  : allowRetry
                                  ? SolveAnalysisAction.retry
                                  : SolveAnalysisAction.exit,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalysisHero extends StatelessWidget {
  const _AnalysisHero({
    required this.correct,
    required this.flowEvaluated,
    required this.number,
    required this.compact,
  });
  final bool correct, flowEvaluated, compact;
  final String number;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Container(
      key: const ValueKey('solve-analysis-hero'),
      padding: EdgeInsets.fromLTRB(
        constraints.maxWidth <= 420 ? 17 : 20,
        compact ? 18 : 28,
        constraints.maxWidth <= 420 ? 17 : 20,
        compact ? 18 : 24,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                key: const ValueKey('solve-analysis-status'),
                width: 58,
                height: 58,
                color: correct ? _success : _ink,
                alignment: Alignment.center,
                child: Text(
                  correct ? '✓' : '!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  correct ? '정답' : '다시 확인',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    letterSpacing: -2.16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  correct
                      ? flowEvaluated
                            ? '풀이 순서와 최종 답이 모두 맞았어요.'
                            : '정답이 맞았어요. 아래 풀이 흐름을 확인해 보세요.'
                      : flowEvaluated
                      ? '정답과 풀이 흐름을 다시 확인해 보세요.'
                      : '선택한 답이 정답과 다릅니다. 풀이를 확인해 보세요.',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _AnalysisAnswers extends StatelessWidget {
  const _AnalysisAnswers({required this.userAnswer, required this.answers});
  final String userAnswer;
  final List<ContentBlock> answers;
  Widget _value(
    BuildContext context,
    String title,
    List<ContentBlock> blocks,
  ) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        blocks.isEmpty
            ? const Text('미제공', style: TextStyle(fontSize: 12, color: _muted))
            : ContentBlocksView(
                blocks: blocks,
                textStyle: TextStyle(
                  fontFamily: 'Georgia',
                  fontFamilyFallback: [
                    Theme.of(context).textTheme.bodyMedium?.fontFamily ??
                        'Noto Sans KR',
                  ],
                  fontSize: 24,
                  fontStyle: FontStyle.italic,
                ),
                latexStyle: const TextStyle(fontSize: 24),
                inline: true,
              ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('solve-analysis-answers'),
    constraints: const BoxConstraints(minHeight: 82),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: _line)),
    ),
    child: Row(
      children: [
        _value(
          context,
          '내 답',
          userAnswer.trim().isEmpty
              ? const []
              : [ContentBlock(type: 'text', content: userAnswer)],
        ),
        const SizedBox(width: 14),
        _value(context, '정답', answers),
        const SizedBox(width: 14),
        const Tooltip(
          message: '서버가 답만 따로 판정한 값을 제공하지 않습니다.',
          child: Text(
            '확인 불가',
            style: TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AnalysisSteps extends StatelessWidget {
  const _AnalysisSteps({
    required this.steps,
    required this.correctness,
    required this.flowEvaluated,
    required this.compact,
    required this.onFlow,
  });
  final List<List<ContentBlock>> steps;
  final List<bool?> correctness;
  final bool flowEvaluated;
  final bool compact;
  final VoidCallback? onFlow;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontal = constraints.maxWidth <= 420 ? 15.0 : 18.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: const ValueKey('solve-analysis-step-header'),
            constraints: BoxConstraints(minHeight: compact ? 70 : 84),
            padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '풀이 흐름',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        flowEvaluated
                            ? '${correctness.where((v) => v == true).length} / ${steps.length}단계 정확'
                            : '풀이 단계는 참고 해설입니다.',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: onFlow,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.standard,
                    foregroundColor: _ink,
                    minimumSize: const Size(0, 48),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: Theme.of(context).textTheme.labelLarge!.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  child: const Text('해설 Flow 보기  →'),
                ),
              ],
            ),
          ),
          if (steps.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '풀이 단계 정보가 없습니다.',
                style: TextStyle(fontSize: 13, color: _muted),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 7, horizontal, 12),
              child: Column(
                children: List.generate(
                  steps.length,
                  (index) => _AnalysisStep(
                    blocks: steps[index],
                    correct: correctness[index],
                    index: index,
                    first: index == 0,
                    last: index == steps.length - 1,
                    compact: compact,
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _AnalysisStep extends StatelessWidget {
  const _AnalysisStep({
    required this.blocks,
    required this.correct,
    required this.index,
    required this.first,
    required this.last,
    required this.compact,
  });
  final List<ContentBlock> blocks;
  final bool? correct;
  final bool first, last, compact;
  final int index;
  @override
  Widget build(BuildContext context) {
    final color = correct == null
        ? const Color(0xFF71717A)
        : correct!
        ? _success
        : _wrong;
    return Container(
      key: ValueKey('solve-analysis-step-$index'),
      constraints: BoxConstraints(minHeight: compact ? 66 : 78),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: _line)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 18,
            top: first ? (compact ? 33 : 39) : 0,
            bottom: last ? (compact ? 33 : 39) : 0,
            child: Container(width: 1, color: const Color(0xFFCFCFD4)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ConstrainedBox(
              // CSS grid centers inside the content box, excluding bottom border.
              constraints: BoxConstraints(
                minHeight: (compact ? 66.0 : 78.0) - 24 - (last ? 0 : 1),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 38,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 36,
                        height: 36,
                        color: color,
                        alignment: Alignment.center,
                        child: Text(
                          correct == null
                              ? '${index + 1}'
                              : correct!
                              ? '✓'
                              : '×',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STEP ${(index + 1).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        ContentBlocksView(
                          blocks: blocks,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                          latexStyle: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                          ),
                          inline: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 11),
                  Text(
                    correct == null
                        ? '해설'
                        : correct!
                        ? '정확'
                        : '다시 확인',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
