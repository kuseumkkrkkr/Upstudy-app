import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_example_catalog.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_expression.dart';
import 'package:s11/sessions/graph_tools/ui/widgets/jsx_graph_embed.dart';
import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';

const _kGreen = Color(0xFF202022);
const _kBorder = Color(0xFFE1E1E4);
const _kMuted = Color(0xFF77777D);
const _kSurface = Colors.white;
const _kSurfaceTint = Color(0xFFF5F5F7);
const _kPalette = <Color>[
  Color(0xFF2F7CF6),
  Color(0xFFDD5F34),
  Color(0xFF238B5E),
  Color(0xFF8A52E8),
  Color(0xFFD6477C),
  Color(0xFF927A1F),
];

typedef GraphSampleRequest =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload);

enum _GraphTrayState { collapsed, compact, expanded }

class JsxGraphPage extends StatefulWidget {
  const JsxGraphPage({super.key, this.embedEnabled = true, this.sampleGraph});

  final bool embedEnabled;
  final GraphSampleRequest? sampleGraph;

  @override
  State<JsxGraphPage> createState() => _JsxGraphPageState();
}

class _JsxGraphPageState extends State<JsxGraphPage> {
  final List<_GraphItemDraft> _drafts = <_GraphItemDraft>[];
  final List<_GraphParameterDraft> _parameters = <_GraphParameterDraft>[];
  final List<AiFlowGraphItem> _sampledItems = <AiFlowGraphItem>[];
  final TextEditingController _beginnerA = TextEditingController(text: '1');
  final TextEditingController _beginnerB = TextEditingController(text: '0');
  final TextEditingController _beginnerC = TextEditingController(text: '0');

  late AiFlowGraphExample _selectedExample;
  int _nextDraftId = 0;
  bool _showAxes = true;
  bool _showGrid = true;
  bool _lockViewport = false;
  bool _degreeMode = false;
  bool _catalogDialogOpen = false;
  String? _editorMessage;
  bool _advancedMode = true;
  bool _sampling = false;
  int _beginnerType = 0;
  int? _activeMobileDraftId;
  Timer? _sampleDebounce;
  int _sampleRevision = 0;
  _GraphTrayState _mobileTrayState = _GraphTrayState.compact;
  String? _graphCommand;
  int _graphCommandRevision = 0;
  AiFlowGraphViewport? _viewport;
  final _workspaceKey = GlobalKey();
  final _exampleButtonFocus = FocusNode(debugLabel: 'Graph examples');

  @override
  void initState() {
    super.initState();
    _selectedExample = aiFlowGraphExamples.first;
    _startBlankGraph();
  }

  @override
  void dispose() {
    _sampleDebounce?.cancel();
    for (final draft in _drafts) {
      draft.dispose();
    }
    _beginnerA.dispose();
    _beginnerB.dispose();
    _beginnerC.dispose();
    _exampleButtonFocus.dispose();
    super.dispose();
  }

  /// 필요한 변수는 다음 수식 ID와 기본 그래프 설정이다.
  /// 작동 원리는 교과 예제를 자동 적용하지 않고 빈 함수식 하나만 만들어
  /// 사용자가 직접 그래프를 그리는 독립 작업 공간으로 시작하게 한다.
  void _startBlankGraph() {
    for (final draft in _drafts) {
      draft.dispose();
    }

    _selectedExample = aiFlowGraphExamples.first;
    final nextId = _nextDraftId++;
    _viewport = const AiFlowGraphViewport(left: -5, right: 5, top: 5, bottom: -5);
    _drafts
      ..clear()
      ..add(
        _GraphItemDraft(
          localId: nextId,
          itemId: 'custom-$nextId',
          type: AiFlowGraphItemType.function,
          label: '함수 1',
          colorHex: _colorToHex(_kPalette[nextId % _kPalette.length]),
          enabled: true,
          expressionController: TextEditingController(),
        ),
      );
    _activeMobileDraftId = nextId;
    _parameters.clear();
    _sampledItems.clear();
    _showAxes = true;
    _showGrid = true;
    _lockViewport = false;
    _degreeMode = false;
    _editorMessage = null;
  }

  /// 필요한 변수는 현재 그래프 초안과 빈 그래프 초기화 함수다.
  /// 작동 원리는 사용자가 새 그래프를 선택하면 기존 입력을 정리하고 빈 좌표평면으로 되돌린다.
  void _resetToBlankGraph() {
    setState(_startBlankGraph);
  }

  void _loadExample(AiFlowGraphExample example) {
    for (final draft in _drafts) {
      draft.dispose();
    }

    _drafts
      ..clear()
      ..addAll(
        example.document.items.map((item) {
          final nextId = _nextDraftId++;
          return _GraphItemDraft.fromItem(
            localId: nextId,
            item: item,
            fallbackColor: _kPalette[nextId % _kPalette.length],
          );
        }),
      );
    _activeMobileDraftId = _drafts.isEmpty ? null : _drafts.first.localId;
    _parameters
      ..clear()
      ..addAll(
        example.document.settings.parameters.map(
          _GraphParameterDraft.fromParameter,
        ),
      );
    _sampledItems.clear();

    _selectedExample = example;
    _viewport = example.document.settings.viewport;
    _showAxes = example.document.settings.showAxes;
    _showGrid = example.document.settings.showGrid;
    _lockViewport = example.document.settings.lockViewport;
    _degreeMode = example.document.settings.degreeMode;
    _editorMessage = null;
  }

  AiFlowGraphDocument _buildDocument() {
    return AiFlowGraphDocument(
      items: List<AiFlowGraphItem>.unmodifiable([
        ..._sampledItems.where((item) => _drafts.any((draft) => draft.enabled && item.id.startsWith('${draft.itemId}-'))),
        ..._drafts.where((draft) => draft.enabled && draft.type != AiFlowGraphItemType.function).map((draft) => draft.toItem()),
      ]),
      settings: _selectedExample.document.settings.copyWith(
        showAxes: _showAxes,
        showGrid: _showGrid,
        lockViewport: _lockViewport,
        degreeMode: _degreeMode,
        viewport: _viewport,
        parameters: _parameters.map((draft) => draft.toParameter()).toList(),
      ),
    );
  }

