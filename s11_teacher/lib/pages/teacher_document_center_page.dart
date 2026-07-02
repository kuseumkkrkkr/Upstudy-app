import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../shared/ui/ios26/ios26_chrome.dart';
import '../widgets/design_tokens.dart';

class TeacherDocumentCenterPage extends StatefulWidget {
  const TeacherDocumentCenterPage({super.key});

  static const routeName = '/teacher-documents';

  @override
  State<TeacherDocumentCenterPage> createState() =>
      _TeacherDocumentCenterPageState();
}

class _TeacherDocumentCenterPageState extends State<TeacherDocumentCenterPage> {
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _documents = const [];
  String _selectedFolder = '전체';
  Map<String, dynamic>? _selectedDocument;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ApiClient.instance.listTeacherDocuments(
        type: 'textbook',
      );
      if (!mounted) return;
      setState(() {
        _documents = items;
        _selectedDocument = items.isEmpty ? null : items.first;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<String> get _folders {
    final folders = <String>{'전체'};
    for (final document in _documents) {
      final folder = _text(document['category'], '미분류');
      if (folder.isNotEmpty) folders.add(folder);
    }
    return folders.toList()..sort((a, b) => a == '전체' ? -1 : a.compareTo(b));
  }

  List<Map<String, dynamic>> get _filteredDocuments {
    final query = _searchController.text.trim().toLowerCase();
    return _documents
        .where((document) {
          final folder = _text(document['category'], '미분류');
          if (_selectedFolder != '전체' && folder != _selectedFolder) {
            return false;
          }
          if (query.isEmpty) return true;
          final text = [
            document['title'],
            document['subtitle'],
            document['category'],
            document['tags'],
          ].map(_text).join(' ').toLowerCase();
          return text.contains(query);
        })
        .toList(growable: false);
  }

  String _text(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _documentId(Map<String, dynamic>? document) {
    if (document == null) return '';
    return _text(
      document['textbook_id'],
      _text(document['document_id'], _text(document['id'])),
    );
  }

  void _selectDocument(Map<String, dynamic> document) {
    final compact = MediaQuery.of(context).size.width < 980;
    setState(() => _selectedDocument = document);
    if (!compact) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: _DocumentDetail(document: document),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F4),
      body: SafeArea(
        child: Column(
          children: [
            Ios26TopBar(
              brandColor: kCourseGreen,
              title: '문서함',
              onBack: () => Navigator.of(context).maybePop(),
              onMenu: () {},
              items: const [
                Ios26NavItem(label: '교재', active: true),
                Ios26NavItem(label: '권한 참조'),
              ],
              trailingIcons: [
                Ios26ActionIcon(
                  icon: Icons.refresh_rounded,
                  label: '새로고침',
                  onTap: _loadDocuments,
                ),
              ],
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _loadDocuments);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1040;
        return Row(
          children: [
            SizedBox(
              width: wide ? 250 : 178,
              child: _FolderRail(
                folders: _folders,
                selectedFolder: _selectedFolder,
                onChanged: (folder) => setState(() => _selectedFolder = folder),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  _DocumentHero(
                    documentCount: _documents.length,
                    folderCount: _folders.length - 1,
                    linkedCount: _documents
                        .where(
                          (d) =>
                              _int(
                                d['linked_course_count'] ?? d['course_count'],
                              ) >
                              0,
                        )
                        .length,
                    minuteCount: _documents.fold<int>(
                      0,
                      (sum, d) =>
                          sum + _int(d['duration_minutes'] ?? d['min_minutes']),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '교재명, 태그, 폴더 검색',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.86),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: _buildDocumentList()),
                ],
              ),
            ),
            if (wide)
              SizedBox(
                width: 360,
                child: _RightPanel(document: _selectedDocument),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDocumentList() {
    final documents = _filteredDocuments;
    if (documents.isEmpty) {
      return const Center(child: Text('표시할 교재가 없습니다.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: documents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final document = documents[index];
        return _DocumentTile(
          document: document,
          selected: _documentId(document) == _documentId(_selectedDocument),
          onTap: () => _selectDocument(document),
        );
      },
    );
  }
}

class _FolderRail extends StatelessWidget {
  const _FolderRail({
    required this.folders,
    required this.selectedFolder,
    required this.onChanged,
  });

  final List<String> folders;
  final String selectedFolder;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 10, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        border: Border(
          right: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 10),
            child: Text(
              '분류',
              style: TextStyle(
                color: kCourseGreen,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: folders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final folder = folders[index];
                final active = folder == selectedFolder;
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onChanged(folder),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? kCourseGreen.withValues(alpha: 0.10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          folder == '전체'
                              ? Icons.inventory_2_outlined
                              : Icons.folder_outlined,
                          color: kCourseGreen,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            folder,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: kCourseGreen,
                              fontWeight: active
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentHero extends StatelessWidget {
  const _DocumentHero({
    required this.documentCount,
    required this.folderCount,
    required this.linkedCount,
    required this.minuteCount,
  });

  final int documentCount;
  final int folderCount;
  final int linkedCount;
  final int minuteCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Ios26FrostedCard(
        radius: 26,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '교재를 복사하지 않고 권한으로 연결합니다',
              style: TextStyle(
                color: kCourseGreen,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '이 문서함은 교사용 코스 생성에서 사용할 교재만 보여줍니다.',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.58)),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricPill(
                  icon: Icons.menu_book_rounded,
                  label: '교재',
                  value: '$documentCount개',
                ),
                _MetricPill(
                  icon: Icons.folder_rounded,
                  label: '폴더',
                  value: '$folderCount개',
                ),
                _MetricPill(
                  icon: Icons.link_rounded,
                  label: '코스 연결',
                  value: '$linkedCount개',
                ),
                _MetricPill(
                  icon: Icons.timer_rounded,
                  label: '분량',
                  value: '$minuteCount분',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8F4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: kCourseGreen),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.document,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> document;
  final bool selected;
  final VoidCallback onTap;

  String _text(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final title = _text(document['title'], '제목 없음');
    final subtitle = _text(document['subtitle'], '설명 없음');
    final category = _text(document['category'], '미분류');
    final id = _text(document['textbook_id'], _text(document['id'], '-'));
    final minutes = _int(
      document['duration_minutes'] ?? document['min_minutes'],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ios26FrostedCard(
          radius: 22,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kCourseLightGreen.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: kCourseGreen,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: kCourseGreen,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (selected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: kCourseLightGreen,
                            size: 18,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.58),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniChip(label: category, icon: Icons.folder_outlined),
                        _MiniChip(
                          label: minutes > 0 ? '$minutes분' : '시간 미지정',
                          icon: Icons.timer_outlined,
                        ),
                        _MiniChip(label: id, icon: Icons.key_rounded),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: kCourseGreen),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8F4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: kCourseGreen),
          const SizedBox(width: 4),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel({required this.document});

  final Map<String, dynamic>? document;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      child: Column(
        children: [
          const _HowToUsePanel(),
          const SizedBox(height: 12),
          Expanded(child: _DocumentDetail(document: document)),
        ],
      ),
    );
  }
}

class _HowToUsePanel extends StatelessWidget {
  const _HowToUsePanel();

  @override
  Widget build(BuildContext context) {
    return Ios26FrostedCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _PanelHeader(icon: Icons.help_outline_rounded, title: '문서함 사용방법'),
          SizedBox(height: 12),
          _GuideStep(number: '1', text: '교재를 선택해 ID와 분량을 확인합니다.'),
          _GuideStep(number: '2', text: '코스 생성에서 교재 보기 모듈을 추가합니다.'),
          _GuideStep(number: '3', text: '문서함 교재를 연결하고 페이지 범위와 최소 시간을 설정합니다.'),
          _GuideStep(number: '4', text: '학생은 코스 전용 리더에서만 해당 교재를 열람합니다.'),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: kCourseGreen,
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentDetail extends StatelessWidget {
  const _DocumentDetail({required this.document});

  final Map<String, dynamic>? document;

  String _text(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final item = document;
    if (item == null) {
      return const Ios26FrostedCard(
        radius: 24,
        child: Center(child: Text('교재를 선택하세요.')),
      );
    }
    final title = _text(item['title'], '제목 없음');
    final subtitle = _text(item['subtitle'], '설명 없음');
    final id = _text(
      item['textbook_id'],
      _text(item['document_id'], _text(item['id'], '-')),
    );
    final category = _text(item['category'], '미분류');
    final from = _int(item['page_from']);
    final to = _int(item['page_to']);
    final minMinutes = _int(item['min_minutes'] ?? item['duration_minutes']);
    final tags = item['tags'] is List
        ? (item['tags'] as List).map((e) => e.toString()).toList()
        : _text(item['tags'])
              .split(',')
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toList();

    return Ios26FrostedCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: ListView(
        children: [
          const _PanelHeader(icon: Icons.article_rounded, title: '교재 상세'),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: kCourseGreen,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.62),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          _DetailRow(label: '교재 ID', value: id),
          _DetailRow(label: '분류', value: category),
          _DetailRow(
            label: '페이지',
            value: from > 0 && to > 0 ? '$from-$to' : '미지정',
          ),
          _DetailRow(
            label: '최소 시간',
            value: minMinutes > 0 ? '$minMinutes분' : '미지정',
          ),
          const _DetailRow(label: '저장 방식', value: '권한 참조'),
          const SizedBox(height: 14),
          const Text('태그', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags.isEmpty
                ? const [Chip(label: Text('태그 없음'))]
                : tags.map((tag) => Chip(label: Text(tag))).toList(),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: kCourseGreen),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: kCourseGreen,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.56),
                fontSize: 12,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kCourseGreen,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Ios26FrostedCard(
        radius: 24,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
