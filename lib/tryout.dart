import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:s11/models/content_block.dart';
import 'package:s11/pages/solve_analysis_page.dart';
import 'package:s11/services/api_client.dart';
import 'package:s11/widgets/content_blocks_view.dart';

class ProblemSolveConfig {
  const ProblemSolveConfig({
    this.questionCount = 1,
    this.hashTags = const <String>[],
    this.gradeImmediately = true,
    this.minDifficultyTier = 3,
    this.maxDifficultyTier = 3,
  });

  final int questionCount;
  final List<String> hashTags;
  final bool gradeImmediately;
  final int minDifficultyTier;
  final int maxDifficultyTier;

  ProblemSolveConfig copyWith({
    int? questionCount,
    List<String>? hashTags,
    bool? gradeImmediately,
    int? minDifficultyTier,
    int? maxDifficultyTier,
  }) {
    return ProblemSolveConfig(
      questionCount: questionCount ?? this.questionCount,
      hashTags: hashTags ?? this.hashTags,
      gradeImmediately: gradeImmediately ?? this.gradeImmediately,
      minDifficultyTier: minDifficultyTier ?? this.minDifficultyTier,
      maxDifficultyTier: maxDifficultyTier ?? this.maxDifficultyTier,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_count': questionCount,
      'hash_tags': hashTags,
      'grade_immediately': gradeImmediately,
      'min_difficulty_tier': minDifficultyTier,
      'max_difficulty_tier': maxDifficultyTier,
    };
  }
}

class BuildpageWidget extends StatefulWidget {
  const BuildpageWidget({super.key, this.config});

  static const String routeName = 'buildpage';
  static const String routePath = '/buildpage';

  final ProblemSolveConfig? config;

  @override
  State<BuildpageWidget> createState() => _BuildpageWidgetState();
}

enum _ToolMode { pen, eraser }

class _BuildpageWidgetState extends State<BuildpageWidget> {
  static const double _baseWidth = 1920;
  static const double _baseHeight = 1080;
  static const double _expandedHeight = 2500;
  static const double _scrollbarThickness = 12;
  static const double _eraserRadius = 26;
  static const double _minPointDistance = 0.6;
  static const Color _kGreen = Color(0xFF1B402B);

  static const Color _penRed = Color(0xFFE53935);
  static const Color _penBlue = Color(0xFF1E88E5);
  static const List<Color> _penColors = [_penRed, _penBlue, Colors.black];
  static const List<double> _penWidths = [5, 3, 1];
  static const Map<int, _TierParams> _tierParams = {
    1: _TierParams(solvesCount: 2, strategyLevel: 1, branchConditions: 0),
    2: _TierParams(solvesCount: 3, strategyLevel: 1, branchConditions: 0),
    3: _TierParams(solvesCount: 4, strategyLevel: 2, branchConditions: 1),
    4: _TierParams(solvesCount: 5, strategyLevel: 2, branchConditions: 1),
    5: _TierParams(solvesCount: 6, strategyLevel: 3, branchConditions: 2),
  };

  static const String _problemText = '''''';

  final math.Random _rng = math.Random();

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<int> _paintVersion = ValueNotifier<int>(0);

  final List<_Stroke> _strokes = <_Stroke>[];
  final List<_UndoAction> _undoStack = <_UndoAction>[];
  final List<_Stroke> _pendingEraseRemoved = <_Stroke>[];
  final List<_InputEvent> _inputEvents = <_InputEvent>[];
  final List<_ProblemSnapshot?> _problemSnapshots = <_ProblemSnapshot?>[];
  final Stopwatch _problemClock = Stopwatch();

  double _problemElapsedOffset = 0.0;
  int _nextStrokeId = 0;

  _Stroke? _currentStroke;
  int _nextStrokeOrder = 0;
  int? _activePointer;
  Offset? _lastFilteredPoint;

  _ToolMode _toolMode = _ToolMode.pen;
  Color _penColor = Colors.black;
  double _penWidth = 3;

  bool _scrollEnabled = false;

  Offset? _eraserPosition;
  bool _eraserActive = false;

  int _problemCount = 1;
  int _currentProblemIndex = 0;
  List<String> _hashTags = <String>[];
  bool _gradeImmediately = true;
  int _minDifficultyTier = 3;
  int _maxDifficultyTier = 3;
  bool _analysisBusy = false;
  bool _questLoading = false;
  String? _questError;
  final List<Map<String, dynamic>?> _quests = <Map<String, dynamic>?>[];

  @override
  void initState() {
    super.initState();
    _applyConfig(widget.config ?? const ProblemSolveConfig());
    _loadQuestsForTags();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _paintVersion.dispose();
    _problemClock.stop();
    super.dispose();
  }

  double get _logicalHeight => _scrollEnabled ? _expandedHeight : _baseHeight;

  void _bumpPaint() {
    _paintVersion.value = _paintVersion.value + 1;
  }

  void _setToolMode(_ToolMode mode) {
    if (_toolMode == mode) return;
    setState(() {
      _toolMode = mode;
    });
  }

