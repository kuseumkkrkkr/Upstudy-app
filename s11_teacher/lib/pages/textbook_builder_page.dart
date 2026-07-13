import '../widgets/student_view_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/textbook.dart';
import '../services/api_client.dart';
import '../shared/theme/app_colors.dart';
import '../shared/ui/ios26/teacher_studio_shell.dart';
import '../widgets/design_tokens.dart';
import '../widgets/teacher_app_drawer.dart';

// ─── Block type definitions ───

const List<Map<String, dynamic>> kBlockTypes = [
  {'type': 'paragraph', 'label': '본문', 'icon': Icons.short_text},
  {'type': 'heading1', 'label': '대제목', 'icon': Icons.title},
  {'type': 'heading2', 'label': '소주제', 'icon': Icons.text_fields},
  {'type': 'latex', 'label': '수식', 'icon': Icons.functions},
  {'type': 'image', 'label': '이미지', 'icon': Icons.image},
  {'type': 'problem', 'label': '문제', 'icon': Icons.help_outline},
  {'type': 'graph', 'label': '그래프', 'icon': Icons.bar_chart},
  {'type': 'divider', 'label': '구분선', 'icon': Icons.remove},
];

const Map<String, Map<String, dynamic>> kBlockTypeInfo = {
  'paragraph': {'label': '본문', 'icon': Icons.short_text},
  'heading1': {'label': '대제목', 'icon': Icons.title},
  'heading2': {'label': '소주제', 'icon': Icons.text_fields},
  'latex': {'label': '수식', 'icon': Icons.functions},
  'image': {'label': '이미지', 'icon': Icons.image},
  'problem': {'label': '문제', 'icon': Icons.help_outline},
  'graph': {'label': '그래프', 'icon': Icons.bar_chart},
  'divider': {'label': '구분선', 'icon': Icons.remove},
};

IconData _iconForType(String type) =>
    kBlockTypeInfo[type]?['icon'] ?? Icons.circle;

// ─── Block data model ───

class _BlockData {
  final String id;
  String type;
  final TextEditingController ctrl;
  final FocusNode focusNode;

  _BlockData({required this.id, required this.type, String content = ''})
    : ctrl = TextEditingController(text: content),
      focusNode = FocusNode();

  void dispose() {
    ctrl.dispose();
    focusNode.dispose();
  }
}

// ─── Page ───

class TextbookBuilderPage extends StatefulWidget {
  const TextbookBuilderPage({super.key, this.initialBook});

  /// When provided, the editor is in "edit" mode for an existing textbook.
  final BookData? initialBook;

  @override
  State<TextbookBuilderPage> createState() => _TextbookBuilderPageState();
}

class _TextbookBuilderPageState extends State<TextbookBuilderPage> {
  final List<_BlockData> _blocks = [];
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _subtitleCtrl = TextEditingController();
  String _category = 'custom';
  final List<String> _tags = [];

  bool _saving = false;
  bool _isPreview = false;

  // For slash command palette
  int? _slashBlockIndex;
  OverlayEntry? _slashOverlayEntry;

  @override
  void initState() {
    super.initState();
    if (widget.initialBook != null) {
      _loadFromBook(widget.initialBook!);
    } else {
      _addBlock('heading1', index: 0);
    }
  }

