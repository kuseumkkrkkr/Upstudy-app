import 'dart:convert';

import 'package:flutter/material.dart';
import '../models/content_block.dart';
import '../widgets/content_blocks_view.dart';

class FlowViewPage extends StatefulWidget {
  final Map<String, dynamic> quest;
  final String title;
  final String? analysisText;
  final List<Map<String, dynamic>>? stepCorrectness;

  const FlowViewPage({
    super.key,
    required this.quest,
    this.title = 'Flow Editor',
    this.analysisText,
    this.stepCorrectness,
  });

  @override
  State<FlowViewPage> createState() => _FlowViewPageState();
}

class _FlowViewPageState extends State<FlowViewPage> {
  late final _FlowGraph _graph;
  _FlowNode? _selected;
  late final Map<String, _FlowNodeState> _nodeStates;

  @override
  void initState() {
    super.initState();
    final solves = widget.quest['solves'] as List<dynamic>? ?? [];
    _graph = _FlowGraphBuilder().build(solves);
    _nodeStates = _buildNodeStates(widget.stepCorrectness);
  }

  @override
  Widget build(BuildContext context) {
    final questData = widget.quest['data'] as Map<String, dynamic>? ?? {};
    final questTitleBlocks = parseContentBlocks(questData['quest_title']);
    final questAnswerBlocks = parseContentBlocks(questData['quest_answer']);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1100;
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildLeftPanel(questTitleBlocks, questAnswerBlocks),
                ),
                Expanded(
                  flex: 5,
                  child: _buildCanvasPanel(),
                ),
                Expanded(
                  flex: 3,
                  child: _buildDetailPanel(),
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _buildLeftPanel(questTitleBlocks, questAnswerBlocks),
              const SizedBox(height: 12),
              _buildCanvasPanel(height: 520),
              const SizedBox(height: 12),
              _buildDetailPanel(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLeftPanel(
    List<ContentBlock> questTitleBlocks,
    List<ContentBlock> questAnswerBlocks,
  ) {
    final titleBlocks = questTitleBlocks.isEmpty
        ? [const ContentBlock(type: 'text', content: '제목 없음')]
        : questTitleBlocks;
    final answerBlocks = questAnswerBlocks.isEmpty
        ? [const ContentBlock(type: 'text', content: '-')]
        : questAnswerBlocks;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '문제 분석',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              '문제 본문',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ContentBlocksView(
              blocks: titleBlocks,
              textStyle: const TextStyle(fontSize: 14, height: 1.4),
              latexStyle: const TextStyle(fontSize: 14, height: 1.4),
            ),
            if (widget.analysisText != null) ...[
              const SizedBox(height: 16),
              const Text(
                '분석 요약',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCCD8FF)),
                ),
                child: ContentBlocksView(
                  blocks: () {
                    final trimmed = widget.analysisText!.trim();
                    final blocks = parseTextWithLatex(trimmed);
                    if (blocks.isNotEmpty) {
                      return blocks;
                    }
                    return const [
                      ContentBlock(type: 'text', content: '-'),
                    ];
                  }(),
                  textStyle: const TextStyle(fontSize: 13, height: 1.4),
                  latexStyle: const TextStyle(fontSize: 13, height: 1.4),
                  inline: true,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              '문제 정답',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ContentBlocksView(
              blocks: answerBlocks,
              textStyle: const TextStyle(fontSize: 14, height: 1.4),
              latexStyle: const TextStyle(fontSize: 14, height: 1.4),
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
      margin: const EdgeInsets.all(12),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_nodeStates.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: const [
                    _LegendChip(
                      label: '정답',
                      color: Color(0xFF2D6BFF),
                    ),
                    _LegendChip(
                      label: '오답',
                      color: Color(0xFFE53935),
                    ),
                    _LegendChip(
                      label: '이후 단계',
                      color: Color(0xFFBDBDBD),
                    ),
                  ],
                ),
              ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailPanel() {
    final node = _selected;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: node == null
            ? const Center(child: Text('노드를 선택하세요.'))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '노드 상세 정보',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('flow', node.flow),
                    _buildDetailRow(
                      'hash_tag',
                      [
                        ContentBlock(
                          type: 'text',
                          content: node.hashTags.isEmpty
                              ? '-'
                              : node.hashTags.join(', '),
                        ),
                      ],
                    ),
                    _buildDetailRow('hint_riddle', node.hintRiddle),
                    _buildDetailRow('answer_riddle', node.answerRiddle),
                  ],
                ),
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
      if (i < stepCorrectness.length &&
          stepCorrectness[i]['correct'] == true) {
        states[node.id] = _FlowNodeState.correct;
      }
    }
    return states;
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
                  nodeWidth: _FlowGraphBuilder.nodeWidth,
                  nodeHeight: _FlowGraphBuilder.nodeHeight,
                ),
              ),
            ),
            ...graph.nodes.values.map((node) {
              final position = graph.positions[node.id];
              if (position == null) {
                return const SizedBox.shrink();
              }
              final isSelected = selected?.id == node.id;
              return Positioned(
                left: position.dx,
                top: position.dy,
                width: _FlowGraphBuilder.nodeWidth,
                height: _FlowGraphBuilder.nodeHeight,
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.6)),
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
  final double nodeWidth;
  final double nodeHeight;

  _FlowEdgePainter({
    required this.edges,
    required this.positions,
    required this.nodeWidth,
    required this.nodeHeight,
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
      final start = Offset(from.dx + nodeWidth / 2, from.dy + nodeHeight);
      final end = Offset(to.dx + nodeWidth / 2, to.dy);
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
    return oldDelegate.edges != edges || oldDelegate.positions != positions;
  }
}

class _FlowEdge {
  final String fromId;
  final String toId;

  const _FlowEdge({required this.fromId, required this.toId});
}

class _FlowNode {
  final String id;
  final List<ContentBlock> flow;
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

  const _FlowGraph({
    required this.nodes,
    required this.positions,
    required this.edges,
    required this.size,
  });

  factory _FlowGraph.empty() {
    return const _FlowGraph(
      nodes: {},
      positions: {},
      edges: [],
      size: Size(0, 0),
    );
  }
}

class _FlowGraphBuilder {
  static const double nodeWidth = 220;
  static const double nodeHeight = 80;
  static const double horizontalGap = 140;
  static const double verticalGap = 90;
  static const double canvasPadding = 32;

  int _counter = 0;

  _FlowGraph build(List<dynamic> solves) {
    final nodes = _buildNodes(solves, sequential: true);
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

    final positions = <String, Offset>{};
    for (final entry in gridPositions.entries) {
      final col = entry.value.col - metrics.minCol;
      final row = entry.value.row;
      positions[entry.key] = Offset(
        canvasPadding + col * (nodeWidth + horizontalGap),
        canvasPadding + row * (nodeHeight + verticalGap),
      );
    }

    final columnCount = metrics.maxCol - metrics.minCol + 1;
    final rowCount = metrics.maxRow + 1;
    final width = columnCount * nodeWidth +
        (columnCount - 1) * horizontalGap +
        canvasPadding * 2;
    final height = rowCount * nodeHeight +
        (rowCount - 1) * verticalGap +
        canvasPadding * 2;
    return _FlowGraph(
      nodes: allNodes,
      positions: positions,
      edges: edges,
      size: Size(width, height),
    );
  }

  List<_FlowNode> _buildNodes(List<dynamic> rawList, {required bool sequential}) {
    final nodes = rawList
        .whereType<Map<String, dynamic>>()
        .map(_buildNode)
        .toList();
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
    final hashTags = (raw['hash_tag'] as List<dynamic>? ?? [])
        .map((tag) => tag.toString())
        .toList();
    return _FlowNode(
      id: 'node-${_counter++}',
      flow: parseContentBlocks(raw['flow']),
      hashTags: hashTags,
      hintRiddle: parseContentBlocks(raw['hint_riddle']),
      answerRiddle: parseContentBlocks(raw['answer_riddle']),
      rawBranches: _buildNodes(branches, sequential: false),
    );
  }

  List<dynamic> _extractBranches(dynamic value) {
    if (value is List<dynamic>) {
      return value;
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List<dynamic>) {
          return decoded;
        }
      } catch (_) {}
    }
    return const [];
  }

  void _normalizeBranches(_FlowNode node) {
    for (final child in node.rawBranches) {
      _normalizeBranches(child);
    }
    if (node.rawBranches.length == 1) {
      node.inline = node.rawBranches.first;
    } else {
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
        final branchRow =
            _layout(branch, startRow, col + offsets[i], positions, metrics);
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
    final offsets =
        List<int>.generate(count, (index) => start + index * spread);
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
