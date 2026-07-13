import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/content_block.dart';
import '../models/exam_editor_layout.dart';
import '../models/exam_editor_models.dart';
import '../services/api_client.dart';
import '../shared/theme/app_colors.dart';
import '../shared/ui/ios26/ios26_chrome.dart';
import '../shared/ui/ios26/teacher_full_face_panel.dart';
import '../shared/ui/ios26/teacher_studio_shell.dart';
import '../widgets/content_blocks_view.dart';
import '../widgets/design_tokens.dart';
import '../widgets/teacher_app_drawer.dart';

enum _EditorLayoutMode { vertical, grid4, grid2, slider }

extension on _EditorLayoutMode {
  String get label {
    switch (this) {
      case _EditorLayoutMode.vertical:
        return '세로형';
      case _EditorLayoutMode.grid4:
        return '4개';
      case _EditorLayoutMode.grid2:
        return '2개';
      case _EditorLayoutMode.slider:
        return '슬라이더형';
    }
  }

  IconData get icon {
    switch (this) {
      case _EditorLayoutMode.vertical:
        return Icons.view_stream_rounded;
      case _EditorLayoutMode.grid4:
        return Icons.grid_view_rounded;
      case _EditorLayoutMode.grid2:
        return Icons.view_week_rounded;
      case _EditorLayoutMode.slider:
        return Icons.slideshow_rounded;
    }
  }
}

class ExamPaperEditorPage extends StatefulWidget {
  final String? initialExamId;
  final List<ExamEditorItem>? initialItems;

  const ExamPaperEditorPage({super.key, this.initialExamId, this.initialItems});

  @override
  State<ExamPaperEditorPage> createState() => _ExamPaperEditorPageState();
}

class _ExamPaperEditorPageState extends State<ExamPaperEditorPage> {
  final _searchCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _rng = math.Random();
  final Map<String, List<ContentBlock>> _contentCache = {};
  final Map<String, Map<String, dynamic>> _rawQuestCache = {};
  final Map<String, int> _sessionSeedCache = {};
  final Map<String, List<String>> _localMcqCache = {};
  final Map<String, double> _itemFontScale = {};
  final PageController _sliderController = PageController(
    viewportFraction: 0.92,
  );

  late ExamEditorState _state;
  _EditorLayoutMode _layoutMode = _EditorLayoutMode.grid4;
  String? _paperId;
  String? _paperUpdatedAt;

  String _searchMode = 'text';
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  String? _searchError;

  bool _aiArranging = false;
  String? _aiStatus;
  bool _saving = false;
  bool _deploying = false;
  String? _deployExamId;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    final initialItems = widget.initialItems ?? const <ExamEditorItem>[];
    _state = ExamEditorState(
      items: initialItems,
      pages: ExamEditorLayoutEngine.computeLayout(initialItems),
      examId: widget.initialExamId,
    );
    _titleCtrl.text = _state.title;
    _titleCtrl.addListener(_syncTitle);
    for (final item in initialItems) {
      _ensureSessionSeed(item);
    }
    _rebuildPages(notify: false);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _titleCtrl
      ..removeListener(_syncTitle)
      ..dispose();
    _sliderController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _syncTitle() {
    final next = _titleCtrl.text.trim();
    final safeTitle = next.isEmpty ? '시험지' : next;
    if (safeTitle == _state.title) return;
    setState(() => _state = _state.copyWith(title: safeTitle));
  }

  void _rebuildPages({bool notify = true}) {
    final pages = _layoutMode == _EditorLayoutMode.grid2
        ? ExamEditorLayoutEngine.computeTwoPerPageLayout(_state.items)
        : ExamEditorLayoutEngine.computeLayout(_state.items);
    if (!notify) {
      _state = _state.copyWith(pages: pages);
      return;
    }
    setState(() => _state = _state.copyWith(pages: pages));
  }

