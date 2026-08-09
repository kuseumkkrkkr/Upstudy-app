part of 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';

extension _MobileSolveStateView on _BuildpageWidgetState {
  /// 모바일 전용 문제풀이 진입점과 카드·필기판을 현재 상태에 연결한다.
  Widget _buildMobileSolveScaffold() => _renderMobileSolveScaffold(this);

  Widget _buildMobileProblemCard() => _renderMobileProblemCard(this);

  Widget _buildMobileWritingSurface() => _renderMobileWritingSurface(this);

  Widget _buildMobileToolbar() => _renderMobileToolbar(this);

  Widget _buildMobileQuickSolveCard() => _renderMobileQuickSolveCard(this);

  Widget _buildMobileQuickAnswerCard() => _renderMobileQuickAnswerCard(this);

  Widget _buildPlacementExamScaffold() => _renderPlacementExamScaffold(this);
}

String _placementTimerLabel(int seconds) {
  final minutes = seconds ~/ 60;
  final remain = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remain.toString().padLeft(2, '0')}';
}

Future<void> _confirmPlacementSubmit(_BuildpageWidgetState state) async {
  if (state._analysisBusy) return;
  final answered = List<int>.generate(
    state._problemCount,
    (index) => index,
  ).where(state._placementAnsweredAt).length;
  final blank = state._problemCount - answered;
  final confirmed = await showDialog<bool>(
    context: state.context,
    builder: (context) => AlertDialog(
      title: const Text('레벨 테스트를 제출할까요?'),
      content: Text(
        blank == 0
            ? '25문항을 마지막에 한 번 채점합니다.'
            : '빈 답 $blank개는 오답으로 채점됩니다. 그래도 제출할까요?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('계속 풀기'),
        ),
        FilledButton(
          key: const ValueKey('placement-confirm-submit'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('일괄 채점'),
        ),
      ],
    ),
  );
  if (confirmed == true) await state._submitPlacementExam();
}

