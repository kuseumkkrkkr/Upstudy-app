import 'package:flutter/material.dart';
import '../models/concept_tag.dart';

class ConceptTagDialog extends StatefulWidget {
  final Function(List<ConceptTag>) onTagsSelected;

  const ConceptTagDialog({super.key, required this.onTagsSelected});

  @override
  State<ConceptTagDialog> createState() => _ConceptTagDialogState();
}

class _ConceptTagDialogState extends State<ConceptTagDialog> {
  late List<ConceptTag> tags;
  final List<ConceptTag> selectedTags = [];
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    // 깊은 복사를 통해 데이터 구조 복제
    tags = _deepCopyTags(conceptTagData);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<ConceptTag> _deepCopyTags(List<ConceptTag> originalTags) {
    return originalTags
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

  void _toggleTagSelection(ConceptTag tag) {
    setState(() {
      tag.isSelected = !tag.isSelected;

      if (tag.isSelected) {
        selectedTags.insert(0, tag);
      } else {
        selectedTags.removeWhere((t) => t.name == tag.name);
      }
    });
  }

  void _toggleExpanded(ConceptTag tag) {
    setState(() {
      tag.isExpanded = !tag.isExpanded;
    });
  }

  List<ConceptTag> _getFilteredTags(List<ConceptTag> tagsToFilter) {
    if (searchQuery.isEmpty) {
      return tagsToFilter;
    }

    List<ConceptTag> filtered = [];
    for (var tag in tagsToFilter) {
      bool matches = tag.displayName.toLowerCase().contains(
        searchQuery.toLowerCase(),
      );

      List<ConceptTag> filteredChildren = _getFilteredTags(tag.children);

      if (matches || filteredChildren.isNotEmpty) {
        filtered.add(
          ConceptTag(
            name: tag.name,
            displayName: tag.displayName,
            children: filteredChildren,
            isExpanded: matches || filteredChildren.isNotEmpty,
            isSelected: tag.isSelected,
          ),
        );
      }
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filteredTags = _getFilteredTags(tags);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF777777),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '개념 태그 선택',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 검색 바
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: searchController,
                onChanged: (value) {
                  setState(() => searchQuery = value);
                },
                decoration: InputDecoration(
                  hintText: '태그 검색...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
            ),

            // 선택된 태그 표시 (최상단)
            if (selectedTags.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: Colors.blue[50],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '선택됨:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: selectedTags
                          .map(
                            (tag) => Chip(
                              label: Text(tag.displayName),
                              onDeleted: () => _toggleTagSelection(tag),
                              backgroundColor: Colors.blue[100],
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),

            // 태그 트리 리스트
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildTagTree(filteredTags),
                ),
              ),
            ),

            // 확인/취소 버튼
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      widget.onTagsSelected(selectedTags);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF777777),
                    ),
                    child: const Text(
                      '확인',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagTree(List<ConceptTag> tagsToRender, {int depth = 0}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: tagsToRender.map((tag) {
        final hasChildren = tag.children.isNotEmpty;

        return Padding(
          padding: EdgeInsets.only(left: depth * 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 화살표 버튼 (자식이 있을 때만)
                  if (hasChildren)
                    IconButton(
                      icon: Icon(
                        tag.isExpanded
                            ? Icons.arrow_drop_down
                            : Icons.arrow_right,
                        size: 20,
                      ),
                      onPressed: () => _toggleExpanded(tag),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    )
                  else
                    const SizedBox(width: 36),

                  // 체크박스
                  Checkbox(
                    value: tag.isSelected,
                    onChanged: (_) => _toggleTagSelection(tag),
                  ),

                  // 태그 텍스트
                  Expanded(
                    child: Text(
                      tag.displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              // 자식 태그 렌더링
              if (hasChildren && tag.isExpanded)
                _buildTagTree(tag.children, depth: depth + 1),

              const SizedBox(height: 4),
            ],
          ),
        );
      }).toList(),
    );
  }
}
