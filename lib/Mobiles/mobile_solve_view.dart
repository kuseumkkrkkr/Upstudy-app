part of 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';

extension _MobileSolveStateView on _BuildpageWidgetState {
  /// 모바일 전용 문제풀이 진입점과 카드·필기판을 현재 상태에 연결한다.
  Widget _buildMobileSolveScaffold() => _renderMobileSolveScaffold(this);

  Widget _buildMobileProblemCard() => _renderMobileProblemCard(this);

  Widget _buildMobileWritingSurface() => _renderMobileWritingSurface(this);

  Widget _buildMobileQuickSolveCard() => _renderMobileQuickSolveCard(this);

  Widget _buildMobileQuickAnswerCard() => _renderMobileQuickAnswerCard(this);
}

/// 필요한 변수는 현재 문제 카드, 세로 필기판, 하단 도구 모음이다.
/// 작동 원리는 모바일에서 PC용 오버레이 캔버스를 제거하고 문제와 필기판을 세로 순서로 분리하는 것이다.
Widget _renderMobileSolveScaffold(_BuildpageWidgetState state) {
  final title = state._hashTags.isEmpty
      ? '오늘의 문제'
      : state._hashTags.first.replaceFirst('#', '');
  return GestureDetector(
    onTap: () => FocusScope.of(state.context).unfocus(),
    child: Scaffold(
      backgroundColor: const Color(0xFFF6F6F4),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        titleSpacing: 8,
        leading: IconButton(
          tooltip: '문제 풀이 나가기',
          onPressed: () => Navigator.of(state.context).maybePop(),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: '문제풀이 안내',
            onPressed: state._showSolveInfo,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value:
                (state._currentProblemIndex + 1) /
                math.max(1, state._problemCount),
            minHeight: 4,
            color: Colors.black,
            backgroundColor: const Color(0xFFE4E4E2),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                children: [
                  state._buildMobileProblemCard(),
                  const SizedBox(height: 14),
                  if (state._mobileQuickSolve) ...[
                    state._buildMobileQuickAnswerCard(),
                    const SizedBox(height: 14),
                    state._buildMobileQuickSolveCard(),
                  ] else
                    state._buildMobileWritingSurface(),
                ],
              ),
            ),
            if (!state._mobileQuickSolve) state._buildToolbar(),
          ],
        ),
      ),
      floatingActionButton: state._hasPendingGeneration
          ? null
          : FloatingActionButton.extended(
              onPressed:
                  state._mobileQuickSolve &&
                      _mobileFlowStepsFor(
                        state._currentQuest?['solves'],
                      ).isNotEmpty
                  ? state._handleMobileQuickSolve
                  : state._handleGrade,
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              label: Text(state._mobileQuickSolve ? '정답 확인' : '제출'),
              icon: const Icon(Icons.check_rounded),
            ),
    ),
  );
}

/// 필요한 변수는 현재 선택한 객관식 답과 간편풀이 모드다.
/// 작동 원리는 필기판·도구 모음을 완전히 제외하고 답 선택과 즉시 채점만 남겨 일반 풀이와
/// 같은 화면으로 보이지 않게 하는 것이다.
Widget _renderMobileQuickAnswerCard(_BuildpageWidgetState state) {
  final selected = state._currentSelectedChoice();
  return DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF171717),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: Color(0xFFFFD54F), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '간편풀이 모드',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selected == null
                      ? '답을 선택한 뒤 정답 확인을 눌러주세요.'
                      : '${selected + 1}번을 선택했습니다. 바로 채점할 수 있어요.',
                  style: const TextStyle(color: Colors.white70, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// 필요한 변수는 현재 문제의 본문과 선택지다.
/// 작동 원리는 모바일에서 작은 메타 정보와 중복 헤더를 줄이고 본문·선택지를 읽기 순서대로 배치하는 것이다.
Widget _renderMobileProblemCard(_BuildpageWidgetState state) {
  final blocks = state._currentQuestTitleBlocks();
  final options = state._currentQuestOptionBlocks();
  return Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '문제 ${state._currentProblemIndex + 1}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          state._buildProblemPrompt(displayBlocks: blocks),
          if (options.isNotEmpty) ...[
            const SizedBox(height: 18),
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

/// 필요한 변수는 필기 획과 모바일 viewport다.
/// 작동 원리는 필기 영역을 문제 카드와 분리하고 항상 세로 스크롤을 허용해 긴 풀이 중간의 입력 단절 구간을 없애는 것이다.
Widget _renderMobileWritingSurface(_BuildpageWidgetState state) {
  return SizedBox(
    height: 520,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: Colors.white)),
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) => state._handlePointerDown(event, 1),
              onPointerMove: (event) => state._handlePointerMove(event, 1),
              onPointerUp: state._handlePointerUp,
              onPointerCancel: state._handlePointerCancel,
              child: ValueListenableBuilder<int>(
                valueListenable: state._paintVersion,
                builder: (context, _, __) => CustomPaint(
                  painter: _StrokePainter(
                    strokes: state._strokes,
                    currentStroke: state._currentStroke,
                    eraserPosition: state._eraserActive
                        ? state._eraserPosition
                        : null,
                    eraserRadius: _BuildpageWidgetState._eraserRadius,
                    scale: 1,
                    logicalSize: const Size(
                      _BuildpageWidgetState._baseWidth,
                      520,
                    ),
                    backgroundColor: Colors.transparent,
                    repaint: state._paintVersion,
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: _NotebookPaperPainter(
                lineStartY: _BuildpageWidgetState._noteLineStartY,
                lineSpacing: _BuildpageWidgetState._noteLineSpacing,
                leftMargin: _BuildpageWidgetState._noteLeftMargin,
              ),
              size: Size.infinite,
            ),
          ),
          const Positioned(
            left: 18,
            top: 14,
            child: Text(
              '여기에 풀이를 적어보세요',
              style: TextStyle(color: Colors.black38),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 필요한 변수는 문제의 flow 데이터다.
/// 작동 원리는 모바일 간편풀이를 켠 경우 정답 흐름을 읽기 쉬운 세로 카드로 보여 주어 필기 없이 순서를 확인하게 하는 것이다.
Widget _renderMobileQuickSolveCard(_BuildpageWidgetState state) {
  final steps = _mobileFlowStepsFor(state._currentQuest?['solves']);
  if (steps.isEmpty) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '이 문제는 답을 고른 뒤 바로 채점합니다. 필기판과 도구 모음은 표시하지 않습니다.',
        style: TextStyle(color: Colors.black54, height: 1.4),
      ),
    );
  }
  return Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: const Color(0xFF202022),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '간편풀이 · 풀이 흐름',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '필기 대신 아래 순서로 풀이 흐름을 확인하세요.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => state._selectMobileFlowStep(i),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: i < state._mobileFlowNextIndex
                        ? const Color(0xFFB9F5D0)
                        : Colors.white.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.white,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          steps[i],
                          style: TextStyle(
                            color: i < state._mobileFlowNextIndex
                                ? Colors.black
                                : Colors.white,
                            fontSize: 15,
                            height: 1.35,
                          ),
                        ),
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
      final flow = current['flow']?.toString().trim() ?? '';
      if (flow.isNotEmpty) steps.add(flow);
      collect(current['branches']);
    }
  }

  collect(value);
  return steps;
}