  void _addFunctionDraft() {
    setState(() {
      final nextId = _nextDraftId++;
      _drafts.add(
        _GraphItemDraft(
          localId: nextId,
          itemId: 'custom-$nextId',
          type: AiFlowGraphItemType.function,
          label: '직접 입력 ${_drafts.length + 1}',
          colorHex: _colorToHex(_kPalette[nextId % _kPalette.length]),
          enabled: true,
          expressionController: TextEditingController(),
        ),
      );
      _activeMobileDraftId = nextId;
      _mobileTrayState = _GraphTrayState.expanded;
      _editorMessage = null;
      _sampledItems.clear();
    });
  }

  void _removeDraft(_GraphItemDraft draft) {
    setState(() {
      _drafts.remove(draft);
      draft.dispose();
      if (_drafts.isEmpty) {
        _parameters.clear();
      }
      if (_activeMobileDraftId == draft.localId) {
        _activeMobileDraftId = _drafts.isEmpty ? null : _drafts.first.localId;
      }
      _editorMessage = null;
      _sampledItems.clear();
    });
  }

  /// 수식 입력을 280ms 동안 기다렸다가 최신 내용만 서버에 보낸다.
  /// 이전 요청이 늦게 도착해도 revision이 다르면 화면 상태를 덮어쓰지 않는다.
  void _scheduleGraphApply() {
    _sampleDebounce?.cancel();
    final revision = ++_sampleRevision;
    _sampleDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted || revision != _sampleRevision) return;
      unawaited(_applyCurrentDrafts(revision: revision));
    });
  }

  Future<void> _applyCurrentDrafts({int? revision}) async {
    _sampleDebounce?.cancel();
    final requestRevision = revision ?? ++_sampleRevision;
    var hasError = false;
    for (final draft in _drafts) {
      if (draft.type != AiFlowGraphItemType.function) {
        continue;
      }

      final result = validateAiFlowExpression(
        draft.expressionController?.text ?? '',
        degreeMode: _degreeMode,
        parameters: {
          for (final parameter in _parameters) parameter.id: parameter.value,
        },
      );
      draft.errorText = result.isValid ? null : result.errorMessage;
      if (result.isValid) {
        draft.expressionController?.text = result.normalizedExpression;
      } else {
        hasError = true;
      }
    }

    if (hasError) {
      if (mounted && requestRevision == _sampleRevision) {
        setState(() => _editorMessage = '검증된 형식으로 바꾼 뒤 다시 갱신하세요.');
      }
      return;
    }
    final functions = _drafts
        .where(
          (draft) =>
              draft.type == AiFlowGraphItemType.function && draft.enabled,
        )
        .toList();
    if (functions.isEmpty) {
      if (mounted && requestRevision == _sampleRevision) {
        setState(() => _editorMessage = '표시할 함수식을 입력해 주세요.');
      }
      return;
    }
    if (!mounted || requestRevision != _sampleRevision) return;
    setState(() {
      _sampling = true;
      _editorMessage = null;
    });
    try {
      final viewport = _viewport ?? _selectedExample.document.settings.viewport;
      final response =
          await (widget.sampleGraph ?? ApiClient.instance.sampleGraph)({
            'expressions': [
              for (final draft in functions)
                {
                  'id': draft.itemId,
                  'label': draft.label,
                  'color_hex': draft.colorHex,
                  'expression': draft.expressionController!.text.trim(),
                },
            ],
            'parameters': {
              for (final parameter in _parameters)
                parameter.id: parameter.value,
            },
            'left': viewport?.left ?? -12,
            'right': viewport?.right ?? 12,
            'degree_mode': _degreeMode,
          });
      final sampled = _readSampledItems(response);
      if (sampled.isEmpty) {
        throw const FormatException('좌표 응답이 비어 있습니다.');
      }
      if (!mounted || requestRevision != _sampleRevision) return;
      setState(() {
        _sampledItems
          ..clear()
          ..addAll(sampled);
        _editorMessage =
            '${sampled.fold<int>(0, (sum, item) => sum + (item.xValues?.length ?? 0))}개 좌표를 API에서 받았습니다.';
      });
    } on ApiException catch (error) {
      if (!mounted || requestRevision != _sampleRevision) return;
      setState(() {
        // 마지막으로 성공한 좌표는 유지해 일시적 입력/API 오류로 그래프가
        // 사라지지 않게 한다. 422는 수식 오류, 나머지는 네트워크/서버 오류다.
        _editorMessage = error.statusCode == 422
            ? '수식을 확인해 주세요: ${error.message}'
            : '그래프 좌표를 가져오지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    } on FormatException catch (error) {
      if (!mounted || requestRevision != _sampleRevision) return;
      setState(() {
        _editorMessage = '수식 응답을 읽지 못했습니다: ${error.message}';
      });
    } catch (_) {
      if (!mounted || requestRevision != _sampleRevision) return;
      setState(() {
        _editorMessage = '그래프 좌표를 가져오지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    } finally {
      if (mounted && requestRevision == _sampleRevision) {
        setState(() => _sampling = false);
      }
    }
    unawaited(
      ActivityStore.recordGraphPractice(
        graphId: 'jsx_graph_apply',
        meta: {'source': 'jsx_graph_page', 'item_count': _drafts.length},
      ),
    );
  }

  List<AiFlowGraphItem> _readSampledItems(Map<String, dynamic> response) {
    final result = <AiFlowGraphItem>[];
    final series = response['series'];
    if (series is! List) return result;
    for (final rawSeries in series.whereType<Map>()) {
      final item = Map<String, dynamic>.from(rawSeries);
      final segments = item['segments'];
      if (segments is! List) continue;
      var segmentIndex = 0;
      for (final rawSegment in segments.whereType<Map>()) {
        final segment = Map<String, dynamic>.from(rawSegment);
        final xs = (segment['x_values'] as List?)
            ?.whereType<num>()
            .map((value) => value.toDouble())
            .toList();
        final ys = (segment['y_values'] as List?)
            ?.whereType<num>()
            .map((value) => value.toDouble())
            .toList();
        if (xs == null || ys == null || xs.length != ys.length || xs.isEmpty) {
          continue;
        }
        result.add(
          AiFlowGraphItem(
            id: '${item['id'] ?? 'graph'}-$segmentIndex',
            type: AiFlowGraphItemType.line,
            label: item['label']?.toString() ?? '',
            colorHex:
                item['color_hex']?.toString() ?? _colorToHex(_kPalette.first),
            enabled: true,
            xValues: xs,
            yValues: ys,
          ),
        );
        segmentIndex += 1;
      }
    }
    return result;
  }

  void _addBeginnerFunction() {
    final a = double.tryParse(_beginnerA.text.trim());
    final b = double.tryParse(_beginnerB.text.trim());
    final c = double.tryParse(_beginnerC.text.trim());
    if (a == null || b == null || c == null) {
      setState(() => _editorMessage = '계수에는 숫자를 입력해 주세요.');
      return;
    }
    if (_drafts.isEmpty) {
      _addFunctionDraft();
    }
    final expressions = <String>[
      '$a*x+$b',
      '$a*x^2+$b*x+$c',
      '$a*x^3+$b*x+$c',
      '$a/x+$b',
    ];
    final draft = _drafts.first;
    draft.expressionController?.text = expressions[_beginnerType];
    _applyCurrentDrafts();
  }

  Future<void> _showInfoDialog() async {
    final box = _workspaceKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final workspace = box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _catalogDialogOpen = true;
    });
    final selected = await showGeneralDialog<AiFlowGraphExample>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '예제 탐색 닫기',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => _GraphCatalogDialog(workspace: workspace),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _catalogDialogOpen = false;
    });
    _exampleButtonFocus.requestFocus();

    if (selected == null) {
      return;
    }

    setState(() {
      _loadExample(selected);
    });
    if (_drafts.any((draft) => draft.type == AiFlowGraphItemType.function)) _scheduleGraphApply();
    unawaited(
      ActivityStore.recordGraphPractice(
        graphId: selected.id,
        meta: {
          'source': 'graph_example',
          'subject': selected.subject,
          'unit': selected.unit,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 720;
    final isLinux = !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
    return StudentHtmlShell(
      title: '그래프 탐색기', activeRoute: '/learning-tools', railWidth: 84,
      showContextAside: false, showBottomNavigation: false, mobileBackButton: true,
      onMenu: () => Navigator.of(context).maybePop(),
      headerTrailing: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox.square(dimension: 48, child: IconButton(tooltip: '새 그래프', onPressed: () { _resetToBlankGraph(); _sendGraphCommand('reset'); }, icon: const Icon(Icons.stacked_line_chart_rounded, size: 18))),
        SizedBox.square(dimension: 48, child: IconButton(key: const ValueKey('graph-zoom-out'), tooltip: '축소', onPressed: _lockViewport ? null : () => _sendGraphCommand('zoomOut'), icon: const Icon(Icons.remove, size: 18))),
        SizedBox.square(dimension: 48, child: IconButton(key: const ValueKey('graph-zoom-in'), tooltip: '확대', onPressed: _lockViewport ? null : () => _sendGraphCommand('zoomIn'), icon: const Icon(Icons.add, size: 18))),
      ]),
      child: ColoredBox(key: _workspaceKey, color: const Color(0xFFEAEAED), child: LayoutBuilder(builder: (context, constraints) {
        final board = _buildGraphPanel(isLinux: isLinux);
        if (mobile) return _buildMobileGraphLayout(constraints: constraints, graphPanel: board);
        return Padding(padding: const EdgeInsets.all(12), child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: board), const SizedBox(width: 12),
          SizedBox(width: 368, child: _buildEditorPanel()),
        ]));
      })),
    );
  }

  /// revision identifies a user action; viewport callback aligns sampling bounds with the live board.
  void _sendGraphCommand(String command) {
    setState(() { _graphCommand = command; _graphCommandRevision++; });
  }

  void _onViewportChanged(AiFlowGraphViewport viewport) {
    if (_viewport?.toJson().toString() == viewport.toJson().toString()) return;
    _viewport = viewport;
    if (_drafts.any((draft) => draft.expressionController?.text.trim().isNotEmpty ?? false)) _scheduleGraphApply();
  }

  void _cycleTray() {
    setState(() {
      _mobileTrayState = switch (_mobileTrayState) {
        _GraphTrayState.collapsed => _GraphTrayState.compact,
        _GraphTrayState.compact => _GraphTrayState.expanded,
        _GraphTrayState.expanded => _GraphTrayState.collapsed,
      };
    });
  }

  Widget _buildMobileGraphLayout({required BoxConstraints constraints, required Widget graphPanel}) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final trayHeight = switch (_mobileTrayState) {
      _GraphTrayState.collapsed => 76.0,
      _GraphTrayState.compact => (viewportHeight * .42).clamp(310.0, 350.0).toDouble(),
      _GraphTrayState.expanded => (viewportHeight * .70).clamp(76.0, 590.0).toDouble(),
    };
    return Stack(children: [
      Positioned.fill(bottom: trayHeight - 18, child: graphPanel),
      AnimatedPositioned(duration: const Duration(milliseconds: 190), left: 0, right: 0, bottom: 0, height: trayHeight,
        child: Material(color: _kSurface, elevation: 8, shadowColor: Colors.black26,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
          clipBehavior: Clip.antiAlias, child: _buildEditorPanel(compactMobile: true))),
    ]);
  }

  Widget _buildGraphPanel({required bool isLinux}) {
    final board = isLinux ? const Center(child: Text('이 그래프 웹뷰는 Linux에서 지원되지 않습니다.'))
        : widget.embedEnabled ? buildJsxGraphEmbed(
            _buildDocument(), showParameterControls: false, directManipulationMode: true,
            command: _graphCommand, commandRevision: _graphCommandRevision, onViewportChanged: _onViewportChanged,
            interactive: !_catalogDialogOpen,
          ) : const _GraphEmbedDisabledForTesting();
    return DecoratedBox(
      key: const ValueKey('graph-html-board'),
      decoration: BoxDecoration(color: const Color(0xFFFAFAFB), border: Border.all(color: _kBorder)),
      child: Stack(children: [
        Positioned.fill(child: board),
        if (_drafts.every((draft) => draft.expressionController?.text.trim().isEmpty ?? false))
          Center(child: Container(width: 220, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(color: const Color(0xEBFDFDFE), border: Border.all(color: _kBorder)),
            child: const Column(mainAxisSize: MainAxisSize.min, children: [
              Text('식에서 그래프로', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              SizedBox(height: 7), Text('아래에 수식을 입력하면 바로 그려져요.', style: TextStyle(fontSize: 11, color: _kMuted)),
            ]))),
        Positioned(right: 8, bottom: 8, child: IgnorePointer(child: Container(height: 32, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: const Color(0xEBFDFDFE), border: Border.all(color: _kBorder)),
          child: Text(_lockViewport ? '보기 고정 켜짐' : '드래그 이동 · ± 확대', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kMuted))))),
      ]),
    );
  }

  /// Reuses expression drafts, examples and debounced sampling; compact tray shows only its first expression.
  Widget _buildEditorPanel({bool compactMobile = false}) {
    final collapsed = compactMobile && _mobileTrayState == _GraphTrayState.collapsed;
    final showSettings = !compactMobile || _mobileTrayState == _GraphTrayState.expanded;
    final visibleDrafts = compactMobile && !showSettings ? _drafts.take(1) : _drafts;
    final content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (compactMobile) GestureDetector(key: const ValueKey('graph-tray-handle'), onTap: _cycleTray, behavior: HitTestBehavior.opaque,
        child: Center(child: Padding(padding: const EdgeInsets.only(top: 2, bottom: 8), child: Container(width: 44, height: 4, decoration: BoxDecoration(color: _kMuted, borderRadius: BorderRadius.circular(4)))))),
      Row(children: [
        if (!compactMobile) ...[Container(width: 18, height: 4, color: _kMuted), const SizedBox(width: 9)],
        Expanded(child: GestureDetector(onTap: _cycleTray, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('수식 ' + _drafts.length.toString() + '개', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2), Text(collapsed ? '그래프 크게 보기' : showSettings ? '전체 편집' : '빠른 편집', style: const TextStyle(fontSize: 10, color: _kMuted)),
        ]))),
        TextButton(onPressed: _cycleTray, style: TextButton.styleFrom(minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 8)), child: Text(collapsed ? '수식 열기' : showSettings ? '그래프 크게' : '전체 편집', style: const TextStyle(fontSize: 10, color: _kMuted))),
        if (!collapsed) ...[
          TextButton(key: const ValueKey('graph-examples-open'), focusNode: _exampleButtonFocus, onPressed: _showInfoDialog, style: TextButton.styleFrom(minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 8)), child: const Text('예제', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
          TextButton(onPressed: _addFunctionDraft, style: TextButton.styleFrom(minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 8)), child: const Text('+ 식', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
        ],
      ]),
      if (!collapsed) ...[
        const SizedBox(height: 10),
        for (final draft in visibleDrafts) ...[_buildDraftTile(draft, compact: compactMobile), const SizedBox(height: 9)],
        if (showSettings) ...[
          const SizedBox(height: 6), const Divider(height: 1, color: _kBorder), const SizedBox(height: 13),
          const Text('보기 설정', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)), const SizedBox(height: 8),
          Row(children: [Expanded(child: _viewOption('축', _showAxes, (value) => setState(() => _showAxes = value))), const SizedBox(width: 6), Expanded(child: _viewOption('격자', _showGrid, (value) => setState(() => _showGrid = value)))]),
          const SizedBox(height: 6),
          Row(children: [Expanded(child: _viewOption('뷰 고정', _lockViewport, (value) => setState(() => _lockViewport = value))), const SizedBox(width: 6), Expanded(child: _viewOption(_degreeMode ? '도 단위' : '라디안', _degreeMode, (value) { setState(() => _degreeMode = value); _applyCurrentDrafts(); }))]),
          if (_parameters.isNotEmpty) _PracticePanel(parameters: _parameters, onChanged: (parameter, value) { setState(() => parameter.value = value); _scheduleGraphApply(); }),
        ],
        if (_editorMessage != null) Padding(padding: const EdgeInsets.only(top: 9), child: Text(_editorMessage!, style: const TextStyle(color: Color(0xFFB33A3A), fontSize: 11, fontWeight: FontWeight.w700))),
      ],
    ]);
    return DecoratedBox(key: const ValueKey('graph-html-editor'), decoration: BoxDecoration(color: _kSurface, border: compactMobile ? null : Border.all(color: _kBorder)),
      child: SingleChildScrollView(key: compactMobile ? const ValueKey('mobile-graph-page-scroll') : null,
        padding: EdgeInsets.fromLTRB(compactMobile ? 12 : 14, compactMobile ? 8 : 14, compactMobile ? 12 : 14, compactMobile ? 10 : 14), child: content));
  }

  Widget _viewOption(String title, bool selected, ValueChanged<bool> onChanged) => SizedBox(height: 48,
    child: OutlinedButton(onPressed: () => onChanged(!selected),
      style: OutlinedButton.styleFrom(backgroundColor: selected ? const Color(0xFF09090B) : Colors.white, foregroundColor: selected ? Colors.white : const Color(0xFF09090B), side: BorderSide(color: selected ? const Color(0xFF09090B) : _kBorder), shape: const RoundedRectangleBorder(), textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), child: Text(title)));

  // Retained only for a future opt-in editor; the Atlas mobile entry point
  // deliberately uses the direct function editor above.
  // ignore: unused_element
  Widget _buildMobileEditorPanel() {
    return _SurfaceCard(
      child: Column(
        children: [
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: _kSurfaceTint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              children: [
                _MobileModeButton(
                  label: '고급 모드',
                  selected: _advancedMode,
                  onTap: () => setState(() => _advancedMode = true),
                ),
                _MobileModeButton(
                  label: '초보자 모드',
                  selected: !_advancedMode,
                  onTap: () => setState(() => _advancedMode = false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _advancedMode
              ? _buildMobileAdvancedEditor()
              : _buildMobileBeginnerEditor(),
          if (_editorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              _editorMessage!,
              key: const ValueKey('graph-api-message'),
              style: TextStyle(
                color: _sampledItems.isEmpty
                    ? const Color(0xFFB33A3A)
                    : _kMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('mobile-graph-apply'),
              onPressed: _sampling ? null : _applyCurrentDrafts,
              style: FilledButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _sampling
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.stacked_line_chart_rounded),
              label: Text(
                _sampling ? '좌표 가져오는 중' : '그래프 그리기',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileAdvancedEditor() {
    _GraphItemDraft? draft;
    for (final item in _drafts) {
      if (item.localId == _activeMobileDraftId) {
        draft = item;
        break;
      }
    }
    draft ??= _drafts.isEmpty ? null : _drafts.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in _drafts) ...[
          _buildDraftTile(item, compact: true),
          const SizedBox(height: 10),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _addFunctionDraft,
              icon: const Icon(Icons.add_rounded),
              label: const Text('추가'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (draft != null)
          _CalculatorKeypad(
            mobile: true,
            onInsert: (token) {
              if (token == _CalculatorKeypad.clearToken) {
                draft!.clearExpression();
              } else if (token == _CalculatorKeypad.backspaceToken) {
                draft!.deletePreviousCharacter();
              } else {
                draft!.insertToken(token);
              }
              setState(() {
                draft!.errorText = null;
                _sampledItems.clear();
                _editorMessage = null;
              });
            },
          ),
      ],
    );
  }

  Widget _buildMobileBeginnerEditor() {
    const labels = ['일차', '이차', '삼차', '유리'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '함수 타입 선택',
          style: TextStyle(color: _kGreen, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var index = 0; index < labels.length; index++) ...[
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ChoiceChip(
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(labels[index], textAlign: TextAlign.center),
                    ),
                    selected: _beginnerType == index,
                    onSelected: (_) => setState(() => _beginnerType = index),
                  ),
                ),
              ),
              if (index != labels.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          '계수 입력',
          style: TextStyle(color: _kGreen, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text(
              'y = ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            _CoefficientField(controller: _beginnerA, label: 'a'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('x +'),
            ),
            _CoefficientField(controller: _beginnerB, label: 'b'),
            if (_beginnerType == 1 || _beginnerType == 2) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('+'),
              ),
              _CoefficientField(controller: _beginnerC, label: 'c'),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _sampling ? null : _addBeginnerFunction,
              style: FilledButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                '함수 추가',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          '함수 목록',
          style: TextStyle(color: _kGreen, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final draft in _drafts) _buildDraftTile(draft, compact: true),
      ],
    );
  }

  Widget _buildDraftTile(_GraphItemDraft draft, {bool compact = false}) {
    if (draft.type == AiFlowGraphItemType.function) {
      return _FunctionDraftTile(
        draft: draft,
        compact: compact,
        onChanged: () {
          setState(() {
            draft.errorText = null;
            _editorMessage = null;
          });
          _scheduleGraphApply();
        },
        onToggle: () {
          setState(() {
            draft.enabled = !draft.enabled;
          });
        },
        onRemove: () => _removeDraft(draft),
        onSubmitted: (_) => _applyCurrentDrafts(),
        onActivated: compact
            ? () => setState(() => _activeMobileDraftId = draft.localId)
            : null,
      );
    }

    return _ReadonlySeriesTile(draft: draft);
  }
}

class _GraphCatalogDialog extends StatefulWidget {
  const _GraphCatalogDialog({required this.workspace});
  final Rect workspace;

  @override
  State<_GraphCatalogDialog> createState() => _GraphCatalogDialogState();
}

class _GraphCatalogDialogState extends State<_GraphCatalogDialog> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Searches the existing complete catalogue; selection returns its original document unchanged.
  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 720;
    final query = _query.trim().toLowerCase();
    final examples = aiFlowGraphExamples.where((example) => query.isEmpty || example.searchIndex.contains(query)).toList();
    final viewport = MediaQuery.sizeOf(context);
    final bounds = widget.workspace.intersect(Rect.fromLTWH(0, 0, viewport.width, math.max(0, viewport.height - MediaQuery.viewInsetsOf(context).bottom)));
    // The HTML sheet is content-sized for short lists and capped at 78% of the workspace on mobile.
    final contentHeight = 68.0 + 16 + 52 + 12 + 18 + (examples.isEmpty ? 68 : examples.length * 82 + math.max(0, examples.length - 1) * 8);
    final sheetHeight = mobile ? math.min(bounds.height * .78, contentHeight) : bounds.height;
    final sheetWidth = mobile ? bounds.width : math.min(430.0, bounds.width);
    final sheet = Material(
      key: const ValueKey('graph-example-sheet'),
      color: _kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: mobile ? const BorderRadius.vertical(top: Radius.circular(18)) : BorderRadius.zero,
        side: const BorderSide(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _kBorder))),
          child: Row(children: [
            const Expanded(child: Text('예제 탐색', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0))),
            SizedBox.square(dimension: 48, child: IconButton(key: const ValueKey('graph-example-close'), tooltip: '닫기', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, size: 20))),
          ]),
        ),
        Container(
          height: 52,
          margin: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(color: _kSurfaceTint, border: Border.all(color: _kBorder)),
          child: Row(children: [
            const Icon(Icons.search, size: 18), const SizedBox(width: 9),
            Expanded(child: TextField(
              key: const ValueKey('graph-example-search'),
              controller: _searchController, focusNode: _searchFocus,
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0),
              decoration: const InputDecoration(hintText: '함수나 단원을 검색하세요', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false, isDense: true, contentPadding: EdgeInsets.zero),
            )),
          ]),
        ),
        Expanded(child: examples.isEmpty
          ? const Padding(padding: EdgeInsets.all(18), child: Text('일치하는 예제가 없습니다.', style: TextStyle(fontSize: 13, color: _kMuted)))
          : ListView.separated(
              key: const ValueKey('graph-example-list'),
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              itemCount: examples.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final example = examples[index];
                final expression = example.document.items.where((item) => item.expression != null).map((item) => item.expression!).join(' · ');
                return Semantics(
                  button: true,
                  label: example.title + ' 불러오기',
                  child: OutlinedButton(
                    key: ValueKey('graph-example-' + example.id),
                    onPressed: () => Navigator.of(context).pop(example),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      minimumSize: const Size.fromHeight(82),
                      visualDensity: VisualDensity.standard,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: _kGreen,
                      side: const BorderSide(color: _kBorder),
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: Row(children: [
                      SizedBox(width: 78, child: Center(child: Text(example.subject, style: const TextStyle(fontSize: 11, color: _kMuted, letterSpacing: 0)))),
                      Container(width: 1, height: 54, color: _kBorder),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(example.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0)),
                        const SizedBox(height: 4),
                        Text(expression, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF2F7CF6), fontWeight: FontWeight.w800, letterSpacing: 0)),
                      ])),
                    ]),
                  ),
                );
              },
            )),
      ]),
    );
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop()},
      child: Stack(children: [
        Positioned.fromRect(rect: bounds, child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: ColoredBox(color: mobile ? const Color(0x4709090B) : Colors.transparent),
        )),
        Positioned(
          right: viewport.width - bounds.right,
          bottom: viewport.height - bounds.bottom,
          width: sheetWidth, height: sheetHeight,
          child: sheet,
        ),
      ]),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: _kBorder),
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}


