import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../widgets/design_tokens.dart';
import '../widgets/teacher_app_drawer.dart';

class ProblemEditorPage extends StatefulWidget {
  const ProblemEditorPage({super.key});

  @override
  State<ProblemEditorPage> createState() => _ProblemEditorPageState();
}

class _ProblemEditorPageState extends State<ProblemEditorPage> {
  final _promptCtrl = TextEditingController();
  final _baseQuestCtrl = TextEditingController();
  final _seedCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final _dbSearchCtrl = TextEditingController();

  final List<String> _tags = [];
  final List<_LogicNodeDraft> _logicNodes = [];
  final Map<String, double> _advancedMetrics = {
    for (final spec in _advancedParameterSpecs) spec.id: spec.defaultValue,
  };

  String _editorMode = 'simple';
  String _variantInputMode = 'prompt_note';
  String _simpleLevel = 'middle';
  String _dbSearchMode = 'text';
  int _solvesCount = 4;
  int _strategyLevel = 2;
  int _branchConditions = 1;
  int _nextNodeId = 1;

  bool _loading = false;
  bool _dbSearching = false;
  String? _resultText;
  String? _selectedNodeId;
  String? _dbError;
  List<String> _availableTags = [];
  List<Map<String, dynamic>> _tray = [];
  List<Map<String, dynamic>> _dbResults = [];
  Map<String, dynamic>? _selectedDbQuest;

  _GenerationProfile get _simpleProfile {
    return _simpleProfiles.firstWhere(
      (profile) => profile.id == _simpleLevel,
      orElse: () => _simpleProfiles[1],
    );
  }

