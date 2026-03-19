import 'package:flutter/material.dart';
import 'package:s11/models/concept_tag.dart';
import 'package:s11/pages/exam_paper_page.dart';
import 'package:s11/services/api_client.dart';
import 'package:s11/services/exam_paper_store.dart';

const int _defaultExamQuestionCount = 30;
const int _minExamQuestionCount = 5;
const int _maxExamQuestionCount = 30;

class ExamBuildResult {
  const ExamBuildResult({required this.examId, required this.questionCount});

  final String examId;
  final int questionCount;
}

Future<void> startExamFlow(BuildContext context) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final result = await showExamBuildModal(context: navigator.context);
  if (result == null) {
    return;
  }
  navigator.push(
    MaterialPageRoute(
      builder: (_) => ExamPaperPage(
        examId: result.examId,
        expectedQuestionCount: result.questionCount,
      ),
    ),
  );
}

VoidCallback buildExamAction(BuildContext context) {
  return () {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    Future.microtask(() => startExamFlow(navigator.context));
  };
}

Future<ExamBuildResult?> showExamBuildModal({required BuildContext context}) {
  return showDialog<ExamBuildResult>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _ExamBuildModal(),
  );
}

class _ExamBuildModal extends StatefulWidget {
  const _ExamBuildModal();

  @override
  State<_ExamBuildModal> createState() => _ExamBuildModalState();
}

enum _SelectionState { selected, unselected, partial }
enum _ExamPaperType { csat, aiflow }

class _TagTreeNode {
  final ConceptTag tag;
  final List<_TagTreeNode> children;

  _TagTreeNode(this.tag, this.children);
}

class _ExamBuildModalState extends State<_ExamBuildModal> {
  static const List<String> _difficultyLabels = [
    '하',
    '중하',
    '중',
    '중상',
    '상',
  ];

  final TextEditingController _questionCountController =
      TextEditingController(text: _defaultExamQuestionCount.toString());
  final TextEditingController _tagSearchController = TextEditingController();
  late final List<ConceptTag> _tagTree;
  String _tagQuery = '';
  double _difficultyValue = 3;
  bool _submitting = false;
  _ExamPaperType _paperType = _ExamPaperType.csat;
  bool _saveToLibrary = true;

  @override
  void initState() {
    super.initState();
    _tagTree = _deepCopyTags(conceptTagData);
  }

  @override
  void dispose() {
    _questionCountController.dispose();
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

  String _difficultyLabelFor(int tier) {
    final index = tier.clamp(1, 5) - 1;
    return _difficultyLabels[index];
  }

  int _difficultyTierFromSlider() {
    return _difficultyValue.round().clamp(1, 5);
  }

  void _setQuestionCount(int value) {
    final clamped = value.clamp(_minExamQuestionCount, _maxExamQuestionCount);
    final text = clamped.toString();
    _questionCountController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  int _parseQuestionCount() {
    final parsed = int.tryParse(_questionCountController.text.trim());
    if (parsed == null) {
      return _defaultExamQuestionCount
          .clamp(_minExamQuestionCount, _maxExamQuestionCount);
    }
    return parsed.clamp(_minExamQuestionCount, _maxExamQuestionCount);
  }

  String _paperTypeLabel(_ExamPaperType type) {
    switch (type) {
      case _ExamPaperType.csat:
        return '수능';
      case _ExamPaperType.aiflow:
        return 'AIflow (더미)';
    }
  }

  String _paperTypeKey(_ExamPaperType type) {
    switch (type) {
      case _ExamPaperType.csat:
        return 'csat';
      case _ExamPaperType.aiflow:
        return 'aiflow';
    }
  }

  Future<void> _submitExam() async {
    if (_submitting) {
      return;
    }
    final questionCount = _parseQuestionCount();
    final tags = _selectedLeafTags();
    if (tags.isEmpty) {
      _showMessage('해시태그를 선택해주세요.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final examId = await ApiClient.instance.createExam(
        ranges: [
          ExamRangeRequest(key: 'range-0', tags: tags),
        ],
        difficultyTier: _difficultyTierFromSlider(),
        questionCount: questionCount,
      );
      if (!mounted) {
        return;
      }
      if (_saveToLibrary) {
        try {
          await ExamPaperStore.add(
            ExamPaperEntry(
              examId: examId,
              questionCount: questionCount,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              paperType: _paperTypeKey(_paperType),
            ),
          );
        } catch (_) {
          _showMessage('문서고 저장에 실패했습니다.');
        }
      }
      Navigator.of(context).pop(
        ExamBuildResult(
          examId: examId,
          questionCount: questionCount,
        ),
      );
    } catch (_) {
      _showMessage('시험지 생성에 실패했습니다.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
    final selectedCount = _selectedLeafTags().length;
    final nodes = _filteredNodes(_tagTree);
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
              const Text(
                '시험지 설정',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
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
                    onPressed: _submitting
                        ? null
                        : () {
                            final value = _parseQuestionCount();
                            if (value <= _minExamQuestionCount) return;
                            setState(() => _setQuestionCount(value - 1));
                          },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _questionCountController,
                      enabled: !_submitting,
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
                        if (parsed < _minExamQuestionCount) {
                          _setQuestionCount(_minExamQuestionCount);
                        } else if (parsed > _maxExamQuestionCount) {
                          _setQuestionCount(_maxExamQuestionCount);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: _submitting
                        ? null
                        : () {
                            final value = _parseQuestionCount();
                            if (value >= _maxExamQuestionCount) return;
                            setState(() => _setQuestionCount(value + 1));
                          },
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_minExamQuestionCount}~${_maxExamQuestionCount}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '시험지 종류',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _ExamPaperType.values.map((type) {
                  final selected = _paperType == type;
                  return ChoiceChip(
                    label: Text(
                      _paperTypeLabel(type),
                      style: TextStyle(
                        fontSize: 12,
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    selected: selected,
                    onSelected: _submitting
                        ? null
                        : (_) => setState(() => _paperType = type),
                    selectedColor: const Color(0xFF1B402B),
                    backgroundColor: const Color(0xFFEFEFEF),
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                '난이도 설정',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                '현재 난이도 ${_difficultyLabelFor(_difficultyTierFromSlider())}',
              ),
              Slider(
                value: _difficultyValue,
                min: 1,
                max: 5,
                divisions: 4,
                label: _difficultyLabelFor(_difficultyTierFromSlider()),
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _difficultyValue = value),
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
              Text(
                '선택된 해시태그 수: $selectedCount',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '문서고에 저장',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Switch.adaptive(
                    value: _saveToLibrary,
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() => _saveToLibrary = value),
                    activeColor: const Color(0xFF1B402B),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '해시태그',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tagSearchController,
                decoration: const InputDecoration(
                  hintText: '해시태그 검색',
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _tagQuery = value),
              ),
              const SizedBox(height: 8),
              Container(
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
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _submitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submitExam,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B402B),
                      foregroundColor: Colors.white,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('시험 풀기'),
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
