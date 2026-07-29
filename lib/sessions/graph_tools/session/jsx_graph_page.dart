import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_example_catalog.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_expression.dart';
import 'package:s11/sessions/graph_tools/ui/widgets/jsx_graph_embed.dart';
import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/shared/theme/app_colors.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';

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

class JsxGraphPage extends StatefulWidget {
  const JsxGraphPage({super.key, this.embedEnabled = true});

  final bool embedEnabled;

  @override
  State<JsxGraphPage> createState() => _JsxGraphPageState();
}

class _JsxGraphPageState extends State<JsxGraphPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<_GraphItemDraft> _drafts = <_GraphItemDraft>[];
  final List<_GraphParameterDraft> _parameters = <_GraphParameterDraft>[];

  late AiFlowGraphExample _selectedExample;
  int _nextDraftId = 0;
  bool _showAxes = true;
  bool _showGrid = true;
  bool _lockViewport = false;
  bool _degreeMode = false;
  bool _catalogDialogOpen = false;
  bool _drawerOpen = false;
  bool _hasActiveExampleContext = true;
  String? _editorMessage;

  @override
  void initState() {
    super.initState();
    _selectedExample = aiFlowGraphExamples.first;
    _startBlankGraph();
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
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
    _parameters.clear();
    _hasActiveExampleContext = false;
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

  /// 필요한 변수는 Scaffold가 전달하는 전체 메뉴 열림 상태다.
  /// 작동 원리는 메뉴가 열리는 동안 플랫폼 웹뷰를 트리에서 제외해
  /// 그래프 레이어가 드로어의 터치를 가로채지 않게 하는 것이다.
  void _handleDrawerChanged(bool isOpened) {
    if (!mounted || _drawerOpen == isOpened) {
      return;
    }
    setState(() {
      _drawerOpen = isOpened;
    });
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
    _parameters
      ..clear()
      ..addAll(
        example.document.settings.parameters.map(
          _GraphParameterDraft.fromParameter,
        ),
      );

    _selectedExample = example;
    _hasActiveExampleContext = true;
    _showAxes = example.document.settings.showAxes;
    _showGrid = example.document.settings.showGrid;
    _lockViewport = example.document.settings.lockViewport;
    _degreeMode = example.document.settings.degreeMode;
    _editorMessage = null;
  }

  AiFlowGraphDocument _buildDocument() {
    return AiFlowGraphDocument(
      items: _drafts.map((draft) => draft.toItem()).toList(),
      settings: _selectedExample.document.settings.copyWith(
        showAxes: _showAxes,
        showGrid: _showGrid,
        lockViewport: _lockViewport,
        degreeMode: _degreeMode,
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
      _editorMessage = null;
    });
  }

  void _removeDraft(_GraphItemDraft draft) {
    setState(() {
      _drafts.remove(draft);
      draft.dispose();
      if (_drafts.isEmpty) {
        _hasActiveExampleContext = false;
        _parameters.clear();
      }
      _editorMessage = null;
    });
  }

  void _applyCurrentDrafts() {
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

    setState(() {
      if (hasError) {
        _editorMessage = '검증된 형식으로 바꾼 뒤 다시 갱신하세요.';
        return;
      }
      _editorMessage = null;
    });
    unawaited(
      ActivityStore.recordGraphPractice(
        graphId: 'jsx_graph_apply',
        meta: {'source': 'jsx_graph_page', 'item_count': _drafts.length},
      ),
    );
  }

  Future<void> _showInfoDialog() async {
    setState(() {
      _catalogDialogOpen = true;
    });
    final selected = await showDialog<AiFlowGraphExample>(
      context: context,
      builder: (_) => _GraphCatalogDialog(initialExample: _selectedExample),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _catalogDialogOpen = false;
    });

    if (selected == null) {
      return;
    }

    setState(() {
      _loadExample(selected);
    });
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
    final isLinux = !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      onDrawerChanged: _handleDrawerChanged,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 1120;
                      final mobileLayout = constraints.maxWidth < 720;
                      final graphPanel = _buildGraphPanel(isLinux: isLinux);
                      final editorPanel = _buildEditorPanel(
                        compactMobile: mobileLayout,
                      );

                      if (mobileLayout) {
                        return Column(
                          children: [
                            SizedBox(
                              height: (constraints.maxHeight * .40)
                                  .clamp(250.0, 330.0)
                                  .toDouble(),
                              child: graphPanel,
                            ),
                            const SizedBox(height: 12),
                            Expanded(child: editorPanel),
                          ],
                        );
                      }

                      if (compact) {
                        return ListView(
                          children: [
                            SizedBox(height: 520, child: graphPanel),
                            const SizedBox(height: 12),
                            editorPanel,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: graphPanel),
                          const SizedBox(width: 14),
                          SizedBox(
                            width: 400,
                            height: constraints.maxHeight,
                            child: editorPanel,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 필요한 변수는 현재 Scaffold·Navigator와 새 그래프·예제 콜백이다.
  /// 작동 원리는 뒤로가기·전체 메뉴·작업 버튼을 공용 앱바 한 줄에 배치해
  /// 그래프 전용 제목 바가 본문 공간을 차지하지 않게 하는 것이다.
  Widget _buildHeader() {
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Ios26TopBar(
      brandColor: Colors.black,
      showLevelIndicator: false,
      showUtilityActions: false,
      onBack: () => Navigator.of(context).maybePop(),
      onMenu: () => _scaffoldKey.currentState?.openDrawer(),
      showMenuWithBack: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAppBarAction(
            compact: compact,
            tooltip: '새 그래프',
            icon: Icons.add_chart_rounded,
            onPressed: _resetToBlankGraph,
          ),
          const SizedBox(width: 6),
          _buildAppBarAction(
            compact: compact,
            tooltip: '예제 불러오기',
            icon: Icons.folder_open_outlined,
            onPressed: _showInfoDialog,
            outlined: true,
          ),
        ],
      ),
    );
  }

  /// 필요한 변수는 화면 밀도·레이블·아이콘·콜백이다.
  /// 작동 원리는 넓은 화면에서는 텍스트 버튼을, 좁은 화면에서는 동일한 도구 설명의
  /// 아이콘 버튼을 보여 앱바가 넘치지 않게 하는 것이다.
  Widget _buildAppBarAction({
    required bool compact,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    bool outlined = false,
  }) {
    if (compact) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
      );
    }
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(tooltip),
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(tooltip),
    );
  }

  /// 필요한 변수는 플랫폼 지원 여부와 현재 그래프 문서다.
  /// 작동 원리는 모든 화면 크기에서 JSXGraph를 유지하고, 모바일은 iframe 로드
  /// 완료 뒤 최신 수식을 다시 전달해 좌표평면과 수식 상태를 일치시키는 것이다.
  Widget _buildGraphPanel({required bool isLinux}) {
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFFFAFAFB)),
          child: _catalogDialogOpen
              ? const _GraphHiddenWhileDialogOpen()
              : _drawerOpen
              ? const SizedBox.expand(
                  key: ValueKey('graph-embed-suspended-for-drawer'),
                )
              : isLinux
              ? const Center(child: Text('이 그래프 웹뷰는 Linux에서 지원되지 않습니다.'))
              : widget.embedEnabled
              ? buildJsxGraphEmbed(
                  _buildDocument(),
                  showParameterControls: false,
                  directManipulationMode: true,
                )
              : const _GraphEmbedDisabledForTesting(),
        ),
      ),
    );
  }

  /// 필요한 변수는 세로 모바일용 축약 여부와 현재 수식 초안이다.
  /// 작동 원리는 모바일에서 큰 설명·여러 줄 입력을 줄이고 한 줄 수식 입력과
  /// 고정된 전체 폭 갱신 행동을 앞세워 그래프 확인까지의 단계를 짧게 만드는 것이다.
  Widget _buildEditorPanel({bool compactMobile = false}) {
    final editorContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          compactMobile ? '함수 그리기' : '수식',
          style: const TextStyle(
            color: _kGreen,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          compactMobile
              ? '수식을 입력하면 좌표평면에 바로 반영됩니다.'
              : '함수식을 직접 입력하고 좌표평면에서 결과를 확인하세요.',
          style: const TextStyle(color: _kMuted, fontSize: 12.5, height: 1.45),
        ),
        if (_hasActiveExampleContext) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kSurfaceTint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '예제에서 시작: ${_selectedExample.title}',
                    style: const TextStyle(
                      color: _kGreen,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '빈 그래프로 전환',
                  onPressed: _resetToBlankGraph,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _addFunctionDraft,
            icon: const Icon(Icons.add_rounded),
            label: const Text('식 추가'),
          ),
        ),
        if (_parameters.isNotEmpty) ...[
          _PracticePanel(
            parameters: _parameters,
            onChanged: (parameter, value) {
              setState(() {
                parameter.value = value;
              });
            },
          ),
          const SizedBox(height: 10),
        ],
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _drafts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) =>
              _buildDraftTile(_drafts[index], compact: compactMobile),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('축'),
              selected: _showAxes,
              onSelected: (value) {
                setState(() {
                  _showAxes = value;
                });
              },
            ),
            FilterChip(
              label: const Text('격자'),
              selected: _showGrid,
              onSelected: (value) {
                setState(() {
                  _showGrid = value;
                });
              },
            ),
            FilterChip(
              label: const Text('뷰 고정'),
              selected: _lockViewport,
              onSelected: (value) {
                setState(() {
                  _lockViewport = value;
                });
              },
            ),
            FilterChip(
              label: Text(_degreeMode ? '도 단위' : '라디안'),
              selected: _degreeMode,
              onSelected: (value) {
                setState(() {
                  _degreeMode = value;
                });
                _applyCurrentDrafts();
              },
            ),
          ],
        ),
        if (_editorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _editorMessage!,
            style: const TextStyle(
              color: Color(0xFFB33A3A),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (!compactMobile)
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: null,
              child: FilledButton.icon(
                onPressed: _applyCurrentDrafts,
                style: FilledButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.stacked_line_chart_rounded),
                label: const Text('그래프 갱신'),
              ),
            ),
          ),
      ],
    );

    if (compactMobile) {
      return _SurfaceCard(
        child: Column(
          children: [
            Expanded(child: SingleChildScrollView(child: editorContent)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('mobile-graph-apply'),
                onPressed: _applyCurrentDrafts,
                style: FilledButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.stacked_line_chart_rounded),
                label: const Text(
                  '그래프에 반영하기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _SurfaceCard(child: SingleChildScrollView(child: editorContent));
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
        },
        onToggle: () {
          setState(() {
            draft.enabled = !draft.enabled;
          });
        },
        onRemove: () => _removeDraft(draft),
        onSubmitted: (_) => _applyCurrentDrafts(),
      );
    }

    return _ReadonlySeriesTile(draft: draft);
  }
}

