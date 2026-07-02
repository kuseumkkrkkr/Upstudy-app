import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/exam_editor_models.dart';
import '../models/exam_editor_layout.dart';
import '../services/api_client.dart';
import '../widgets/design_tokens.dart';
import '../widgets/content_blocks_view.dart';
import '../models/content_block.dart';

/// Detailed exam paper editor page.
///
/// Features:
/// - Left panel: problem search & "My Problem Set"
/// - Center: 2×2 grid preview with drag-and-drop
/// - Right panel: toolbar (font size, AI arrange, deploy, PDF)
class ExamPaperEditorPage extends StatefulWidget {
  final String? initialExamId;
  final List<ExamEditorItem>? initialItems;

  const ExamPaperEditorPage({
    super.key,
    this.initialExamId,
    this.initialItems,
  });

  @override
  State<ExamPaperEditorPage> createState() => _ExamPaperEditorPageState();
}

class _ExamPaperEditorPageState extends State<ExamPaperEditorPage> {
  late ExamEditorState _state;
  String? _paperId;
  String? _paperUpdatedAt;

  // Search panel state
  final _searchCtrl = TextEditingController();
  String _searchMode = 'text'; // 'text', 'hashtag', 'date'
  List<Map<String, dynamic>> _searchResults = [];
  bool _searching = false;
  String? _searchError;

  // Managed by ReorderableListView drag target

  // AI arrangement state
  bool _aiArranging = false;
  String? _aiStatus;

  // Deploy / PDF state
  bool _deploying = false;
  String? _deployExamId;
  Timer? _pollTimer;

  // Two-per-page mode
  bool _twoPerPage = false;

