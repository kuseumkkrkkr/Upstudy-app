part of 'package:s11/sessions/exam_paper/session/exam_paper_page.dart';

class ExamGradingReportPage extends StatelessWidget {
  const ExamGradingReportPage({
    required this.results,
    required this.totalQuestions,
    required this.passRate,
    required this.passed,
    required this.moduleSubmissionRequired,
    required this.moduleSubmissionSucceeded,
    this.onRetryModuleSubmission,
    this.examId,
  });

  final List<ExamGradeResult> results;
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

    final media = MediaQuery.of(context);
    final portraitPhone =
        media.orientation == Orientation.portrait && media.size.width <= 600;
    if (portraitPhone) {
      return _buildPortraitPhonePage(
        context,
        total: total,
        processed: processed,
        progress: progress,
        correct: correctCount,
        incorrect: incorrectCount,
        empty: math.max(0, total - correctCount - incorrectCount),
        errors: errorCount,
        score: score,
      );
    }

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

  /// 세로형 휴대전화에서만 사용하는 결과 화면이다.
  /// 점수와 정오답 분포를 첫 화면에 모으고 완료 동작은 엄지 영역에 고정한다.
  Widget _buildPortraitPhonePage(
    BuildContext context, {
    required int total,
    required int processed,
    required double progress,
    required int correct,
    required int incorrect,
    required int empty,
    required int errors,
    required double score,
  }) {
    final scoreValue = (score * 100).round();
    final statusColor = passed
        ? const Color(0xFF2E7D57)
        : const Color(0xFFB5473C);

    return Scaffold(
      key: const ValueKey('exam-result-portrait-mobile'),
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text(
          '시험 결과',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: StudentDensityTokens.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: StudentDensityTokens.line),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Row(
              children: [
                _buildMobileStatusPill(statusColor),
                const Spacer(),
                if (examId != null && examId!.isNotEmpty)
                  _ExamIdLabel(examId: examId!),
              ],
            ),
            const SizedBox(height: 12),
            _buildMobileScoreCard(
              score: scoreValue,
              total: total,
              correct: correct,
              incorrect: incorrect,
              empty: empty,
              statusColor: statusColor,
            ),
            const SizedBox(height: 12),
            _buildMobileGradingSummary(
              total: total,
              processed: processed,
              progress: progress,
              errors: errors,
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(
                  child: Text(
                    '문항별 결과',
                    style: TextStyle(
                      color: StudentDensityTokens.ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                Text(
                  '정답 $correct / $total',
                  style: const TextStyle(
                    color: StudentDensityTokens.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (results.isEmpty)
              const _MobileEmptyResult()
            else
              ...results.map(
                (result) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildMobileResultTile(context, result),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          key: const ValueKey('exam-result-mobile-footer'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: StudentDensityTokens.lineStrong),
            ),
          ),
          child: ModuleSubmissionFooter(
            passed: passed,
            submissionRequired: moduleSubmissionRequired,
            initialSubmissionSucceeded: moduleSubmissionSucceeded,
            onRetry: onRetryModuleSubmission,
            onComplete: () => Navigator.of(context).pop(true),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileStatusPill(Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          passed ? Icons.check_circle_rounded : Icons.refresh_rounded,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          passed ? '시험 통과' : '다시 도전',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  Widget _buildMobileScoreCard({
    required int score,
    required int total,
    required int correct,
    required int incorrect,
    required int empty,
    required Color statusColor,
  }) => Container(
    key: const ValueKey('exam-result-mobile-score'),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: StudentDensityTokens.dark,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          passed ? '잘했어요!' : '조금만 더 연습해요',
          style: const TextStyle(
            color: Color(0xFFD4D4D8),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$score',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 66,
                height: .9,
                fontWeight: FontWeight.w900,
                letterSpacing: -3.5,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                '점',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Spacer(),
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('$total문제 중 $correct문제를 맞혔어요', style: _paperMetaStyle),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(height: 1, color: Color(0xFF343438)),
        ),
        Row(
          children: [
            Expanded(child: _buildMobileScoreStat('정답', correct)),
            const _MobileStatDivider(),
            Expanded(child: _buildMobileScoreStat('오답', incorrect)),
            const _MobileStatDivider(),
            Expanded(child: _buildMobileScoreStat('미응답', empty)),
          ],
        ),
      ],
    ),
  );

  Widget _buildMobileScoreStat(String label, int value) => Column(
    children: [
      Text(
        '$value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 3),
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

  Widget _buildMobileGradingSummary({
    required int total,
    required int processed,
    required double progress,
    required int errors,
  }) => Container(
    key: const ValueKey('exam-result-mobile-progress'),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Icon(Icons.fact_check_outlined, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '채점 완료',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '$processed / $total',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: const Color(0xFFE8E8EC),
            valueColor: AlwaysStoppedAnimation(
              errors > 0 ? const Color(0xFFB5473C) : StudentDensityTokens.dark,
            ),
          ),
        ),
        if (errors > 0) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '채점 오류 $errors건을 확인해 주세요.',
              style: const TextStyle(
                color: Color(0xFFB5473C),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _buildMobileResultTile(BuildContext context, ExamGradeResult result) {
    final color = result.isCorrect == true
        ? const Color(0xFF2E7D57)
        : result.isCorrect == false
        ? const Color(0xFFB5473C)
        : const Color(0xFF71717A);
    final label = result.empty
        ? '미응답'
        : result.error != null
        ? '채점 오류'
        : result.isCorrect == true
        ? '정답'
        : result.isCorrect == false
        ? '오답'
        : '판정 불가';

    return Material(
      key: ValueKey('exam-result-mobile-question-${result.itemIndex}'),
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: StudentDensityTokens.ink,
        collapsedIconColor: StudentDensityTokens.muted,
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            result.isCorrect == true
                ? Icons.check_rounded
                : result.isCorrect == false
                ? Icons.close_rounded
                : Icons.more_horiz_rounded,
            color: color,
            size: 22,
          ),
        ),
        title: Text(
          '${result.itemIndex}번 문제',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        children: [
          if (result.warnings.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                result.warnings.join(', '),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (result.quest != null)
            SizedBox(
              width: double.infinity,
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
                label: const Text('풀이 흐름 보기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: StudentDensityTokens.ink,
                  side: const BorderSide(
                    color: StudentDensityTokens.lineStrong,
                  ),
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
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
  Widget _buildResultTile(BuildContext context, ExamGradeResult result) {
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

class _MobileStatDivider extends StatelessWidget {
  const _MobileStatDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 34, color: const Color(0xFF343438));
}

class _MobileEmptyResult extends StatelessWidget {
  const _MobileEmptyResult();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Column(
      children: [
        Icon(Icons.inbox_outlined, color: StudentDensityTokens.muted),
        SizedBox(height: 8),
        Text(
          '표시할 문항별 결과가 없습니다.',
          style: TextStyle(
            color: StudentDensityTokens.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
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
      mainAxisSize: MainAxisSize.min,
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