class _GraphEmbedDisabledForTesting extends StatelessWidget {
  const _GraphEmbedDisabledForTesting();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: CustomPaint(painter: _GraphPreviewPainter()),
        ),
        Positioned(
          right: 14,
          bottom: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _kBorder),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('━  f(x)=a(x-h)²+k', style: TextStyle(fontSize: 10)),
                Text('┄  y=2x+1', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GraphPreviewPainter extends CustomPainter {
  const _GraphPreviewPainter();

  /// 필요한 변수는 좌표평면의 실제 캔버스 크기다.
  /// 작동 원리는 네트워크 없는 감사에서도 격자·축·이차함수·직선을 HTML과 같은 흑백 선으로 그리는 것이다.
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFE7E7EA)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final axis = Paint()
      ..color = const Color(0xFF88888E)
      ..strokeWidth = 1.3;
    canvas.drawLine(
      Offset(size.width * .48, 0),
      Offset(size.width * .48, size.height),
      axis,
    );
    canvas.drawLine(
      Offset(0, size.height * .58),
      Offset(size.width, size.height * .58),
      axis,
    );
    final curve = Paint()
      ..color = const Color(0xFF242426)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var index = 0; index <= 120; index++) {
      final t = index / 120;
      final x = 20 + t * (size.width - 40);
      final normalized = (t - .68) * 2.25;
      final y = size.height * .22 + normalized * normalized * size.height * .5;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, curve);
    final line = Paint()
      ..color = const Color(0xFF85858C)
      ..strokeWidth = 3;
    for (var index = 0; index < 18; index += 2) {
      final start = index / 18;
      final end = (index + 1) / 18;
      canvas.drawLine(
        Offset(
          20 + start * (size.width - 40),
          size.height * (.78 - start * .62),
        ),
        Offset(20 + end * (size.width - 40), size.height * (.78 - end * .62)),
        line,
      );
    }
    final points = <(Offset, String)>[
      (Offset(size.width * .42, size.height * .47), 'A'),
      (Offset(size.width * .64, size.height * .26), 'B'),
    ];
    for (final entry in points) {
      final point = entry.$1;
      canvas.drawCircle(point, 13, Paint()..color = Colors.white);
      canvas.drawCircle(point, 11, Paint()..color = const Color(0xFF202022));
      final label = TextPainter(
        text: TextSpan(
          text: entry.$2,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(point.dx - label.width / 2, point.dy - label.height / 2),
      );
    }
  }

  /// 필요한 변수는 이전 페인터 참조다.
  /// 작동 원리는 고정 시안 그래프이므로 크기 변경 외에는 다시 그리지 않는 것이다.
  @override
  bool shouldRepaint(covariant _GraphPreviewPainter oldDelegate) => false;
}

