import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../shared/theme/app_colors.dart';
import '../shared/ui/ios26/ios26_chrome.dart';
import '../shared/ui/ios26/teacher_full_face_panel.dart';
import '../widgets/design_tokens.dart';
import '../widgets/teacher_app_drawer.dart';

class ProblemEditorPage extends StatefulWidget {
  const ProblemEditorPage({
    super.key,
    this.initialTags = const <String>[],
    this.returnGeneratedQuestOnSave = false,
  });

  final List<String> initialTags;
  final bool returnGeneratedQuestOnSave;

  @override
  State<ProblemEditorPage> createState() => _ProblemEditorPageState();
}

class _ProblemEditorPageState extends State<ProblemEditorPage> {
  final _promptCtrl = TextEditingController();
  final _baseQuestCtrl = TextEditingController();
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

  String _canvasTool = 'edit';
  String? _edgeSourceId;
  String? _canvasNotice;
  Size _canvasSize = const Size(1600, 1000);

  bool _loading = false;
  bool _dbSearching = false;
  String? _resultText;
  String? _selectedNodeId;
  String? _dbError;
  List<String> _availableTags = [];
  List<_GenerationTagGroup> _tagGroups = [];
  List<Map<String, dynamic>> _tray = [];
  List<Map<String, dynamic>> _dbResults = [];
  List<Map<String, dynamic>> _teacherTextbooks = [];
  List<Map<String, dynamic>> _teacherExams = [];
  Map<String, dynamic>? _selectedDbQuest;

  _GenerationProfile get _simpleProfile {
    return _simpleProfiles.firstWhere(
      (profile) => profile.id == _simpleLevel,
      orElse: () => _simpleProfiles[1],
    );
  }

  /// 필요 변수: 선택된 노드 ID와 현재 노드 목록.
  /// 작동 원리: ID가 일치하는 노드 초안을 반환하고 없으면 null을 반환한다.
  _LogicNodeDraft? get _selectedNode {
    for (final node in _logicNodes) {
      if (node.id == _selectedNodeId) return node;
    }
    return null;
  }

  /// 필요 변수: 초기 태그·문제 저장소·고급 노드 상태.
  /// 작동 원리: 화면 생성 시 비동기 자료를 요청하고 기본 풀이 그래프를 한 번 구성한다.
  @override
  void initState() {
    super.initState();
    _tags.addAll(_uniqueTags(widget.initialTags));
    _loadTagSuggestions();
    _loadTray();
    _searchProblemDb();
    _resetAdvancedNodes();
  }

  /// 필요 변수: 서버의 문항 생성 태그 그룹 또는 과정 태그 목록.
  /// 작동 원리: 생성 전용 태그를 우선 조회하고 실패하면 과정 태그로 대체한다.
  Future<void> _loadTagSuggestions() async {
    try {
      final groupsRaw = await ApiClient.instance.getQuestGenerationTagGroups();
      final groups = groupsRaw
          .map(_GenerationTagGroup.fromJson)
          .where((group) => group.tags.isNotEmpty)
          .toList();
      final tags = _uniqueTags(groups.expand((group) => group.tags));
      if (!mounted) return;
      setState(() {
        _tagGroups = groups;
        _availableTags = tags;
      });
    } catch (_) {
      try {
        final tags = await ApiClient.instance.getCourseHashTags();
        if (!mounted) return;
        setState(() => _availableTags = _uniqueTags(tags));
      } catch (_) {}
    }
  }

  /// 필요 변수: 현재 교사의 최근 문항 트레이 최대 50건.
  /// 작동 원리: 서버 목록을 읽고 화면이 살아 있을 때만 로컬 상태를 갱신한다.
  Future<void> _loadTray() async {
    try {
      final items = await ApiClient.instance.listQuestTray(limit: 50);
      if (!mounted) return;
      setState(() => _tray = items);
    } catch (_) {}
  }

  /// 필요 변수: 직접 입력 문항 ID와 선택한 코드베이스·seed.
  /// 작동 원리: 값이 존재하는 참조만 API 요청 맵에 포함한다.
  Map<String, dynamic> _baseQuestRef() {
    final questId = _baseQuestCtrl.text.trim();
    return {
      if (questId.isNotEmpty) 'quest_id': questId,
      if (_selectedDbQuest?['codebase_id'] != null)
        'codebase_id': _selectedDbQuest!['codebase_id'],
      if (_selectedDbQuest?['seed'] != null) 'seed': _selectedDbQuest!['seed'],
    };
  }

  /// 필요 변수: 현재 노드 목록과 노드 ID 시퀀스.
  /// 작동 원리: 기존 컨트롤러를 해제한 뒤 조건→발상→추론→검증 흐름으로 초기화한다.
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