  void _toggleScroll() {
    setState(() {
      _scrollEnabled = !_scrollEnabled;
      if (!_scrollEnabled) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _applyConfig(ProblemSolveConfig config) {
    _problemCount = math.max(1, config.questionCount);
    _hashTags = List<String>.from(config.hashTags);
    _gradeImmediately = config.gradeImmediately;
    final minTier = math.min(config.minDifficultyTier, config.maxDifficultyTier)
        .clamp(1, 5)
        .toInt();
    final maxTier = math.max(config.minDifficultyTier, config.maxDifficultyTier)
        .clamp(1, 5)
        .toInt();
    _minDifficultyTier = minTier;
    _maxDifficultyTier = maxTier;
    _problemSnapshots
      ..clear()
      ..addAll(List<_ProblemSnapshot?>.filled(_problemCount, null));
    _currentProblemIndex = 0;
    _problemElapsedOffset = 0.0;
    _problemClock.stop();
    _problemClock.reset();
    _quests
      ..clear()
      ..addAll(List<Map<String, dynamic>?>.filled(_problemCount, null));
    _questError = null;
    _questLoading = false;
  }

  int _tierForProblemIndex(int index) {
    final minTier = math.min(_minDifficultyTier, _maxDifficultyTier);
    final maxTier = math.max(_minDifficultyTier, _maxDifficultyTier);
    if (_problemCount <= 1 || minTier == maxTier) {
      return minTier.clamp(1, 5).toInt();
    }
    final ratio = index / (_problemCount - 1);
    final value = minTier + (maxTier - minTier) * ratio;
    return value.round().clamp(1, 5).toInt();
  }

  int _tagCountForTier(int tier) {
    switch (tier.clamp(1, 5)) {
      case 1:
        return 1;
      case 2:
        return 1 + _rng.nextInt(3);
      case 3:
        return 3;
      case 4:
        return 3 + _rng.nextInt(3);
      case 5:
        return 5;
    }
    return 3;
  }

  int _maxTagCountForTier(int tier) {
    switch (tier.clamp(1, 5)) {
      case 1:
        return 1;
      case 2:
        return 3;
      case 3:
        return 3;
      case 4:
        return 5;
      case 5:
        return 5;
    }
    return 3;
  }

  List<String> _pickRandomTags(List<String> source, int count) {
    if (source.isEmpty) return const [];
    if (count <= 0) return const [];
    if (source.length <= count) return List<String>.from(source);
    final pool = List<String>.from(source);
    pool.shuffle(_rng);
    return pool.take(count).toList();
  }

  Map<String, dynamic>? get _currentQuest {
    if (_quests.isEmpty || _currentProblemIndex >= _quests.length) {
      return null;
    }
    return _quests[_currentProblemIndex];
  }

  String _currentQuestId() {
    final quest = _currentQuest;
    if (quest == null) return '';
    final header = quest['header'] as Map<String, dynamic>? ?? {};
    return header['quest_id']?.toString() ?? '';
  }

  List<String> _currentQuestModels() {
    // TEMP: force Gemini Vision OCR only (disable pix2text).
    return const ['gemini-vision'];
  }

  List<ContentBlock> _currentQuestTitleBlocks() {
    final quest = _currentQuest;
    if (quest == null) return [];
    final data = quest['data'] as Map<String, dynamic>? ?? {};
    return parseContentBlocks(data['quest_title']);
  }

  Future<void> _loadQuestsForTags() async {
    if (_hashTags.isEmpty) {
      setState(() {
        _questError = '해시태그를 먼저 선택하세요.';
      });
      return;
    }
    setState(() {
      _questLoading = true;
      _questError = null;
    });

    try {
      final reuseEnabled = _minDifficultyTier == _maxDifficultyTier &&
          _hashTags.length <= _maxTagCountForTier(_minDifficultyTier);
      final matches =
          reuseEnabled ? await _searchQuestsByTags(_hashTags) : <Map<String, dynamic>>[];
      final selected = <Map<String, dynamic>>[];
      var matchIndex = 0;
      for (var i = 0; i < _problemCount; i++) {
        if (matchIndex < matches.length) {
          selected.add(matches[matchIndex]);
          matchIndex += 1;
          continue;
        }
        final tier = _tierForProblemIndex(i);
        final params = _tierParams[tier] ?? _tierParams[3]!;
        final tagCount = _tagCountForTier(tier);
        final tags = _pickRandomTags(_hashTags, tagCount);
        final generated = await ApiClient.instance.generateQuest(
          hashTags: tags,
          solvesCount: params.solvesCount,
          strategyLevel: params.strategyLevel,
          branchConditions: params.branchConditions,
          strictTags: false,
        );
        selected.add(generated);
      }

      for (var i = 0; i < _problemCount; i++) {
        _quests[i] = selected[i];
      }

      setState(() {
        _questLoading = false;
        _questError = null;
      });
    } catch (error, stackTrace) {
      debugPrint('[ProblemSolve] Failed to load quests: $error');
      debugPrint(stackTrace.toString());
      setState(() {
        _questLoading = false;
        _questError = '문제 불러오기 실패';
      });
    }
  }

  Future<List<Map<String, dynamic>>> _searchQuestsByTags(
    List<String> tags,
  ) async {
    if (tags.isEmpty) return [];
    final primary = tags.first;
    final results = await ApiClient.instance.searchQuests(
      hashTag: primary,
      pageSize: 200,
    );
    return results.where((quest) => _questHasAllTags(quest, tags)).toList();
  }

  bool _questHasAllTags(Map<String, dynamic> quest, List<String> tags) {
    final info = quest['info'] as Map<String, dynamic>? ?? {};
    final questTags = (info['hash_tag'] as List<dynamic>? ?? [])
        .map((tag) => _normalizeTag(tag.toString()))
        .where((tag) => tag.isNotEmpty)
        .toSet();
    for (final tag in tags) {
      final normalized = _normalizeTag(tag);
      if (normalized.isEmpty) continue;
      if (!questTags.contains(normalized)) {
        return false;
      }
    }
    return true;
  }

  String _normalizeTag(String tag) {
    return tag.trim().toLowerCase().replaceFirst('#', '');
  }

  void _ensureClockRunning() {
    if (!_problemClock.isRunning) {
      _problemClock.start();
    }
  }

  void _pauseProblemClock() {
    if (_problemClock.isRunning) {
      _problemElapsedOffset += _problemClock.elapsedMicroseconds / 1e6;
      _problemClock.stop();
      _problemClock.reset();
    }
  }

  double _nowSeconds() {
    final elapsed = _problemClock.isRunning
        ? _problemClock.elapsedMicroseconds / 1e6
        : 0.0;
    return _problemElapsedOffset + elapsed;
  }

  void _saveCurrentProblem() {
    _pauseProblemClock();
    _problemSnapshots[_currentProblemIndex] = _ProblemSnapshot(
      strokes: List<_Stroke>.from(_strokes),
      undoStack: List<_UndoAction>.from(_undoStack),
      pendingEraseRemoved: List<_Stroke>.from(_pendingEraseRemoved),
      inputEvents: List<_InputEvent>.from(_inputEvents),
      nextStrokeOrder: _nextStrokeOrder,
      nextStrokeId: _nextStrokeId,
      elapsedSeconds: _problemElapsedOffset,
    );
  }

  void _loadProblem(int index) {
    final snapshot = _problemSnapshots[index];
    _strokes
      ..clear()
      ..addAll(snapshot?.strokes ?? const []);
    _undoStack
      ..clear()
      ..addAll(snapshot?.undoStack ?? const []);
    _pendingEraseRemoved
      ..clear()
      ..addAll(snapshot?.pendingEraseRemoved ?? const []);
    _inputEvents
      ..clear()
      ..addAll(snapshot?.inputEvents ?? const []);
    _nextStrokeOrder = snapshot?.nextStrokeOrder ?? 0;
    _nextStrokeId = snapshot?.nextStrokeId ?? 0;
    _problemElapsedOffset = snapshot?.elapsedSeconds ?? 0.0;
    _problemClock.stop();
    _problemClock.reset();
    _currentStroke = null;
    _activePointer = null;
    _lastFilteredPoint = null;
    _eraserActive = false;
    _eraserPosition = null;
    _bumpPaint();
  }

  void _goToProblem(int index) {
    if (index == _currentProblemIndex) return;
    if (index < 0 || index >= _problemCount) return;
    if (_toolMode == _ToolMode.pen) {
      _finishStroke();
    } else {
      _finishEraser();
    }
    _activePointer = null;
    _saveCurrentProblem();
    setState(() {
      _currentProblemIndex = index;
      _loadProblem(index);
    });
  }

  void _goToNextProblem() => _goToProblem(_currentProblemIndex + 1);

  void _goToPreviousProblem() => _goToProblem(_currentProblemIndex - 1);

  Future<void> _openPenSettings() async {
    final result = await showModalBottomSheet<_PenSettings>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        var tempColor = _penColor;
        var tempWidth = _penWidth;
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '펜 설정',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  const Text('색상', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      for (final color in _penColors)
                        _ColorChip(
                          color: color,
                          selected: tempColor == color,
                          onTap: () => setState(() => tempColor = color),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('굵기', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      for (final width in _penWidths)
                        _WidthChip(
                          width: width,
                          selected: tempWidth == width,
                          onTap: () => setState(() => tempWidth = width),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('취소'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(
                            _PenSettings(color: tempColor, width: tempWidth),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B402B),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('적용'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;
    setState(() {
      _penColor = result.color;
      _penWidth = result.width;
      _toolMode = _ToolMode.pen;
    });
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _ensureClockRunning();
    _inputEvents.add(_InputEvent.undo(_nowSeconds()));
    final action = _undoStack.removeLast();
    if (action is _AddAction) {
      _strokes.remove(action.stroke);
    } else if (action is _RemoveAction) {
      _strokes.addAll(action.strokes);
      _strokes.sort((a, b) => a.order.compareTo(b.order));
    }
    _bumpPaint();
  }

  void _clearAll() {
    if (_strokes.isEmpty && _currentStroke == null) return;
    final removed = <_Stroke>[
      ..._strokes,
      if (_currentStroke != null) _currentStroke!,
    ];
    _strokes.clear();
    _currentStroke = null;
    if (removed.isNotEmpty) {
      _undoStack.add(_RemoveAction(removed));
    }
    _bumpPaint();
  }

  double _uiScale(BuildContext context, {double min = 0.6, double max = 1.0}) {
    final width = MediaQuery.of(context).size.width;
    final scale = width / 1100;
    if (scale < min) return min;
    if (scale > max) return max;
    return scale;
  }

  void _handlePointerDown(PointerDownEvent event, double scale) {
    if (_activePointer != null) return;
    final position = _toLogicalPosition(event.localPosition, scale);
    if (!_withinCanvas(position)) return;
    _activePointer = event.pointer;
    _ensureClockRunning();
    if (_toolMode == _ToolMode.pen) {
      _startStroke(position, _normalizePressure(event));
    } else {
      _startEraser(position);
    }
  }

  void _handlePointerMove(PointerMoveEvent event, double scale) {
    if (_activePointer != event.pointer) return;
    final position = _toLogicalPosition(event.localPosition, scale);
    if (!_withinCanvas(position)) return;
    if (_toolMode == _ToolMode.pen) {
      _appendStroke(position, _normalizePressure(event));
    } else {
      _updateEraser(position);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;
    if (_toolMode == _ToolMode.pen) {
      _finishStroke();
    } else {
      _finishEraser();
    }
    _activePointer = null;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;
    if (_toolMode == _ToolMode.pen) {
      _finishStroke();
    } else {
      _finishEraser();
    }
    _activePointer = null;
  }

  void _startStroke(Offset position, double pressure) {
    _lastFilteredPoint = null;
    final startTime = _nowSeconds();
    final stroke = _Stroke(
      id: 's${_nextStrokeId++}',
      color: _penColor,
      baseWidth: _penWidth,
      order: _nextStrokeOrder++,
      startTime: startTime,
    );
    _currentStroke = stroke;
    _appendStroke(position, pressure);
  }

  void _appendStroke(Offset position, double pressure) {
    final stroke = _currentStroke;
    if (stroke == null) return;
    final filtered = _filterPoint(position);
    if (stroke.points.isNotEmpty) {
      final lastPoint = stroke.points.last.position;
      if ((filtered - lastPoint).distance < _minPointDistance) return;
    }
    stroke.addPoint(filtered, pressure, _nowSeconds());
    _bumpPaint();
  }

  void _finishStroke() {
    final stroke = _currentStroke;
    if (stroke != null && stroke.points.isNotEmpty) {
      stroke.endTime = stroke.points.last.timestamp;
      _strokes.add(stroke);
      _undoStack.add(_AddAction(stroke));
    }
    _currentStroke = null;
    _lastFilteredPoint = null;
    _bumpPaint();
  }

  void _startEraser(Offset position) {
    _ensureClockRunning();
    _pendingEraseRemoved.clear();
    _eraserActive = true;
    _eraserPosition = position;
    _eraseAt(position);
    _bumpPaint();
  }

  void _updateEraser(Offset position) {
    _eraserActive = true;
    _eraserPosition = position;
    _eraseAt(position);
    _bumpPaint();
  }

  void _finishEraser() {
    if (_pendingEraseRemoved.isNotEmpty) {
      _undoStack.add(_RemoveAction(List<_Stroke>.from(_pendingEraseRemoved)));
      _pendingEraseRemoved.clear();
    }
    _eraserActive = false;
    _eraserPosition = null;
    _bumpPaint();
  }

  void _eraseAt(Offset position) {
    if (_strokes.isEmpty) return;
    final toRemove = <_Stroke>[];
    for (final stroke in _strokes) {
      if (!stroke.hitTestCircle(position, _eraserRadius)) continue;
      toRemove.add(stroke);
    }
    if (toRemove.isEmpty) return;
    final timestamp = _nowSeconds();
    _strokes.removeWhere(toRemove.contains);
    _pendingEraseRemoved.addAll(toRemove);
    for (final stroke in toRemove) {
      final region = stroke.resolvedBounds;
      if (region == null) continue;
      _inputEvents.add(
        _InputEvent.erase(
          timestamp: timestamp,
          region: region,
          strokeId: stroke.id,
        ),
      );
    }
  }

  bool _withinCanvas(Offset position) {
    return position.dx >= 0 &&
        position.dy >= 0 &&
        position.dx <= _baseWidth &&
        position.dy <= _logicalHeight;
  }

  Offset _toLogicalPosition(Offset localPosition, double scale) {
    if (scale <= 0) return localPosition;
    return Offset(localPosition.dx / scale, localPosition.dy / scale);
  }

  Offset _filterPoint(Offset next) {
    const smoothing = 0.55;
    final last = _lastFilteredPoint;
    if (last == null) {
      _lastFilteredPoint = next;
      return next;
    }
    final filtered = Offset(
      last.dx + (next.dx - last.dx) * smoothing,
      last.dy + (next.dy - last.dy) * smoothing,
    );
    _lastFilteredPoint = filtered;
    return filtered;
  }

  double _normalizePressure(PointerEvent event) {
    final min = event.pressureMin;
    final max = event.pressureMax;
    final value = event.pressure;
    if (max <= min) return 1.0;
    final normalized = (value - min) / (max - min);
    return normalized.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeader(),
              Expanded(child: _buildCanvasArea()),
              _buildToolbar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final scale = _uiScale(context);
    return SizedBox(
      height: 72 * scale,
      child: Row(
        children: [
          SizedBox(width: 16 * scale),
          IconButton(
            iconSize: 28 * scale,
            icon: const Icon(Icons.arrow_back, color: _kGreen),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Center(
              child: Text(
                'AIFlow',
                style: TextStyle(
                  fontSize: 36 * scale,
                  fontWeight: FontWeight.bold,
                  color: _kGreen,
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                iconSize: 28 * scale,
                icon: const Icon(Icons.info_outline, color: _kGreen),
                onPressed: () {},
              ),
              SizedBox(width: 8 * scale),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rightPadding = _scrollEnabled ? _scrollbarThickness + 6 : 0.0;
        final drawableWidth = math.max(
          0.0,
          constraints.maxWidth - rightPadding,
        );
        final double scale = drawableWidth <= 0
            ? 1.0
            : drawableWidth / _baseWidth;
        final double scaledHeight = _logicalHeight * scale;
        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: _scrollEnabled,
          interactive: _scrollEnabled,
          thickness: _scrollbarThickness,
          radius: const Radius.circular(6),
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: _scrollEnabled
                ? const ClampingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: constraints.maxWidth,
              height: scaledHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(right: rightPadding),
                      child: Transform.scale(
                        alignment: Alignment.topLeft,
                        scale: scale,
                        child: SizedBox(
                          width: _baseWidth,
                          height: _logicalHeight,
                          child: _buildProblemContent(),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(right: rightPadding),
                      child: RepaintBoundary(
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (event) =>
                              _handlePointerDown(event, scale),
                          onPointerMove: (event) =>
                              _handlePointerMove(event, scale),
                          onPointerUp: _handlePointerUp,
                          onPointerCancel: _handlePointerCancel,
                          child: ValueListenableBuilder<int>(
                            valueListenable: _paintVersion,
                            builder: (context, _, __) {
                              return CustomPaint(
                                painter: _StrokePainter(
                                  strokes: _strokes,
                                  currentStroke: _currentStroke,
                                  eraserPosition: _eraserActive
                                      ? _eraserPosition
                                      : null,
                                  eraserRadius: _eraserRadius,
                                  scale: scale,
                                  logicalSize: Size(_baseWidth, _logicalHeight),
                                  backgroundColor: Colors.transparent,
                                  repaint: _paintVersion,
                                ),
                                size: Size(drawableWidth, scaledHeight),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProblemContent() {
    final titleBlocks = _currentQuestTitleBlocks();
    final fallbackBlocks = parseContentBlocks(_problemText);
    final displayBlocks = titleBlocks.isEmpty ? fallbackBlocks : titleBlocks;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(80, 20, 80, 0),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_questLoading)
              Row(
                children: const [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('문제 불러오는 중...'),
                ],
              )
            else if (_questError != null)
              Text(
                _questError!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            const SizedBox(height: 12),
            ContentBlocksView(
              blocks: displayBlocks,
              textStyle: const TextStyle(fontSize: 22, height: 1.4),
              latexStyle: const TextStyle(fontSize: 22, height: 1.4),
              inline: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    final activeColor = const Color(0xFF1B402B);
    final inactiveColor = const Color(0xFF6B6B6B);
    return Container(
      width: 800,
      height: 70,
      decoration: const BoxDecoration(
        color: Color(0xFFE9E9E9),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ToolbarIcon(
              icon: Icons.edit_outlined,
              size: 48,
              color: _toolMode == _ToolMode.pen ? activeColor : inactiveColor,
              onTap: () => _setToolMode(_ToolMode.pen),
            ),
            const SizedBox(width: 20),
            _ToolbarIcon(
              icon: Icons.cleaning_services_outlined,
              size: 40,
              color: _toolMode == _ToolMode.eraser
                  ? activeColor
                  : inactiveColor,
              onTap: () => _setToolMode(_ToolMode.eraser),
            ),
            const SizedBox(width: 20),
            _ToolbarIcon(
              icon: Icons.color_lens_outlined,
              size: 48,
              color: _penColor,
              onTap: _openPenSettings,
            ),
            const SizedBox(width: 20),
            const SizedBox(
              height: 100,
              child: VerticalDivider(thickness: 2, color: Color(0xFFE0E3E7)),
            ),
            const SizedBox(width: 20),
            _ToolbarIcon(
              icon: Icons.undo_outlined,
              size: 40,
              color: _undoStack.isEmpty ? inactiveColor : activeColor,
              onTap: _undoStack.isEmpty ? null : _undo,
            ),
            const SizedBox(width: 20),
            _ToolbarIcon(
              icon: Icons.delete_outline,
              size: 48,
              color: (_strokes.isEmpty && _currentStroke == null)
                  ? inactiveColor
                  : activeColor,
              onTap: (_strokes.isEmpty && _currentStroke == null)
                  ? null
                  : _clearAll,
            ),
            const SizedBox(width: 20),
            const SizedBox(
              height: 100,
              child: VerticalDivider(thickness: 2, color: Color(0xFFE0E3E7)),
            ),
            const SizedBox(width: 20),
            _ToolbarIcon(
              icon: Icons.auto_fix_high,
              size: 40,
              color: _scrollEnabled ? activeColor : inactiveColor,
              onTap: _toggleScroll,
            ),
            const SizedBox(width: 20),
            const SizedBox(
              height: 100,
              child: VerticalDivider(thickness: 2, color: Color(0xFFE0E3E7)),
            ),
            const SizedBox(width: 20),
            if (_gradeImmediately)
              _ToolbarIcon(
                icon: Icons.arrow_forward,
                size: 44,
                color:
                    (_strokes.isEmpty && _currentStroke == null) ||
                        _analysisBusy
                    ? inactiveColor
                    : activeColor,
                onTap:
                    (_strokes.isEmpty && _currentStroke == null) ||
                        _analysisBusy
                    ? null
                    : _handleGrade,
              )
            else ...[
              _ToolbarIcon(
                icon: Icons.arrow_back_ios_new,
                size: 32,
                color: _currentProblemIndex == 0 ? inactiveColor : activeColor,
                onTap: _currentProblemIndex == 0 ? null : _goToPreviousProblem,
              ),
              const SizedBox(width: 8),
              Text(
                '${_currentProblemIndex + 1}/$_problemCount',
                style: TextStyle(
                  color: activeColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              _ToolbarIcon(
                icon: Icons.arrow_forward_ios,
                size: 32,
                color: _currentProblemIndex >= _problemCount - 1
                    ? inactiveColor
                    : activeColor,
                onTap: _currentProblemIndex >= _problemCount - 1
                    ? null
                    : _goToNextProblem,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleGrade() async {
    if (_analysisBusy) return;
    if (_toolMode == _ToolMode.pen && _currentStroke != null) {
      _finishStroke();
    } else if (_toolMode == _ToolMode.eraser && _eraserActive) {
      _finishEraser();
    }
    setState(() => _analysisBusy = true);
    final navigator = Navigator.of(context);
    var gradingShown = false;
    navigator.push(
      MaterialPageRoute(builder: (_) => const _GradingScreen()),
    );
    gradingShown = true;
    try {
      final payload = await _buildLlmPayload();
      final response = await ApiClient.instance.submitSolveAnalysis(
        payload: payload,
      );
      if (!mounted) return;
      final analysis = response.analysis.trim();
      if (response.warnings.isNotEmpty) {
        debugPrint('Solve analysis warnings: ${response.warnings.join(', ')}');
      }
      final quest = _currentQuest;
      final rawSteps = payload['step_correctness'] as List<dynamic>? ?? [];
      final fallbackResults = rawSteps
          .whereType<Map<String, dynamic>>()
          .map(_StepCorrectness.fromJson)
          .toList();
      final ocrBlocks = _parseOcrBlocksFromResponse(response.recognizedText);
      final steps = ocrBlocks.isNotEmpty
          ? _segmentSteps(ocrBlocks, _strokes)
          : <_SolutionStep>[];
      final referenceSteps = quest == null
          ? <_ReferenceSolveStep>[]
          : _ReferenceSolveStep.fromServer(quest['solves']);
      final evaluated = steps.isNotEmpty
          ? _evaluateStepCorrectness(steps, referenceSteps)
          : fallbackResults;
      final stepCorrectness = evaluated.map((result) => result.toJson()).toList();
      final referenceCount = _flattenReferenceSteps(referenceSteps).length;
      final insufficientData = analysis.isEmpty ||
          _strokes.isEmpty ||
          (steps.isEmpty && fallbackResults.isEmpty);
      final analysisText = insufficientData
          ? '채점에 필요한 자료가 부족해요!'
          : analysis;
      final isCorrect =
          insufficientData ? false : _isSolveCorrect(evaluated, referenceCount);
      if (!mounted) return;
      final route = MaterialPageRoute<SolveAnalysisAction>(
        builder: (_) => SolveAnalysisPage(
          analysisText: analysisText,
          quest: quest,
          stepCorrectness: stepCorrectness,
          isCorrect: isCorrect,
          hasNextProblem: _currentProblemIndex < _problemCount - 1,
        ),
      );
      final action = gradingShown
          ? await navigator.pushReplacement(route)
          : await navigator.push(route);
      gradingShown = false;
      if (!mounted) return;
      if (action == SolveAnalysisAction.next) {
        _goToNextProblem();
      }
    } catch (error) {
      if (!mounted) return;
      if (gradingShown) {
        navigator.pop();
        gradingShown = false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('채점 데이터 생성 실패: $error')));
    } finally {
      if (mounted) {
        setState(() => _analysisBusy = false);
      }
    }
  }

  bool _isSolveCorrect(List<_StepCorrectness> results, int referenceCount) {
    if (referenceCount <= 0) return false;
    if (results.length < referenceCount) return false;
    for (var i = 0; i < referenceCount; i++) {
      if (results[i].correct != true) {
        return false;
      }
    }
    return true;
  }

  Future<Map<String, dynamic>> _buildLlmPayload() async {
    final analytics = _StrokeAnalyticsEngine.analyze(
      strokes: _strokes,
      inputEvents: _inputEvents,
      sampleWindowSeconds: _StrokeAnalyticsEngine.sampleWindowSeconds,
    );
    final writingEvents = _StrokeAnalyticsEngine.extractEvents(
      analytics: analytics,
      strokes: _strokes,
      inputEvents: _inputEvents,
    );

    final imageBytes = await _renderStrokesToPng();
    final ocrBlocks = await _runOcr(imageBytes);
    final steps = _segmentSteps(ocrBlocks, _strokes);
    final referenceSteps = _ReferenceSolveStep.fromServer(
      _currentQuest?['solves'],
    );
    final stepCorrectness = _evaluateStepCorrectness(steps, referenceSteps);
    final timeWeakness = _analyzeTimeWeakness(steps);

    final titleBlocks = _currentQuestTitleBlocks();
    final problemText = titleBlocks.isEmpty
        ? _problemText
        : contentBlocksToPlainText(titleBlocks);
    final questId = _currentQuestId();
    final questModels = _currentQuestModels();

    return {
      'quest_id': questId.isEmpty ? null : questId,
      'quest_model': questModels,
      'problem': problemText,
      'problem_index': _currentProblemIndex + 1,
      'problem_count': _problemCount,
      'hash_tags': _hashTags,
      'student_work_image': base64Encode(imageBytes),
      'recognized_text': ocrBlocks.map((block) => block.toJson()).toList(),
      'writing_events': writingEvents.map((event) => event.toJson()).toList(),
      'step_correctness': stepCorrectness
          .map((result) => result.toJson())
          .toList(),
      'time_weakness': timeWeakness.map((item) => item.toJson()).toList(),
    };
  }

  Future<Uint8List> _renderStrokesToPng() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final logicalSize = Size(_baseWidth, _logicalHeight);
    // Stroke-only render for grading (no problem text or UI layers).
    canvas.drawRect(Offset.zero & logicalSize, Paint()..color = Colors.white);
    _StrokePainter.drawStrokes(canvas, _strokes, currentStroke: _currentStroke);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      math.max(1, _baseWidth.toInt()),
      math.max(1, _logicalHeight.toInt()),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes?.buffer.asUint8List() ?? Uint8List(0);
  }

  Future<List<_OcrBlock>> _runOcr(Uint8List pngBytes) async {
    // TODO: integrate OCR/Vision pipeline with backend service.
    return <_OcrBlock>[];
  }

  List<_OcrBlock> _parseOcrBlocksFromResponse(List<dynamic> rawBlocks) {
    if (rawBlocks.isEmpty) return <_OcrBlock>[];
    final blocks = <_OcrBlock>[];
    for (final entry in rawBlocks) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry as Map);
      final text = map['text']?.toString() ?? '';
      final rect = _parseOcrRect(map['bbox']);
      if (rect == null) continue;
      blocks.add(_OcrBlock(text: text, bbox: rect));
    }
    return blocks;
  }

  Rect? _parseOcrRect(dynamic value) {
    List<double>? coords;
    if (value is List && value.length >= 4) {
      coords = value.take(4).map(_toDouble).toList();
    } else if (value is Map) {
      final map = Map<String, dynamic>.from(value as Map);
      if (map.containsKey('x1') &&
          map.containsKey('y1') &&
          map.containsKey('x2') &&
          map.containsKey('y2')) {
        coords = [
          _toDouble(map['x1']),
          _toDouble(map['y1']),
          _toDouble(map['x2']),
          _toDouble(map['y2']),
        ];
      }
    }
    if (coords == null) return null;

    final maxValue = coords.reduce((a, b) => a > b ? a : b);
    final isNormalized = maxValue <= 1.5;
    var left = coords[0];
    var top = coords[1];
    var right = coords[2];
    var bottom = coords[3];

    if (isNormalized) {
      left *= _baseWidth;
      right *= _baseWidth;
      top *= _logicalHeight;
      bottom *= _logicalHeight;
    }

    final l = math.min(left, right).clamp(0.0, _baseWidth).toDouble();
    final r = math.max(left, right).clamp(0.0, _baseWidth).toDouble();
    final t = math.min(top, bottom).clamp(0.0, _logicalHeight).toDouble();
    final b = math.max(top, bottom).clamp(0.0, _logicalHeight).toDouble();
    if (r <= l || b <= t) return null;
    return Rect.fromLTRB(l, t, r, b);
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  List<_SolutionStep> _segmentSteps(
    List<_OcrBlock> blocks,
    List<_Stroke> strokes,
  ) {
    if (blocks.isEmpty) return <_SolutionStep>[];
    final orderedBlocks = List<_OcrBlock>.from(blocks)
      ..sort((a, b) {
        final dy = a.bbox.top.compareTo(b.bbox.top);
        if (dy != 0) return dy;
        return a.bbox.left.compareTo(b.bbox.left);
      });
    final steps = <_SolutionStep>[];
    for (var i = 0; i < orderedBlocks.length; i++) {
      final block = orderedBlocks[i];
      final connectedStrokes = <_Stroke>[];
      for (final stroke in strokes) {
        final centroid = stroke.centroid;
        if (centroid != null && block.bbox.contains(centroid)) {
          connectedStrokes.add(stroke);
        }
      }
      final times = _SolutionStepTimeRange.fromStrokes(connectedStrokes);
      steps.add(
        _SolutionStep(
          stepId: i + 1,
          recognizedText: block.text,
          bbox: block.bbox,
          connectedStrokes: connectedStrokes
              .map((stroke) => stroke.id)
              .toList(),
          startTime: times.startTime,
          endTime: times.endTime,
        ),
      );
    }
    return steps;
  }

  List<_StepCorrectness> _evaluateStepCorrectness(
    List<_SolutionStep> steps,
    List<_ReferenceSolveStep> referenceSteps,
  ) {
    if (steps.isEmpty) return <_StepCorrectness>[];
    final flattened = _flattenReferenceSteps(referenceSteps);
    if (flattened.isEmpty) {
      return steps
          .map((step) => _StepCorrectness.unknown(stepId: step.stepId))
          .toList();
    }
    final results = <_StepCorrectness>[];
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      final reference = i < flattened.length ? flattened[i] : null;
      if (reference == null) {
        results.add(_StepCorrectness.unknown(stepId: step.stepId));
        continue;
      }
      final similarity = _textSimilarity(
        step.recognizedText,
        reference.flowText,
      );
      final isCorrect = similarity >= 0.6;
      results.add(
        _StepCorrectness(
          stepId: step.stepId,
          correct: isCorrect,
          similarity: similarity,
          feedback: isCorrect ? null : '정답 풀이 단계와 내용이 다릅니다.',
        ),
      );
    }
    return results;
  }

  List<_StepWeakness> _analyzeTimeWeakness(List<_SolutionStep> steps) {
    if (steps.isEmpty) return <_StepWeakness>[];
    final durations = steps
        .map((step) => step.duration)
        .where((duration) => duration > 0)
        .toList();
    if (durations.isEmpty) return <_StepWeakness>[];
    final avg = durations.reduce((a, b) => a + b) / durations.length;
    return steps
        .where((step) => step.duration > avg * 1.7)
        .map(
          (step) =>
              _StepWeakness(stepId: step.stepId, weaknessType: 'time_delay'),
        )
        .toList();
  }

  List<_ReferenceSolveStep> _flattenReferenceSteps(
    List<_ReferenceSolveStep> steps,
  ) {
    final flattened = <_ReferenceSolveStep>[];
    void visit(_ReferenceSolveStep step) {
      flattened.add(step);
      for (final branch in step.branches) {
        visit(branch);
      }
    }

    for (final step in steps) {
      visit(step);
    }
    return flattened;
  }

  double _textSimilarity(String a, String b) {
    final tokensA = _tokenize(a);
    final tokensB = _tokenize(b);
    if (tokensA.isEmpty && tokensB.isEmpty) return 1.0;
    if (tokensA.isEmpty || tokensB.isEmpty) return 0.0;
    final intersection = tokensA.intersection(tokensB).length;
    final union = tokensA.union(tokensB).length;
    return union == 0 ? 0.0 : intersection / union;
  }

  Set<String> _tokenize(String text) {
    final regex = RegExp(r'[A-Za-z0-9가-힣]+');
    final matches = regex.allMatches(text);
    return matches.map((m) => m.group(0)!.toLowerCase()).toSet();
  }
}

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({
    required this.icon,
    required this.size,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: size * 0.8,
      child: Icon(icon, size: size, color: color),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.black : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _WidthChip extends StatelessWidget {
  const _WidthChip({
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 54,
        height: 42,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1B402B) : const Color(0xFFE9E9E9),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Container(
          width: width * 6,
          height: width * 6,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _PenSettings {
  const _PenSettings({required this.color, required this.width});

  final Color color;
  final double width;
}

abstract class _UndoAction {
  const _UndoAction();
}

class _AddAction extends _UndoAction {
  const _AddAction(this.stroke);

  final _Stroke stroke;
}

class _RemoveAction extends _UndoAction {
  const _RemoveAction(this.strokes);

  final List<_Stroke> strokes;
}

class _ProblemSnapshot {
  const _ProblemSnapshot({
    required this.strokes,
    required this.undoStack,
    required this.pendingEraseRemoved,
    required this.inputEvents,
    required this.nextStrokeOrder,
    required this.nextStrokeId,
    required this.elapsedSeconds,
  });

  final List<_Stroke> strokes;
  final List<_UndoAction> undoStack;
  final List<_Stroke> pendingEraseRemoved;
  final List<_InputEvent> inputEvents;
  final int nextStrokeOrder;
  final int nextStrokeId;
  final double elapsedSeconds;
}

enum _InputEventType { undo, erase }

class _InputEvent {
  const _InputEvent._({
    required this.type,
    required this.timestamp,
    this.region,
    this.strokeId,
  });

  factory _InputEvent.undo(double timestamp) {
    return _InputEvent._(type: _InputEventType.undo, timestamp: timestamp);
  }

  factory _InputEvent.erase({
    required double timestamp,
    required Rect region,
    required String strokeId,
  }) {
    return _InputEvent._(
      type: _InputEventType.erase,
      timestamp: timestamp,
      region: region,
      strokeId: strokeId,
    );
  }

  final _InputEventType type;
  final double timestamp;
  final Rect? region;
  final String? strokeId;
}

class _PauseEvent {
  const _PauseEvent({required this.strokeIndex, required this.duration});

  final int strokeIndex;
  final double duration;

  Map<String, dynamic> toJson() {
    return {'stroke_index': strokeIndex, 'duration': duration};
  }
}

class _TimelineBucket {
  const _TimelineBucket({
    required this.t,
    required this.strokeCount,
    required this.avgSpeed,
  });

  final double t;
  final int strokeCount;
  final double avgSpeed;

  Map<String, dynamic> toJson() {
    return {'t': t, 'stroke_count': strokeCount, 'avg_speed': avgSpeed};
  }
}

class _StrokeAnalytics {
  const _StrokeAnalytics({
    required this.totalStrokes,
    required this.totalTime,
    required this.avgLength,
    required this.avgSpeed,
    required this.pauseEvents,
    required this.eraseCount,
    required this.undoCount,
    required this.rewriteCount,
    required this.timeline,
  });

  final int totalStrokes;
  final double totalTime;
  final double avgLength;
  final double avgSpeed;
  final List<_PauseEvent> pauseEvents;
  final int eraseCount;
  final int undoCount;
  final int rewriteCount;
  final List<_TimelineBucket> timeline;

  Map<String, dynamic> toJson() {
    return {
      'total_strokes': totalStrokes,
      'total_time': totalTime,
      'avg_stroke_length': avgLength,
      'avg_stroke_speed': avgSpeed,
      'pause_events': pauseEvents.map((event) => event.toJson()).toList(),
      'erase_count': eraseCount,
      'undo_count': undoCount,
      'rewrite_count': rewriteCount,
      'timeline': timeline.map((bucket) => bucket.toJson()).toList(),
    };
  }
}

enum _WritingEventType {
  longPause,
  slowWriting,
  rewrite,
  undoBurst,
  eraseCluster,
}

extension _WritingEventTypeLabel on _WritingEventType {
  String get label {
    switch (this) {
      case _WritingEventType.longPause:
        return 'long_pause';
      case _WritingEventType.slowWriting:
        return 'slow_writing';
      case _WritingEventType.rewrite:
        return 'rewrite';
      case _WritingEventType.undoBurst:
        return 'undo_burst';
      case _WritingEventType.eraseCluster:
        return 'erase_cluster';
    }
  }
}

class _WritingEvent {
  const _WritingEvent({required this.type, required this.data});

  final _WritingEventType type;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() {
    return {'type': type.label, ...data};
  }
}

class _RegionCluster {
  _RegionCluster(this.region) : count = 1;

  Rect region;
  int count;

  void absorb(Rect other) {
    region = region.expandToInclude(other);
    count += 1;
  }
}

class _StrokeAnalyticsEngine {
  static const double pauseThresholdSeconds = 1.5;
  static const double slowWritingFactor = 0.5;
  static const double undoBurstWindowSeconds = 3.0;
  static const int undoBurstMinCount = 2;
  static const int maxEventsPerType = 5;
  static const int maxTotalEvents = 20;
  static const double sampleWindowSeconds = 1.0;

  static _StrokeAnalytics analyze({
    required List<_Stroke> strokes,
    required List<_InputEvent> inputEvents,
    required double sampleWindowSeconds,
  }) {
    if (strokes.isEmpty) {
      return const _StrokeAnalytics(
        totalStrokes: 0,
        totalTime: 0,
        avgLength: 0,
        avgSpeed: 0,
        pauseEvents: <_PauseEvent>[],
        eraseCount: 0,
        undoCount: 0,
        rewriteCount: 0,
        timeline: <_TimelineBucket>[],
      );
    }

    final ordered = List<_Stroke>.from(strokes)
      ..sort((a, b) => a.order.compareTo(b.order));
    final totalStrokes = ordered.length;
    final totalTime = math.max(
      0.0,
      ordered.last.endTime - ordered.first.startTime,
    );

    final totalLength = ordered.fold<double>(
      0.0,
      (sum, stroke) => sum + stroke.length,
    );
    final avgLength = totalStrokes == 0 ? 0.0 : totalLength / totalStrokes;

    final speeds = ordered
        .map((stroke) {
          final duration = stroke.duration;
          if (duration <= 0) return 0.0;
          return stroke.length / duration;
        })
        .where((speed) => speed > 0)
        .toList();
    final avgSpeed = speeds.isEmpty
        ? 0.0
        : speeds.reduce((a, b) => a + b) / speeds.length;

    final pauseEvents = <_PauseEvent>[];
    for (var i = 0; i < ordered.length - 1; i++) {
      final pause = ordered[i + 1].startTime - ordered[i].endTime;
      if (pause > 0) {
        pauseEvents.add(_PauseEvent(strokeIndex: i, duration: pause));
      }
    }

    final eraseCount = inputEvents
        .where((event) => event.type == _InputEventType.erase)
        .length;
    final undoCount = inputEvents
        .where((event) => event.type == _InputEventType.undo)
        .length;
    final rewriteClusters = _buildRewriteClusters(ordered, inputEvents);
    final rewriteCount = rewriteClusters.fold<int>(
      0,
      (sum, cluster) => sum + cluster.count,
    );

    final timeline = _buildTimeline(
      strokes: ordered,
      totalTime: totalTime,
      sampleWindowSeconds: sampleWindowSeconds,
    );

    return _StrokeAnalytics(
      totalStrokes: totalStrokes,
      totalTime: totalTime,
      avgLength: avgLength,
      avgSpeed: avgSpeed,
      pauseEvents: pauseEvents,
      eraseCount: eraseCount,
      undoCount: undoCount,
      rewriteCount: rewriteCount,
      timeline: timeline,
    );
  }

  static List<_WritingEvent> extractEvents({
    required _StrokeAnalytics analytics,
    required List<_Stroke> strokes,
    required List<_InputEvent> inputEvents,
  }) {
    final events = <_WritingEvent>[];

    final longPauses =
        analytics.pauseEvents
            .where((event) => event.duration >= pauseThresholdSeconds)
            .toList()
          ..sort((a, b) => b.duration.compareTo(a.duration));
    for (final pause in longPauses.take(maxEventsPerType)) {
      events.add(
        _WritingEvent(type: _WritingEventType.longPause, data: pause.toJson()),
      );
    }

    final avgSpeed = analytics.avgSpeed;
    final slowCandidates = <Map<String, dynamic>>[];
    for (var i = 0; i < strokes.length; i++) {
      final stroke = strokes[i];
      if (stroke.duration <= 0) continue;
      final speed = stroke.length / stroke.duration;
      if (avgSpeed > 0 && speed < avgSpeed * slowWritingFactor) {
        slowCandidates.add({'stroke_index': i, 'speed': speed});
      }
    }
    slowCandidates.sort(
      (a, b) => (a['speed'] as double).compareTo(b['speed'] as double),
    );
    for (final slow in slowCandidates.take(maxEventsPerType)) {
      events.add(
        _WritingEvent(
          type: _WritingEventType.slowWriting,
          data: {'stroke_index': slow['stroke_index']},
        ),
      );
    }

    final rewriteClusters = _buildRewriteClusters(strokes, inputEvents)
      ..sort((a, b) => b.count.compareTo(a.count));
    for (final cluster in rewriteClusters.take(maxEventsPerType)) {
      events.add(
        _WritingEvent(
          type: _WritingEventType.rewrite,
          data: {'region': _rectToList(cluster.region), 'count': cluster.count},
        ),
      );
    }

    final undoBurst = _buildUndoBurst(inputEvents);
    if (undoBurst != null) {
      events.add(undoBurst);
    }

    final eraseClusters = _buildEraseClusters(inputEvents)
      ..sort((a, b) => b.count.compareTo(a.count));
    for (final cluster in eraseClusters.take(maxEventsPerType)) {
      events.add(
        _WritingEvent(
          type: _WritingEventType.eraseCluster,
          data: {'region': _rectToList(cluster.region), 'count': cluster.count},
        ),
      );
    }

    if (events.length <= maxTotalEvents) {
      return events;
    }
    return events.take(maxTotalEvents).toList();
  }

  static List<_TimelineBucket> _buildTimeline({
    required List<_Stroke> strokes,
    required double totalTime,
    required double sampleWindowSeconds,
  }) {
    if (totalTime <= 0 || sampleWindowSeconds <= 0) {
      return <_TimelineBucket>[];
    }
    final bucketCount = (totalTime / sampleWindowSeconds).ceil();
    final buckets = List<_TimelineBucket>.generate(
      bucketCount,
      (index) => _TimelineBucket(
        t: index * sampleWindowSeconds,
        strokeCount: 0,
        avgSpeed: 0,
      ),
    );

    for (var i = 0; i < bucketCount; i++) {
      final start = i * sampleWindowSeconds;
      final end = start + sampleWindowSeconds;
      final strokesInBucket = strokes
          .where(
            (stroke) => stroke.startTime >= start && stroke.startTime < end,
          )
          .toList();
      if (strokesInBucket.isEmpty) continue;
      final speeds = strokesInBucket
          .map(
            (stroke) =>
                stroke.duration > 0 ? stroke.length / stroke.duration : 0.0,
          )
          .where((speed) => speed > 0)
          .toList();
      final avgSpeed = speeds.isEmpty
          ? 0.0
          : speeds.reduce((a, b) => a + b) / speeds.length;
      buckets[i] = _TimelineBucket(
        t: start,
        strokeCount: strokesInBucket.length,
        avgSpeed: avgSpeed,
      );
    }
    return buckets;
  }

  static List<_RegionCluster> _buildRewriteClusters(
    List<_Stroke> strokes,
    List<_InputEvent> inputEvents,
  ) {
    if (strokes.isEmpty || inputEvents.isEmpty) return <_RegionCluster>[];
    final erases = inputEvents
        .where((event) => event.type == _InputEventType.erase)
        .where((event) => event.region != null)
        .toList();
    if (erases.isEmpty) return <_RegionCluster>[];

    final clusters = <_RegionCluster>[];
    for (final stroke in strokes) {
      final strokeBounds = stroke.resolvedBounds;
      if (strokeBounds == null) continue;
      Rect? overlapRegion;
      for (final erase in erases) {
        if (erase.timestamp > stroke.startTime) continue;
        final region = erase.region!;
        if (!region.overlaps(strokeBounds)) continue;
        overlapRegion = overlapRegion == null
            ? strokeBounds.expandToInclude(region)
            : overlapRegion.expandToInclude(region);
      }
      if (overlapRegion == null) continue;
      _addToClusters(clusters, overlapRegion);
    }
    return clusters;
  }

  static List<_RegionCluster> _buildEraseClusters(
    List<_InputEvent> inputEvents,
  ) {
    final erases = inputEvents
        .where((event) => event.type == _InputEventType.erase)
        .where((event) => event.region != null)
        .toList();
    if (erases.isEmpty) return <_RegionCluster>[];
    final clusters = <_RegionCluster>[];
    for (final erase in erases) {
      _addToClusters(clusters, erase.region!);
    }
    return clusters.where((cluster) => cluster.count >= 2).toList();
  }

  static _WritingEvent? _buildUndoBurst(List<_InputEvent> inputEvents) {
    final undoTimes =
        inputEvents
            .where((event) => event.type == _InputEventType.undo)
            .map((event) => event.timestamp)
            .toList()
          ..sort();
    if (undoTimes.length < undoBurstMinCount) return null;
    var maxCount = 0;
    var start = 0;
    for (var end = 0; end < undoTimes.length; end++) {
      while (undoTimes[end] - undoTimes[start] > undoBurstWindowSeconds) {
        start += 1;
      }
      final count = end - start + 1;
      if (count > maxCount) maxCount = count;
    }
    if (maxCount < undoBurstMinCount) return null;
    return _WritingEvent(
      type: _WritingEventType.undoBurst,
      data: {'count': maxCount},
    );
  }

  static void _addToClusters(List<_RegionCluster> clusters, Rect region) {
    for (final cluster in clusters) {
      if (cluster.region.overlaps(region)) {
        cluster.absorb(region);
        return;
      }
    }
    clusters.add(_RegionCluster(region));
  }
}

class _OcrBlock {
  const _OcrBlock({required this.text, required this.bbox});

  final String text;
  final Rect bbox;

  Map<String, dynamic> toJson() {
    return {'text': text, 'bbox': _rectToList(bbox)};
  }
}

class _SolutionStepTimeRange {
  const _SolutionStepTimeRange(this.startTime, this.endTime);

  final double startTime;
  final double endTime;

  static _SolutionStepTimeRange fromStrokes(List<_Stroke> strokes) {
    if (strokes.isEmpty) {
      return const _SolutionStepTimeRange(0, 0);
    }
    final start = strokes
        .map((stroke) => stroke.startTime)
        .reduce((a, b) => a < b ? a : b);
    final end = strokes
        .map((stroke) => stroke.endTime)
        .reduce((a, b) => a > b ? a : b);
    return _SolutionStepTimeRange(start, end);
  }
}

class _SolutionStep {
  const _SolutionStep({
    required this.stepId,
    required this.recognizedText,
    required this.bbox,
    required this.connectedStrokes,
    required this.startTime,
    required this.endTime,
  });

  final int stepId;
  final String recognizedText;
  final Rect bbox;
  final List<String> connectedStrokes;
  final double startTime;
  final double endTime;

  double get duration => math.max(0.0, endTime - startTime);

  Map<String, dynamic> toJson() {
    return {
      'step_id': stepId,
      'recognized_text': recognizedText,
      'bbox': _rectToList(bbox),
      'connected_strokes': connectedStrokes,
      'start_time': startTime,
      'end_time': endTime,
      'duration': duration,
    };
  }
}

class _ReferenceSolveStep {
  const _ReferenceSolveStep({
    required this.flowText,
    required this.hashTags,
    required this.hintText,
    required this.answerText,
    required this.enterHuddle,
    this.branches = const [],
  });

  final String flowText;
  final List<String> hashTags;
  final String hintText;
  final String answerText;
  final int enterHuddle;
  final List<_ReferenceSolveStep> branches;

  static List<_ReferenceSolveStep> fromServer(dynamic solves) {
    if (solves is! List) return <_ReferenceSolveStep>[];
    return solves
        .whereType<Map<String, dynamic>>()
        .map(_fromServerMap)
        .toList();
  }

  static _ReferenceSolveStep _fromServerMap(Map<String, dynamic> step) {
    final flowText = _contentBlocksToText(step['flow']);
    final hintText = _contentBlocksToText(step['hint_riddle']);
    final answerText = _contentBlocksToText(step['answer_riddle']);
    final hashTags = (step['hash_tag'] as List<dynamic>? ?? const [])
        .map((tag) => tag.toString())
        .toList();
    final enterHuddle = (step['enter_huddle'] as int?) ?? 0;
    final branches = fromServer(step['branches']);
    return _ReferenceSolveStep(
      flowText: flowText,
      hashTags: hashTags,
      hintText: hintText,
      answerText: answerText,
      enterHuddle: enterHuddle,
      branches: branches,
    );
  }
}

class _StepCorrectness {
  const _StepCorrectness({
    required this.stepId,
    required this.correct,
    required this.similarity,
    this.feedback,
  });

  const _StepCorrectness.unknown({required this.stepId})
    : correct = null,
      similarity = 0.0,
      feedback = null;

  final int stepId;
  final bool? correct;
  final double similarity;
  final String? feedback;

  factory _StepCorrectness.fromJson(Map<String, dynamic> json) {
    return _StepCorrectness(
      stepId: (json['step_id'] as num?)?.toInt() ?? 0,
      correct: json['correct'] as bool?,
      similarity: (json['similarity'] as num?)?.toDouble() ?? 0.0,
      feedback: json['feedback'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'step_id': stepId,
      'correct': correct,
      'similarity': similarity,
      if (feedback != null) 'feedback': feedback,
    };
  }
}

class _StepWeakness {
  const _StepWeakness({required this.stepId, required this.weaknessType});

  final int stepId;
  final String weaknessType;

  Map<String, dynamic> toJson() {
    return {'step_id': stepId, 'weakness_type': weaknessType};
  }
}

class _Stroke {
  _Stroke({
    required this.id,
    required this.color,
    required this.baseWidth,
    required this.order,
    required this.startTime,
  }) : endTime = startTime;

  final String id;
  final Color color;
  final double baseWidth;
  final int order;
  final double startTime;
  double endTime;
  final List<_StrokePoint> points = <_StrokePoint>[];
  Rect? bounds;

  void addPoint(Offset position, double pressure, double timestamp) {
    points.add(_StrokePoint(position, pressure, timestamp));
    endTime = timestamp;
    final radius = baseWidth / 2;
    final pointRect = Rect.fromCircle(center: position, radius: radius);
    bounds = bounds == null ? pointRect : bounds!.expandToInclude(pointRect);
  }

  double get duration => math.max(0.0, endTime - startTime);

  double get length {
    if (points.length < 2) return 0.0;
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += (points[i + 1].position - points[i].position).distance;
    }
    return total;
  }

  Offset? get centroid {
    if (points.isEmpty) return null;
    var sumX = 0.0;
    var sumY = 0.0;
    for (final point in points) {
      sumX += point.position.dx;
      sumY += point.position.dy;
    }
    return Offset(sumX / points.length, sumY / points.length);
  }

  Rect? get resolvedBounds {
    if (bounds != null) return bounds;
    if (points.isEmpty) return null;
    var rect = Rect.fromCircle(
      center: points.first.position,
      radius: baseWidth / 2,
    );
    for (final point in points.skip(1)) {
      final pointRect = Rect.fromCircle(
        center: point.position,
        radius: baseWidth / 2,
      );
      rect = rect.expandToInclude(pointRect);
    }
    return rect;
  }

  Map<String, dynamic> toJson() {
    return {
      'stroke_id': id,
      'order': order,
      'start_time': startTime,
      'end_time': endTime,
      'points': points.map((point) => point.toJson()).toList(),
    };
  }

  bool hitTestCircle(Offset center, double radius) {
    final currentBounds = bounds;
    if (currentBounds == null) return false;
    if (!currentBounds.inflate(radius).contains(center)) return false;
    if (points.length == 1) {
      return (points.first.position - center).distance <= radius;
    }
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i].position;
      final b = points[i + 1].position;
      if (_distanceToSegment(center, a, b) <= radius) {
        return true;
      }
    }
    return false;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final abLen2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLen2 == 0) return (p - a).distance;
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLen2;
    final clamped = t.clamp(0.0, 1.0);
    final closest = Offset(a.dx + ab.dx * clamped, a.dy + ab.dy * clamped);
    return (p - closest).distance;
  }
}

class _StrokePoint {
  const _StrokePoint(this.position, this.pressure, this.timestamp);

  final Offset position;
  final double pressure;
  final double timestamp;

  Map<String, dynamic> toJson() {
    return {
      'x': position.dx,
      'y': position.dy,
      'pressure': pressure,
      'timestamp': timestamp,
    };
  }
}

class _StrokePainter extends CustomPainter {
  static const double _pressureMinFactor = 0.35;

  _StrokePainter({
    required this.strokes,
    required this.currentStroke,
    required this.eraserPosition,
    required this.eraserRadius,
    required this.scale,
    required this.logicalSize,
    required this.backgroundColor,
    Listenable? repaint,
  }) : super(repaint: repaint);

  final List<_Stroke> strokes;
  final _Stroke? currentStroke;
  final Offset? eraserPosition;
  final double eraserRadius;
  final double scale;
  final Size logicalSize;
  final Color backgroundColor;

  static void drawStrokes(
    Canvas canvas,
    List<_Stroke> strokes, {
    _Stroke? currentStroke,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    void drawOne(_Stroke stroke) {
      if (stroke.points.isEmpty) return;
      paint.color = stroke.color;
      if (stroke.points.length == 1) {
        final point = stroke.points.first;
        final width = _pressureWidth(stroke.baseWidth, point.pressure);
        canvas.drawCircle(
          point.position,
          width / 2,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
        return;
      }
      for (var i = 0; i < stroke.points.length - 1; i++) {
        final p1 = stroke.points[i];
        final p2 = stroke.points[i + 1];
        final width = _pressureWidth(
          stroke.baseWidth,
          (p1.pressure + p2.pressure) * 0.5,
        );
        paint.strokeWidth = width;
        canvas.drawLine(p1.position, p2.position, paint);
      }
    }

    for (final stroke in strokes) {
      drawOne(stroke);
    }
    if (currentStroke != null) {
      drawOne(currentStroke);
    }
  }

  static double _pressureWidth(double baseWidth, double pressure) {
    final factor =
        _pressureMinFactor +
        (1 - _pressureMinFactor) * pressure.clamp(0.0, 1.0);
    return baseWidth * factor;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale);
    canvas.clipRect(Offset.zero & logicalSize);
    if (backgroundColor.opacity > 0) {
      canvas.drawRect(
        Offset.zero & logicalSize,
        Paint()..color = backgroundColor,
      );
    }
    drawStrokes(canvas, strokes, currentStroke: currentStroke);

    if (eraserPosition != null) {
      final fillPaint = Paint()
        ..color = Colors.black.withOpacity(0.08)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(eraserPosition!, eraserRadius, fillPaint);
      canvas.drawCircle(eraserPosition!, eraserRadius, borderPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.logicalSize != logicalSize ||
        oldDelegate.eraserPosition != eraserPosition ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class _GradingScreen extends StatelessWidget {
  const _GradingScreen();

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(height: 16),
              Text(
                '채점 중',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<double> _rectToList(Rect rect) {
  return <double>[rect.left, rect.top, rect.right, rect.bottom];
}

String _contentBlocksToText(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is Map<String, dynamic>) {
    if (value.containsKey('blocks')) {
      final blocks = value['blocks'];
      if (blocks is List) {
        return blocks
            .whereType<Map<String, dynamic>>()
            .map((block) => (block['content'] ?? '').toString().trim())
            .where((content) => content.isNotEmpty)
            .join(' ')
            .trim();
      }
    }
    if (value.containsKey('content')) {
      return (value['content'] ?? '').toString().trim();
    }
  }
  if (value is List) {
    return value
        .map((item) {
          if (item is Map<String, dynamic>) {
            return (item['content'] ?? '').toString().trim();
          }
          return item.toString().trim();
        })
        .where((content) => content.isNotEmpty)
        .join(' ')
        .trim();
  }
  return value.toString().trim();
}

class _TierParams {
  final int solvesCount;
  final int strategyLevel;
  final int branchConditions;

  const _TierParams({
    required this.solvesCount,
    required this.strategyLevel,
    required this.branchConditions,
  });
}
