import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_example_catalog.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_expression.dart';
import 'package:s11/sessions/graph_tools/shared/jsx_graph_html_builder.dart';
import 'package:s11/sessions/graph_tools/ui/widgets/jsx_graph_embed.dart';
import 'package:s11/shared/theme/app_colors.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';

const _kGreen = AppColors.primary;
const _kBorder = Color(0xFFE2E7E2);
const _kMuted = Color(0xFF67796D);
const _kSurface = Colors.white;
const _kSurfaceTint = Color(0xFFF4F7F3);
const _kPalette = <Color>[
  Color(0xFF2F7CF6),
  Color(0xFFDD5F34),
  Color(0xFF238B5E),
  Color(0xFF8A52E8),
  Color(0xFFD6477C),
  Color(0xFF927A1F),
];

class JsxGraphPage extends StatefulWidget {
  const JsxGraphPage({
    super.key,
    this.embedEnabled = true,
  });

  final bool embedEnabled;

  @override
  State<JsxGraphPage> createState() => _JsxGraphPageState();
}

class _JsxGraphPageState extends State<JsxGraphPage> {
  final List<_GraphItemDraft> _drafts = <_GraphItemDraft>[];
  final List<_GraphParameterDraft> _parameters = <_GraphParameterDraft>[];

  late AiFlowGraphExample _selectedExample;
  String _graphHtml = '';
  int _nextDraftId = 0;
  bool _showAxes = true;
  bool _showGrid = true;
  bool _lockViewport = false;
  bool _degreeMode = false;
  bool _catalogDialogOpen = false;
  bool _hasActiveExampleContext = true;
  String? _editorMessage;

  @override
  void initState() {
    super.initState();
    _selectedExample = aiFlowGraphExamples.first;
    _loadExample(_selectedExample, rebuild: true);
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _loadExample(AiFlowGraphExample example, {bool rebuild = false}) {
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
        example.document.settings.parameters.map(_GraphParameterDraft.fromParameter),
      );

    _selectedExample = example;
    _hasActiveExampleContext = true;
    _showAxes = example.document.settings.showAxes;
    _showGrid = example.document.settings.showGrid;
    _lockViewport = example.document.settings.lockViewport;
    _degreeMode = example.document.settings.degreeMode;
    _editorMessage = null;

    if (rebuild) {
      _rebuildGraph();
    }
  }

