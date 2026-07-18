part of 'package:s11/sessions/exam_paper/session/exam_paper_page.dart';

class _ExamGradingReportPage extends StatelessWidget {
  const _ExamGradingReportPage({
    required this.results,
    required this.totalQuestions,
    required this.passRate,
    required this.passed,
    required this.moduleSubmissionRequired,
    required this.moduleSubmissionSucceeded,
    this.onRetryModuleSubmission,
    this.examId,
  });

  final List<_GradeResult> results;
  final int totalQuestions;
  final int passRate;
  final bool passed;
  final bool moduleSubmissionRequired;
  final bool moduleSubmissionSucceeded;
  final Future<bool> Function()? onRetryModuleSubmission;
  final String? examId;

  /// 필요한 변수는 채점 결과, 합격 기준과 화면 너비다.
  /// 작동 원리: 학생 시안의 종이형 표면과 흑백 상태 체계를 사용하되, 결과 집계와
  /// 문항별 Flow 이동은 기존 시험 채점 흐름의 데이터를 그대로 연결한다.
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

    final mobile = isStudentDensityMobile(context);
    final summary = _buildSummary(
      total: total,
      processed: processed,
      progress: progress,
      graded: gradedCount,
      empty: emptyCount,
      errors: errorCount,
      ungraded: ungraded,
    );
    final questions = _buildQuestionSection(context);