  _LogicNodeDraft? get _selectedNode {
    for (final node in _logicNodes) {
      if (node.id == _selectedNodeId) return node;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadTagSuggestions();
    _loadTray();
    _resetAdvancedNodes();
  }

  Future<void> _loadTagSuggestions() async {
    try {
      final tags = await ApiClient.instance.getCourseHashTags();
      if (!mounted) return;
      setState(() => _availableTags = tags);
    } catch (_) {}
  }

  Future<void> _loadTray() async {
    try {
      final items = await ApiClient.instance.listQuestTray(limit: 50);
      if (!mounted) return;
      setState(() => _tray = items);
    } catch (_) {}
  }

  int? _seedOverride() {
    final text = _seedCtrl.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  Map<String, dynamic> _baseQuestRef() {
    final questId = _baseQuestCtrl.text.trim();
    return {
      if (questId.isNotEmpty) 'quest_id': questId,
      if (_selectedDbQuest?['codebase_id'] != null)
        'codebase_id': _selectedDbQuest!['codebase_id'],
      if (_selectedDbQuest?['seed'] != null) 'seed': _selectedDbQuest!['seed'],
    };
  }

  void _resetAdvancedNodes() {
    for (final node in _logicNodes) {
      node.dispose();
    }
    _logicNodes
      ..clear()
      ..addAll([
        _createNode(
          type: 'condition',
          title: '조건 정리',
          detail: '문제에 드러난 조건과 숨은 제약을 정리한다.',
          position: const Offset(40, 70),
        ),
        _createNode(
          type: 'insight',
          title: '핵심 발상',
          detail: '역추적, 치환, 대칭성 등 필요한 발상을 선택한다.',
          position: const Offset(300, 90),
        ),
        _createNode(
          type: 'reasoning',
          title: '그래프 추론',
          detail: '조건에서 결론으로 이어지는 방향성 풀이 그래프를 구성한다.',
          position: const Offset(560, 150),
        ),
        _createNode(
          type: 'verification',
          title: '정답 검증',
          detail: '정답 유일성, 조건 모순, 계산량을 검증한다.',
          position: const Offset(820, 210),
        ),
      ]);
    for (var i = 0; i < _logicNodes.length - 1; i++) {
      _logicNodes[i].nextIds.add(_logicNodes[i + 1].id);
    }
    _selectedNodeId = _logicNodes.first.id;
  }

  _LogicNodeDraft _createNode({
    required String type,
    required String title,
    required String detail,
    required Offset position,
  }) {
    final id = 'node_${_nextNodeId++}';
    return _LogicNodeDraft(
      id: id,
      type: type,
      position: position,
      titleCtrl: TextEditingController(text: title),
      detailCtrl: TextEditingController(text: detail),
      tagCtrl: TextEditingController(),
    );
  }

  void _addLogicNode(String type) {
    final index = _logicNodes.length;
    setState(() {
      final node = _createNode(
        type: type,
        title: _nodeTypeLabel(type),
        detail: _defaultNodeDetail(type),
        position: Offset(80 + (index % 4) * 220, 80 + (index ~/ 4) * 130),
      );
      if (_selectedNode != null) {
        _selectedNode!.nextIds.add(node.id);
      }
      _logicNodes.add(node);
      _selectedNodeId = node.id;
    });
  }

  void _removeSelectedNode() {
    final selected = _selectedNode;
    if (selected == null || _logicNodes.length <= 1) return;
    setState(() {
      _logicNodes.remove(selected);
      for (final node in _logicNodes) {
        node.nextIds.remove(selected.id);
      }
      selected.dispose();
      _selectedNodeId = _logicNodes.first.id;
    });
  }

  void _addTag() {
    final value = _tagCtrl.text.trim();
    if (value.isEmpty) return;
    if (!_tags.contains(value)) {
      setState(() => _tags.add(value));
    }
    _tagCtrl.clear();
  }

  void _selectDbQuest(Map<String, dynamic> quest) {
    final questId = quest['quest_id']?.toString() ?? '';
    if (questId.isEmpty) return;
    setState(() {
      _selectedDbQuest = quest;
      _baseQuestCtrl.text = questId;
      final rawTags = quest['hash_tags'];
      if (rawTags is List) {
        for (final tag in rawTags) {
          final value = tag.toString().trim();
          if (value.isNotEmpty && !_tags.contains(value)) {
            _tags.add(value);
          }
        }
      }
    });
  }

  Future<void> _searchProblemDb() async {
    final query = _dbSearchCtrl.text.trim();
    setState(() {
      _dbSearching = true;
      _dbError = null;
    });
    try {
      final result = await ApiClient.instance.searchExamEditorProblems(
        text: _dbSearchMode == 'text' ? query : null,
        hashTag: _dbSearchMode == 'hashtag' ? query : null,
        dateFrom: _dbSearchMode == 'date' ? query : null,
        pageSize: 80,
      );
      final items = (result['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      setState(() => _dbResults = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _dbError = e.toString());
    } finally {
      if (mounted) setState(() => _dbSearching = false);
    }
  }

  Future<void> _generateVariant() async {
    final advanced = _editorMode == 'advanced';
    final profile = advanced ? _buildAdvancedProfile() : _simpleProfile;
    final flowDraft = advanced
        ? _advancedFlowDraft()
        : _simpleFlowDraft(profile);
    final prompt = advanced
        ? _buildAdvancedPrompt(profile)
        : _buildSimplePrompt(profile);

    setState(() {
      _loading = true;
      _resultText = null;
    });

    try {
      final common = <String, dynamic>{
        'base_quest_ref': _baseQuestRef(),
        'prompt': prompt,
        'seed_override': _seedOverride(),
        'tags': _tags,
        'solves_count': profile.solvesCount,
        'strategy_level': profile.strategyLevel,
        'branch_conditions': profile.branchConditions,
      };

      final Map<String, dynamic> result;
      if (_variantInputMode == 'flow_draft') {
        result = await ApiClient.instance.generateVariantFromFlowDraft(
          payload: {
            ...common,
            'variant_input_mode': 'flow_draft',
            'flow_draft': flowDraft,
            'note_blocks': flowDraft,
          },
        );
      } else {
        result = await ApiClient.instance.generateVariantFromPromptNote(
          payload: {
            ...common,
            'variant_input_mode': 'prompt_note',
            'note_blocks': flowDraft,
          },
        );
      }

      if (!mounted) return;
      setState(() {
        _resultText = _formatGenerationResult(result, profile);
      });

      final quest = result['quest'] as Map<String, dynamic>?;
      final header = quest?['header'] as Map<String, dynamic>?;
      final questId = header?['quest_id']?.toString();
      if (questId != null && questId.isNotEmpty) {
        await ApiClient.instance.createQuestTrayItem(
          payload: {
            'quest_id': questId,
            'source_variant_mode': _variantInputMode,
            'visibility_scope': 'shared',
            'is_mcq_branch': false,
            'payload': {
              'mode': _editorMode,
              'tags': _tags,
              'base_quest': _selectedDbQuest,
              'workflow': advanced
                  ? _advancedWorkflowMeta(profile)
                  : profile.toMeta(),
            },
          },
        );
      }
      await _loadTray();
    } catch (e) {
      if (!mounted) return;
      setState(() => _resultText = '오류: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _convertToMcq() async {
    final questId = _baseQuestCtrl.text.trim();
    if (questId.isEmpty) {
      setState(() => _resultText = '기준 문항 ID가 필요합니다.');
      return;
    }
    setState(() {
      _loading = true;
      _resultText = null;
    });
    try {
      final result = await ApiClient.instance.convertQuestToMcq(
        questId: questId,
      );
      if (!mounted) return;
      setState(() => _resultText = result.toString());
      await _loadTray();
    } catch (e) {
      if (!mounted) return;
      setState(() => _resultText = '오류: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  _GenerationProfile _buildAdvancedProfile() {
    return _GenerationProfile(
      id: 'advanced_custom',
      label: '고급 커스텀',
      description: '교사가 직접 조정한 수능형 생성 파라미터',
      expectedNumber: _classifyExpectedNumber(),
      difficultyVector: {
        for (final id in _difficultyMetricIds) id: _metricInt(id),
      },
      expectedCorrectRate: {
        '상위권': _metricInt('top_rate'),
        '중위권': _metricInt('middle_rate'),
        '하위권': _metricInt('low_rate'),
      },
      solvesCount: _solvesCount,
      strategyLevel: _strategyLevel,
      branchConditions: _branchConditions,
      insights: _logicNodes
          .where((node) => node.type == 'insight')
          .map((node) => node.titleCtrl.text.trim())
          .where((text) => text.isNotEmpty)
          .toList(),
      intent: _advancedIntent(),
    );
  }

  int _metricInt(String id) => (_advancedMetrics[id] ?? 0).round();

  String _metricLabel(String id) {
    for (final spec in _advancedParameterSpecs) {
      if (spec.id == id) return spec.label;
    }
    return id;
  }

  void _applyAdvancedPreset(_AdvancedPreset preset) {
    setState(() {
      _solvesCount = preset.solvesCount;
      _strategyLevel = preset.strategyLevel;
      _branchConditions = preset.branchConditions;
      for (final spec in _advancedParameterSpecs) {
        _advancedMetrics[spec.id] = spec.defaultValue;
      }
      for (final entry in preset.metrics.entries) {
        _advancedMetrics[entry.key] = entry.value;
      }
    });
  }

  String _classifyExpectedNumber() {
    final reasoning = _metricInt('reasoning');
    final insight = _metricInt('insight');
    final graphDepth = _metricInt('graph_depth');
    final branchFactor = _metricInt('branch_factor');
    final concept = _metricInt('concept');
    if (reasoning >= 9 &&
        insight >= 10 &&
        graphDepth >= 8 &&
        branchFactor >= 2) {
      return '30번';
    }
    if (reasoning >= 9 && insight >= 9) return '29번';
    if (concept >= 7 && reasoning >= 8) return '22번';
    if (concept <= 4 && reasoning <= 3 && insight <= 2) return '3점';
    return '일반 4점';
  }

  String _advancedIntent() {
    final selected = _selectedDbQuest?['quest_id']?.toString();
    final source = selected == null || selected.isEmpty
        ? '신규 코드베이스 문항'
        : '기존 문제 $selected 기반 변형';
    return '$source에서 조건 해석, 발상, 방향성 풀이 그래프 추론, 검증을 교사가 지정한 구조로 평가한다.';
  }

  String _buildSimplePrompt(_GenerationProfile profile) {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isNotEmpty) return prompt;
    return '${profile.label} 난이도의 기존 문항 제작 파이프라인으로 문제를 생성한다.';
  }

  String _buildAdvancedPrompt(_GenerationProfile profile) {
    final userPrompt = _promptCtrl.text.trim();
    final buffer = StringBuffer()
      ..writeln(_ksatMathGenerationSystemPrompt)
      ..writeln()
      ..writeln('적용 모드: 고급 문항 제작')
      ..writeln('출력 호환성: 기존 코드베이스 문항 스키마와 저장 위치를 변경하지 않는다.')
      ..writeln(
        '기존 저장 종단점: /quests/variants/from-flow-draft 또는 /quests/variants/from-prompt-note',
      )
      ..writeln('수능 예상 번호: ${profile.expectedNumber}')
      ..writeln('난이도 벡터: ${_formatVector(profile.difficultyVector)}')
      ..writeln(
        '코드베이스 파라미터: 풀이 단계 수=$_solvesCount, '
        '전략 난이도=$_strategyLevel, 분기 수=$_branchConditions',
      )
      ..writeln('예상 정답률: ${_formatCorrectRate(profile.expectedCorrectRate)}')
      ..writeln('세부 평가 변수:')
      ..writeln(_formatAdvancedMetricPayload())
      ..writeln('교사 작성 방향성 풀이 그래프:')
      ..writeln(_formatNodeSummary());
    if (_selectedDbQuest != null) {
      buffer
        ..writeln('기반 문제:')
        ..writeln(_selectedDbQuest.toString());
    }
    if (userPrompt.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('교사 추가 지시:')
        ..writeln(userPrompt);
    }
    return buffer.toString().trim();
  }

  String _formatAdvancedMetricPayload() {
    return _advancedParameterSpecs
        .map((spec) => '- ${spec.label}: ${_metricInt(spec.id)}')
        .join('\n');
  }

  String _formatNodeSummary() {
    return _logicNodes
        .map(
          (node) =>
              '- ${node.id} [${_nodeTypeLabel(node.type)}] ${node.titleCtrl.text.trim()} '
              '다음=${node.nextIds.join(', ')}: ${node.detailCtrl.text.trim()}',
        )
        .join('\n');
  }

  List<Map<String, dynamic>> _simpleFlowDraft(_GenerationProfile profile) {
    return [
      {
        'node_id': 'simple_${profile.id}',
        'text':
            '${profile.label} 난이도: 풀이 단계 수=${profile.solvesCount}, '
            '전략 난이도=${profile.strategyLevel}, '
            '분기 수=${profile.branchConditions}',
        'hash_tags': _tags,
        'branches': <String>[],
      },
    ];
  }

  List<Map<String, dynamic>> _advancedFlowDraft() {
    return _logicNodes
        .map(
          (node) => {
            'node_id': node.id,
            'text':
                '${node.titleCtrl.text.trim()}\n${node.detailCtrl.text.trim()}',
            'hash_tags': node.tags.isEmpty ? _tags : node.tags.toList(),
            'branches': node.nextIds.toList(),
          },
        )
        .toList();
  }

  Map<String, dynamic> _advancedWorkflowMeta(_GenerationProfile profile) {
    return {
      ...profile.toMeta(),
      'mode': 'advanced',
      'metrics': {
        for (final spec in _advancedParameterSpecs)
          spec.id: _metricInt(spec.id),
      },
      'logic_nodes': _advancedFlowDraft(),
      'base_quest': _selectedDbQuest,
    };
  }

  String _formatVector(Map<String, int> vector) {
    return vector.entries
        .map((entry) => '${_metricLabel(entry.key)}: ${entry.value}')
        .join(', ');
  }

  String _formatCorrectRate(Map<String, int> rates) {
    return rates.entries
        .map((entry) => '${entry.key} ${entry.value}%')
        .join(', ');
  }

  String _contentToText(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is List) {
      return value
          .map(_contentToText)
          .where((text) => text.isNotEmpty)
          .join(' ');
    }
    if (value is Map) {
      final blocks = value['blocks'];
      if (blocks is List) {
        return blocks
            .map((block) {
              if (block is Map) return block['content']?.toString() ?? '';
              return block?.toString() ?? '';
            })
            .where((text) => text.trim().isNotEmpty)
            .join(' ');
      }
      final content = value['content'];
      if (content != null) return content.toString();
    }
    return value.toString();
  }

  String _formatSolution(dynamic solves) {
    if (solves is! List || solves.isEmpty) return '생성 응답에 풀이 단계가 없습니다.';
    final lines = <String>[];
    for (var i = 0; i < solves.length; i++) {
      final step = solves[i];
      if (step is! Map) continue;
      final answer = _contentToText(step['answer_riddle']).trim();
      final flow = _contentToText(step['flow']).trim();
      final text = answer.isNotEmpty ? answer : flow;
      if (text.isNotEmpty) lines.add('${i + 1}. $text');
    }
    return lines.isEmpty ? '생성 응답에 풀이 단계가 없습니다.' : lines.join('\n');
  }

  String _formatSolutionGraph(dynamic solves) {
    if (solves is! List || solves.isEmpty) return '조건 -> 정답';
    final nodes = <String>['조건'];
    for (final step in solves) {
      if (step is! Map) continue;
      final flow = _contentToText(step['flow']).trim();
      if (flow.isNotEmpty) nodes.add(flow);
      final branches = step['branches'];
      if (branches is List && branches.isNotEmpty) {
        nodes.add('분기 ${branches.length}개 병합');
      }
    }
    nodes.add('정답');
    return nodes.join(' -> ');
  }

  String _formatGenerationResult(
    Map<String, dynamic> result,
    _GenerationProfile profile,
  ) {
    final quest = result['quest'];
    if (quest is! Map) return result.toString();

    final data = quest['data'] is Map ? quest['data'] as Map : const {};
    final info = quest['info'] is Map ? quest['info'] as Map : const {};
    final solves = quest['solves'];
    final tags = info['hash_tag'] is List
        ? (info['hash_tag'] as List).map((item) => item.toString()).join(', ')
        : _tags.join(', ');

    return [
      '1. 문제',
      _contentToText(data['quest_title']),
      '',
      '2. 정답',
      _contentToText(data['quest_answer']),
      '',
      '3. 모범 풀이',
      _formatSolution(solves),
      '',
      '4. 풀이 그래프',
      _formatSolutionGraph(solves),
      '',
      '5. 사용 개념',
      tags,
      '',
      '6. 핵심 발상',
      profile.insights.isEmpty ? '-' : profile.insights.join(', '),
      '',
      '7. 난이도 벡터',
      _formatVector(profile.difficultyVector),
      '',
      '8. 예상 정답률',
      _formatCorrectRate(profile.expectedCorrectRate),
      '',
      '9. 수능 예상 번호',
      profile.expectedNumber,
      '',
      '10. 출제 의도',
      profile.intent,
      '',
      '원본 응답',
      result.toString(),
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final scale = courseUiScale(context);
    return Scaffold(
      endDrawer: const TeacherAppDrawer(currentRoute: '/problem-editor'),
      backgroundColor: kCourseBgGrey,
      appBar: AppBar(
        backgroundColor: kCourseGreen,
        foregroundColor: Colors.white,
        title: const Text('문항 제작 스튜디오'),
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        actions: [
          Builder(
            builder: (context) => IconButton(
              tooltip: '메뉴',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildWorkspaceHeader(scale),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 1180;
                final left = _buildLeftPanel(scale);
                final center = _editorMode == 'simple'
                    ? _buildSimplePipelinePanel(scale)
                    : _buildAdvancedCanvasPanel(scale);
                final right = _buildRightPanel(scale);

                if (compact) {
                  return ListView(
                    padding: EdgeInsets.all(14 * scale),
                    children: [
                      SizedBox(height: 640 * scale, child: left),
                      SizedBox(height: 12 * scale),
                      SizedBox(
                        height: _editorMode == 'simple' ? 420 : 620,
                        child: center,
                      ),
                      SizedBox(height: 12 * scale),
                      SizedBox(height: 760 * scale, child: right),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 360 * scale, child: left),
                    Expanded(child: center),
                    SizedBox(width: 390 * scale, child: right),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceHeader(double scale) {
    final profile = _editorMode == 'advanced'
        ? _buildAdvancedProfile()
        : _simpleProfile;
    final baseQuest = _baseQuestCtrl.text.trim();
    final sourceText = baseQuest.isEmpty ? '신규 문항' : '기준 문항 $baseQuest';

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(10 * scale, 10 * scale, 10 * scale, 0),
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE7DD)),
        boxShadow: const [kCourseShadow],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          final modeSwitch = SizedBox(
            width: compact ? constraints.maxWidth : 210 * scale,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'simple', label: Text('간편')),
                ButtonSegment(value: 'advanced', label: Text('고급')),
              ],
              selected: {_editorMode},
              onSelectionChanged: (values) =>
                  setState(() => _editorMode = values.first),
            ),
          );
          final steps = _buildWorkflowSteps();
          final summary = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryPill(
                icon: Icons.track_changes_rounded,
                label: _editorMode == 'simple' ? '간편 난이도' : '예상 번호',
                value: _editorMode == 'simple'
                    ? profile.label
                    : profile.expectedNumber,
              ),
              _SummaryPill(
                icon: Icons.account_tree_rounded,
                label: '풀이 단계',
                value: '${profile.solvesCount}',
              ),
              _SummaryPill(
                icon: Icons.psychology_alt_rounded,
                label: '전략',
                value: '${profile.strategyLevel}',
              ),
              _SummaryPill(
                icon: Icons.call_split_rounded,
                label: '분기',
                value: '${profile.branchConditions}',
              ),
              _SummaryPill(
                icon: Icons.library_books_rounded,
                label: '기반',
                value: sourceText,
              ),
            ],
          );
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _loading ? null : _generateVariant,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('문항 생성'),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : _convertToMcq,
                icon: const Icon(Icons.checklist_rtl_rounded),
                label: const Text('객관식 변환'),
              ),
              OutlinedButton.icon(
                onPressed: _loading ? null : _loadTray,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('보관함 새로고침'),
              ),
            ],
          );

          final content = compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    modeSwitch,
                    SizedBox(height: 10 * scale),
                    steps,
                    SizedBox(height: 10 * scale),
                    summary,
                    SizedBox(height: 10 * scale),
                    actions,
                  ],
                )
              : Row(
                  children: [
                    modeSwitch,
                    SizedBox(width: 12 * scale),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          steps,
                          SizedBox(height: 8 * scale),
                          summary,
                        ],
                      ),
                    ),
                    SizedBox(width: 12 * scale),
                    actions,
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              content,
              if (_loading) ...[
                SizedBox(height: 10 * scale),
                const LinearProgressIndicator(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildWorkflowSteps() {
    final advanced = _editorMode == 'advanced';
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _WorkflowStepChip(index: 1, label: '입력', active: true),
        _WorkflowStepChip(
          index: 2,
          label: '저장소',
          active: _selectedDbQuest != null,
        ),
        _WorkflowStepChip(
          index: 3,
          label: advanced ? '논리 설계' : '기존 흐름',
          active: advanced,
        ),
        _WorkflowStepChip(
          index: 4,
          label: advanced ? '세부값' : '상/중/하',
          active: true,
        ),
        _WorkflowStepChip(
          index: 5,
          label: '생성/보관',
          active: _resultText != null || _tray.isNotEmpty,
        ),
      ],
    );
  }

  Widget _buildLeftPanel(double scale) {
    return _StudioPanel(
      title: '생성 입력',
      child: ListView(
        padding: EdgeInsets.all(16 * scale),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _variantInputMode,
            decoration: const InputDecoration(
              labelText: '입력 방식',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'prompt_note', child: Text('지시문 + 노트')),
              DropdownMenuItem(value: 'flow_draft', child: Text('풀이 흐름 초안')),
            ],
            onChanged: (value) =>
                setState(() => _variantInputMode = value ?? 'prompt_note'),
          ),
          if (_editorMode == 'simple') ...[
            SizedBox(height: 14 * scale),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'low', label: Text('하')),
                ButtonSegment(value: 'middle', label: Text('중')),
                ButtonSegment(value: 'high', label: Text('상')),
              ],
              selected: {_simpleLevel},
              onSelectionChanged: (values) =>
                  setState(() => _simpleLevel = values.first),
            ),
            SizedBox(height: 8 * scale),
            _MutedText(_simpleProfile.description),
          ],
          SizedBox(height: 14 * scale),
          TextField(
            controller: _baseQuestCtrl,
            decoration: const InputDecoration(
              labelText: '기준 문항 ID',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: 10 * scale),
          TextField(
            controller: _seedCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '시드 고정값',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10 * scale),
          TextField(
            controller: _promptCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '교사 지시',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16 * scale),
          _buildTagEditor(scale),
          if (_resultText != null) ...[
            SizedBox(height: 16 * scale),
            const Text(
              '생성 결과',
              style: TextStyle(
                color: kCourseGreen,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8 * scale),
            SelectableText(
              _resultText!,
              style: const TextStyle(fontSize: 12.5, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTagEditor(double scale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '태그',
          style: TextStyle(fontWeight: FontWeight.w800, color: kCourseGreen),
        ),
        SizedBox(height: 8 * scale),
        Autocomplete<String>(
          optionsBuilder: (value) {
            if (value.text.trim().isEmpty) {
              return const Iterable<String>.empty();
            }
            final q = value.text.trim().toLowerCase();
            return _availableTags
                .where((tag) => tag.toLowerCase().contains(q))
                .take(12);
          },
          onSelected: (value) {
            _tagCtrl.text = value;
            _addTag();
          },
          fieldViewBuilder: (_, ctrl, focusNode, onFieldSubmitted) {
            return TextField(
              controller: ctrl,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: '해시태그 추가',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                _tagCtrl.text = ctrl.text;
                _addTag();
                ctrl.clear();
              },
            );
          },
        ),
        SizedBox(height: 8 * scale),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _tags
              .map(
                (tag) => Chip(
                  label: Text(tag),
                  onDeleted: () => setState(() => _tags.remove(tag)),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSimplePipelinePanel(double scale) {
    return _StudioPanel(
      title: '간편모드',
      child: Padding(
        padding: EdgeInsets.all(18 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '기존 파이프라인',
              style: TextStyle(
                color: kCourseGreen,
                fontSize: 22 * scale,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8 * scale),
            const _MutedText(
              '상/중/하 선택값만 기존 코드베이스 생성 파라미터로 매핑합니다. 고급 프롬프트나 상세 난이도 벡터는 주입하지 않습니다.',
            ),
            SizedBox(height: 18 * scale),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _simpleProfiles
                  .map(
                    (profile) => _SimpleLevelTile(
                      profile: profile,
                      selected: profile.id == _simpleLevel,
                      onTap: () => setState(() => _simpleLevel = profile.id),
                    ),
                  )
                  .toList(),
            ),
            const Spacer(),
            _PipelineSummary(profile: _simpleProfile),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedCanvasPanel(double scale) {
    return _StudioPanel(
      title: '풀이 논리 캔버스',
      child: Padding(
        padding: EdgeInsets.all(14 * scale),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in _nodeTypes)
                  OutlinedButton.icon(
                    onPressed: () => _addLogicNode(type),
                    icon: Icon(_nodeTypeIcon(type), size: 18),
                    label: Text(_nodeTypeLabel(type)),
                  ),
                OutlinedButton.icon(
                  onPressed: () => setState(_resetAdvancedNodes),
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('초기화'),
                ),
              ],
            ),
            SizedBox(height: 12 * scale),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FBF8),
                    border: Border.all(color: const Color(0xFFDDE7DD)),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _LogicEdgePainter(nodes: _logicNodes),
                            ),
                          ),
                          for (final node in _logicNodes)
                            Positioned(
                              left: node.position.dx.clamp(
                                8,
                                math.max(8, constraints.maxWidth - 190),
                              ),
                              top: node.position.dy.clamp(
                                8,
                                math.max(8, constraints.maxHeight - 108),
                              ),
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedNodeId = node.id),
                                onPanUpdate: (details) {
                                  setState(() {
                                    final next = node.position + details.delta;
                                    node.position = Offset(
                                      next.dx.clamp(
                                        8,
                                        math.max(8, constraints.maxWidth - 190),
                                      ),
                                      next.dy.clamp(
                                        8,
                                        math.max(
                                          8,
                                          constraints.maxHeight - 108,
                                        ),
                                      ),
                                    );
                                  });
                                },
                                child: _LogicNodeCard(
                                  node: node,
                                  selected: node.id == _selectedNodeId,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPanel(double scale) {
    return _StudioPanel(
      title: _editorMode == 'advanced' ? '고급 설정' : '문제 저장소',
      child: DefaultTabController(
        length: _editorMode == 'advanced' ? 5 : 2,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              labelColor: kCourseGreen,
              tabs: [
                if (_editorMode == 'advanced') const Tab(text: '파라미터'),
                if (_editorMode == 'advanced') const Tab(text: '노드'),
                if (_editorMode == 'advanced') const Tab(text: '설명서'),
                const Tab(text: '저장소'),
                const Tab(text: '보관함'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  if (_editorMode == 'advanced') _buildParameterPanel(scale),
                  if (_editorMode == 'advanced') _buildNodeEditor(scale),
                  if (_editorMode == 'advanced')
                    _buildDocumentationPanel(scale),
                  _buildProblemDbPanel(scale),
                  _buildTrayPanel(scale),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterPanel(double scale) {
    final profile = _buildAdvancedProfile();
    return ListView(
      padding: EdgeInsets.all(14 * scale),
      children: [
        const _DocBlock(
          title: '빠른 설계',
          body:
              '수능 예상 번호 프리셋으로 시작한 뒤 아래의 모든 변수를 직접 조정합니다. 프리셋은 시작값만 바꾸며 기존 저장 파이프라인은 변경하지 않습니다.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in _advancedPresets)
              ChoiceChip(
                label: Text(preset.label),
                selected: profile.expectedNumber == preset.expectedNumber,
                tooltip: preset.description,
                onSelected: (_) => _applyAdvancedPreset(preset),
              ),
          ],
        ),
        SizedBox(height: 12 * scale),
        _DocBlock(
          title: '현재 판정',
          body:
              '${profile.expectedNumber} · 풀이 단계 ${profile.solvesCount} · 전략 ${profile.strategyLevel} · 분기 ${profile.branchConditions}',
        ),
        SizedBox(height: 8 * scale),
        _IntControl(
          label: '풀이 단계 수',
          value: _solvesCount,
          min: 1,
          max: 10,
          description: '루트 풀이 단계 수입니다. 2는 짧은 기본형, 7 이상은 30번형 장문 추론에 가깝습니다.',
          onChanged: (value) => setState(() => _solvesCount = value),
        ),
        _IntControl(
          label: '전략 난이도',
          value: _strategyLevel,
          min: 1,
          max: 3,
          description: '핵심 전략 난이도입니다. 1은 공식 적용, 3은 발상 전환과 복원 중심입니다.',
          onChanged: (value) => setState(() => _strategyLevel = value),
        ),
        _IntControl(
          label: '분기 수',
          value: _branchConditions,
          min: 0,
          max: 5,
          description: '풀이 분기 수입니다. 0은 일직선 풀이, 2 이상은 케이스 분류/병합 풀이입니다.',
          onChanged: (value) => setState(() => _branchConditions = value),
        ),
        const Divider(height: 28),
        for (final group in _parameterGroups)
          ExpansionTile(
            initiallyExpanded: group.id == 'difficulty',
            title: Text(group.label),
            children: group.specs
                .map(
                  (spec) => _MetricSlider(
                    spec: spec,
                    value: _advancedMetrics[spec.id] ?? spec.defaultValue,
                    onChanged: (value) =>
                        setState(() => _advancedMetrics[spec.id] = value),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildNodeEditor(double scale) {
    final node = _selectedNode;
    if (node == null) {
      return const Center(child: Text('선택된 노드가 없습니다.'));
    }

    final connectable = _logicNodes
        .where((item) => item.id != node.id)
        .toList();

    return ListView(
      padding: EdgeInsets.all(14 * scale),
      children: [
        DropdownButtonFormField<String>(
          initialValue: node.type,
          decoration: const InputDecoration(
            labelText: '노드 유형',
            border: OutlineInputBorder(),
          ),
          items: _nodeTypes
              .map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Text(_nodeTypeLabel(type)),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => node.type = value ?? node.type),
        ),
        SizedBox(height: 10 * scale),
        TextField(
          controller: node.titleCtrl,
          decoration: const InputDecoration(
            labelText: '노드 제목',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: 10 * scale),
        TextField(
          controller: node.detailCtrl,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: '풀이 논리',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: 10 * scale),
        TextField(
          controller: node.tagCtrl,
          decoration: const InputDecoration(
            labelText: '노드 태그 추가',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            final tag = node.tagCtrl.text.trim();
            if (tag.isEmpty) return;
            setState(() => node.tags.add(tag));
            node.tagCtrl.clear();
          },
        ),
        SizedBox(height: 8 * scale),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: node.tags
              .map(
                (tag) => Chip(
                  label: Text(tag),
                  onDeleted: () => setState(() => node.tags.remove(tag)),
                ),
              )
              .toList(),
        ),
        const Divider(height: 28),
        const Text(
          '연결',
          style: TextStyle(fontWeight: FontWeight.w800, color: kCourseGreen),
        ),
        SizedBox(height: 8 * scale),
        for (final target in connectable)
          CheckboxListTile(
            dense: true,
            value: node.nextIds.contains(target.id),
            title: Text(
              target.titleCtrl.text.trim().isEmpty
                  ? target.id
                  : target.titleCtrl.text.trim(),
            ),
            subtitle: Text(_nodeTypeLabel(target.type)),
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  node.nextIds.add(target.id);
                } else {
                  node.nextIds.remove(target.id);
                }
              });
            },
          ),
        const Divider(height: 28),
        OutlinedButton.icon(
          onPressed: _removeSelectedNode,
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('선택 노드 삭제'),
        ),
      ],
    );
  }

  Widget _buildDocumentationPanel(double scale) {
    return ListView(
      padding: EdgeInsets.all(14 * scale),
      children: [
        const _DocBlock(
          title: '코드베이스 파라미터 비교',
          body:
              '풀이 단계 수는 풀이의 길이, 전략 난이도는 핵심 발상의 강도, 분기 수는 케이스 분류와 병합 규모입니다. '
              '예를 들어 하 난이도는 2/1/0, 상 난이도는 6/3/2로 기존 생성 파이프라인에 전달됩니다.',
        ),
        for (final spec in _advancedParameterSpecs)
          _ParameterDocTile(spec: spec),
      ],
    );
  }

  Widget _buildProblemDbPanel(double scale) {
    return ListView(
      padding: EdgeInsets.all(14 * scale),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'text', label: Text('텍스트')),
            ButtonSegment(value: 'hashtag', label: Text('해시태그')),
            ButtonSegment(value: 'date', label: Text('날짜')),
          ],
          selected: {_dbSearchMode},
          onSelectionChanged: (values) =>
              setState(() => _dbSearchMode = values.first),
        ),
        SizedBox(height: 10 * scale),
        TextField(
          controller: _dbSearchCtrl,
          decoration: InputDecoration(
            labelText: _dbSearchMode == 'hashtag'
                ? '예: #미분'
                : _dbSearchMode == 'date'
                ? '예: 2026-07-04'
                : '문제 본문 검색',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: _dbSearching ? null : _searchProblemDb,
            ),
          ),
          onSubmitted: (_) => _searchProblemDb(),
        ),
        if (_selectedDbQuest != null) ...[
          SizedBox(height: 10 * scale),
          _SelectedQuestBox(
            quest: _selectedDbQuest!,
            onClear: () {
              setState(() {
                _selectedDbQuest = null;
                _baseQuestCtrl.clear();
              });
            },
          ),
        ],
        SizedBox(height: 12 * scale),
        if (_dbSearching)
          const LinearProgressIndicator()
        else if (_dbError != null)
          Text(_dbError!, style: const TextStyle(color: Colors.red))
        else if (_dbResults.isEmpty)
          const _MutedText('검색 결과가 없습니다.')
        else
          for (final item in _dbResults)
            _DbQuestRow(
              item: item,
              selected: item['quest_id'] == _selectedDbQuest?['quest_id'],
              onTap: () => _selectDbQuest(item),
              contentToText: _contentToText,
            ),
      ],
    );
  }

  Widget _buildTrayPanel(double scale) {
    return ListView(
      padding: EdgeInsets.all(14 * scale),
      children: [
        OutlinedButton.icon(
          onPressed: _loadTray,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('새로고침'),
        ),
        SizedBox(height: 12 * scale),
        if (_tray.isEmpty)
          const _MutedText('보관함이 비어 있습니다.')
        else
          for (final item in _tray) _TrayItemCard(item: item),
      ],
    );
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _baseQuestCtrl.dispose();
    _seedCtrl.dispose();
    _tagCtrl.dispose();
    _dbSearchCtrl.dispose();
    for (final node in _logicNodes) {
      node.dispose();
    }
    super.dispose();
  }
}

class _GenerationProfile {
  const _GenerationProfile({
    required this.id,
    required this.label,
    required this.description,
    required this.expectedNumber,
    required this.difficultyVector,
    required this.expectedCorrectRate,
    required this.solvesCount,
    required this.strategyLevel,
    required this.branchConditions,
    required this.insights,
    required this.intent,
  });

  final String id;
  final String label;
  final String description;
  final String expectedNumber;
  final Map<String, int> difficultyVector;
  final Map<String, int> expectedCorrectRate;
  final int solvesCount;
  final int strategyLevel;
  final int branchConditions;
  final List<String> insights;
  final String intent;

  Map<String, dynamic> toMeta() {
    return {
      'id': id,
      'label': label,
      'expected_number': expectedNumber,
      'difficulty_vector': difficultyVector,
      'expected_correct_rate': expectedCorrectRate,
      'generation_params': {
        'solves_count': solvesCount,
        'strategy_level': strategyLevel,
        'branch_conditions': branchConditions,
      },
      'insights': insights,
      'intent': intent,
    };
  }
}

class _LogicNodeDraft {
  _LogicNodeDraft({
    required this.id,
    required this.type,
    required this.position,
    required this.titleCtrl,
    required this.detailCtrl,
    required this.tagCtrl,
  });

  final String id;
  String type;
  Offset position;
  final TextEditingController titleCtrl;
  final TextEditingController detailCtrl;
  final TextEditingController tagCtrl;
  final Set<String> tags = {};
  final Set<String> nextIds = {};

  Offset get center => position + const Offset(90, 48);

  void dispose() {
    titleCtrl.dispose();
    detailCtrl.dispose();
    tagCtrl.dispose();
  }
}

class _ParameterSpec {
  const _ParameterSpec({
    required this.id,
    required this.label,
    required this.group,
    required this.defaultValue,
    required this.min,
    required this.max,
    required this.description,
    required this.lowExample,
    required this.highExample,
  });

  final String id;
  final String label;
  final String group;
  final double defaultValue;
  final double min;
  final double max;
  final String description;
  final String lowExample;
  final String highExample;
}

class _ParameterGroup {
  const _ParameterGroup({
    required this.id,
    required this.label,
    required this.specs,
  });

  final String id;
  final String label;
  final List<_ParameterSpec> specs;
}

class _AdvancedPreset {
  const _AdvancedPreset({
    required this.label,
    required this.expectedNumber,
    required this.description,
    required this.solvesCount,
    required this.strategyLevel,
    required this.branchConditions,
    required this.metrics,
  });

  final String label;
  final String expectedNumber;
  final String description;
  final int solvesCount;
  final int strategyLevel;
  final int branchConditions;
  final Map<String, double> metrics;
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE7DD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: kCourseGreen),
          const SizedBox(width: 6),
          Text(
            '$label ',
            style: const TextStyle(color: Color(0xFF64746A), fontSize: 12),
          ),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kCourseGreen,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowStepChip extends StatelessWidget {
  const _WorkflowStepChip({
    required this.index,
    required this.label,
    required this.active,
  });

  final int index;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? kCourseGreen : const Color(0xFF90AA91);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEAF5ED) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? kCourseGreen : const Color(0xFFDDE7DD),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: color,
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioPanel extends StatelessWidget {
  const _StudioPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE7DD)),
        boxShadow: const [kCourseShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              title,
              style: const TextStyle(
                color: kCourseGreen,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF64746A),
        fontSize: 12.5,
        height: 1.45,
      ),
    );
  }
}

class _SimpleLevelTile extends StatelessWidget {
  const _SimpleLevelTile({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final _GenerationProfile profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 190,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF5ED) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? kCourseGreen : const Color(0xFFDDE7DD),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.label,
              style: const TextStyle(
                color: kCourseGreen,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              profile.description,
              style: const TextStyle(color: Color(0xFF64746A), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PipelineSummary extends StatelessWidget {
  const _PipelineSummary({required this.profile});

  final _GenerationProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE7DD)),
      ),
      child: Text(
        '전달값: 풀이 단계 수=${profile.solvesCount}, '
        '전략 난이도=${profile.strategyLevel}, '
        '분기 수=${profile.branchConditions}',
        style: const TextStyle(
          color: kCourseGreen,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LogicNodeCard extends StatelessWidget {
  const _LogicNodeCard({required this.node, required this.selected});

  final _LogicNodeDraft node;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = _nodeTypeColor(node.type);
    final title = node.titleCtrl.text.trim().isEmpty
        ? node.id
        : node.titleCtrl.text.trim();
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? color : const Color(0xFFDDE7DD),
          width: selected ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180B2617),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(_nodeTypeIcon(node.type), color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _nodeTypeLabel(node.type),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kCourseGreen,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            node.detailCtrl.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF64746A),
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogicEdgePainter extends CustomPainter {
  const _LogicEdgePainter({required this.nodes});

  final List<_LogicNodeDraft> nodes;

  @override
  void paint(Canvas canvas, Size size) {
    final byId = {for (final node in nodes) node.id: node};
    final paint = Paint()
      ..color = const Color(0xFF90AA91)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final arrowPaint = Paint()
      ..color = const Color(0xFF90AA91)
      ..style = PaintingStyle.fill;

    for (final node in nodes) {
      for (final nextId in node.nextIds) {
        final target = byId[nextId];
        if (target == null) continue;
        final start = node.center;
        final end = target.center;
        final control = Offset(
          (start.dx + end.dx) / 2,
          math.min(start.dy, end.dy) - 42,
        );
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
        canvas.drawPath(path, paint);

        final angle = math.atan2(end.dy - control.dy, end.dx - control.dx);
        final p1 =
            end -
            Offset(math.cos(angle - 0.45) * 10, math.sin(angle - 0.45) * 10);
        final p2 =
            end -
            Offset(math.cos(angle + 0.45) * 10, math.sin(angle + 0.45) * 10);
        final arrow = Path()
          ..moveTo(end.dx, end.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..close();
        canvas.drawPath(arrow, arrowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LogicEdgePainter oldDelegate) => true;
}

class _IntControl extends StatelessWidget {
  const _IntControl({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.description,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final String description;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$label $value',
                  style: const TextStyle(
                    color: kCourseGreen,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: value <= min ? null : () => onChanged(value - 1),
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              IconButton(
                onPressed: value >= max ? null : () => onChanged(value + 1),
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$value',
            onChanged: (next) => onChanged(next.round()),
          ),
          _MutedText(description),
        ],
      ),
    );
  }
}

class _MetricSlider extends StatelessWidget {
  const _MetricSlider({
    required this.spec,
    required this.value,
    required this.onChanged,
  });

  final _ParameterSpec spec;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final rounded = value.round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${spec.label} ($rounded)',
                  style: const TextStyle(
                    color: kCourseGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${spec.min.round()}-${spec.max.round()}',
                style: const TextStyle(color: Color(0xFF64746A), fontSize: 11),
              ),
            ],
          ),
          Slider(
            value: value,
            min: spec.min,
            max: spec.max,
            divisions: (spec.max - spec.min).round(),
            label: '$rounded',
            onChanged: onChanged,
          ),
          _MutedText(spec.description),
        ],
      ),
    );
  }
}

class _DocBlock extends StatelessWidget {
  const _DocBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE7DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kCourseGreen,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          _MutedText(body),
        ],
      ),
    );
  }
}

class _ParameterDocTile extends StatelessWidget {
  const _ParameterDocTile({required this.spec});

