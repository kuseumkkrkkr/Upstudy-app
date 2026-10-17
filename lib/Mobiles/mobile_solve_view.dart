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
  final currentIndex = state._currentProblemIndex;
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
                          key: ValueKey('placement-answer-${currentIndex + 1}'),
                          controller:
                              state._placementAnswerControllers[currentIndex],
                          enabled: !state._timeLimitReached,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          textInputAction: isLast
                              ? TextInputAction.done
                              : TextInputAction.next,
                          onChanged: (value) =>
                              state._updatePlacementAnswer(currentIndex, value),
                          onFieldSubmitted: (_) {
                            if (!isLast)
                              state._goToPlacementProblem(currentIndex + 1);
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
                Container(
                  key: const ValueKey('placement-writing-mode-controls'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E2DF)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '풀이 메모',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '채점에는 반영되지 않아요',
                              style: TextStyle(
                                color: Colors.black45,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _PlacementModeButton(
                        key: const ValueKey('placement-move-mode'),
                        stateKey: 'placement-move-mode-state',
                        label: '이동',
                        icon: Icons.pan_tool_outlined,
                        selected: !state._placementWritingMode,
                        onTap: () => state._setPlacementWritingMode(false),
                      ),
                      const SizedBox(width: 6),
                      _PlacementModeButton(
                        key: const ValueKey('placement-write-mode'),
                        stateKey: 'placement-write-mode-state',
                        label: '필기',
                        icon: Icons.edit_outlined,
                        selected: state._placementWritingMode,
                        onTap: () => state._setPlacementWritingMode(true),
                      ),
                    ],
                  ),
                ),
                if (state._placementWritingMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          key: const ValueKey('placement-pen-tool'),
                          tooltip: '펜',
                          onPressed: () => state._setToolMode(_ToolMode.pen),
                          icon: Icon(
                            Icons.edit_outlined,
                            color: state._toolMode == _ToolMode.pen
                                ? Colors.black
                                : Colors.black38,
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('placement-eraser-tool'),
                          tooltip: '지우개',
                          onPressed: () => state._setToolMode(_ToolMode.eraser),
                          icon: Icon(
                            Icons.cleaning_services_outlined,
                            color: state._toolMode == _ToolMode.eraser
                                ? Colors.black
                                : Colors.black38,
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('placement-undo-tool'),
                          tooltip: '되돌리기',
                          onPressed: state._undoStack.isEmpty
                              ? null
                              : state._undo,
                          icon: const Icon(Icons.undo_rounded),
                        ),
                        IconButton(
                          key: const ValueKey('placement-clear-tool'),
                          tooltip: '전체 지우기',
                          onPressed: state._strokes.isEmpty
                              ? null
                              : state._clearAll,
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                _renderMobileWritingSurface(
                  state,
                  interactive: state._placementWritingMode,
                  allowCollapse: false,
                ),
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
                        '빈 답은 제출하면 오답 처리됩니다.',
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

/// 레벨테스트 필기판의 이동·필기 모드를 같은 크기의 명확한 버튼으로 표시한다.
class _PlacementModeButton extends StatelessWidget {
  const _PlacementModeButton({
    super.key,
    required this.stateKey,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String stateKey;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? Colors.black : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(
        color: selected ? Colors.black : const Color(0xFFD6D6D3),
      ),
    ),
    child: Semantics(
      key: ValueKey(stateKey),
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 72,
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : Colors.black54,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

final Expando<Map<int, _MobileQuickSolveSession>> _mobileQuickSolveSessions =
    Expando<Map<int, _MobileQuickSolveSession>>('mobileQuickSolveSessions');

class _MobileQuickSolveSession {
  _MobileQuickSolveSession({required this.questKey, required int stepCount})
    : slots = List<int?>.filled(stepCount, null),
      trayOrder = _shuffledFlowOrder(questKey, stepCount);

  final String questKey;
  final List<int?> slots;
  final List<int> trayOrder;
  String numericAnswer = '';
  bool? firstCorrect;
  bool practiceRetry = false;
  final GlobalKey htmlSurfaceKey = GlobalKey();
}

_MobileQuickSolveSession _mobileQuickSessionFor(
  _BuildpageWidgetState state, {
  int? problemIndex,
}) {
  final index = problemIndex ?? state._currentProblemIndex;
  final quest = index >= 0 && index < state._quests.length
      ? state._quests[index]
      : null;
  final steps = _mobileFlowStepsFor(quest?['solves']);
  final header = quest?['header'];
  final questId = header is Map
      ? (header['quest_id'] ?? '').toString().trim()
      : '';
  final questKey = questId.isNotEmpty
      ? '$questId:$index'
      : 'problem:$index:${steps.length}';
  final sessions = _mobileQuickSolveSessions[state] ??=
      <int, _MobileQuickSolveSession>{};
  final current = sessions[index];
  if (current != null &&
      current.questKey == questKey &&
      current.slots.length == steps.length) {
    return current;
  }
  final created = _MobileQuickSolveSession(
    questKey: questKey,
    stepCount: steps.length,
  );
  sessions[index] = created;
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
  _MobileQuickSolveSession session, {
  int? problemIndex,
}) {
  final index = problemIndex ?? state._currentProblemIndex;
  final quest = index >= 0 && index < state._quests.length
      ? state._quests[index]
      : null;
  final data = quest?['data'];
  final options = data is Map ? data['quest_options'] : null;
  if (options is List && options.isNotEmpty) {
    return index < state._selectedChoices.length &&
        state._selectedChoices[index] != null;
  }
  return _isNumericQuickAnswer(session.numericAnswer);
}

void _placeMobileFlowNode(
  _BuildpageWidgetState state,
  _MobileQuickSolveSession session,
  int nodeIndex,
  int slotIndex,
) {
  if (state._analysisBusy ||
      slotIndex < 0 ||
      slotIndex >= session.slots.length ||
      nodeIndex < 0 ||
      nodeIndex >= session.slots.length)
    return;
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
  final practiceAttempt =
      session.practiceRetry &&
      session.firstCorrect != null &&
      !state._placementExam &&
      state._timeLimitSeconds == null &&
      !state._timeLimitReached;
  if (state._currentProblemIndex < state._problemGraded.length &&
      state._problemGraded[state._currentProblemIndex] &&
      !practiceAttempt) {
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
  final ratingSubmissionId = state._ratingSubmissionIdFor(
    state._currentProblemIndex,
    questId,
  );

  state.setState(() => state._analysisBusy = true);
  try {
    final options = state._currentQuestOptionBlocks();
    final selectedIndex = state._currentSelectedChoice();
    final submittedIndex = state._currentProblemIndex;
    final submittedQuest = state._currentQuest;
    final flowOrder = List<int>.unmodifiable(session.slots.whereType<int>());
    final result = await ApiClient.instance.gradeVariantSolve(
      questId: questId,
      selectedIndex: options.isNotEmpty ? selectedIndex : null,
      userAnswer: options.isEmpty ? session.numericAnswer.trim() : null,
      flowOrder: flowOrder,
      submissionId: state._ratingEnabled ? ratingSubmissionId : null,
    );
    if (!state.mounted ||
        state._currentProblemIndex != submittedIndex ||
        state._currentQuestId() != questId)
      return;
    final isCorrect = result['raw_correct'] == true || result['pass'] == true;
    final flowCorrect = result['flow_correct'] == true;
    final answerCorrect = result['answer_correct'] == true;
    // Server owns step verdicts; never infer O/X from the client's slots.
    final stepCorrectness = (result['step_correctness'] as List? ?? const [])
        .map((step) => Map<String, dynamic>.from(step as Map))
        .toList(growable: false);
    if (!practiceAttempt) {
      final quest = submittedQuest;
      final fingerprint = state._problemFingerprint(
        quest,
        state._currentProblemIndex,
      );
      final problemMeta = state._problemMeta(quest);
      await state.widget.config?.onProblemGraded?.call(
        itemIndex: state._currentProblemIndex + 1,
        quest: quest,
        isCorrect: isCorrect,
        stepCorrectness: stepCorrectness,
        selectedIndex: options.isNotEmpty ? selectedIndex : null,
        elapsedSeconds: state._sessionClock.elapsed.inSeconds,
      );
      if (!state.mounted ||
          state._currentProblemIndex != submittedIndex ||
          state._currentQuestId() != questId)
        return;
      state._problemGraded[submittedIndex] = true;
      session.firstCorrect = isCorrect;
      state._gradedCount += 1;
      if (isCorrect) state._correctCount += 1;
      if (state._ratingEnabled) {
        await state._submitRatingUpdate(
          quest: quest,
          isCorrect: isCorrect,
          stepCorrectness: stepCorrectness,
          gradeProof: (result['grade_proof'] ?? '').toString(),
          submissionId: ratingSubmissionId,
        );
      }
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
    }
    if (!state.mounted) return;
    final hasNext = state._currentProblemIndex < state._problemCount - 1;
    final canPractice =
        !isCorrect &&
        !state._placementExam &&
        state._timeLimitSeconds == null &&
        !state._timeLimitReached;
    final surface =
        session.htmlSurfaceKey.currentContext?.findRenderObject() as RenderBox?;
    final screen = MediaQuery.sizeOf(state.context);
    final bounds = surface == null
        ? Rect.fromLTWH(
            (screen.width - math.min(screen.width, 620)) / 2,
            0,
            math.min(screen.width, 620),
            screen.height,
          )
        : surface.localToGlobal(Offset.zero) & surface.size;
    await showGeneralDialog<void>(
      context: state.context,
      barrierDismissible: true,
      barrierLabel: '풀이 결과 닫기',
      barrierColor: Colors.transparent,
      pageBuilder: (context, _, __) => Stack(
        children: [
          Positioned.fromRect(
            rect: bounds,
            child: const ColoredBox(color: Color(0x7A09090B)),
          ),
          Positioned(
            left: bounds.left,
            width: bounds.width,
            bottom: screen.height - bounds.bottom,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: bounds.height),
              child: Material(
                key: const ValueKey('html-quick-result-sheet'),
                color: _htmlQuickPaper,
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 304),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        24,
                        20,
                        20 + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                color: _htmlQuickInk,
                                child: Text(
                                  isCorrect ? '✓' : '!',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isCorrect
                                          ? '좋아요, 모두 맞았어요'
                                          : '한 번 더 확인해 보세요',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -.8,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isCorrect
                                          ? '풀이 순서와 최종 답이 정확해요.'
                                          : canPractice
                                          ? '틀린 항목만 다시 고치면 돼요.'
                                          : '제출한 풀이의 결과를 확인해 주세요.',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _htmlQuickMuted,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: _htmlQuickLine),
                              ),
                            ),
                            child: Column(
                              children: [
                                _MobileQuickResultRow(
                                  label: '풀이 흐름',
                                  correct: flowCorrect,
                                ),
                                _MobileQuickResultRow(
                                  label: '최종 답',
                                  correct: answerCorrect,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              key: const ValueKey('html-quick-result-action'),
                              onPressed: () => Navigator.of(context).pop(),
                              style: FilledButton.styleFrom(
                                shape: const RoundedRectangleBorder(),
                                backgroundColor: _htmlQuickInk,
                                foregroundColor: Colors.white,
                                textStyle: TextStyle(
                                  fontFamily: Theme.of(
                                    state.context,
                                  ).textTheme.bodyMedium?.fontFamily,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    canPractice
                                        ? '다시 맞추기'
                                        : hasNext
                                        ? '다음 문제'
                                        : isCorrect
                                        ? '풀이 분석 보기'
                                        : '확인',
                                  ),
                                  if (!canPractice &&
                                      (hasNext || isCorrect)) ...[
                                    const SizedBox(width: 9),
                                    const Icon(Icons.arrow_forward, size: 18),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (!state.mounted) return;
    if (canPractice) {
      session.practiceRetry = true;
    } else if (hasNext) {
      state._goToNextProblem();
    } else if (isCorrect) {
      _completeMobileQuickModule(state);
      state.setState(() => state._analysisBusy = false);
      final selectedBlocks =
          options.isNotEmpty &&
              selectedIndex != null &&
              selectedIndex >= 0 &&
              selectedIndex < options.length
          ? options[selectedIndex]
          : null;
      final action = await Navigator.of(state.context)
          .push<SolveAnalysisAction>(
            MaterialPageRoute(
              builder: (_) => SolveAnalysisPage(
                userAnswer: selectedBlocks == null
                    ? session.numericAnswer.trim()
                    : contentBlocksToPlainText(selectedBlocks),
                quest: submittedQuest,
                stepCorrectness: stepCorrectness,
                isCorrect: isCorrect,
                hasNextProblem: false,
                problemIndex: submittedIndex + 1,
                problemCount: state._problemCount,
              ),
            ),
          );
      if (state.mounted && action == SolveAnalysisAction.exit)
        Navigator.of(state.context).maybePop();
      if (state.mounted && action == SolveAnalysisAction.retry) {
        if (session.firstCorrect != null &&
            state._timeLimitSeconds == null &&
            !state._timeLimitReached &&
            !state._placementExam) {
          session.practiceRetry = true;
        } else {
          ScaffoldMessenger.of(state.context).showSnackBar(
            const SnackBar(content: Text('시간제한 평가에서는 다시 제출할 수 없습니다.')),
          );
        }
      }
    }
    if (!canPractice) _completeMobileQuickModule(state);
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

Future<void> _saveMobileQuickSolveForBatch(_BuildpageWidgetState state) async {
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
  if (state._problemGraded[state._currentProblemIndex]) {
    ScaffoldMessenger.of(
      state.context,
    ).showSnackBar(const SnackBar(content: Text('이미 제출한 문제입니다.')));
    return;
  }

  state._saveCurrentProblem();
  if (state._currentProblemIndex < state._problemCount - 1) {
    state._goToNextProblem();
    return;
  }
  await state._handleBatchGrade();
}

// First-attempt totals stay authoritative; the result/analysis surface replaces
// the legacy completion popup, so completion must not stack a second dialog.
void _completeMobileQuickModule(_BuildpageWidgetState state) {
  if (state._completionReported ||
      state._passRate <= 0 ||
      state._gradedCount < state._problemCount)
    return;
  state._completionReported = true;
  state.widget.config?.onComplete?.call(
    correctCount: state._correctCount,
    totalCount: state._problemCount,
    passed:
        (state._correctCount / state._problemCount * 100).round() >=
        state._passRate,
    elapsedSeconds: state._sessionClock.elapsed.inSeconds,
  );
}

const _htmlQuickInk = Color(0xFF111113);
const _htmlQuickPaper = Color(0xFFFDFDFE);
const _htmlQuickLine = Color(0xFFDEDEE2);
const _htmlQuickMuted = Color(0xFF71717A);

/// 실제 문제·기존 quick session을 HTML 작업면에 연결한다. placement와 필기 renderer는 호출자가 분리한다.
Widget _renderHtmlQuickSolveScaffold(_BuildpageWidgetState state) {
  final session = _mobileQuickSessionFor(state);
  final ready =
      _mobileQuickFlowReady(session) && _mobileQuickAnswerReady(state, session);
  return Scaffold(
    backgroundColor: const Color(0xFFE7E7E9),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            key: session.htmlSurfaceKey,
            child: ColoredBox(
              key: const ValueKey('html-quick-solve-root'),
              color: const Color(0xFFF1F1F3),
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontFamily: 'Noto Sans KR',
                  color: _htmlQuickInk,
                  fontSize: 16,
                  letterSpacing: 0,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth <= 600;
                    return Stack(
                      children: [
                        Column(
                          children: [
                            _HtmlQuickSessionHeader(
                              state: state,
                              surfaceKey: session.htmlSurfaceKey,
                            ),
                            Expanded(
                              child: ListView(
                                key: const ValueKey('html-quick-scroll'),
                                padding: EdgeInsets.zero,
                                children: [
                                  _htmlQuickProblem(state, compact),
                                  _htmlQuickFlow(state, session, compact),
                                  _htmlQuickAnswer(state, session, compact),
                                ],
                              ),
                            ),
                            _htmlQuickFooter(state, ready, compact),
                          ],
                        ),
                        if (state._questLoading)
                          state._buildGenerationOverlay(),
                        if (!state._questLoading && state._hasPendingGeneration)
                          state._buildGenerationStatusBadge(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _HtmlQuickSessionHeader extends StatefulWidget {
  const _HtmlQuickSessionHeader({
    required this.state,
    required this.surfaceKey,
  });
  final _BuildpageWidgetState state;
  final GlobalKey surfaceKey;
  @override
  State<_HtmlQuickSessionHeader> createState() =>
      _HtmlQuickSessionHeaderState();
}

class _HtmlQuickSessionHeaderState extends State<_HtmlQuickSessionHeader> {
  final _hintFocus = FocusNode(debugLabel: 'Quick solve hint');
  @override
  void dispose() {
    _hintFocus.dispose();
    super.dispose();
  }

  Future<void> _showHint() async {
    final box =
        widget.surfaceKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final bounds = box.localToGlobal(Offset.zero) & box.size;
    final hints = widget.state._currentQuestHintBlocks();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '힌트 닫기',
      barrierColor: Colors.transparent,
      pageBuilder: (dialogContext, _, __) => Stack(
        children: [
          Positioned.fromRect(
            rect: bounds,
            child: GestureDetector(
              onTap: () => Navigator.of(dialogContext).pop(),
              child: const ColoredBox(color: Color(0x7A09090B)),
            ),
          ),
          Positioned(
            left: bounds.left,
            width: bounds.width,
            bottom: MediaQuery.sizeOf(dialogContext).height - bounds.bottom,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: bounds.height * .78),
              child: Material(
                key: const ValueKey('html-quick-hint-sheet'),
                color: _htmlQuickPaper,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          color: const Color(0xFFD4D4D8),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 50,
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '힌트',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.88,
                                ),
                              ),
                            ),
                            SizedBox.square(
                              dimension: 48,
                              child: IconButton(
                                tooltip: '닫기',
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                icon: const Icon(Icons.close, size: 19),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (hints.isEmpty)
                        const Text(
                          '이 문제에 등록된 힌트가 없습니다.',
                          style: TextStyle(
                            fontSize: 14,
                            color: _htmlQuickMuted,
                          ),
                        )
                      else
                        for (final blocks in hints)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: ContentBlocksView(
                              blocks: blocks,
                              textStyle: const TextStyle(
                                fontSize: 14,
                                height: 1.55,
                                color: _htmlQuickMuted,
                                letterSpacing: 0,
                              ),
                              latexStyle: const TextStyle(
                                fontSize: 14,
                                color: _htmlQuickMuted,
                              ),
                              inline: true,
                            ),
                          ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: FilledButton.styleFrom(
                            shape: const RoundedRectangleBorder(),
                            backgroundColor: _htmlQuickInk,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontFamily: 'Noto Sans KR',
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          child: const Text('다시 맞춰보기'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (mounted) _hintFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final tags = state._hashTags.isNotEmpty
        ? state._hashTags
        : ((state._currentQuest?['data'] as Map?)?['hash_tags'] as List? ??
                  const [])
              .whereType<String>()
              .toList();
    return Container(
      key: const ValueKey('html-quick-session-header'),
      height: 66,
      color: _htmlQuickPaper,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 48,
                  child: IconButton(
                    key: const ValueKey('html-quick-close'),
                    tooltip: '문제 풀이 나가기',
                    onPressed: state._analysisBusy
                        ? null
                        : () => Navigator.of(state.context).maybePop(),
                    icon: const Icon(Icons.close, size: 21),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${state._currentProblemIndex + 1} / ${state._problemCount}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tags.isEmpty ? '빠른 풀이' : '${tags.first} · 빠른 풀이',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _htmlQuickMuted,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 58,
                  height: 48,
                  child: TextButton(
                    key: const ValueKey('html-quick-hint'),
                    focusNode: _hintFocus,
                    onPressed: state._analysisBusy ? null : _showHint,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: _htmlQuickInk,
                      shape: const RoundedRectangleBorder(),
                      textStyle: const TextStyle(
                        fontFamily: 'Noto Sans KR',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    child: const Text('힌트'),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(
              value:
                  (state._currentProblemIndex + 1) /
                  math.max(1, state._problemCount),
              minHeight: 3,
              color: _htmlQuickInk,
              backgroundColor: const Color(0xFFE8E8EB),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _htmlQuickProblem(_BuildpageWidgetState state, bool compact) {
  final blocks = state._currentQuestTitleBlocks();
  final text = blocks.where((block) => !block.isLatex).toList();
  final formulas = blocks.where((block) => block.isLatex).toList();
  return Container(
    key: const ValueKey('html-quick-problem'),
    padding: EdgeInsets.fromLTRB(
      compact ? 16 : 18,
      compact ? 14 : 21,
      compact ? 16 : 18,
      compact ? 13 : 19,
    ),
    decoration: const BoxDecoration(
      color: _htmlQuickPaper,
      border: Border(bottom: BorderSide(color: _htmlQuickLine)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 26,
              alignment: Alignment.center,
              color: _htmlQuickInk,
              child: Text(
                (state._currentProblemIndex + 1).toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              state._currentQuestOptionBlocks().isEmpty ? '단답형' : '객관식',
              style: const TextStyle(
                fontSize: 11,
                color: _htmlQuickMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 8 : 12),
        if (state._questError != null)
          Text(
            state._questError!,
            style: const TextStyle(color: Color(0xFFA33434)),
          )
        else
          ContentBlocksView(
            blocks: text,
            textStyle: TextStyle(
              fontSize: compact ? 20 : 27,
              fontWeight: FontWeight.w700,
              height: 1.34,
              letterSpacing: compact ? -.9 : -1.215,
              color: _htmlQuickInk,
            ),
            inline: true,
          ),
        if (formulas.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: compact ? 10 : 15),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 15,
              vertical: compact ? 10 : 13,
            ),
            color: const Color(0xFFF0F0F2),
            child: ContentBlocksView(
              blocks: formulas,
              latexStyle: TextStyle(
                fontSize: compact ? 21 : 27,
                color: _htmlQuickInk,
              ),
              inline: true,
            ),
          ),
      ],
    ),
  );
}

Widget _htmlQuickFlow(
  _BuildpageWidgetState state,
  _MobileQuickSolveSession session,
  bool compact,
) {
  final steps = _mobileFlowStepsFor(state._currentQuest?['solves']);
  final unplaced = session.trayOrder
      .where((node) => !session.slots.contains(node))
      .toList();
  final next = session.slots.indexOf(null);
  final slots = <Widget>[
    for (var index = 0; index < session.slots.length; index++)
      if (!compact || session.slots[index] != null || index == next)
        Padding(
          padding: EdgeInsets.only(bottom: compact ? 7 : 10),
          child: _htmlQuickSlot(state, session, steps, index, compact),
        ),
  ];
  final tray = Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              next < 0 ? '배치 완료' : '${next + 1}번에 놓을 노드',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '${unplaced.length}개 남음',
            style: const TextStyle(fontSize: 11, color: _htmlQuickMuted),
          ),
        ],
      ),
      const SizedBox(height: 9),
      if (unplaced.isEmpty)
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          color: const Color(0xFFEEF6F1),
          alignment: Alignment.centerLeft,
          child: Text(
            steps.isEmpty ? '등록된 풀이 단계가 없습니다.' : '✓  모든 노드를 배치했어요.',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF2E7D57),
              fontWeight: FontWeight.w800,
            ),
          ),
        )
      else if (compact)
        Column(
          children: [
            for (final node in unplaced)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _htmlQuickNode(
                  state,
                  session,
                  steps,
                  node,
                  next,
                  compact,
                ),
              ),
          ],
        )
      else
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final node in unplaced)
                  Padding(
                    padding: const EdgeInsets.only(right: 9),
                    child: SizedBox(
                      width: 286,
                      child: _htmlQuickNode(
                        state,
                        session,
                        steps,
                        node,
                        next,
                        compact,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
    ],
  );
  return Container(
    key: const ValueKey('html-quick-flow-builder'),
    padding: EdgeInsets.fromLTRB(
      compact ? 11 : 14,
      compact ? 14 : 19,
      compact ? 11 : 14,
      compact ? 12 : 16,
    ),
    decoration: const BoxDecoration(
      color: _htmlQuickPaper,
      border: Border(bottom: BorderSide(color: _htmlQuickLine)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '풀이 순서',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: _htmlQuickMuted,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '풀 순서대로 눌러 주세요',
                    style: TextStyle(
                      fontSize: compact ? 18 : 20,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      letterSpacing: compact ? -.72 : -.8,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 64,
              height: 48,
              child: OutlinedButton(
                key: const ValueKey('html-quick-reset'),
                onPressed:
                    state._analysisBusy ||
                        session.slots.every((node) => node == null)
                    ? null
                    : () => state.setState(
                        () => session.slots.fillRange(
                          0,
                          session.slots.length,
                          null,
                        ),
                      ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const RoundedRectangleBorder(),
                  side: const BorderSide(color: _htmlQuickLine),
                  foregroundColor: _htmlQuickInk,
                  textStyle: const TextStyle(
                    fontFamily: 'Noto Sans KR',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                child: const Text('초기화'),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 11 : 15),
        if (compact) ...slots,
        Container(
          padding: EdgeInsets.only(
            top: compact ? 11 : 13,
            bottom: compact ? 0 : 14,
          ),
          decoration: BoxDecoration(
            border: Border(
              top: const BorderSide(color: _htmlQuickLine),
              bottom: compact
                  ? BorderSide.none
                  : const BorderSide(color: _htmlQuickLine),
            ),
          ),
          child: tray,
        ),
        if (!compact)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 3),
            child: Column(children: slots),
          ),
        Padding(
          padding: EdgeInsets.only(top: compact ? 10 : 12),
          child: const Text(
            '노드를 탭하면 다음 순서에 바로 들어가요.',
            style: TextStyle(fontSize: 10, color: _htmlQuickMuted),
          ),
        ),
      ],
    ),
  );
}

Widget _htmlQuickNode(
  _BuildpageWidgetState state,
  _MobileQuickSolveSession session,
  List<String> steps,
  int node,
  int next,
  bool compact,
) {
  void place() {
    final nextSlot = session.slots.indexOf(null);
    if (!state._analysisBusy && nextSlot >= 0)
      _placeMobileFlowNode(state, session, node, nextSlot);
  }

  Widget card() => Material(
    color: const Color(0xFFFAFAFA),
    shape: const RoundedRectangleBorder(
      side: BorderSide(color: Color(0xFFCFCFD4)),
    ),
    child: InkWell(
      onTap: state._analysisBusy ? null : place,
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 68 : 108),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 9 : 12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _mobileFlowNodeLabel(session.trayOrder, node),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: _htmlQuickMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    steps[node],
                    style: TextStyle(
                      fontSize: compact ? 12 : 13,
                      height: 1.42,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 5),
                    const Text(
                      '탭하거나 끌어서 배치',
                      style: TextStyle(fontSize: 9, color: Color(0xFF9999A1)),
                    ),
                  ],
                ],
              ),
            ),
            if (compact) ...[
              const SizedBox(width: 10),
              Container(
                width: 72,
                height: 48,
                alignment: Alignment.center,
                color: state._analysisBusy ? _htmlQuickMuted : _htmlQuickInk,
                child: Text(
                  '${next + 1}번에 놓기',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  return Semantics(
    button: true,
    label: _mobileFlowNodeLabel(session.trayOrder, node) + '. 다음 순서에 배치',
    child: LongPressDraggable<int>(
      key: ValueKey('html-quick-flow-node-$node'),
      data: node,
      maxSimultaneousDrags: state._analysisBusy ? 0 : 1,
      delay: const Duration(milliseconds: 220),
      feedback: SizedBox(width: 286, child: card()),
      childWhenDragging: Opacity(opacity: .4, child: card()),
      child: card(),
    ),
  );
}

Widget _htmlQuickSlot(
  _BuildpageWidgetState state,
  _MobileQuickSolveSession session,
  List<String> steps,
  int index,
  bool compact,
) {
  final node = session.slots[index];
  return DragTarget<int>(
    key: ValueKey('html-quick-flow-slot-$index'),
    onWillAcceptWithDetails: (details) =>
        !state._analysisBusy &&
        details.data >= 0 &&
        details.data < steps.length,
    onAcceptWithDetails: (details) {
      if (!state._analysisBusy)
        _placeMobileFlowNode(state, session, details.data, index);
    },
    builder: (_, candidates, __) => ConstrainedBox(
      constraints: BoxConstraints(minHeight: compact ? 58 : 76),
      child: Row(
        children: [
          Container(
            width: compact ? 34 : 36,
            height: compact ? 34 : 36,
            alignment: Alignment.center,
            color: _htmlQuickInk,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: _htmlQuickPlacedDrag(
              state,
              node,
              steps,
              CustomPaint(
                foregroundPainter: node == null
                    ? _HtmlQuickDashBorder(
                        candidates.isNotEmpty
                            ? const Color(0xFF2E7D57)
                            : const Color(0xFFC9C9CF),
                      )
                    : null,
                child: Container(
                  constraints: BoxConstraints(minHeight: compact ? 56 : 66),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: candidates.isNotEmpty
                        ? const Color(0xFFEEF6F1)
                        : node == null
                        ? const Color(0xFFF7F7F8)
                        : Colors.white,
                    border: node == null
                        ? null
                        : Border.all(color: const Color(0xFFC9C9CF)),
                  ),
                  child: node == null
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            index == session.slots.indexOf(null)
                                ? '다음 노드를 선택하세요'
                                : '앞 순서를 먼저 선택하세요',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF9999A1),
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _mobileFlowNodeLabel(
                                      session.trayOrder,
                                      node,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: _htmlQuickMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    steps[node],
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      height: 1.42,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 52,
                              height: 48,
                              child: TextButton(
                                key: ValueKey('html-quick-remove-$index'),
                                onPressed: state._analysisBusy
                                    ? null
                                    : () => state.setState(
                                        () => session.slots[index] = null,
                                      ),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor: _htmlQuickMuted,
                                  textStyle: const TextStyle(
                                    fontFamily: 'Noto Sans KR',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                child: const Text('빼기'),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 이미 배치된 실제 노드도 같은 0-based data로 다른 slot에 이동할 수 있다.
Widget _htmlQuickPlacedDrag(
  _BuildpageWidgetState state,
  int? node,
  List<String> steps,
  Widget child,
) {
  if (node == null) return child;
  return LongPressDraggable<int>(
    data: node,
    maxSimultaneousDrags: state._analysisBusy ? 0 : 1,
    delay: const Duration(milliseconds: 220),
    feedback: SizedBox(
      width: 286,
      child: Material(
        color: _htmlQuickPaper,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            steps[node],
            style: const TextStyle(fontSize: 13, color: _htmlQuickInk),
          ),
        ),
      ),
    ),
    childWhenDragging: Opacity(opacity: .4, child: child),
    child: child,
  );
}

class _HtmlQuickDashBorder extends CustomPainter {
  const _HtmlQuickDashBorder(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(.5, .5, size.width - 1, size.height - 1));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      for (var position = 0.0; position < metric.length; position += 5) {
        canvas.drawPath(
          metric.extractPath(position, math.min(position + 3, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HtmlQuickDashBorder oldDelegate) =>
      oldDelegate.color != color;
}

Widget _htmlQuickAnswer(
  _BuildpageWidgetState state,
  _MobileQuickSolveSession session,
  bool compact,
) {
  final options = state._currentQuestOptionBlocks();
  final selected = state._currentSelectedChoice();
  final label = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        '최종 답',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
      ),
      Text(
        options.isEmpty ? '숫자로 입력하세요' : '보기를 선택하세요',
        style: const TextStyle(fontSize: 10, color: _htmlQuickMuted),
      ),
    ],
  );
  final answer = options.isNotEmpty
      ? Column(
          children: [
            for (var index = 0; index < options.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: ValueKey('html-quick-choice-$index'),
                    onPressed: state._analysisBusy
                        ? null
                        : () => state._toggleChoice(index),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: const RoundedRectangleBorder(),
                      side: BorderSide(
                        color: selected == index
                            ? _htmlQuickInk
                            : _htmlQuickLine,
                      ),
                      backgroundColor: selected == index
                          ? const Color(0xFFE8E8EB)
                          : _htmlQuickPaper,
                      foregroundColor: _htmlQuickInk,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ContentBlocksView(
                            blocks: options[index],
                            textStyle: const TextStyle(fontSize: 16),
                            latexStyle: const TextStyle(fontSize: 16),
                            inline: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        )
      : TextFormField(
          key: ValueKey(
            'mobile-quick-numeric-answer-${state._currentProblemIndex}',
          ),
          initialValue: session.numericAnswer,
          enabled: !state._analysisBusy,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          textInputAction: TextInputAction.done,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: (value) {
            if (!state._analysisBusy) {
              session.numericAnswer = value;
              state.setState(() {});
            }
          },
          validator: (value) =>
              value?.trim().isEmpty != false || _isNumericQuickAnswer(value!)
              ? null
              : '숫자만 입력해 주세요.',
          decoration: InputDecoration(
            hintText: '예: 2',
            filled: true,
            fillColor: const Color(0xFFF7F7F8),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: _htmlQuickLine),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: _htmlQuickLine),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: _htmlQuickInk),
            ),
            suffixIcon: _isNumericQuickAnswer(session.numericAnswer)
                ? const Tooltip(
                    message: '숫자 형식 확인',
                    child: Icon(
                      Icons.check,
                      color: Color(0xFF2E7D57),
                      size: 17,
                    ),
                  )
                : null,
          ),
        );
  return Container(
    key: const ValueKey('html-quick-answer'),
    color: _htmlQuickPaper,
    padding: EdgeInsets.all(compact ? 15 : 18),
    child: compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '최종 답',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    options.isEmpty ? '숫자로 입력하세요' : '보기를 선택하세요',
                    style: const TextStyle(
                      fontSize: 10,
                      color: _htmlQuickMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              answer,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 32, child: label),
              const SizedBox(width: 12),
              Expanded(flex: 68, child: answer),
            ],
          ),
  );
}

Widget _htmlQuickFooter(_BuildpageWidgetState state, bool ready, bool compact) {
  final disabled = state._analysisBusy || state._hasPendingGeneration || !ready;
  final batchMode = !state._gradeImmediately;
  final lastQuestion = state._currentProblemIndex >= state._problemCount - 1;
  final submitAction = batchMode
      ? () => _saveMobileQuickSolveForBatch(state)
      : () => _submitMobileQuickSolve(state);
  final submitLabel = batchMode
      ? lastQuestion
            ? '전체 채점'
            : '답안 저장 · 다음'
      : '풀이 제출';
  final copy = Text(
    state._analysisBusy
        ? (batchMode ? '답안을 채점하고 있어요' : '풀이를 확인하고 있어요')
        : batchMode
        ? ready
              ? (lastQuestion
                    ? '모든 답안을 저장한 뒤 전체 채점해요'
                    : '현재 답안을 저장하고 다음 문제로 이동해요')
              : 'Flow와 최종 답을 완성해 주세요'
        : ready
        ? 'Flow와 최종 답이 준비됐어요'
        : 'Flow와 최종 답을 완성해 주세요',
    textAlign: compact ? TextAlign.center : TextAlign.left,
    style: const TextStyle(fontSize: 11, color: _htmlQuickMuted, height: 1.35),
  );
  final submit = SizedBox(
    height: compact ? 48 : 52,
    child: FilledButton(
      key: ValueKey(batchMode ? 'batch-grade-submit' : 'html-quick-submit'),
      onPressed: disabled ? null : submitAction,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: const RoundedRectangleBorder(),
        backgroundColor: _htmlQuickInk,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFE4E4E7),
        disabledForegroundColor: const Color(0xFF909098),
        textStyle: const TextStyle(
          fontFamily: 'Noto Sans KR',
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(submitLabel),
          const SizedBox(width: 9),
          Icon(
            batchMode ? Icons.fact_check_outlined : Icons.arrow_forward,
            size: 18,
          ),
        ],
      ),
    ),
  );
  return Container(
    key: const ValueKey('html-quick-footer'),
    constraints: BoxConstraints(minHeight: compact ? 82 : 80),
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 12 : 14,
      vertical: compact ? 7 : 10,
    ),
    decoration: const BoxDecoration(
      color: _htmlQuickPaper,
      border: Border(top: BorderSide(color: _htmlQuickLine)),
      boxShadow: [
        BoxShadow(
          color: Color(0x0D111113),
          blurRadius: 24,
          offset: Offset(0, -8),
        ),
      ],
    ),
    child: compact
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [copy, const SizedBox(height: 5), submit],
          )
        : Row(
            children: [
              Expanded(flex: 52, child: copy),
              const SizedBox(width: 12),
              Expanded(flex: 48, child: submit),
            ],
          ),
  );
}

/// 필요한 변수는 현재 문제 카드, 세로 필기판, 하단 도구 모음이다.
/// 작동 원리는 모바일에서 PC용 오버레이 캔버스를 제거하고 문제와 필기판을 세로 순서로 분리하는 것이다.
Widget _renderMobileSolveScaffold(_BuildpageWidgetState state) {
  final progress =
      (state._currentProblemIndex + 1) / math.max(1, state._problemCount);
  final hasOptions = state._currentQuestOptionBlocks().isNotEmpty;
  final showWritingSurface = !state._mobileQuickSolve;
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
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PROBLEM SESSION',
                                    style: TextStyle(
                                      color: Colors.black45,
                                      fontSize: 8,
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    '문제 풀이',
                                    style: TextStyle(
                                      fontSize: 19,
                                      letterSpacing: -.6,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
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
                            const Text(
                              'SAVED',
                              style: TextStyle(
                                color: Colors.black45,
                                fontSize: 8,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w900,
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
  final showWritingTools = !state._mobileQuickSolve;
  final canSubmit = options.isNotEmpty
      ? state._currentSelectedChoice() != null
      : state._strokes.isNotEmpty || state._currentStroke != null;
  final quickReady =
      _mobileQuickFlowReady(quickSession) &&
      _mobileQuickAnswerReady(state, quickSession);
  final submit = state._mobileQuickSolve
      ? state._gradeImmediately
            ? () => _submitMobileQuickSolve(state)
            : () => _saveMobileQuickSolveForBatch(state)
      : state._gradeImmediately
      ? state._handleGrade
      : state._handleBatchGrade;
  final quickBatchLast =
      state._mobileQuickSolve &&
      !state._gradeImmediately &&
      state._currentProblemIndex >= state._problemCount - 1;
  final submitLabel = state._mobileQuickSolve
      ? state._gradeImmediately
            ? '풀이 제출'
            : quickBatchLast
            ? '전체 채점'
            : '답안 저장'
      : state._gradeImmediately
      ? '제출'
      : state._analysisBusy
      ? '채점 ${state._batchGradeProgress}/${state._problemCount}'
      : '전체 채점';
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
              child: Tooltip(
                message: state._gradeImmediately ? '제출' : '전체 채점',
                child: FilledButton.icon(
                  key: state._gradeImmediately
                      ? const ValueKey('solve-submit')
                      : const ValueKey('batch-grade-submit'),
                  onPressed:
                      state._analysisBusy ||
                          state._hasPendingGeneration ||
                          (state._mobileQuickSolve
                              ? !quickReady
                              : state._gradeImmediately && !canSubmit)
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
                  icon: Icon(
                    state._gradeImmediately
                        ? Icons.check_rounded
                        : Icons.fact_check_outlined,
                    size: 19,
                  ),
                  label: Text(
                    submitLabel,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
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
          const Text(
            '오늘의 문제',
            style: TextStyle(
              color: Colors.black45,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
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
Widget _renderMobileWritingSurface(
  _BuildpageWidgetState state, {
  bool interactive = true,
  bool allowCollapse = true,
}) {
  final canCollapse =
      allowCollapse && state._currentQuestOptionBlocks().isNotEmpty;
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
              Text(
                state._placementExam ? '필기 영역' : '풀이 노트',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
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
              else if (!state._placementExam)
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
                        child: IgnorePointer(
                          ignoring: !interactive,
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
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: SizedBox(
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
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 50),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: _htmlQuickLine)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 24,
          child: Text(
            correct ? '✓' : '×',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              color: correct
                  ? const Color(0xFF2E7D57)
                  : const Color(0xFFA33434),
            ),
          ),
        ),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        Text(
          correct ? '정답' : '다시 확인',
          style: TextStyle(
            color: correct ? const Color(0xFF2E7D57) : const Color(0xFFA33434),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    ),
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