class _PracticePanel extends StatelessWidget {
  const _PracticePanel({required this.parameters, required this.onChanged});

  final List<_GraphParameterDraft> parameters;
  final void Function(_GraphParameterDraft parameter, double value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '실습',
            style: TextStyle(
              color: _kGreen,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final parameter in parameters) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${parameter.label} = ${_formatNumber(parameter.value)}',
                    style: const TextStyle(
                      color: _kMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    parameter.id,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: _kGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: parameter.value
                  .clamp(parameter.min, parameter.max)
                  .toDouble(),
              min: parameter.min,
              max: parameter.max,
              divisions: _sliderDivisions(parameter),
              label: _formatNumber(parameter.value),
              onChanged: (value) =>
                  onChanged(parameter, _snapToStep(parameter, value)),
            ),
          ],
        ],
      ),
    );
  }
}

class _CalculatorKeypad extends StatelessWidget {
  const _CalculatorKeypad({required this.onInsert, this.mobile = false});

  static const clearToken = '__clear__';
  static const backspaceToken = '__backspace__';

  final ValueChanged<String> onInsert;
  final bool mobile;

  static const _keys = <_CalculatorKey>[
    _CalculatorKey('x', 'x'),
    _CalculatorKey('x²', '^2'),
    _CalculatorKey('√', 'sqrt()'),
    _CalculatorKey('| |', 'abs()'),
    _CalculatorKey('sin', 'sin()'),
    _CalculatorKey('cos', 'cos()'),
    _CalculatorKey('tan', 'tan()'),
    _CalculatorKey('log', 'log()'),
    _CalculatorKey('ln', 'ln()'),
    _CalculatorKey('π', 'pi'),
    _CalculatorKey('e', 'e'),
    _CalculatorKey('(', '('),
    _CalculatorKey(')', ')'),
    _CalculatorKey('+', '+'),
    _CalculatorKey('−', '-'),
    _CalculatorKey('×', '*'),
    _CalculatorKey('÷', '/'),
    _CalculatorKey('^', '^'),
  ];

