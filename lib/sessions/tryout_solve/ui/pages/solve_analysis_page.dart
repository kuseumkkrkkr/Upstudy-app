import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/content_block.dart';
import 'package:s11/shared/ui/app_bar/solve_header.dart';
import 'package:s11/shared/ui/components/content_blocks_view.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
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

  /// 필요 변수: 문제 원본의 풀이 단계 목록.
  /// 작동 원리: 재귀적으로 분기 단계를 펼쳐 결과 화면의 단계별 채점 순서와 맞는 블록 목록을 만든다.
  List<List<ContentBlock>> _extractFlowSteps(Map<String, dynamic> quest) {
    final steps = <List<ContentBlock>>[];
    final solves = quest['solves'];
    if (solves is! List) return steps;

    void visit(Map<String, dynamic> step) {
      steps.add(normalizeFlowBlocks(parseContentBlocks(step['answer_riddle'])));
      final branches = step['branches'];
      if (branches is List) {
        for (final branch in branches) {
          if (branch is Map<String, dynamic>) visit(branch);
        }
      }
    }

    for (final entry in solves) {
      if (entry is Map<String, dynamic>) visit(entry);
    }
    return steps;
  }

  /// 필요 변수: 서버가 전달한 단계별 정오답과 실제 풀이 단계 수.
  /// 작동 원리: 누락된 결과는 오답으로 채우고 초과한 결과는 잘라 안전하게 화면 단계 수와 맞춘다.
  List<bool> _buildCorrectnessList(
    List<Map<String, dynamic>> stepCorrectness,
    int count,
  ) {
    final results = stepCorrectness
        .map((entry) => entry['correct'] == true)
        .toList();
    if (results.length < count) {
      results.addAll(List<bool>.filled(count - results.length, false));
    }
    return results.take(count).toList();
  }

  /// 필요 변수: 현재 정답 여부와 다음 문제 존재 여부.
  /// 작동 원리: 학습을 계속하는 가장 중요한 행동 하나만 채운 버튼으로 강조한다.
  Widget _buildPrimaryAction(BuildContext context) {
    final continuesToNext = isCorrect && hasNextProblem;
    return FilledButton.icon(
      onPressed: () => Navigator.of(context).pop(
        continuesToNext ? SolveAnalysisAction.next : SolveAnalysisAction.retry,
      ),
      icon: Icon(
        continuesToNext ? Icons.arrow_forward_rounded : Icons.refresh_rounded,
        size: 18,
      ),
      label: Text(continuesToNext ? '다음 문제 풀기' : '다시 풀기'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        backgroundColor: StudentDensityTokens.dark,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );
  }

  /// 필요 변수: 아이콘·문구·탭 동작으로 구성된 보조 행동 정보.
  /// 작동 원리: 넓은 전체 폭 버튼 대신 작은 외곽선 버튼을 사용해 핵심 학습 행동의 가독성을 보존한다.
  Widget _buildSecondaryAction({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        foregroundColor: StudentDensityTokens.ink,
        side: const BorderSide(color: StudentDensityTokens.lineStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  /// 필요 변수: 풀이 블록·단계별 정오답·결과 행동 콜백.
  /// 작동 원리: 결과는 카드로 그룹화하고, 재시도만 강한 행동으로 보여 학습 흐름을 우선한다.
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
        ? const Color(0xFF277A3A)
        : const Color(0xFFC62828);
    final statusText = isCorrect ? '정답' : '오답';
    final flowSteps = quest == null
        ? <List<ContentBlock>>[]
        : _extractFlowSteps(quest!);
    final correctness = _buildCorrectnessList(
      stepCorrectness,
      flowSteps.length,
    );

    return Scaffold(
      backgroundColor: StudentDensityTokens.background,
      body: SafeArea(
        child: Column(
          children: [
            const SolveHeader(title: 'AIFlow'),
            Expanded(
              child: SingleChildScrollView(
                child: StudentDensityPage(
                  padding: EdgeInsets.symmetric(
                    horizontal: studentDensityHorizontalPadding(context),
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildResultSummary(context, statusColor, statusText),
                      const SizedBox(height: 16),
                      _buildAnswerCard(displayAnswer),
                      const SizedBox(height: 16),
                      _buildFlowCard(flowSteps, correctness),
                      const SizedBox(height: 16),
                      _buildSecondaryActions(context),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 필요 변수: 정오답 색상·문구와 핵심 행동.
  /// 작동 원리: 상태와 다음 학습 행동을 같은 요약 카드에 배치해 시선이 분산되지 않게 한다.
  Widget _buildResultSummary(
    BuildContext context,
    Color statusColor,
    String statusText,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: StudentDensityTokens.surface,
        borderRadius: BorderRadius.circular(StudentDensityTokens.radiusMedium),
        border: Border.all(color: StudentDensityTokens.line),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 16,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCorrect ? Icons.check_rounded : Icons.close_rounded,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StudentDensityEyebrow(
                    isCorrect ? 'RESULT' : 'REVIEW',
                    color: statusColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    style: const TextStyle(
                      color: StudentDensityTokens.ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          _buildPrimaryAction(context),
        ],
      ),
    );
  }

  /// 필요 변수: 표시할 정답 콘텐츠 블록.
  /// 작동 원리: 답안을 독립 표면에 담아 풀이 단계와 시각적으로 구분한다.
  Widget _buildAnswerCard(List<ContentBlock> displayAnswer) {
    return StudentDensitySurface(
      padding: const EdgeInsets.all(20),
      radius: StudentDensityTokens.radiusMedium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StudentDensityEyebrow('ANSWER'),
          const SizedBox(height: 8),
          const Text(
            '정답 확인',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: StudentDensityTokens.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: ContentBlocksView(
              blocks: displayAnswer,
              textStyle: const TextStyle(fontSize: 15, height: 1.5),
              latexStyle: const TextStyle(fontSize: 15, height: 1.5),
              inline: true,
            ),
          ),
        ],
      ),
    );
  }

  /// 필요 변수: 풀이 블록과 단계별 정오답 목록.
  /// 작동 원리: 단계는 옅은 성공·실패 배경으로 구분하되, 테두리와 색 대비를 낮춰 내용 읽기를 우선한다.
  Widget _buildFlowCard(
    List<List<ContentBlock>> flowSteps,
    List<bool> correctness,
  ) {
    return StudentDensitySurface(
      padding: const EdgeInsets.all(20),
      radius: StudentDensityTokens.radiusMedium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StudentDensityEyebrow('SOLUTION FLOW'),
          const SizedBox(height: 8),
          const Text(
            '풀이 흐름',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 14),
          if (flowSteps.isEmpty)
            const Text('풀이 단계가 없습니다.')
          else
            ...List.generate(flowSteps.length, (index) {
              final blocks = flowSteps[index];
              final display = blocks.isEmpty
                  ? [const ContentBlock(type: 'text', content: '-')]
                  : blocks;
              final isOk = correctness[index];
              final stateColor = isOk
                  ? const Color(0xFF277A3A)
                  : const Color(0xFFC62828);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: isOk
                      ? const Color(0xFFF4FAF5)
                      : const Color(0xFFFFF7F7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isOk
                        ? const Color(0xFFB9D9BF)
                        : const Color(0xFFFFC5C5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: stateColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isOk ? Icons.check_rounded : Icons.close_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    Expanded(
                      child: ContentBlocksView(
                        blocks: display,
                        textStyle: const TextStyle(fontSize: 14, height: 1.45),
                        latexStyle: const TextStyle(fontSize: 14, height: 1.45),
                        inline: true,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  /// 필요 변수: 페이지 이동에 필요한 문제·디버그 스냅샷.
  /// 작동 원리: 종료·상세보기는 한 줄에서 자동 줄바꿈되는 보조 행동으로 묶어 과도한 전체 폭 버튼을 제거한다.
  Widget _buildSecondaryActions(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        _buildSecondaryAction(
          icon: Icons.close_rounded,
          label: '종료',
          onPressed: () => Navigator.of(context).pop(SolveAnalysisAction.exit),
        ),
        if (quest != null)
          _buildSecondaryAction(
            icon: Icons.account_tree_outlined,
            label: '풀이 흐름 보기',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FlowViewPage(
                  quest: quest!,
                  title: '풀이 흐름',
                  stepCorrectness: stepCorrectness,
                ),
              ),
            ),
          ),
        if (debugSnapshot != null)
          _buildSecondaryAction(
            icon: Icons.bug_report_outlined,
            label: '디버그 정보',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SolveDebugPage(snapshot: debugSnapshot!),
              ),
            ),
          ),
      ],
    );
  }
}
