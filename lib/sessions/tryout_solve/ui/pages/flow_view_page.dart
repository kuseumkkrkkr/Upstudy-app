import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/content_block.dart';
import 'package:s11/shared/business/repositories/problem_bookmark_store.dart';
import 'package:s11/shared/ui/components/content_blocks_view.dart';
import 'package:s11/shared/ui/app_bar/solve_header.dart';
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
  late final _FlowGraph _graph;
  _FlowNode? _selected;
  late final Map<String, _FlowNodeState> _nodeStates;
  late final bool _allStepsCorrect;
  bool _chatActive = false;
  bool _showSharedAnalysis = false;
  bool _formulaModalVisible = false;
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                SolveHeader(
                  title: widget.title,
                  onInfo: widget.sharedMode
                      ? _toggleFormulaModal
                      : _shareToGroupStudy,
                  infoIcon: widget.sharedMode
                      ? Icons.info_outline
                      : Icons.share_outlined,
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1100;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: _chatActive ? 3 : 2,
                              child: _buildLeftPanel(
                                questTitleBlocks,
                                questAnswerBlocks,
                                questAnswerRiddle,
                              ),
                            ),
                            Expanded(flex: 5, child: _buildCanvasPanel()),
                            Expanded(
                              flex: _chatActive ? 2 : 3,
                              child: _buildDetailPanel(),
                            ),
                          ],
                        );
                      }

                      // 필요한 변수는 좁은 화면 폭과 그래프·제출 요약 패널이다.
                      // 모바일에서는 핵심 학습 흐름인 그래프를 먼저 보여주고 제출 요약을 아래로 보낸다.
                      return ListView(
                        padding: const EdgeInsets.all(10),
                        children: [
                          _buildCanvasPanel(height: 520),
                          const SizedBox(height: 10),
                          _buildLeftPanel(
                            questTitleBlocks,
                            questAnswerBlocks,
                            questAnswerRiddle,
                          ),
                          const SizedBox(height: 10),
                          _buildDetailPanel(),
                        ],
                      );
                    },
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
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(10),
      color: Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book_outlined, color: Color(0xFF1B402B)),
                const SizedBox(width: 8),
                const Text(
                  '문제 정보',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                  ElevatedButton.icon(
                    onPressed: () => _openInstantChat(
                      questTitleBlocks,
                      showAnswer
                          ? (questAnswerBlocks.isNotEmpty
                                ? questAnswerBlocks
                                : questAnswerRiddle)
                          : <ContentBlock>[],
                      questData['all_formulas'],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D6BFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text(
                      showAnswer ? '질문하기 (AI 채팅 열기)' : '질문하기 (정답 비공개)',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  )
                else ...[
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _showSharedAnalysis = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B402B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('왜 틀렸는지 분석'),
                  ),
                  const SizedBox(height: 12),
                  if (_showSharedAnalysis) _buildSharedAnalysisCard(questData),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvasPanel({double? height}) {
    final content = _graph.nodes.isEmpty
        ? const Center(child: Text('No flow data.'))
        : _FlowCanvas(
            graph: _graph,
            selected: _selected,
            nodeStates: _nodeStates,
            onNodeTap: (node) => setState(() => _selected = node),
          );
    return Card(
      elevation: 6,
      margin: const EdgeInsets.all(10),
      color: Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_nodeStates.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: const [
                    _LegendChip(label: '정답', color: Color(0xFF2D6BFF)),
                    _LegendChip(label: '오답', color: Color(0xFFE53935)),
                    _LegendChip(label: '이후 단계', color: Color(0xFF9E9E9E)),
                  ],
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(color: Colors.white, child: content),
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
    return Card(
      elevation: 5,
      margin: const EdgeInsets.all(10),
      color: Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  (tag) => Container(
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
                )
                .toList(),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('개념 상세보기로 넘어가기')));
        },
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.open_in_new, size: 14, color: Colors.black45),
                  SizedBox(width: 4),
                  Text(
                    '개념 상세보기로 넘어가기',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
        ),
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
                onPressed: () {},
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

class _FlowCanvas extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(200),
      constrained: false,
      minScale: 0.6,
      maxScale: 2.5,
      child: SizedBox(
        width: graph.size.width,
        height: graph.size.height,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _FlowEdgePainter(
                  edges: graph.edges,
                  positions: graph.positions,
                  nodeSizes: graph.nodeSizes,
                ),
              ),
            ),
            ...graph.nodes.values.map((node) {
              final position = graph.positions[node.id];
              if (position == null) {
                return const SizedBox.shrink();
              }
              final nodeSize =
                  graph.nodeSizes[node.id] ??
                  const Size(
                    _FlowGraphBuilder.nodeWidth,
                    _FlowGraphBuilder.nodeMinHeight,
                  );
              final isSelected = selected?.id == node.id;
              return Positioned(
                left: position.dx,
                top: position.dy,
                width: nodeSize.width,
                height: nodeSize.height,
                child: _FlowNodeCard(
                  node: node,
                  selected: isSelected,
                  state: nodeStates[node.id] ?? _FlowNodeState.normal,
                  onTap: () => onNodeTap(node),
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
    final baseBorder = selected ? Colors.blueAccent : Colors.black12;
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
          background: Color(0xFFE9F0FF),
          border: Color(0xFF2D6BFF),
          opacity: 1,
        );
      case _FlowNodeState.incorrect:
        return const _NodeStyle(
          background: Color(0xFFFFEBEE),
          border: Color(0xFFE53935),
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
      final midY = (start.dy + end.dy) / 2;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(start.dx, midY)
        ..lineTo(end.dx, midY)
        ..lineTo(end.dx, end.dy);
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
