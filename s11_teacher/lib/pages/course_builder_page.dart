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
      _textbooks = books;
      if (_textbooks.isNotEmpty) {
        _selectedTextbookId =
            (_textbooks.first['textbook_id'] ?? _textbooks.first['id'])
                ?.toString();
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
    if ((_selectedTextbookId ?? '').isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('교재를 선택해 주세요.')));
      return;
    }

    for (final module in _modules) {
      if (module.type == 'textbook_view') {
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
            value: _difficulty,
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
          value: _selectedTextbookId,
          decoration: _decoration('교재 선택 *'),
          items: _textbooks
              .map(
                (book) => DropdownMenuItem(
                  value: (book['textbook_id'] ?? book['id'])?.toString(),
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
                    value: module.type,
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
                      value: module.textbookId.isNotEmpty
                          ? module.textbookId
                          : _selectedTextbookId,
                      decoration: _decoration('교재'),
                      items: _textbooks
                          .map(
                            (book) => DropdownMenuItem(
                              value: (book['textbook_id'] ?? book['id'])
                                  ?.toString(),
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
  });

  factory _ModuleDraft.fromJson(Map<String, dynamic> json) {
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
      'estimated_minutes': estimatedMinutes,
      'max_problems': maxProblems,
    };
  }
}