  static const _mobileKeys = <_CalculatorKey>[
    _CalculatorKey('sin', 'sin()'),
    _CalculatorKey('cos', 'cos()'),
    _CalculatorKey('tan', 'tan()'),
    _CalculatorKey('log', 'log()'),
    _CalculatorKey('ln', 'ln()'),
    _CalculatorKey('√', 'sqrt()'),
    _CalculatorKey('| |', 'abs()'),
    _CalculatorKey('x', 'x'),
    _CalculatorKey('7', '7'),
    _CalculatorKey('8', '8'),
    _CalculatorKey('9', '9'),
    _CalculatorKey('÷', '/'),
    _CalculatorKey('4', '4'),
    _CalculatorKey('5', '5'),
    _CalculatorKey('6', '6'),
    _CalculatorKey('×', '*'),
    _CalculatorKey('1', '1'),
    _CalculatorKey('2', '2'),
    _CalculatorKey('3', '3'),
    _CalculatorKey('−', '-'),
    _CalculatorKey('0', '0'),
    _CalculatorKey('.', '.'),
    _CalculatorKey('π', 'pi'),
    _CalculatorKey('+', '+'),
    _CalculatorKey('(', '('),
    _CalculatorKey(')', ')'),
    _CalculatorKey('^', '^'),
    _CalculatorKey('x²', '^2'),
    _CalculatorKey('e', 'e'),
    _CalculatorKey('C', clearToken),
    _CalculatorKey('⌫', backspaceToken),
  ];