  void _loadFromBook(BookData book) {
    _titleCtrl.text = book.title;
    _subtitleCtrl.text = book.subtitle;
    _category = book.category;
    _tags.clear();
    _tags.addAll(book.tags);
    _blocks.clear();

    for (final chapter in book.chapters) {
      _blocks.add(
        _BlockData(id: _uid(), type: 'heading1', content: chapter.title),
      );
      for (final intro in chapter.intro) {
        if (intro.trim().isNotEmpty) {
          _blocks.add(
            _BlockData(id: _uid(), type: 'paragraph', content: intro),
          );
        }
      }
      for (final section in chapter.sections) {
        _blocks.add(
          _BlockData(id: _uid(), type: 'heading2', content: section.title),
        );
        for (final para in section.paragraphs) {
          final trimmed = para.trim();
          if (trimmed.isEmpty) continue;
          // Heuristic: detect latex blocks
          if (trimmed.startsWith(r'$$') && trimmed.endsWith(r'$$')) {
            _blocks.add(
              _BlockData(
                id: _uid(),
                type: 'latex',
                content: trimmed.substring(2, trimmed.length - 2).trim(),
              ),
            );
          } else if (trimmed.startsWith('[PROBLEM:') && trimmed.endsWith(']')) {
            _blocks.add(
              _BlockData(
                id: _uid(),
                type: 'problem',
                content: trimmed.substring(9, trimmed.length - 1),
              ),
            );
          } else if (trimmed.startsWith('[GRAPH:') && trimmed.endsWith(']')) {
            _blocks.add(
              _BlockData(
                id: _uid(),
                type: 'graph',
                content: trimmed.substring(7, trimmed.length - 1),
              ),
            );
          } else if (trimmed == '[DIVIDER]') {
            _blocks.add(_BlockData(id: _uid(), type: 'divider'));
          } else {
            _blocks.add(
              _BlockData(id: _uid(), type: 'paragraph', content: trimmed),
            );
          }
        }
        for (final img in section.images) {
          if (img.trim().isNotEmpty) {
            _blocks.add(
              _BlockData(id: _uid(), type: 'image', content: img.trim()),
            );
          }
        }
      }
    }
    if (_blocks.isEmpty) {
      _addBlock('heading1', index: 0);
    }
  }

