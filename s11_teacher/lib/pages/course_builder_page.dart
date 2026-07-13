// UTF-8 only: This file must be read/written as UTF-8.
import 'dart:convert';

import 'package:flutter/material.dart';

import '../pages/problem_editor_page.dart';
import '../services/api_client.dart';
import '../services/course_builder_payload.dart';
import '../shared/theme/app_colors.dart';
import '../shared/ui/ios26/teacher_full_face_panel.dart';
import '../shared/ui/ios26/teacher_studio_shell.dart';
import '../widgets/design_tokens.dart';
import '../widgets/teacher_app_drawer.dart';

const List<String> _moduleTypes = <String>[
  'textbook_view',
  'problem_solve',
  'exam_solve',
  'level_test',
];

const Map<String, String> _moduleLabels = <String, String>{
  'textbook_view': '교재 보기',
  'problem_solve': '문제 풀이',
  'exam_solve': '시험지 풀이',
  'level_test': '레벨 테스트',
};

class CourseBuilderPage extends StatefulWidget {
  const CourseBuilderPage({super.key, this.initialCourseId});

  final String? initialCourseId;

  @override
  State<CourseBuilderPage> createState() => _CourseBuilderPageState();
}

class _CourseBuilderPageState extends State<CourseBuilderPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _targetOvrCtrl = TextEditingController(text: '0');
  final _tagInputCtrl = TextEditingController();

  bool _advancedOpen = false;
  String _difficulty = '중';
  bool _wrongAnswerReviewEnabled = true;

  bool _loading = false;
  bool _saving = false;

  final List<String> _tags = <String>[];
  final List<String> _focusTags = <String>[];
  List<String> _availableHashTags = <String>[];
  List<String> _availableProblemTags = <String>[];

  List<Map<String, dynamic>> _textbooks = <Map<String, dynamic>>[];

  final List<_ModuleDraft> _modules = <_ModuleDraft>[];
  int _selectedModuleIndex = 0;

  bool get _isEditing => widget.initialCourseId != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _modules.add(_ModuleDraft(type: 'textbook_view'));
    _titleCtrl.addListener(_syncLevelTestTitleHint);
    _bootstrap();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.removeListener(_syncLevelTestTitleHint);
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _targetOvrCtrl.dispose();
    _tagInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final tagsFuture = ApiClient.instance.getCourseHashTags();
      final generationTagsFuture = ApiClient.instance
          .getQuestGenerationTagGroups();
      final booksFuture = ApiClient.instance.listTeacherDocuments(
        type: 'textbook',
      );
      final tags = await tagsFuture;
      final generationTagGroups = await generationTagsFuture;
      final books = await booksFuture;
      final generationTags = _tagsFromGenerationGroups(generationTagGroups);

      if (!mounted) return;
      _availableHashTags = _mergeTags(tags, generationTags);
      _availableProblemTags = generationTags.isEmpty
          ? List<String>.from(_availableHashTags)
          : generationTags;
      _textbooks = books
          .where(_isCourseSelectableTextbook)
          .toList(growable: false);

      if (_isEditing) {
        await _loadCourse();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('초기화 실패: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadCourse() async {
    final c = await ApiClient.instance.getCourseV2(widget.initialCourseId!);
    _titleCtrl.text = c['title']?.toString() ?? '';
    _descCtrl.text = c['description']?.toString() ?? '';
    _difficulty = (c['difficulty']?.toString().isNotEmpty ?? false)
        ? c['difficulty'].toString()
        : '중';
    _targetOvrCtrl.text = (c['target_ovr'] ?? 0).toString();
    final runtimeFlags = c['runtime_flags'] is Map
        ? Map<String, dynamic>.from(c['runtime_flags'] as Map)
        : const <String, dynamic>{};
    _wrongAnswerReviewEnabled =
        runtimeFlags['enable_wrong_answer_auto_insert'] != false;

    _tags
      ..clear()
      ..addAll(((c['tags'] as List?) ?? const []).map((e) => e.toString()));
    _focusTags
      ..clear()
      ..addAll(
        ((c['focus_tags'] as List?) ?? const []).map((e) => e.toString()),
      );
    _focusTags.removeWhere((t) => !_tags.contains(t));

    _modules.clear();
    final rawModules = (c['modules'] as List?) ?? const [];
    for (final raw in rawModules) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final type = m['type']?.toString() ?? '';
      if (!_moduleTypes.contains(type)) continue;
      _modules.add(_ModuleDraft.fromJson(m));
    }
    if (_modules.isEmpty) {
      _modules.add(_ModuleDraft(type: 'textbook_view'));
    }
    _selectedModuleIndex = 0;
    _normalizeSelectableTextbookSelection();
  }

  bool _isCourseSelectableTextbook(Map<String, dynamic> book) {
    return book['is_course_selectable'] != false;
  }

  List<String> _tagsFromGenerationGroups(List<Map<String, dynamic>> groups) {
    final tags = <String>[];
    final seen = <String>{};
    for (final group in groups) {
      final raw = group['tags'];
      if (raw is! List) continue;
      for (final item in raw) {
        final tag = item.toString().trim();
        if (tag.isEmpty || !seen.add(tag)) continue;
        tags.add(tag);
      }
    }
    tags.sort();
    return tags;
  }

  List<String> _mergeTags(List<String> first, List<String> second) {
    final merged = <String>[];
    final seen = <String>{};
    for (final tag in [...first, ...second]) {
      final trimmed = tag.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) continue;
      merged.add(trimmed);
    }
    return merged;
  }

  String _textbookId(Map<String, dynamic> book) {
    return (book['textbook_id'] ?? book['id'])?.toString() ?? '';
  }

  bool _hasSelectableTextbookId(String? id) {
    final target = (id ?? '').trim();
    if (target.isEmpty) return false;
    return _textbooks.any((book) => _textbookId(book) == target);
  }

  String? _dropdownTextbookValue(String? id) {
    final target = (id ?? '').trim();
    return _hasSelectableTextbookId(target) ? target : null;
  }

  void _normalizeSelectableTextbookSelection() {
    for (final module in _modules) {
      if (module.type == 'textbook_view' &&
          module.textbookId.trim().isNotEmpty &&
          !_hasSelectableTextbookId(module.textbookId)) {
        module.textbookId = '';
      }
    }
  }

  void _addTag() {
    final tag = _tagInputCtrl.text.trim();
    if (tag.isEmpty) return;
    if (!_tags.contains(tag)) {
      setState(() => _tags.add(tag));
    }
    _tagInputCtrl.clear();
  }

  void _addModule() {
    setState(() {
      _modules.add(_ModuleDraft(type: 'problem_solve'));
      _selectedModuleIndex = _modules.length - 1;
    });
  }

  void _syncLevelTestTitleHint() {
    if (_isEditing || _modules.length != 1) return;
    final title = _titleCtrl.text.replaceAll(' ', '');
    if (!title.contains('레벨테스트') && !title.contains('레테')) return;
    final module = _modules.first;
    final isUntouchedDefault =
        module.type == 'textbook_view' &&
        module.title.trim().isEmpty &&
        module.textbookId.trim().isEmpty;
    if (!isUntouchedDefault) return;
    setState(() {
      module.type = 'level_test';
      module.title = '레벨 테스트';
      module.description = '시험지 기반 레벨 테스트';
      module.passRate = 100;
    });
  }

  void _removeModule(int index) {
    if (_modules.length <= 1) return;
    setState(() {
      _modules.removeAt(index);
      if (_selectedModuleIndex >= _modules.length) {
        _selectedModuleIndex = _modules.length - 1;
      } else if (_selectedModuleIndex > index) {
        _selectedModuleIndex -= 1;
      }
    });
  }

  void _moveModule(int from, int to) {
    if (from == to || to < 0 || to >= _modules.length) return;
    setState(() {
      final item = _modules.removeAt(from);
      _modules.insert(to, item);
      if (_selectedModuleIndex == from) {
        _selectedModuleIndex = to;
      } else if (from < _selectedModuleIndex && to >= _selectedModuleIndex) {
        _selectedModuleIndex -= 1;
      } else if (from > _selectedModuleIndex && to <= _selectedModuleIndex) {
        _selectedModuleIndex += 1;
      }
    });
  }

  List<String> _splitCsv(String value) {
    return value
        .split(RegExp(r'[,#\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _questIdOf(Map<String, dynamic> item) {
    return (item['quest_id'] ?? item['id'] ?? '').toString();
  }

  String _questTitleOf(Map<String, dynamic> item) {
    final raw =
        item['quest_title_text'] ??
        item['title'] ??
        item['quest_title'] ??
        item['content'];
    final normalized = _contentTextOf(raw);
    if (normalized.isNotEmpty) return normalized;
    return _questIdOf(item).isEmpty ? '문제' : _questIdOf(item);
  }

  String _questBodyOf(Map<String, dynamic> item) {
    final raw =
        item['quest_answer_text'] ??
        item['subtitle'] ??
        item['description'] ??
        item['content'];
    final normalized = _contentTextOf(raw);
    if (normalized.isNotEmpty) return normalized;
    final tags = item['hash_tags'];
    if (tags is List && tags.isNotEmpty) {
      return tags.map((tag) => tag.toString()).join(', ');
    }
    return '미리보기 없음';
  }

  String _examIdOf(Map<String, dynamic> item) {
    return (item['exam_id'] ?? item['document_id'] ?? item['id'] ?? '')
        .toString();
  }

  String _examTitleOf(Map<String, dynamic> item) {
    final title = item['title']?.toString().trim() ?? '';
    return title.isEmpty ? '시험지' : title;
  }

  String _examSubtitleOf(Map<String, dynamic> item) {
    final subtitle = item['subtitle']?.toString().trim() ?? '';
    if (subtitle.isNotEmpty) return subtitle;
    final itemCount = item['item_count'];
    if (itemCount is num && itemCount > 0) {
      return '${itemCount.toInt()}문항';
    }
    return '상세 정보 없음';
  }

  String _contentTextOf(dynamic raw) {
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return '';
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          return _contentTextOf(jsonDecode(trimmed));
        } catch (_) {}
      }
      return trimmed;
    }
    if (raw is Map) {
      final blocks = raw['blocks'];
      if (blocks is List) {
        return blocks
            .whereType<Map>()
            .map((block) => block['content']?.toString().trim() ?? '')
            .where((text) => text.isNotEmpty)
            .join(' ')
            .trim();
      }
      final content = raw['content']?.toString().trim() ?? '';
      if (content.isNotEmpty) return content;
    }
    if (raw is List) {
      return raw
          .map((e) {
            if (e is Map) return (e['text'] ?? e['value'] ?? '').toString();
            return e.toString();
          })
          .where((e) => e.trim().isNotEmpty)
          .join(' ')
          .trim();
    }
    return '';
  }

  Future<void> _openProblemSearch(_ModuleDraft module) async {
    final tagCtrl = TextEditingController(text: module.hashTags.join(', '));
    final textCtrl = TextEditingController();
    var loading = false;
    var initialized = false;
    var results = <Map<String, dynamic>>[];
    final selected = Set<String>.from(module.problemIds);
    Map<String, dynamic>? activeItem;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> runSearch() async {
              initialized = true;
              setDialogState(() => loading = true);
              try {
                final payload = await ApiClient.instance
                    .searchExamEditorProblems(
                      ownedOnly: true,
                      hashTag: tagCtrl.text.trim().isEmpty
                          ? null
                          : tagCtrl.text.trim(),
                      text: textCtrl.text.trim().isEmpty
                          ? null
                          : textCtrl.text.trim(),
                      pageSize: 50,
                    );
                final rawItems =
                    (payload['items'] ?? payload['problems'] ?? const [])
                        as List;
                results = rawItems
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();
                activeItem = results.isEmpty ? null : results.first;
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(SnackBar(content: Text('문제 검색 실패: $e')));
              } finally {
                setDialogState(() => loading = false);
              }
            }

            if (!initialized && !loading) {
              runSearch();
            }

            return TeacherFullFacePanel(
              eyebrow: 'COURSE STUDIO',
              title: '문서함 문제 선택',
              description: '교사 문서함에 저장된 문제만 코스 모듈에 연결합니다.',
              maxContentWidth: 1180,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '교사 문서함에 저장된 문제만 연결합니다. 생성은 기존 문제 제작 스튜디오에서 처리합니다.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: tagCtrl,
                          decoration: _decoration('필터 태그'),
                          onSubmitted: (_) => runSearch(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: textCtrl,
                          decoration: _decoration('문제명/내용 검색'),
                          onSubmitted: (_) => runSearch(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: loading ? null : runSearch,
                        icon: const Icon(Icons.search_rounded),
                        label: Text(loading ? '검색 중' : '검색'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 11,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F7F8),
                              border: Border.all(
                                color: AppColors.surfaceBorder,
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: loading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : results.isEmpty
                                ? const Center(
                                    child: Text('문서함에 연결할 문제가 없습니다.'),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(10),
                                    itemCount: results.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final item = results[index];
                                      final id = _questIdOf(item);
                                      if (id.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      final selectedNow = selected.contains(id);
                                      final activeNow =
                                          activeItem != null &&
                                          _questIdOf(activeItem!) == id;
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () => setDialogState(
                                          () => activeItem = item,
                                        ),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 120,
                                          ),
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: activeNow
                                                ? const Color(0xFFF0F0F2)
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: activeNow
                                                  ? kCourseGreen
                                                  : AppColors.surfaceBorder,
                                              width: activeNow ? 1.4 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Checkbox(
                                                value: selectedNow,
                                                onChanged: (value) {
                                                  setDialogState(() {
                                                    activeItem = item;
                                                    if (value == true) {
                                                      selected.add(id);
                                                    } else {
                                                      selected.remove(id);
                                                    }
                                                  });
                                                },
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _questTitleOf(item),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      _questBodyOf(item),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.black54,
                                                        height: 1.35,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      id,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.black45,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 9,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: AppColors.surfaceBorder,
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: activeItem == null
                                ? const Center(child: Text('왼쪽에서 문제를 선택하세요.'))
                                : Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _questTitleOf(activeItem!),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          _questIdOf(activeItem!),
                                          style: const TextStyle(
                                            color: Colors.black45,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children:
                                              ((activeItem!['hash_tags']
                                                          as List?) ??
                                                      const [])
                                                  .map(
                                                    (tag) => Chip(
                                                      label: Text(
                                                        tag.toString(),
                                                      ),
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                    ),
                                                  )
                                                  .toList()
                                                  .cast<Widget>(),
                                        ),
                                        const SizedBox(height: 14),
                                        const Text(
                                          '문제 미리보기',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            child: Text(
                                              _questBodyOf(activeItem!),
                                              style: const TextStyle(
                                                height: 1.45,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      module.problemIds
                        ..clear()
                        ..addAll(selected);
                      module.hashTags
                        ..clear()
                        ..addAll(_splitCsv(tagCtrl.text));
                    });
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('추가'),
                ),
              ],
            );
          },
        ),
      ),
    );
    tagCtrl.dispose();
    textCtrl.dispose();
  }

  Future<void> _openProblemStudioForModule(_ModuleDraft module) async {
    final created = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ProblemEditorPage(
          initialTags: module.hashTags,
          returnGeneratedQuestOnSave: true,
        ),
      ),
    );
    if (created == null || !mounted) return;
    final questId = _questIdOf(created);
    if (questId.isEmpty) return;
    setState(() {
      if (!module.problemIds.contains(questId)) {
        module.problemIds.add(questId);
      }
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('문제를 추가했습니다: $questId')));
  }

  Future<void> _openExamSearch(_ModuleDraft module) async {
    final searchCtrl = TextEditingController(text: module.examTitle);
    var loading = true;
    var documents = <Map<String, dynamic>>[];
    Map<String, dynamic>? selected;

    try {
      documents = await ApiClient.instance.listTeacherDocuments(type: 'exam');
      final currentId = module.examId.trim();
      for (final item in documents) {
        if (_examIdOf(item) == currentId) {
          selected = item;
          break;
        }
      }
      selected ??= documents.isEmpty ? null : documents.first;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('시험지 문서함 조회 실패: $e')));
      searchCtrl.dispose();
      return;
    } finally {
      loading = false;
    }

    if (!mounted) {
      searchCtrl.dispose();
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            List<Map<String, dynamic>> filteredDocuments() {
              final query = searchCtrl.text.trim().toLowerCase();
              if (query.isEmpty) return documents;
              return documents
                  .where((item) {
                    final haystack = <String>[
                      _examTitleOf(item),
                      _examSubtitleOf(item),
                      ((item['tags'] as List?) ?? const [])
                          .map((tag) => tag.toString())
                          .join(' '),
                    ].join(' ').toLowerCase();
                    return haystack.contains(query);
                  })
                  .toList(growable: false);
            }

            final visible = filteredDocuments();
            if (selected == null && visible.isNotEmpty) {
              selected = visible.first;
            }

            return TeacherFullFacePanel(
              eyebrow: 'COURSE STUDIO',
              title: '문서함 시험지 선택',
              description: '교사 문서함에 저장된 시험지만 시험지 풀이 모듈에 연결합니다.',
              maxContentWidth: 1080,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '교사 문서함에 저장된 시험지만 연결합니다. 다른 파일 탐색은 지원하지 않습니다.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: searchCtrl,
                    decoration: _decoration('시험지명/태그 검색'),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F8),
                        border: Border.all(color: AppColors.surfaceBorder),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : visible.isEmpty
                          ? const Center(child: Text('문서함에 선택 가능한 시험지가 없습니다.'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(10),
                              itemCount: visible.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = visible[index];
                                final id = _examIdOf(item);
                                final active =
                                    selected != null &&
                                    _examIdOf(selected!) == id;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () =>
                                      setDialogState(() => selected = item),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 120),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? const Color(0xFFF0F0F2)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: active
                                            ? kCourseGreen
                                            : AppColors.surfaceBorder,
                                        width: active ? 1.4 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                            right: 10,
                                          ),
                                          child: Icon(
                                            active
                                                ? Icons
                                                      .radio_button_checked_rounded
                                                : Icons
                                                      .radio_button_off_rounded,
                                            color: active
                                                ? kCourseGreen
                                                : Colors.black26,
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _examTitleOf(item),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                _examSubtitleOf(item),
                                                style: const TextStyle(
                                                  color: Colors.black54,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children:
                                                    ((item['tags'] as List?) ??
                                                            const [])
                                                        .take(6)
                                                        .map(
                                                          (tag) => Chip(
                                                            label: Text(
                                                              tag.toString(),
                                                            ),
                                                            visualDensity:
                                                                VisualDensity
                                                                    .compact,
                                                          ),
                                                        )
                                                        .toList(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: selected == null
                      ? null
                      : () {
                          setState(() {
                            module.examId = _examIdOf(selected!);
                            module.examTitle = _examTitleOf(selected!);
                          });
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('선택'),
                ),
              ],
            );
          },
        ),
      ),
    );
    searchCtrl.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('코스 제목을 입력해 주세요.')));
      return;
    }
    for (final module in _modules) {
      if (module.type == 'textbook_view') {
        if (module.textbookId.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('교재 보기 모듈에는 교재를 선택해 주세요.')),
          );
          return;
        }
        if (!_hasSelectableTextbookId(module.textbookId)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('코스에 등록할 수 없는 교재가 포함되어 있습니다.')),
          );
          return;
        }
        if (module.pageFrom <= 0) module.pageFrom = 1;
        if (module.pageTo < module.pageFrom) module.pageTo = module.pageFrom;
      } else if (module.type == 'exam_solve') {
        if (module.examId.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('시험지 풀이 모듈에는 시험지를 선택해 주세요.')),
          );
          return;
        }
        module.minMinutes = module.minMinutes < 0 ? 0 : module.minMinutes;
        module.passRate = module.passRate.clamp(1, 100).toInt();
      } else if (module.type == 'level_test') {
        if (module.examId.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('레벨 테스트 모듈에는 시험지를 선택해 주세요.')),
          );
          return;
        }
        module.minMinutes = module.minMinutes < 0 ? 0 : module.minMinutes;
        module.passRate = module.passRate.clamp(1, 100).toInt();
      }
    }

    _focusTags.removeWhere((t) => !_tags.contains(t));
    while (_focusTags.length > 3) {
      _focusTags.removeLast();
    }

    setState(() => _saving = true);
    try {
      final payload = buildCourseV2Payload(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        advancedOpen: _advancedOpen,
        difficulty: _difficulty,
        targetOvr: int.tryParse(_targetOvrCtrl.text.trim()) ?? 0,
        tags: List<String>.from(_tags),
        focusTags: List<String>.from(_focusTags),
        modules: _modules.asMap().entries.map((entry) {
          final item = entry.value.toJson();
          item['id'] = item['id']?.toString().isNotEmpty == true
              ? item['id']
              : 'mod_${entry.key}';
          item['position'] = entry.key;
          return item;
        }).toList(),
        curriculumEnabled: false,
        curriculumEveryNDays: 0,
        curriculumMaxDeadlineDeviation: 0,
        curriculumDailyMaxModules: 0,
        moduleDeadlineDays: List<int>.filled(_modules.length, 0),
        wrongAnswerReviewEnabled: _wrongAnswerReviewEnabled,
      );

      if (_isEditing) {
        await ApiClient.instance.updateCourseV2(
          widget.initialCourseId!,
          payload,
        );
      } else {
        await ApiClient.instance.createCourseV2(payload);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? '코스를 수정했습니다.' : '코스를 생성했습니다.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = courseUiScale(context);
    return TeacherStudioShell(
      currentRoute: '/course-builder',
      eyebrow: 'COURSE WORKSPACE',
      title: _isEditing ? '코스 수정' : '코스 만들기',
      description: '기본 정보와 학습 모듈을 구성하고 저장 전 흐름을 검토합니다.',
      endDrawer: const TeacherAppDrawer(currentRoute: '/course-builder'),
      onBack: Navigator.of(context).canPop()
          ? () => Navigator.of(context).pop()
          : null,
      actions: [
        TeacherStudioAction(
          label: _saving ? '저장 중' : '저장',
          icon: Icons.save_rounded,
          onTap: _saving ? null : _save,
          primary: true,
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _BuilderTabSwitcher(controller: _tabController),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabContainer(_buildMetaTab(scale), scale),
                      _buildTabContainer(_buildModuleTab(scale), scale),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaTab(double scale) {
    return ListView(
      padding: EdgeInsets.all(16 * scale),
      children: [
        _sectionTitle('기본 정보', scale),
        _field(_titleCtrl, '코스 제목 *', scale),
        SwitchListTile(
          title: const Text('상세 옵션 펼치기'),
          subtitle: const Text('설명, 난이도, 목표 OVR을 함께 설정합니다.'),
          value: _advancedOpen,
          onChanged: (v) => setState(() => _advancedOpen = v),
          activeThumbColor: kCourseLightGreen,
        ),
        if (_advancedOpen) ...[
          _field(_descCtrl, '설명', scale, maxLines: 3),
          DropdownButtonFormField<String>(
            initialValue: _difficulty,
            decoration: _decoration('난이도'),
            items: const [
              '하',
              '중하',
              '중',
              '중상',
              '상',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _difficulty = v ?? '중'),
          ),
          SizedBox(height: 12 * scale),
          _field(
            _targetOvrCtrl,
            '목표 OVR',
            scale,
            keyboardType: TextInputType.number,
          ),
        ],
        const SizedBox(height: 8),
        _sectionTitle('오답 복습', scale),
        SwitchListTile(
          title: const Text('오답 복습 자동 삽입'),
          subtitle: const Text('기준 점수 미만 모듈의 오답 복습을 코스 마지막에 추가합니다.'),
          value: _wrongAnswerReviewEnabled,
          onChanged: (v) => setState(() => _wrongAnswerReviewEnabled = v),
          activeThumbColor: kCourseLightGreen,
        ),
        const SizedBox(height: 8),
        _sectionTitle('태그 설정', scale),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ..._tags.map(
              (t) => Chip(
                label: Text(t),
                onDeleted: () {
                  setState(() {
                    _tags.remove(t);
                    _focusTags.remove(t);
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagInputCtrl,
                decoration: _decoration('태그 입력 후 Enter'),
                onSubmitted: (_) => _addTag(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _addTag, child: const Text('추가')),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: _availableHashTags
              .where((t) => !_tags.contains(t))
              .take(20)
              .map(
                (t) => ActionChip(
                  label: Text(t),
                  onPressed: () => setState(() => _tags.add(t)),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        _sectionTitle('핵심 태그 (최대 3개)', scale),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: _tags.map((tag) {
            final selected = _focusTags.contains(tag);
            return FilterChip(
              label: Text(tag),
              selected: selected,
              onSelected: (on) {
                setState(() {
                  if (on) {
                    if (_focusTags.length < 3) _focusTags.add(tag);
                  } else {
                    _focusTags.remove(tag);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildModuleTab(double scale) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final selectedIndex = _selectedModuleIndex.clamp(
          0,
          _modules.length - 1,
        );
        final module = _modules[selectedIndex];
        final compact = constraints.maxWidth < 860;
        final listPanel = _buildModuleListPanel(scale, selectedIndex);
        final editorPanel = _buildModuleEditor(module, selectedIndex, scale);

        return Padding(
          padding: EdgeInsets.all(16 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _sectionTitle('모듈 구성', scale)),
                  FilledButton.icon(
                    onPressed: _addModule,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('모듈 추가'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kCourseGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              Text(
                '왼쪽에서 학습 순서를 고르고, 오른쪽에서 선택한 모듈만 편집합니다.',
                style: TextStyle(fontSize: 12 * scale, color: Colors.black54),
              ),
              SizedBox(height: 12 * scale),
              Expanded(
                child: compact
                    ? Column(
                        children: [
                          SizedBox(height: 230 * scale, child: listPanel),
                          SizedBox(height: 12 * scale),
                          Expanded(child: editorPanel),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 320 * scale, child: listPanel),
                          SizedBox(width: 14 * scale),
                          Expanded(child: editorPanel),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModuleListPanel(double scale, int selectedIndex) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFA),
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12 * scale, 10 * scale, 8 * scale, 6),
            child: Row(
              children: [
                Text(
                  '학습 순서',
                  style: TextStyle(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w800,
                    color: kCourseGreen,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_modules.length}개',
                  style: TextStyle(
                    fontSize: 11 * scale,
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.surfaceBorder),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.all(8 * scale),
              itemCount: _modules.length,
              separatorBuilder: (_, _) => SizedBox(height: 6 * scale),
              itemBuilder: (context, index) {
                final module = _modules[index];
                final selected = index == selectedIndex;
                return _ModuleListTile(
                  key: ValueKey(module),
                  index: index,
                  module: module,
                  selected: selected,
                  canMoveUp: index > 0,
                  canMoveDown: index < _modules.length - 1,
                  canDelete: _modules.length > 1,
                  scale: scale,
                  summary: _moduleSummary(module),
                  onTap: () => setState(() => _selectedModuleIndex = index),
                  onMoveUp: () => _moveModule(index, index - 1),
                  onMoveDown: () => _moveModule(index, index + 1),
                  onDelete: () => _removeModule(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Key _moduleFieldKey(_ModuleDraft module, String name) {
    return ValueKey<String>('${identityHashCode(module)}_$name');
  }

  Widget _buildModuleEditor(_ModuleDraft module, int index, double scale) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: ListView(
        padding: EdgeInsets.all(14 * scale),
        children: [
          Row(
            children: [
              Container(
                width: 36 * scale,
                height: 36 * scale,
                decoration: BoxDecoration(
                  color: kCourseGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8 * scale),
                ),
                child: Icon(
                  _moduleIcon(module.type),
                  color: kCourseGreen,
                  size: 20 * scale,
                ),
              ),
              SizedBox(width: 10 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '모듈 ${index + 1}',
                      style: TextStyle(
                        fontSize: 15 * scale,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _moduleLabels[module.type] ?? module.type,
                      style: TextStyle(
                        fontSize: 12 * scale,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '삭제',
                onPressed: _modules.length <= 1
                    ? null
                    : () => _removeModule(index),
                icon: const Icon(Icons.delete_outline_rounded),
                color: Colors.red,
              ),
            ],
          ),
          SizedBox(height: 14 * scale),
          TextFormField(
            key: _moduleFieldKey(module, 'title'),
            initialValue: module.title,
            decoration: _decoration('제목'),
            onChanged: (v) => setState(() => module.title = v),
          ),
          SizedBox(height: 8 * scale),
          DropdownButtonFormField<String>(
            key: _moduleFieldKey(module, 'type'),
            initialValue: module.type,
            decoration: _decoration('유형'),
            items: _moduleTypes
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(_moduleLabels[t] ?? t),
                  ),
                )
                .toList(),
            onChanged: (v) {
              final nextType = v ?? 'problem_solve';
              if (nextType != module.type) {
                setState(() => module.type = nextType);
              }
            },
          ),
          SizedBox(height: 8 * scale),
          TextFormField(
            key: _moduleFieldKey(module, 'description'),
            initialValue: module.description,
            decoration: _decoration('설명'),
            onChanged: (v) => setState(() => module.description = v),
          ),
          if (module.type == 'textbook_view')
            ..._buildTextbookModuleFields(module, scale),
          if (module.type == 'problem_solve')
            ..._buildProblemModuleFields(module, scale),
          if (module.type == 'exam_solve')
            ..._buildExamModuleFields(module, scale),
          if (module.type == 'level_test')
            ..._buildLevelTestModuleFields(module, scale),
          if (module.type == 'problem_solve' || module.type == 'exam_solve')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('이 모듈 오답 복습'),
              subtitle: Text(
                _wrongAnswerReviewEnabled
                    ? '켜면 저장 시 필요할 때 오답 복습 대상이 됩니다.'
                    : '코스 전체 오답 복습 자동 삽입이 꺼져 있습니다.',
              ),
              value: module.wrongAnswerReviewEnabled,
              onChanged: _wrongAnswerReviewEnabled
                  ? (v) => setState(() => module.wrongAnswerReviewEnabled = v)
                  : null,
              activeThumbColor: kCourseLightGreen,
            ),
        ],
      ),
    );
  }

  List<Widget> _buildTextbookModuleFields(_ModuleDraft module, double scale) {
    return [
      SizedBox(height: 12 * scale),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              key: _moduleFieldKey(module, 'textbook'),
              initialValue: _dropdownTextbookValue(module.textbookId),
              decoration: _decoration('교재'),
              items: _textbooks
                  .map(
                    (book) => DropdownMenuItem(
                      value: _textbookId(book),
                      child: Text(book['title']?.toString() ?? '교재'),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() => module.textbookId = v?.toString() ?? '');
              },
            ),
          ),
        ],
      ),
      SizedBox(height: 8 * scale),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              key: _moduleFieldKey(module, 'pageFrom'),
              initialValue: module.pageFrom.toString(),
              decoration: _decoration('시작 페이지'),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                setState(() {
                  module.pageFrom = int.tryParse(v) ?? 1;
                  if (module.pageTo < module.pageFrom) {
                    module.pageTo = module.pageFrom;
                  }
                });
              },
            ),
          ),
          SizedBox(width: 8 * scale),
          Expanded(
            child: TextFormField(
              key: _moduleFieldKey(module, 'pageTo'),
              initialValue: module.pageTo.toString(),
              decoration: _decoration('종료 페이지'),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                setState(() {
                  module.pageTo = int.tryParse(v) ?? module.pageFrom;
                  if (module.pageTo < module.pageFrom) {
                    module.pageTo = module.pageFrom;
                  }
                });
              },
            ),
          ),
          SizedBox(width: 8 * scale),
          Expanded(
            child: TextFormField(
              key: _moduleFieldKey(module, 'minMinutes'),
              initialValue: module.minMinutes.toString(),
              decoration: _decoration('최소 학습 시간(분)'),
              keyboardType: TextInputType.number,
              onChanged: (v) =>
                  setState(() => module.minMinutes = int.tryParse(v) ?? 0),
            ),
          ),
        ],
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('최소 시간 미달 시 미완료 처리'),
        value: module.enforceMinMinutes,
        onChanged: (v) => setState(() => module.enforceMinMinutes = v ?? false),
      ),
    ];
  }

  List<Widget> _buildProblemModuleFields(_ModuleDraft module, double scale) {
    return [
      SizedBox(height: 12 * scale),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('객관식 자동 구성'),
        subtitle: const Text('정답을 기준으로 5개의 보기를 생성합니다.'),
        value: module.multipleChoice,
        onChanged: (v) => setState(() => module.multipleChoice = v),
        secondary: const Icon(Icons.fact_check_rounded),
      ),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              key: _moduleFieldKey(module, 'passRate'),
              initialValue: module.passRate.toString(),
              decoration: _decoration('이수 정답률(%)'),
              keyboardType: TextInputType.number,
              onChanged: (v) => module.passRate = (int.tryParse(v) ?? 90)
                  .clamp(1, 100)
                  .toInt(),
            ),
          ),
          SizedBox(width: 8 * scale),
          Expanded(
            child: TextFormField(
              key: _moduleFieldKey(module, 'questionCount'),
              initialValue: module.questionCount.toString(),
              decoration: _decoration('출제 수'),
              keyboardType: TextInputType.number,
              onChanged: (v) => setState(
                () => module.questionCount = (int.tryParse(v) ?? 5)
                    .clamp(1, 30)
                    .toInt(),
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: 8 * scale),
      TextFormField(
        key: _moduleFieldKey(module, 'hashTags'),
        initialValue: module.hashTags.join(', '),
        decoration: _decoration('문항 태그'),
        onChanged: (v) {
          setState(() {
            module.hashTags
              ..clear()
              ..addAll(_splitCsv(v));
          });
        },
      ),
      if (_availableProblemTags.isNotEmpty) ...[
        SizedBox(height: 8 * scale),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: _availableProblemTags
              .where((tag) => !module.hashTags.contains(tag))
              .take(20)
              .map(
                (tag) => ActionChip(
                  label: Text(tag),
                  onPressed: () => setState(() => module.hashTags.add(tag)),
                ),
              )
              .toList(),
        ),
      ],
      SizedBox(height: 6 * scale),
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(12 * scale),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3E3E7)),
        ),
        child: const Text(
          '문제 검색은 문서함 문제만 사용합니다. 새 문제 제작은 기존 문제 제작 스튜디오에서 바로 추가합니다.',
          style: TextStyle(color: Colors.black54, height: 1.4),
        ),
      ),
      SizedBox(height: 10 * scale),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: () => _openProblemSearch(module),
            icon: const Icon(Icons.search_rounded),
            label: const Text('문서함에서 선택'),
          ),
          FilledButton.icon(
            onPressed: () => _openProblemStudioForModule(module),
            icon: const Icon(Icons.auto_fix_high_rounded),
            label: const Text('생성해서 추가'),
          ),
        ],
      ),
      if (module.problemIds.isNotEmpty) ...[
        SizedBox(height: 8 * scale),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: module.problemIds
              .map(
                (id) => InputChip(
                  avatar: const Icon(Icons.quiz_rounded, size: 16),
                  label: Text(id),
                  onDeleted: () => setState(() => module.problemIds.remove(id)),
                ),
              )
              .toList(),
        ),
      ],
    ];
  }

  List<Widget> _buildExamModuleFields(_ModuleDraft module, double scale) {
    return [
      SizedBox(height: 12 * scale),
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(12 * scale),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3E3E7)),
        ),
        child: const Text(
          '시험지 선택은 교사 문서함에 저장된 시험지만 가능합니다.',
          style: TextStyle(color: Colors.black54, height: 1.4),
        ),
      ),
      SizedBox(height: 10 * scale),
      OutlinedButton.icon(
        onPressed: () => _openExamSearch(module),
        icon: const Icon(Icons.assignment_rounded),
        label: Text(
          module.examId.trim().isEmpty ? '문서함에서 시험지 선택' : '선택한 시험지 변경',
        ),
      ),
      if (module.examId.trim().isNotEmpty) ...[
        SizedBox(height: 8 * scale),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12 * scale),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                module.examTitle.trim().isEmpty ? '시험지' : module.examTitle,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                module.examId,
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ),
        ),
      ],
      SizedBox(height: 12 * scale),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              key: _moduleFieldKey(module, 'examMinMinutes'),
              initialValue: module.minMinutes.toString(),
              decoration: _decoration('최소 시험 시간(분)'),
              keyboardType: TextInputType.number,
              onChanged: (v) => setState(
                () => module.minMinutes = int.tryParse(v.trim()) ?? 0,
              ),
            ),
          ),
          SizedBox(width: 8 * scale),
          Expanded(
            child: TextFormField(
              key: _moduleFieldKey(module, 'examPassRate'),
              initialValue: module.passRate.toString(),
              decoration: _decoration('이수 정답률(%)'),
              keyboardType: TextInputType.number,
              onChanged: (v) => setState(
                () => module.passRate = (int.tryParse(v.trim()) ?? 90)
                    .clamp(1, 100)
                    .toInt(),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildLevelTestModuleFields(_ModuleDraft module, double scale) {
    return [
      SizedBox(height: 12 * scale),
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(12 * scale),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3E3E7)),
        ),
        child: const Text(
          '선택한 시험지를 레벨 테스트로 실행합니다. 태그와 풀이 결과는 학습 분석 초기 데이터로 사용할 수 있게 모듈에 함께 저장됩니다.',
          style: TextStyle(color: Colors.black54, height: 1.4),
        ),
      ),
      SizedBox(height: 10 * scale),
      OutlinedButton.icon(
        onPressed: () => _openExamSearch(module),
        icon: const Icon(Icons.trending_up_rounded),
        label: Text(
          module.examId.trim().isEmpty ? '레벨 테스트 시험지 선택' : '레벨 테스트 시험지 변경',
        ),
      ),
      if (module.examId.trim().isNotEmpty) ...[
        SizedBox(height: 8 * scale),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12 * scale),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                module.examTitle.trim().isEmpty
                    ? '레벨 테스트 시험지'
                    : module.examTitle,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                module.examId,
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
          ),
        ),
      ],
      SizedBox(height: 12 * scale),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              key: _moduleFieldKey(module, 'levelTestMinMinutes'),
              initialValue: module.minMinutes.toString(),
              decoration: _decoration('최소 테스트 시간(분)'),
              keyboardType: TextInputType.number,
              onChanged: (v) => setState(
                () => module.minMinutes = int.tryParse(v.trim()) ?? 0,
              ),
            ),
          ),
          SizedBox(width: 8 * scale),
          Expanded(
            child: TextFormField(
              key: _moduleFieldKey(module, 'levelTestPassRate'),
              initialValue: module.passRate.toString(),
              decoration: _decoration('판정 기준 정답률(%)'),
              keyboardType: TextInputType.number,
              onChanged: (v) => setState(
                () => module.passRate = (int.tryParse(v.trim()) ?? 100)
                    .clamp(1, 100)
                    .toInt(),
              ),
            ),
          ),
        ],
      ),
      SizedBox(height: 8 * scale),
      TextFormField(
        key: _moduleFieldKey(module, 'levelTestHashTags'),
        initialValue: module.hashTags.join(', '),
        decoration: _decoration('분석 태그'),
        onChanged: (v) {
          setState(() {
            module.hashTags
              ..clear()
              ..addAll(_splitCsv(v));
          });
        },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('AI 분석 사용'),
        subtitle: const Text('풀이 통계와 일부 문제 샘플을 분석 메타데이터로 보냅니다.'),
        value: module.levelTestAiAnalysisEnabled,
        onChanged: (v) => setState(() => module.levelTestAiAnalysisEnabled = v),
        activeThumbColor: kCourseLightGreen,
      ),
    ];
  }

  IconData _moduleIcon(String type) {
    return switch (type) {
      'textbook_view' => Icons.menu_book_rounded,
      'problem_solve' => Icons.edit_note_rounded,
      'exam_solve' => Icons.assignment_rounded,
      'level_test' => Icons.trending_up_rounded,
      _ => Icons.extension_rounded,
    };
  }

  String _moduleSummary(_ModuleDraft module) {
    if (module.type == 'textbook_view') {
      return '${module.pageFrom}-${module.pageTo}p · ${module.minMinutes}분';
    }
    if (module.type == 'problem_solve') {
      final tag = module.hashTags.isEmpty
          ? '태그 없음'
          : module.hashTags.join(', ');
      return '${module.questionCount}문항 · $tag';
    }
    if (module.type == 'exam_solve') {
      final examLabel = module.examTitle.trim().isEmpty
          ? '시험지 미선택'
          : module.examTitle.trim();
      return '${module.minMinutes}분 · ${module.passRate}% · $examLabel';
    }
    if (module.type == 'level_test') {
      final examLabel = module.examTitle.trim().isEmpty
          ? '시험지 미선택'
          : module.examTitle.trim();
      return '레벨 테스트 · ${module.passRate}% · $examLabel';
    }
    return module.description.trim().isEmpty ? '세부 설정 없음' : module.description;
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    double scale, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12 * scale),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: _decoration(label),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.surfaceMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.surfaceBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.surfaceBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kCourseLightGreen, width: 2),
      ),
    );
  }

  Widget _sectionTitle(String text, double scale) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8 * scale),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15 * scale,
          fontWeight: FontWeight.w700,
          color: kCourseGreen,
        ),
      ),
    );
  }

  /// 필요 변수: 탭 본문 [child]와 화면 비율 [scale]을 사용한다.
  /// 작동 원리: 장식 컨테이너 위에 투명 Material 레이어를 두어 ListTile의
  /// 선택 배경과 잉크 효과가 가려지지 않으며, 동일한 둥근 모서리로 자른다.
  Widget _buildTabContainer(Widget child, double scale) {
    final borderRadius = BorderRadius.circular(16 * scale);
    return Padding(
      padding: EdgeInsets.all(12 * scale),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius,
          border: Border.all(color: AppColors.surfaceBorder),
          boxShadow: const [kCourseShadow],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }
}

