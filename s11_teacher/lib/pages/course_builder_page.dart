// UTF-8 only: This file must be read/written as UTF-8.
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/course_builder_payload.dart';
import '../widgets/design_tokens.dart';
import '../widgets/teacher_app_drawer.dart';

const List<String> _moduleTypes = <String>[
  'textbook_view',
  'problem_solve',
  'exam_solve',
];

const Map<String, String> _moduleLabels = <String, String>{
  'textbook_view': '교재 보기',
  'problem_solve': '문제 풀이',
  'exam_solve': '시험지 풀이',
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

  bool _loading = false;
  bool _saving = false;

  final List<String> _tags = <String>[];
  final List<String> _focusTags = <String>[];
  List<String> _availableHashTags = <String>[];

  List<Map<String, dynamic>> _textbooks = <Map<String, dynamic>>[];
  String? _selectedTextbookId;

  final List<_ModuleDraft> _modules = <_ModuleDraft>[];

  bool get _isEditing => widget.initialCourseId != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _modules.add(_ModuleDraft(type: 'textbook_view'));
    _bootstrap();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      final booksFuture = ApiClient.instance.listTeacherDocuments(
        type: 'textbook',
      );
      final tags = await tagsFuture;
      final books = await booksFuture;

      if (!mounted) return;
      _availableHashTags = tags;
      _textbooks = books
          .where(_isCourseSelectableTextbook)
          .toList(growable: false);
      if (_textbooks.isNotEmpty) {
        _selectedTextbookId = _textbookId(_textbooks.first);
      }

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

    _tags
      ..clear()
      ..addAll(((c['tags'] as List?) ?? const []).map((e) => e.toString()));
    _focusTags
      ..clear()
      ..addAll(
        ((c['focus_tags'] as List?) ?? const []).map((e) => e.toString()),
      );
    _focusTags.removeWhere((t) => !_tags.contains(t));

    _selectedTextbookId = c['textbook_id']?.toString() ?? _selectedTextbookId;

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
    String? firstModuleTextbook;
    for (final m in _modules) {
      if (m.type == 'textbook_view' && m.textbookId.isNotEmpty) {
        firstModuleTextbook = m.textbookId;
        break;
      }
    }
    if ((c['textbook_id']?.toString() ?? '').trim().isEmpty &&
        firstModuleTextbook != null) {
      _selectedTextbookId = firstModuleTextbook;
    }
    _normalizeSelectableTextbookSelection();
  }

  bool _isCourseSelectableTextbook(Map<String, dynamic> book) {
    return book['is_course_selectable'] != false;
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
    if (!_hasSelectableTextbookId(_selectedTextbookId)) {
      _selectedTextbookId = _textbooks.isEmpty
          ? null
          : _textbookId(_textbooks.first);
    }
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
    setState(() => _modules.add(_ModuleDraft(type: 'problem_solve')));
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
    final raw = item['title'] ?? item['quest_title'] ?? item['content'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
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
    return _questIdOf(item).isEmpty ? '문제' : _questIdOf(item);
  }

  Future<void> _openProblemSearch(_ModuleDraft module) async {
    final tagCtrl = TextEditingController(text: module.hashTags.join(', '));
    final textCtrl = TextEditingController();
    var loading = false;
    var results = <Map<String, dynamic>>[];
    final selected = Set<String>.from(module.problemIds);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> runSearch() async {
              setDialogState(() => loading = true);
              try {
                final payload = await ApiClient.instance
                    .searchExamEditorProblems(
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
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(SnackBar(content: Text('문제 검색 실패: $e')));
              } finally {
                setDialogState(() => loading = false);
              }
            }

            return AlertDialog(
              title: const Text('문서함 문제 검색'),
              content: SizedBox(
                width: 640,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: tagCtrl,
                      decoration: _decoration('태그'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: textCtrl,
                      decoration: _decoration('문제명/내용'),
                      onSubmitted: (_) => runSearch(),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: loading ? null : runSearch,
                        icon: const Icon(Icons.search_rounded),
                        label: Text(loading ? '검색 중' : '검색'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 320,
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (context, index) {
                                final item = results[index];
                                final id = _questIdOf(item);
                                if (id.isEmpty) return const SizedBox.shrink();
                                return CheckboxListTile(
                                  value: selected.contains(id),
                                  onChanged: (v) {
                                    setDialogState(() {
                                      if (v == true) {
                                        selected.add(id);
                                      } else {
                                        selected.remove(id);
                                      }
                                    });
                                  },
                                  title: Text(
                                    _questTitleOf(item),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(id),
                                );
                              },
                            ),
                    ),
                  ],
                ),
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
        );
      },
    );
    tagCtrl.dispose();
    textCtrl.dispose();
  }

  Future<void> _generateProblemForModule(_ModuleDraft module) async {
    if (module.hashTags.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('먼저 태그를 입력해 주세요.')));
      return;
    }
    setState(() => _saving = true);
    try {
      var quest = await ApiClient.instance.generateQuest(
        hashTags: module.hashTags,
        solvesCount: module.solvesCount,
        strategyLevel: module.strategyLevel,
        branchConditions: module.branchConditions,
        strictTags: module.strictTags,
        referenceQuestId: module.referenceQuestId,
        requestId: 'course_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (module.multipleChoice) {
        quest = await ApiClient.instance.convertQuestToMcq(
          questId: _questIdOf(quest),
        );
      }
      final id = _questIdOf(quest);
      if (id.isEmpty) throw Exception('생성된 문제 ID가 없습니다.');
      setState(() {
        if (!module.problemIds.contains(id)) module.problemIds.add(id);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('문제를 추가했습니다: $id')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('문제 생성 실패: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('코스 제목을 입력해 주세요.')));
      return;
    }
    final fallbackModuleTextbookId = _modules
        .firstWhere(
          (m) => m.type == 'textbook_view' && m.textbookId.trim().isNotEmpty,
          orElse: () => _ModuleDraft(type: 'textbook_view'),
        )
        .textbookId
        .trim();
    if ((_selectedTextbookId ?? '').isEmpty) {
      _selectedTextbookId = fallbackModuleTextbookId.isEmpty
          ? null
          : fallbackModuleTextbookId;
    }
    if (!_hasSelectableTextbookId(_selectedTextbookId)) {
      _selectedTextbookId = null;
    }
    if ((_selectedTextbookId ?? '').isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('교재를 선택해 주세요.')));
      return;
    }

    for (final module in _modules) {
      if (module.type == 'textbook_view') {
        if (module.textbookId.trim().isEmpty) {
          module.textbookId = _selectedTextbookId!;
        }
        if (!_hasSelectableTextbookId(module.textbookId)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('코스에 등록할 수 없는 교재가 포함되어 있습니다.')),
          );
          return;
        }
        if (module.pageFrom <= 0) module.pageFrom = 1;
        if (module.pageTo < module.pageFrom) module.pageTo = module.pageFrom;
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
        textbookId: _selectedTextbookId!,
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
    return Scaffold(
      endDrawer: const TeacherAppDrawer(currentRoute: '/course-builder'),
      backgroundColor: kCourseBgGrey,
      appBar: AppBar(
        backgroundColor: kCourseGreen,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        title: Text(_isEditing ? '코스 수정' : '코스 생성'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              tooltip: '메뉴',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '메타데이터'),
            Tab(text: '교재'),
            Tab(text: '모듈'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTabContainer(_buildMetaTab(scale), scale),
                _buildTabContainer(_buildTextbookTab(scale), scale),
                _buildTabContainer(_buildModuleTab(scale), scale),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _save,
        backgroundColor: kCourseLightGreen,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save),
        label: Text(_saving ? '저장 중' : '저장'),
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

  Widget _buildTextbookTab(double scale) {
    return ListView(
      padding: EdgeInsets.all(16 * scale),
      children: [
        _sectionTitle('교재 연결', scale),
        Text(
          '코스 진행에 사용할 교재를 선택합니다.',
          style: TextStyle(fontSize: 12 * scale, color: Colors.black54),
        ),
        SizedBox(height: 10 * scale),
        DropdownButtonFormField<String>(
          initialValue: _dropdownTextbookValue(_selectedTextbookId),
          decoration: _decoration('교재 선택 *'),
          items: _textbooks
              .map(
                (book) => DropdownMenuItem(
                  value: _textbookId(book),
                  child: Text(book['title']?.toString() ?? '교재'),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedTextbookId = v),
        ),
      ],
    );
  }

  Widget _buildModuleTab(double scale) {
    return ListView(
      padding: EdgeInsets.all(16 * scale),
      children: [
        _sectionTitle('모듈 구성', scale),
        Text(
          '학습 순서대로 모듈을 추가/수정하세요.',
          style: TextStyle(fontSize: 12 * scale, color: Colors.black54),
        ),
        SizedBox(height: 8 * scale),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _addModule,
            icon: const Icon(Icons.add),
            label: const Text('모듈 추가'),
          ),
        ),
        const SizedBox(height: 8),
        ..._modules.asMap().entries.map((entry) {
          final i = entry.key;
          final module = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '모듈 ${i + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _modules.length <= 1
                            ? null
                            : () => setState(() => _modules.removeAt(i)),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  TextFormField(
                    initialValue: module.title,
                    decoration: _decoration('제목'),
                    onChanged: (v) => module.title = v,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
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
                        setState(() {
                          module.type = nextType;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: module.description,
                    decoration: _decoration('설명'),
                    onChanged: (v) => module.description = v,
                  ),
                  if (module.type == 'textbook_view') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _dropdownTextbookValue(
                        module.textbookId.isNotEmpty
                            ? module.textbookId
                            : _selectedTextbookId,
                      ),
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
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: module.pageFrom.toString(),
                      decoration: _decoration('시작 페이지'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        module.pageFrom = int.tryParse(v) ?? 1;
                        if (module.pageTo < module.pageFrom) {
                          module.pageTo = module.pageFrom;
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: module.pageTo.toString(),
                      decoration: _decoration('종료 페이지'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        module.pageTo = int.tryParse(v) ?? module.pageFrom;
                        if (module.pageTo < module.pageFrom) {
                          module.pageTo = module.pageFrom;
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: module.minMinutes.toString(),
                      decoration: _decoration('최소 학습 시간(분)'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          module.minMinutes = int.tryParse(v) ?? 0,
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('최소 시간 미달 시 미완료 처리'),
                      value: module.enforceMinMinutes,
                      onChanged: (v) =>
                          setState(() => module.enforceMinMinutes = v ?? false),
                    ),
                  ],
                  if (module.type == 'problem_solve') ...[
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('객관식 자동 구성'),
                      subtitle: const Text('정답을 기준으로 5개의 보기를 생성합니다.'),
                      value: module.multipleChoice,
                      onChanged: (v) =>
                          setState(() => module.multipleChoice = v),
                      secondary: const Icon(Icons.fact_check_rounded),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: module.passRate.toString(),
                            decoration: _decoration('이수 정답률(%)'),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => module.passRate =
                                (int.tryParse(v) ?? 90).clamp(1, 100),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: module.questionCount.toString(),
                            decoration: _decoration('출제 수'),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => module.questionCount =
                                (int.tryParse(v) ?? 5).clamp(1, 30),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: module.hashTags.join(', '),
                      decoration: _decoration('검색/생성 태그'),
                      onChanged: (v) {
                        module.hashTags
                          ..clear()
                          ..addAll(_splitCsv(v));
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: module.prompt,
                      decoration: _decoration('생성 프롬프트'),
                      maxLines: 2,
                      onChanged: (v) => module.prompt = v,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: module.solvesCount.toString(),
                            decoration: _decoration('풀이 수'),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => module.solvesCount =
                                (int.tryParse(v) ?? 4).clamp(1, 20),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: module.strategyLevel.toString(),
                            decoration: _decoration('전략 레벨'),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => module.strategyLevel =
                                (int.tryParse(v) ?? 2).clamp(1, 5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: module.branchConditions.toString(),
                            decoration: _decoration('분기 조건'),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => module.branchConditions =
                                (int.tryParse(v) ?? 1).clamp(0, 10),
                          ),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('태그를 엄격히 적용'),
                      value: module.strictTags,
                      onChanged: (v) =>
                          setState(() => module.strictTags = v ?? false),
                    ),
                    const SizedBox(height: 6),
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
                          onPressed: _saving
                              ? null
                              : () => _generateProblemForModule(module),
                          icon: const Icon(Icons.auto_fix_high_rounded),
                          label: const Text('생성해서 추가'),
                        ),
                      ],
                    ),
                    if (module.problemIds.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: module.problemIds
                            .map(
                              (id) => InputChip(
                                avatar: const Icon(
                                  Icons.quiz_rounded,
                                  size: 16,
                                ),
                                label: Text(id),
                                onDeleted: () => setState(
                                  () => module.problemIds.remove(id),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
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
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildTabContainer(Widget child, double scale) {
    return Padding(
      padding: EdgeInsets.all(12 * scale),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16 * scale),
          boxShadow: const [kCourseShadow],
        ),
        child: child,
      ),
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
    this.prompt = '',
    this.solvesCount = 4,
    this.strategyLevel = 2,
    this.branchConditions = 1,
    this.strictTags = false,
    this.referenceQuestId = '',
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
      prompt: generation['prompt']?.toString() ?? '',
      solvesCount: (generation['solves_count'] as num?)?.toInt() ?? 4,
      strategyLevel: (generation['strategy_level'] as num?)?.toInt() ?? 2,
      branchConditions: (generation['branch_conditions'] as num?)?.toInt() ?? 1,
      strictTags: generation['strict_tags'] == true,
      referenceQuestId: generation['reference_quest_id']?.toString() ?? '',
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
  String prompt;
  int solvesCount;
  int strategyLevel;
  int branchConditions;
  bool strictTags;
  String referenceQuestId;

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
      'estimated_minutes': estimatedMinutes,
      'max_problems': maxProblems,
    };
  }
}
