import 'package:flutter/material.dart';
import 'package:s11/features/textbook/ui/pages/book_page.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/business/repositories/textbook_store.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';

class TextbookCreationPage extends StatelessWidget {
  const TextbookCreationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StudentHtmlShell(
      title: '교재 만들기',
      activeRoute: '/bookbag',
      showContextAside: true,
      mobileBackButton: true,
      onMenu: () => Navigator.of(context).maybePop(),
      onSearch: () => showStudentQuickSearch(context),
      onNotifications: () => showStudentNotifications(context),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 36, 20, 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 876),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NEW TEXTBOOK',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF71717A),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '배운 내용을\n내 순서로 엮어보세요.',
                style: TextStyle(
                  fontSize: 38,
                  height: 1.08,
                  letterSpacing: -1.3,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF09090B),
                ),
              ),
              const SizedBox(height: 28),
              _TemplateRow(
                tag: '빠른 시작',
                title: '개념 + 예제',
                meta: '두 섹션 기본 구성',
                onSelect: () => _openEditor(context),
              ),
              _TemplateRow(
                tag: '복습',
                title: '오답 + 해설',
                meta: '오답에서 자동 수집',
                onSelect: () => _openEditor(context),
              ),
              _TemplateRow(
                tag: '직접 집필',
                title: '빈 교재',
                meta: '완전히 새로 구성',
                onSelect: () => _openEditor(context),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: () => _openEditor(context),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('빈 교재 만들기'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF09090B),
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('템플릿은 준비 중입니다.')),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF09090B),
                      shape: const RoundedRectangleBorder(),
                      side: const BorderSide(color: Color(0xFF09090B)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('템플릿으로 시작'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _openEditor(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TextbookEditorPage()));
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.tag,
    required this.title,
    required this.meta,
    required this.onSelect,
  });

  final String tag;
  final String title;
  final String meta;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFDFDFE),
        border: Border(bottom: BorderSide(color: Color(0xFFE1E1E4))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            color: const Color(0xFFF3F3F5),
            child: Text(
              tag,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  meta,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF71717A),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onSelect,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF09090B),
              shape: const RoundedRectangleBorder(),
              side: const BorderSide(color: Color(0xFFE1E1E4)),
            ),
            child: const Text('선택'),
          ),
        ],
      ),
    );
  }
}

class TextbookEditorPage extends StatefulWidget {
  const TextbookEditorPage({super.key});

  @override
  State<TextbookEditorPage> createState() => _TextbookEditorPageState();
}