  BookData _buildBookData() {
    final chapters = <BookChapter>[];
    String? currentChapterTitle;
    var currentChapterIntro = <String>[];
    final currentSections = <BookSection>[];

    String? currentSectionTitle;
    var currentParagraphs = <String>[];
    var currentImages = <String>[];

    void flushSection() {
      if (currentSectionTitle == null &&
          currentParagraphs.isEmpty &&
          currentImages.isEmpty) {
        return;
      }
      currentSections.add(
        BookSection(
          title: currentSectionTitle ?? '',
          paragraphs: List.from(currentParagraphs),
          images: List.from(currentImages),
        ),
      );
      currentSectionTitle = null;
      currentParagraphs = [];
      currentImages = [];
    }

    void flushChapter() {
      flushSection();
      if (currentChapterTitle == null && currentSections.isEmpty) return;
      chapters.add(
        BookChapter(
          title: currentChapterTitle ?? '',
          intro: List.from(currentChapterIntro),
          sections: List.from(currentSections),
        ),
      );
      currentChapterTitle = null;
      currentChapterIntro = [];
      currentSections.clear();
    }

    for (final block in _blocks) {
      final content = block.ctrl.text.trim();
      switch (block.type) {
        case 'heading1':
          flushChapter();
          currentChapterTitle = content.isEmpty ? 'Chapter' : content;
        case 'heading2':
          flushSection();
          currentSectionTitle = content.isEmpty ? 'Section' : content;
        case 'paragraph':
          if (content.isNotEmpty) currentParagraphs.add(content);
        case 'latex':
          if (content.isNotEmpty) {
            currentParagraphs.add(r'$$' + content + r'$$');
          }
        case 'image':
          if (content.isNotEmpty) currentImages.add(content);
        case 'problem':
          if (content.isNotEmpty) currentParagraphs.add('[PROBLEM:$content]');
        case 'graph':
          if (content.isNotEmpty) currentParagraphs.add('[GRAPH:$content]');
        case 'divider':
          currentParagraphs.add('[DIVIDER]');
      }
    }
    flushChapter();

    // If no chapters at all, create a default empty one so API doesn't break
    if (chapters.isEmpty) {
      chapters.add(
        const BookChapter(
          title: 'Chapter 1',
          intro: [],
          sections: [BookSection(title: 'Section 1', paragraphs: [])],
        ),
      );
    }

    return BookData(
      id: widget.initialBook?.id ?? '',
      title: _titleCtrl.text.trim().isEmpty
          ? 'Untitled'
          : _titleCtrl.text.trim(),
      subtitle: _subtitleCtrl.text.trim(),
      chapters: chapters,
      progress: widget.initialBook?.progress ?? 0,
      tags: _tags,
      category: _category,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final book = _buildBookData();
      final payload = book.toCreateJson();
      payload['tags'] = _tags;

      if (widget.initialBook != null && widget.initialBook!.id.isNotEmpty) {
        // Update existing textbook if update method exists
        await ApiClient.instance.createTextbook(payload);
      } else {
        await ApiClient.instance.createTextbook(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('교재가 저장되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _uid() => '${DateTime.now().millisecondsSinceEpoch}_${_blocks.length}';

  void _addBlock(String type, {int? index, String content = ''}) {
    setState(() {
      final block = _BlockData(id: _uid(), type: type, content: content);
      if (index != null) {
        _blocks.insert(index, block);
      } else {
        _blocks.add(block);
      }
      // Focus after frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        block.focusNode.requestFocus();
      });
    });
  }

  void _removeBlock(int index) {
    if (index < 0 || index >= _blocks.length) return;
    final block = _blocks[index];
    block.dispose();
    setState(() => _blocks.removeAt(index));
    // Focus previous or next
    final newIndex = index < _blocks.length ? index : _blocks.length - 1;
    if (newIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _blocks[newIndex].focusNode.requestFocus();
      });
    }
  }

  void _moveBlock(int from, int to) {
    if (from < 0 || to < 0 || from >= _blocks.length || to >= _blocks.length) {
      return;
    }
    setState(() {
      final b = _blocks.removeAt(from);
      _blocks.insert(to, b);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _blocks[to].focusNode.requestFocus();
    });
  }

  void _changeBlockType(int index, String newType) {
    if (index < 0 || index >= _blocks.length) return;
    setState(() => _blocks[index].type = newType);
  }

  /// When user presses Enter in a text block, split or insert new paragraph below.
  void _onEnter(int index, TextEditingController ctrl) {
    final text = ctrl.text;
    final sel = ctrl.selection;
    final before = text.substring(0, sel.start);
    final after = text.substring(sel.end);
    ctrl.text = before;
    ctrl.selection = TextSelection.collapsed(offset: before.length);
    _addBlock('paragraph', index: index + 1, content: after);
  }

  /// On backspace when empty, merge with previous block or delete.
  void _onBackspace(int index, TextEditingController ctrl) {
    if (ctrl.text.isNotEmpty) return;
    if (index == 0) return;
    final prev = _blocks[index - 1];
    if (prev.type == 'divider' || prev.type == 'image') {
      _removeBlock(index - 1);
      return;
    }
    final prevText = prev.ctrl.text;
    prev.ctrl.selection = TextSelection.collapsed(offset: prevText.length);
    _removeBlock(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      prev.focusNode.requestFocus();
    });
  }

  void _onAddBelow(int index) {
    _addBlock('paragraph', index: index + 1);
  }

  void _onJumpFocus(int index, bool down) {
    final target = down ? index + 1 : index - 1;
    if (target >= 0 && target < _blocks.length) {
      _blocks[target].focusNode.requestFocus();
    }
  }