  @override
  void initState() {
    super.initState();
    final initialItems = widget.initialItems ?? [];
    _state = ExamEditorState(
      items: initialItems,
      pages: ExamEditorLayoutEngine.computeLayout(initialItems),
      examId: widget.initialExamId,
    );
    _paperId = null;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  // ────────────────────────── Search ──────────────────────────

  Future<void> _performSearch() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _searchError = null;
    });

    try {
      List<Map<String, dynamic>> results;
      switch (_searchMode) {
        case 'hashtag':
          final payload = await ApiClient.instance.searchExamEditorProblems(hashTag: query, pageSize: 200);
          results = ((payload['items'] as List<dynamic>? ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList());
          break;
        case 'date':
          final dateParts = query.split('~').map((e) => e.trim()).toList();
          final payload = await ApiClient.instance.searchExamEditorProblems(
            dateFrom: dateParts.isNotEmpty ? dateParts.first : query,
            dateTo: dateParts.length > 1 ? dateParts[1] : null,
            pageSize: 200,
          );
          results = ((payload['items'] as List<dynamic>? ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList());
          break;
        case 'text':
        default:
          final payload = await ApiClient.instance.searchExamEditorProblems(text: query, pageSize: 200);
          results = ((payload['items'] as List<dynamic>? ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList());
          break;
      }
      setState(() => _searchResults = results);
    } catch (e) {
      setState(() => _searchError = e.toString());
    } finally {
      setState(() => _searching = false);
    }
  }

  // ────────────────────────── Item management ──────────────────────────

  void _addItemFromSearch(Map<String, dynamic> quest) {
    if (!_state.canAddMore) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최대 100문제까지 추가 가능합니다.')),
      );
      return;
    }

    final item = ExamItem.fromJson({
      'item_index': _state.items.length,
      'status': 'done',
      'subject_key': 'custom',
      'hash_tags': (quest['hash_tags'] as List<dynamic>? ?? const []),
      'difficulty_tier': (quest['difficulty_tier'] as num?)?.toInt() ?? 3,
      'solves_count': (quest['solves_count'] as num?)?.toInt() ?? 5,
      'strategy_level': (quest['strategy_level'] as num?)?.toInt() ?? 3,
      'branch_conditions': (quest['branch_conditions'] as num?)?.toInt() ?? 2,
      'question_type': quest['question_type']?.toString(),
      'quest_id': quest['quest_id']?.toString(),
      'flow_count': (quest['flow_count'] as num?)?.toInt() ?? 3,
      'codebase_id': (quest['codebase_id'] as num?)?.toInt(),
      'seed': (quest['seed'] as num?)?.toInt(),
      'quest_title': quest['quest_title'],
      'quest_options': quest['quest_options'] as List<dynamic>?,
      'error': null,
    });
    final editorItem = ExamEditorItem.fromExamItem(item, _state.items.length);
    final newItems = ExamEditorLayoutEngine.insertAt(_state.items, _state.items.length, editorItem);
    final newPages = _twoPerPage
        ? ExamEditorLayoutEngine.computeTwoPerPageLayout(newItems)
        : ExamEditorLayoutEngine.computeLayout(newItems);

    setState(() {
      _state = _state.copyWith(items: newItems, pages: newPages);
    });
  }

  void _removeItem(int index) {
    final newItems = ExamEditorLayoutEngine.removeAt(_state.items, index);
    final newPages = _twoPerPage
        ? ExamEditorLayoutEngine.computeTwoPerPageLayout(newItems)
        : ExamEditorLayoutEngine.computeLayout(newItems);
    setState(() => _state = _state.copyWith(items: newItems, pages: newPages));
  }

  void _reorderItems(int oldIndex, int newIndex) {
    final newItems = ExamEditorLayoutEngine.reorder(_state.items, oldIndex, newIndex);
    final newPages = _twoPerPage
        ? ExamEditorLayoutEngine.computeTwoPerPageLayout(newItems)
        : ExamEditorLayoutEngine.computeLayout(newItems);
    setState(() => _state = _state.copyWith(items: newItems, pages: newPages));
  }

  // ────────────────────────── Font scale ──────────────────────────

  void _setFontScale(double scale) {
    setState(() => _state = _state.copyWith(fontScale: scale));
  }

  // ────────────────────────── AI Arrange ──────────────────────────

  Future<void> _aiArrange() async {
    if (_state.items.isEmpty) return;

    setState(() {
      _aiArranging = true;
      _aiStatus = 'AI가 문제를 배치하는 중...';
    });

    try {
      final response = await ApiClient.instance.arrangeExamEditorAi(
        paperId: _paperId,
        instruction: _buildArrangePrompt(),
        items: _state.items.asMap().entries.map((entry) {
          final idx = entry.key;
          final editorItem = entry.value;
          return {
            'order_no': idx,
            'page_no': (idx ~/ (_twoPerPage ? 2 : 4)) + 1,
            'layout_slot': 'auto',
            'codebase_id': editorItem.item.codebaseId,
            'seed': editorItem.item.seed,
            'quest_id': editorItem.item.questId,
            'question_type': editorItem.item.questionType,
            'is_geometry': editorItem.isGeometry,
          };
        }).toList(),
      );
      if (response['accepted'] != true) {
        setState(() => _aiStatus = '諛곗튂 嫄곕?: ${response['reason'] ?? 'rejected'}');
        return;
      }
      final arranged = (response['items'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final byQuestId = {
        for (final item in _state.items)
          if ((item.item.questId ?? '').isNotEmpty) item.item.questId!: item,
      };
      final sorted = <ExamEditorItem>[];
      for (final row in arranged) {
        final qid = row['quest_id']?.toString() ?? '';
        final found = byQuestId[qid];
        if (found != null) {
          sorted.add(found);
        }
      }
      if (sorted.length != _state.items.length) {
        sorted
          ..clear()
          ..addAll(List<ExamEditorItem>.from(_state.items)
            ..sort((a, b) => a.item.difficultyTier.compareTo(b.item.difficultyTier)));
      }
      for (var i = 0; i < sorted.length; i++) {
        sorted[i] = sorted[i].copyWith(displayIndex: i);
      }

      final newPages = _twoPerPage
          ? ExamEditorLayoutEngine.computeTwoPerPageLayout(sorted)
          : ExamEditorLayoutEngine.computeLayout(sorted);

      setState(() {
        _state = _state.copyWith(items: sorted, pages: newPages);
        _aiStatus = '배치 완료!';
      });
    } catch (e) {
      setState(() => _aiStatus = '배치 실패: $e');
    } finally {
      setState(() => _aiArranging = false);
    }
  }

  String _buildArrangePrompt() {
    final buffer = StringBuffer();
    buffer.writeln('시험지 문제 배치 요청:');
    buffer.writeln('총 ${_state.items.length}문제');
    buffer.writeln('2×2 그리드, 기하/그래프 문제는 행당 1개, 페이지당 2개 제한');
    buffer.writeln('문제 목록:');
    for (final item in _state.items) {
      buffer.writeln(
        '- [${item.isGeometry ? "기하" : "일반"}] ${item.item.difficultyTier}티어: ${item.titleText.substring(0, item.titleText.length.clamp(0, 50))}',
      );
    }
    return buffer.toString();
  }

  // ────────────────────────── Deploy / PDF ──────────────────────────

  Future<void> _deployExam() async {
    if (_state.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문제를 1개 이상 추가하세요.')),
      );
      return;
    }

    setState(() => _deploying = true);

    try {
      final saved = await ApiClient.instance.saveExamEditorPaper(
        paperId: _paperId,
        title: _state.title,
        twoPerPage: _twoPerPage,
        gradingAreaDirection: 'bottom',
        expectedUpdatedAt: _paperUpdatedAt,
        items: _state.items.asMap().entries.map((entry) {
          final idx = entry.key;
          final editorItem = entry.value;
          return {
            'order_no': idx,
            'page_no': (idx ~/ (_twoPerPage ? 2 : 4)) + 1,
            'layout_slot': 'auto',
            'codebase_id': editorItem.item.codebaseId,
            'seed': editorItem.item.seed,
            'quest_id': editorItem.item.questId,
            'question_type': editorItem.item.questionType,
            'is_geometry': editorItem.isGeometry,
          };
        }).toList(),
      );
      _paperId = saved['paper_id']?.toString();
      _paperUpdatedAt = saved['updated_at']?.toString();
      if (_paperId == null || _paperId!.isEmpty) {
        throw Exception('missing paper_id');
      }
      final deploy = await ApiClient.instance.deployExamEditorPaper(_paperId!);
      final examId = deploy['exam_id']?.toString() ?? '';
      if (examId.isEmpty) {
        throw Exception('missing exam_id');
      }

      setState(() {
        _deployExamId = examId;
        _state = _state.copyWith(examId: examId);
      });

      _startPolling();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('시험지 배포 시작: $examId')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('배포 오류: $e')),
        );
      }
    } finally {
      setState(() => _deploying = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_deployExamId == null) {
        timer.cancel();
        return;
      }
      try {
        final status = await ApiClient.instance.getExamStatus(_deployExamId!);
        if (status.status == 'completed' || status.status == 'failed') {
          timer.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('시험지 상태: ${status.status}')),
            );
          }
        }
      } catch (_) {
        timer.cancel();
      }
    });
  }

  Future<void> _downloadPdf() async {
    final examId = _state.examId ?? _deployExamId;
    if (examId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 시험지를 배포하세요.')),
      );
      return;
    }

    final urlStr = await ApiClient.instance.examPdfUrl(examId);
    final uri = Uri.parse(urlStr);

    if (Platform.isAndroid || Platform.isIOS) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF URL: $urlStr'),
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
    }
  }

  // ────────────────────────── Build ──────────────────────────

  @override
  Widget build(BuildContext context) {
    final scale = courseUiScale(context);
    return Scaffold(
      backgroundColor: kCourseBgGrey,
      appBar: AppBar(
        backgroundColor: kCourseGreen,
        foregroundColor: Colors.white,
        title: TextField(
          controller: TextEditingController(text: _state.title),
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: '시험지 제목',
            hintStyle: TextStyle(color: Colors.white54),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              setState(() => _state = _state.copyWith(title: value.trim()));
            }
          },
        ),
        actions: [
          // Two-per-page toggle
          Tooltip(
            message: '2문제/페이지 확장 모드',
            child: IconButton(
              icon: Icon(_twoPerPage ? Icons.view_agenda : Icons.grid_view),
              onPressed: () {
                setState(() {
                  _twoPerPage = !_twoPerPage;
                  final newPages = _twoPerPage
                      ? ExamEditorLayoutEngine.computeTwoPerPageLayout(_state.items)
                      : ExamEditorLayoutEngine.computeLayout(_state.items);
                  _state = _state.copyWith(pages: newPages);
                });
              },
            ),
          ),
          // AI Arrange
          Tooltip(
            message: 'AI 자동 배치',
            child: IconButton(
              icon: _aiArranging
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              onPressed: _aiArranging ? null : _aiArrange,
            ),
          ),
          // Deploy
          Tooltip(
            message: '시험지 배포',
            child: IconButton(
              icon: _deploying
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload),
              onPressed: _deploying ? null : _deployExam,
            ),
          ),
          // PDF
          Tooltip(
            message: 'PDF 다운로드',
            child: IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _downloadPdf,
            ),
          ),
          SizedBox(width: 8 * scale),
        ],
      ),
      body: Row(
        children: [
          // Left panel: search + problem set
          SizedBox(
            width: 320 * scale,
            child: _buildLeftPanel(scale),
          ),
          // Center: preview canvas
          Expanded(child: _buildPreviewCanvas(scale)),
          // Right panel: toolbar
          SizedBox(
            width: 240 * scale,
            child: _buildRightPanel(scale),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── Left Panel ──────────────────────────

  Widget _buildLeftPanel(double scale) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Search section
          Container(
            padding: EdgeInsets.all(16 * scale),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '문제 검색',
                  style: TextStyle(
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.bold,
                    color: kCourseGreen,
                  ),
                ),
                SizedBox(height: 8 * scale),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'text', label: Text('텍스트')),
                    ButtonSegment(value: 'hashtag', label: Text('해시태그')),
                    ButtonSegment(value: 'date', label: Text('날짜')),
                  ],
                  selected: {_searchMode},
                  onSelectionChanged: (set) => setState(() => _searchMode = set.first),
                ),
                SizedBox(height: 8 * scale),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: _searchMode == 'hashtag'
                        ? '예: common-math-1'
                        : _searchMode == 'date'
                            ? '예: 2024-01'
                            : '검색어 입력',
                    filled: true,
                    fillColor: kCourseBgGrey,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12 * scale),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _performSearch,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12 * scale,
                      vertical: 10 * scale,
                    ),
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),
              ],
            ),
          ),
          // Search results
          if (_searching)
            const Expanded(child: Center(child: CircularProgressIndicator())),
          if (_searchError != null)
            Expanded(
              child: Center(
                child: Text(
                  '오류: $_searchError',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          if (!_searching && _searchError == null)
            Expanded(
              child: _searchResults.isEmpty
                  ? Center(
                      child: Text(
                        '검색 결과가 없습니다.',
                        style: TextStyle(
                          fontSize: 14 * scale,
                          color: Colors.black54,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final quest = _searchResults[index];
                        final title = quest['quest_title']?.toString() ?? '문제 ${index + 1}';
                        final tags = (quest['hash_tags'] as List<dynamic>? ?? [])
                            .map((t) => t.toString())
                            .toList();
                        return ListTile(
                          dense: true,
                          title: Text(
                            title.substring(0, title.length.clamp(0, 60)),
                            style: TextStyle(fontSize: 13 * scale),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Wrap(
                            spacing: 4,
                            children: tags
                                .take(3)
                                .map((t) => Chip(
                                      label: Text(t, style: TextStyle(fontSize: 10 * scale)),
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ))
                                .toList(),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle, color: kCourseLightGreen),
                            onPressed: () => _addItemFromSearch(quest),
                          ),
                        );
                      },
                    ),
            ),
          // My Problem Set header
          Container(
            padding: EdgeInsets.all(12 * scale),
            decoration: BoxDecoration(
              color: kCourseGreen.withValues(alpha: 0.05),
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Icon(Icons.folder_open, size: 18 * scale, color: kCourseGreen),
                SizedBox(width: 8 * scale),
                Text(
                  'My Problem Set',
                  style: TextStyle(
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.bold,
                    color: kCourseGreen,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_state.items.length}/100',
                  style: TextStyle(
                    fontSize: 12 * scale,
                    color: _state.items.length >= 100 ? Colors.red : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          // My Problem Set list
          SizedBox(
            height: 200 * scale,
            child: _state.items.isEmpty
                ? Center(
                    child: Text(
                      '문제를 추가하세요',
                      style: TextStyle(
                        fontSize: 13 * scale,
                        color: Colors.black38,
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: _state.items.length,
                    onReorder: _reorderItems,
                    itemBuilder: (context, index) {
                      final editorItem = _state.items[index];
                      return _buildDraggableListTile(editorItem, index, scale);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableListTile(ExamEditorItem editorItem, int index, double scale) {
    final key = ValueKey(editorItem.editorId);
    final title = editorItem.titleText;
    final isGeometry = editorItem.isGeometry;
    final isMC = editorItem.isMultipleChoice;

    return ReorderableDragStartListener(
      index: index,
      key: key,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 2 * scale),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8 * scale),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ListTile(
          dense: true,
          leading: Container(
            width: 24 * scale,
            height: 24 * scale,
            decoration: BoxDecoration(
              color: isGeometry
                  ? Colors.orange.withValues(alpha: 0.1)
                  : kCourseLightGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4 * scale),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 11 * scale,
                  fontWeight: FontWeight.bold,
                  color: isGeometry ? Colors.orange : kCourseGreen,
                ),
              ),
            ),
          ),
          title: Text(
            title.substring(0, title.length.clamp(0, 50)),
            style: TextStyle(fontSize: 12 * scale),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isGeometry)
                _buildMiniBadge('기하', Colors.orange, scale),
              if (isMC)
                _buildMiniBadge('객관식', Colors.blue, scale),
              _buildMiniBadge('${editorItem.item.difficultyTier}티어', Colors.grey, scale),
            ],
          ),
          trailing: IconButton(
            icon: Icon(Icons.close, size: 16 * scale, color: Colors.red.shade300),
            onPressed: () => _removeItem(index),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String label, Color color, double scale) {
    return Container(
      margin: EdgeInsets.only(right: 4 * scale),
      padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 1 * scale),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4 * scale),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9 * scale, color: color),
      ),
    );
  }

  // ────────────────────────── Preview Canvas ──────────────────────────

  Widget _buildPreviewCanvas(double scale) {
    if (_state.pages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined, size: 64 * scale, color: Colors.grey.shade300),
            SizedBox(height: 16 * scale),
            Text(
              '문제를 추가하여 시험지를 구성하세요',
              style: TextStyle(fontSize: 16 * scale, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.grey.shade100,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24 * scale),
        child: Column(
          children: [
            for (var pageIndex = 0; pageIndex < _state.pages.length; pageIndex++) ...[
              _buildPagePreview(pageIndex, scale),
              if (pageIndex < _state.pages.length - 1)
                SizedBox(height: 24 * scale),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPagePreview(int pageIndex, double scale) {
    final page = _state.pages[pageIndex];
    const double paperWidth = 794;
    const double paperHeight = paperWidth * 297 / 210; // A4

    return Container(
      width: paperWidth * scale,
      height: paperHeight * scale,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4 * scale),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 40 * scale,
              padding: EdgeInsets.symmetric(horizontal: 16 * scale),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Text(
                    '제 ${pageIndex + 1} 교시',
                    style: TextStyle(
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _state.title,
                    style: TextStyle(
                      fontSize: 12 * scale,
                      color: Colors.black54,
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
          // Grid content
          Positioned.fill(
            top: 40 * scale,
            bottom: 24 * scale,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columnWidth = constraints.maxWidth / 2;
                final rowHeight = constraints.maxHeight / 2;

                return Stack(
                  children: [
                    // Items
                    ...page.entries.map((entry) {
                      final left = entry.column * columnWidth;
                      final top = entry.row * rowHeight;
                      final height = rowHeight * entry.rowSpan;
                      return Positioned(
                        left: left,
                        top: top,
                        width: columnWidth,
                        height: height,
                        child: _buildProblemCell(entry, scale),
                      );
                    }),
                    // Vertical divider
                    Positioned(
                      left: constraints.maxWidth / 2 - 0.5,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 1, color: Colors.black12),
                    ),
                    // Horizontal divider (if not all items span full height)
                    if (page.entries.any((e) => e.rowSpan == 1))
                      Positioned(
                        left: 0,
                        right: 0,
                        top: constraints.maxHeight / 2 - 0.5,
                        child: Container(height: 1, color: Colors.black12),
                      ),
                  ],
                );
              },
            ),
          ),
          // Footer
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 24 * scale,
              padding: EdgeInsets.symmetric(horizontal: 16 * scale),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Text(
                    'AIFlow',
                    style: TextStyle(fontSize: 9 * scale, color: Colors.black38),
                  ),
                  const Spacer(),
                  Text(
                    '${pageIndex + 1} / ${_state.pages.length}',
                    style: TextStyle(fontSize: 9 * scale, color: Colors.black38),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemCell(EditorLayoutEntry entry, double scale) {
    final editorItem = entry.editorItem;
    final item = editorItem.item;
    final blocks = parseContentBlocks(item.questTitle);
    final options = editorItem.options;
    final fontSize = 14.0 * _state.fontScale * scale;

    return Container(
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Problem number + badges
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 2 * scale),
                  decoration: BoxDecoration(
                    color: kCourseGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4 * scale),
                  ),
                  child: Text(
                    '${editorItem.displayIndex + 1}',
                    style: TextStyle(
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.bold,
                      color: kCourseGreen,
                    ),
                  ),
                ),
                if (editorItem.isGeometry) ...[
                  SizedBox(width: 4 * scale),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 1 * scale),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4 * scale),
                    ),
                    child: Text(
                      '기하',
                      style: TextStyle(fontSize: 9 * scale, color: Colors.orange),
                    ),
                  ),
                ],
                if (editorItem.isMultipleChoice) ...[
                  SizedBox(width: 4 * scale),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 1 * scale),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4 * scale),
                    ),
                    child: Text(
                      '객관식',
                      style: TextStyle(fontSize: 9 * scale, color: Colors.blue),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 6 * scale),
            // Problem content
            ContentBlocksView(
              blocks: blocks,
              textStyle: TextStyle(fontSize: fontSize, height: 1.4),
              latexStyle: TextStyle(fontSize: fontSize, height: 1.4),
              inline: true,
            ),
            // Options
            if (options.isNotEmpty) ...[
              SizedBox(height: 8 * scale),
              ...options.asMap().entries.map((optEntry) {
                final optIndex = optEntry.key;
                final optText = optEntry.value;
                final optBlocks = parseContentBlocks(optText);
                return Padding(
                  padding: EdgeInsets.only(bottom: 2 * scale),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 18 * scale,
                        height: 18 * scale,
                        margin: EdgeInsets.only(right: 6 * scale, top: 1 * scale),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(0x2460 + optIndex), // ①, ②, ③...
                            style: TextStyle(fontSize: 10 * scale, color: Colors.black54),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ContentBlocksView(
                          blocks: optBlocks,
                          textStyle: TextStyle(fontSize: fontSize * 0.9, height: 1.3),
                          inline: true,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  // ────────────────────────── Right Panel ──────────────────────────

  Widget _buildRightPanel(double scale) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(16 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '설정',
            style: TextStyle(
              fontSize: 16 * scale,
              fontWeight: FontWeight.bold,
              color: kCourseGreen,
            ),
          ),
          SizedBox(height: 16 * scale),
          // Font size
          Text(
            '글자 크기',
            style: TextStyle(fontSize: 13 * scale, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8 * scale),
          Slider(
            value: _state.fontScale,
            min: 0.7,
            max: 1.5,
            divisions: 16,
            label: '${(_state.fontScale * 100).round()}%',
            onChanged: _setFontScale,
            activeColor: kCourseLightGreen,
          ),
          Center(
            child: Text(
              '${(_state.fontScale * 100).round()}%',
              style: TextStyle(fontSize: 12 * scale, color: Colors.black54),
            ),
          ),
          SizedBox(height: 24 * scale),
          // Layout mode
          Text(
            '레이아웃',
            style: TextStyle(fontSize: 13 * scale, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8 * scale),
          SwitchListTile(
            title: Text('2문제/페이지 확장', style: TextStyle(fontSize: 12 * scale)),
            subtitle: Text('채점 영역 확보', style: TextStyle(fontSize: 10 * scale, color: Colors.black54)),
            value: _twoPerPage,
            onChanged: (v) {
              setState(() {
                _twoPerPage = v;
                final newPages = _twoPerPage
                    ? ExamEditorLayoutEngine.computeTwoPerPageLayout(_state.items)
                    : ExamEditorLayoutEngine.computeLayout(_state.items);
                _state = _state.copyWith(pages: newPages);
              });
            },
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          SizedBox(height: 16 * scale),
          // Stats
          Text(
            '통계',
            style: TextStyle(fontSize: 13 * scale, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8 * scale),
          _buildStatRow('총 문제', '${_state.items.length}', scale),
          _buildStatRow('페이지 수', '${_state.pages.length}', scale),
          _buildStatRow('기하 문제', '${_state.items.where((i) => i.isGeometry).length}', scale),
          _buildStatRow('객관식', '${_state.items.where((i) => i.isMultipleChoice).length}', scale),
          const Spacer(),
          // AI status
          if (_aiStatus != null) ...[
            Container(
              padding: EdgeInsets.all(8 * scale),
              decoration: BoxDecoration(
                color: kCourseLightGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8 * scale),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 14 * scale, color: kCourseLightGreen),
                  SizedBox(width: 6 * scale),
                  Expanded(
                    child: Text(
                      _aiStatus!,
                      style: TextStyle(fontSize: 11 * scale, color: kCourseGreen),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8 * scale),
          ],
          // Deploy status
          if (_deployExamId != null) ...[
            Container(
              padding: EdgeInsets.all(8 * scale),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8 * scale),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud, size: 14 * scale, color: Colors.blue),
                  SizedBox(width: 6 * scale),
                  Expanded(
                    child: Text(
                      '배포 ID: ${_deployExamId!.substring(0, _deployExamId!.length.clamp(0, 16))}...',
                      style: TextStyle(fontSize: 11 * scale, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8 * scale),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, double scale) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3 * scale),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12 * scale, color: Colors.black54)),
          Text(value, style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
