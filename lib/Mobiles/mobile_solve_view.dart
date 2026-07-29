part of 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';

extension _MobileSolveStateView on _BuildpageWidgetState {
  /// 모바일 전용 문제풀이 진입점과 카드·필기판을 현재 상태에 연결한다.
  Widget _buildMobileSolveScaffold() => _renderMobileSolveScaffold(this);

  Widget _buildMobileProblemCard() => _renderMobileProblemCard(this);

  Widget _buildMobileWritingSurface() => _renderMobileWritingSurface(this);

  Widget _buildMobileToolbar() => _renderMobileToolbar(this);

  Widget _buildMobileQuickSolveCard() => _renderMobileQuickSolveCard(this);

  Widget _buildMobileQuickAnswerCard() => _renderMobileQuickAnswerCard(this);
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
                        state._buildMobileQuickAnswerCard(),
                        const SizedBox(height: 12),
                        state._buildMobileQuickSolveCard(),
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
  final showWritingTools =
      !state._mobileQuickSolve &&
      (options.isEmpty || state._mobileNoteExpanded);
  final canSubmit = options.isNotEmpty
      ? state._currentSelectedChoice() != null
      : state._strokes.isNotEmpty || state._currentStroke != null;
  final quickSteps = _mobileFlowStepsFor(state._currentQuest?['solves']);
  final submit = state._mobileQuickSolve && quickSteps.isNotEmpty
      ? state._handleMobileQuickSolve
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
                        (!state._mobileQuickSolve && !canSubmit)
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
                  state._mobileQuickSolve ? '정답 확인' : '제출',
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
          if (options.isNotEmpty) ...[
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
