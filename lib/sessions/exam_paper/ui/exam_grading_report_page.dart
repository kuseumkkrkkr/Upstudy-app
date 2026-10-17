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
    final correct = results
        .where((r) => !r.empty && r.error == null && r.isCorrect == true)
        .length;
    final incorrect = results
        .where((r) => !r.empty && r.error == null && r.isCorrect == false)
        .length;
    final empty = results.where((r) => r.empty).length;
    final errors = results.where((r) => r.error != null).length;
    final graded = results
        .where((r) => !r.empty && r.error == null && r.isCorrect != null)
        .length;
    final score = total > 0 ? (correct * 100 / total).round() : 0;
    final viewport = MediaQuery.sizeOf(context);
    // The compact result layout is for portrait phones, not the reduced
    // content width left by a tablet/desktop shell's reserved context rail.
    final mobile = viewport.width <= 600 && viewport.height > viewport.width;
    if (mobile) {
      return _buildPortraitPhonePage(
        context,
        total: total,
        processed: graded,
        progress: total > 0 ? (graded / total).clamp(0, 1) : 0,
        correct: correct,
        incorrect: incorrect,
        empty: empty,
        errors: errors,
        score: score.toDouble(),
      );
    }
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _reportSection(
          '01',
          '채점 요약',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '채점 완료',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '$graded / $total',
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: total > 0 ? (graded / total).clamp(0, 1) : 0,
                minHeight: 5,
                color: const Color(0xFF09090B),
                backgroundColor: const Color(0xFFF3F3F5),
              ),
              const SizedBox(height: 10),
              Text(
                errors > 0
                    ? '채점 오류 $errors문항이 있어요. 문항별 상태를 확인해 주세요.'
                    : graded == total
                    ? '모든 문항의 채점이 완료됐습니다.'
                    : '미응답·미채점 문항을 확인해 주세요.',
                style: const TextStyle(
                  fontSize: 8,
                  height: 1.5,
                  color: Color(0xFF71717A),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: mobile ? 10 : 14),
        _reportSection(
          '02',
          '학습 피드백',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '종합 학습 피드백이 제공되지 않았어요.',
                style: TextStyle(
                  fontSize: 21,
                  height: 1.35,
                  letterSpacing: -.84,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              for (final label in ['강점', '보완', '다음'])
                Container(
                  constraints: const BoxConstraints(minHeight: 46),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0x1909090B)),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF71717A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('—', style: TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: mobile ? 10 : 14),
        _reportSection(
          '03',
          '코스 진도',
          Text(
            moduleSubmissionRequired
                ? '코스 제출 상태를 아래에서 확인하고 필요하면 다시 제출해 주세요.'
                : '이 시험은 코스 진도 제출 대상이 아닙니다.',
            style: const TextStyle(fontSize: 8, height: 1.5),
          ),
        ),
      ],
    );
    final questions = _reportQuestions(context, correct, total, mobile);
    return StudentHtmlShell(
      key: mobile
          ? const ValueKey('exam-result-portrait-mobile')
          : const ValueKey('exam-result-html-desktop'),
      title: '채점 리포트',
      activeRoute: '/bookbag',
      railWidth: 84,
      reserveContextTrack: true,
      mobileBackButton: true,
      onMenu: () => Navigator.of(context).maybePop(),
      child: ColoredBox(
        color: const Color(0xFFF0F0F2),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Padding(
                padding: mobile
                    ? const EdgeInsets.fromLTRB(10, 10, 10, 24)
                    : const EdgeInsets.fromLTRB(18, 24, 18, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      constraints: BoxConstraints(minHeight: mobile ? 64 : 72),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0x2909090B)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '시험 결과',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF71717A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '시험 결과',
                                  style: TextStyle(
                                    fontSize: mobile ? 20 : 25,
                                    letterSpacing: -.05 * (mobile ? 20 : 25),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0x2909090B),
                              ),
                            ),
                            child: Text(
                              passed ? '시험 통과' : '통과 기준 미달',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: mobile ? 10 : 14),
                    _reportScore(
                      score,
                      correct,
                      incorrect,
                      empty,
                      total,
                      mobile,
                    ),
                    SizedBox(height: mobile ? 10 : 14),
                    if (mobile) ...[
                      summary,
                      const SizedBox(height: 10),
                      questions,
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 320, child: summary),
                          const SizedBox(width: 14),
                          Expanded(child: questions),
                        ],
                      ),
                    SizedBox(height: mobile ? 10 : 14),
                    Row(
                      key: const ValueKey('exam-result-mobile-footer'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 100,
                          child: OutlinedButton(
                            onPressed: incorrect > 0
                                ? () => Navigator.of(
                                    context,
                                  ).pushNamed('/wrong_answers')
                                : null,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              visualDensity: VisualDensity.standard,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: const RoundedRectangleBorder(),
                            ),
                            child: const Text(
                              '틀린 문제 복습',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: mobile ? 135 : 100,
                          child: ModuleSubmissionFooter(
                            passed: passed,
                            submissionRequired: moduleSubmissionRequired,
                            initialSubmissionSucceeded:
                                moduleSubmissionSucceeded,
                            onRetry: onRetryModuleSubmission,
                            completionLabel: '코스로 돌아가기 →',
                            onComplete: () => Navigator.of(context).pop(true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _reportSection(String number, String title, Widget body) => Container(
    key: ValueKey('exam-report-section-$number'),
    decoration: BoxDecoration(
      color: const Color(0xFFFDFDFE),
      border: Border.all(color: const Color(0x1909090B)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: ValueKey('exam-report-section-header-$number'),
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x1909090B))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                number,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Padding(
          key: ValueKey('exam-report-section-body-$number'),
          padding: number == '02'
              ? const EdgeInsets.symmetric(vertical: 18, horizontal: 16)
              : const EdgeInsets.all(16),
          child: body,
        ),
      ],
    ),
  );

  Widget _reportScore(
    int score,
    int correct,
    int incorrect,
    int empty,
    int total,
    bool mobile,
  ) {
    final scoreCopy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'FINAL SCORE',
          style: TextStyle(
            color: Color(0xFFA1A1AA),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.08,
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            text: '$score',
            style: TextStyle(
              color: Colors.white,
              fontSize: mobile ? 58 : 66,
              height: .95,
              letterSpacing: -.07 * (mobile ? 58 : 66),
              fontWeight: FontWeight.w900,
            ),
            children: const [
              TextSpan(
                text: '점',
                style: TextStyle(fontSize: 17, letterSpacing: 0),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$total문제 중 $correct문제 정답',
          style: const TextStyle(
            color: Color(0xFFD4D4D8),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    final metrics = Row(
      children: [
        for (final entry in {
          '정답': '$correct',
          '오답': '$incorrect',
          '미응답': '$empty',
          '풀이 시간': '—',
        }.entries)
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: mobile ? 8 : 18,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                border: Border(
                  left: mobile
                      ? BorderSide.none
                      : const BorderSide(color: Color(0xFF343438)),
                  right: mobile
                      ? const BorderSide(color: Color(0xFF343438))
                      : BorderSide.none,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 8,
                      color: Color(0xFFA1A1AA),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: mobile ? 16 : 20,
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    return Container(
      key: const ValueKey('exam-result-mobile-score'),
      constraints: BoxConstraints(minHeight: mobile ? 0 : 210),
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 20 : 34,
        vertical: mobile ? 24 : 30,
      ),
      color: const Color(0xFF09090B),
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                scoreCopy,
                const SizedBox(height: 22),
                Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFF343438))),
                  ),
                  child: metrics,
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: scoreCopy),
                SizedBox(width: 388, child: metrics),
              ],
            ),
    );
  }

  Widget _reportQuestions(
    BuildContext context,
    int correct,
    int total,
    bool mobile,
  ) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFFDFDFE),
      border: Border.all(color: const Color(0x1909090B)),
    ),
    child: Column(
      children: [
        Container(
          constraints: BoxConstraints(minHeight: mobile ? 66 : 70),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x1909090B))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '문항별 결과',
                      style: TextStyle(fontSize: 8, color: Color(0xFF71717A)),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '정답 $correct / $total',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (results.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('표시할 문항별 결과가 없습니다.'),
          )
        else
          for (var index = 0; index < results.length; index += mobile ? 1 : 2)
            Row(
              children: [
                Expanded(child: _reportResultRow(context, results[index])),
                if (!mobile)
                  Expanded(
                    child: index + 1 < results.length
                        ? _reportResultRow(context, results[index + 1])
                        : const SizedBox(),
                  ),
              ],
            ),
      ],
    ),
  );

  Widget _reportResultRow(BuildContext context, ExamGradeResult result) {
    final label = result.empty
        ? '미응답'
        : result.error != null
        ? '오류'
        : result.isCorrect == true
        ? '정답'
        : result.isCorrect == false
        ? '오답'
        : '미판정';
    return Material(
      color: const Color(0xFFFDFDFE),
      child: InkWell(
        key: ValueKey('exam-result-mobile-question-${result.itemIndex}'),
        onTap: () => _reportDetail(context, result, label),
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0x1909090B)),
              right: BorderSide(color: Color(0x1909090B)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                color: result.isCorrect == false
                    ? const Color(0xFFB91C1C)
                    : const Color(0xFF09090B),
                child: Text(
                  result.itemIndex.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '문제 ${result.itemIndex}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      result.error ?? (result.empty ? '답안 없음' : '문항별 채점 상세'),
                      style: const TextStyle(
                        fontSize: 8,
                        color: Color(0xFF71717A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 9)),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 15),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reportDetail(
    BuildContext context,
    ExamGradeResult result,
    String label,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(),
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '문항별 채점',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close, size: 19),
                  ),
                ],
              ),
              Text(
                '문제 ${result.itemIndex}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (result.analysis != null) Text(result.analysis!),
              if (result.error != null)
                Semantics(liveRegion: true, child: Text(result.error!)),
              if (result.warnings.isNotEmpty)
                Text('경고: ${result.warnings.join(', ')}'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: result.quest == null
                    ? null
                    : () {
                        Navigator.of(sheetContext).pop();
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
                child: const Text('풀이 Flow 보기 →'),
              ),
              if (result.quest == null)
                const Text(
                  '풀이 데이터가 없어 Flow를 열 수 없습니다.',
                  style: TextStyle(fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    ),
  );
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
    final scoreValue = score.round();
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
      child: Material(
        type: MaterialType.transparency,
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
    this.completionLabel = '완료',
    this.onRetry,
  });

  final bool passed;
  final bool submissionRequired;
  final bool initialSubmissionSucceeded;
  final VoidCallback onComplete;
  final String completionLabel;
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
            visualDensity: VisualDensity.standard,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
          child: Text(
            widget.passed
                ? blockedBySubmission
                      ? '진도 제출이 필요해요'
                      : widget.completionLabel
                : '통과 후 완료할 수 있어요',
          ),
        ),
      ],
    );
  }
}
