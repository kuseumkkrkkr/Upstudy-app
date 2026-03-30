import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:s11/models/concept_tag.dart';
import 'package:s11/services/activity_store.dart';
import 'package:s11/tryout.dart';

VoidCallback buildProblemSolveAction(BuildContext context) {
  return () {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    Future.microtask(() async {
      final config = await showProblemSolveModal(context: navigator.context);
      if (config == null) return;
      try {
        await ActivityStore.recordProblemSession(config: config.toJson());
      } catch (_) {}
      navigator.push(
        MaterialPageRoute(
          builder: (_) => BuildpageWidget(config: config),
        ),
      );
    });
  };
}

Future<ProblemSolveConfig?> showProblemSolveModal({
  required BuildContext context,
}) {
  return showDialog<ProblemSolveConfig>(
    context: context,
    barrierDismissible: true,
    builder: (context) => const _ProblemSolveModal(),
  );
}

enum _SelectionState { selected, unselected, partial }

class _TagTreeNode {
  final ConceptTag tag;
  final List<_TagTreeNode> children;

  _TagTreeNode(this.tag, this.children);
}

class _ProblemSolveModal extends StatefulWidget {
  const _ProblemSolveModal();

  @override
  State<_ProblemSolveModal> createState() => _ProblemSolveModalState();
}

class _ProblemSolveModalState extends State<_ProblemSolveModal> {
  static const int _minCount = 1;
  static const int _maxCount = 20;
  static const List<String> _difficultyLabels = [
    '하',
    '중하',
    '중',
    '중상',
    '상',
  ];

  final TextEditingController _countController =
      TextEditingController(text: '1');
  final TextEditingController _tagSearchController = TextEditingController();
  late final List<ConceptTag> _tagTree;
  String _tagQuery = '';
  RangeValues _difficultyRange = const RangeValues(3, 3);

  bool _gradeImmediately = true;

  String _difficultyLabelFor(int tier) {
    final index = tier.clamp(1, 5) - 1;
    return _difficultyLabels[index];
  }

  String _difficultyRangeText(RangeValues range) {
    final start = range.start.round().clamp(1, 5);
    final end = range.end.round().clamp(1, 5);
    final startLabel = _difficultyLabelFor(start);
    final endLabel = _difficultyLabelFor(end);
    if (start == end) {
      return '현재 난이도: $startLabel';
    }
    return '현재 난이도: $startLabel ~ $endLabel';
  }

  int _minTagCountForTier(int tier) {
    final resolved = tier.clamp(1, 5);
    if (resolved == 1) return 1;
    if (resolved == 2) return 1;
    if (resolved == 3) return 3;
    if (resolved == 4) return 3;
    return 5;
  }

  bool _isInsufficientTags(int selectedCount, int maxTier) {
    return selectedCount < _minTagCountForTier(maxTier);
  }

  bool _isNarrowRange(int selectedCount, int maxTier) {
    final minRequired = _minTagCountForTier(maxTier);
    return selectedCount == minRequired || selectedCount < 10;
  }

  @override
  void initState() {
    super.initState();
    _tagTree = _deepCopyTags(conceptTagData);
  }

  @override
  void dispose() {
    _countController.dispose();
    _tagSearchController.dispose();
    super.dispose();
  }

  List<ConceptTag> _deepCopyTags(List<ConceptTag> source) {
    return source
        .map(
          (tag) => ConceptTag(
            name: tag.name,
            displayName: tag.displayName,
            children: tag.children.isNotEmpty
                ? _deepCopyTags(tag.children)
                : [],
            isExpanded: tag.isExpanded,
            isSelected: tag.isSelected,
          ),
        )
        .toList();
  }

  String _normalizeTag(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.startsWith('#') ? trimmed : '#$trimmed';
  }

  String _normalizeSearch(String raw) {
    return raw.replaceAll('#', '').toLowerCase().trim();
  }

  void _toggleTagSelection(ConceptTag tag) {
    final state = _getSelectionState(tag);
    final shouldSelect = state != _SelectionState.selected;
    setState(() => _setSelectionRecursively(tag, shouldSelect));
  }

  void _setSelectionRecursively(ConceptTag tag, bool selected) {
    tag.isSelected = selected;
    for (final child in tag.children) {
      _setSelectionRecursively(child, selected);
    }
  }

  void _toggleExpanded(ConceptTag tag) {
    setState(() => tag.isExpanded = !tag.isExpanded);
  }

  List<_TagTreeNode> _filteredNodes(List<ConceptTag> source) {
    if (_tagQuery.isEmpty) {
      return _buildNodes(source);
    }
    final results = <_TagTreeNode>[];
    for (final tag in source) {
      final matches =
          _normalizeSearch(tag.displayName).contains(_normalizeSearch(_tagQuery));
      final children = _filteredNodes(tag.children);
      if (matches || children.isNotEmpty) {
        results.add(_TagTreeNode(tag, children));
      }
    }
    return results;
  }

  List<_TagTreeNode> _buildNodes(List<ConceptTag> source) {
    return source
        .map((tag) => _TagTreeNode(tag, _buildNodes(tag.children)))
        .toList();
  }

  _SelectionState _getSelectionState(ConceptTag tag) {
    if (tag.children.isEmpty) {
      return tag.isSelected
          ? _SelectionState.selected
          : _SelectionState.unselected;
    }
    var hasSelected = false;
    var hasUnselected = false;
    for (final child in tag.children) {
      final state = _getSelectionState(child);
      if (state == _SelectionState.partial) {
        return _SelectionState.partial;
      }
      if (state == _SelectionState.selected) {
        hasSelected = true;
      } else {
        hasUnselected = true;
      }
    }
    if (hasSelected && hasUnselected) {
      return _SelectionState.partial;
    }
    return hasSelected ? _SelectionState.selected : _SelectionState.unselected;
  }