class _TextbookEditorPageState extends State<TextbookEditorPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  final List<_ChapterDraft> _chapters = <_ChapterDraft>[];
  bool _saving = false;
  int _idSeed = 0;

  @override
  void initState() {
    super.initState();
    _chapters.add(_ChapterDraft(id: _newId(), sectionFactory: _newSection));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  String _newId() {
    _idSeed += 1;
    return '${DateTime.now().microsecondsSinceEpoch}_$_idSeed';
  }

  _SectionDraft _newSection() {
    return _SectionDraft(id: _newId());
  }

  void _addChapter() {
    setState(() {
      _chapters.add(_ChapterDraft(id: _newId(), sectionFactory: _newSection));
    });
  }

  void _removeChapter(_ChapterDraft chapter) {
    setState(() {
      _chapters.remove(chapter);
      if (_chapters.isEmpty) {
        _chapters.add(_ChapterDraft(id: _newId(), sectionFactory: _newSection));
      }
    });
  }

  void _undoLastChapter() {
    if (_chapters.length <= 1) return;
    setState(() => _chapters.removeLast());
  }

  void _showGraphNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('그래프 삽입은 저장 API 연결 후 사용할 수 있습니다.')),
    );
  }

  void _addSection(_ChapterDraft chapter) {
    setState(() => chapter.sections.add(_newSection()));
  }

  void _removeSection(_ChapterDraft chapter, _SectionDraft section) {
    setState(() {
      chapter.sections.remove(section);
      if (chapter.sections.isEmpty) {
        chapter.sections.add(_newSection());
      }
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('교재 제목을 입력해주세요.')));
      return;
    }

    final subtitle = _subtitleController.text.trim();
    final chapters = <BookChapter>[];
    for (var i = 0; i < _chapters.length; i++) {
      final draft = _chapters[i];
      final chapterTitle = draft.title.trim().isEmpty
          ? '대제목 ${i + 1}'
          : draft.title.trim();
      final intro = draft.intro
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList();
      final sections = <BookSection>[];
      for (var j = 0; j < draft.sections.length; j++) {
        final section = draft.sections[j];
        final sectionTitle = section.title.trim().isEmpty
            ? '소주제 ${j + 1}'
            : section.title.trim();
        final paragraphs = section.paragraphs
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toList();
        final images = section.images
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toList();
        sections.add(
          BookSection(
            title: sectionTitle,
            paragraphs: paragraphs,
            images: images,
          ),
        );
      }
      chapters.add(
        BookChapter(title: chapterTitle, intro: intro, sections: sections),
      );
    }

    final draftBook = BookData(
      id: '',
      title: title,
      subtitle: subtitle.isEmpty ? '커스텀 교재' : subtitle,
      chapters: chapters,
      category: 'custom',
    );

    setState(() => _saving = true);
    try {
      final created = await TextbookStore.create(draftBook);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => BookWidget(book: created)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('교재 저장에 실패했습니다.')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StudentHtmlShell(
      title: '교재 편집',
      activeRoute: '/bookbag',
      showContextAside: true,
      mobileBackButton: true,
      onMenu: () => Navigator.of(context).maybePop(),
      onSearch: () => showStudentQuickSearch(context),
      onNotifications: () => showStudentNotifications(context),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '교재 편집',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('저장'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _EditorTabBar(),
              const SizedBox(height: 20),
              _EditorToolbar(
                onAddChapter: _addChapter,
                onUndo: _undoLastChapter,
                onGraph: _showGraphNotice,
                onSave: _saving ? null : _save,
              ),
              const SizedBox(height: 12),
              _ChapterOutline(chapters: _chapters, onAddChapter: _addChapter),
              const SizedBox(height: 20),
              _SectionTitle(label: '교재 기본정보'),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '교재 제목',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subtitleController,
                decoration: const InputDecoration(
                  labelText: '교재 설명 (선택)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              _SectionTitle(label: '대제목 / 소주제'),
              const SizedBox(height: 8),
              for (var i = 0; i < _chapters.length; i++)
                _ChapterCard(
                  chapter: _chapters[i],
                  chapterIndex: i,
                  onRemove: () => _removeChapter(_chapters[i]),
                  onAddSection: () => _addSection(_chapters[i]),
                  onRemoveSection: (section) =>
                      _removeSection(_chapters[i], section),
                  onRefresh: () => setState(() {}),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _addChapter,
                icon: const Icon(Icons.add),
                label: const Text('대제목 추가'),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('교재 저장'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF09090B),
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('미리보기 전에 교재를 먼저 저장해주세요.')),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: const Text('미리보기'),
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

class _EditorTabBar extends StatelessWidget {
  const _EditorTabBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EditorTab(label: '편집', selected: true),
        _EditorTab(label: '태그'),
        _EditorTab(label: '시험지'),
      ],
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.onAddChapter,
    required this.onUndo,
    required this.onGraph,
    required this.onSave,
  });

  final VoidCallback onAddChapter;
  final VoidCallback onUndo;
  final VoidCallback onGraph;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: onAddChapter,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('펜'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onUndo,
          icon: const Icon(Icons.undo, size: 16),
          label: const Text('되돌리기'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onGraph,
          icon: const Icon(Icons.show_chart, size: 16),
          label: const Text('그래프'),
        ),
        const Spacer(),
        TextButton(onPressed: onSave, child: const Text('교재 저장')),
      ],
    );
  }
}

class _ChapterOutline extends StatelessWidget {
  const _ChapterOutline({required this.chapters, required this.onAddChapter});

  final List<_ChapterDraft> chapters;
  final VoidCallback onAddChapter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFFDFDFE),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFFE1E1E4))),
      ),
      child: Column(
        children: [
          for (var index = 0; index < chapters.length; index++)
            ListTile(
              dense: true,
              leading: Text(
                '${index + 1}장',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              title: Text(
                chapters[index].title.trim().isEmpty
                    ? '새 장'
                    : chapters[index].title,
              ),
              trailing: const Text('편집'),
            ),
          ListTile(
            dense: true,
            leading: const Text(
              '+',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            title: const Text('새 장 추가'),
            onTap: onAddChapter,
            trailing: const Text('추가'),
          ),
        ],
      ),
    );
  }
}