class _GraphCatalogDialog extends StatefulWidget {
  const _GraphCatalogDialog({required this.initialExample});

  final AiFlowGraphExample initialExample;

  @override
  State<_GraphCatalogDialog> createState() => _GraphCatalogDialogState();
}

class _GraphCatalogDialogState extends State<_GraphCatalogDialog> {
  late final TextEditingController _searchController;
  late AiFlowGraphSubjectCatalog _selectedCatalog;
  late String _selectedSubject;
  late String _selectedUnit;
  AiFlowGraphFormulaSummary? _selectedFormula;
  AiFlowGraphExample? _selectedExample;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedCatalog = _findCatalogForExample(widget.initialExample);
    _selectedSubject = _selectedCatalog.subject;
    _selectedUnit = widget.initialExample.unit;
    _selectedExample = widget.initialExample;
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  AiFlowGraphSubjectCatalog get _subjectCatalog => _selectedCatalog;

  /// 필요한 변수는 처음 선택된 예제와 전체 과목 카탈로그다.
  /// 작동 원리는 예제의 표시용 과목명이 아닌 예제 ID의 실제 포함 관계로 소속 카탈로그를 찾는다.
  AiFlowGraphSubjectCatalog _findCatalogForExample(AiFlowGraphExample example) {
    for (final catalog in aiFlowGraphCatalog) {
      if (catalog.examples.any((item) => item.id == example.id)) {
        return catalog;
      }
    }

    // 페이지 초기 예제도 같은 목록에서 가져오므로 정상 데이터에서는 도달하지 않는다.
    return aiFlowGraphCatalog.first;
  }