  @override
  Widget build(BuildContext context) {
    if (mobile) {
      return GridView.builder(
        key: const ValueKey('mobile-math-keypad'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _mobileKeys.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.55,
        ),
        itemBuilder: (context, index) {
          final key = _mobileKeys[index];
          return _CalculatorKeyButton(calculatorKey: key, onInsert: onInsert);
        },
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final key in _keys)
          SizedBox(
            width: 46,
            height: 34,
            child: _CalculatorKeyButton(calculatorKey: key, onInsert: onInsert),
          ),
      ],
    );
  }
}

class _CalculatorKeyButton extends StatelessWidget {
  const _CalculatorKeyButton({
    required this.calculatorKey,
    required this.onInsert,
  });

  final _CalculatorKey calculatorKey;
  final ValueChanged<String> onInsert;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onInsert(calculatorKey.value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Text(
          calculatorKey.label,
          style: const TextStyle(
            color: _kGreen,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MobileModeButton extends StatelessWidget {
  const _MobileModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? _kGreen : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? _kGreen : _kMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _CoefficientField extends StatelessWidget {
  const _CoefficientField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 52,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: label,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _CalculatorKey {
  const _CalculatorKey(this.label, this.value);

  final String label;
  final String value;
}


class _FunctionDraftTile extends StatefulWidget {
  const _FunctionDraftTile({
    required this.draft,
    required this.compact,
    required this.onChanged,
    required this.onToggle,
    required this.onRemove,
    required this.onSubmitted,
    this.onActivated,
  });

  final _GraphItemDraft draft;
  final bool compact;
  final VoidCallback onChanged;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onActivated;

  @override
  State<_FunctionDraftTile> createState() => _FunctionDraftTileState();
}

class _FunctionDraftTileState extends State<_FunctionDraftTile> {
  late final FocusNode _expressionFocusNode;

  _GraphItemDraft get draft => widget.draft;
  VoidCallback get onChanged => widget.onChanged;
  VoidCallback get onToggle => widget.onToggle;
  VoidCallback get onRemove => widget.onRemove;
  ValueChanged<String> get onSubmitted => widget.onSubmitted;
  bool get compact => widget.compact;

  /// 필요한 변수는 수식 입력란의 포커스 상태다.
  /// 작동 원리는 포커스 변경을 감지해 현재 편집 중인 카드에만 계산 입력 패드를 표시하는 것이다.
  @override
  void initState() {
    super.initState();
    _expressionFocusNode = FocusNode()..addListener(_handleFocusChange);
  }

  /// 필요한 변수는 [_expressionFocusNode]의 현재 포커스 값이다.
  /// 작동 원리는 포커스가 들어오거나 빠질 때 위젯을 다시 그려 입력 패드 표시 여부를 갱신하는 것이다.
  void _handleFocusChange() {
    setState(() {});
  }

  /// 필요한 변수는 생성한 수식 입력 포커스 노드다.
  /// 작동 원리는 리스너와 노드를 함께 정리해 화면을 반복해서 열어도 리소스가 남지 않게 하는 것이다.
  @override
  void dispose() {
    _expressionFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  /// Single 48px input row matches HTML; the existing focus node and draft callbacks retain calculation behavior.
  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(draft.colorHex);
    final border = OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: const BorderSide(color: _kBorder));
    return Container(
      padding: EdgeInsets.all(compact ? 6 : 8),
      decoration: BoxDecoration(color: _kSurfaceTint, border: Border.all(color: draft.errorText == null ? _kBorder : const Color(0xFFB33A3A))),
      child: TextFieldTapRegion(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox.square(dimension: 48, child: IconButton(tooltip: draft.label + ' 표시 전환', onPressed: onToggle, icon: Container(width: 18, height: 5, color: draft.enabled ? color : _kBorder))),
          const SizedBox(width: 3),
          SizedBox(width: compact ? 26 : 30, child: Text('y =', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700))),
          const SizedBox(width: 3),
          Expanded(child: SizedBox(height: 48, child: TextField(
            key: compact ? ValueKey('mobile-math-expression-' + draft.localId.toString()) : ValueKey('graph-expression-' + draft.localId.toString()),
            controller: draft.expressionController, focusNode: _expressionFocusNode,
            minLines: 1, maxLines: 1, keyboardType: TextInputType.text, textInputAction: TextInputAction.done,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            onChanged: (_) => onChanged(), onSubmitted: onSubmitted, onTap: widget.onActivated,
            onTapOutside: (_) => _expressionFocusNode.unfocus(),
            decoration: InputDecoration(border: border, enabledBorder: border, focusedBorder: border.copyWith(borderSide: const BorderSide(color: Color(0xFF2F7CF6))), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13), isDense: true, hintText: '예: x^2 - 3'),
          ))),
          const SizedBox(width: 3),
          SizedBox.square(dimension: 48, child: IconButton(tooltip: draft.label + ' 삭제', onPressed: onRemove, icon: const Icon(Icons.close, size: 18))),
        ]),
        Padding(padding: EdgeInsets.fromLTRB(compact ? 77 : 83, 6, 4, 0), child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: draft.expressionController!,
          builder: (context, value, _) => Text(draft.errorText ?? (value.text.trim().isEmpty ? '수식을 입력하세요' : 'y = ' + value.text.trim()), style: TextStyle(fontSize: 11, height: 1.45, fontWeight: FontWeight.w600, color: draft.errorText == null ? _kMuted : const Color(0xFFB33A3A))),
        )),
        if (_expressionFocusNode.hasFocus) Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Row(children: [
            for (final token in const ['x', '^2', 'sin()', 'cos()', '(', ')'])
              Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: SizedBox(height: 48, child: OutlinedButton(
                onPressed: () { draft.insertToken(token); onChanged(); },
                style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, shape: const RoundedRectangleBorder(), side: const BorderSide(color: _kBorder), backgroundColor: Colors.white, textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                child: Text(token == '^2' ? 'x²' : token.replaceAll('()', '')),
              )))),
          ]),
        ),
      ])),
    );
  }
}


