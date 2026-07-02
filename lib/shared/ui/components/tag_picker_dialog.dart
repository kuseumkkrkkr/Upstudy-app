import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/concept_tag.dart';
import 'package:s11/shared/ui/ios26/ios26_modal.dart';

Future<List<String>?> showTagPickerDialog({
  required BuildContext context,
  List<String> initialTags = const [],
}) {
  return showIos26Modal<List<String>>(
    context: context,
    maxWidth: 760,
    maxHeight: 680,
    child: _TagPickerDialog(initialTags: initialTags),
  );
}

class _TagPickerDialog extends StatefulWidget {
  const _TagPickerDialog({required this.initialTags});

  final List<String> initialTags;

  @override
  State<_TagPickerDialog> createState() => _TagPickerDialogState();
}

class _TagPickerDialogState extends State<_TagPickerDialog> {
  late final List<ConceptTag> _tags;
  final List<ConceptTag> _selectedTags = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tags = _deepCopyTags(conceptTagData);
    _applyInitialSelection(widget.initialTags);
    _syncSelectedTags();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ConceptTag> _deepCopyTags(List<ConceptTag> source) {
    return source
        .map(
          (tag) => ConceptTag(
            name: tag.name,
            displayName: tag.displayName,
            children: tag.children.isNotEmpty ? _deepCopyTags(tag.children) : [],
            isExpanded: tag.isExpanded,
            isSelected: tag.isSelected,
          ),
        )
        .toList();
  }

  void _applyInitialSelection(List<String> initialTags) {
    if (initialTags.isEmpty) return;
    final normalized = initialTags.map(_normalizeTag).toSet();
    void visit(ConceptTag tag) {
      if (tag.children.isEmpty) {
        if (normalized.contains(_normalizeTag(tag.displayName))) {
          tag.isSelected = true;
        }
        return;
      }
      for (final child in tag.children) {
        visit(child);
      }
    }

    for (final root in _tags) {
      visit(root);
    }
  }

  String _normalizeTag(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.startsWith('#') ? trimmed : '#$trimmed';
  }

  void _toggleTagSelection(ConceptTag tag) {
    final state = _getSelectionState(tag);
    final shouldSelect = state != _SelectionState.selected;
    setState(() {
      _setSelectionRecursively(tag, shouldSelect);
      _syncSelectedTags();
    });
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

  void _syncSelectedTags() {
    _selectedTags
      ..clear()
      ..addAll(_collectSelectedLeafTags(_tags));
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

  List<_TagNode> _filteredNodes(List<ConceptTag> source) {
    if (_searchQuery.isEmpty) {
      return _buildNodes(source);
    }
    final results = <_TagNode>[];
    for (final tag in source) {
      final matches =
          tag.displayName.toLowerCase().contains(_searchQuery.toLowerCase());
      final children = _filteredNodes(tag.children);
      if (matches || children.isNotEmpty) {
        results.add(_TagNode(tag, children));
      }
    }
    return results;
  }

  List<_TagNode> _buildNodes(List<ConceptTag> source) {
    return source.map((tag) => _TagNode(tag, _buildNodes(tag.children))).toList();
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

  @override
  Widget build(BuildContext context) {
    final nodes = _filteredNodes(_tags);
    return Ios26ModalShell(
      title: '해시태그 선택',
      child: SizedBox(
        width: 720,
        height: 640,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: '해시태그 검색',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF3F5F3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Scrollbar(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [_buildTree(nodes)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final tags =
                          _selectedTags.map((tag) => tag.displayName).toList();
                      Navigator.of(context).pop(tags);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B402B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('선택 완료'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTree(List<_TagNode> nodes, {int depth = 0}) {
    return Column(
      children: nodes.map((node) {
        final tag = node.tag;
        final hasChildren = node.children.isNotEmpty;
        final selectionState = _getSelectionState(tag);
        final shouldExpand = _searchQuery.isNotEmpty || tag.isExpanded;
        return Padding(
          padding: EdgeInsets.only(left: depth * 14),
          child: Column(
            children: [
              Row(
                children: [
                  if (hasChildren)
                    IconButton(
                      icon: Icon(
                        tag.isExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                      ),
                      onPressed: () => _toggleExpanded(tag),
                    )
                  else
                    const SizedBox(width: 40),
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
                      style: const TextStyle(fontSize: 14),
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
}

enum _SelectionState { selected, unselected, partial }

class _TagNode {
  final ConceptTag tag;
  final List<_TagNode> children;

  _TagNode(this.tag, this.children);
}