  List<AiFlowGraphFormulaSummary> get _filteredFormulas {
    final query = _query.trim().toLowerCase();
    final formulas = _subjectCatalog.formulas.where((formula) {
      if (_selectedUnit.isNotEmpty && formula.unit != _selectedUnit) {
        return false;
      }
      return query.isEmpty || formula.searchIndex.contains(query);
    }).toList();
    return formulas;
  }

  List<AiFlowGraphExample> get _filteredExamples {
    final query = _query.trim().toLowerCase();
    return _subjectCatalog.examples.where((example) {
      if (_selectedUnit.isNotEmpty && example.unit != _selectedUnit) {
        return false;
      }
      return query.isEmpty || example.searchIndex.contains(query);
    }).toList();
  }

  void _selectSubject(String subject) {
    AiFlowGraphSubjectCatalog? catalog;
    for (final item in aiFlowGraphCatalog) {
      if (item.subject == subject) {
        catalog = item;
        break;
      }
    }
    if (catalog == null) {
      return;
    }

    setState(() {
      _selectedCatalog = catalog!;
      _selectedSubject = subject;
      _selectedUnit = catalog.units.isNotEmpty ? catalog.units.first : '';
      _query = '';
      _searchController.clear();
      _selectedFormula = catalog.formulas.isNotEmpty
          ? catalog.formulas.first
          : null;
      _selectedExample = catalog.examples.isNotEmpty
          ? catalog.examples.first
          : null;
    });
  }