class _ReadonlySeriesTile extends StatelessWidget {
  const _ReadonlySeriesTile({required this.draft});

  final _GraphItemDraft draft;

  @override
  Widget build(BuildContext context) {
    final pointCount = draft.xValues?.length ?? 0;
    final typeLabel = draft.type == AiFlowGraphItemType.line ? '선그래프' : '산점도';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurfaceTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _hexToColor(draft.colorHex),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.label,
                  style: const TextStyle(
                    color: _kGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$typeLabel · 데이터 $pointCount개',
                  style: const TextStyle(color: _kMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphItemDraft {
  _GraphItemDraft({
    required this.localId,
    required this.itemId,
    required this.type,
    required this.label,
    required this.colorHex,
    required this.enabled,
    this.expressionController,
    this.xValues,
    this.yValues,
  });

  factory _GraphItemDraft.fromItem({
    required int localId,
    required AiFlowGraphItem item,
    required Color fallbackColor,
  }) {
    return _GraphItemDraft(
      localId: localId,
      itemId: item.id,
      type: item.type,
      label: item.label,
      colorHex: item.colorHex.isNotEmpty
          ? item.colorHex
          : _colorToHex(fallbackColor),
      enabled: item.enabled,
      expressionController: item.isFunction
          ? TextEditingController(text: item.expression ?? '')
          : null,
      xValues: item.xValues == null ? null : List<double>.from(item.xValues!),
      yValues: item.yValues == null ? null : List<double>.from(item.yValues!),
    );
  }

  final int localId;
  final String itemId;
  final AiFlowGraphItemType type;
  final String label;
  final String colorHex;
  bool enabled;
  String? errorText;
  final TextEditingController? expressionController;
  final List<double>? xValues;
  final List<double>? yValues;

  AiFlowGraphItem toItem() {
    return AiFlowGraphItem(
      id: itemId,
      type: type,
      label: label,
      colorHex: colorHex,
      enabled: enabled,
      expression: expressionController?.text.trim(),
      xValues: xValues,
      yValues: yValues,
    );
  }

  void dispose() {
    expressionController?.dispose();
  }

  void insertToken(String token) {
    final controller = expressionController;
    if (controller == null) {
      return;
    }

    final selection = controller.selection;
    final text = controller.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final normalizedStart = start.clamp(0, text.length);
    final normalizedEnd = end.clamp(0, text.length);
    final nextText = text.replaceRange(normalizedStart, normalizedEnd, token);
    final cursor = token.endsWith('()')
        ? normalizedStart + token.length - 1
        : normalizedStart + token.length;
    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  void clearExpression() {
    expressionController?.clear();
  }

  void deletePreviousCharacter() {
    final controller = expressionController;
    if (controller == null || controller.text.isEmpty) return;
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : controller.text.length;
    final end = selection.isValid ? selection.end : controller.text.length;
    if (start != end) {
      controller.text = controller.text.replaceRange(start, end, '');
      controller.selection = TextSelection.collapsed(offset: start);
      return;
    }
    if (start <= 0) return;
    controller.text = controller.text.replaceRange(start - 1, start, '');
    controller.selection = TextSelection.collapsed(offset: start - 1);
  }
}

class _GraphParameterDraft {
  _GraphParameterDraft({
    required this.id,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
  });

  factory _GraphParameterDraft.fromParameter(AiFlowGraphParameter parameter) {
    return _GraphParameterDraft(
      id: parameter.id,
      label: parameter.label,
      value: parameter.value,
      min: parameter.min,
      max: parameter.max,
      step: parameter.step,
    );
  }

  final String id;
  final String label;
  double value;
  final double min;
  final double max;
  final double step;

  AiFlowGraphParameter toParameter() {
    return AiFlowGraphParameter(
      id: id,
      label: label,
      value: value,
      min: min,
      max: max,
      step: step,
    );
  }
}

String _colorToHex(Color color) {
  final rgb = color.toARGB32() & 0x00FFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

int? _sliderDivisions(_GraphParameterDraft parameter) {
  if (parameter.step <= 0) {
    return null;
  }
  final divisions = ((parameter.max - parameter.min) / parameter.step).round();
  return divisions > 0 ? divisions : null;
}

double _snapToStep(_GraphParameterDraft parameter, double value) {
  if (parameter.step <= 0) {
    return value;
  }
  final snapped =
      parameter.min +
      ((value - parameter.min) / parameter.step).round() * parameter.step;
  return snapped.clamp(parameter.min, parameter.max).toDouble();
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}


Color _hexToColor(String hex) {
  final normalized = hex.replaceFirst('#', '');
  final value = int.tryParse(normalized, radix: 16) ?? 0x1B402B;
  return Color(0xFF000000 | value);
}
