import 'package:flutter/material.dart';
import 'package:s11/features/textbook/ui/pages/book_page.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/business/repositories/textbook_store.dart';

class TextbookCreationPage extends StatelessWidget {
  const TextbookCreationPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1B402B);
    return Scaffold(
      appBar: AppBar(
        title: const Text('교재 만들기'),
        backgroundColor: Colors.white,
        foregroundColor: primary,
        elevation: 0.5,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '생성 방식 선택',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _CreationCard(
              icon: Icons.auto_awesome,
              title: 'AI 집필',
              subtitle: 'AI가 대제목/소주제를 구성합니다',
              trailing: const Icon(Icons.lock_outline),
              enabled: false,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('AI 집필은 준비중입니다.')),
                );
              },
            ),
            const SizedBox(height: 12),
            _CreationCard(
              icon: Icons.edit,
              title: '직접 집필',
              subtitle: '대제목/소주제와 내용을 직접 작성합니다',
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              enabled: true,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TextbookEditorPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'AI 집필은 추후 활성화 예정입니다.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreationCard extends StatelessWidget {
  const _CreationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF3F3F3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled ? const Color(0xFFE0E3E7) : const Color(0xFFEAEAEA),
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 4,
              color: Color(0x14000000),
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: enabled ? const Color(0xFF1B402B) : Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('교재 제목을 입력해주세요.')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('교재 저장에 실패했습니다.')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1B402B);
    return Scaffold(
      appBar: AppBar(
        title: const Text('직접 집필'),
        backgroundColor: Colors.white,
        foregroundColor: primary,
        elevation: 0.5,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '저장',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
          ],
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
            const Text(
              '대제목 설명',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
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
          const Text(
            '내용',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
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
          const Text(
            '이미지 URL',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
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
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _ChapterDraft {
  _ChapterDraft({required this.id, required _SectionDraft Function() sectionFactory})
      : sections = [sectionFactory()];

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