  void _selectUnit(String unit) {
    setState(() {
      _selectedUnit = unit;
      _selectedFormula = null;
      _selectedExample = null;
    });
  }

  void _ensureSelection() {
    final formulas = _filteredFormulas;
    final examples = _filteredExamples;

    if (_selectedFormula != null &&
        !formulas.any((formula) => identical(formula, _selectedFormula))) {
      _selectedFormula = null;
    }
    if (_selectedExample != null &&
        !examples.any((example) => example.id == _selectedExample!.id)) {
      _selectedExample = null;
    }

    _selectedFormula ??= formulas.isNotEmpty ? formulas.first : null;
    _selectedExample ??= examples.isNotEmpty ? examples.first : null;
  }

  @override
  Widget build(BuildContext context) {
    _ensureSelection();
    final formulas = _filteredFormulas;
    final examples = _filteredExamples;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1360, maxHeight: 820),
        child: Material(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '예제 탐색',
                        style: TextStyle(
                          color: _kGreen,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 30),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 1040;
                      if (compact) {
                        return Column(
                          children: [
                            SizedBox(
                              height: 220,
                              child: _ExplorerSidebar(
                                selectedSubject: _selectedSubject,
                                selectedUnit: _selectedUnit,
                                onSelectSubject: _selectSubject,
                                onSelectUnit: _selectUnit,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: _ExplorerMainPane(
                                searchController: _searchController,
                                onSearchChanged: (value) =>
                                    setState(() => _query = value),
                                selectedSubject: _selectedSubject,
                                selectedUnit: _selectedUnit,
                                formulas: formulas,
                                examples: examples,
                                selectedFormula: _selectedFormula,
                                selectedExample: _selectedExample,
                                onSelectFormula: (formula) {
                                  setState(() {
                                    _selectedFormula = formula;
                                    _selectedExample = null;
                                  });
                                },
                                onSelectExample: (example) {
                                  setState(() {
                                    _selectedExample = example;
                                    _selectedFormula = null;
                                  });
                                },
                                onApplyExample: (example) =>
                                    Navigator.of(context).pop(example),
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          SizedBox(
                            width: 280,
                            child: _ExplorerSidebar(
                              selectedSubject: _selectedSubject,
                              selectedUnit: _selectedUnit,
                              onSelectSubject: _selectSubject,
                              onSelectUnit: _selectUnit,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _ExplorerMainPane(
                              searchController: _searchController,
                              onSearchChanged: (value) =>
                                  setState(() => _query = value),
                              selectedSubject: _selectedSubject,
                              selectedUnit: _selectedUnit,
                              formulas: formulas,
                              examples: examples,
                              selectedFormula: _selectedFormula,
                              selectedExample: _selectedExample,
                              onSelectFormula: (formula) {
                                setState(() {
                                  _selectedFormula = formula;
                                  _selectedExample = null;
                                });
                              },
                              onSelectExample: (example) {
                                setState(() {
                                  _selectedExample = example;
                                  _selectedFormula = null;
                                });
                              },
                              onApplyExample: (example) =>
                                  Navigator.of(context).pop(example),
                            ),
                          ),
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
}

class _ExplorerSidebar extends StatelessWidget {
  const _ExplorerSidebar({
    required this.selectedSubject,
    required this.selectedUnit,
    required this.onSelectSubject,
    required this.onSelectUnit,
  });

  final String selectedSubject;
  final String selectedUnit;
  final ValueChanged<String> onSelectSubject;
  final ValueChanged<String> onSelectUnit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Text(
              '탐색기',
              style: TextStyle(
                color: _kGreen,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(10),
              children: [
                for (final subject in aiFlowGraphCatalog) ...[
                  _ExplorerNode(
                    icon: Icons.folder_open_rounded,
                    title: subject.subject,
                    selected: subject.subject == selectedSubject,
                    depth: 0,
                    onTap: () => onSelectSubject(subject.subject),
                  ),
                  if (subject.subject == selectedSubject)
                    for (final unit in subject.units)
                      _ExplorerNode(
                        icon: Icons.folder_outlined,
                        title: unit,
                        selected: unit == selectedUnit,
                        depth: 1,
                        onTap: () => onSelectUnit(unit),
                      ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplorerMainPane extends StatelessWidget {
  const _ExplorerMainPane({
    required this.searchController,
    required this.onSearchChanged,
    required this.selectedSubject,
    required this.selectedUnit,
    required this.formulas,
    required this.examples,
    required this.selectedFormula,
    required this.selectedExample,
    required this.onSelectFormula,
    required this.onSelectExample,
    required this.onApplyExample,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String selectedSubject;
  final String selectedUnit;
  final List<AiFlowGraphFormulaSummary> formulas;
  final List<AiFlowGraphExample> examples;
  final AiFlowGraphFormulaSummary? selectedFormula;
  final AiFlowGraphExample? selectedExample;
  final ValueChanged<AiFlowGraphFormulaSummary> onSelectFormula;
  final ValueChanged<AiFlowGraphExample> onSelectExample;
  final ValueChanged<AiFlowGraphExample> onApplyExample;

  @override
  Widget build(BuildContext context) {
    final listPane = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$selectedSubject > $selectedUnit',
                  style: const TextStyle(
                    color: _kGreen,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: '예: 접선, 지수함수, 타원, 산점도',
                    prefixIcon: const Icon(Icons.manage_search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _kBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _kBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF89A489)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _ExplorerSectionHeader(title: '공식 파일', count: formulas.length),
                if (formulas.isEmpty)
                  const _ExplorerEmpty(label: '공식 항목이 없습니다.')
                else
                  for (final formula in formulas)
                    _ExplorerFileRow(
                      icon: Icons.functions_rounded,
                      title: formula.title,
                      subtitle: formula.formula,
                      subtitleIsLatex: true,
                      meta: formula.unit,
                      selected: identical(formula, selectedFormula),
                      onTap: () => onSelectFormula(formula),
                    ),
                const SizedBox(height: 14),
                _ExplorerSectionHeader(title: '예제 파일', count: examples.length),
                if (examples.isEmpty)
                  const _ExplorerEmpty(label: '예제 항목이 없습니다.')
                else
                  for (final example in examples)
                    _ExplorerFileRow(
                      icon: Icons.stacked_line_chart_rounded,
                      title: example.title,
                      subtitle: example.summary,
                      meta: example.unit,
                      selected: selectedExample?.id == example.id,
                      onTap: () => onSelectExample(example),
                    ),
              ],
            ),
          ),
        ],
      ),
    );

    final detailPane = _ExplorerDetailPane(
      formula: selectedFormula,
      example: selectedExample,
      onApplyExample: onApplyExample,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              Expanded(child: listPane),
              const SizedBox(height: 12),
              SizedBox(height: 320, child: detailPane),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: listPane),
            const SizedBox(width: 14),
            SizedBox(width: 360, child: detailPane),
          ],
        );
      },
    );
  }
}

class _ExplorerDetailPane extends StatelessWidget {
  const _ExplorerDetailPane({
    required this.formula,
    required this.example,
    required this.onApplyExample,
  });

  final AiFlowGraphFormulaSummary? formula;
  final AiFlowGraphExample? example;
  final ValueChanged<AiFlowGraphExample> onApplyExample;

  @override
  Widget build(BuildContext context) {
    final showExample = example != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: showExample
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '예제 상세',
                    style: TextStyle(
                      color: _kGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    example!.title,
                    style: const TextStyle(
                      color: _kGreen,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${example!.subject} · ${example!.unit}',
                    style: const TextStyle(
                      color: _kMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    example!.summary,
                    style: const TextStyle(
                      color: _kMuted,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kSurfaceTint,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Text(
                      example!.document.items
                          .map((item) => item.expression ?? item.label)
                          .join('\n'),
                      style: const TextStyle(
                        color: _kGreen,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '출처: ${example!.sourceLabel}',
                    style: const TextStyle(color: _kMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    example!.sourceUrl,
                    style: const TextStyle(color: _kMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => onApplyExample(example!),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('이 예제 불러오기'),
                    ),
                  ),
                ],
              )
            : formula != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '공식 상세',
                    style: TextStyle(
                      color: _kGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    formula!.title,
                    style: const TextStyle(
                      color: _kGreen,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formula!.unit,
                    style: const TextStyle(
                      color: _kMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LatexFormula(formula: formula!.formula, fontSize: 17),
                  const SizedBox(height: 12),
                  Text(
                    formula!.summary,
                    style: const TextStyle(
                      color: _kMuted,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kSurfaceTint,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kBorder),
                    ),
                    child: const Text(
                      '그래프로 옮길 여지가 있는 공식은 단원별로 예제와 함께 같은 폴더에 묶어 두었습니다.',
                      style: TextStyle(
                        color: _kGreen,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              )
            : const Center(
                child: Text(
                  '왼쪽에서 공식 또는 예제를 선택하세요.',
                  style: TextStyle(color: _kMuted),
                ),
              ),
      ),
    );
  }
}

class _ExplorerNode extends StatelessWidget {
  const _ExplorerNode({
    required this.icon,
    required this.title,
    required this.selected,
    required this.depth,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final int depth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 18.0, bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFF2F7F2) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? const Color(0xFF8DAC90) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: _kGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _kGreen,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
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
}

class _ExplorerSectionHeader extends StatelessWidget {
  const _ExplorerSectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _kGreen,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          _MiniBadge(label: '$count개'),
        ],
      ),
    );
  }
}

class _ExplorerFileRow extends StatelessWidget {
  const _ExplorerFileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.selected,
    required this.onTap,
    this.subtitleIsLatex = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String meta;
  final bool selected;
  final VoidCallback onTap;
  final bool subtitleIsLatex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFF6FAF6) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? const Color(0xFF90AA91) : _kBorder,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: _kGreen, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _kGreen,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        style: const TextStyle(
                          color: _kMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      subtitleIsLatex
                          ? _LatexFormula(formula: subtitle, fontSize: 13)
                          : Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _kMuted,
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                    ],
                  ),
                ),
                if (selected)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.check_circle_rounded, color: _kGreen),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExplorerEmpty extends StatelessWidget {
  const _ExplorerEmpty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(color: _kMuted, fontSize: 12.5),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _kBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x110B2617),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _GraphHiddenWhileDialogOpen extends StatelessWidget {
  const _GraphHiddenWhileDialogOpen();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '예제 탐색 중에는 그래프를 잠시 숨깁니다.',
        style: TextStyle(
          color: _kMuted,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
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
  const _CalculatorKeypad({required this.onInsert});

  final ValueChanged<String> onInsert;

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

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final key in _keys)
          InkWell(
            onTap: () => onInsert(key.value),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 46,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              child: Text(
                key.label,
                style: const TextStyle(
                  color: _kGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CalculatorKey {
  const _CalculatorKey(this.label, this.value);

  final String label;
  final String value;
}

class _LatexFormula extends StatelessWidget {
  const _LatexFormula({required this.formula, required this.fontSize});

  final String formula;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    try {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(
          formula,
          textStyle: TextStyle(
            color: _kGreen,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    } catch (_) {
      return Text(
        formula,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _kGreen,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      );
    }
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _kSurfaceTint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _kGreen,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FunctionDraftTile extends StatefulWidget {
  const _FunctionDraftTile({
    required this.draft,
    required this.compact,
    required this.onChanged,
    required this.onToggle,
    required this.onRemove,
    required this.onSubmitted,
  });

  final _GraphItemDraft draft;
  final bool compact;
  final VoidCallback onChanged;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final ValueChanged<String> onSubmitted;

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

  /// 필요한 변수는 수식 초안·입력란 포커스 상태·모바일 축약 여부다.
  /// 작동 원리는 데스크톱에서는 여러 줄 입력과 계산 패드를 제공하고,
  /// 모바일에서는 시스템 키보드에 맞춘 한 줄 입력으로 편집 영역을 줄이는 것이다.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kSurfaceTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: draft.errorText == null ? _kBorder : const Color(0xFFE4AEAE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: draft.enabled
                        ? _hexToColor(draft.colorHex)
                        : Colors.white,
                    border: Border.all(
                      color: _hexToColor(draft.colorHex),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    draft.enabled ? Icons.check_rounded : Icons.close_rounded,
                    size: 17,
                    color: draft.enabled
                        ? Colors.white
                        : _hexToColor(draft.colorHex),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  draft.label,
                  style: TextStyle(
                    color: _hexToColor(draft.colorHex),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          TextFieldTapRegion(
            child: Column(
              children: [
                TextField(
                  controller: draft.expressionController,
                  focusNode: _expressionFocusNode,
                  minLines: compact ? 1 : 2,
                  maxLines: compact ? 1 : 4,
                  keyboardType: compact
                      ? TextInputType.text
                      : TextInputType.multiline,
                  textInputAction: compact
                      ? TextInputAction.done
                      : TextInputAction.newline,
                  onChanged: (_) => onChanged(),
                  onSubmitted: onSubmitted,
                  onTapOutside: (_) => _expressionFocusNode.unfocus(),
                  decoration: InputDecoration(
                    border: compact
                        ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _kBorder),
                          )
                        : InputBorder.none,
                    enabledBorder: compact
                        ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _kBorder),
                          )
                        : InputBorder.none,
                    focusedBorder: compact
                        ? OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF2F7CF6),
                              width: 1.5,
                            ),
                          )
                        : InputBorder.none,
                    contentPadding: compact
                        ? const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          )
                        : null,
                    isDense: true,
                    hintText: '예: sin(x), x^2-1, log(x)',
                  ),
                ),
                _ExpressionPreview(controller: draft.expressionController),
                AnimatedSize(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.topCenter,
                  child: !compact && _expressionFocusNode.hasFocus
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _CalculatorKeypad(
                            onInsert: (token) {
                              draft.insertToken(token);
                              onChanged();
                            },
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          if (draft.errorText != null)
            Text(
              draft.errorText!,
              style: const TextStyle(
                color: Color(0xFFB33A3A),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _ExpressionPreview extends StatelessWidget {
  const _ExpressionPreview({required this.controller});

  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final listenable = controller;
    if (listenable == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: listenable,
      builder: (context, _) {
        final raw = listenable.text.trim();
        if (raw.isEmpty) {
          return const SizedBox.shrink();
        }
        final normalized = normalizeAiFlowExpression(raw);
        final latex = _expressionToLatex(normalized);
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.functions_rounded, size: 16, color: _kGreen),
              const SizedBox(width: 8),
              Expanded(child: _LatexFormula(formula: 'y=$latex', fontSize: 14)),
            ],
          ),
        );
      },
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

String _expressionToLatex(String expression) {
  return expression
      .replaceAll('*', r'\cdot ')
      .replaceAllMapped(RegExp(r'\bpi\b', caseSensitive: false), (_) => r'\pi')
      .replaceAllMapped(RegExp(r'\bsqrt\s*\(([^()]+)\)'), (match) {
        return '\\sqrt{${match.group(1) ?? ''}}';
      })
      .replaceAllMapped(RegExp(r'\b(abs|sin|cos|tan|log|ln)\s*\('), (match) {
        return '\\${match.group(1)}(';
      });
}

Color _hexToColor(String hex) {
  final normalized = hex.replaceFirst('#', '');
  final value = int.tryParse(normalized, radix: 16) ?? 0x1B402B;
  return Color(0xFF000000 | value);
}