  final _ParameterSpec spec;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        spec.label,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(spec.description),
      children: [
        _DocBlock(title: '설명', body: spec.description),
        _DocBlock(title: '낮은 값 예시', body: spec.lowExample),
        _DocBlock(title: '높은 값 예시', body: spec.highExample),
      ],
    );
  }
}

class _SelectedQuestBox extends StatelessWidget {
  const _SelectedQuestBox({required this.quest, required this.onClear});

  final Map<String, dynamic> quest;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kCourseGreen),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '선택: ${quest['quest_id'] ?? ''}',
              style: const TextStyle(
                color: kCourseGreen,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(onPressed: onClear, icon: const Icon(Icons.close_rounded)),
        ],
      ),
    );
  }
}

class _TrayItemCard extends StatelessWidget {
  const _TrayItemCard({required this.item});

  final Map<String, dynamic> item;

  String _modeLabel(String? value) {
    switch (value) {
      case 'flow_draft':
        return '풀이 흐름 초안';
      case 'prompt_note':
        return '지시문 + 노트';
      default:
        return value == null || value.isEmpty ? '생성 방식 없음' : value;
    }
  }

  String _scopeLabel(String? value) {
    switch (value) {
      case 'shared':
        return '공유';
      case 'private':
        return '비공개';
      default:
        return value == null || value.isEmpty ? '범위 없음' : value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final questId = item['quest_id']?.toString() ?? '문항 ID 없음';
    final mode = _modeLabel(item['source_variant_mode']?.toString());
    final scope = _scopeLabel(item['visibility_scope']?.toString());
    final createdAt = item['created_at']?.toString() ?? '';
    final payload = item['payload'];
    final workflowMode = payload is Map ? payload['mode']?.toString() : null;
    final modeText = workflowMode == 'advanced'
        ? '고급 워크플로우'
        : workflowMode == 'simple'
        ? '간편모드'
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE7DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            questId,
            style: const TextStyle(
              color: kCourseGreen,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Chip(label: Text(mode), visualDensity: VisualDensity.compact),
              Chip(label: Text(scope), visualDensity: VisualDensity.compact),
              if (modeText != null)
                Chip(
                  label: Text(modeText),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (createdAt.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              createdAt,
              style: const TextStyle(color: Color(0xFF64746A), fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _DbQuestRow extends StatelessWidget {
  const _DbQuestRow({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.contentToText,
  });

  final Map<String, dynamic> item;
  final bool selected;
  final VoidCallback onTap;
  final String Function(dynamic value) contentToText;

  @override
  Widget build(BuildContext context) {
    final title = contentToText(item['quest_title']);
    final tags = item['hash_tags'] is List
        ? (item['hash_tags'] as List).map((tag) => tag.toString()).join(', ')
        : '';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF5ED) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? kCourseGreen : const Color(0xFFDDE7DD),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['quest_id']?.toString() ?? '',
              style: const TextStyle(
                color: kCourseGreen,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (title.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, height: 1.35),
              ),
            ],
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                tags,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64746A),
                  fontSize: 11.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _advancedPresets = <_AdvancedPreset>[
  _AdvancedPreset(
    label: '3점형',
    expectedNumber: '3점',
    description: '개념 확인과 짧은 계산 중심의 기본 문항 시작값입니다.',
    solvesCount: 2,
    strategyLevel: 1,
    branchConditions: 0,
    metrics: {
      'concept': 3,
      'reasoning': 2,
      'insight': 2,
      'calculation': 3,
      'information': 2,
      'trap': 1,
      'compression': 2,
      'concept_count': 1,
      'concept_depth': 3,
      'prerequisite_depth': 2,
      'graph_depth': 2,
      'graph_width': 1,
      'branch_factor': 0,
      'merge_factor': 0,
      'insight_count': 1,
      'insight_depth': 2,
      'insight_uniqueness': 2,
      'condition_count': 2,
      'condition_density': 2,
      'hidden_information': 1,
      'implicit_constraints': 1,
      'symbolic_operations': 2,
      'algebra_steps': 2,
      'derivative_steps': 0,
      'integral_steps': 0,
      'simplification_cost': 2,
      'trap_count': 0,
      'trap_severity': 1,
      'compression_score': 2,
      'implicit_information': 1,
      'top_rate': 96,
      'middle_rate': 78,
      'low_rate': 42,
    },
  ),
  _AdvancedPreset(
    label: '4점형',
    expectedNumber: '일반 4점',
    description: '표준 개념 결합과 한 번의 발상 전환을 요구하는 시작값입니다.',
    solvesCount: 4,
    strategyLevel: 2,
    branchConditions: 1,
    metrics: {
      'concept': 6,
      'reasoning': 6,
      'insight': 5,
      'calculation': 4,
      'information': 5,
      'trap': 3,
      'compression': 4,
      'concept_count': 3,
      'concept_depth': 5,
      'prerequisite_depth': 4,
      'graph_depth': 5,
      'graph_width': 3,
      'branch_factor': 1,
      'merge_factor': 1,
      'insight_count': 2,
      'insight_depth': 5,
      'insight_uniqueness': 4,
      'condition_count': 4,
      'condition_density': 5,
      'hidden_information': 4,
      'implicit_constraints': 4,
      'symbolic_operations': 4,
      'algebra_steps': 4,
      'derivative_steps': 2,
      'integral_steps': 1,
      'simplification_cost': 4,
      'trap_count': 2,
      'trap_severity': 3,
      'compression_score': 4,
      'implicit_information': 4,
      'top_rate': 82,
      'middle_rate': 46,
      'low_rate': 18,
    },
  ),
  _AdvancedPreset(
    label: '22번형',
    expectedNumber: '22번',
    description: '개념 깊이와 조건 해석이 높은 준킬러형 시작값입니다.',
    solvesCount: 5,
    strategyLevel: 3,
    branchConditions: 1,
    metrics: {
      'concept': 8,
      'reasoning': 8,
      'insight': 7,
      'calculation': 5,
      'information': 7,
      'trap': 5,
      'compression': 6,
      'concept_count': 4,
      'concept_depth': 8,
      'prerequisite_depth': 7,
      'graph_depth': 7,
      'graph_width': 4,
      'branch_factor': 1,
      'merge_factor': 2,
      'insight_count': 2,
      'insight_depth': 7,
      'insight_uniqueness': 6,
      'condition_count': 5,
      'condition_density': 7,
      'hidden_information': 6,
      'implicit_constraints': 6,
      'symbolic_operations': 5,
      'algebra_steps': 5,
      'derivative_steps': 3,
      'integral_steps': 2,
      'simplification_cost': 5,
      'trap_count': 3,
      'trap_severity': 5,
      'compression_score': 6,
      'implicit_information': 6,
      'top_rate': 68,
      'middle_rate': 28,
      'low_rate': 8,
    },
  ),
  _AdvancedPreset(
    label: '29번형',
    expectedNumber: '29번',
    description: '긴 추론과 강한 발상 전환을 요구하는 고난도 시작값입니다.',
    solvesCount: 6,
    strategyLevel: 3,
    branchConditions: 2,
    metrics: {
      'concept': 8,
      'reasoning': 9,
      'insight': 9,
      'calculation': 5,
      'information': 7,
      'trap': 6,
      'compression': 7,
      'concept_count': 4,
      'concept_depth': 8,
      'prerequisite_depth': 7,
      'graph_depth': 8,
      'graph_width': 4,
      'branch_factor': 2,
      'merge_factor': 2,
      'insight_count': 3,
      'insight_depth': 9,
      'insight_uniqueness': 8,
      'condition_count': 6,
      'condition_density': 7,
      'hidden_information': 7,
      'implicit_constraints': 7,
      'symbolic_operations': 5,
      'algebra_steps': 5,
      'derivative_steps': 3,
      'integral_steps': 2,
      'simplification_cost': 5,
      'trap_count': 4,
      'trap_severity': 6,
      'compression_score': 7,
      'implicit_information': 7,
      'top_rate': 44,
      'middle_rate': 12,
      'low_rate': 3,
    },
  ),
  _AdvancedPreset(
    label: '30번형',
    expectedNumber: '30번',
    description: '깊은 그래프 구조, 복수 분기, 희소 발상을 요구하는 최고난도 시작값입니다.',
    solvesCount: 8,
    strategyLevel: 3,
    branchConditions: 3,
    metrics: {
      'concept': 9,
      'reasoning': 10,
      'insight': 10,
      'calculation': 5,
      'information': 8,
      'trap': 7,
      'compression': 8,
      'concept_count': 5,
      'concept_depth': 9,
      'prerequisite_depth': 8,
      'graph_depth': 9,
      'graph_width': 5,
      'branch_factor': 3,
      'merge_factor': 3,
      'insight_count': 4,
      'insight_depth': 10,
      'insight_uniqueness': 10,
      'condition_count': 7,
      'condition_density': 8,
      'hidden_information': 8,
      'implicit_constraints': 8,
      'symbolic_operations': 5,
      'algebra_steps': 5,
      'derivative_steps': 3,
      'integral_steps': 2,
      'simplification_cost': 5,
      'trap_count': 5,
      'trap_severity': 7,
      'compression_score': 8,
      'implicit_information': 8,
      'top_rate': 28,
      'middle_rate': 6,
      'low_rate': 1,
    },
  ),
];

const _simpleProfiles = <_GenerationProfile>[
  _GenerationProfile(
    id: 'low',
    label: '하',
    description: '기본 개념 확인형',
    expectedNumber: '3점',
    difficultyVector: {
      'concept': 3,
      'reasoning': 2,
      'insight': 2,
      'calculation': 3,
      'information': 2,
      'trap': 1,
      'compression': 2,
    },
    expectedCorrectRate: {'상위권': 96, '중위권': 78, '하위권': 42},
    solvesCount: 2,
    strategyLevel: 1,
    branchConditions: 0,
    insights: ['치환'],
    intent: '기본 개념 적용을 확인한다.',
  ),
  _GenerationProfile(
    id: 'middle',
    label: '중',
    description: '일반 4점형',
    expectedNumber: '일반 4점',
    difficultyVector: {
      'concept': 6,
      'reasoning': 6,
      'insight': 5,
      'calculation': 4,
      'information': 5,
      'trap': 3,
      'compression': 4,
    },
    expectedCorrectRate: {'상위권': 82, '중위권': 46, '하위권': 18},
    solvesCount: 4,
    strategyLevel: 2,
    branchConditions: 1,
    insights: ['숨은 조건', '경우 분류'],
    intent: '조건 해석과 표준 풀이 연결 능력을 평가한다.',
  ),
  _GenerationProfile(
    id: 'high',
    label: '상',
    description: '고난도 추론형',
    expectedNumber: '29번',
    difficultyVector: {
      'concept': 8,
      'reasoning': 9,
      'insight': 9,
      'calculation': 5,
      'information': 7,
      'trap': 6,
      'compression': 7,
    },
    expectedCorrectRate: {'상위권': 44, '중위권': 12, '하위권': 3},
    solvesCount: 6,
    strategyLevel: 3,
    branchConditions: 2,
    insights: ['역추론', '불변량', '경우 분류'],
    intent: '분기 추론과 발상 전환을 평가한다.',
  ),
];

const _difficultyMetricIds = <String>[
  'concept',
  'reasoning',
  'insight',
  'calculation',
  'information',
  'trap',
  'compression',
];

const _advancedParameterSpecs = <_ParameterSpec>[
  _ParameterSpec(
    id: 'concept',
    label: '개념 난이도',
    group: 'difficulty',
    defaultValue: 6,
    min: 1,
    max: 10,
    description: '문제에 필요한 개념의 수와 깊이입니다.',
    lowExample: '함수값 대입, 단일 공식 적용처럼 선수 개념이 거의 없습니다.',
    highExample: '미분, 극값, 함수 복원, 정적분이 한 문제에서 결합됩니다.',
  ),
  _ParameterSpec(
    id: 'reasoning',
    label: '추론 난이도',
    group: 'difficulty',
    defaultValue: 6,
    min: 1,
    max: 10,
    description: '조건에서 정답까지 이어지는 논리 경로의 길이와 복잡도입니다.',
    lowExample: '조건 하나를 바로 공식에 대입합니다.',
    highExample: '조건 해석, 역추적, 분기, 병합을 거쳐 결론을 만듭니다.',
  ),
  _ParameterSpec(
    id: 'insight',
    label: '발상 난이도',
    group: 'difficulty',
    defaultValue: 5,
    min: 1,
    max: 10,
    description: '풀이를 시작하게 만드는 핵심 아이디어의 깊이입니다.',
    lowExample: '대표 공식이나 그래프 성질을 바로 떠올리면 됩니다.',
    highExample: '숨은 조건, 역방향 구성, 함수 복원 같은 전환이 필요합니다.',
  ),
  _ParameterSpec(
    id: 'calculation',
    label: '계산량',
    group: 'difficulty',
    defaultValue: 4,
    min: 1,
    max: 10,
    description: '상징 계산, 전개, 미분, 적분, 정리 비용입니다.',
    lowExample: '단순 대입과 사칙연산 중심입니다.',
    highExample: '여러 식의 전개와 미분/적분 계산이 이어집니다.',
  ),
  _ParameterSpec(
    id: 'information',
    label: '정보 밀도',
    group: 'difficulty',
    defaultValue: 5,
    min: 1,
    max: 10,
    description: '조건 수와 한 문장에 담긴 암묵 정보의 양입니다.',
    lowExample: '조건이 직접적이고 문장 수가 적습니다.',
    highExample: '짧은 문장에 정의역, 연속성, 부호, 극값 조건이 압축됩니다.',
  ),
  _ParameterSpec(
    id: 'trap',
    label: '함정 강도',
    group: 'difficulty',
    defaultValue: 3,
    min: 1,
    max: 10,
    description: '학생이 놓치기 쉬운 정의역, 부호, 필요충분 조건의 위험도입니다.',
    lowExample: '함정 없이 정석 풀이로 바로 해결됩니다.',
    highExample: '정의역 누락이나 극값/최댓값 혼동이 오답을 유도합니다.',
  ),
  _ParameterSpec(
    id: 'compression',
    label: '압축도',
    group: 'difficulty',
    defaultValue: 4,
    min: 1,
    max: 10,
    description: '문장 하나가 유도하는 암묵 결론의 양입니다.',
    lowExample: '조건을 그대로 읽으면 필요한 정보가 모두 보입니다.',
    highExample: '미분 가능, 모든 실수 등 짧은 문구에서 여러 결론을 꺼내야 합니다.',
  ),
  _ParameterSpec(
    id: 'concept_count',
    label: '개념 수',
    group: 'concept_layer',
    defaultValue: 3,
    min: 1,
    max: 8,
    description: '사용 개념의 개수입니다.',
    lowExample: '수열의 합 공식 하나만 사용합니다.',
    highExample: '함수, 미분, 극값, 적분, 방정식 해석을 함께 씁니다.',
  ),
  _ParameterSpec(
    id: 'concept_depth',
    label: '개념 깊이',
    group: 'concept_layer',
    defaultValue: 5,
    min: 1,
    max: 10,
    description: '각 개념을 표면적으로 쓰는지, 깊게 변형해 쓰는지 나타냅니다.',
    lowExample: '정의나 공식 그대로 적용합니다.',
    highExample: '개념의 역조건이나 동치 변환까지 사용합니다.',
  ),
  _ParameterSpec(
    id: 'prerequisite_depth',
    label: '선수 개념 깊이',
    group: 'concept_layer',
    defaultValue: 4,
    min: 1,
    max: 10,
    description: '풀이 전에 요구되는 선수 지식의 깊이입니다.',
    lowExample: '해당 단원 기본 정의만 알면 됩니다.',
    highExample: '이전 단원 성질과 복합 개념을 함께 알아야 합니다.',
  ),
  _ParameterSpec(
    id: 'graph_depth',
    label: '풀이 그래프 깊이',
    group: 'reasoning_layer',
    defaultValue: 5,
    min: 1,
    max: 10,
    description: '방향성 풀이 그래프의 최장 경로 길이입니다.',
    lowExample: '조건 -> 공식 적용 -> 정답입니다.',
    highExample: '조건 해석 -> 보조식 -> 분기 -> 병합 -> 검증으로 깊어집니다.',
  ),
  _ParameterSpec(
    id: 'graph_width',
    label: '풀이 그래프 폭',
    group: 'reasoning_layer',
    defaultValue: 3,
    min: 1,
    max: 8,
    description: '동시에 고려해야 하는 풀이 갈래의 폭입니다.',
    lowExample: '한 줄 풀이입니다.',
    highExample: '그래프, 대수, 조건식을 병렬로 비교합니다.',
  ),
  _ParameterSpec(
    id: 'branch_factor',
    label: '분기 계수',
    group: 'reasoning_layer',
    defaultValue: 1,
    min: 0,
    max: 5,
    description: '케이스 분류나 조건별 갈래 수입니다.',
    lowExample: '분기가 없습니다.',
    highExample: '부호, 정의역, 극값 위치에 따라 여러 케이스를 나눕니다.',
  ),
  _ParameterSpec(
    id: 'merge_factor',
    label: '병합 계수',
    group: 'reasoning_layer',
    defaultValue: 1,
    min: 0,
    max: 5,
    description: '분기된 논리를 다시 하나의 결론으로 병합하는 정도입니다.',
    lowExample: '케이스가 없어 병합도 없습니다.',
    highExample: '각 케이스의 공통 구조를 찾아 하나의 식으로 합칩니다.',
  ),
  _ParameterSpec(
    id: 'insight_count',
    label: '발상 수',
    group: 'insight_layer',
    defaultValue: 2,
    min: 0,
    max: 6,
    description: '필요한 핵심 발상 수입니다.',
    lowExample: '치환 하나면 충분합니다.',
    highExample: '역추적, 숨은 조건, 함수 복원을 모두 요구합니다.',
  ),
  _ParameterSpec(
    id: 'insight_depth',
    label: '발상 깊이',
    group: 'insight_layer',
    defaultValue: 5,
    min: 1,
    max: 10,
    description: '발상을 얼마나 깊게 적용해야 하는지입니다.',
    lowExample: '눈에 보이는 대칭성을 쓰면 됩니다.',
    highExample: '문제 조건을 거꾸로 설계한 구조를 읽어야 합니다.',
  ),
  _ParameterSpec(
    id: 'insight_uniqueness',
    label: '발상 희소성',
    group: 'insight_layer',
    defaultValue: 5,
    min: 1,
    max: 10,
    description: '발상이 얼마나 흔하지 않은지 나타냅니다.',
    lowExample: '교과서 대표 유형입니다.',
    highExample: '일반 풀이가 막히고 특정 관점 전환이 필요합니다.',
  ),
  _ParameterSpec(
    id: 'condition_count',
    label: '조건 수',
    group: 'information_layer',
    defaultValue: 4,
    min: 1,
    max: 12,
    description: '명시 조건 수입니다.',
    lowExample: '조건이 한두 개입니다.',
    highExample: '여러 식, 범위, 부호, 그래프 조건이 동시에 주어집니다.',
  ),
  _ParameterSpec(
    id: 'condition_density',
    label: '조건 밀도',
    group: 'information_layer',
    defaultValue: 5,
    min: 1,
    max: 10,
    description: '문장 대비 정보량입니다.',
    lowExample: '각 문장이 하나의 조건만 말합니다.',
    highExample: '한 문장이 연속성, 미분 가능성, 극한 정보를 동시에 담습니다.',
  ),
  _ParameterSpec(
    id: 'hidden_information',
    label: '숨은 정보량',
    group: 'information_layer',
    defaultValue: 4,
    min: 0,
    max: 10,
    description: '직접 쓰이지 않았지만 추론해야 하는 정보량입니다.',
    lowExample: '숨은 정보가 거의 없습니다.',
    highExample: '정의역, 계수 부호, 접점 조건을 직접 끌어내야 합니다.',
  ),
  _ParameterSpec(
    id: 'implicit_constraints',
    label: '암묵 제약',
    group: 'information_layer',
    defaultValue: 4,
    min: 0,
    max: 10,
    description: '암묵 제약의 수와 강도입니다.',
    lowExample: '모든 제약이 명시되어 있습니다.',
    highExample: '실수 조건, 자연수 조건, 함수 존재 조건이 숨어 있습니다.',
  ),
  _ParameterSpec(
    id: 'symbolic_operations',
    label: '기호 조작량',
    group: 'computation_layer',
    defaultValue: 4,
    min: 0,
    max: 15,
    description: '기호 조작 횟수입니다.',
    lowExample: '간단한 대입 위주입니다.',
    highExample: '식 변형과 계수 비교가 반복됩니다.',
  ),
  _ParameterSpec(
    id: 'algebra_steps',
    label: '대수 계산 단계',
    group: 'computation_layer',
    defaultValue: 4,
    min: 0,
    max: 15,
    description: '대수 계산 단계 수입니다.',
    lowExample: '일차식 정리 수준입니다.',
    highExample: '다항식 전개, 인수분해, 연립 조건 정리가 필요합니다.',
  ),
  _ParameterSpec(
    id: 'derivative_steps',
    label: '미분 단계',
    group: 'computation_layer',
    defaultValue: 2,
    min: 0,
    max: 10,
    description: '미분 계산 단계 수입니다.',
    lowExample: '미분을 쓰지 않거나 한 번만 씁니다.',
    highExample: '도함수, 이계도함수, 극값 조건을 연쇄적으로 씁니다.',
  ),
  _ParameterSpec(
    id: 'integral_steps',
    label: '적분 단계',
    group: 'computation_layer',
    defaultValue: 1,
    min: 0,
    max: 10,
    description: '적분 계산 단계 수입니다.',
    lowExample: '적분이 없거나 넓이 공식만 씁니다.',
    highExample: '정적분 조건과 함수 복원을 함께 처리합니다.',
  ),
  _ParameterSpec(
    id: 'simplification_cost',
    label: '식 정리 비용',
    group: 'computation_layer',
    defaultValue: 4,
    min: 0,
    max: 15,
    description: '마지막 식 정리 비용입니다.',
    lowExample: '정답식이 바로 나옵니다.',
    highExample: '여러 항 정리와 약분을 거쳐야 합니다.',
  ),
  _ParameterSpec(
    id: 'trap_count',
    label: '함정 수',
    group: 'trap_layer',
    defaultValue: 2,
    min: 0,
    max: 8,
    description: '오답 유발 요소 수입니다.',
    lowExample: '함정이 거의 없습니다.',
    highExample: '정의역, 부호, 필요조건 오류가 동시에 존재합니다.',
  ),
  _ParameterSpec(
    id: 'trap_severity',
    label: '함정 강도',
    group: 'trap_layer',
    defaultValue: 3,
    min: 0,
    max: 10,
    description: '함정을 놓쳤을 때 오답으로 이어지는 정도입니다.',
    lowExample: '검산하면 쉽게 회복됩니다.',
    highExample: '초반 조건을 놓치면 풀이 전체가 틀어집니다.',
  ),
  _ParameterSpec(
    id: 'compression_score',
    label: '압축 점수',
    group: 'compression_layer',
    defaultValue: 4,
    min: 1,
    max: 10,
    description: '조건 문장의 압축 점수입니다.',
    lowExample: '문제 문장이 길지만 직접적입니다.',
    highExample: '짧은 문장에서 여러 성질을 추론해야 합니다.',
  ),
  _ParameterSpec(
    id: 'implicit_information',
    label: '암묵 정보량',
    group: 'compression_layer',
    defaultValue: 4,
    min: 0,
    max: 10,
    description: '압축 문장에서 풀어내야 하는 암묵 정보입니다.',
    lowExample: '문장 그대로 사용합니다.',
    highExample: '미분 가능성에서 연속성, 극한 존재, 접선 조건을 꺼냅니다.',
  ),
  _ParameterSpec(
    id: 'top_rate',
    label: '상위권 예상 정답률',
    group: 'student_simulator',
    defaultValue: 82,
    min: 0,
    max: 100,
    description: '상위권 학생 시뮬레이션 정답률입니다.',
    lowExample: '30% 이하면 최상위권도 발상 장벽이 큽니다.',
    highExample: '90% 이상이면 상위권에게 안정적인 문항입니다.',
  ),
  _ParameterSpec(
    id: 'middle_rate',
    label: '중위권 예상 정답률',
    group: 'student_simulator',
    defaultValue: 46,
    min: 0,
    max: 100,
    description: '중위권 학생 시뮬레이션 정답률입니다.',
    lowExample: '10%대는 고난도 문항입니다.',
    highExample: '60% 이상이면 일반 4점 이하에 가깝습니다.',
  ),
  _ParameterSpec(
    id: 'low_rate',
    label: '하위권 예상 정답률',
    group: 'student_simulator',
    defaultValue: 18,
    min: 0,
    max: 100,
    description: '하위권 학생 시뮬레이션 정답률입니다.',
    lowExample: '5% 이하는 거의 접근이 어렵습니다.',
    highExample: '40% 이상이면 기본 개념 확인형입니다.',
  ),
];

final _parameterGroups = <_ParameterGroup>[
  for (final entry in {
    'difficulty': '난이도 벡터',
    'concept_layer': '개념 계층',
    'reasoning_layer': '추론 계층',
    'insight_layer': '발상 계층',
    'information_layer': '정보 계층',
    'computation_layer': '계산 계층',
    'trap_layer': '함정 계층',
    'compression_layer': '압축 계층',
    'student_simulator': '학생 시뮬레이터',
  }.entries)
    _ParameterGroup(
      id: entry.key,
      label: entry.value,
      specs: _advancedParameterSpecs
          .where((spec) => spec.group == entry.key)
          .toList(),
    ),
];

const _nodeTypes = <String>[
  'condition',
  'concept',
  'insight',
  'reasoning',
  'computation',
  'trap',
  'verification',
];

String _nodeTypeLabel(String type) {
  switch (type) {
    case 'condition':
      return '조건';
    case 'concept':
      return '개념';
    case 'insight':
      return '발상';
    case 'reasoning':
      return '추론';
    case 'computation':
      return '계산';
    case 'trap':
      return '함정';
    case 'verification':
      return '검증';
    default:
      return type;
  }
}

String _defaultNodeDetail(String type) {
  switch (type) {
    case 'condition':
      return '명시 조건과 숨은 제약을 정리한다.';
    case 'concept':
      return '사용할 교과 개념과 선수 지식을 지정한다.';
    case 'insight':
      return '대칭성, 역추론, 치환 등 핵심 발상을 지정한다.';
    case 'reasoning':
      return '방향성 풀이 그래프에서 다음 결론으로 이어지는 논리를 작성한다.';
    case 'computation':
      return '계산량과 식 정리 단계를 조절한다.';
    case 'trap':
      return '정의역, 부호, 필요충분 조건 함정을 설계한다.';
    case 'verification':
      return '정답 유일성과 조건 모순 여부를 검증한다.';
    default:
      return '';
  }
}

IconData _nodeTypeIcon(String type) {
  switch (type) {
    case 'condition':
      return Icons.fact_check_rounded;
    case 'concept':
      return Icons.school_rounded;
    case 'insight':
      return Icons.lightbulb_outline_rounded;
    case 'reasoning':
      return Icons.account_tree_rounded;
    case 'computation':
      return Icons.functions_rounded;
    case 'trap':
      return Icons.warning_amber_rounded;
    case 'verification':
      return Icons.verified_rounded;
    default:
      return Icons.circle_rounded;
  }
}

Color _nodeTypeColor(String type) {
  switch (type) {
    case 'condition':
      return const Color(0xFF2F7CF6);
    case 'concept':
      return const Color(0xFF238B5E);
    case 'insight':
      return const Color(0xFF8A52E8);
    case 'reasoning':
      return const Color(0xFFDD5F34);
    case 'computation':
      return const Color(0xFFD6477C);
    case 'trap':
      return const Color(0xFF927A1F);
    case 'verification':
      return kCourseGreen;
    default:
      return kCourseGreen;
  }
}

const _ksatMathGenerationSystemPrompt = r'''
시스템 지시문: 수능 수학 문제 생성 및 난이도 평가 엔진

당신은 대한민국 수능 수학 출제 및 평가 엔진이다.
목표는 단순히 문제를 만드는 것이 아니라, 수능 스타일의 문제를 생성하고 그 난이도를 정량적으로 평가하는 것이다.

1. 기본 원칙

(1) 개념 계층
- 필요한 개념의 종류와 깊이를 고려한다.
- 평가항목: 개념 수, 개념 깊이, 선수 개념 깊이

(2) 추론 계층
- 풀이를 방향성 비순환 풀이 그래프 형태로 구성한다.
- 평가항목: 풀이 그래프 깊이, 풀이 그래프 폭, 분기 계수, 병합 계수

(3) 발상 계층
- 풀이에 필요한 핵심 발상을 정의한다.
- 발상 라이브러리: 대칭성, 역추론, 치환, 불변량, 모순 이용, 경우 분류, 그래프 해석, 극값 변환, 숨은 조건, 함수 복원
- 평가항목: 발상 수, 발상 깊이, 발상 희소성

(4) 정보 계층
- 조건의 양과 밀도를 평가한다.
- 평가항목: 조건 수, 조건 밀도, 숨은 정보량, 암묵 제약

(5) 계산 계층
- 계산량을 측정한다.
- 평가항목: 기호 조작량, 대수 계산 단계, 미분 단계, 적분 단계, 식 정리 비용
- 최근 수능은 계산량보다 발상과 추론을 우선한다.

(6) 함정 계층
- 정의역 함정, 필요조건/충분조건 혼동, 극값/최댓값 혼동, 부호 실수, 조건 누락을 평가한다.
- 평가항목: 함정 수, 함정 강도

(7) 압축 계층
- 한 문장에 압축된 암묵 정보를 평가한다.
- 평가항목: 압축 점수, 암묵 정보량

2. 문제 생성 절차
1) 목표 난이도 벡터 설정
2) 지식 그래프에서 개념 선택
3) 풀이 그래프 생성
4) 조건 생성
5) 발상 삽입
6) 함정 삽입
7) 계산량 조절
8) 문제 문장 생성

3. 난이도 평가기
- 개념 점수, 추론 점수, 발상 점수, 정보 점수, 계산 점수, 함정 점수, 압축 점수, 그래프 복잡도, 풀이 그래프 깊이, 분기 계수, 숨은 정보량, 정답 유일성을 평가한다.
- 난이도는 단일 점수가 아니라 {개념, 추론, 발상, 계산, 정보, 함정, 압축} 벡터로 관리한다.

4. 학생 시뮬레이터
- 상위권, 중위권, 하위권 학생 모델을 가정한다.
- 개념 숙련도, 추론 능력, 발상 능력, 부주의 확률을 고려하여 예상 정답률을 계산한다.

5. 수능 난이도 분류
- 3점: 개념 <= 4, 추론 <= 3, 발상 <= 2
- 일반 4점: 개념 5~7, 추론 5~7
- 22번: 개념 >= 7, 추론 >= 8
- 29번: 추론 >= 9, 발상 >= 9
- 30번: 추론 >= 9, 발상 >= 10, 풀이 그래프 깊이 >= 8, 분기 계수 >= 2

6. 품질 검증
- 정답의 유일성, 조건의 모순 여부, 풀이 가능 여부, 과도한 계산 여부, 교육과정 범위 준수, 우회 풀이 존재 여부, 출제 의도 일관성을 검사한다.
- 품질 기준을 만족하지 못하면 문제를 폐기하고 다시 생성한다.

7. 출력 형식
문제를 생성할 때 다음 정보를 함께 산출한다.
1. 문제
2. 정답
3. 모범 풀이
4. 풀이 그래프
5. 사용 개념
6. 핵심 발상
7. 난이도 벡터
8. 예상 정답률
9. 수능 예상 번호(3점/4점/22번/29번/30번)
10. 출제 의도

최종 목표는 어려운 문제를 만드는 것이 아니라, 수능의 사고 구조를 재현 가능한 형태로 모델링하고 생성과 평가를 동일한 프레임워크 안에서 수행하는 것이다.
''';