  void _rebuildGraph() {
    _graphHtml = buildAiFlowGraphHtml(_buildDocument());
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
      _rebuildGraph();
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
      _rebuildGraph();
    });
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
      _loadExample(selected, rebuild: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLinux = !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

    return Scaffold(
      backgroundColor: AppColors.background,
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
                      final graphPanel = _buildGraphPanel(isLinux: isLinux);
                      final editorPanel = _buildEditorPanel(compact: compact);

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
                          SizedBox(width: 400, child: editorPanel),
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

  Widget _buildHeader() {
    return Ios26TopBar(
      brandColor: _kGreen,
      title: 'AIFlow',
      onBack: () => Navigator.of(context).maybePop(),
      trailingIcons: [
        Ios26ActionIcon(
          icon: Icons.info_outline_rounded,
          label: '예제',
          onTap: _showInfoDialog,
        ),
      ],
    );
  }

  Widget _buildGraphPanel({required bool isLinux}) {
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FBF8),
            border: Border.all(color: _kBorder),
          ),
          child: _catalogDialogOpen
              ? const _GraphHiddenWhileDialogOpen()
              : isLinux
                  ? const Center(child: Text('이 그래프 웹뷰는 Linux에서 지원되지 않습니다.'))
                  : widget.embedEnabled
                      ? buildJsxGraphEmbed(_graphHtml)
                      : const _GraphEmbedDisabledForTesting(),
        ),
      ),
    );
  }

  Widget _buildEditorPanel({required bool compact}) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasActiveExampleContext) ...[
            Text(
              _selectedExample.subject,
              style: const TextStyle(
                color: _kGreen,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedExample.title,
              style: const TextStyle(
                color: _kGreen,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedExample.summary,
              style: const TextStyle(
                color: _kMuted,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kSurfaceTint,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '현재 그래프 구성',
                    style: TextStyle(
                      color: _kGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedExample.unit,
                    style: const TextStyle(
                      color: _kMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
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
                  _rebuildGraph();
                });
              },
            ),
            const SizedBox(height: 10),
          ],
          if (compact)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _drafts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _buildDraftTile(_drafts[index]),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _drafts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _buildDraftTile(_drafts[index]),
              ),
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
                    _rebuildGraph();
                  });
                },
              ),
              FilterChip(
                label: const Text('격자'),
                selected: _showGrid,
                onSelected: (value) {
                  setState(() {
                    _showGrid = value;
                    _rebuildGraph();
                  });
                },
              ),
              FilterChip(
                label: const Text('뷰 고정'),
                selected: _lockViewport,
                onSelected: (value) {
                  setState(() {
                    _lockViewport = value;
                    _rebuildGraph();
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
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _applyCurrentDrafts,
              style: FilledButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.stacked_line_chart_rounded),
              label: const Text('그래프 갱신'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftTile(_GraphItemDraft draft) {
    if (draft.type == AiFlowGraphItemType.function) {
      return _FunctionDraftTile(
        draft: draft,
        onChanged: () {
          setState(() {
            draft.errorText = null;
            _editorMessage = null;
          });
        },
        onToggle: () {
          setState(() {
            draft.enabled = !draft.enabled;
            _rebuildGraph();
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
  late String _selectedSubject;
  late String _selectedUnit;
  AiFlowGraphFormulaSummary? _selectedFormula;
  AiFlowGraphExample? _selectedExample;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedSubject = widget.initialExample.subject;
    _selectedUnit = widget.initialExample.unit;
    _selectedExample = widget.initialExample;
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  AiFlowGraphSubjectCatalog get _subjectCatalog => aiFlowGraphCatalog.firstWhere(
        (subject) => subject.subject == _selectedSubject,
      );

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
    final catalog = aiFlowGraphCatalog.firstWhere((item) => item.subject == subject);
    setState(() {
      _selectedSubject = subject;
      _selectedUnit = catalog.units.first;
      _query = '';
      _searchController.clear();
      _selectedFormula = catalog.formulas.isNotEmpty ? catalog.formulas.first : null;
      _selectedExample = catalog.examples.isNotEmpty ? catalog.examples.first : null;
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
                                onSearchChanged: (value) => setState(() => _query = value),
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
                              onSearchChanged: (value) => setState(() => _query = value),
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
                _ExplorerSectionHeader(
                  title: '공식 파일',
                  count: formulas.length,
                ),
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
                _ExplorerSectionHeader(
                  title: '예제 파일',
                  count: examples.length,
                ),
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
                    style: const TextStyle(
                      color: _kMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    example!.sourceUrl,
                    style: const TextStyle(
                      color: _kMuted,
                      fontSize: 12,
                    ),
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
                      _LatexFormula(
                        formula: formula!.formula,
                        fontSize: 17,
                      ),
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
  const _ExplorerSectionHeader({
    required this.title,
    required this.count,
  });

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
    return const Center(
      child: Text(
        '그래프 임베드 비활성화',
        style: TextStyle(
          color: _kMuted,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PracticePanel extends StatelessWidget {
  const _PracticePanel({
    required this.parameters,
    required this.onChanged,
  });

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
              value: parameter.value.clamp(parameter.min, parameter.max).toDouble(),
              min: parameter.min,
              max: parameter.max,
              divisions: _sliderDivisions(parameter),
              label: _formatNumber(parameter.value),
              onChanged: (value) => onChanged(parameter, _snapToStep(parameter, value)),
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
  const _LatexFormula({
    required this.formula,
    required this.fontSize,
  });

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

class _FunctionDraftTile extends StatelessWidget {
  const _FunctionDraftTile({
    required this.draft,
    required this.onChanged,
    required this.onToggle,
    required this.onRemove,
    required this.onSubmitted,
  });

  final _GraphItemDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final ValueChanged<String> onSubmitted;

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
                    color: draft.enabled ? _hexToColor(draft.colorHex) : Colors.white,
                    border: Border.all(
                      color: _hexToColor(draft.colorHex),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    draft.enabled ? Icons.check_rounded : Icons.close_rounded,
                    size: 17,
                    color: draft.enabled ? Colors.white : _hexToColor(draft.colorHex),
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
          TextField(
            controller: draft.expressionController,
            onChanged: (_) => onChanged(),
            onSubmitted: onSubmitted,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: '예: sin(x), x^2-1, log(x), sqrt(9-x^2)',
            ),
          ),
          const SizedBox(height: 8),
          _CalculatorKeypad(
            onInsert: (token) {
              draft.insertToken(token);
              onChanged();
            },
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
      colorHex: item.colorHex.isNotEmpty ? item.colorHex : _colorToHex(fallbackColor),
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
      parameter.min + ((value - parameter.min) / parameter.step).round() * parameter.step;
  return snapped.clamp(parameter.min, parameter.max).toDouble();
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

Color _hexToColor(String hex) {
  final normalized = hex.replaceFirst('#', '');
  final value = int.tryParse(normalized, radix: 16) ?? 0x1B402B;
  return Color(0xFF000000 | value);
}