class _EditorTab extends StatelessWidget {
  const _EditorTab({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      color: selected ? const Color(0xFF09090B) : const Color(0xFFFDFDFE),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: selected ? Colors.white : const Color(0xFF09090B),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.chapter,
    required this.chapterIndex,
    required this.onRemove,
    required this.onAddSection,
    required this.onRemoveSection,
    required this.onRefresh,
  });

  final _ChapterDraft chapter;
  final int chapterIndex;
  final VoidCallback onRemove;
  final VoidCallback onAddSection;
  final ValueChanged<_SectionDraft> onRemoveSection;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '대제목 ${chapterIndex + 1}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            TextFormField(
              key: ValueKey('chapter_title_${chapter.id}'),
              initialValue: chapter.title,
              onChanged: (value) => chapter.title = value,
              decoration: const InputDecoration(
                labelText: '대제목 제목',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text('대제목 설명', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            for (var i = 0; i < chapter.intro.length; i++)
              _EditableLine(
                key: ValueKey('chapter_intro_${chapter.id}_$i'),
                value: chapter.intro[i],
                label: '설명 ${i + 1}',
                maxLines: 2,
                onChanged: (value) => chapter.intro[i] = value,
                onRemove: () {
                  chapter.intro.removeAt(i);
                  onRefresh();
                },
              ),
            TextButton.icon(
              onPressed: () {
                chapter.intro.add('');
                onRefresh();
              },
              icon: const Icon(Icons.add),
              label: const Text('설명 추가'),
            ),
            const Divider(height: 24),
            for (var i = 0; i < chapter.sections.length; i++)
              _SectionCard(
                section: chapter.sections[i],
                sectionIndex: i,
                onRemove: () => onRemoveSection(chapter.sections[i]),
                onRefresh: onRefresh,
              ),
            OutlinedButton.icon(
              onPressed: onAddSection,
              icon: const Icon(Icons.add),
              label: const Text('소주제 추가'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.sectionIndex,
    required this.onRemove,
    required this.onRefresh,
  });

  final _SectionDraft section;
  final int sectionIndex;
  final VoidCallback onRemove;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E3E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '소주제 ${sectionIndex + 1}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          TextFormField(
            key: ValueKey('section_title_${section.id}'),
            initialValue: section.title,
            onChanged: (value) => section.title = value,
            decoration: const InputDecoration(
              labelText: '소주제 제목',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          const Text('내용', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (var i = 0; i < section.paragraphs.length; i++)
            _EditableLine(
              key: ValueKey('section_paragraph_${section.id}_$i'),
              value: section.paragraphs[i],
              label: '내용 ${i + 1}',
              maxLines: 3,
              onChanged: (value) => section.paragraphs[i] = value,
              onRemove: () {
                section.paragraphs.removeAt(i);
                onRefresh();
              },
            ),
          TextButton.icon(
            onPressed: () {
              section.paragraphs.add('');
              onRefresh();
            },
            icon: const Icon(Icons.add),
            label: const Text('내용 추가'),
          ),
          const SizedBox(height: 8),
          const Text('이미지 URL', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (var i = 0; i < section.images.length; i++)
            _EditableLine(
              key: ValueKey('section_image_${section.id}_$i'),
              value: section.images[i],
              label: '이미지 URL ${i + 1}',
              onChanged: (value) => section.images[i] = value,
              onRemove: () {
                section.images.removeAt(i);
                onRefresh();
              },
            ),
          TextButton.icon(
            onPressed: () {
              section.images.add('');
              onRefresh();
            },
            icon: const Icon(Icons.add),
            label: const Text('이미지 URL 추가'),
          ),
        ],
      ),
    );
  }
}

class _EditableLine extends StatelessWidget {
  const _EditableLine({
    super.key,
    required this.value,
    required this.label,
    this.maxLines = 1,
    required this.onChanged,
    required this.onRemove,
  });

  final String value;
  final String label;
  final int maxLines;
  final ValueChanged<String> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: value,
              onChanged: onChanged,
              maxLines: maxLines,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(onPressed: onRemove, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}

class _ChapterDraft {
  _ChapterDraft({
    required this.id,
    required _SectionDraft Function() sectionFactory,
  }) : sections = [sectionFactory()];

  final String id;
  String title = '';
  List<String> intro = [''];
  final List<_SectionDraft> sections;
}

class _SectionDraft {
  _SectionDraft({required this.id});

  final String id;
  String title = '';
  List<String> paragraphs = [''];
  List<String> images = [];
}