Future<void> _showPlacementQuestionGrid(_BuildpageWidgetState state) async {
  await showModalBottomSheet<void>(
    context: state.context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '문항 이동',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              '답을 쓰지 않아도 원하는 문항으로 이동할 수 있어요.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 18),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 9,
                crossAxisSpacing: 9,
              ),
              itemCount: state._problemCount,
              itemBuilder: (context, index) {
                final current = index == state._currentProblemIndex;
                final answered = state._placementAnsweredAt(index);
                return Material(
                  color: current
                      ? Colors.black
                      : answered
                      ? const Color(0xFFE8E8E6)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                    side: BorderSide(
                      color: current ? Colors.black : const Color(0xFFD8D8D5),
                    ),
                  ),
                  child: InkWell(
                    key: ValueKey('placement-question-${index + 1}'),
                    borderRadius: BorderRadius.circular(13),
                    onTap: () {
                      Navigator.of(context).pop();
                      state._goToPlacementProblem(index);
                    },
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: current ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _renderPlacementExamScaffold(_BuildpageWidgetState state) {
  final options = state._currentQuestOptionBlocks();
  final answered = List<int>.generate(
    state._problemCount,
    (index) => index,
  ).where(state._placementAnsweredAt).length;
  final isLast = state._currentProblemIndex == state._problemCount - 1;
  final timerUrgent = state._timerDisplaySeconds <= 5 * 60;
  return Scaffold(
    key: const ValueKey('placement-exam-screen'),
    backgroundColor: const Color(0xFFF5F5F3),
    body: SafeArea(
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: Column(
              children: [
                SizedBox(
                  height: 62,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: '레벨 테스트 나가기',
                          onPressed: state._analysisBusy
                              ? null
                              : () => Navigator.of(state.context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const Expanded(
                          child: Text(
                            '레벨 테스트',
                            style: TextStyle(
                              fontSize: 19,
                              letterSpacing: -.6,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          key: const ValueKey('placement-timer'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: timerUrgent
                                ? const Color(0xFFFFE7E4)
                                : const Color(0xFFF0F0EE),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 16,
                                color: timerUrgent
                                    ? const Color(0xFFCF3527)
                                    : Colors.black87,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _placementTimerLabel(
                                  state._timerDisplaySeconds,
                                ),
                                style: TextStyle(
                                  color: timerUrgent
                                      ? const Color(0xFFB52D22)
                                      : Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                LinearProgressIndicator(
                  value: (state._currentProblemIndex + 1) / state._problemCount,
                  minHeight: 3,
                  color: Colors.black,
                  backgroundColor: const Color(0xFFE8E8E6),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
              children: [
                Row(
                  children: [
                    Text(
                      '${state._currentProblemIndex + 1}번',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '응답 $answered / ${state._problemCount}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE2E2DF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ContentBlocksView(
                        blocks: state._currentQuestTitleBlocks(),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          height: 1.5,
                          color: Color(0xFF202020),
                        ),
                        latexStyle: const TextStyle(
                          fontSize: 18,
                          height: 1.5,
                          color: Color(0xFF202020),
                        ),
                        inline: true,
                      ),
                      if (options.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        state._buildOptionPreview(
                          options,
                          selectedIndex: state._currentSelectedChoice(),
                        ),
                      ],
                    ],
                  ),
                ),
                if (options.isEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E2DF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '정답 입력',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          key: ValueKey(
                            'placement-answer-${state._currentProblemIndex + 1}',
                          ),
                          initialValue: state
                              ._placementAnswers[state._currentProblemIndex],
                          enabled: !state._timeLimitReached,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          textInputAction: isLast
                              ? TextInputAction.done
                              : TextInputAction.next,
                          onChanged: state._updatePlacementAnswer,
                          onFieldSubmitted: (_) {
                            if (!isLast)
                              state._goToPlacementProblem(
                                state._currentProblemIndex + 1,
                              );
                          },
                          decoration: InputDecoration(
                            hintText: '숫자 답을 입력하세요',
                            filled: true,
                            fillColor: const Color(0xFFF5F5F3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFDADAD7),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Colors.black45,
                    ),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '빈 답도 넘길 수 있으며 마지막에 전체 문항을 한 번만 채점합니다.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: Colors.white,
            elevation: 10,
            shadowColor: Colors.black12,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  children: [
                    InkWell(
                      key: const ValueKey('placement-question-grid'),
                      onTap: state._analysisBusy
                          ? null
                          : () => _showPlacementQuestionGrid(state),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.grid_view_rounded, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              '문항 보기',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$answered개 응답',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.expand_less_rounded,
                              size: 18,
                              color: Colors.black45,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('placement-previous'),
                            onPressed:
                                state._analysisBusy ||
                                    state._currentProblemIndex == 0
                                ? null
                                : () => state._goToPlacementProblem(
                                    state._currentProblemIndex - 1,
                                  ),
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('이전'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black,
                              minimumSize: const Size(0, 50),
                              side: const BorderSide(color: Color(0xFFD3D3D0)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            key: ValueKey(
                              isLast ? 'placement-submit' : 'placement-next',
                            ),
                            onPressed: state._analysisBusy
                                ? null
                                : isLast
                                ? () => _confirmPlacementSubmit(state)
                                : () => state._goToPlacementProblem(
                                    state._currentProblemIndex + 1,
                                  ),
                            icon: state._analysisBusy
                                ? const SizedBox.square(
                                    dimension: 17,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    isLast
                                        ? Icons.check_rounded
                                        : Icons.arrow_forward_rounded,
                                  ),
                            label: Text(
                              state._analysisBusy
                                  ? '제출 중'
                                  : isLast
                                  ? '전체 제출'
                                  : '다음 문제',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

final Expando<_MobileQuickSolveSession> _mobileQuickSolveSessions =
    Expando<_MobileQuickSolveSession>('mobileQuickSolveSessions');

class _MobileQuickSolveSession {
  _MobileQuickSolveSession({required this.questKey, required int stepCount})
    : slots = List<int?>.filled(stepCount, null),
      trayOrder = _shuffledFlowOrder(questKey, stepCount);

  final String questKey;
  final List<int?> slots;
  final List<int> trayOrder;
  String numericAnswer = '';
}

_MobileQuickSolveSession _mobileQuickSessionFor(_BuildpageWidgetState state) {
  final steps = _mobileFlowStepsFor(state._currentQuest?['solves']);
  final questId = state._currentQuestId().trim();
  final questKey = questId.isNotEmpty
      ? '$questId:${state._currentProblemIndex}'
      : 'problem:${state._currentProblemIndex}:${steps.length}';
  final current = _mobileQuickSolveSessions[state];
  if (current != null &&
      current.questKey == questKey &&
      current.slots.length == steps.length) {
    return current;
  }
  final created = _MobileQuickSolveSession(
    questKey: questKey,
    stepCount: steps.length,
  );
  _mobileQuickSolveSessions[state] = created;
  return created;
}

List<int> _shuffledFlowOrder(String key, int count) {
  final order = List<int>.generate(count, (index) => index);
  if (count <= 1) return order;
  final shift = (key.hashCode.abs() % (count - 1)) + 1;
  return <int>[...order.sublist(shift), ...order.sublist(0, shift)];
}

bool _mobileQuickFlowReady(_MobileQuickSolveSession session) =>
    session.slots.every((node) => node != null);

bool _isNumericQuickAnswer(String value) =>
    RegExp(r'^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$').hasMatch(value.trim());

bool _mobileQuickAnswerReady(
  _BuildpageWidgetState state,
  _MobileQuickSolveSession session,
) {
  if (state._currentQuestOptionBlocks().isNotEmpty) {
    return state._currentSelectedChoice() != null;
  }
  return _isNumericQuickAnswer(session.numericAnswer);
}

void _placeMobileFlowNode(
  _BuildpageWidgetState state,
  _MobileQuickSolveSession session,
  int nodeIndex,
  int slotIndex,
) {
  final previousSlot = session.slots.indexOf(nodeIndex);
  final displacedNode = session.slots[slotIndex];
  state.setState(() {
    if (previousSlot >= 0) session.slots[previousSlot] = displacedNode;
    session.slots[slotIndex] = nodeIndex;
  });
}

Future<void> _submitMobileQuickSolve(_BuildpageWidgetState state) async {
  if (state._analysisBusy) return;
  final session = _mobileQuickSessionFor(state);
  if (!_mobileQuickFlowReady(session)) {
    ScaffoldMessenger.of(
      state.context,
    ).showSnackBar(const SnackBar(content: Text('모든 Flow 노드를 순서 칸에 넣어주세요.')));
    return;
  }
  if (!_mobileQuickAnswerReady(state, session)) {
    ScaffoldMessenger.of(
      state.context,
    ).showSnackBar(const SnackBar(content: Text('객관식 답 또는 숫자 답을 입력해 주세요.')));
    return;
  }
  if (state._currentProblemIndex < state._problemGraded.length &&
      state._problemGraded[state._currentProblemIndex]) {
    ScaffoldMessenger.of(
      state.context,
    ).showSnackBar(const SnackBar(content: Text('이미 제출한 문제입니다.')));
    return;
  }
  final questId = state._currentQuestId();
  if (questId.isEmpty) {
    ScaffoldMessenger.of(
      state.context,
    ).showSnackBar(const SnackBar(content: Text('문제 ID가 없습니다.')));
    return;
  }

  state.setState(() => state._analysisBusy = true);
  try {
    final options = state._currentQuestOptionBlocks();
    final selectedIndex = state._currentSelectedChoice();
    final flowOrder = session.slots.whereType<int>().toList(growable: false);
    final result = await ApiClient.instance.gradeVariantSolve(
      questId: questId,
      selectedIndex: options.isNotEmpty ? selectedIndex : null,
      userAnswer: options.isEmpty ? session.numericAnswer.trim() : null,
      flowOrder: flowOrder,
    );
    final isCorrect = result['raw_correct'] == true || result['pass'] == true;
    final flowCorrect = result['flow_correct'] == true;
    final answerCorrect = result['answer_correct'] == true;
    final stepCorrectness = List<Map<String, dynamic>>.generate(
      session.slots.length,
      (index) => {
        'flow_number': index + 1,
        'status': session.slots[index] == index ? 'O' : 'X',
      },
      growable: false,
    );
    final quest = state._currentQuest;
    final fingerprint = state._problemFingerprint(
      quest,
      state._currentProblemIndex,
    );
    final problemMeta = state._problemMeta(quest);
    state._problemGraded[state._currentProblemIndex] = true;
    state._gradedCount += 1;
    if (isCorrect) state._correctCount += 1;
    if (state._ratingEnabled) {
      unawaited(
        state._submitRatingUpdate(
          quest: quest,
          isCorrect: isCorrect,
          stepCorrectness: stepCorrectness,
        ),
      );
    }
    await state.widget.config?.onProblemGraded?.call(
      itemIndex: state._currentProblemIndex + 1,
      quest: quest,
      isCorrect: isCorrect,
      stepCorrectness: stepCorrectness,
      selectedIndex: options.isNotEmpty ? selectedIndex : null,
      elapsedSeconds: state._sessionClock.elapsed.inSeconds,
    );
    try {
      if (isCorrect) {
        await ActivityStore.recordProblemSolve(
          problemId: fingerprint,
          problemNumber: fingerprint,
          difficultyTier: state._tierForProblemIndex(
            state._currentProblemIndex,
          ),
          meta: problemMeta.isEmpty ? null : problemMeta,
        );
      } else {
        await ActivityStore.recordProblemIncorrect(
          problemId: fingerprint,
          problemNumber: fingerprint,
          meta: problemMeta.isEmpty ? null : problemMeta,
        );
      }
    } catch (_) {}
    if (!state.mounted) return;
    final hasNext = state._currentProblemIndex < state._problemCount - 1;
    await showDialog<void>(
      context: state.context,
      builder: (context) => AlertDialog(
        title: Text(isCorrect ? '정답' : '다시 확인해 보세요'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MobileQuickResultRow(label: '풀이 흐름', correct: flowCorrect),
            const SizedBox(height: 8),
            _MobileQuickResultRow(label: '최종 정답', correct: answerCorrect),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (hasNext) state._goToNextProblem();
            },
            child: Text(hasNext ? '다음 문제' : '확인'),
          ),
        ],
      ),
    );
    state._completeCourseModuleIfNeeded();
  } catch (error) {
    if (!state.mounted) return;
    ScaffoldMessenger.of(state.context).showSnackBar(
      SnackBar(
        content: Text(
          studentFacingApiError(error, fallback: '간편풀이 답안을 채점하지 못했어요.'),
        ),
      ),
    );
  } finally {
    if (state.mounted) state.setState(() => state._analysisBusy = false);
  }
}

/// 필요한 변수는 현재 문제 카드, 세로 필기판, 하단 도구 모음이다.
/// 작동 원리는 모바일에서 PC용 오버레이 캔버스를 제거하고 문제와 필기판을 세로 순서로 분리하는 것이다.
Widget _renderMobileSolveScaffold(_BuildpageWidgetState state) {
  final progress =
      (state._currentProblemIndex + 1) / math.max(1, state._problemCount);
  final hasOptions = state._currentQuestOptionBlocks().isNotEmpty;
  final showWritingSurface =
      !state._mobileQuickSolve && (!hasOptions || state._mobileNoteExpanded);
  return Stack(
    children: [
      GestureDetector(
        onTap: () => FocusScope.of(state.context).unfocus(),
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F5F3),
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 58,
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: '문제 풀이 나가기',
                              onPressed: () =>
                                  Navigator.of(state.context).maybePop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(width: 2),
                            const Expanded(
                              child: Text(
                                '문제 풀이',
                                style: TextStyle(
                                  fontSize: 19,
                                  letterSpacing: -.6,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              '${state._currentProblemIndex + 1} / ${state._problemCount}',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            IconButton(
                              tooltip: '문제풀이 안내',
                              onPressed: state._showSolveInfo,
                              icon: const Icon(
                                Icons.info_outline_rounded,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        color: Colors.black,
                        backgroundColor: const Color(0xFFE8E8E6),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                    children: [
                      state._buildMobileProblemCard(),
                      const SizedBox(height: 10),
                      if (state._mobileQuickSolve) ...[
                        state._buildMobileQuickSolveCard(),
                        const SizedBox(height: 12),
                        state._buildMobileQuickAnswerCard(),
                      ] else if (showWritingSurface)
                        state._buildMobileWritingSurface(),
                      if (!state._mobileQuickSolve &&
                          hasOptions &&
                          !showWritingSurface)
                        _renderMobileNoteLauncher(state),
                    ],
                  ),
                ),
                state._buildMobileToolbar(),
              ],
            ),
          ),
        ),
      ),
      if (state._questLoading) state._buildGenerationOverlay(),
      if (!state._questLoading && state._hasPendingGeneration)
        state._buildGenerationStatusBadge(),
    ],
  );
}

/// 필요한 변수는 현재 도구·선택 답·필기 획·제출 상태다.
/// 작동 원리는 접힌 객관식에서는 노트·제출만, 필기판을 펼치면 편집 도구까지
/// 한 줄에 보여 답 선택과 필기 작업의 우선순위를 분리하는 것이다.
Widget _renderMobileToolbar(_BuildpageWidgetState state) {
  final options = state._currentQuestOptionBlocks();
  final quickSession = _mobileQuickSessionFor(state);
  final showWritingTools =
      !state._mobileQuickSolve &&
      (options.isEmpty || state._mobileNoteExpanded);
  final canSubmit = options.isNotEmpty
      ? state._currentSelectedChoice() != null
      : state._strokes.isNotEmpty || state._currentStroke != null;
  final quickReady =
      _mobileQuickFlowReady(quickSession) &&
      _mobileQuickAnswerReady(state, quickSession);
  final submit = state._mobileQuickSolve
      ? () => _submitMobileQuickSolve(state)
      : state._handleGrade;
  return Material(
    color: Colors.white,
    elevation: 12,
    shadowColor: Colors.black12,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          children: [
            if (showWritingTools) ...[
              _MobileSolveTool(
                icon: Icons.edit_rounded,
                label: '펜',
                active: state._toolMode == _ToolMode.pen,
                onTap: () => state._setToolMode(_ToolMode.pen),
              ),
              _MobileSolveTool(
                icon: Icons.auto_fix_off_rounded,
                label: '지우개',
                active: state._toolMode == _ToolMode.eraser,
                onTap: () => state._setToolMode(_ToolMode.eraser),
              ),
              _MobileSolveTool(
                icon: Icons.palette_outlined,
                label: '색상',
                indicatorColor: state._penColor,
                onTap: state._openPenSettings,
              ),
              _MobileSolveTool(
                icon: Icons.undo_rounded,
                label: '되돌리기',
                enabled: state._undoStack.isNotEmpty,
                onTap: () {
                  state._undo();
                  state.setState(() {});
                },
              ),
              _MobileSolveTool(
                icon: Icons.delete_outline_rounded,
                label: '지우기',
                enabled:
                    state._strokes.isNotEmpty || state._currentStroke != null,
                onTap: () {
                  state._clearAll();
                  state.setState(() {});
                },
              ),
              const SizedBox(width: 6),
            ] else if (!state._mobileQuickSolve) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state._toggleMobileNote,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(96, 48),
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Color(0xFFD8D8D6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.draw_outlined, size: 19),
                  label: const Text(
                    '풀이 노트',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ] else
              const Spacer(),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed:
                    state._analysisBusy ||
                        state._hasPendingGeneration ||
                        (state._mobileQuickSolve ? !quickReady : !canSubmit)
                    ? null
                    : submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(88, 48),
                  backgroundColor: Colors.black,
                  disabledBackgroundColor: const Color(0xFFD8D8D6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.check_rounded, size: 19),
                label: Text(
                  state._mobileQuickSolve ? '풀이 제출' : '제출',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 필요한 변수는 현재 선택한 객관식 답과 간편풀이 모드다.
/// 작동 원리는 필기판·도구 모음을 완전히 제외하고 답 선택과 즉시 채점만 남겨 일반 풀이와
/// 같은 화면으로 보이지 않게 하는 것이다.
Widget _renderMobileQuickAnswerCard(_BuildpageWidgetState state) {
  final session = _mobileQuickSessionFor(state);
  final options = state._currentQuestOptionBlocks();
  final selected = state._currentSelectedChoice();
  return Container(
    key: const ValueKey('mobile-quick-answer-card'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE3E3E0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '2',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '최종 정답 입력',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '객관식 또는 숫자 답안을 입력하세요.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (options.isNotEmpty) ...[
          state._buildOptionPreview(options, selectedIndex: selected),
          if (selected != null) ...[
            const SizedBox(height: 10),
            Text(
              '${selected + 1}번을 선택했습니다.',
              style: const TextStyle(
                color: Color(0xFF2E7D57),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ] else
          TextFormField(
            key: ValueKey(
              'mobile-quick-numeric-answer-${state._currentProblemIndex}',
            ),
            initialValue: session.numericAnswer,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            textInputAction: TextInputAction.done,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onChanged: (value) {
              session.numericAnswer = value;
              state.setState(() {});
            },
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return null;
              return _isNumericQuickAnswer(text) ? null : '숫자만 입력해 주세요.';
            },
            decoration: InputDecoration(
              hintText: '예: -2.5',
              prefixIcon: const Icon(Icons.numbers_rounded),
              filled: true,
              fillColor: const Color(0xFFF5F5F3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE1E1DE)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.black, width: 1.5),
              ),
            ),
          ),
      ],
    ),
  );
}

/// 필요한 변수는 현재 문제의 본문과 선택지다.
/// 작동 원리는 중복 문제 번호를 없애고 글자·여백·선택지 높이를 줄여 문제와 답을
/// 첫 화면에서 함께 읽을 수 있게 한다.
Widget _renderMobileProblemCard(_BuildpageWidgetState state) {
  final blocks = state._currentQuestTitleBlocks();
  final options = state._currentQuestOptionBlocks();
  final tag = state._hashTags.isEmpty
      ? null
      : state._hashTags.first.replaceFirst('#', '');
  return DecoratedBox(
    key: const ValueKey('mobile-solve-problem-card'),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE7E7E4)),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (tag != null)
                Expanded(
                  child: Text(
                    tag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black45,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                const Spacer(),
              TextButton(
                onPressed: state._showHint,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('힌트'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (state._questLoading)
            const LinearProgressIndicator(minHeight: 2)
          else if (state._questError != null)
            Text(
              state._questError!,
              style: const TextStyle(color: Colors.redAccent),
            )
          else
            ContentBlocksView(
              blocks: blocks,
              textStyle: const TextStyle(
                fontSize: 17,
                height: 1.35,
                letterSpacing: -.35,
                color: Color(0xFF202020),
              ),
              latexStyle: const TextStyle(
                fontSize: 17,
                height: 1.35,
                color: Color(0xFF202020),
              ),
              inline: true,
            ),
          if (options.isNotEmpty && !state._mobileQuickSolve) ...[
            const SizedBox(height: 10),
            state._buildOptionPreview(
              options,
              selectedIndex: state._currentSelectedChoice(),
            ),
          ],
        ],
      ),
    ),
  );
}

/// 필요한 변수는 객관식 문제의 접힌 풀이 노트 상태다.
/// 작동 원리는 작은 한 줄 행동만 보여 주고, 탭하면 기존 필기판과 편집 도구를 함께 펼친다.
Widget _renderMobileNoteLauncher(_BuildpageWidgetState state) {
  return Material(
    key: const ValueKey('mobile-solve-note-launcher'),
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: state._toggleMobileNote,
      child: const SizedBox(
        height: 56,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.draw_outlined, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '풀이 노트',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '필요할 때 펼치기',
                style: TextStyle(color: Colors.black45, fontSize: 11),
              ),
              SizedBox(width: 4),
              Icon(Icons.expand_more_rounded, color: Colors.black45, size: 20),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 필요한 변수는 필기 획과 모바일 viewport다.
/// 작동 원리는 필기 영역을 문제 카드와 분리하고 항상 세로 스크롤을 허용해 긴 풀이 중간의 입력 단절 구간을 없애는 것이다.
Widget _renderMobileWritingSurface(_BuildpageWidgetState state) {
  final canCollapse = state._currentQuestOptionBlocks().isNotEmpty;
  return DecoratedBox(
    key: const ValueKey('mobile-solve-writing-surface'),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE7E7E4)),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.draw_outlined, size: 18),
              const SizedBox(width: 7),
              const Text(
                '풀이 노트',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              if (canCollapse)
                TextButton.icon(
                  onPressed: state._toggleMobileNote,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black54,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  icon: const Icon(Icons.expand_less_rounded, size: 18),
                  label: const Text(
                    '접기',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                )
              else
                const Text(
                  '손가락이나 펜으로 작성',
                  style: TextStyle(color: Colors.black38, fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: AspectRatio(
              aspectRatio:
                  _BuildpageWidgetState._baseWidth /
                  _BuildpageWidgetState._baseHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale =
                      constraints.maxWidth / _BuildpageWidgetState._baseWidth;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: state._noteLinesEnabled
                            ? CustomPaint(
                                painter: _NotebookPaperPainter(
                                  lineStartY:
                                      _BuildpageWidgetState._noteLineStartY *
                                      scale,
                                  lineSpacing:
                                      _BuildpageWidgetState._noteLineSpacing *
                                      scale,
                                  leftMargin:
                                      _BuildpageWidgetState._noteLeftMargin *
                                      scale,
                                ),
                              )
                            : const ColoredBox(color: Colors.white),
                      ),
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (details) {
                            final position = state._toLogicalPosition(
                              details.localPosition,
                              scale,
                            );
                            state._ensureClockRunning();
                            if (state._toolMode == _ToolMode.pen) {
                              state._startStroke(position, 1);
                            } else {
                              state._startEraser(position);
                            }
                          },
                          onPanUpdate: (details) {
                            final position = state._toLogicalPosition(
                              details.localPosition,
                              scale,
                            );
                            if (!state._withinCanvas(position)) return;
                            if (state._toolMode == _ToolMode.pen) {
                              state._appendStroke(position, 1);
                            } else {
                              state._updateEraser(position);
                            }
                          },
                          onPanEnd: (_) {
                            if (state._toolMode == _ToolMode.pen) {
                              state._finishStroke();
                            } else {
                              state._finishEraser();
                            }
                            state.setState(() {});
                          },
                          onPanCancel: () {
                            if (state._toolMode == _ToolMode.pen) {
                              state._finishStroke();
                            } else {
                              state._finishEraser();
                            }
                            state.setState(() {});
                          },
                          child: ValueListenableBuilder<int>(
                            valueListenable: state._paintVersion,
                            builder: (context, _, __) => CustomPaint(
                              painter: _StrokePainter(
                                strokes: state._strokes,
                                currentStroke: state._currentStroke,
                                eraserPosition: state._eraserActive
                                    ? state._eraserPosition
                                    : null,
                                eraserRadius:
                                    _BuildpageWidgetState._eraserRadius,
                                scale: scale,
                                logicalSize: const Size(
                                  _BuildpageWidgetState._baseWidth,
                                  _BuildpageWidgetState._baseHeight,
                                ),
                                backgroundColor: Colors.transparent,
                                repaint: state._paintVersion,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (state._strokes.isEmpty &&
                          state._currentStroke == null)
                        const Positioned(
                          left: 14,
                          top: 12,
                          child: IgnorePointer(
                            child: Text(
                              '여기에 풀이를 적어보세요',
                              style: TextStyle(
                                color: Colors.black26,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MobileSolveTool extends StatelessWidget {
  const _MobileSolveTool({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.enabled = true,
    this.indicatorColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool enabled;
  final Color? indicatorColor;

  /// 필요한 변수는 도구 아이콘·활성 상태·동작 콜백이다.
  /// 작동 원리는 좁은 하단 바에서 최소 44px 터치 영역과 현재 선택 상태를 함께 제공하는 것이다.
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 45,
    height: 48,
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: active ? const Color(0xFFEEEEEC) : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 21,
              color: enabled ? Colors.black : Colors.black26,
            ),
          ),
          if (indicatorColor != null)
            Positioned(
              right: 6,
              bottom: 5,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            child: ExcludeSemantics(
              child: Text(
                label,
                style: TextStyle(
                  color: enabled ? Colors.black54 : Colors.black26,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 필요한 변수는 문제의 Flow 노드와 현재 조립 상태다.
/// 작동 원리는 무작위 노드 보관함에서 번호가 있는 순서 칸으로 드래그해 풀이 흐름을 직접 조립하게 하는 것이다.
Widget _renderMobileQuickSolveCard(_BuildpageWidgetState state) {
  final steps = _mobileFlowStepsFor(state._currentQuest?['solves']);
  final session = _mobileQuickSessionFor(state);
  if (steps.isEmpty) {
    return Container(
      key: const ValueKey('mobile-quick-flow-empty'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E3E0)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '이 문제에는 조립할 Flow 노드가 없습니다. 최종 정답만 입력해 제출하세요.',
              style: TextStyle(color: Colors.black54, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
  final unplaced = session.trayOrder
      .where((nodeIndex) => !session.slots.contains(nodeIndex))
      .toList(growable: false);
  return Container(
    key: const ValueKey('mobile-quick-flow-builder'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE3E3E0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '1',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flow 조립',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '노드를 길게 눌러 순서 칸에 끌어놓으세요.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Flow 조립 초기화',
              onPressed: session.slots.any((node) => node != null)
                  ? () => state.setState(
                      () => session.slots.fillRange(
                        0,
                        session.slots.length,
                        null,
                      ),
                    )
                  : null,
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Flow 노드 보관함',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '${unplaced.length}개 남음',
              style: const TextStyle(
                color: Colors.black45,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (unplaced.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6EF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF2E7D57),
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  '모든 노드를 배치했습니다.',
                  style: TextStyle(
                    color: Color(0xFF2E7D57),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: unplaced.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final nodeIndex = unplaced[index];
                return SizedBox(
                  width: 258,
                  child: _MobileFlowDraggableNode(
                    key: ValueKey('mobile-flow-node-source-$nodeIndex'),
                    nodeIndex: nodeIndex,
                    label: _mobileFlowNodeLabel(session.trayOrder, nodeIndex),
                    text: steps[nodeIndex],
                    onTap: () {
                      final emptySlot = session.slots.indexOf(null);
                      if (emptySlot >= 0) {
                        _placeMobileFlowNode(
                          state,
                          session,
                          nodeIndex,
                          emptySlot,
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          '나의 풀이 순서',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        for (var slotIndex = 0; slotIndex < session.slots.length; slotIndex++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MobileFlowSlot(
              key: ValueKey('mobile-flow-slot-$slotIndex'),
              slotIndex: slotIndex,
              nodeIndex: session.slots[slotIndex],
              steps: steps,
              trayOrder: session.trayOrder,
              onAccept: (nodeIndex) =>
                  _placeMobileFlowNode(state, session, nodeIndex, slotIndex),
              onRemove: () =>
                  state.setState(() => session.slots[slotIndex] = null),
            ),
          ),
      ],
    ),
  );
}

String _mobileFlowNodeLabel(List<int> trayOrder, int nodeIndex) {
  final displayIndex = trayOrder.indexOf(nodeIndex);
  if (displayIndex >= 0 && displayIndex < 26) {
    return '노드 ${String.fromCharCode(65 + displayIndex)}';
  }
  return '노드 ${displayIndex + 1}';
}

class _MobileFlowSlot extends StatelessWidget {
  const _MobileFlowSlot({
    super.key,
    required this.slotIndex,
    required this.nodeIndex,
    required this.steps,
    required this.trayOrder,
    required this.onAccept,
    required this.onRemove,
  });

  final int slotIndex;
  final int? nodeIndex;
  final List<String> steps;
  final List<int> trayOrder;
  final ValueChanged<int> onAccept;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => DragTarget<int>(
    onWillAcceptWithDetails: (details) =>
        details.data >= 0 && details.data < steps.length,
    onAcceptWithDetails: (details) => onAccept(details.data),
    builder: (context, candidates, rejected) {
      final active = candidates.isNotEmpty;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEAF6EF) : const Color(0xFFF5F5F3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? const Color(0xFF2E7D57) : const Color(0xFFDADAD6),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${slotIndex + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: nodeIndex == null
                  ? Text(
                      active ? '여기에 놓기' : 'Flow 노드를 끌어오세요',
                      style: const TextStyle(
                        color: Colors.black38,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : _MobileFlowDraggableNode(
                      nodeIndex: nodeIndex!,
                      label: _mobileFlowNodeLabel(trayOrder, nodeIndex!),
                      text: steps[nodeIndex!],
                      compact: true,
                      onTap: onRemove,
                    ),
            ),
          ],
        ),
      );
    },
  );
}

class _MobileFlowDraggableNode extends StatelessWidget {
  const _MobileFlowDraggableNode({
    super.key,
    required this.nodeIndex,
    required this.label,
    required this.text,
    required this.onTap,
    this.compact = false,
  });

  final int nodeIndex;
  final String label;
  final String text;
  final VoidCallback onTap;
  final bool compact;

  Widget _card({bool feedback = false}) => Material(
    color: Colors.transparent,
    child: Container(
      width: feedback ? 300 : null,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 11,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD5D5D2)),
        boxShadow: feedback
            ? const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.drag_indicator_rounded, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  maxLines: compact ? 2 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF202020),
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (compact)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.close_rounded, size: 16, color: Colors.black38),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label. 길게 눌러 드래그하거나 탭해 배치',
    button: true,
    child: LongPressDraggable<int>(
      data: nodeIndex,
      delay: const Duration(milliseconds: 220),
      feedback: _card(feedback: true),
      childWhenDragging: Opacity(opacity: .32, child: _card()),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: _card(),
      ),
    ),
  );
}

class _MobileQuickResultRow extends StatelessWidget {
  const _MobileQuickResultRow({required this.label, required this.correct});

  final String label;
  final bool correct;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
        color: correct ? const Color(0xFF2E7D57) : const Color(0xFFB5473C),
        size: 20,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      Text(
        correct ? '정답' : '오답',
        style: TextStyle(
          color: correct ? const Color(0xFF2E7D57) : const Color(0xFFB5473C),
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

/// 필요한 변수는 서버가 전달한 solves 트리다.
/// 작동 원리는 순차 단계와 분기 단계를 깊이 우선으로 펼쳐 모바일 순서 선택 UI와 동일한 기준을 제공하는 것이다.
List<String> _mobileFlowStepsFor(dynamic value) {
  final steps = <String>[];
  void collect(dynamic current) {
    if (current is List) {
      for (final item in current) {
        collect(item);
      }
      return;
    }
    if (current is Map) {
      final flow = contentBlocksToPlainText(
        normalizeFlowBlocks(parseContentBlocks(current['flow'])),
      ).trim();
      if (flow.isNotEmpty) steps.add(flow);
      collect(current['branches']);
    }
  }

  collect(value);
  return steps;
}