  /// 필요 변수: 노드 유형·제목·설명·초기 좌표와 증가 ID.
  /// 작동 원리: 각 입력용 컨트롤러를 소유하는 편집 가능한 노드 초안을 만든다.
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
      teacherInstructionCtrl: TextEditingController(),
    );
  }

  /// 필요 변수: 새 노드 유형, 현재 노드 수와 캔버스 배치 순서.
  /// 작동 원리: 최대 32개 경계를 지키며 격자 위치에 역할별 기본 노드를 추가한다.
  void _addLogicNode(String type) {
    if (_logicNodes.length >= 32) {
      setState(() => _canvasNotice = '한 캔버스에는 최대 32개 노드를 추가할 수 있습니다.');
      return;
    }
    final index = _logicNodes.length;
    setState(() {
      final node = _createNode(
        type: type,
        title: _nodeTypeLabel(type),
        detail: _defaultNodeDetail(type),
        position: Offset(80 + (index % 4) * 220, 80 + (index ~/ 4) * 130),
      );
      _logicNodes.add(node);
      _selectedNodeId = node.id;
      _canvasTool = 'edit';
      _edgeSourceId = null;
      _canvasNotice = '${_nodeTypeLabel(type)} 노드를 추가했습니다.';
    });
  }

  /// 필요 변수: 연결 시작 노드 [source], 연결 대상 노드 [target].
  /// 작동 원리: 노드 역할별 연결 제한과 순환 여부를 검사해 방향성 비순환 풀이 그래프를 유지한다.
  String? _connectionBlockReason(
    _LogicNodeDraft source,
    _LogicNodeDraft target,
  ) {
    if (source.id == target.id) return '같은 노드끼리는 연결할 수 없습니다.';
    if (source.nextIds.contains(target.id)) return '이미 연결된 노드입니다.';
    if (source.type == 'verification') {
      return '검증 노드는 마지막 단계라 다음 노드를 연결할 수 없습니다.';
    }
    final maxOutgoing = _nodeMaxOutgoing(source.type);
    if (source.nextIds.length >= maxOutgoing) {
      return '${_nodeTypeLabel(source.type)} 노드는 최대 $maxOutgoing개까지 연결할 수 있습니다.';
    }
    if (_hasNodePath(target.id, source.id)) return '순환하는 풀이 흐름은 만들 수 없습니다.';
    return null;
  }

  /// 필요 변수: 탐색 시작 노드 ID [fromId], 도착 노드 ID [toId], 현재 연결 목록.
  /// 작동 원리: 반복 깊이 우선 탐색으로 기존 경로를 확인해 새 연결이 순환을 만드는지 판정한다.
  bool _hasNodePath(String fromId, String toId) {
    final byId = {for (final node in _logicNodes) node.id: node};
    final pending = <String>[fromId];
    final visited = <String>{};
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      if (current == toId) return true;
      if (!visited.add(current)) continue;
      pending.addAll(byId[current]?.nextIds ?? const <String>{});
    }
    return false;
  }

  /// 필요 변수: 클릭한 [node], 현재 캔버스 도구 [_canvasTool].
  /// 작동 원리: 편집은 선택만 수행하고 연결·해제는 첫 클릭을 시작점, 두 번째 클릭을 대상점으로 처리한다.
  void _handleCanvasNodeTap(_LogicNodeDraft node, [VoidCallback? refresh]) {
    setState(() {
      _selectedNodeId = node.id;
      if (_canvasTool != 'link' && _canvasTool != 'unlink') return;
      if (_edgeSourceId == null) {
        _edgeSourceId = node.id;
        _canvasNotice = '${node.titleCtrl.text.trim()}에서 시작할 대상 노드를 선택하세요.';
        return;
      }
      final source = _logicNodes.firstWhere((item) => item.id == _edgeSourceId);
      if (_canvasTool == 'link') {
        final reason = _connectionBlockReason(source, node);
        if (reason == null) {
          source.nextIds.add(node.id);
          _canvasNotice =
              '${source.titleCtrl.text.trim()} → ${node.titleCtrl.text.trim()} 연결 완료';
        } else {
          _canvasNotice = reason;
        }
      } else if (source.nextIds.remove(node.id)) {
        _canvasNotice =
            '${source.titleCtrl.text.trim()} → ${node.titleCtrl.text.trim()} 연결 해제';
      } else {
        _canvasNotice = '두 노드 사이에 해제할 직접 연결이 없습니다.';
      }
      _edgeSourceId = null;
    });
    refresh?.call();
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

  Future<void> _editNodeInstruction(_LogicNodeDraft node) async {
    final ctrl = TextEditingController(text: node.teacherInstructionCtrl.text);
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (context) => TeacherFullFacePanel(
          eyebrow: 'PROBLEM STUDIO',
          title: '세부 지시',
          description: '선택한 논리 노드에만 적용할 교사 지시를 입력합니다.',
          maxContentWidth: 680,
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: const Text('지시 제거'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
              child: const Text('저장'),
            ),
          ],
          content: Align(
            alignment: Alignment.topCenter,
            child: TextField(
              controller: ctrl,
              maxLength: 200,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '이 노드에서만 반영할 지시를 입력합니다.',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ),
      ),
    );
    ctrl.dispose();
    if (result == null) return;
    setState(() {
      node.teacherInstructionCtrl.text = result.length > 200
          ? result.substring(0, 200)
          : result;
    });
  }

  /// 필요 변수: [_logicNodes]의 노드별 태그 목록.
  /// 작동 원리: 고급 생성에서는 전체 태그 입력값을 섞지 않고 노드에 지정된 태그만 중복 제거해 반환한다.
  List<String> get _advancedTags {
    final tags = <String>[];
    for (final node in _logicNodes) {
      tags.addAll(node.tags);
    }
    return _uniqueTags(tags);
  }

  List<String> _generationTagsForPayload(bool advanced) {
    return advanced ? _advancedTags : _uniqueTags(_tags);
  }

  bool _ensureAdvancedNodeTags() {
    final pool = _availableTags;
    if (pool.isEmpty) return false;
    final rng = math.Random();
    var changed = false;
    for (final node in _logicNodes) {
      node.tags.removeWhere((tag) => !pool.contains(tag));
      if (node.tags.isEmpty) {
        node.tags.add(pool[rng.nextInt(pool.length)]);
        changed = true;
      }
    }
    if (changed) setState(() {});
    return true;
  }

  /// 필요 변수: 선택한 [quest], 현재 편집 모드 [_editorMode].
  /// 작동 원리: 참고문항 식별자를 연결하고 간편 모드에서만 해당 문항의 태그를 전체 태그에 병합한다.
  void _selectDbQuest(Map<String, dynamic> quest) {
    final questId = quest['quest_id']?.toString() ?? '';
    if (questId.isEmpty) return;
    setState(() {
      _selectedDbQuest = quest;
      _baseQuestCtrl.text = questId;
      final rawTags = quest['hash_tags'];
      if (_editorMode == 'simple' && rawTags is List) {
        for (final tag in rawTags) {
          final value = tag.toString().trim();
          if (value.isNotEmpty && !_tags.contains(value)) {
            _tags.add(value);
          }
        }
      }
    });
  }

  /// 필요 변수: 검색 모드 [_dbSearchMode], 검색어 [_dbSearchCtrl].
  /// 작동 원리: 교사 소유 문항과 문서함의 교재·시험지를 함께 조회해 파일 트리 상태를 갱신한다.
  Future<void> _searchProblemDb() async {
    final query = _dbSearchCtrl.text.trim();
    setState(() {
      _dbSearching = true;
      _dbError = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        ApiClient.instance.searchExamEditorProblems(
          text: _dbSearchMode == 'text' ? query : null,
          hashTag: _dbSearchMode == 'hashtag' ? query : null,
          dateFrom: _dbSearchMode == 'date' ? query : null,
          ownedOnly: true,
          pageSize: 80,
        ),
        ApiClient.instance.listTeacherDocuments(type: 'textbook'),
        ApiClient.instance.listTeacherDocuments(type: 'exam'),
      ]);
      final result = results[0] as Map<String, dynamic>;
      final items = (result['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      setState(() {
        _dbResults = items;
        _teacherTextbooks = (results[1] as List<Map<String, dynamic>>);
        _teacherExams = (results[2] as List<Map<String, dynamic>>);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _dbError = e.toString());
    } finally {
      if (mounted) setState(() => _dbSearching = false);
    }
  }

  /// 필요 변수: 서버 생성 응답 [result], 생성 방식 [sourceMode], 화면 모드 [advanced].
  /// 작동 원리: 서버 저장 완료 응답을 임시저장함 목록 맨 앞에 즉시 반영해 재조회 요청을 없앤다.
  void _addResultToTray(
    Map<String, dynamic> result, {
    required String sourceMode,
    required bool advanced,
  }) {
    final quest = result['quest'];
    if (quest is! Map) return;
    final header = quest['header'];
    final data = quest['data'];
    if (header is! Map) return;
    final questId = header['quest_id']?.toString().trim() ?? '';
    if (questId.isEmpty) return;
    final item = <String, dynamic>{
      'quest_id': questId,
      if (data is Map) 'codebase_id': data['codebase_id'],
      if (data is Map) 'seed': data['seed'],
      'source_variant_mode': sourceMode,
      'visibility_scope': sourceMode == 'mcq_convert'
          ? 'private_mcq'
          : 'shared',
      'is_mcq_branch': sourceMode == 'mcq_convert',
      'payload': {'mode': advanced ? 'advanced' : 'simple'},
      'updated_at': DateTime.now().toIso8601String(),
    };
    setState(() {
      _tray.removeWhere((saved) => saved['quest_id']?.toString() == questId);
      _tray.insert(0, item);
    });
  }

  Future<void> _generateVariant() async {
    final advanced = _editorMode == 'advanced';
    final graphError = advanced ? _validateAdvancedGraph() : null;
    if (graphError != null) {
      setState(() {
        _resultText = graphError;
        _canvasNotice = graphError;
      });
      return;
    }
    if (advanced && !_ensureAdvancedNodeTags()) {
      setState(() => _resultText = '생성 태그 목록을 불러오지 못했습니다.');
      return;
    }
    final profile = advanced ? _buildAdvancedProfile() : _simpleProfile;
    final flowDraft = advanced
        ? _advancedFlowDraft()
        : _simpleFlowDraft(profile);
    final prompt = advanced
        ? _buildAdvancedPrompt(profile)
        : _buildSimplePrompt(profile);
    final tagsForPayload = _generationTagsForPayload(advanced);

    if (tagsForPayload.isEmpty) {
      setState(() => _resultText = '태그를 1개 이상 선택해야 합니다.');
      return;
    }

    setState(() {
      _loading = true;
      _resultText = null;
    });

    try {
      final common = <String, dynamic>{
        'base_quest_ref': _baseQuestRef(),
        'prompt': prompt,
        'tags': tagsForPayload,
        'solves_count': profile.solvesCount,
        'strategy_level': profile.strategyLevel,
        'branch_conditions': profile.branchConditions,
      };
      if (advanced) {
        common['advanced_metrics'] = _advancedMetricMap();
        common['advanced_profile'] = {
          ...profile.toMeta(),
          'mode': 'advanced',
          'metrics': _advancedMetricMap(),
        };
      }

      final Map<String, dynamic> result;
      if (advanced || _variantInputMode == 'flow_draft') {
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
        final data = quest?['data'] is Map<String, dynamic>
            ? quest!['data'] as Map<String, dynamic>
            : const <String, dynamic>{};
        if (widget.returnGeneratedQuestOnSave && mounted) {
          Navigator.of(context).pop(<String, dynamic>{
            'quest_id': questId,
            'quest_title': data['quest_title'],
            'question_type': data['question_type'],
            'codebase_id': data['codebase_id'],
            'seed': data['seed'],
            'hash_tags': tagsForPayload,
          });
          return;
        }
      }
      _addResultToTray(
        result,
        sourceMode: advanced || _variantInputMode == 'flow_draft'
            ? 'flow_draft'
            : 'prompt_note',
        advanced: advanced,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _resultText = '오류: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 필요 변수: [_logicNodes]와 각 노드의 [nextIds].
  /// 작동 원리: 생성 직전에 도달 가능성·종료 검증·병합 입력 수를 검사해 불완전한 그래프 전송을 차단한다.
  String? _validateAdvancedGraph() {
    if (_logicNodes.isEmpty) return '풀이 논리 노드가 1개 이상 필요합니다.';
    final indegree = {for (final node in _logicNodes) node.id: 0};
    final neighbors = {for (final node in _logicNodes) node.id: <String>{}};
    for (final node in _logicNodes) {
      for (final targetId in node.nextIds) {
        if (!indegree.containsKey(targetId)) return '존재하지 않는 노드 연결이 있습니다.';
        indegree[targetId] = indegree[targetId]! + 1;
        neighbors[node.id]!.add(targetId);
        neighbors[targetId]!.add(node.id);
      }
    }
    final roots = _logicNodes.where((node) => indegree[node.id] == 0).toList();
    if (roots.isEmpty) return '풀이 시작 노드가 없습니다.';
    final reachable = <String>{};
    final pending = <String>[_logicNodes.first.id];
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      if (!reachable.add(id)) continue;
      pending.addAll(neighbors[id]!);
    }
    if (reachable.length != _logicNodes.length) {
      return '시작점에서 도달할 수 없는 고립 노드가 있습니다.';
    }
    final verifications = _logicNodes.where(
      (node) => node.type == 'verification',
    );
    if (verifications.isEmpty) return '마지막 단계에 검증 노드가 1개 이상 필요합니다.';
    if (verifications.any((node) => node.nextIds.isNotEmpty)) {
      return '검증 노드는 다른 노드로 연결될 수 없습니다.';
    }
    if (_logicNodes.any(
      (node) => node.nextIds.isEmpty && node.type != 'verification',
    )) {
      return '모든 풀이 갈래는 검증 노드에서 끝나야 합니다.';
    }
    for (final node in _logicNodes.where((node) => node.type == 'merge')) {
      if ((indegree[node.id] ?? 0) < 2) return '병합 노드는 앞선 흐름이 2개 이상 연결되어야 합니다.';
    }
    return null;
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
      _addResultToTray(
        result,
        sourceMode: 'mcq_convert',
        advanced: _editorMode == 'advanced',
      );
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
    final parts = _buildAdvancedPromptParts(profile);
    final buffer = StringBuffer();
    for (final entry in parts.entries) {
      final value = entry.value.trim();
      if (value.isEmpty) continue;
      buffer
        ..writeln('[${entry.key}]')
        ..writeln(value)
        ..writeln();
    }
    return buffer.toString().trim();
  }

  Map<String, String> _buildAdvancedPromptParts(_GenerationProfile profile) {
    final buffer = StringBuffer()
      ..writeln('적용 모드: 고급 문항 제작')
      ..writeln('출력 호환성: 기존 코드베이스 문항 스키마와 저장 위치를 변경하지 않는다.')
      ..writeln('생성 방식: 풀이 논리 캔버스의 노드 지시를 우선 반영한다.');
    final difficulty = StringBuffer()
      ..writeln('수능 예상 번호: ${profile.expectedNumber}')
      ..writeln('난이도 벡터: ${_formatVector(profile.difficultyVector)}')
      ..writeln(
        '코드베이스 파라미터: 풀이 단계 수=$_solvesCount, '
        '전략 난이도=$_strategyLevel, 분기 수=$_branchConditions',
      )
      ..writeln('예상 정답률: ${_formatCorrectRate(profile.expectedCorrectRate)}');
    final nodes = StringBuffer();
    for (final node in _logicNodes) {
      nodes.writeln(_nodePromptText(node));
    }
    final reference = StringBuffer();
    if (_selectedDbQuest != null) {
      reference
        ..writeln('저장소에서 선택한 참고문항을 변형 기준으로 사용한다.')
        ..writeln(_selectedDbQuest.toString());
    }
    return {
      '시스템': _ksatMathGenerationSystemPrompt,
      '호환성': buffer.toString(),
      '난이도': difficulty.toString(),
      '세부 평가 변수': _formatAdvancedMetricPayload(),
      '풀이 논리 노드': nodes.toString(),
      '참고문항': reference.toString(),
    };
  }

  String _nodePromptText(_LogicNodeDraft node) {
    final instruction = node.teacherInstructionCtrl.text.trim();
    final prompt = instruction.isEmpty
        ? _defaultNodePrompt(node.type)
        : instruction;
    return [
      '- ${node.id} [${_nodeTypeLabel(node.type)}] ${node.titleCtrl.text.trim()}',
      '  태그: ${node.tags.join(', ')}',
      '  다음: ${node.nextIds.isEmpty ? '-' : node.nextIds.join(', ')}',
      '  풀이 논리: ${node.detailCtrl.text.trim()}',
      '  생성 지시: $prompt',
    ].join('\n');
  }

  String _formatAdvancedMetricPayload() {
    return _advancedParameterSpecs
        .map((spec) => '- ${spec.label}: ${_metricInt(spec.id)}')
        .join('\n');
  }

  Map<String, int> _advancedMetricMap() {
    return {
      for (final spec in _advancedParameterSpecs) spec.id: _metricInt(spec.id),
    };
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

  /// 필요 변수: [_logicNodes]의 내용, 연결 관계, 교사 지시, 노드별 태그.
  /// 작동 원리: 각 노드를 생성 API의 풀이 흐름 형식으로 변환하며 태그는 해당 노드 값만 전달한다.
  List<Map<String, dynamic>> _advancedFlowDraft() {
    return _logicNodes
        .map(
          (node) => {
            'node_id': node.id,
            'node_type': node.type,
            'text':
                '${node.titleCtrl.text.trim()}\n${node.detailCtrl.text.trim()}',
            'hash_tags': node.tags.toList(),
            'branches': node.nextIds.toList(),
            'teacher_instruction': node.teacherInstructionCtrl.text.trim(),
            'prompt_text': _nodePromptText(node),
          },
        )
        .toList();
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
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: InputDecorationTheme(
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
        ),
      ),
      child: Scaffold(
        endDrawer: const TeacherAppDrawer(currentRoute: '/problem-editor'),
        backgroundColor: kCourseBgGrey,
        body: Builder(
          builder: (scaffoldContext) => SafeArea(
            child: Column(
              children: [
                Ios26TopBar(
                  brandColor: kCourseGreen,
                  title: '문항 제작 스튜디오',
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.of(context).pop()
                      : null,
                  onMenu: () => Scaffold.of(scaffoldContext).openEndDrawer(),
                  items: const [
                    Ios26NavItem(label: '입력', active: true),
                    Ios26NavItem(label: '논리 설계'),
                    Ios26NavItem(label: '생성 설정'),
                  ],
                  trailingIcons: [
                    Ios26ActionIcon(
                      icon: Icons.info_outline_rounded,
                      label: '설명서',
                      onTap: _showDocumentation,
                    ),
                  ],
                ),
                _buildWorkspaceHeader(scale),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 1180;
                      final mobile = constraints.maxWidth < 720;
                      final simple = _editorMode == 'simple';
                      final left = simple ? _buildLeftPanel(scale) : null;
                      final center = _editorMode == 'simple'
                          ? _buildSimplePipelinePanel(scale)
                          : _buildAdvancedCanvasPanel(scale);
                      final right = _buildRightPanel(scale);

                      if (mobile) {
                        final panels = simple
                            ? <Widget>[if (left != null) left, center, right]
                            : <Widget>[center, right];
                        final tabs = simple
                            ? const [
                                Tab(text: '입력'),
                                Tab(text: '흐름'),
                                Tab(text: '설정'),
                              ]
                            : const [Tab(text: '논리 설계'), Tab(text: '설정')];
                        return DefaultTabController(
                          length: panels.length,
                          child: Column(
                            children: [
                              Material(
                                color: Colors.white,
                                child: TabBar(tabs: tabs),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.all(10 * scale),
                                  child: TabBarView(children: panels),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (compact) {
                        return ListView(
                          padding: EdgeInsets.all(14 * scale),
                          children: [
                            if (left != null) ...[
                              SizedBox(height: 640 * scale, child: left),
                              SizedBox(height: 12 * scale),
                            ],
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
                          if (left != null)
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
          ),
        ),
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
        border: Border.all(color: AppColors.surfaceBorder),
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
          label: '생성/임시저장',
          active: _resultText != null || _tray.isNotEmpty,
        ),
      ],
    );
  }

  /// 필요 변수: 화면 배율 [scale], 간편 모드 입력값과 태그.
  /// 작동 원리: 간편 모드의 생성 입력만 표시하며 고급 모드 설정은 모두 우측 패널에서 관리한다.
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

  /// 필요 변수: 화면 배율 [scale], 간편 모드의 선택 태그 [_tags].
  /// 작동 원리: 간편 생성에서만 사용할 전체 태그를 선택·삭제할 수 있도록 구성한다.
  Future<List<String>?> _openTagPicker(Iterable<String> initialTags) {
    return Navigator.of(context).push<List<String>>(
      MaterialPageRoute<List<String>>(
        fullscreenDialog: true,
        builder: (_) => _GenerationTagPickerDialog(
          groups: _tagGroups,
          fallbackTags: _availableTags,
          initialTags: initialTags,
        ),
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
        OutlinedButton.icon(
          onPressed: _availableTags.isEmpty
              ? null
              : () async {
                  final selected = await _openTagPicker(_tags);
                  if (selected == null) return;
                  setState(() {
                    _tags
                      ..clear()
                      ..addAll(selected);
                  });
                },
          icon: const Icon(Icons.checklist_rounded),
          label: const Text('해시태그 선택'),
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

  /// 필요 변수: 화면 배율 [scale], 캔버스 도구 상태와 노드 목록.
  /// 작동 원리: 일반 화면과 전체화면에서 공용 캔버스 작업영역을 사용해 편집 상태를 동일하게 유지한다.
  Widget _buildAdvancedCanvasPanel(double scale) {
    return _StudioPanel(
      title: '풀이 논리 캔버스',
      child: Padding(
        padding: EdgeInsets.all(14 * scale),
        child: _buildCanvasWorkspace(scale),
      ),
    );
  }

  /// 필요 변수: 화면 배율 [scale], 전체화면 여부 [fullscreen], 선택적 갱신 함수 [refresh].
  /// 작동 원리: 도구막대와 유한 크기 캔버스를 조합하고 현재 도구의 사용 안내를 즉시 표시한다.
  Widget _buildCanvasWorkspace(
    double scale, {
    bool fullscreen = false,
    VoidCallback? refresh,
  }) {
    return Column(
      children: [
        _buildCanvasToolbar(scale, fullscreen: fullscreen, refresh: refresh),
        if (_canvasNotice != null) ...[
          SizedBox(height: 8 * scale),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _canvasNotice!,
              style: const TextStyle(color: Color(0xFF64746A), fontSize: 12),
            ),
          ),
        ],
        SizedBox(height: 10 * scale),
        Expanded(child: _buildCanvasViewport(refresh)),
      ],
    );
  }

  /// 필요 변수: 현재 도구 [_canvasTool], 노드 유형 목록, 캔버스 크기.
  /// 작동 원리: 추가·화면 이동·노드 편집·연결·해제를 서로 배타적인 동작으로 전환한다.
  Widget _buildCanvasToolbar(
    double scale, {
    required bool fullscreen,
    VoidCallback? refresh,
  }) {
    void selectTool(String tool, String notice) {
      setState(() {
        _canvasTool = tool;
        _edgeSourceId = null;
        _canvasNotice = notice;
      });
      refresh?.call();
    }

    return SizedBox(
      height: 48 * scale,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          PopupMenuButton<String>(
            tooltip: '노드 추가',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onSelected: (type) {
              _addLogicNode(type);
              refresh?.call();
            },
            itemBuilder: (context) => [
              for (final type in _nodeTypes)
                PopupMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(_nodeTypeIcon(type), color: _nodeTypeColor(type)),
                      const SizedBox(width: 10),
                      Text(_nodeTypeLabel(type)),
                    ],
                  ),
                ),
            ],
          ),
          _CanvasToolButton(
            tooltip: '화면 옮기기',
            icon: Icons.pan_tool_alt_rounded,
            selected: _canvasTool == 'pan',
            onPressed: () => selectTool('pan', '빈 화면을 드래그해 캔버스를 이동합니다.'),
          ),
          _CanvasToolButton(
            tooltip: '노드 편집 및 이동',
            icon: Icons.edit_rounded,
            selected: _canvasTool == 'edit',
            onPressed: () => selectTool('edit', '노드를 선택하거나 드래그해 위치를 옮깁니다.'),
          ),
          _CanvasToolButton(
            tooltip: '노드 연결',
            icon: Icons.link_rounded,
            selected: _canvasTool == 'link',
            onPressed: () => selectTool('link', '시작 노드와 대상 노드를 차례로 선택하세요.'),
          ),
          _CanvasToolButton(
            tooltip: '노드 연결 해제',
            icon: Icons.link_off_rounded,
            selected: _canvasTool == 'unlink',
            onPressed: () => selectTool('unlink', '연결된 두 노드를 시작점부터 차례로 선택하세요.'),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: '캔버스 확장',
            onPressed: _canvasSize.width >= 5200 && _canvasSize.height >= 3600
                ? null
                : () {
                    setState(() {
                      _canvasSize = Size(
                        math.min(5200, _canvasSize.width + 600),
                        math.min(3600, _canvasSize.height + 400),
                      );
                      _canvasNotice =
                          '캔버스를 ${_canvasSize.width.round()} × ${_canvasSize.height.round()}로 확장했습니다.';
                    });
                    refresh?.call();
                  },
            icon: const Icon(Icons.expand_rounded),
          ),
          if (!fullscreen)
            IconButton(
              tooltip: '캔버스 전체화면',
              onPressed: _showFullscreenCanvas,
              icon: const Icon(Icons.fullscreen_rounded),
            ),
          const SizedBox(width: 8),
          Text(
            '${_canvasSize.width.round()} × ${_canvasSize.height.round()}',
            style: const TextStyle(color: Color(0xFF64746A), fontSize: 11),
          ),
          IconButton(
            tooltip: '캔버스 초기화',
            onPressed: () {
              setState(() {
                _canvasSize = const Size(1600, 1000);
                _resetAdvancedNodes();
                _canvasNotice = '기본 풀이 흐름으로 초기화했습니다.';
              });
              refresh?.call();
            },
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
    );
  }

  /// 필요 변수: 유한 캔버스 크기 [_canvasSize], 노드 좌표, 현재 도구.
  /// 작동 원리: 손 도구일 때만 화면을 이동하고 연필 도구일 때만 노드 좌표를 변경한다.
  Widget _buildCanvasViewport([VoidCallback? refresh]) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F8),
          border: Border.all(color: const Color(0xFFE3E3E7)),
        ),
        child: InteractiveViewer(
          constrained: false,
          boundaryMargin: const EdgeInsets.all(120),
          minScale: 0.25,
          maxScale: 2.5,
          panEnabled: _canvasTool == 'pan',
          child: SizedBox(
            width: _canvasSize.width,
            height: _canvasSize.height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LogicEdgePainter(nodes: _logicNodes),
                  ),
                ),
                for (final node in _logicNodes)
                  Positioned(
                    left: node.position.dx,
                    top: node.position.dy,
                    child: GestureDetector(
                      onTap: _canvasTool == 'pan'
                          ? null
                          : () => _handleCanvasNodeTap(node, refresh),
                      onPanUpdate: _canvasTool != 'edit'
                          ? null
                          : (details) {
                              setState(() {
                                final next = node.position + details.delta;
                                node.position = Offset(
                                  next.dx.clamp(8, _canvasSize.width - 190),
                                  next.dy.clamp(8, _canvasSize.height - 108),
                                );
                              });
                              refresh?.call();
                            },
                      child: _LogicNodeCard(
                        node: node,
                        selected: node.id == _selectedNodeId,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 필요 변수: 현재 노드와 캔버스 상태.
  /// 작동 원리: 독립 풀페이스 라우트에서도 동일 노드 객체를 편집해 일반 화면과 결과를 즉시 공유한다.
  Future<void> _showFullscreenCanvas() async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        fullscreenDialog: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (dialogContext, animation, secondaryAnimation) =>
            StatefulBuilder(
              builder: (context, refresh) => Scaffold(
                appBar: AppBar(
                  title: const Text('풀이 논리 캔버스'),
                  leading: IconButton(
                    tooltip: '전체화면 닫기',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildCanvasWorkspace(
                    1,
                    fullscreen: true,
                    refresh: () => refresh(() {}),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildRightPanel(double scale) {
    return _StudioPanel(
      title: _editorMode == 'advanced' ? '고급 설정' : '문제 저장소',
      child: DefaultTabController(
        length: _editorMode == 'advanced' ? 4 : 2,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              labelColor: kCourseGreen,
              tabs: [
                if (_editorMode == 'advanced') const Tab(text: '파라미터'),
                if (_editorMode == 'advanced') const Tab(text: '노드'),
                const Tab(text: '저장소'),
                const Tab(text: '임시저장함'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  if (_editorMode == 'advanced') _buildParameterPanel(scale),
                  if (_editorMode == 'advanced') _buildNodeEditor(scale),
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
        _SelectedQuestBox(
          quest: _selectedDbQuest ?? const {'quest_id': '참고문항 없음'},
          onClear: _selectedDbQuest == null
              ? () {}
              : () {
                  setState(() {
                    _selectedDbQuest = null;
                    _baseQuestCtrl.clear();
                  });
                },
        ),
        SizedBox(height: 8 * scale),
        const _MutedText('참고문항은 저장소 탭에서 검색해 연결합니다. 선택하지 않아도 직접 생성할 수 있습니다.'),
        if (_resultText != null) ...[
          SizedBox(height: 12 * scale),
          _DocBlock(title: '최근 생성 결과', body: _resultText!),
        ],
        const Divider(height: 28),
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
          onChanged: (value) {
            setState(() {
              node.type = value ?? node.type;
              final maxOutgoing = _nodeMaxOutgoing(node.type);
              if (node.nextIds.length > maxOutgoing) {
                final keptIds = node.nextIds.take(maxOutgoing).toList();
                node.nextIds
                  ..clear()
                  ..addAll(keptIds);
              }
              _canvasNotice = '${_nodeTypeLabel(node.type)} 노드 규칙을 적용했습니다.';
            });
          },
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
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _availableTags.isEmpty
                    ? null
                    : () async {
                        final selected = await _openTagPicker(node.tags);
                        if (selected == null) return;
                        setState(() {
                          node.tags
                            ..clear()
                            ..addAll(selected);
                        });
                      },
                icon: const Icon(Icons.checklist_rounded),
                label: const Text('노드 태그 선택'),
              ),
            ),
          ],
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
        SizedBox(height: 10 * scale),
        _DocBlock(
          title: '노드 생성 지시',
          body: node.teacherInstructionCtrl.text.trim().isEmpty
              ? _defaultNodePrompt(node.type)
              : node.teacherInstructionCtrl.text.trim(),
        ),
        OutlinedButton.icon(
          onPressed: () => _editNodeInstruction(node),
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('세부 지시 추가'),
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
                  final reason = _connectionBlockReason(node, target);
                  if (reason == null) {
                    node.nextIds.add(target.id);
                    _canvasNotice =
                        '${node.titleCtrl.text.trim()} → ${target.titleCtrl.text.trim()} 연결 완료';
                  } else {
                    _canvasNotice = reason;
                  }
                } else {
                  node.nextIds.remove(target.id);
                  _canvasNotice =
                      '${node.titleCtrl.text.trim()} → ${target.titleCtrl.text.trim()} 연결 해제';
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

  /// 필요 변수: 현재 화면의 [context], 노드 유형과 고급 파라미터 설명.
  /// 작동 원리: 상단 설명서 버튼을 누르면 폴더별 문서를 탐색하는 풀페이스 라우트를 연다.
  Future<void> _showDocumentation() async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        fullscreenDialog: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (dialogContext, animation, secondaryAnimation) => Scaffold(
          backgroundColor: kCourseBgGrey,
          body: SafeArea(
            child: _GenerationDocumentationExplorer(
              files: _buildDocumentationFiles(),
              onClose: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ),
      ),
    );
  }

  /// 필요 변수: 노드 목록 [_nodeTypes], 파라미터 목록 [_advancedParameterSpecs].
  /// 작동 원리: 개요·도구·노드·파라미터·실전 예시를 파일관리자에서 선택 가능한 문서로 변환한다.
  List<_GenerationDocFile> _buildDocumentationFiles() {
    return [
      const _GenerationDocFile(
        id: 'overview',
        folder: '시작하기',
        title: '고급 문제 생성 개요',
        icon: Icons.rocket_launch_rounded,
        summary: '풀이 그래프와 세부 파라미터를 함께 사용해 문제의 구조와 난이도를 설계합니다.',
        details:
            '풀이 단계 수는 풀이의 길이, 전략 난이도는 핵심 발상의 강도, 분기 수는 케이스 분류와 병합 규모입니다. '
            '예를 들어 하 난이도는 2/1/0, 상 난이도는 6/3/2로 기존 생성 파이프라인에 전달됩니다.',
        examples: [
          '3점형: 조건 → 개념 → 계산 → 검증',
          '30번형: 조건 → 발상/추론 분기 → 병합 → 계산 → 검증',
        ],
      ),
      const _GenerationDocFile(
        id: 'toolbar',
        folder: '시작하기',
        title: '캔버스 도구막대',
        icon: Icons.build_circle_outlined,
        summary: '화면 이동과 노드 이동을 별도 도구로 전환해 오작동을 막습니다.',
        details:
            '더하기는 8개 유형의 노드를 추가합니다. 손은 캔버스 화면을 이동하고, 연필은 노드를 선택하거나 위치를 옮깁니다. '
            '링크와 링크 해제는 시작 노드와 대상 노드를 차례로 선택합니다. 확장은 최대 5200×3600까지 가능하며 전체화면에서도 같은 상태를 편집합니다.',
        examples: [
          '멀리 있는 노드 보기: 손 도구 → 빈 화면 드래그',
          '노드 위치 정리: 연필 도구 → 노드 드래그',
          '관계 만들기: 링크 → 시작 노드 → 대상 노드',
        ],
      ),
      const _GenerationDocFile(
        id: 'connection_rules',
        folder: '시작하기',
        title: '연결 규칙',
        icon: Icons.account_tree_rounded,
        summary: '연결은 방향성을 가지며 순환하지 않는 풀이 그래프로 관리합니다.',
        details:
            '같은 노드 연결, 중복 연결, 순환 연결은 차단됩니다. 검증 노드는 마지막 단계이므로 다음 연결이 없고, '
            '병합 노드는 앞선 연결이 2개 이상이어야 하며 다음 연결은 1개만 허용합니다. 생성 전에는 고립 노드와 검증 노드 존재 여부를 검사합니다.',
        examples: [
          '조건에서 풀이가 갈라질 때 조건 → 추론 A, 조건 → 추론 B로 연결합니다.',
          '두 풀이가 같은 결론에 도달하면 추론 A/B → 병합 → 검증으로 연결합니다.',
          '실제 연관이 없으면 링크 해제로 해당 직접 연결만 제거합니다.',
        ],
      ),
      for (final type in _nodeTypes)
        _GenerationDocFile(
          id: 'node_$type',
          folder: '노드 8종',
          title: '${_nodeTypeLabel(type)} 노드',
          icon: _nodeTypeIcon(type),
          summary: _defaultNodeDetail(type),
          details: _defaultNodePrompt(type),
          examples: _nodeDocumentationExamples(type),
        ),
      for (final spec in _advancedParameterSpecs)
        _GenerationDocFile(
          id: 'parameter_${spec.id}',
          folder: '파라미터',
          title: spec.label,
          icon: Icons.tune_rounded,
          summary:
              '${spec.description} · 범위 ${spec.min.round()}~${spec.max.round()}',
          details: spec.description,
          examples: ['낮은 값: ${spec.lowExample}', '높은 값: ${spec.highExample}'],
        ),
      const _GenerationDocFile(
        id: 'example_branch_merge',
        folder: '실전 예시',
        title: '조건 분기와 병합',
        icon: Icons.call_merge_rounded,
        summary: '조건 또는 생각의 흐름이 갈라졌다가 다시 하나의 결론으로 모이는 구성입니다.',
        details:
            '조건 노드에서 두 개의 추론 노드로 링크를 만들고, 각 추론을 같은 병합 노드로 연결합니다. '
            '병합 이후 계산과 검증을 연결하면 분기별 근거와 공통 결론이 모두 생성 지시에 반영됩니다.',
        examples: [
          '조건 → (양수인 경우 / 음수인 경우) → 병합 → 계산 → 검증',
          '발상 → (그래프 해석 / 대수 해석) → 병합 → 검증',
        ],
      ),
      const _GenerationDocFile(
        id: 'example_target',
        folder: '실전 예시',
        title: '목표 난이도 시작값',
        icon: Icons.track_changes_rounded,
        summary: '프리셋은 시작값이며 노드 구조와 파라미터를 함께 조정해야 의도가 선명해집니다.',
        details:
            '3점형은 짧고 직접적인 단일 흐름, 22·29번형은 발상과 추론 중심의 분기, 30번형은 깊은 그래프와 병합·검증을 권장합니다.',
        examples: [
          '3점형: 풀이 2 / 전략 1 / 분기 0',
          '일반 4점형: 풀이 4 / 전략 2 / 분기 1',
          '30번형: 풀이 7 이상 / 전략 3 / 분기 2 이상',
        ],
      ),
    ];
  }

  /// 필요 변수: 문서 정보 [document], 현재 검색 모드와 검색어.
  /// 작동 원리: 문서함 파일의 제목·분류·태그 또는 저장일을 기준으로 화면 트리만 가볍게 필터링한다.
  bool _matchesDocumentFilter(Map<String, dynamic> document) {
    final query = _dbSearchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    if (_dbSearchMode == 'date') {
      final date = [
        document['updated_at'],
        document['created_at'],
        document['document_updated_at'],
      ].whereType<Object>().map((value) => value.toString()).join(' ');
      return date.contains(query);
    }
    final values = _dbSearchMode == 'hashtag'
        ? <dynamic>[document['tags'], document['hash_tags']]
        : <dynamic>[
            document['title'],
            document['subtitle'],
            document['category'],
            document['textbook_id'],
            document['exam_id'],
          ];
    return values
        .map((value) => value?.toString() ?? '')
        .join(' ')
        .toLowerCase()
        .contains(query);
  }

  /// 필요 변수: 현재 검색 모드 [_dbSearchMode], 검색어 [_dbSearchCtrl].
  /// 작동 원리: 풀페이스 필터에서 조건을 확정한 경우에만 문서함 트리를 다시 조회한다.
  Future<void> _openProblemDbFilter() async {
    final filter = await Navigator.of(context).push<_ProblemDbFilter>(
      MaterialPageRoute<_ProblemDbFilter>(
        fullscreenDialog: true,
        builder: (_) => _ProblemDbFilterDialog(
          initialMode: _dbSearchMode,
          initialQuery: _dbSearchCtrl.text,
        ),
      ),
    );
    if (filter == null || !mounted) return;
    setState(() {
      _dbSearchMode = filter.mode;
      _dbSearchCtrl.text = filter.query;
    });
    await _searchProblemDb();
  }

  /// 필요 변수: 화면 배율 [scale], 교사 문서함 자료와 선택 참고문항.
  /// 작동 원리: 문서함 자료를 교재·시험지·문항 폴더로 묶어 파일 관리자 형태로 표시한다.
  Widget _buildProblemDbPanel(double scale) {
    final textbooks = _teacherTextbooks.where(_matchesDocumentFilter).toList();
    final exams = _teacherExams.where(_matchesDocumentFilter).toList();
    final query = _dbSearchCtrl.text.trim();
    final filterLabel = query.isEmpty
        ? '전체 자료'
        : '${_problemDbModeLabel(_dbSearchMode)} · $query';

    return ListView(
      padding: EdgeInsets.all(14 * scale),
      children: [
        const _DocBlock(
          title: '교사 보유 자료',
          body: '현재 로그인한 교사의 문서함 파일 트리입니다. 문항 파일을 선택하면 참고문항으로 연결됩니다.',
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F8),
            border: Border.all(color: AppColors.surfaceBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.filter_list_rounded, color: kCourseGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  filterLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: _dbSearching ? null : _openProblemDbFilter,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('검색 조건'),
              ),
            ],
          ),
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
        SizedBox(height: 10 * scale),
        if (_dbSearching)
          const LinearProgressIndicator()
        else if (_dbError != null)
          Text(_dbError!, style: const TextStyle(color: Colors.red))
        else ...[
          _DocumentTreeFolder(
            label: '문항',
            icon: Icons.quiz_outlined,
            itemCount: _dbResults.length,
            initiallyExpanded: true,
            emptyText: '조건에 맞는 보유 문항이 없습니다.',
            children: [
              for (final item in _dbResults)
                _DbQuestRow(
                  item: item,
                  selected: item['quest_id'] == _selectedDbQuest?['quest_id'],
                  onTap: () => _selectDbQuest(item),
                  contentToText: _contentToText,
                ),
            ],
          ),
          _DocumentTreeFolder(
            label: '교재',
            icon: Icons.menu_book_outlined,
            itemCount: textbooks.length,
            emptyText: '조건에 맞는 교재가 없습니다.',
            children: [
              for (final item in textbooks)
                _DocumentFileRow(item: item, type: 'textbook'),
            ],
          ),
          _DocumentTreeFolder(
            label: '시험지',
            icon: Icons.description_outlined,
            itemCount: exams.length,
            emptyText: '조건에 맞는 시험지가 없습니다.',
            children: [
              for (final item in exams)
                _DocumentFileRow(item: item, type: 'exam'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTrayPanel(double scale) {
    return ListView(
      padding: EdgeInsets.all(14 * scale),
      children: [
        if (_tray.isEmpty)
          const _MutedText('임시저장함이 비어 있습니다.')
        else
          for (final item in _tray) _TrayItemCard(item: item),
      ],
    );
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _baseQuestCtrl.dispose();
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
    required this.teacherInstructionCtrl,
  });

  final String id;
  String type;
  Offset position;
  final TextEditingController titleCtrl;
  final TextEditingController detailCtrl;
  final TextEditingController teacherInstructionCtrl;
  final Set<String> tags = {};
  final Set<String> nextIds = {};

  Offset get center => position + const Offset(90, 48);

  void dispose() {
    titleCtrl.dispose();
    detailCtrl.dispose();
    teacherInstructionCtrl.dispose();
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

class _GenerationTagGroup {
  const _GenerationTagGroup({required this.label, required this.tags});

  factory _GenerationTagGroup.fromJson(Map<String, dynamic> json) {
    final label = json['label']?.toString().trim();
    final name = json['name']?.toString().trim();
    final tags = (json['tags'] as List<dynamic>? ?? const [])
        .map((item) => item.toString().trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    return _GenerationTagGroup(
      label: label == null || label.isEmpty ? name ?? '태그' : label,
      tags: _uniqueTags(tags),
    );
  }

  final String label;
  final List<String> tags;
}

class _GenerationTagPickerDialog extends StatefulWidget {
  const _GenerationTagPickerDialog({
    required this.groups,
    required this.fallbackTags,
    required this.initialTags,
  });

  final List<_GenerationTagGroup> groups;
  final List<String> fallbackTags;
  final Iterable<String> initialTags;

  @override
  State<_GenerationTagPickerDialog> createState() =>
      _GenerationTagPickerDialogState();
}

class _GenerationTagPickerDialogState
    extends State<_GenerationTagPickerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  late final Set<String> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.initialTags.map((tag) => tag.trim()).toSet();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_GenerationTagGroup> get _groups {
    if (widget.groups.isNotEmpty) return widget.groups;
    return [_GenerationTagGroup(label: '생성 태그', tags: widget.fallbackTags)];
  }

  bool _matches(String tag) {
    if (_query.trim().isEmpty) return true;
    return tag.toLowerCase().contains(_query.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return TeacherFullFacePanel(
      eyebrow: 'PROBLEM STUDIO',
      title: '해시태그 선택',
      description: '문항 생성 또는 선택한 논리 노드에 사용할 태그를 검색합니다.',
      maxContentWidth: 820,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_uniqueTags(_selected.toList())),
          child: Text('${_selected.length}개 선택 완료'),
        ),
      ],
      content: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: '태그 검색',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          if (_selected.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selected
                    .map(
                      (tag) => Chip(
                        label: Text(tag),
                        onDeleted: () => setState(() => _selected.remove(tag)),
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                for (final group in _groups)
                  _TagGroupTile(
                    group: group,
                    selected: _selected,
                    matches: _matches,
                    onChanged: () => setState(() {}),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagGroupTile extends StatelessWidget {
  const _TagGroupTile({
    required this.group,
    required this.selected,
    required this.matches,
    required this.onChanged,
  });

  final _GenerationTagGroup group;
  final Set<String> selected;
  final bool Function(String tag) matches;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final visibleTags = group.tags.where(matches).toList();
    if (visibleTags.isEmpty) return const SizedBox.shrink();
    final selectedCount = visibleTags.where(selected.contains).length;
    final groupValue = selectedCount == 0
        ? false
        : selectedCount == visibleTags.length
        ? true
        : null;
    return ExpansionTile(
      initiallyExpanded: true,
      title: Text(group.label),
      leading: Checkbox(
        tristate: true,
        value: groupValue,
        onChanged: (value) {
          if (value == true) {
            selected.addAll(visibleTags);
          } else {
            selected.removeAll(visibleTags);
          }
          onChanged();
        },
      ),
      children: [
        for (final tag in visibleTags)
          CheckboxListTile(
            dense: true,
            value: selected.contains(tag),
            title: Text(tag),
            onChanged: (value) {
              if (value == true) {
                selected.add(tag);
              } else {
                selected.remove(tag);
              }
              onChanged();
            },
          ),
      ],
    );
  }
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
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceBorder),
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
    final color = active ? kCourseGreen : const Color(0xFF71717A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF0F0F2) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? kCourseGreen : const Color(0xFFE3E3E7),
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
        border: Border.all(color: AppColors.surfaceBorder),
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
          color: selected ? const Color(0xFFF0F0F2) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? kCourseGreen : AppColors.surfaceBorder,
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
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceBorder),
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
          color: selected ? color : const Color(0xFFE3E3E7),
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

class _CanvasToolButton extends StatelessWidget {
  const _CanvasToolButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  /// 필요 변수: 도구 이름 [tooltip], 아이콘 [icon], 선택 상태 [selected].
  /// 작동 원리: 현재 도구만 강조해 화면 이동과 노드 편집 동작을 시각적으로 구분한다.
  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: selected ? const Color(0xFFE4E4E7) : null,
        foregroundColor: selected ? kCourseGreen : const Color(0xFF64746A),
      ),
      icon: Icon(icon),
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
      ..color = const Color(0xFF71717A)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final arrowPaint = Paint()
      ..color = const Color(0xFF71717A)
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

class _GenerationDocFile {
  const _GenerationDocFile({
    required this.id,
    required this.folder,
    required this.title,
    required this.icon,
    required this.summary,
    required this.details,
    required this.examples,
  });

  final String id;
  final String folder;
  final String title;
  final IconData icon;
  final String summary;
  final String details;
  final List<String> examples;

  String toMarkdown() {
    final exampleText = examples.map((item) => '- $item').join('\n');
    return '# $title\n\n$summary\n\n## 상세 설명\n\n$details\n\n## 예시\n\n$exampleText';
  }
}

class _GenerationDocumentationExplorer extends StatefulWidget {
  const _GenerationDocumentationExplorer({
    required this.files,
    required this.onClose,
  });

  final List<_GenerationDocFile> files;
  final VoidCallback onClose;

  @override
  State<_GenerationDocumentationExplorer> createState() =>
      _GenerationDocumentationExplorerState();
}

class _GenerationDocumentationExplorerState
    extends State<_GenerationDocumentationExplorer> {
  final TextEditingController _searchCtrl = TextEditingController();
  late String _selectedId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedId = widget.files.first.id;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  _GenerationDocFile get _selectedFile => widget.files.firstWhere(
    (file) => file.id == _selectedId,
    orElse: () => widget.files.first,
  );

  List<_GenerationDocFile> get _visibleFiles {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.files;
    return widget.files
        .where(
          (file) => [
            file.folder,
            file.title,
            file.summary,
            file.details,
            ...file.examples,
          ].join(' ').toLowerCase().contains(query),
        )
        .toList();
  }

  /// 필요 변수: 검색 결과 [_visibleFiles]와 선택 문서 [_selectedId].
  /// 작동 원리: 폴더 트리와 단일 문서 상세창을 반응형 2단 구조로 배치한다.
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.surfaceBorder)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: kCourseGreen),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '문제 생성 설명서',
                  style: TextStyle(
                    color: kCourseGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: '설명서 닫기',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tree = _buildFileTree();
              final details = _buildDocumentDetails(context);
              if (constraints.maxWidth < 720) {
                return Column(
                  children: [
                    SizedBox(height: 260, child: tree),
                    const Divider(height: 1),
                    Expanded(child: details),
                  ],
                );
              }
              return Row(
                children: [
                  SizedBox(width: 310, child: tree),
                  const VerticalDivider(width: 1),
                  Expanded(child: details),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// 필요 변수: 검색어 [_query], 설명서 파일 목록 [widget.files].
  /// 작동 원리: 같은 폴더의 파일을 묶고 검색 결과에 포함된 문서만 탐색 트리에 표시한다.
  Widget _buildFileTree() {
    final groups = <String, List<_GenerationDocFile>>{};
    for (final file in _visibleFiles) {
      groups.putIfAbsent(file.folder, () => []).add(file);
    }
    return Material(
      color: const Color(0xFFF7F7F8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: '설명서 검색',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: groups.isEmpty
                ? const Center(child: Text('검색 결과가 없습니다.'))
                : ListView(
                    children: [
                      for (final entry in groups.entries)
                        ExpansionTile(
                          initiallyExpanded: true,
                          leading: const Icon(
                            Icons.folder_open_rounded,
                            color: kCourseGreen,
                          ),
                          title: Text(
                            '${entry.key} (${entry.value.length})',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          children: [
                            for (final file in entry.value)
                              ListTile(
                                dense: true,
                                selected: file.id == _selectedId,
                                selectedTileColor: const Color(0xFFE4E4E7),
                                leading: Icon(file.icon, size: 19),
                                title: Text(file.title),
                                onTap: () =>
                                    setState(() => _selectedId = file.id),
                              ),
                          ],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// 필요 변수: 현재 선택 문서 [_selectedFile].
  /// 작동 원리: 한 번에 한 문서의 설명과 예시만 표시하고 Markdown 형태로 복사할 수 있게 한다.
  Widget _buildDocumentDetails(BuildContext context) {
    final file = _selectedFile;
    return ListView(
      key: ValueKey(file.id),
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE4E4E7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(file.icon, color: kCourseGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.folder,
                    style: const TextStyle(color: Color(0xFF64746A)),
                  ),
                  Text(
                    file.title,
                    style: const TextStyle(
                      color: kCourseGreen,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '현재 문서 복사',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: file.toMarkdown()));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('현재 설명서를 Markdown으로 복사했습니다.')),
                );
              },
              icon: const Icon(Icons.copy_all_rounded),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SelectableText(
          file.summary,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        const Divider(height: 36),
        const Text(
          '상세 설명',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        SelectableText(file.details, style: const TextStyle(height: 1.65)),
        const SizedBox(height: 24),
        const Text(
          '예시',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < file.examples.length; index++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE3E3E7)),
            ),
            child: SelectableText('${index + 1}. ${file.examples[index]}'),
          ),
      ],
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
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3E3E7)),
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

/// 필요 변수: 검색 모드 [mode].
/// 작동 원리: 내부 검색 모드 코드를 필터 라인에 표시할 한국어로 변환한다.
String _problemDbModeLabel(String mode) {
  return switch (mode) {
    'hashtag' => '해시태그',
    'date' => '날짜',
    _ => '텍스트',
  };
}

class _ProblemDbFilter {
  const _ProblemDbFilter({required this.mode, required this.query});

  final String mode;
  final String query;
}

class _ProblemDbFilterDialog extends StatefulWidget {
  const _ProblemDbFilterDialog({
    required this.initialMode,
    required this.initialQuery,
  });

  final String initialMode;
  final String initialQuery;

  @override
  State<_ProblemDbFilterDialog> createState() => _ProblemDbFilterDialogState();
}

class _ProblemDbFilterDialogState extends State<_ProblemDbFilterDialog> {
  late final TextEditingController _controller;
  late String _mode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 필요 변수: 검색 모드 [_mode], 검색어 컨트롤러 [_controller].
  /// 작동 원리: 풀페이스 작업면 안에서 조건을 편집하고 적용할 때 부모 화면으로 값을 반환한다.
  @override
  Widget build(BuildContext context) {
    final hint = switch (_mode) {
      'hashtag' => '예: #미분',
      'date' => '예: 2026-07-04',
      _ => '문제 본문, 문서명, 폴더명',
    };
    return TeacherFullFacePanel(
      eyebrow: 'PROBLEM STUDIO',
      title: '문서함 검색 필터',
      description: '문제 본문, 태그, 날짜 기준으로 교사 문서함을 다시 조회합니다.',
      maxContentWidth: 680,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(const _ProblemDbFilter(mode: 'text', query: '')),
          child: const Text('초기화'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(
            context,
          ).pop(_ProblemDbFilter(mode: _mode, query: _controller.text.trim())),
          icon: const Icon(Icons.search_rounded),
          label: const Text('적용'),
        ),
      ],
      content: Align(
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'text', label: Text('텍스트')),
                ButtonSegment(value: 'hashtag', label: Text('해시태그')),
                ButtonSegment(value: 'date', label: Text('날짜')),
              ],
              selected: {_mode},
              onSelectionChanged: (values) =>
                  setState(() => _mode = values.first),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '검색어',
                hintText: hint,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => Navigator.of(context).pop(
                _ProblemDbFilter(mode: _mode, query: _controller.text.trim()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentTreeFolder extends StatelessWidget {
  const _DocumentTreeFolder({
    required this.label,
    required this.icon,
    required this.itemCount,
    required this.emptyText,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String label;
  final IconData icon;
  final int itemCount;
  final String emptyText;
  final List<Widget> children;
  final bool initiallyExpanded;

  /// 필요 변수: 폴더명 [label], 파일 수 [itemCount], 하위 파일 [children].
  /// 작동 원리: 문서 종류별 폴더를 접고 펼칠 수 있는 파일 트리 한 단계로 렌더링한다.
  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      childrenPadding: const EdgeInsets.only(left: 12),
      leading: Icon(icon, color: kCourseGreen),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$itemCount', style: const TextStyle(color: Color(0xFF64746A))),
          const SizedBox(width: 6),
          const Icon(Icons.expand_more_rounded),
        ],
      ),
      children: children.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: _MutedText(emptyText),
              ),
            ]
          : children,
    );
  }
}

class _DocumentFileRow extends StatelessWidget {
  const _DocumentFileRow({required this.item, required this.type});

  final Map<String, dynamic> item;
  final String type;

  /// 필요 변수: 문서 정보 [item], 문서 종류 [type].
  /// 작동 원리: 교재와 시험지를 선택 불가능한 문서함 파일 행으로 표시한다.
  @override
  Widget build(BuildContext context) {
    final title = item['title']?.toString().trim();
    final fallbackId = type == 'exam' ? item['exam_id'] : item['textbook_id'];
    final fileName = title == null || title.isEmpty
        ? fallbackId?.toString() ?? '이름 없는 파일'
        : title;
    final tags = item['tags'] is List
        ? (item['tags'] as List).map((tag) => tag.toString()).join(', ')
        : '';
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(
        type == 'exam' ? Icons.description_outlined : Icons.menu_book_outlined,
        color: const Color(0xFF64746A),
      ),
      title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: tags.isEmpty
          ? null
          : Text(tags, maxLines: 1, overflow: TextOverflow.ellipsis),
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
        color: const Color(0xFFF0F0F2),
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
          if ((quest['quest_id']?.toString() ?? '') != '참고문항 없음')
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
            ),
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
    final createdAt =
        item['updated_at']?.toString() ?? item['created_at']?.toString() ?? '';
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
        border: Border.all(color: const Color(0xFFE3E3E7)),
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
          color: selected ? const Color(0xFFF0F0F2) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? kCourseGreen : AppColors.surfaceBorder,
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
  'merge',
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
    case 'merge':
      return '병합';
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
    case 'merge':
      return '둘 이상의 분기 결과에서 공통 결론을 찾아 하나의 풀이 흐름으로 병합한다.';
    case 'verification':
      return '정답 유일성과 조건 모순 여부를 검증한다.';
    default:
      return '';
  }
}

String _defaultNodePrompt(String type) {
  switch (type) {
    case 'condition':
      return '문제 조건을 명시 조건과 암묵 제약으로 나누고, 풀이에 필요한 형태로 정리한다.';
    case 'concept':
      return '선택 태그에 맞는 교과 개념을 정확히 사용하고 교육과정 밖 도구는 쓰지 않는다.';
    case 'insight':
      return '풀이를 여는 핵심 발상을 하나 이상 만들고, 우연한 계산보다 구조 인식이 드러나게 한다.';
    case 'reasoning':
      return '이전 조건에서 다음 결론으로 이어지는 논리 경로를 끊기지 않게 구성한다.';
    case 'computation':
      return '계산은 검산 가능한 수준으로 유지하고 불필요한 전개를 줄인다.';
    case 'trap':
      return '정의역, 부호, 필요충분 조건 중 하나의 자연스러운 오답 유발 요소를 포함한다.';
    case 'merge':
      return '앞선 두 개 이상의 분기에서 공통으로 성립하는 결론을 명시하고 이후 흐름을 하나로 합친다.';
    case 'verification':
      return '정답 유일성, 조건 모순 여부, 풀이 가능성을 마지막 단계에서 확인한다.';
    default:
      return '문제 생성 논리에 맞는 보편적인 풀이 단계를 구성한다.';
  }
}

/// 필요 변수: 노드 역할 [type].
/// 작동 원리: 설명서에서 바로 따라 할 수 있는 역할별 연결·작성 예시를 반환한다.
List<String> _nodeDocumentationExamples(String type) {
  switch (type) {
    case 'condition':
      return ['f(x)가 모든 실수에서 미분 가능하다는 명시 조건과 연속성이라는 암묵 조건을 분리합니다.'];
    case 'concept':
      return ['미분계수의 정의, 극값 조건처럼 풀이에 실제 사용할 교과 개념만 지정합니다.'];
    case 'insight':
      return ['정답에서 조건을 역추적하거나 그래프의 대칭성을 먼저 찾도록 지시합니다.'];
    case 'reasoning':
      return ['조건에서 보조식으로, 보조식에서 계수 결정으로 이어지는 근거를 단계별로 적습니다.'];
    case 'computation':
      return ['다항식 전개 2회와 계수 비교 1회처럼 허용할 계산량을 구체적으로 제한합니다.'];
    case 'trap':
      return ['제곱 후 생기는 불필요한 해나 정의역 누락을 자연스러운 오답 갈래로 설계합니다.'];
    case 'merge':
      return ['부호에 따른 두 경우가 모두 같은 계수 조건에 도달하도록 두 연결을 병합합니다.'];
    case 'verification':
      return ['후보 답을 원래 조건에 대입해 유일성·정의역·교육과정 범위를 마지막에 확인합니다.'];
    default:
      return const ['노드의 역할과 다음 노드로 이어지는 근거를 구체적으로 작성합니다.'];
  }
}

List<String> _uniqueTags(Iterable<String> tags) {
  final seen = <String>{};
  final results = <String>[];
  for (final tag in tags) {
    final value = tag.trim();
    if (value.isEmpty || seen.contains(value)) continue;
    seen.add(value);
    results.add(value);
  }
  return results;
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
    case 'merge':
      return Icons.call_merge_rounded;
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
    case 'merge':
      return const Color(0xFF137C8B);
    case 'verification':
      return kCourseGreen;
    default:
      return kCourseGreen;
  }
}

/// 필요 변수: 노드 역할 [type].
/// 작동 원리: 기능별 의미가 흐려지지 않도록 허용 가능한 최대 다음 연결 수를 반환한다.
int _nodeMaxOutgoing(String type) {
  switch (type) {
    case 'verification':
      return 0;
    case 'merge':
      return 1;
    case 'computation':
    case 'trap':
      return 2;
    case 'condition':
    case 'concept':
    case 'insight':
    case 'reasoning':
      return 4;
    default:
      return 1;
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