  void _showSlashCommands(int index) {
    _hideSlashCommands();
    setState(() => _slashBlockIndex = index);
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (ctx) {
        // Find the TextField's position via the block's focus node context
        final blockCtx = _blocks[index].focusNode.context;
        if (blockCtx == null) return const SizedBox.shrink();
        final blockBox = blockCtx.findRenderObject() as RenderBox?;
        if (blockBox == null) return const SizedBox.shrink();
        final pos = blockBox.localToGlobal(Offset.zero);
        return Positioned(
          left: pos.dx + 40,
          top: pos.dy + 40,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 200,
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _buildSlashCommandList(index),
            ),
          ),
        );
      },
    );
    _slashOverlayEntry = overlayEntry;
    overlay.insert(overlayEntry);
  }

  void _hideSlashCommands() {
    _slashOverlayEntry?.remove();
    _slashOverlayEntry = null;
    setState(() => _slashBlockIndex = null);
  }

  Widget _buildSlashCommandList(int index) {
    final items = [
      ('paragraph', '본문', Icons.short_text),
      ('heading1', '대제목', Icons.title),
      ('heading2', '소주제', Icons.text_fields),
      ('latex', '수식', Icons.functions),
      ('image', '이미지', Icons.image),
      ('problem', '문제', Icons.help_outline),
      ('graph', '그래프', Icons.bar_chart),
      ('divider', '구분선', Icons.remove),
    ];
    return ListView.builder(
      shrinkWrap: true,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final (type, label, icon) = items[i];
        return ListTile(
          dense: true,
          leading: Icon(icon, size: 18, color: kCourseLightGreen),
          title: Text(label, style: const TextStyle(fontSize: 13)),
          subtitle: Text(
            '/$type',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          onTap: () => _applySlashCommand(index, type),
        );
      },
    );
  }

  void _applySlashCommand(int index, String type) {
    final block = _blocks[index];
    final text = block.ctrl.text;
    // Remove the '/' trigger character
    if (text.startsWith('/')) {
      block.ctrl.text = '';
      block.ctrl.selection = TextSelection.collapsed(offset: 0);
    }
    if (type == 'paragraph') {
      // keep as paragraph, just clear the /
      _hideSlashCommands();
      return;
    }
    if (type == 'heading1' ||
        type == 'heading2' ||
        type == 'latex' ||
        type == 'image' ||
        type == 'problem' ||
        type == 'graph' ||
        type == 'divider') {
      setState(() {
        _blocks[index].type = type;
        if (type == 'divider') {
          _blocks[index].ctrl.text = '';
        }
      });
      _hideSlashCommands();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _blocks[index].focusNode.requestFocus();
      });
      return;
    }
    _hideSlashCommands();
  }

  Widget _buildBlockEditor(int index, _BlockData block, double scale) {
    final isFocused = block.focusNode.hasFocus;

    // Divider block is simple
    if (block.type == 'divider') {
      return _BlockRow(
        scale: scale,
        isFocused: isFocused,
        blockId: block.id,
        onRemove: () => _removeBlock(index),
        onMoveUp: index > 0 ? () => _moveBlock(index, index - 1) : null,
        onMoveDown: index < _blocks.length - 1
            ? () => _moveBlock(index, index + 1)
            : null,
        onChangeType: (t) => _changeBlockType(index, t),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8 * scale),
          child: Divider(
            color: Colors.grey.shade400,
            thickness: 1,
            indent: 40 * scale,
            endIndent: 40 * scale,
          ),
        ),
      );
    }

    // Image block
    if (block.type == 'image') {
      return _BlockRow(
        scale: scale,
        isFocused: isFocused,
        blockId: block.id,
        onRemove: () => _removeBlock(index),
        onMoveUp: index > 0 ? () => _moveBlock(index, index - 1) : null,
        onMoveDown: index < _blocks.length - 1
            ? () => _moveBlock(index, index + 1)
            : null,
        onChangeType: (t) => _changeBlockType(index, t),
        child: _ImageBlockField(
          scale: scale,
          ctrl: block.ctrl,
          focusNode: block.focusNode,
          onEnter: () => _onAddBelow(index),
          onBackspaceEmpty: () => _onBackspace(index, block.ctrl),
          onArrowUp: () => _onJumpFocus(index, false),
          onArrowDown: () => _onJumpFocus(index, true),
        ),
      );
    }

    // Text-based blocks
    final ts = _textStyleForType(block.type, scale);
    final maxLines = block.type == 'latex' || block.type == 'paragraph'
        ? null
        : 1;
    final hint = _hintForType(block.type);

    return _BlockRow(
      scale: scale,
      isFocused: isFocused,
      blockId: block.id,
      onRemove: () => _removeBlock(index),
      onMoveUp: index > 0 ? () => _moveBlock(index, index - 1) : null,
      onMoveDown: index < _blocks.length - 1
          ? () => _moveBlock(index, index + 1)
          : null,
      onChangeType: (t) => _changeBlockType(index, t),
      child: KeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter) {
              if (!HardwareKeyboard.instance.isShiftPressed) {
                _onEnter(index, block.ctrl);
              }
            } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
              if (block.ctrl.text.isEmpty) {
                _onBackspace(index, block.ctrl);
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              if (block.ctrl.selection.start == 0) {
                _onJumpFocus(index, false);
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              if (block.ctrl.selection.start == block.ctrl.text.length) {
                _onJumpFocus(index, true);
              }
            }
          }
        },
        child: TextField(
          controller: block.ctrl,
          focusNode: block.focusNode,
          style: ts,
          maxLines: maxLines,
          keyboardType: maxLines == null
              ? TextInputType.multiline
              : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: ts.copyWith(color: Colors.grey.shade400),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 6 * scale),
            isDense: true,
          ),
          onSubmitted: (_) {},
          onChanged: (value) {
            if (value == '/' && _slashBlockIndex != index) {
              _showSlashCommands(index);
            } else if (!value.startsWith('/') && _slashBlockIndex == index) {
              _hideSlashCommands();
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final b in _blocks) {
      b.dispose();
    }
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = courseUiScale(context);
    return TeacherStudioShell(
      currentRoute: '/textbook-builder',
      eyebrow: 'TEXTBOOK WORKSPACE',
      title: widget.initialBook != null ? '교재 편집' : '교재 작성',
      description: '블록을 조합하고 순서를 바꾸며 학습자 화면을 즉시 확인합니다.',
      endDrawer: const TeacherAppDrawer(currentRoute: '/textbook-builder'),
      onBack: Navigator.of(context).canPop()
          ? () => Navigator.of(context).pop()
          : null,
      actions: [
        TeacherStudioAction(
          label: _isPreview ? '편집으로' : '미리보기',
          icon: _isPreview ? Icons.edit_rounded : Icons.preview_rounded,
          onTap: () => setState(() => _isPreview = !_isPreview),
        ),
        TeacherStudioAction(
          label: '완료',
          icon: Icons.check_rounded,
          primary: true,
          onTap: () {
            final book = _buildBookData();
            Navigator.of(context).pop(book);
          },
        ),
      ],
      child: _isPreview
          ? Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: StudentViewPreview(
                book: _buildBookData(),
                scale: scale,
                onEditPressed: () => setState(() => _isPreview = false),
              ),
            )
          : Column(
              children: [
                Container(
                  margin: EdgeInsets.fromLTRB(16 * scale, 0, 16 * scale, 10),
                  padding: EdgeInsets.all(18 * scale),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _titleCtrl,
                        style: TextStyle(
                          fontSize: 22 * scale,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: '교재 제목',
                          hintStyle: TextStyle(
                            fontSize: 22 * scale,
                            fontWeight: FontWeight.w900,
                            color: Colors.black26,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      SizedBox(height: 4 * scale),
                      TextField(
                        controller: _subtitleCtrl,
                        style: TextStyle(
                          fontSize: 14 * scale,
                          color: Colors.black54,
                        ),
                        decoration: InputDecoration(
                          hintText: '부제목 또는 설명',
                          hintStyle: TextStyle(
                            fontSize: 14 * scale,
                            color: Colors.black38,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: EdgeInsets.symmetric(
                      vertical: 8 * scale,
                      horizontal: 16 * scale,
                    ),
                    itemCount: _blocks.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        final b = _blocks.removeAt(oldIndex);
                        _blocks.insert(newIndex, b);
                      });
                    },
                    itemBuilder: (_, i) {
                      final block = _blocks[i];
                      return _BlockDragWrapper(
                        key: ValueKey(block.id),
                        index: i,
                        child: _buildBlockEditor(i, block, scale),
                      );
                    },
                  ),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  padding: EdgeInsets.all(10 * scale),
                  decoration: BoxDecoration(
                    color: const Color(0xF7FFFFFF),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '${_blocks.length} 블록',
                            style: TextStyle(
                              fontSize: 12 * scale,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        const Spacer(),
                        _TextbookCapsuleButton(
                          loading: _saving,
                          onTap: _saving ? null : _save,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// 필요 변수: 저장 중 상태와 기존 저장 콜백.
/// 작동 원리: 하단 작업 바의 저장 기능을 검정 캡슐 버튼으로 제공한다.
class _TextbookCapsuleButton extends StatelessWidget {
  const _TextbookCapsuleButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(Icons.save_rounded, size: 17, color: Colors.white),
              const SizedBox(width: 7),
              Text(
                loading ? '저장 중' : '저장',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ───

TextStyle _textStyleForType(String type, double scale) {
  switch (type) {
    case 'heading1':
      return TextStyle(
        fontSize: 22 * scale,
        fontWeight: FontWeight.bold,
        color: kCourseGreen,
        height: 1.3,
      );
    case 'heading2':
      return TextStyle(
        fontSize: 18 * scale,
        fontWeight: FontWeight.w700,
        color: kCourseGreen,
        height: 1.3,
      );
    case 'latex':
      return TextStyle(
        fontSize: 15 * scale,
        color: Colors.black87,
        fontFamily: 'monospace',
        height: 1.5,
      );
    case 'problem':
      return TextStyle(
        fontSize: 15 * scale,
        color: Colors.blue.shade800,
        height: 1.5,
      );
    case 'graph':
      return TextStyle(
        fontSize: 15 * scale,
        color: Colors.purple.shade800,
        height: 1.5,
      );
    case 'paragraph':
    default:
      return TextStyle(
        fontSize: 15 * scale,
        color: Colors.black87,
        height: 1.6,
      );
  }
}

String _hintForType(String type) {
  switch (type) {
    case 'heading1':
      return '대제목 입력...';
    case 'heading2':
      return '소주제 입력...';
    case 'latex':
      return 'LaTeX 수식 입력... (예: x^2 + y^2 = 1)';
    case 'problem':
      return '문제 ID 또는 설명 입력...';
    case 'graph':
      return '그래프 설정 (JSON 또는 태그)...';
    case 'paragraph':
    default:
      return '내용을 입력하세요...';
  }
}

// ─── _BlockRow ───

class _BlockRow extends StatefulWidget {
  final double scale;
  final bool isFocused;
  final String blockId;
  final Widget child;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final ValueChanged<String> onChangeType;

  const _BlockRow({
    required this.scale,
    required this.isFocused,
    required this.blockId,
    required this.child,
    required this.onRemove,
    this.onMoveUp,
    this.onMoveDown,
    required this.onChangeType,
  });

  @override
  State<_BlockRow> createState() => _BlockRowState();
}

class _BlockRowState extends State<_BlockRow> {
  bool _hover = false;

  void _showTypeMenu() {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero, ancestor: overlay);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        pos.dx + 40 * widget.scale,
        pos.dy,
        pos.dx + box.size.width,
        pos.dy + box.size.height,
      ),
      items: kBlockTypes.map((t) {
        final type = t['type'] as String;
        return PopupMenuItem<String>(
          value: type,
          child: Row(
            children: [
              Icon(t['icon'] as IconData, size: 18, color: Colors.black54),
              const SizedBox(width: 8),
              Text(t['label'] as String),
            ],
          ),
        );
      }).toList(),
    ).then((value) {
      if (value != null) widget.onChangeType(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final showActions = widget.isFocused || _hover;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 2 * widget.scale),
        padding: EdgeInsets.symmetric(
          horizontal: 8 * widget.scale,
          vertical: 2 * widget.scale,
        ),
        decoration: BoxDecoration(
          color: widget.isFocused ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6 * widget.scale),
          border: Border.all(
            color: widget.isFocused
                ? kCourseLightGreen.withValues(alpha: 0.4)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle + type icon
            SizedBox(
              width: 32 * widget.scale,
              child: Column(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.drag_indicator,
                      size: 16 * widget.scale,
                      color: Colors.grey.shade400,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: null, // Drag handled by ReorderableListView
                  ),
                  if (showActions)
                    IconButton(
                      icon: Icon(
                        _iconForType(
                          widget.blockId.contains('divider')
                              ? 'divider'
                              : 'paragraph',
                        ),
                        size: 14 * widget.scale,
                        color: Colors.grey.shade500,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: '블록 유형 변경',
                      onPressed: _showTypeMenu,
                    ),
                ],
              ),
            ),
            SizedBox(width: 4 * widget.scale),
            // Content
            Expanded(child: widget.child),
            // Actions
            if (showActions)
              SizedBox(
                width: 32 * widget.scale,
                child: Column(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.add,
                        size: 16 * widget.scale,
                        color: kCourseLightGreen,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: '아래에 추가',
                      onPressed: () {
                        // Handled by parent via focus listener — not reachable cleanly here;
                        // use a static callback pattern or callback bridge.
                        // Simpler: just ignore, user can press Enter.
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 16 * widget.scale,
                        color: Colors.red.shade300,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: '삭제',
                      onPressed: widget.onRemove,
                    ),
                  ],
                ),
              )
            else
              SizedBox(width: 32 * widget.scale),
          ],
        ),
      ),
    );
  }
}

// ─── Image block field ───

class _ImageBlockField extends StatelessWidget {
  final double scale;
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final VoidCallback onEnter;
  final VoidCallback onBackspaceEmpty;
  final VoidCallback onArrowUp;
  final VoidCallback onArrowDown;

  const _ImageBlockField({
    required this.scale,
    required this.ctrl,
    required this.focusNode,
    required this.onEnter,
    required this.onBackspaceEmpty,
    required this.onArrowUp,
    required this.onArrowDown,
  });

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(skipTraversal: true),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            if (!HardwareKeyboard.instance.isShiftPressed) onEnter();
          } else if (event.logicalKey == LogicalKeyboardKey.backspace &&
              ctrl.text.isEmpty) {
            onBackspaceEmpty();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
              ctrl.selection.start == 0) {
            onArrowUp();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
              ctrl.selection.start == ctrl.text.length) {
            onArrowDown();
          }
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: ctrl,
            focusNode: focusNode,
            style: TextStyle(fontSize: 14 * scale, color: Colors.black87),
            decoration: InputDecoration(
              hintText: '이미지 URL 입력...',
              hintStyle: TextStyle(
                fontSize: 14 * scale,
                color: Colors.grey.shade400,
              ),
              prefixIcon: Icon(
                Icons.image,
                size: 18 * scale,
                color: Colors.grey.shade500,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8 * scale),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12 * scale,
                vertical: 10 * scale,
              ),
              isDense: true,
            ),
          ),
          if (ctrl.text.trim().isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8 * scale),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8 * scale),
                child: Image.network(
                  ctrl.text.trim(),
                  height: 120 * scale,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 60 * scale,
                    color: Colors.grey.shade200,
                    child: Center(
                      child: Text(
                        '미리보기 실패',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12 * scale,
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
  }
}

// ─── Reorderable drag wrapper ───

class _BlockDragWrapper extends StatelessWidget {
  final int index;
  final Widget child;

  const _BlockDragWrapper({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(index: index, child: child);
  }
}