  List<String> _selectedLeafTags() {
    final selected = _collectSelectedLeafTags(_tagTree);
    return selected.map((tag) => _normalizeTag(tag.displayName)).toList();
  }

  List<ConceptTag> _collectSelectedLeafTags(List<ConceptTag> tags) {
    final results = <ConceptTag>[];
    for (final tag in tags) {
      if (tag.children.isEmpty) {
        if (tag.isSelected) {
          results.add(tag);
        }
      } else {
        results.addAll(_collectSelectedLeafTags(tag.children));
      }
    }
    return results;
  }

  void _setCount(int value) {
    final clamped = value.clamp(_minCount, _maxCount).toInt();
    final text = clamped.toString();
    _countController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  int _parseCount() {
    final parsed = int.tryParse(_countController.text.trim());
    if (parsed == null) return _minCount;
    return parsed.clamp(_minCount, _maxCount).toInt();
  }

  Widget _buildTree(List<_TagTreeNode> nodes, {int depth = 0}) {
    return Column(
      children: nodes.map((node) {
        final tag = node.tag;
        final hasChildren = node.children.isNotEmpty;
        final selectionState = _getSelectionState(tag);
        final shouldExpand = _tagQuery.isNotEmpty || tag.isExpanded;
        return Padding(
          padding: EdgeInsets.only(left: depth * 14),
          child: Column(
            children: [
              Row(
                children: [
                  if (hasChildren)
                    IconButton(
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        tag.isExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                      ),
                      onPressed: () => _toggleExpanded(tag),
                    )
                  else
                    const SizedBox(width: 32),
                  Checkbox(
                    value: selectionState == _SelectionState.selected
                        ? true
                        : selectionState == _SelectionState.unselected
                            ? false
                            : null,
                    tristate: true,
                    onChanged: (_) => _toggleTagSelection(tag),
                  ),
                  Expanded(
                    child: Text(
                      tag.displayName,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              if (hasChildren && shouldExpand)
                _buildTree(node.children, depth: depth + 1),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedTags = _selectedLeafTags();
    final selectedCount = selectedTags.length;
    final minTier = _difficultyRange.start.round();
    final maxTier = _difficultyRange.end.round();
    final resolvedMaxTier = minTier > maxTier ? minTier : maxTier;
    final minRequired = _minTagCountForTier(resolvedMaxTier);
    final insufficientTags = _isInsufficientTags(selectedCount, resolvedMaxTier);
    final narrowRange = !insufficientTags && _isNarrowRange(selectedCount, resolvedMaxTier);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '문제풀이 설정',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 12),
              const Text(
                '문제 수',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      final value = _parseCount();
                      if (value <= _minCount) return;
                      setState(() => _setCount(value - 1));
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _countController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        if (value.trim().isEmpty) return;
                        final parsed = int.tryParse(value);
                        if (parsed == null) return;
                        if (parsed > _maxCount) {
                          _setCount(_maxCount);
                        } else if (parsed < _minCount) {
                          _setCount(_minCount);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final value = _parseCount();
                      if (value >= _maxCount) return;
                      setState(() => _setCount(value + 1));
                    },
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '난이도 티어',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(_difficultyRangeText(_difficultyRange)),
              RangeSlider(
                values: _difficultyRange,
                min: 1,
                max: 5,
                divisions: 4,
                labels: RangeLabels(
                  _difficultyRange.start.round().toString(),
                  _difficultyRange.end.round().toString(),
                ),
                onChanged: (values) {
                  setState(() => _difficultyRange = values);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('하', style: TextStyle(fontSize: 12)),
                  Text('중하', style: TextStyle(fontSize: 12)),
                  Text('중', style: TextStyle(fontSize: 12)),
                  Text('중상', style: TextStyle(fontSize: 12)),
                  Text('상', style: TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '선택한 해시태그가 난이도별 출제 개수보다 많으면 그 안에서 랜덤으로 출제됩니다.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 6),
              Text(
                '문제가 1문제인데 너무 많은 양의 해시태그를 추가할 경우 원하는 범위가 아닐 수 있음\n현재 해시태그 갯수 ${selectedCount}개',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              if (insufficientTags) ...[
                const SizedBox(height: 6),
                Text(
                  '${_difficultyLabelFor(resolvedMaxTier)} 난이도의 최소 선택 개념 갯수는 ${minRequired}개입니다.',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ] else if (narrowRange) ...[
                const SizedBox(height: 6),
                const Text(
                  '선택된 범위가 좁아 생성에 시간이 더 걸릴 수 있습니다.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFD97706)),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                '해시태그',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tagSearchController,
                decoration: const InputDecoration(
                  hintText: '태그 검색',
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _tagQuery = value),
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final nodes = _filteredNodes(_tagTree);
                  return Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: nodes.isEmpty
                        ? const Center(child: Text('검색 결과가 없습니다.'))
                        : Scrollbar(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                              children: [_buildTree(nodes)],
                            ),
                          ),
                  );
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('푼 즉시 채점'),
                subtitle: const Text('끄면 모든 문제 풀이 후 채점'),
                value: _gradeImmediately,
                onChanged: (value) {
                  setState(() => _gradeImmediately = value);
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: insufficientTags
                        ? null
                        : () {
                            final config = ProblemSolveConfig(
                              questionCount: _parseCount(),
                              hashTags: selectedTags,
                              gradeImmediately: _gradeImmediately,
                              minDifficultyTier: minTier,
                              maxDifficultyTier: maxTier,
                            );
                            Navigator.of(context).pop(config);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B402B),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('시작'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