/// 필요 변수: 기존 TabController.
/// 작동 원리: 메타데이터와 모듈 작업공간을 넓은 캡슐 탭으로 전환하고 TabBarView 상태를 동기화한다.
class _BuilderTabSwitcher extends StatelessWidget {
  const _BuilderTabSwitcher({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Container(
        height: 52,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            _item(0, Icons.tune_rounded, '기본 정보'),
            _item(1, Icons.account_tree_outlined, '학습 모듈'),
          ],
        ),
      ),
    );
  }

  Widget _item(int index, IconData icon, String label) {
    final selected = controller.index == index;
    return Expanded(
      child: Material(
        color: selected ? Colors.black : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => controller.animateTo(index),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : Colors.black45,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black54,
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

class _ModuleListTile extends StatelessWidget {
  const _ModuleListTile({
    super.key,
    required this.index,
    required this.module,
    required this.selected,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canDelete,
    required this.scale,
    required this.summary,
    required this.onTap,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  final int index;
  final _ModuleDraft module;
  final bool selected;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool canDelete;
  final double scale;
  final String summary;
  final VoidCallback onTap;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? kCourseLightGreen : AppColors.surfaceBorder;
    final bgColor = selected
        ? kCourseGreen.withValues(alpha: 0.06)
        : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8 * scale),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.all(10 * scale),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8 * scale),
          border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 28 * scale,
              height: 28 * scale,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? kCourseGreen : const Color(0xFFF0F0F2),
                borderRadius: BorderRadius.circular(8 * scale),
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: selected ? Colors.white : kCourseGreen,
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(width: 10 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.title.trim().isEmpty
                        ? _moduleLabels[module.type] ?? '모듈'
                        : module.title.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13 * scale,
                      fontWeight: FontWeight.w800,
                      color: selected ? kCourseGreen : Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2 * scale),
                  Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11 * scale,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 4 * scale),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TinyIconButton(
                  tooltip: '위로',
                  icon: Icons.keyboard_arrow_up_rounded,
                  onPressed: canMoveUp ? onMoveUp : null,
                ),
                _TinyIconButton(
                  tooltip: '아래로',
                  icon: Icons.keyboard_arrow_down_rounded,
                  onPressed: canMoveDown ? onMoveDown : null,
                ),
              ],
            ),
            _TinyIconButton(
              tooltip: '삭제',
              icon: Icons.delete_outline_rounded,
              color: Colors.red,
              onPressed: canDelete ? onDelete : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyIconButton extends StatelessWidget {
  const _TinyIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      padding: EdgeInsets.zero,
      iconSize: 18,
      color: color ?? Colors.black54,
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

class _ModuleDraft {
  _ModuleDraft({
    required this.type,
    this.id,
    this.title = '',
    this.description = '',
    this.textbookId = '',
    this.pageFrom = 1,
    this.pageTo = 1,
    this.minMinutes = 0,
    this.enforceMinMinutes = false,
    this.estimatedMinutes = 20,
    this.maxProblems = 10,
    List<String>? problemIds,
    List<String>? hashTags,
    this.questionCount = 5,
    this.passRate = 90,
    this.multipleChoice = true,
    this.examId = '',
    this.examTitle = '',
    this.showTimer = true,
    this.prompt = '',
    this.solvesCount = 4,
    this.strategyLevel = 2,
    this.branchConditions = 1,
    this.strictTags = false,
    this.referenceQuestId = '',
    this.wrongAnswerReviewEnabled = true,
    this.levelTestAiAnalysisEnabled = true,
  }) : problemIds = problemIds ?? <String>[],
       hashTags = hashTags ?? <String>[];

  factory _ModuleDraft.fromJson(Map<String, dynamic> json) {
    final generation = json['generation_config'] is Map
        ? Map<String, dynamic>.from(json['generation_config'] as Map)
        : const <String, dynamic>{};
    return _ModuleDraft(
      id: json['id']?.toString(),
      type: json['type']?.toString() ?? 'problem_solve',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      textbookId: json['textbook_id']?.toString() ?? '',
      pageFrom: (json['page_from'] as num?)?.toInt() ?? 1,
      pageTo: (json['page_to'] as num?)?.toInt() ?? 1,
      minMinutes: (json['min_minutes'] as num?)?.toInt() ?? 0,
      enforceMinMinutes: json['enforce_min_minutes'] == true,
      estimatedMinutes: (json['estimated_minutes'] as num?)?.toInt() ?? 20,
      maxProblems: (json['max_problems'] as num?)?.toInt() ?? 10,
      problemIds: ((json['problem_ids'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      hashTags: ((json['hash_tags'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(),
      questionCount: (json['question_count'] as num?)?.toInt() ?? 5,
      passRate: (json['pass_rate'] as num?)?.toInt() ?? 90,
      multipleChoice:
          (json['objectify_mode']?.toString() ?? 'multiple_choice').isNotEmpty,
      examId: json['exam_id']?.toString() ?? '',
      examTitle: json['exam_title']?.toString() ?? '',
      showTimer: json['show_timer'] != false,
      prompt: generation['prompt']?.toString() ?? '',
      solvesCount: (generation['solves_count'] as num?)?.toInt() ?? 4,
      strategyLevel: (generation['strategy_level'] as num?)?.toInt() ?? 2,
      branchConditions: (generation['branch_conditions'] as num?)?.toInt() ?? 1,
      strictTags: generation['strict_tags'] == true,
      referenceQuestId: generation['reference_quest_id']?.toString() ?? '',
      wrongAnswerReviewEnabled: json['wrong_answer_review_enabled'] != false,
      levelTestAiAnalysisEnabled: json['analysis_enabled'] != false,
    );
  }

  String? id;
  String type;
  String title;
  String description;
  String textbookId;
  int pageFrom;
  int pageTo;
  int minMinutes;
  bool enforceMinMinutes;
  int estimatedMinutes;
  int maxProblems;
  List<String> problemIds;
  List<String> hashTags;
  int questionCount;
  int passRate;
  bool multipleChoice;
  String examId;
  String examTitle;
  bool showTimer;
  String prompt;
  int solvesCount;
  int strategyLevel;
  int branchConditions;
  bool strictTags;
  String referenceQuestId;
  bool wrongAnswerReviewEnabled;
  bool levelTestAiAnalysisEnabled;

  Map<String, dynamic> toJson() {
    return {
      if ((id ?? '').isNotEmpty) 'id': id,
      'type': type,
      'title': title,
      'description': description,
      if (type == 'textbook_view') ...{
        'textbook_id': textbookId,
        'page_from': pageFrom,
        'page_to': pageTo,
        'min_minutes': minMinutes,
        'enforce_min_minutes': enforceMinMinutes,
      },
      if (type == 'problem_solve') ...{
        'problem_source': problemIds.isEmpty ? 'document_search' : 'selected',
        'problem_ids': problemIds,
        'hash_tags': hashTags,
        'question_count': questionCount,
        'pass_rate': passRate,
        'pass_policy': {'required_accuracy': passRate},
        'wrong_answer_review_enabled': wrongAnswerReviewEnabled,
        'objectify_mode': multipleChoice ? 'multiple_choice' : '',
        'mcq_policy': {
          'offset_pattern': 'pm2',
          'random_choices': true,
          'choice_count': 5,
        },
        'generation_config': {
          'prompt': prompt,
          'solves_count': solvesCount,
          'strategy_level': strategyLevel,
          'branch_conditions': branchConditions,
          'strict_tags': strictTags,
          if (referenceQuestId.trim().isNotEmpty)
            'reference_quest_id': referenceQuestId.trim(),
        },
      },
      if (type == 'exam_solve') ...{
        'exam_id': examId.trim(),
        'exam_title': examTitle.trim(),
        'exam_duration': minMinutes > 0 ? minMinutes : estimatedMinutes,
        'min_minutes': minMinutes,
        'enforce_min_minutes': minMinutes > 0,
        'pass_rate': passRate,
        'pass_policy': {'required_accuracy': passRate},
        'wrong_answer_review_enabled': wrongAnswerReviewEnabled,
        'show_timer': showTimer,
      },
      if (type == 'level_test') ...{
        'test_type': 'exam',
        'exam_id': examId.trim(),
        'exam_title': examTitle.trim(),
        'hash_tags': hashTags,
        'tags': hashTags,
        'question_count': questionCount,
        'pass_rate': passRate,
        'pass_policy': {'required_accuracy': passRate},
        'exam_duration': minMinutes > 0 ? minMinutes : estimatedMinutes,
        'min_minutes': minMinutes,
        'enforce_min_minutes': minMinutes > 0,
        'show_timer': showTimer,
        'analysis_enabled': levelTestAiAnalysisEnabled,
        'analysis_model': 'gemma-4',
        'analysis_retention_days': 7,
        'analysis_sample_question_count': 5,
        'privacy_scope': 'teacher_summary',
      },
      'estimated_minutes': estimatedMinutes,
      'max_problems': maxProblems,
    };
  }
}