    return Scaffold(
      backgroundColor: StudentDensityTokens.background,
      appBar: AppBar(
        title: const Text('시험 결과'),
        centerTitle: false,
        backgroundColor: StudentDensityTokens.surface,
        foregroundColor: StudentDensityTokens.ink,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: StudentDensityTokens.lineStrong),
        ),
      ),
      body: ListView(
        children: [
          StudentDensityPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StudentDensityPageHeader(
                  eyebrow: 'EXAM REVIEW',
                  title: passed ? '시험을 통과했어요.' : '시험 결과를 확인하세요.',
                  description: '문항별 채점 결과와 풀이 흐름을 한 번에 검토할 수 있어요.',
                  action: examId == null || examId!.isEmpty
                      ? null
                      : _ExamIdLabel(examId: examId!),
                ),
                SizedBox(height: mobile ? 22 : 30),
                _buildScorePaper(
                  total: total,
                  correct: correctCount,
                  incorrect: incorrectCount,
                  score: score,
                ),
                SizedBox(height: mobile ? 14 : 20),
                if (mobile) ...[
                  summary,
                  const SizedBox(height: 14),
                  questions,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 340, child: summary),
                      const SizedBox(width: 20),
                      Expanded(child: questions),
                    ],
                  ),
                SizedBox(height: mobile ? 14 : 20),
                StudentDensitySurface(
                  padding: const EdgeInsets.all(18),
                  radius: StudentDensityTokens.radiusMedium,
                  child: ModuleSubmissionFooter(
                    passed: passed,
                    submissionRequired: moduleSubmissionRequired,
                    initialSubmissionSucceeded: moduleSubmissionSucceeded,
                    onRetry: onRetryModuleSubmission,
                    onComplete: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 필요한 변수는 총 문항, 정오답 수, 정답률과 통과 기준이다.
  /// 작동 원리: 시험지 제목 영역처럼 넓은 단색 종이 표면에 점수와 최소 상태만 배치한다.
  Widget _buildScorePaper({
    required int total,
    required int correct,
    required int incorrect,
    required double score,
  }) {
    return StudentDensitySurface(
      color: StudentDensityTokens.dark,
      radius: StudentDensityTokens.radiusExtraLarge,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StudentDensityEyebrow('FINAL SCORE', color: Color(0xFFA1A1AA)),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final scoreBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${(score * 100).round()}점',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 64,
                      height: .95,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('$total문제 중 $correct문제 정답', style: _paperMetaStyle),
                ],
              );
              final statBlock = Wrap(
                spacing: 26,
                runSpacing: 14,
                children: [
                  _buildPaperStat('정답', correct),
                  _buildPaperStat('오답', incorrect),
                  _buildPaperStat(
                    '미응답',
                    math.max(0, total - correct - incorrect),
                  ),
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [scoreBlock, const SizedBox(height: 24), statBlock],
                );
              }
              return Row(
                children: [
                  Expanded(child: scoreBlock),
                  statBlock,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static const TextStyle _paperMetaStyle = TextStyle(
    color: Color(0xFFD4D4D8),
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  /// 필요한 변수는 상태명과 집계 수다.
  /// 작동 원리: 점수 영역의 보조 지표를 동일한 작은 숫자·라벨 조합으로 맞춘다.
  Widget _buildPaperStat(String label, int count) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFFA1A1AA),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  /// 필요한 변수는 채점 처리 상태와 문항 수 집계다.
  /// 작동 원리: 종이형 요약 카드 안에 진행률과 예외 상태만 남겨 재검토 우선순위를 빠르게 만든다.
  Widget _buildSummary({
    required int total,
    required int processed,
    required double progress,
    required int graded,
    required int empty,
    required int errors,
    required int ungraded,
  }) {
    return StudentDensitySurface(
      padding: const EdgeInsets.all(20),
      radius: StudentDensityTokens.radiusMedium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StudentDensityEyebrow('GRADING STATUS'),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '채점 현황',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ),
              Text(
                '$processed / $total',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: StudentDensityTokens.surfaceMuted,
              valueColor: const AlwaysStoppedAnimation(
                StudentDensityTokens.dark,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _buildStatusText('채점 완료', graded),
              if (empty > 0) _buildStatusText('미응답', empty),
              if (errors > 0) _buildStatusText('오류', errors),
              if (ungraded > 0) _buildStatusText('미채점', ungraded),
            ],
          ),
        ],
      ),
    );
  }

  /// 필요한 변수는 보조 상태의 라벨과 개수다.
  /// 작동 원리: 색에 의존하지 않는 테두리 배지로 상태를 전달해 종이형 시안과 접근성을 함께 유지한다.
  Widget _buildStatusText(String label, int count) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      border: Border.all(color: StudentDensityTokens.lineStrong),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      '$label $count',
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
    ),
  );

  /// 필요한 변수는 문항별 채점 결과다.
  /// 작동 원리: 문항 목록을 종이형 카드에 묶고 확장된 항목에서만 상세 상태와 Flow 이동을 노출한다.
  Widget _buildQuestionSection(BuildContext context) => StudentDensitySurface(
    padding: const EdgeInsets.all(20),
    radius: StudentDensityTokens.radiusMedium,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StudentDensityEyebrow('QUESTION REVIEW'),
        const SizedBox(height: 10),
        const Text(
          '문항별 결과',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '문항을 눌러 채점 상세와 풀이 흐름을 확인하세요.',
          style: TextStyle(
            color: StudentDensityTokens.muted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        if (results.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                '표시할 문항별 결과가 없습니다.',
                style: TextStyle(color: StudentDensityTokens.muted),
              ),
            ),
          )
        else
          ...results.map(
            (result) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildResultTile(context, result),
            ),
          ),
      ],
    ),
  );

  /// 필요한 변수는 문항 채점 상태와 선택적인 풀이 데이터다.
  /// 작동 원리: 정오답을 아이콘과 텍스트로 함께 제공하고, Flow 데이터가 있을 때만 분석 화면 진입을 허용한다.
  Widget _buildResultTile(BuildContext context, _GradeResult result) {
    final statusLabel = result.empty
        ? '미응답'
        : result.error != null
        ? '오류'
        : '채점 완료';
    final gradingStatus = result.empty
        ? '미응답'
        : result.error != null
        ? '채점 실패'
        : '채점 성공';
    final correctnessLabel = result.isCorrect == true
        ? '정답'
        : result.isCorrect == false
        ? '오답'
        : '판정 불가';
    return Container(
      decoration: BoxDecoration(
        color: StudentDensityTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(StudentDensityTokens.radiusSmall),
        border: Border.all(color: StudentDensityTokens.line),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: StudentDensityTokens.ink,
        leading: CircleAvatar(
          backgroundColor: StudentDensityTokens.dark,
          child: Icon(
            result.isCorrect == true
                ? Icons.check_rounded
                : result.isCorrect == false
                ? Icons.close_rounded
                : Icons.more_horiz_rounded,
            color: Colors.white,
          ),
        ),
        title: Text(
          '문제 ${result.itemIndex}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          statusLabel,
          style: const TextStyle(
            color: StudentDensityTokens.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip('채점', gradingStatus),
              _buildStatusChip('결과', correctnessLabel),
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
                style: const TextStyle(
                  fontSize: 12,
                  color: StudentDensityTokens.muted,
                ),
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
                  foregroundColor: StudentDensityTokens.ink,
                  side: const BorderSide(
                    color: StudentDensityTokens.lineStrong,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 필요한 변수는 문항 상태 라벨과 표시값이다.
  /// 작동 원리: 색상 의미를 제거한 테두리 칩으로 상태를 읽을 수 있게 한다.
  Widget _buildStatusChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: StudentDensityTokens.lineStrong),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// 필요한 변수는 시험 식별자 문자열이다.
/// 작동 원리: 긴 식별자는 앞부분만 표시해 상단 정보 계층을 방해하지 않도록 한다.
class _ExamIdLabel extends StatelessWidget {
  const _ExamIdLabel({required this.examId});

  final String examId;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: StudentDensityTokens.surface,
      border: Border.all(color: StudentDensityTokens.lineStrong),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      'EXAM ${examId.substring(0, math.min(8, examId.length)).toUpperCase()}',
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: .5,
      ),
    ),
  );
}

class ModuleSubmissionFooter extends StatefulWidget {
  const ModuleSubmissionFooter({
    super.key,
    required this.passed,
    required this.submissionRequired,
    required this.initialSubmissionSucceeded,
    required this.onComplete,
    this.onRetry,
  });

  final bool passed;
  final bool submissionRequired;
  final bool initialSubmissionSucceeded;
  final VoidCallback onComplete;
  final Future<bool> Function()? onRetry;

  @override
  State<ModuleSubmissionFooter> createState() => _ModuleSubmissionFooterState();
}

class _ModuleSubmissionFooterState extends State<ModuleSubmissionFooter> {
  late bool _submissionSucceeded = widget.initialSubmissionSucceeded;
  bool _retrying = false;

  /// 필요한 변수는 재시도 콜백과 현재 제출 상태다.
  /// 중복 탭을 막고 서버 응답 성공 시에만 완료 버튼을 활성화한다.
  Future<void> _retrySubmission() async {
    final retry = widget.onRetry;
    if (retry == null || _retrying) return;
    setState(() => _retrying = true);
    final succeeded = await retry();
    if (!mounted) return;
    setState(() {
      _submissionSucceeded = succeeded;
      _retrying = false;
    });
  }

  /// 필요한 변수는 시험 통과 여부와 코스 제출 성공 여부다.
  /// 제출 실패 시 재시도 안내를 먼저 노출하고 성공 후에만 학습 화면 복귀를 허용한다.
  @override
  Widget build(BuildContext context) {
    final blockedBySubmission =
        widget.passed && widget.submissionRequired && !_submissionSucceeded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (blockedBySubmission) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: StudentDensityTokens.surfaceMuted,
              border: Border.all(color: StudentDensityTokens.lineStrong),
              borderRadius: BorderRadius.circular(
                StudentDensityTokens.radiusSmall,
              ),
            ),
            child: const Text(
              '시험 결과는 저장됐지만 코스 진도 제출에 실패했습니다. 다시 제출해 주세요.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _retrying ? null : _retrySubmission,
            icon: _retrying
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label: Text(_retrying ? '다시 제출 중' : '코스 진도 다시 제출'),
            style: OutlinedButton.styleFrom(
              foregroundColor: StudentDensityTokens.ink,
              side: const BorderSide(color: StudentDensityTokens.lineStrong),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        ElevatedButton(
          onPressed: widget.passed && !blockedBySubmission
              ? widget.onComplete
              : null,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: StudentDensityTokens.dark,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFE4E4E7),
            disabledForegroundColor: StudentDensityTokens.muted,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
          child: Text(
            widget.passed
                ? blockedBySubmission
                      ? '진도 제출이 필요해요'
                      : '완료'
                : '통과 후 완료할 수 있어요',
          ),
        ),
      ],
    );
  }
}
