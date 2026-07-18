import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:s11/shared/data/models/content_block.dart';
import 'package:s11/shared/business/repositories/problem_bookmark_store.dart';
import 'package:s11/shared/ui/components/content_blocks_view.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/data/models/concept_textbooks.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/server_chat_page.dart';
import 'package:s11/shared/services/api/api_client.dart';

class FlowViewPage extends StatefulWidget {
  final Map<String, dynamic> quest;
  final String title;
  final List<Map<String, dynamic>>? stepCorrectness;
  final bool sharedMode;
  final SharedMeta? sharedMeta;

  const FlowViewPage({
    super.key,
    required this.quest,
    this.title = 'Flow Editor',
    this.stepCorrectness,
    this.sharedMode = false,
    this.sharedMeta,
  });

  @override
  State<FlowViewPage> createState() => _FlowViewPageState();
}

class SharedMeta {
  final String shareId;
  final String userId;
  final String createdAt;
  final List<String> tags;
  final int? difficulty;
  final bool canDelete;

  const SharedMeta({
    required this.shareId,
    required this.userId,
    required this.createdAt,
    required this.tags,
    required this.difficulty,
    required this.canDelete,
  });
}

class _FlowViewPageState extends State<FlowViewPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final _FlowGraph _graph;
  _FlowNode? _selected;
  late final Map<String, _FlowNodeState> _nodeStates;
  late final bool _allStepsCorrect;
  bool _chatActive = false;
  bool _showSharedAnalysis = false;
  bool _formulaModalVisible = false;
  bool _fullScreen = false;
  Offset _formulaModalOffset = const Offset(24, 120);

  Future<void> _bookmarkProblem() async {
    final questData = widget.quest['data'] as Map<String, dynamic>? ?? {};
    final title = _blocksToPlainText(
      parseContentBlocks(questData['quest_title']),
    );
    final item = ProblemBookmarkItem(
      id: 'pb_${DateTime.now().microsecondsSinceEpoch}',
      title: title.isEmpty ? '제목 없는 문제' : title,
      source: widget.title,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      questId: questData['quest_id']?.toString(),
      codebaseId: (questData['codebase_id'] as num?)?.toInt(),
      seed: (questData['seed'] as num?)?.toInt(),
      flowStepCount: _graph.nodes.length,
    );
    final snapshot = await ProblemBookmarkStore.add(item);
    if (!mounted) return;
    final isOverflow =
        snapshot.serverItems.length >= ProblemBookmarkStore.maxServerBookmarks;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isOverflow ? '문제 북마크(로컬)에 저장했습니다.' : '문제 북마크에 저장했습니다.'),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _graph = _FlowGraphBuilder().build(widget.quest['solves']);
    _nodeStates = _buildNodeStates(widget.stepCorrectness);
    _allStepsCorrect = _areAllStepsCorrect(widget.stepCorrectness);
    if (widget.sharedMode) {
      _chatActive = false;
    }
  }

  /// 필요한 변수는 전체화면 상태와 시스템 UI 설정이다.
  /// 작동 원리는 Flow에 집중할 때만 상단 시스템 영역을 숨기고, 종료 즉시 기본 화면 상태로 복구하는 것이다.
  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// 필요한 변수는 전체화면 여부다.
  /// 작동 원리는 일반 화면의 양쪽 상세 패널을 축약 도구로 바꾸고 캔버스에 가능한 넓은 폭을 제공하는 것이다.
  Future<void> _toggleFullScreen() async {
    final next = !_fullScreen;
    await SystemChrome.setEnabledSystemUIMode(
      next ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    if (mounted) setState(() => _fullScreen = next);
  }

  /// 필요한 변수는 현재 Navigator의 이전 화면 유무와 전체화면 상태다.
  /// 작동 원리는 제출 직후 진입한 Flow에서 이전 풀이 화면으로 즉시 돌아가고, 직접 진입한 경우에는 학생 홈으로 안전하게 빠져나가게 하는 것이다.
  Future<void> _returnToPreviousPage() async {
    if (_fullScreen) await _toggleFullScreen();
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed('/student/dashboard');
  }

  void _shareToGroupStudy() async {
    final groups = await _pickGroups();
    if (groups.isEmpty) return;
    final questData = widget.quest['data'] as Map<String, dynamic>? ?? {};
    final codebaseId = questData['codebase_id'] as int? ?? 0;
    final seed = questData['seed'] is int
        ? questData['seed'] as int
        : int.tryParse(questData['seed']?.toString() ?? '') ?? 0;
    final questId = questData['quest_id']?.toString();
    final questTitle = _blocksToPlainText(
      parseContentBlocks(questData['quest_title']),
    );
    final statusJson = _buildStatusJson(questData);
    final allFormulas = questData['all_formulas']?.toString() ?? '';
    final answerRiddle = _blocksToPlainText(
      parseContentBlocks(questData['answer_riddle']),
    );
    final rawTags = questData['hash_tag'];
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString()).toList()
        : <String>[];
    final difficulty = questData['difficulty'] is int
        ? questData['difficulty'] as int
        : null;

    for (final group in groups) {
      await ApiClient.instance.shareFlowToGroup(
        groupId: group['group_id']!,
        codebaseId: codebaseId,
        seed: seed,
        questId: questId ?? '',
        questTitle: questTitle,
        statusJson: statusJson,
        allFormulas: allFormulas,
        answerRiddle: answerRiddle,
        tags: tags,
        difficulty: difficulty,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('그룹 ${groups.length}곳에 공유했습니다.')));
  }

  Future<List<Map<String, String>>> _pickGroups() async {
    final groups = await ApiClient.instance.listMyStudyGroups();
    if (!mounted) return [];
    return showModalBottomSheet<List<Map<String, String>>>(
      context: context,
      builder: (ctx) {
        final selected = <String>{};
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        '공유할 그룹 선택',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    SizedBox(
                      height: 360,
                      child: ListView(
                        children: groups
                            .map(
                              (g) => CheckboxListTile(
                                title: Text(g.name),
                                subtitle: Text(g.description ?? ''),
                                value: selected.contains(g.groupId),
                                onChanged: (v) => setState(() {
                                  if (v == true) {
                                    selected.add(g.groupId);
                                  } else {
                                    selected.remove(g.groupId);
                                  }
                                }),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(
                          groups
                              .where((g) => selected.contains(g.groupId))
                              .map(
                                (g) => {'group_id': g.groupId, 'name': g.name},
                              )
                              .toList(),
                        ),
                        child: const Text('공유'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((value) => value ?? []);
  }

  @override
  Widget build(BuildContext context) {
    final questData = widget.quest['data'] as Map<String, dynamic>? ?? {};
    final questTitleBlocks = parseContentBlocks(questData['quest_title']);
    final questAnswerBlocks = parseContentBlocks(questData['quest_answer']);
    final questAnswerRiddle = parseContentBlocks(questData['answer_riddle']);
    final allFormulas = questData['all_formulas'];
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: StudentDensityTokens.background,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Stack(
          children: [
            _fullScreen
                ? _buildFocusWorkspace(
                    questTitleBlocks,
                    questAnswerBlocks,
                    questAnswerRiddle,
                  )
                : Column(
                    children: [
                      _buildFlowChrome(),
                      Expanded(
                        child: _buildFlowWorkspace(
                          questTitleBlocks,
                          questAnswerBlocks,
                          questAnswerRiddle,
                        ),
                      ),
                    ],
                  ),
            if (widget.sharedMode && _formulaModalVisible)
              Positioned(
                left: _formulaModalOffset.dx,
                top: _formulaModalOffset.dy,
                child: Draggable(
                  feedback: _FormulaModal(
                    allFormulas: allFormulas?.toString() ?? '',
                    onClose: _toggleFormulaModal,
                    isPreview: true,
                  ),
                  childWhenDragging: const SizedBox.shrink(),
                  onDraggableCanceled: (_, offset) =>
                      setState(() => _formulaModalOffset = offset),
                  child: _FormulaModal(
                    allFormulas: allFormulas?.toString() ?? '',
                    onClose: _toggleFormulaModal,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 필요한 변수는 문제·정답 블록과 현재 화면 폭이다.
  /// 작동 원리는 세로 길이는 페이지 스크롤에 맡기고, 카드형 좌우 정보는 긴 Flow를 읽는 동안 같은 문맥으로 따라오게 배치하는 것이다.
  Widget _buildFlowWorkspace(
    List<ContentBlock> questTitleBlocks,
    List<ContentBlock> questAnswerBlocks,
    List<ContentBlock> questAnswerRiddle,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1040;
        if (isWide) {
          return _buildStickyDesktopWorkspace(
            questTitleBlocks,
            questAnswerBlocks,
            questAnswerRiddle,
          );
        }
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: studentDensityHorizontalPadding(context),
            vertical: 18,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: StudentDensityTokens.desktopMaxWidth,
              ),
              child: Column(
                children: [
                  _buildCanvasPanel(),
                  const SizedBox(height: 14),
                  _buildLeftPanel(
                    questTitleBlocks,
                    questAnswerBlocks,
                    questAnswerRiddle,
                  ),
                  const SizedBox(height: 14),
                  _buildDetailPanel(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 필요한 변수는 좌우 패널의 문제·정답 블록과 화면 크기다.
  /// 작동 원리는 중앙 Flow만 세로로 스크롤하고 좌우 패널은 고정해, 긴 풀이를 읽을 때도 문제와 선택 노드의 값이 화면을 따라오게 하는 것이다.
  Widget _buildStickyDesktopWorkspace(
    List<ContentBlock> questTitleBlocks,
    List<ContentBlock> questAnswerBlocks,
    List<ContentBlock> questAnswerRiddle,
  ) {
    final leftWidth = _chatActive ? 300.0 : 272.0;
    final rightWidth = _chatActive ? 300.0 : 316.0;
    const gap = 16.0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: StudentDensityTokens.desktopMaxWidth,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  leftWidth + gap,
                  18,
                  rightWidth + gap,
                  18,
                ),
                child: _buildCanvasPanel(),
              ),
            ),
            Positioned(
              left: 0,
              top: 18,
              bottom: 18,
              width: leftWidth,
              child: SingleChildScrollView(
                child: _buildLeftPanel(
                  questTitleBlocks,
                  questAnswerBlocks,
                  questAnswerRiddle,
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 18,
              bottom: 18,
              width: rightWidth,
              child: SingleChildScrollView(child: _buildDetailPanel()),
            ),
          ],
        ),
      ),
    );
  }

  /// 필요한 변수는 문제·정답 정보와 선택 노드다.
  /// 작동 원리는 전체화면에서는 Flow만 넓게 표시하고, 양쪽 정보는 여닫는 축약 컨테이너로 전환하는 것이다.
  Widget _buildFocusWorkspace(
    List<ContentBlock> questTitleBlocks,
    List<ContentBlock> questAnswerBlocks,
    List<ContentBlock> questAnswerRiddle,
  ) => Stack(
    children: [
      Positioned.fill(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: _buildCanvasPanel(fullScreen: true),
        ),
      ),
      Positioned(
        top: 20,
        left: 20,
        child: _buildCompactPanelButton(
          label: '문제 정보',
          icon: Icons.menu_book_outlined,
          onPressed: () => _showFocusPanel(
            _buildLeftPanel(
              questTitleBlocks,
              questAnswerBlocks,
              questAnswerRiddle,
            ),
          ),
        ),
      ),
      Positioned(
        top: 20,
        right: 20,
        child: _buildCompactPanelButton(
          label: _selected == null ? '노드 상세' : '선택한 노드',
          icon: Icons.account_tree_outlined,
          onPressed: () => _showFocusPanel(_buildDetailPanel()),
        ),
      ),
    ],
  );

  /// 필요한 변수는 축약 컨테이너의 라벨·아이콘·열기 콜백이다.
  /// 작동 원리는 전체화면의 보조 정보를 작은 반투명 도구로 남겨 Flow 읽기 폭을 보존하는 것이다.
  Widget _buildCompactPanelButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) => Material(
    color: Colors.white.withValues(alpha: .94),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    ),
  );

  /// 필요한 변수는 전체화면에서 열 보조 패널이다.
  /// 작동 원리는 축약 컨테이너를 탭하면 하단 시트로 원래 문제·노드 상세 기능을 그대로 제공하는 것이다.
  void _showFocusPanel(Widget panel) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: .55,
        minChildSize: .3,
        maxChildSize: .9,
        builder: (context, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(14),
          child: panel,
        ),
      ),
    );
  }

  /// 필요한 변수는 공유 모드·공유/북마크 콜백과 현재 Navigator다.
  /// 작동 원리는 학생 화면의 공통 여백·제목·캡슐 버튼 규칙으로 Flow의 진입부를 구성하는 것이다.
  Widget _buildFlowChrome() {
    return Column(
      children: [
        Ios26TopBar(
          brandColor: Colors.black,
          showLevelIndicator: false,
          onBack: _returnToPreviousPage,
          items: const [],
        ),
        Container(
          width: double.infinity,
          color: StudentDensityTokens.background,
          child: StudentDensityPage(
            padding: EdgeInsets.fromLTRB(
              studentDensityHorizontalPadding(context),
              24,
              studentDensityHorizontalPadding(context),
              18,
            ),
            child: StudentDensityPageHeader(
              eyebrow: 'Solution flow',
              title: '풀이 흐름 분석',
              description: '내 풀이의 흐름을 따라가며 놓친 단계와 다음 학습 포인트를 확인하세요.',
              action: _buildFlowActions(),
            ),
          ),
        ),
      ],
    );
  }

  /// 필요한 변수는 공유 여부와 각 행동 콜백이다.
  /// 작동 원리는 공통 학생 버튼을 사용해 보조 행동과 핵심 행동의 우선순위를 일관되게 표시하는 것이다.
  Widget _buildFlowActions() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 310),
      child: Row(
        children: [
          Expanded(
            child: StudentDensityButton(
              label: widget.sharedMode ? '공식 정보' : '그룹 공유',
              icon: widget.sharedMode
                  ? Icons.functions
                  : Icons.ios_share_outlined,
              onPressed: widget.sharedMode
                  ? _toggleFormulaModal
                  : _shareToGroupStudy,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StudentDensityButton(
              label: '북마크',
              icon: Icons.bookmark_add_outlined,
              primary: true,
              onPressed: _bookmarkProblem,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPanel(
    List<ContentBlock> questTitleBlocks,
    List<ContentBlock> questAnswerBlocks,
    List<ContentBlock> questAnswerRiddle,
  ) {
    final titleBlocks = questTitleBlocks.isEmpty
        ? [const ContentBlock(type: 'text', content: '제목 없음')]
        : questTitleBlocks;
    final answerBlocks = questAnswerBlocks.isEmpty
        ? [const ContentBlock(type: 'text', content: '-')]
        : questAnswerBlocks;
    final showAnswer = _allStepsCorrect;
    final questData = widget.quest['data'] as Map<String, dynamic>? ?? {};
    return _buildFlowSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.menu_book_outlined,
                color: StudentDensityTokens.ink,
              ),
              const SizedBox(width: 8),
              const Text(
                '문제 정보',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.3,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _bookmarkProblem,
                tooltip: '문제 북마크',
                icon: const Icon(Icons.bookmark_add_outlined),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            '문제 지문',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ContentBlocksView(
            blocks: titleBlocks,
            textStyle: const TextStyle(fontSize: 14, height: 1.45),
            latexStyle: const TextStyle(fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 18),
          const Text(
            '문제 정답',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showAnswer)
                ContentBlocksView(
                  blocks: answerBlocks,
                  textStyle: const TextStyle(fontSize: 14, height: 1.45),
                  latexStyle: const TextStyle(fontSize: 14, height: 1.45),
                )
              else
                const Text(
                  '정답은 정답 제출 후 확인 가능합니다.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              const SizedBox(height: 12),
              if (!widget.sharedMode)
                StudentDensityButton(
                  onPressed: () => _openInstantChat(
                    questTitleBlocks,
                    showAnswer
                        ? (questAnswerBlocks.isNotEmpty
                              ? questAnswerBlocks
                              : questAnswerRiddle)
                        : <ContentBlock>[],
                    questData['all_formulas'],
                  ),
                  primary: true,
                  icon: Icons.chat_bubble_outline,
                  label: showAnswer ? '질문하기 · AI 채팅' : '질문하기 · 정답 비공개',
                )
              else ...[
                StudentDensityButton(
                  onPressed: () => setState(() => _showSharedAnalysis = true),
                  primary: true,
                  icon: Icons.analytics_outlined,
                  label: '왜 틀렸는지 분석',
                ),
                const SizedBox(height: 12),
                if (_showSharedAnalysis) _buildSharedAnalysisCard(questData),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 필요한 변수는 그래프 실제 높이와 전체화면 여부다.
  /// 작동 원리는 그래프의 세로 길이만큼 카드 높이를 자연스럽게 늘려 바깥 페이지가 세로 스크롤을 담당하게 하는 것이다.
  Widget _buildCanvasPanel({bool fullScreen = false}) {
    final content = _graph.nodes.isEmpty
        ? const Center(child: Text('No flow data.'))
        : _FlowCanvas(
            graph: _graph,
            selected: _selected,
            nodeStates: _nodeStates,
            onNodeTap: (node) => setState(() => _selected = node),
          );
    return _buildFlowSurface(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        height: math.max(500, _graph.size.height + 72),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_nodeStates.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _LegendChip(label: '정답', color: Color(0xFF202022)),
                          _LegendChip(label: '오답', color: Color(0xFF7A7A80)),
                          _LegendChip(label: '이후 단계', color: Color(0xFFB3B3B8)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: fullScreen ? '전체화면 닫기' : '전체화면 보기',
                      onPressed: _toggleFullScreen,
                      icon: Icon(
                        fullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CustomPaint(
                    painter: const _FlowDotGridPainter(),
                    child: ColoredBox(
                      color: Colors.transparent,
                      child: content,
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

  Widget _buildDetailPanel() {
    final node = _selected;
    final nodeState = node == null
        ? _FlowNodeState.normal
        : _nodeStates[node.id] ?? _FlowNodeState.normal;
    return _buildFlowSurface(
      padding: const EdgeInsets.all(20),
      child: Padding(
        padding: EdgeInsets.zero,
        child: node == null
            ? const Center(child: Text('노드를 선택해주세요'))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.sharedMeta != null) ...[
                      _buildSharedMetaCard(widget.sharedMeta!),
                      const SizedBox(height: 12),
                    ],
                    const Text(
                      '노드 상세 정보',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('노드 요약', node.flow),
                    _buildConceptRow(node.hashTags),
                    ..._buildHelpAndSolutionRows(
                      nodeState: nodeState,
                      hintBlocks: node.hintRiddle,
                      solutionBlocks: node.answerRiddle,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// 필요한 변수는 카드 본문과 안쪽 여백이다.
  /// 작동 원리는 학생 화면 전체에서 쓰는 흰 표면·옅은 경계·넉넉한 반경을 Flow의 세 패널에도 동일하게 적용하는 것이다.
  Widget _buildFlowSurface({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) => StudentDensitySurface(
    padding: padding,
    radius: StudentDensityTokens.radius,
    child: child,
  );

  void _openInstantChat(
    List<ContentBlock> questTitleBlocks,
    List<ContentBlock> answerBlocks,
    dynamic allFormulas,
  ) async {
    final contextMap = {
      'quest_title': _blocksToPlainText(questTitleBlocks),
      'answer_riddle': _blocksToPlainText(answerBlocks),
      'all_formulas': allFormulas?.toString() ?? '',
    };
    setState(() => _chatActive = true);
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => ServerChatPage(
          initialContext: contextMap,
          initialMode: 'chat',
          ephemeral: true,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    if (mounted) {
      setState(() => _chatActive = false);
    }
  }

  void _toggleFormulaModal() {
    setState(() => _formulaModalVisible = !_formulaModalVisible);
  }

  Widget _buildSharedAnalysisCard(Map<String, dynamic> questData) {
    final allFormulas = questData['all_formulas']?.toString() ?? '';
    final answerRiddleBlocks = parseContentBlocks(
      questData['answer_riddle'] ?? '',
    );
    final answerText = _blocksToPlainText(answerRiddleBlocks).toLowerCase();
    final studentLines = allFormulas
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final missing = <String>[];
    for (final line in studentLines) {
      if (!answerText.contains(line.toLowerCase())) {
        missing.add(line);
      }
    }
    final allMatched = missing.isEmpty && studentLines.isNotEmpty;
    final verdict = allMatched
        ? '제출한 공식이 모두 정답에 포함되어 있어요.'
        : '다음 공식이 정답과 일치하지 않습니다.';

    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '분석 결과',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(verdict, style: const TextStyle(fontSize: 14)),
            if (!allMatched) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: missing
                    .map(
                      (f) => Chip(
                        label: Text(f),
                        backgroundColor: const Color(0xFFFFF0ED),
                        labelStyle: const TextStyle(color: Color(0xFFD84315)),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            const Text('정답 풀이', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ContentBlocksView(
              blocks: answerRiddleBlocks,
              textStyle: const TextStyle(fontSize: 14, height: 1.4),
              latexStyle: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              '제출한 공식 (all_formulas)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ContentBlocksView(
              blocks: [ContentBlock(type: 'text', content: allFormulas)],
              textStyle: const TextStyle(fontSize: 14, height: 1.4),
              latexStyle: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, List<ContentBlock> blocks) {
    final displayBlocks = blocks.isEmpty
        ? [const ContentBlock(type: 'text', content: '-')]
        : blocks;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          ContentBlocksView(
            blocks: displayBlocks,
            textStyle: const TextStyle(fontSize: 14, height: 1.4),
            latexStyle: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildConceptRow(List<String> rawTags) {
    final tags = rawTags
        .map((tag) => tag.startsWith('#') ? tag.substring(1) : tag)
        .where((tag) => tag.trim().isNotEmpty)
        .toList();
    final content = tags.isEmpty
        ? const Text('-')
        : Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags
                .map(
                  (tag) => Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openConceptTextbook(tag),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E8EF)),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2A44),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFDFEFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6EAF2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '관련 개념',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            content,
            const SizedBox(height: 6),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.open_in_new, size: 14, color: Colors.black45),
                SizedBox(width: 4),
                Text(
                  '태그를 선택하면 개념교재로 이동합니다',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 필요한 변수는 Flow 노드에 연결된 개념 태그다.
  /// 작동 원리는 태그 하나로 구성한 기본 개념교재를 열어 선택한 개념의 첫 지면부터 바로 읽게 하는 것이다.
  void _openConceptTextbook(String tag) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookWidget(book: buildConceptBook([tag])),
      ),
    );
  }

  List<Widget> _buildHelpAndSolutionRows({
    required _FlowNodeState nodeState,
    required List<ContentBlock> hintBlocks,
    required List<ContentBlock> solutionBlocks,
  }) {
    final widgets = <Widget>[];
    switch (nodeState) {
      case _FlowNodeState.correct:
        if (solutionBlocks.isNotEmpty) {
          widgets.add(_buildDetailRow('상세 풀이', solutionBlocks));
        }
        break;
      case _FlowNodeState.incorrect:
        if (hintBlocks.isNotEmpty) {
          widgets.add(_buildDetailRow('도움말', hintBlocks));
        }
        break;
      case _FlowNodeState.dim:
        if (hintBlocks.isNotEmpty) {
          widgets.add(_buildDetailRow('도움말', hintBlocks));
        }
        break;
      case _FlowNodeState.normal:
        if (hintBlocks.isNotEmpty) {
          widgets.add(_buildDetailRow('도움말', hintBlocks));
        }
        if (solutionBlocks.isNotEmpty) {
          widgets.add(_buildDetailRow('상세 풀이', solutionBlocks));
        }
        break;
    }
    return widgets;
  }

  String _blocksToPlainText(List<ContentBlock> blocks) {
    final buffer = StringBuffer();
    for (final block in blocks) {
      final content = block.content.trim();
      if (content.isEmpty) continue;
      if (buffer.isNotEmpty) buffer.write(" ");
      buffer.write(content);
    }
    return buffer.toString();
  }

  Widget _buildSharedMetaCard(SharedMeta meta) {
    final tagsLabel = meta.tags.isEmpty
        ? '태그 없음'
        : meta.tags.map((e) => '#$e').join(' ');
    final difficultyLabel = () {
      switch (meta.difficulty) {
        case 5:
          return '상';
        case 4:
          return '중상';
        case 3:
          return '중';
        case 2:
          return '중하';
        case 1:
          return '하';
        default:
          return '정보 없음';
      }
    }();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE4D4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '공유 정보',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1B402B),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text('공유자: ${meta.userId}'),
          Text('공유일: ${meta.createdAt}'),
          Text('난이도: $difficultyLabel'),
          Text('태그: $tagsLabel'),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: () => _showSharedMetaDialog(meta),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B402B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(80, 36),
                ),
                child: const Text('열람'),
              ),
              const SizedBox(width: 8),
              if (meta.canDelete)
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await ApiClient.instance.deleteSharedFlow(meta.shareId);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('공유를 취소했어요.')),
                        );
                        Navigator.of(context).maybePop();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('취소 실패: $e')));
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD84315),
                    side: const BorderSide(color: Color(0xFFD84315)),
                  ),
                  child: const Text('공유 취소'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 필요한 변수는 공유 ID·공유자·시각·태그·난이도다.
  /// 작동 원리는 공유 Flow의 공식 정보와 소유권 상태를 HTML 상세 모달에서 다시 확인하게 한다.
  void _showSharedMetaDialog(SharedMeta meta) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('공유 Flow 정보'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('공유자 · ${meta.userId}'),
            Text('공유일 · ${meta.createdAt}'),
            Text('난이도 · ${meta.difficulty ?? '-'}'),
            Text('태그 · ${meta.tags.join(' · ')}'),
            const SizedBox(height: 10),
            const Text('현재 Flow의 문제 정보·단계 상태·공식·정답 풀이를 공유 범위에서 열람합니다.'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  String _buildStatusJson(Map<String, dynamic> questData) {
    final statusRaw =
        widget.stepCorrectness ??
        (questData['status'] as List<dynamic>?)
            ?.map((e) {
              if (e is Map<String, dynamic>) return e;
              if (e is Map) return Map<String, dynamic>.from(e);
              return null;
            })
            .whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    final inPanic = questData['in_panic'] ?? [];
    final aiOpinion = questData['ai_opinion'] ?? '';
    final oReasons = questData['o_reasons'] ?? [];
    final payload = {
      'status': statusRaw,
      'in_panic': inPanic,
      'ai_opinion': aiOpinion,
      'o_reasons': oReasons,
    };
    return jsonEncode(payload);
  }

  Map<String, _FlowNodeState> _buildNodeStates(
    List<Map<String, dynamic>>? stepCorrectness,
  ) {
    if (stepCorrectness == null || stepCorrectness.isEmpty) {
      return {};
    }
    final nodes = _graph.nodes.values.toList()
      ..sort((a, b) => _nodeIndex(a.id).compareTo(_nodeIndex(b.id)));
    final firstIncorrect = stepCorrectness.indexWhere(
      (entry) => entry['correct'] == false,
    );
    final states = <String, _FlowNodeState>{};
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (firstIncorrect >= 0) {
        if (i < firstIncorrect) {
          states[node.id] = _FlowNodeState.correct;
        } else if (i == firstIncorrect) {
          states[node.id] = _FlowNodeState.incorrect;
        } else {
          states[node.id] = _FlowNodeState.dim;
        }
        continue;
      }
      if (i < stepCorrectness.length && stepCorrectness[i]['correct'] == true) {
        states[node.id] = _FlowNodeState.correct;
      }
    }
    return states;
  }

  bool _areAllStepsCorrect(List<Map<String, dynamic>>? stepCorrectness) {
    if (stepCorrectness == null || stepCorrectness.isEmpty) {
      return false;
    }
    return stepCorrectness.every((entry) => entry['correct'] == true);
  }

  int _nodeIndex(String id) {
    final parts = id.split('-');
    if (parts.length < 2) {
      return 0;
    }
    return int.tryParse(parts.last) ?? 0;
  }
}

class _FlowCanvas extends StatefulWidget {
  final _FlowGraph graph;
  final _FlowNode? selected;
  final Map<String, _FlowNodeState> nodeStates;
  final ValueChanged<_FlowNode> onNodeTap;

  const _FlowCanvas({
    required this.graph,
    required this.selected,
    required this.nodeStates,
    required this.onNodeTap,
  });

  @override
  State<_FlowCanvas> createState() => _FlowCanvasState();
}

class _FlowCanvasState extends State<_FlowCanvas> {
  /// 필요한 변수는 그래프의 실제 가로·세로 크기다.
  /// 작동 원리는 세로 이동은 상위 페이지 스크롤에 넘기고, 화면보다 넓어진 Flow만 가로 스크롤로 탐색하게 하는 것이다.
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: widget.graph.size.width,
        height: widget.graph.size.height,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _FlowEdgePainter(
                  edges: widget.graph.edges,
                  positions: widget.graph.positions,
                  nodeSizes: widget.graph.nodeSizes,
                ),
              ),
            ),
            ...widget.graph.nodes.values.map((node) {
              final position = widget.graph.positions[node.id];
              if (position == null) return const SizedBox.shrink();
              final nodeSize =
                  widget.graph.nodeSizes[node.id] ??
                  const Size(
                    _FlowGraphBuilder.nodeWidth,
                    _FlowGraphBuilder.nodeMinHeight,
                  );
              return Positioned(
                left: position.dx,
                top: position.dy,
                width: nodeSize.width,
                height: nodeSize.height,
                child: _FlowNodeCard(
                  node: node,
                  selected: widget.selected?.id == node.id,
                  state: widget.nodeStates[node.id] ?? _FlowNodeState.normal,
                  onTap: () => widget.onNodeTap(node),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _FlowNodeCard extends StatelessWidget {
  final _FlowNode node;
  final bool selected;
  final _FlowNodeState state;
  final VoidCallback onTap;

  const _FlowNodeCard({
    required this.node,
    required this.selected,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseBorder = selected ? Colors.black : const Color(0xFFD8D8DC);
    final style = _NodeStyle.fromState(state, baseBorder);
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: style.opacity,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: style.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: style.border, width: selected ? 2 : 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: ClipRect(
              child: ContentBlocksView(
                blocks: node.flow.isEmpty
                    ? [const ContentBlock(type: 'text', content: '-')]
                    : node.flow,
                textStyle: const TextStyle(fontSize: 12, height: 1.3),
                latexStyle: const TextStyle(fontSize: 12, height: 1.3),
                textAlign: TextAlign.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _FlowNodeState { normal, correct, incorrect, dim }

class _NodeStyle {
  final Color background;
  final Color border;
  final double opacity;

  const _NodeStyle({
    required this.background,
    required this.border,
    required this.opacity,
  });

  factory _NodeStyle.fromState(_FlowNodeState state, Color fallbackBorder) {
    switch (state) {
      case _FlowNodeState.correct:
        return const _NodeStyle(
          background: Color(0xFFECECEF),
          border: Color(0xFF202022),
          opacity: 1,
        );
      case _FlowNodeState.incorrect:
        return const _NodeStyle(
          background: Color(0xFFF2F2F3),
          border: Color(0xFF66666C),
          opacity: 1,
        );
      case _FlowNodeState.dim:
        return _NodeStyle(
          background: const Color(0xFFF3F3F3),
          border: fallbackBorder,
          opacity: 0.45,
        );
      case _FlowNodeState.normal:
        return _NodeStyle(
          background: Colors.white,
          border: fallbackBorder,
          opacity: 1,
        );
    }
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowEdgePainter extends CustomPainter {
  final List<_FlowEdge> edges;
  final Map<String, Offset> positions;
  final Map<String, Size> nodeSizes;

  _FlowEdgePainter({
    required this.edges,
    required this.positions,
    required this.nodeSizes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final from = positions[edge.fromId];
      final to = positions[edge.toId];
      if (from == null || to == null) {
        continue;
      }
      final fromSize =
          nodeSizes[edge.fromId] ??
          const Size(
            _FlowGraphBuilder.nodeWidth,
            _FlowGraphBuilder.nodeMinHeight,
          );
      final toSize =
          nodeSizes[edge.toId] ??
          const Size(
            _FlowGraphBuilder.nodeWidth,
            _FlowGraphBuilder.nodeMinHeight,
          );
      final start = Offset(
        from.dx + fromSize.width / 2,
        from.dy + fromSize.height,
      );
      final end = Offset(to.dx + toSize.width / 2, to.dy);
      final controlDistance = (end.dy - start.dy).abs() * .52;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx,
          start.dy + controlDistance,
          end.dx,
          end.dy - controlDistance,
          end.dx,
          end.dy,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FlowEdgePainter oldDelegate) {
    return oldDelegate.edges != edges ||
        oldDelegate.positions != positions ||
        oldDelegate.nodeSizes != nodeSizes;
  }
}

class _FlowDotGridPainter extends CustomPainter {
  const _FlowDotGridPainter();

  /// 필요한 변수는 현재 캔버스 크기다.
  /// 작동 원리는 20px 간격의 옅은 점을 찍어 HTML Flow 작업 영역의 격자 배경을 재현하는 것이다.
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFE2E2E5);
    for (double x = 8; x < size.width; x += 20) {
      for (double y = 8; y < size.height; y += 20) {
        canvas.drawCircle(Offset(x, y), .75, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FlowDotGridPainter oldDelegate) => false;
}

class _FlowEdge {
  final String fromId;
  final String toId;

  const _FlowEdge({required this.fromId, required this.toId});
}

class _FormulaModal extends StatelessWidget {
  const _FormulaModal({
    required this.allFormulas,
    required this.onClose,
    this.isPreview = false,
  });

  final String allFormulas;
  final VoidCallback onClose;
  final bool isPreview;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: 320,
      constraints: const BoxConstraints(maxHeight: 420),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.functions, color: Color(0xFF1B402B)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '풀이 내역',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF1B402B),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: isPreview ? null : onClose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: ContentBlocksView(
                blocks: [ContentBlock(type: 'text', content: allFormulas)],
                textStyle: const TextStyle(fontSize: 14, height: 1.4),
                latexStyle: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
    return isPreview ? Opacity(opacity: 0.8, child: content) : content;
  }
}

class _FlowNode {
  final String id;
  final List<ContentBlock> flow;
  final Size size;
  final List<String> hashTags;
  final List<ContentBlock> hintRiddle;
  final List<ContentBlock> answerRiddle;
  final List<_FlowNode> rawBranches;
  _FlowNode? next;
  _FlowNode? inline;
  List<_FlowNode> branchLanes = [];

  _FlowNode({
    required this.id,
    required this.flow,
    required this.size,
    required this.hashTags,
    required this.hintRiddle,
    required this.answerRiddle,
    required this.rawBranches,
  });
}

class _FlowGraph {
  final Map<String, _FlowNode> nodes;
  final Map<String, Offset> positions;
  final List<_FlowEdge> edges;
  final Size size;
  final Map<String, Size> nodeSizes;

  const _FlowGraph({
    required this.nodes,
    required this.positions,
    required this.edges,
    required this.size,
    required this.nodeSizes,
  });

  factory _FlowGraph.empty() {
    return const _FlowGraph(
      nodes: {},
      positions: {},
      edges: [],
      size: Size(0, 0),
      nodeSizes: {},
    );
  }
}

class _FlowGraphBuilder {
  static const double nodeWidth = 220;
  static const double nodeMinHeight = 80;
  static const double nodePadding = 8;
  static const double nodeTextFontSize = 12;
  static const double nodeTextLineHeight = 1.3;
  static const double horizontalGap = 140;
  static const double verticalGap = 90;
  static const double canvasPadding = 32;

  int _counter = 0;

  _FlowGraph build(dynamic solves) {
    final nodes = _buildNodes(_extractBranches(solves), sequential: true);
    if (nodes.isEmpty) {
      return _FlowGraph.empty();
    }
    final root = nodes.first;
    final gridPositions = <String, _GridPosition>{};
    final metrics = _LayoutMetrics();
    _layout(root, 0, 0, gridPositions, metrics);

    final allNodes = <String, _FlowNode>{};
    _collectNodes(root, allNodes);
    final edges = <_FlowEdge>[];
    _collectEdges(root, edges);

    final rowCount = metrics.maxRow + 1;
    final rowHeights = <int, double>{};
    for (final entry in gridPositions.entries) {
      final node = allNodes[entry.key];
      final height = node?.size.height ?? nodeMinHeight;
      final current = rowHeights[entry.value.row] ?? 0.0;
      if (height > current) {
        rowHeights[entry.value.row] = height;
      }
    }
    for (var row = 0; row < rowCount; row++) {
      rowHeights.putIfAbsent(row, () => nodeMinHeight);
    }
    final rowOffsets = <int, double>{};
    var cursorY = canvasPadding;
    for (var row = 0; row < rowCount; row++) {
      rowOffsets[row] = cursorY;
      cursorY += rowHeights[row]! + verticalGap;
    }

    final positions = <String, Offset>{};
    for (final entry in gridPositions.entries) {
      final col = entry.value.col - metrics.minCol;
      final row = entry.value.row;
      positions[entry.key] = Offset(
        canvasPadding + col * (nodeWidth + horizontalGap),
        rowOffsets[row] ?? canvasPadding,
      );
    }

    final columnCount = metrics.maxCol - metrics.minCol + 1;
    final width =
        columnCount * nodeWidth +
        (columnCount - 1) * horizontalGap +
        canvasPadding * 2;
    final totalRowHeight = rowHeights.values.fold(
      0.0,
      (sum, height) => sum + height,
    );
    final height =
        totalRowHeight + (rowCount - 1) * verticalGap + canvasPadding * 2;
    final nodeSizes = {for (final node in allNodes.values) node.id: node.size};
    return _FlowGraph(
      nodes: allNodes,
      positions: positions,
      edges: edges,
      size: Size(width, height),
      nodeSizes: nodeSizes,
    );
  }

  List<_FlowNode> _buildNodes(
    List<dynamic> rawList, {
    required bool sequential,
  }) {
    final nodes = <_FlowNode>[];
    for (final entry in rawList) {
      final decoded = _decodeValue(entry);
      if (!sequential && decoded is List<dynamic>) {
        final laneNodes = _buildNodes(decoded, sequential: true);
        if (laneNodes.isNotEmpty) {
          nodes.add(laneNodes.first);
        }
        continue;
      }
      final map = _coerceStepMap(decoded);
      if (map == null) {
        continue;
      }
      nodes.add(_buildNode(map));
    }
    if (sequential && nodes.isNotEmpty) {
      for (var i = 0; i < nodes.length - 1; i++) {
        nodes[i].next = nodes[i + 1];
      }
    }
    for (final node in nodes) {
      _normalizeBranches(node);
    }
    return nodes;
  }

  _FlowNode _buildNode(Map<String, dynamic> raw) {
    final branches = _extractBranches(raw['branches']);
    final flowBlocks = normalizeFlowBlocks(parseContentBlocks(raw['flow']));
    final nodeSize = _measureNodeSize(flowBlocks);
    final hashTags = (raw['hash_tag'] as List<dynamic>? ?? [])
        .map((tag) => tag.toString())
        .toList();
    return _FlowNode(
      id: 'node-${_counter++}',
      flow: flowBlocks,
      size: nodeSize,
      hashTags: hashTags,
      hintRiddle: normalizeFlowBlocks(parseContentBlocks(raw['hint_riddle'])),
      answerRiddle: normalizeFlowBlocks(
        parseContentBlocks(raw['answer_riddle']),
      ),
      rawBranches: _buildNodes(branches, sequential: false),
    );
  }

  Size _measureNodeSize(List<ContentBlock> blocks) {
    final text = _plainText(blocks);
    if (text.isEmpty) {
      return const Size(nodeWidth, nodeMinHeight);
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: nodeTextFontSize,
          height: nodeTextLineHeight,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );
    painter.layout(maxWidth: nodeWidth - nodePadding * 2);
    final height = math.max(
      nodeMinHeight,
      painter.size.height + nodePadding * 2 + 12,
    );
    return Size(nodeWidth, height);
  }

  String _plainText(List<ContentBlock> blocks) {
    final buffer = StringBuffer();
    for (final block in blocks) {
      final content = block.content.trim();
      if (content.isEmpty) {
        continue;
      }
      if (buffer.isNotEmpty) {
        buffer.write(' ');
      }
      buffer.write(content);
    }
    return buffer.toString();
  }

  List<dynamic> _extractBranches(dynamic value) {
    final decoded = _decodeValue(value);
    if (decoded is List<dynamic>) {
      return decoded.map(_decodeValue).toList();
    }
    if (decoded is Map<String, dynamic>) {
      final inner =
          decoded['branches'] ?? decoded['solves'] ?? decoded['steps'];
      if (inner is List<dynamic>) {
        return inner.map(_decodeValue).toList();
      }
    }
    return const [];
  }

  dynamic _decodeValue(dynamic value) {
    if (value is! String) {
      return value;
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(value);
    } catch (_) {
      return value;
    }
    if (decoded is String) {
      try {
        final second = jsonDecode(decoded);
        return second;
      } catch (_) {
        return decoded;
      }
    }
    return decoded;
  }

  Map<String, dynamic>? _coerceStepMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    if (value is String) {
      final decoded = _decodeValue(value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, entry) => MapEntry(key.toString(), entry));
      }
    }
    return null;
  }

  void _normalizeBranches(_FlowNode node) {
    for (final child in node.rawBranches) {
      _normalizeBranches(child);
    }
    if (node.rawBranches.isNotEmpty) {
      node.branchLanes = node.rawBranches;
    }
  }

  int _layout(
    _FlowNode node,
    int row,
    int col,
    Map<String, _GridPosition> positions,
    _LayoutMetrics metrics,
  ) {
    metrics.minCol = metrics.minCol < col ? metrics.minCol : col;
    metrics.maxCol = metrics.maxCol > col ? metrics.maxCol : col;
    metrics.maxRow = metrics.maxRow > row ? metrics.maxRow : row;
    positions[node.id] = _GridPosition(row: row, col: col);
    var cursor = row + 1;
    if (node.inline != null) {
      cursor = _layout(node.inline!, cursor, col, positions, metrics);
    }
    if (node.branchLanes.isNotEmpty) {
      final startRow = cursor;
      var maxRow = cursor;
      final offsets = _branchOffsets(node.branchLanes.length);
      for (var i = 0; i < node.branchLanes.length; i++) {
        final branch = node.branchLanes[i];
        final branchRow = _layout(
          branch,
          startRow,
          col + offsets[i],
          positions,
          metrics,
        );
        if (branchRow > maxRow) {
          maxRow = branchRow;
        }
      }
      cursor = maxRow;
    }
    if (node.next != null) {
      cursor = _layout(node.next!, cursor, col, positions, metrics);
    }
    return cursor;
  }

  List<int> _branchOffsets(int count) {
    if (count <= 1) {
      return const [0];
    }
    const spread = 2;
    final start = -((count - 1) * spread) ~/ 2;
    final offsets = List<int>.generate(
      count,
      (index) => start + index * spread,
    );
    if (count.isOdd) {
      for (var i = 0; i < offsets.length; i++) {
        offsets[i] = offsets[i] + 1;
      }
    }
    return offsets;
  }

  void _collectNodes(_FlowNode node, Map<String, _FlowNode> nodes) {
    if (nodes.containsKey(node.id)) {
      return;
    }
    nodes[node.id] = node;
    if (node.inline != null) {
      _collectNodes(node.inline!, nodes);
    }
    for (final branch in node.branchLanes) {
      _collectNodes(branch, nodes);
    }
    if (node.next != null) {
      _collectNodes(node.next!, nodes);
    }
  }

  void _collectEdges(_FlowNode node, List<_FlowEdge> edges) {
    if (node.inline != null) {
      edges.add(_FlowEdge(fromId: node.id, toId: node.inline!.id));
      _collectEdges(node.inline!, edges);
    }
    if (node.branchLanes.isNotEmpty) {
      for (final branch in node.branchLanes) {
        edges.add(_FlowEdge(fromId: node.id, toId: branch.id));
        _collectEdges(branch, edges);
      }
      if (node.next != null) {
        final terminals = node.branchLanes.expand(_collectTerminals).toList();
        for (final leaf in terminals) {
          edges.add(_FlowEdge(fromId: leaf.id, toId: node.next!.id));
        }
      }
    } else if (node.next != null && node.inline == null) {
      edges.add(_FlowEdge(fromId: node.id, toId: node.next!.id));
    }
    if (node.inline != null && node.next != null) {
      final terminals = _collectTerminals(node.inline!);
      for (final leaf in terminals) {
        edges.add(_FlowEdge(fromId: leaf.id, toId: node.next!.id));
      }
    }
    if (node.next != null) {
      _collectEdges(node.next!, edges);
    }
  }

  List<_FlowNode> _collectTerminals(_FlowNode node) {
    if (node.inline != null) {
      return _collectTerminals(node.inline!);
    }
    if (node.branchLanes.isNotEmpty) {
      return node.branchLanes.expand(_collectTerminals).toList();
    }
    return [node];
  }
}

class _GridPosition {
  final int row;
  final int col;

  const _GridPosition({required this.row, required this.col});
}

class _LayoutMetrics {
  int minCol = 0;
  int maxCol = 0;
  int maxRow = 0;
}