  dynamic _decodeStructuredValue(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
          (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
        try {
          return jsonDecode(trimmed);
        } catch (_) {
          return value;
        }
      }
    }
    return value;
  }

  String _contentCacheKey(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }

  List<ContentBlock> _blocksOf(dynamic value) {
    final decoded = _decodeStructuredValue(value);
    final key = _contentCacheKey(decoded);
    if (key.isEmpty) {
      return const <ContentBlock>[];
    }
    return _contentCache.putIfAbsent(key, () => parseContentBlocks(decoded));
  }

  String _plainTextOf(dynamic value) {
    final blocks = _blocksOf(value);
    final plain = contentBlocksToPlainText(blocks);
    if (plain.isNotEmpty) return plain;
    final decoded = _decodeStructuredValue(value);
    if (decoded == null) return '';
    if (decoded is List) {
      return decoded.map((entry) => _plainTextOf(entry)).join(' ').trim();
    }
    if (decoded is Map) {
      return _plainTextOf(
        decoded['content'] ?? decoded['text'] ?? decoded['blocks'],
      );
    }
    return decoded.toString().trim();
  }

  List<ContentBlock> _searchBlocksOf(Map<String, dynamic> quest) {
    return _blocksOf(
      quest['quest_title_text'] ??
          quest['title'] ??
          quest['quest_title'] ??
          quest['content'],
    );
  }

  List<String> _normalizedTagsOf(dynamic raw) {
    final source = raw is List ? raw : const <dynamic>[];
    return source
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  int _ensureSessionSeed(ExamEditorItem item) {
    return _sessionSeedCache.putIfAbsent(
      item.editorId,
      () => item.item.seed ?? 100000 + _rng.nextInt(900000),
    );
  }

  double _fontScaleFor(ExamEditorItem item) =>
      _itemFontScale[item.editorId] ?? 1.0;

  String _difficultyLabel(int tier) {
    if (tier >= 5) return '상';
    if (tier == 4) return '중상';
    if (tier == 3) return '중';
    if (tier == 2) return '중하';
    return '하';
  }

  Future<void> _performSearch() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _searchError = null;
    });

    try {
      late final List<Map<String, dynamic>> results;
      switch (_searchMode) {
        case 'hashtag':
          final payload = await ApiClient.instance.searchExamEditorProblems(
            hashTag: query,
            ownedOnly: true,
            pageSize: 200,
          );
          results = ((payload['items'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((entry) => Map<String, dynamic>.from(entry))
              .toList());
          break;
        case 'date':
          final parts = query.split('~').map((entry) => entry.trim()).toList();
          final payload = await ApiClient.instance.searchExamEditorProblems(
            dateFrom: parts.isNotEmpty ? parts.first : query,
            dateTo: parts.length > 1 ? parts[1] : null,
            ownedOnly: true,
            pageSize: 200,
          );
          results = ((payload['items'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((entry) => Map<String, dynamic>.from(entry))
              .toList());
          break;
        case 'text':
        default:
          final payload = await ApiClient.instance.searchExamEditorProblems(
            text: query,
            ownedOnly: true,
            pageSize: 200,
          );
          results = ((payload['items'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((entry) => Map<String, dynamic>.from(entry))
              .toList());
      }
      if (!mounted) return;
      setState(() => _searchResults = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _searchError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  void _addItemFromSearch(Map<String, dynamic> quest) {
    if (!_state.canAddMore) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('문제는 최대 100개까지 담을 수 있습니다.')));
      return;
    }

    final seed =
        (quest['seed'] as num?)?.toInt() ?? 100000 + _rng.nextInt(900000);
    final item = ExamItem.fromJson({
      'item_index': _state.items.length,
      'status': 'done',
      'subject_key': 'custom',
      'hash_tags': quest['hash_tags'] as List<dynamic>? ?? const <dynamic>[],
      'difficulty_tier': (quest['difficulty_tier'] as num?)?.toInt() ?? 3,
      'solves_count': (quest['solves_count'] as num?)?.toInt() ?? 5,
      'strategy_level': (quest['strategy_level'] as num?)?.toInt() ?? 3,
      'branch_conditions': (quest['branch_conditions'] as num?)?.toInt() ?? 2,
      'question_type': quest['question_type']?.toString(),
      'quest_id': quest['quest_id']?.toString(),
      'flow_count': (quest['flow_count'] as num?)?.toInt() ?? 3,
      'codebase_id': (quest['codebase_id'] as num?)?.toInt(),
      'seed': seed,
      'quest_title':
          quest['quest_title'] ?? quest['quest_title_text'] ?? quest['content'],
      'quest_options': quest['quest_options'] as List<dynamic>?,
      'error': null,
    });
    final editorItem = ExamEditorItem.fromExamItem(item, _state.items.length);
    _rawQuestCache[editorItem.editorId] = quest;
    _ensureSessionSeed(editorItem);
    final newItems = ExamEditorLayoutEngine.insertAt(
      _state.items,
      _state.items.length,
      editorItem,
    );
    setState(() {
      _state = _state.copyWith(items: newItems);
    });
    _rebuildPages();
  }

  void _removeItem(int index) {
    final removed = _state.items[index];
    final newItems = ExamEditorLayoutEngine.removeAt(_state.items, index);
    setState(() {
      _rawQuestCache.remove(removed.editorId);
      _sessionSeedCache.remove(removed.editorId);
      _localMcqCache.remove(removed.editorId);
      _itemFontScale.remove(removed.editorId);
      _state = _state.copyWith(items: newItems);
    });
    _rebuildPages();
  }

  void _reorderItems(int oldIndex, int newIndex) {
    final newItems = ExamEditorLayoutEngine.reorder(
      _state.items,
      oldIndex,
      newIndex,
    );
    setState(() => _state = _state.copyWith(items: newItems));
    _rebuildPages();
  }

  void _swapItems(String sourceEditorId, String targetEditorId) {
    final items = List<ExamEditorItem>.from(_state.items);
    final from = items.indexWhere((item) => item.editorId == sourceEditorId);
    final to = items.indexWhere((item) => item.editorId == targetEditorId);
    if (from < 0 || to < 0 || from == to) return;
    final source = items[from];
    items[from] = items[to].copyWith(displayIndex: from);
    items[to] = source.copyWith(displayIndex: to);
    for (var i = 0; i < items.length; i++) {
      items[i] = items[i].copyWith(displayIndex: i);
    }
    setState(() => _state = _state.copyWith(items: items));
    _rebuildPages();
  }

  void _adjustGlobalFont(bool increase) {
    final next = (_state.fontScale + (increase ? 0.05 : -0.05)).clamp(0.7, 1.6);
    setState(() => _state = _state.copyWith(fontScale: next));
  }

  void _adjustItemFont(ExamEditorItem item, bool increase) {
    final current = _fontScaleFor(item);
    final next = (current + (increase ? 0.05 : -0.05)).clamp(0.8, 1.5);
    setState(() => _itemFontScale[item.editorId] = next);
  }

  List<String> _generateNumericChoices(num target, int seed) {
    final rng = math.Random(seed);
    final values = <num>{target};
    final steps = <num>[1, 2, 3, 5, 10];
    while (values.length < 5) {
      final step = steps[rng.nextInt(steps.length)];
      final op = rng.nextInt(3);
      num candidate;
      if (op == 0) {
        candidate = target + step;
      } else if (op == 1) {
        candidate = target - step;
      } else {
        final factor = rng.nextBool() ? 2 : 3;
        candidate = target * factor;
      }
      values.add(candidate);
    }
    final choices = values.toList()..shuffle(rng);
    return choices
        .map((value) {
          if (value is int || value == value.roundToDouble()) {
            return value.round().toString();
          }
          return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
        })
        .toList(growable: false);
  }

  List<String> _generateTextChoices(String content, int seed) {
    final rng = math.Random(seed);
    final tokens = content
        .split(RegExp(r'[\s,.;:()\[\]{}]+'))
        .map((token) => token.trim())
        .where((token) => token.length >= 2)
        .toSet()
        .toList();
    tokens.shuffle(rng);
    final basis = tokens.take(2).join(' ');
    final stem = basis.isEmpty ? '조건' : basis;
    final choices = <String>[
      '$stem 이(가) 항상 성립한다',
      '$stem 에 1을 더한 경우',
      '$stem 에 2를 더한 경우',
      '$stem 을(를) 2배 한 경우',
      '$stem 과 무관한 경우',
    ];
    choices.shuffle(rng);
    return choices;
  }

  void _makeLocalMultipleChoice(ExamEditorItem item) {
    if (_localMcqCache.containsKey(item.editorId)) return;
    final raw = _rawQuestCache[item.editorId] ?? const <String, dynamic>{};
    final sourceAnswer = _plainTextOf(
      raw['quest_answer'] ??
          raw['answer'] ??
          raw['answer_text'] ??
          raw['solution'],
    );
    final sourceBody = _plainTextOf(
      raw['quest_title'] ??
          raw['quest_title_text'] ??
          raw['title'] ??
          item.item.questTitle,
    );
    final numbers = RegExp(r'-?\d+(?:\.\d+)?')
        .allMatches(sourceAnswer.isNotEmpty ? sourceAnswer : sourceBody)
        .map((match) => num.tryParse(match.group(0)!))
        .whereType<num>()
        .toList();
    final seed = _ensureSessionSeed(item);
    final choices = numbers.isNotEmpty
        ? _generateNumericChoices(numbers.last, seed)
        : _generateTextChoices(sourceBody, seed);
    setState(() => _localMcqCache[item.editorId] = choices);
  }

  List<String> _optionsFor(ExamEditorItem item) {
    final local = _localMcqCache[item.editorId];
    if (local != null && local.isNotEmpty) return local;
    return item.options;
  }

  Future<void> _saveToDocumentBox() async {
    if (_state.items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('문제를 1개 이상 추가해 주세요.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final saved = await ApiClient.instance.saveExamEditorPaper(
        paperId: _paperId,
        title: _state.title,
        twoPerPage: _layoutMode == _EditorLayoutMode.grid2,
        gradingAreaDirection: 'bottom',
        expectedUpdatedAt: _paperUpdatedAt,
        items: _state.items.asMap().entries.map((entry) {
          final index = entry.key;
          final editorItem = entry.value;
          return {
            'order_no': index,
            'page_no': index + 1,
            'layout_slot': _layoutMode.label,
            'codebase_id': editorItem.item.codebaseId,
            'seed': _ensureSessionSeed(editorItem),
            'quest_id': editorItem.item.questId,
            'question_type': editorItem.item.questionType,
            'is_geometry': editorItem.isGeometry,
          };
        }).toList(),
      );
      _paperId = saved['paper_id']?.toString();
      _paperUpdatedAt = saved['updated_at']?.toString();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시험지를 교사 문서함 저장 대상으로 보관했습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('문서함 저장 실패: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deployForPdfIfNeeded() async {
    await _saveToDocumentBox();
    if (_paperId == null || _paperId!.isEmpty) {
      throw Exception('paper_id missing');
    }
    if (_state.examId != null || _deployExamId != null) return;
    final deploy = await ApiClient.instance.deployExamEditorPaper(_paperId!);
    final examId = deploy['exam_id']?.toString() ?? '';
    if (examId.isEmpty) {
      throw Exception('exam_id missing');
    }
    _deployExamId = examId;
    _state = _state.copyWith(examId: examId);
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final examId = _deployExamId;
      if (examId == null) {
        timer.cancel();
        return;
      }
      try {
        final status = await ApiClient.instance.getExamStatus(examId);
        if (status.status == 'completed' || status.status == 'failed') {
          timer.cancel();
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('PDF 상태: ${status.status}')));
        }
      } catch (_) {
        timer.cancel();
      }
    });
  }

  Future<void> _downloadPdf() async {
    if (_state.items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PDF를 만들 문제를 먼저 담아 주세요.')));
      return;
    }

    setState(() => _deploying = true);
    try {
      await _deployForPdfIfNeeded();
      final examId = _state.examId ?? _deployExamId;
      if (examId == null || examId.isEmpty) {
        throw Exception('exam_id missing');
      }
      final url = await ApiClient.instance.examPdfUrl(examId);
      final uri = Uri.parse(url);
      if (Platform.isAndroid || Platform.isIOS) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF URL: $url'),
            action: SnackBarAction(
              label: '열기',
              onPressed: () async {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF 생성 실패: $e')));
    } finally {
      if (mounted) {
        setState(() => _deploying = false);
      }
    }
  }

  Future<void> _aiArrange() async {
    if (_state.items.isEmpty) return;
    setState(() {
      _aiArranging = true;
      _aiStatus = '문제 배치를 정리하는 중입니다.';
    });
    try {
      final response = await ApiClient.instance.arrangeExamEditorAi(
        paperId: _paperId,
        instruction: _buildArrangePrompt(),
        items: _state.items.asMap().entries.map((entry) {
          final index = entry.key;
          final editorItem = entry.value;
          return {
            'order_no': index,
            'page_no': index + 1,
            'layout_slot': _layoutMode.label,
            'codebase_id': editorItem.item.codebaseId,
            'seed': _ensureSessionSeed(editorItem),
            'quest_id': editorItem.item.questId,
            'question_type': editorItem.item.questionType,
            'is_geometry': editorItem.isGeometry,
          };
        }).toList(),
      );
      if (response['accepted'] != true) {
        setState(() => _aiStatus = '배치 요청이 거절되었습니다.');
        return;
      }
      final orderedIds = (response['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((entry) => entry['quest_id']?.toString() ?? '')
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
      final byQuestId = <String, ExamEditorItem>{
        for (final item in _state.items)
          if ((item.item.questId ?? '').isNotEmpty) item.item.questId!: item,
      };
      final reordered = <ExamEditorItem>[
        for (final questId in orderedIds)
          if (byQuestId.containsKey(questId)) byQuestId[questId]!,
      ];
      if (reordered.length != _state.items.length) {
        reordered
          ..clear()
          ..addAll(
            List<ExamEditorItem>.from(_state.items)..sort(
              (a, b) => a.item.difficultyTier.compareTo(b.item.difficultyTier),
            ),
          );
      }
      for (var i = 0; i < reordered.length; i++) {
        reordered[i] = reordered[i].copyWith(displayIndex: i);
      }
      setState(() {
        _state = _state.copyWith(items: reordered);
        _aiStatus = '배치를 정리했습니다.';
      });
      _rebuildPages();
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiStatus = '배치 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _aiArranging = false);
      }
    }
  }

  String _buildArrangePrompt() {
    final buffer = StringBuffer()
      ..writeln('시험지 배치 요청')
      ..writeln('레이아웃: ${_layoutMode.label}')
      ..writeln('총 문제 수: ${_state.items.length}');
    for (final item in _state.items) {
      buffer.writeln(
        '- 난이도 ${_difficultyLabel(item.item.difficultyTier)} / ${_plainTextOf(item.item.questTitle)}',
      );
    }
    return buffer.toString();
  }

  Map<String, int> get _tagStats {
    final stats = <String, int>{};
    for (final item in _state.items) {
      for (final tag in item.item.hashTags) {
        stats[tag] = (stats[tag] ?? 0) + 1;
      }
    }
    final entries = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final entry in entries) entry.key: entry.value};
  }

  Map<String, int> get _difficultyStats {
    final buckets = <String, int>{'상': 0, '중상': 0, '중': 0, '중하': 0, '하': 0};
    for (final item in _state.items) {
      final label = _difficultyLabel(item.item.difficultyTier);
      buckets[label] = (buckets[label] ?? 0) + 1;
    }
    return buckets;
  }

  Future<void> _showLayoutSheet() async {
    final selected = await Navigator.of(context).push<_EditorLayoutMode>(
      MaterialPageRoute<_EditorLayoutMode>(
        fullscreenDialog: true,
        builder: (context) => TeacherFullFacePanel(
          eyebrow: 'EXAM STUDIO',
          title: '레이아웃 조절',
          description: '시험지 출력 방식은 문항 데이터나 저장 구조를 변경하지 않습니다.',
          content: ListView(
            children: [
              for (final mode in _EditorLayoutMode.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: mode == _layoutMode
                            ? kCourseGreen
                            : AppColors.surfaceBorder,
                      ),
                    ),
                    tileColor: mode == _layoutMode
                        ? kCourseGreen
                        : Colors.white,
                    textColor: mode == _layoutMode
                        ? Colors.white
                        : Colors.black,
                    iconColor: mode == _layoutMode
                        ? Colors.white
                        : Colors.black,
                    leading: Icon(mode.icon),
                    title: Text(
                      mode.label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    trailing: mode == _layoutMode
                        ? const Icon(Icons.check_rounded)
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).pop(mode),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _layoutMode = selected);
    _rebuildPages();
  }

  Future<void> _showStatsSheet() async {
    final tags = _tagStats.entries.take(12).toList();
    final difficulties = _difficultyStats.entries.toList();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => TeacherFullFacePanel(
          eyebrow: 'EXAM STUDIO',
          title: '문항 통계',
          description: '현재 편집 중인 문항을 로컬 상태에서 집계합니다.',
          content: ListView(
            children: [
              _buildStatTile('총 문제 수', '${_state.items.length}개'),
              _buildStatTile('레이아웃', _layoutMode.label),
              _buildStatTile(
                '객관식 문제',
                '${_state.items.where((item) => _optionsFor(item).isNotEmpty).length}개',
              ),
              _buildStatTile(
                '기하 문제',
                '${_state.items.where((item) => item.isGeometry).length}개',
              ),
              const SizedBox(height: 18),
              const Text(
                '난이도 분포',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              for (final entry in difficulties)
                _buildStatTile(entry.key, '${entry.value}개'),
              const SizedBox(height: 18),
              const Text(
                '태그 사용량',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (tags.isEmpty)
                const Text('아직 태그 통계가 없습니다.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags
                      .map(
                        (entry) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: const Color(0xFFF2F2F4),
                            border: Border.all(color: const Color(0xFFD4D4D8)),
                          ),
                          child: Text('#${entry.key} ${entry.value}'),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFF7F7F8),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = courseUiScale(context);
    return TeacherStudioShell(
      currentRoute: '/exam-editor',
      eyebrow: 'EXAM STUDIO',
      title: '시험지 제작 스튜디오',
      description: '문제 검색부터 AI 배치·PDF 출력까지 한 작업면에서 이어갑니다.',
      endDrawer: const TeacherAppDrawer(currentRoute: '/exam-editor'),
      onBack: Navigator.of(context).canPop()
          ? () => Navigator.of(context).pop()
          : null,
      topItems: const [
        Ios26NavItem(label: '검색'),
        Ios26NavItem(label: '편집', active: true),
        Ios26NavItem(label: '미리보기'),
      ],
      actions: [
        TeacherStudioAction(
          label: _aiArranging ? '배치 중' : 'AI 배치',
          icon: Icons.auto_awesome_rounded,
          onTap: _aiArranging ? null : _aiArrange,
        ),
        TeacherStudioAction(
          label: _saving ? '저장 중' : '문서함 저장',
          icon: Icons.folder_copy_rounded,
          onTap: _saving ? null : _saveToDocumentBox,
        ),
        TeacherStudioAction(
          label: _deploying ? '준비 중' : 'PDF',
          icon: Icons.picture_as_pdf_rounded,
          onTap: _deploying ? null : _downloadPdf,
          primary: true,
        ),
      ],
      child: Column(
        children: [
          _buildTopBar(scale),
          Expanded(child: _buildResponsiveEditor(scale)),
        ],
      ),
    );
  }

  /// 필요 변수: 화면 배율 [scale]과 기존 검색·미리보기·설정 패널.
  /// 작동 원리: 기능 위젯은 그대로 두고 PC에서는 카드형 3단, 모바일에서는 3개 탭으로 재배치한다.
  Widget _buildResponsiveEditor(double scale) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1080) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20 * scale,
              8 * scale,
              20 * scale,
              20 * scale,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 278 * scale,
                  child: _buildEditorSurface(_buildLeftPanel(scale)),
                ),
                SizedBox(width: 14 * scale),
                Expanded(child: _buildEditorSurface(_buildPreviewArea(scale))),
                SizedBox(width: 14 * scale),
                SizedBox(
                  width: 270 * scale,
                  child: _buildEditorSurface(_buildInspectorPanel(scale)),
                ),
              ],
            ),
          );
        }
        if (constraints.maxWidth >= 720) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16 * scale,
              8 * scale,
              16 * scale,
              16 * scale,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 290 * scale,
                  child: _buildEditorSurface(_buildLeftPanel(scale)),
                ),
                SizedBox(width: 12 * scale),
                Expanded(child: _buildEditorSurface(_buildPreviewArea(scale))),
              ],
            ),
          );
        }
        return DefaultTabController(
          length: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TeacherStudioTabStrip(labels: ['문제 검색', '시험지', '편집 설정']),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    12 * scale,
                    8 * scale,
                    12 * scale,
                    0,
                  ),
                  child: TabBarView(
                    children: [
                      _buildEditorSurface(_buildLeftPanel(scale)),
                      _buildEditorSurface(_buildPreviewArea(scale)),
                      _buildEditorSurface(_buildInspectorPanel(scale)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 필요 변수: 기존 검색·미리보기·설정 위젯.
  /// 작동 원리: 내부 기능에는 관여하지 않고 공통 카드 경계와 둥근 클리핑만 적용한다.
  Widget _buildEditorSurface(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.surfaceBorder),
          boxShadow: const [kCourseShadow],
        ),
        child: child,
      ),
    );
  }

  Widget _buildTopBar(double scale) {
    final fontPt = (14 * _state.fontScale).toStringAsFixed(1);
    final titleField = TextField(
      controller: _titleCtrl,
      decoration: const InputDecoration(
        border: InputBorder.none,
        hintText: '시험지 제목',
      ),
      style: TextStyle(
        fontSize: 22 * scale,
        fontWeight: FontWeight.w700,
        color: kCourseGreen,
      ),
    );
    final toolbar = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildToolbarChip(
            icon: Icons.remove_rounded,
            label: 'pt',
            onTap: () => _adjustGlobalFont(false),
            trailing: Text(fontPt),
          ),
          SizedBox(width: 8 * scale),
          _buildToolbarChip(
            icon: Icons.add_rounded,
            label: 'pt',
            onTap: () => _adjustGlobalFont(true),
          ),
          SizedBox(width: 8 * scale),
          _buildToolbarChip(
            icon: _layoutMode.icon,
            label: _layoutMode.label,
            onTap: _showLayoutSheet,
          ),
          SizedBox(width: 8 * scale),
          _buildToolbarChip(
            icon: Icons.query_stats_rounded,
            label: '통계',
            onTap: _showStatsSheet,
          ),
        ],
      ),
    );
    return Container(
      margin: EdgeInsets.fromLTRB(18 * scale, 0, 18 * scale, 0),
      padding: EdgeInsets.fromLTRB(
        18 * scale,
        14 * scale,
        18 * scale,
        12 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 900) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleField,
                    SizedBox(height: 8 * scale),
                    toolbar,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: titleField),
                  SizedBox(width: 14 * scale),
                  Flexible(flex: 2, child: toolbar),
                ],
              );
            },
          ),
          if (_aiStatus != null || _paperId != null) ...[
            SizedBox(height: 10 * scale),
            Row(
              children: [
                if (_aiStatus != null)
                  Expanded(
                    child: Text(
                      _aiStatus!,
                      style: TextStyle(
                        fontSize: 12 * scale,
                        color: kCourseGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (_paperId != null)
                  Text(
                    '저장 ID ${_paperId!.substring(0, _paperId!.length.clamp(0, 12))}',
                    style: TextStyle(
                      fontSize: 11 * scale,
                      color: Colors.black54,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolbarChip({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Widget? trailing,
    bool filled = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: filled ? kCourseGreen : const Color(0xFFF4F4F5),
          border: Border.all(
            color: filled ? kCourseGreen : const Color(0xFFD4D4D8),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: filled ? Colors.white : kCourseGreen),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : Colors.black87,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              DefaultTextStyle(
                style: TextStyle(
                  fontSize: 12,
                  color: filled ? Colors.white : Colors.black54,
                ),
                child: trailing,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 필요 변수: 화면 배율 [scale], 현재 레이아웃·글자 크기·문항 통계 상태.
  /// 작동 원리: 기존 하단 시트에서 제공하던 설정을 PC에서는 상시 노출하고,
  /// 모바일에서는 편집 설정 탭 안에 표시해 별도 API 호출 없이 같은 상태를 수정한다.
  Widget _buildInspectorPanel(double scale) {
    final objectiveCount = _state.items
        .where((item) => _optionsFor(item).isNotEmpty)
        .length;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: ListView(
        padding: EdgeInsets.all(18 * scale),
        children: [
          Text(
            '편집 설정',
            style: TextStyle(
              color: kCourseGreen,
              fontSize: 22 * scale,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6 * scale),
          Text(
            '레이아웃과 출력 밀도를 실시간으로 조절합니다.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 12 * scale,
              height: 1.4,
            ),
          ),
          SizedBox(height: 20 * scale),
          const Text('레이아웃', style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 10 * scale),
          for (final mode in _EditorLayoutMode.values)
            Padding(
              padding: EdgeInsets.only(bottom: 8 * scale),
              child: _buildInspectorChoice(
                icon: mode.icon,
                label: mode.label,
                selected: mode == _layoutMode,
                onTap: () {
                  setState(() => _layoutMode = mode);
                  _rebuildPages();
                },
              ),
            ),
          SizedBox(height: 14 * scale),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '문제 글자',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${(14 * _state.fontScale).toStringAsFixed(1)} pt',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          Slider(
            value: _state.fontScale,
            min: 0.7,
            max: 1.6,
            divisions: 18,
            onChanged: (value) =>
                setState(() => _state = _state.copyWith(fontScale: value)),
          ),
          SizedBox(height: 8 * scale),
          Container(
            padding: EdgeInsets.all(16 * scale),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '문항 통계',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 12 * scale),
                _buildInspectorMetric('전체', '${_state.items.length}문항'),
                _buildInspectorMetric('객관식', '$objectiveCount문항'),
                _buildInspectorMetric(
                  '기하',
                  '${_state.items.where((item) => item.isGeometry).length}문항',
                ),
              ],
            ),
          ),
          SizedBox(height: 14 * scale),
          OutlinedButton.icon(
            onPressed: _showStatsSheet,
            icon: const Icon(Icons.query_stats_rounded),
            label: const Text('상세 통계 보기'),
          ),
          SizedBox(height: 8 * scale),
          FilledButton.icon(
            onPressed: _deploying ? null : _downloadPdf,
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: Text(_deploying ? 'PDF 준비중' : 'PDF 출력'),
          ),
        ],
      ),
    );
  }

  /// 필요 변수: 아이콘, 라벨, 선택 여부, 선택 콜백.
  /// 작동 원리: 선택 상태는 검정 면으로, 나머지는 흰색 경계 카드로 표현한다.
  Widget _buildInspectorChoice({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? kCourseGreen : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? kCourseGreen : AppColors.surfaceBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : Colors.black),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, size: 18, color: Colors.white),
          ],
        ),
      ),
    );
  }

  /// 필요 변수: 통계명 [label], 표시값 [value].
  /// 작동 원리: 계산된 로컬 편집 상태를 한 줄 요약으로 표시한다.
  Widget _buildInspectorMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildLeftPanel(double scale) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              18 * scale,
              22 * scale,
              18 * scale,
              18 * scale,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '문제 검색',
                  style: TextStyle(
                    fontSize: 26 * scale,
                    fontWeight: FontWeight.w900,
                    color: kCourseGreen,
                  ),
                ),
                SizedBox(height: 18 * scale),
                _buildSearchModeControl(scale),
                SizedBox(height: 14 * scale),
                _buildSearchField(scale),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.surfaceBorder),
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator())
                : _searchError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        '검색 실패: $_searchError',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  )
                : _buildSearchResults(scale),
          ),
          _buildProblemSetHeader(scale),
          Flexible(child: _buildProblemSet(scale)),
        ],
      ),
    );
  }

  Widget _buildSearchModeControl(double scale) {
    const modes = [
      ('text', Icons.check_rounded, '텍스트'),
      ('hashtag', Icons.sell_rounded, '태그'),
      ('date', Icons.calendar_month_rounded, '날짜'),
    ];

    return Container(
      height: 48 * scale,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24 * scale),
        border: Border.all(color: Colors.black54, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final mode in modes)
            Expanded(
              child: _buildSearchModeButton(
                value: mode.$1,
                icon: mode.$2,
                label: mode.$3,
                scale: scale,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchModeButton({
    required String value,
    required IconData icon,
    required String label,
    required double scale,
  }) {
    final selected = _searchMode == value;
    return InkWell(
      onTap: () => setState(() => _searchMode = value),
      child: Container(
        height: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? kCourseGreen.withValues(alpha: 0.16)
              : Colors.transparent,
          border: Border(
            right: value == 'date'
                ? BorderSide.none
                : const BorderSide(color: Colors.black45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(icon, size: 18 * scale, color: kCourseGreen),
              SizedBox(width: 8 * scale),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16 * scale,
                  color: Colors.black87,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(double scale) {
    return SizedBox(
      height: 62 * scale,
      child: TextField(
        controller: _searchCtrl,
        onSubmitted: (_) => _performSearch(),
        style: TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: _searchHintText,
          hintStyle: TextStyle(
            color: Colors.black54,
            fontSize: 18 * scale,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: AppColors.surfaceMuted,
          contentPadding: EdgeInsets.symmetric(horizontal: 20 * scale),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18 * scale),
            borderSide: const BorderSide(color: AppColors.surfaceBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18 * scale),
            borderSide: const BorderSide(color: AppColors.surfaceBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18 * scale),
            borderSide: const BorderSide(color: kCourseLightGreen, width: 2),
          ),
          suffixIcon: IconButton(
            tooltip: '검색',
            onPressed: _performSearch,
            icon: Icon(
              Icons.search_rounded,
              size: 28 * scale,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  String get _searchHintText {
    return switch (_searchMode) {
      'hashtag' => '태그 검색',
      'date' => '날짜 검색',
      _ => '문제 내용 검색',
    };
  }

  Widget _buildProblemSetHeader(double scale) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        18 * scale,
        16 * scale,
        18 * scale,
        16 * scale,
      ),
      color: const Color(0xFFF1F3F2),
      child: Row(
        children: [
          Icon(Icons.folder_outlined, size: 22 * scale, color: kCourseGreen),
          SizedBox(width: 10 * scale),
          Text(
            'My Problem Set',
            style: TextStyle(
              fontSize: 18 * scale,
              fontWeight: FontWeight.w900,
              color: kCourseGreen,
            ),
          ),
          const Spacer(),
          Text(
            '${_state.items.length}/100',
            style: TextStyle(
              fontSize: 14 * scale,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(double scale) {
    if (_searchResults.isEmpty) {
      return _buildEmptyMessage('검색 결과가 없습니다.', scale);
    }
    return ListView.separated(
      padding: EdgeInsets.all(14 * scale),
      itemBuilder: (context, index) {
        final quest = _searchResults[index];
        final titleBlocks = _searchBlocksOf(quest);
        final tags = _normalizedTagsOf(quest['hash_tags']).take(4).toList();
        return Container(
          padding: EdgeInsets.all(14 * scale),
          decoration: BoxDecoration(
            color: const Color(0xFFFDFDFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE3E3E7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ContentBlocksView(
                blocks: titleBlocks,
                textStyle: TextStyle(
                  fontSize: 14 * scale,
                  height: 1.55,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                latexStyle: TextStyle(fontSize: 14 * scale, height: 1.55),
              ),
              SizedBox(height: 10 * scale),
              Wrap(
                spacing: 6 * scale,
                runSpacing: 6 * scale,
                children: [
                  for (final tag in tags) _buildTagPill('#$tag', scale),
                ],
              ),
              SizedBox(height: 10 * scale),
              Row(
                children: [
                  Text(
                    '난이도 ${_difficultyLabel((quest['difficulty_tier'] as num?)?.toInt() ?? 3)}',
                    style: TextStyle(
                      fontSize: 11 * scale,
                      color: Colors.black54,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: () => _addItemFromSearch(quest),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('담기'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      separatorBuilder: (_, __) => SizedBox(height: 10 * scale),
      itemCount: _searchResults.length,
    );
  }

  Widget _buildProblemSet(double scale) {
    if (_state.items.isEmpty) {
      return _buildEmptyMessage('문제를 담으면 여기에서 순서를 정리합니다.', scale);
    }
    return ReorderableListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8 * scale),
      itemCount: _state.items.length,
      onReorder: _reorderItems,
      itemBuilder: (context, index) {
        final item = _state.items[index];
        final tags = item.item.hashTags.take(3);
        final hasMcq = _optionsFor(item).isNotEmpty;
        return ReorderableDragStartListener(
          key: ValueKey(item.editorId),
          index: index,
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: 10 * scale,
              vertical: 4 * scale,
            ),
            padding: EdgeInsets.all(12 * scale),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE3E3E7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28 * scale,
                      height: 28 * scale,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: kCourseGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 12 * scale,
                          fontWeight: FontWeight.w700,
                          color: kCourseGreen,
                        ),
                      ),
                    ),
                    SizedBox(width: 8 * scale),
                    Expanded(
                      child: Text(
                        _plainTextOf(item.item.questTitle),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13 * scale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeItem(index),
                      icon: Icon(Icons.close_rounded, size: 18 * scale),
                    ),
                  ],
                ),
                SizedBox(height: 8 * scale),
                Wrap(
                  spacing: 6 * scale,
                  runSpacing: 6 * scale,
                  children: [
                    _buildTagPill(
                      _difficultyLabel(item.item.difficultyTier),
                      scale,
                    ),
                    if (item.isGeometry) _buildTagPill('기하', scale),
                    if (hasMcq) _buildTagPill('객관식', scale),
                    for (final tag in tags) _buildTagPill('#$tag', scale),
                  ],
                ),
                SizedBox(height: 8 * scale),
                Wrap(
                  spacing: 8 * scale,
                  runSpacing: 6 * scale,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: hasMcq
                          ? null
                          : () => _makeLocalMultipleChoice(item),
                      icon: const Icon(Icons.auto_fix_high_rounded),
                      label: const Text('객관식으로 변경'),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 10 * scale),
                      child: Text(
                        'seed ${_ensureSessionSeed(item)}',
                        style: TextStyle(
                          fontSize: 11 * scale,
                          color: Colors.black45,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyMessage(String message, double scale) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 18 * scale),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17 * scale,
            color: Colors.black45,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTagPill(String label, double scale) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 6 * scale,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD4D4D8)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11 * scale, color: const Color(0xFF52525B)),
      ),
    );
  }

  Widget _buildPreviewArea(double scale) {
    if (_state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 60 * scale,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 12 * scale),
            Text(
              '왼쪽에서 문제를 담아 시험지를 구성하세요.',
              style: TextStyle(fontSize: 16 * scale, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    switch (_layoutMode) {
      case _EditorLayoutMode.vertical:
        return _buildVerticalPreview(scale);
      case _EditorLayoutMode.slider:
        return _buildSliderPreview(scale);
      case _EditorLayoutMode.grid4:
      case _EditorLayoutMode.grid2:
        return _buildGridPreview(scale);
    }
  }

  Widget _buildVerticalPreview(double scale) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24 * scale),
      child: Column(
        children: [
          for (var i = 0; i < _state.items.length; i++) ...[
            _buildSingleProblemPage(_state.items[i], i, scale),
            SizedBox(height: 22 * scale),
          ],
        ],
      ),
    );
  }

  Widget _buildSliderPreview(double scale) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 26 * scale),
      child: PageView.builder(
        controller: _sliderController,
        itemCount: _state.items.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 8 * scale),
            child: _buildSingleProblemPage(_state.items[index], index, scale),
          );
        },
      ),
    );
  }

  Widget _buildGridPreview(double scale) {
    return Container(
      color: const Color(0xFFF2F2F4),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24 * scale),
        child: Column(
          children: [
            for (
              var pageIndex = 0;
              pageIndex < _state.pages.length;
              pageIndex++
            ) ...[
              _buildGridPage(pageIndex, scale),
              if (pageIndex < _state.pages.length - 1)
                SizedBox(height: 24 * scale),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSingleProblemPage(ExamEditorItem item, int index, double scale) {
    const paperWidth = 794.0;
    const paperHeight = paperWidth * 297 / 210;
    return Container(
      width: paperWidth * scale,
      height: paperHeight * scale,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20 * scale),
        child: _buildProblemCard(
          item,
          scale,
          dragTargetId: item.editorId,
          pageLabel: '${index + 1}/${_state.items.length}',
        ),
      ),
    );
  }

  Widget _buildGridPage(int pageIndex, double scale) {
    final page = _state.pages[pageIndex];
    const paperWidth = 794.0;
    const paperHeight = paperWidth * 297 / 210;
    return Container(
      width: paperWidth * scale,
      height: paperHeight * scale,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 44 * scale,
              padding: EdgeInsets.symmetric(horizontal: 18 * scale),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.surfaceBorder),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    _state.title,
                    style: TextStyle(
                      fontSize: 13 * scale,
                      fontWeight: FontWeight.w700,
                      color: kCourseGreen,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${pageIndex + 1}/${_state.pages.length}',
                    style: TextStyle(
                      fontSize: 11 * scale,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            top: 44 * scale,
            bottom: 26 * scale,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columnWidth = constraints.maxWidth / 2;
                final rowHeight = constraints.maxHeight / 2;
                return Stack(
                  children: [
                    for (final entry in page.entries)
                      Positioned(
                        left: entry.column * columnWidth,
                        top: entry.row * rowHeight,
                        width: columnWidth,
                        height: rowHeight * entry.rowSpan,
                        child: Padding(
                          padding: EdgeInsets.all(8 * scale),
                          child: _buildProblemCard(
                            entry.editorItem,
                            scale,
                            dragTargetId: entry.editorItem.editorId,
                            pageLabel: 'p${pageIndex + 1}',
                          ),
                        ),
                      ),
                    Positioned(
                      left: constraints.maxWidth / 2 - 0.5,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 1,
                        color: const Color(0xFFE4E4E7),
                      ),
                    ),
                    if (page.entries.any((entry) => entry.rowSpan == 1))
                      Positioned(
                        left: 0,
                        right: 0,
                        top: constraints.maxHeight / 2 - 0.5,
                        child: Container(
                          height: 1,
                          color: const Color(0xFFE4E4E7),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 26 * scale,
              padding: EdgeInsets.symmetric(horizontal: 18 * scale),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _layoutMode.label,
                  style: TextStyle(fontSize: 10 * scale, color: Colors.black45),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemCard(
    ExamEditorItem item,
    double scale, {
    required String dragTargetId,
    required String pageLabel,
  }) {
    final fontSize = 14.0 * _state.fontScale * _fontScaleFor(item) * scale;
    final contentBlocks = _blocksOf(item.item.questTitle);
    final options = _optionsFor(item);
    final title = _plainTextOf(item.item.questTitle);
    final tags = item.item.hashTags.take(4).toList();
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != dragTargetId,
      onAcceptWithDetails: (details) => _swapItems(details.data, dragTargetId),
      builder: (context, candidateData, rejectedData) {
        final highlighted = candidateData.isNotEmpty;
        return LongPressDraggable<String>(
          data: item.editorId,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 260 * scale,
              child: _buildDragGhost(title, scale),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.55,
            child: _buildProblemCardBody(
              item,
              contentBlocks,
              options,
              tags,
              fontSize,
              scale,
              highlighted,
              pageLabel,
            ),
          ),
          child: _buildProblemCardBody(
            item,
            contentBlocks,
            options,
            tags,
            fontSize,
            scale,
            highlighted,
            pageLabel,
          ),
        );
      },
    );
  }

  Widget _buildDragGhost(String title, double scale) {
    return Container(
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kCourseLightGreen, width: 2),
      ),
      child: Text(
        title,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13 * scale, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildProblemCardBody(
    ExamEditorItem item,
    List<ContentBlock> contentBlocks,
    List<String> options,
    List<String> tags,
    double fontSize,
    double scale,
    bool highlighted,
    String pageLabel,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFF2F2F4) : const Color(0xFFFFFEFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlighted ? kCourseLightGreen : const Color(0xFFE3E3E7),
          width: highlighted ? 2 : 1,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 9 * scale,
                    vertical: 4 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: kCourseGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${item.displayIndex + 1}',
                    style: TextStyle(
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w700,
                      color: kCourseGreen,
                    ),
                  ),
                ),
                SizedBox(width: 8 * scale),
                Expanded(
                  child: Wrap(
                    spacing: 6 * scale,
                    runSpacing: 6 * scale,
                    children: [
                      _buildTagPill(
                        _difficultyLabel(item.item.difficultyTier),
                        scale,
                      ),
                      if (item.isGeometry) _buildTagPill('기하', scale),
                      if (options.isNotEmpty) _buildTagPill('객관식', scale),
                      for (final tag in tags) _buildTagPill('#$tag', scale),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 10 * scale),
            Row(
              children: [
                Text(
                  'seed ${_ensureSessionSeed(item)}',
                  style: TextStyle(fontSize: 10 * scale, color: Colors.black45),
                ),
                const Spacer(),
                Text(
                  pageLabel,
                  style: TextStyle(fontSize: 10 * scale, color: Colors.black45),
                ),
                SizedBox(width: 8 * scale),
                _fontButton(
                  Icons.remove_rounded,
                  () => _adjustItemFont(item, false),
                ),
                SizedBox(width: 4 * scale),
                _fontButton(
                  Icons.add_rounded,
                  () => _adjustItemFont(item, true),
                ),
              ],
            ),
            SizedBox(height: 12 * scale),
            ContentBlocksView(
              blocks: contentBlocks,
              textStyle: TextStyle(
                fontSize: fontSize,
                height: 1.7,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              latexStyle: TextStyle(
                fontSize: fontSize,
                height: 1.7,
                color: Colors.black87,
              ),
            ),
            if (options.isNotEmpty) ...[
              SizedBox(height: 12 * scale),
              for (final entry in options.asMap().entries)
                Padding(
                  padding: EdgeInsets.only(bottom: 8 * scale),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24 * scale,
                        height: 24 * scale,
                        alignment: Alignment.center,
                        margin: EdgeInsets.only(
                          right: 8 * scale,
                          top: 2 * scale,
                        ),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF4F4F5),
                          border: Border.all(color: const Color(0xFFE3E3E7)),
                        ),
                        child: Text(
                          String.fromCharCode(0x2460 + entry.key),
                          style: TextStyle(
                            fontSize: 11 * scale,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ContentBlocksView(
                          blocks: _blocksOf(entry.value),
                          textStyle: TextStyle(
                            fontSize: fontSize * 0.92,
                            height: 1.55,
                            color: Colors.black87,
                          ),
                          latexStyle: TextStyle(
                            fontSize: fontSize * 0.92,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ] else ...[
              SizedBox(height: 12 * scale),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _makeLocalMultipleChoice(item),
                  icon: const Icon(Icons.auto_fix_high_rounded),
                  label: const Text('객관식으로 변경'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fontButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE3E3E7)),
        ),
        child: Icon(icon, size: 14, color: Colors.black54),
      ),
    );
  }
}
