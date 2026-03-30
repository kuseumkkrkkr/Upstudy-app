part of s11.tryout;

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
  static const bool _debugEnabled = true;
  // Gemini prompt/model is handled on the server.
  static const HeatmapConfig _heatmapConfig = HeatmapConfig();
  static const bool _sendProblemImage = false;

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
  final GlobalKey _problemBoundaryKey = GlobalKey();

  final List<_Stroke> _strokes = <_Stroke>[];
  final List<_Stroke> _strokeHistory = <_Stroke>[];
  final List<_UndoAction> _undoStack = <_UndoAction>[];
  final List<_Stroke> _pendingEraseRemoved = <_Stroke>[];
  final List<_InputEvent> _inputEvents = <_InputEvent>[];
  final List<_EraserStroke> _eraserHistory = <_EraserStroke>[];
  _EraserStroke? _currentEraserStroke;
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
  double _genTemperature = 0.2;
  double _genTopP = 0.95;
  int _genTopK = 40;
  int _genMaxTokens = 1024;

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
  final List<int?> _selectedChoices = <int?>[];

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
    final minTier = math
        .min(config.minDifficultyTier, config.maxDifficultyTier)
        .clamp(1, 5)
        .toInt();
    final maxTier = math
        .max(config.minDifficultyTier, config.maxDifficultyTier)
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
    _strokeHistory.clear();
    _eraserHistory.clear();
    _currentEraserStroke = null;
    _quests
      ..clear()
      ..addAll(List<Map<String, dynamic>?>.filled(_problemCount, null));
    _selectedChoices
      ..clear()
      ..addAll(List<int?>.filled(_problemCount, null));
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

  int _currentDifficultyTier() {
    final quest = _currentQuest;
    if (quest != null) {
      final info = quest['info'] as Map<String, dynamic>? ?? {};
      final raw =
          info['difficulty_tier'] ??
          info['difficulty'] ??
          info['tier'] ??
          info['level'];
      if (raw is num) {
        return raw.toInt().clamp(1, 5);
      }
      final parsed = int.tryParse(raw?.toString() ?? '');
      if (parsed != null) {
        return parsed.clamp(1, 5);
      }
    }
    return _tierForProblemIndex(_currentProblemIndex).clamp(1, 5);
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

  List<List<ContentBlock>> _currentQuestOptionBlocks() {
    final quest = _currentQuest;
    if (quest == null) return const [];
    final data = quest['data'] as Map<String, dynamic>? ?? {};
    final rawOptions = data['quest_options'];
    if (rawOptions is! List) return const [];
    final results = <List<ContentBlock>>[];
    for (final option in rawOptions) {
      final blocks = parseContentBlocks(option);
      if (blocks.isNotEmpty) {
        results.add(blocks);
      }
    }
    return results;
  }

  int? _currentSelectedChoice() {
    if (_currentProblemIndex < 0 ||
        _currentProblemIndex >= _selectedChoices.length) {
      return null;
    }
    return _selectedChoices[_currentProblemIndex];
  }

  void _toggleChoice(int index) {
    if (_currentProblemIndex < 0 ||
        _currentProblemIndex >= _selectedChoices.length) {
      return;
    }
    setState(() {
      final current = _selectedChoices[_currentProblemIndex];
      if (current == index) {
        _selectedChoices[_currentProblemIndex] = null;
      } else {
        _selectedChoices[_currentProblemIndex] = index;
      }
    });
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
      final quests = await ApiClient.instance.generateProblemSet(
        hashTags: _hashTags,
        minDifficultyTier: _minDifficultyTier,
        maxDifficultyTier: _maxDifficultyTier,
        questionCount: _problemCount,
      );
      final selected = List<Map<String, dynamic>?>.filled(_problemCount, null);
      for (var i = 0; i < _problemCount; i++) {
        selected[i] = i < quests.length ? quests[i] : null;
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
        _questError = error.toString().replaceFirst('Exception: ', '');
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
      strokeHistory: List<_Stroke>.from(_strokeHistory),
      eraserHistory: List<_EraserStroke>.from(_eraserHistory),
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
    _strokeHistory
      ..clear()
      ..addAll(snapshot?.strokeHistory ?? const []);
    _eraserHistory
      ..clear()
      ..addAll(snapshot?.eraserHistory ?? const []);
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
    _currentEraserStroke = null;
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

  Future<void> _openLlmSettings() async {
    final tempController = TextEditingController(text: _genTemperature.toStringAsFixed(2));
    final topPController = TextEditingController(text: _genTopP.toStringAsFixed(2));
    final topKController = TextEditingController(text: _genTopK.toString());
    final maxTokensController = TextEditingController(text: _genMaxTokens.toString());
    final result = await showDialog<_GenConfig>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('LLM 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tempController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Temperature (T)'),
              ),
              TextField(
                controller: topPController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Top-P'),
              ),
              TextField(
                controller: topKController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Top-K'),
              ),
              TextField(
                controller: maxTokensController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Max tokens'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(
                  _GenConfig(
                    temperature: double.tryParse(tempController.text) ?? _genTemperature,
                    topP: double.tryParse(topPController.text) ?? _genTopP,
                    topK: int.tryParse(topKController.text) ?? _genTopK,
                    maxTokens: int.tryParse(maxTokensController.text) ?? _genMaxTokens,
                  ),
                );
              },
              child: const Text('적용'),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    setState(() {
      _genTemperature = result.temperature.clamp(0.0, 2.0).toDouble();
      _genTopP = result.topP.clamp(0.0, 1.0).toDouble();
      _genTopK = result.topK < 0 ? 0 : result.topK;
      _genMaxTokens = result.maxTokens <= 0 ? _genMaxTokens : result.maxTokens;
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
      _strokeHistory.add(stroke);
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
    _currentEraserStroke = _EraserStroke(startTime: _nowSeconds());
    _recordEraserPoint(position);
    _eraseAt(position);
    _bumpPaint();
  }

  void _updateEraser(Offset position) {
    _eraserActive = true;
    _eraserPosition = position;
    _recordEraserPoint(position);
    _eraseAt(position);
    _bumpPaint();
  }

  void _finishEraser() {
    final eraserStroke = _currentEraserStroke;
    final lastPosition = _eraserPosition;
    if (eraserStroke != null && lastPosition != null) {
      _recordEraserPoint(lastPosition);
    }
    if (_pendingEraseRemoved.isNotEmpty) {
      _undoStack.add(_RemoveAction(List<_Stroke>.from(_pendingEraseRemoved)));
      _pendingEraseRemoved.clear();
    }
    _eraserActive = false;
    _eraserPosition = null;
    if (eraserStroke != null && eraserStroke.points.isNotEmpty) {
      _eraserHistory.add(eraserStroke);
    }
    _currentEraserStroke = null;
    _bumpPaint();
  }

  void _recordEraserPoint(Offset position) {
    final stroke = _currentEraserStroke;
    if (stroke == null) return;
    stroke.addPoint(position, _nowSeconds());
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
                        child: RepaintBoundary(
                          key: _problemBoundaryKey,
                          child: SizedBox(
                            width: _baseWidth,
                            height: _logicalHeight,
                            child: _buildProblemContent(),
                          ),
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
    final optionBlocks = _currentQuestOptionBlocks();
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
                  Text('문제를 불러오는 중입니다...'),
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
            if (optionBlocks.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildOptionPreview(optionBlocks),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionPreview(List<List<ContentBlock>> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(options.length, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_optionLabel(index), style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: ContentBlocksView(
                  blocks: options[index],
                  textStyle: const TextStyle(fontSize: 16, height: 1.4),
                  latexStyle: const TextStyle(fontSize: 16, height: 1.4),
                  inline: true,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  String _optionLabel(int index) {
    const labels = ['①', '②', '③', '④', '⑤'];
    if (index >= 0 && index < labels.length) {
      return labels[index];
    }
    return '${index + 1}';
  }

  Widget _buildToolbar() {
    final activeColor = const Color(0xFF1B402B);
    final inactiveColor = const Color(0xFF6B6B6B);
    final optionBlocks = _currentQuestOptionBlocks();
    final hasOptions = optionBlocks.isNotEmpty;
    final selectedIndex = _currentSelectedChoice();
    return Container(
      width: 800,
      height: hasOptions ? 130 : 70,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ToolbarIcon(
                  icon: Icons.edit_outlined,
                  size: 48,
                  color: _toolMode == _ToolMode.pen
                      ? activeColor
                      : inactiveColor,
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
                if (_debugEnabled) ...[
                  _ToolbarIcon(
                    icon: Icons.tune,
                    size: 40,
                    color: activeColor,
                    onTap: _openLlmSettings,
                  ),
                  const SizedBox(width: 20),
                ],
                const SizedBox(
                  height: 40,
                  child: VerticalDivider(
                    thickness: 2,
                    color: Color(0xFFE0E3E7),
                  ),
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
                  height: 40,
                  child: VerticalDivider(
                    thickness: 2,
                    color: Color(0xFFE0E3E7),
                  ),
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
                  height: 40,
                  child: VerticalDivider(
                    thickness: 2,
                    color: Color(0xFFE0E3E7),
                  ),
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
                    color: _currentProblemIndex == 0
                        ? inactiveColor
                        : activeColor,
                    onTap: _currentProblemIndex == 0
                        ? null
                        : _goToPreviousProblem,
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
            if (hasOptions) ...[
              const SizedBox(height: 12),
              _buildOptionSelector(
                options: optionBlocks,
                selectedIndex: selectedIndex,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionSelector({
    required List<List<ContentBlock>> options,
    required int? selectedIndex,
  }) {
    final activeColor = const Color(0xFF1B402B);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: List.generate(options.length, (index) {
        final isSelected = selectedIndex == index;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _toggleChoice(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? activeColor : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: activeColor, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildOptionCircle(_optionLabel(index), isSelected),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: ContentBlocksView(
                    blocks: options[index],
                    textStyle: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    latexStyle: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    inline: true,
                    spacing: 2,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildOptionCircle(String label, bool selected) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? Colors.white : Colors.transparent,
        border: Border.all(
          color: selected ? Colors.white : const Color(0xFF1B402B),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: selected ? const Color(0xFF1B402B) : const Color(0xFF1B402B),
          fontWeight: FontWeight.w600,
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
    if (_strokes.length <= 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('필기 수가 너무 적어 채점을 시작할 수 없습니다.')));
      return;
    }
    setState(() => _analysisBusy = true);
    final navigator = Navigator.of(context);
    var gradingShown = false;
    navigator.push(MaterialPageRoute(builder: (_) => const _GradingScreen()));
    gradingShown = true;
    try {
      final studentWorkImage = await _renderStrokesToPng();
      final problemImage =
          _sendProblemImage ? await _renderProblemToPng() : Uint8List(0);
      final heatmapResult = _buildHeatmapResult();
      final heatmapImage = await heatmapResult.renderImage();
      debugPrint(
        '[grading] images: student=${studentWorkImage.lengthInBytes}B '
        'problem=${problemImage.lengthInBytes}B '
        'heatmap=${heatmapImage.lengthInBytes}B',
      );
      final payload = await _buildLlmPayload();
      final response = await ApiClient.instance.submitSolveAnalysis(
        payload: payload,
        studentWorkImage: studentWorkImage,
        problemImage: problemImage,
        heatmapImage: heatmapImage,
      );
      if (!mounted) return;
      if (response.warnings.isNotEmpty) {
        debugPrint('Solve analysis warnings: ${response.warnings.join(', ')}');
      }
      final quest = _currentQuest;
      final stepCorrectness = response.stepCorrectness;
      final insufficientData = _strokes.isEmpty;
      final isCorrect = response.isCorrect ?? false;
      const userAnswer = '';
      final debugSnapshot = _debugEnabled
          ? SolveDebugSnapshot(
              ocrPayload: const {},
              ocrDebug: null,
              ocrResult:
                  (response.debugInfo?['ocr'] as Map<String, dynamic>?) ?? const {},
              gradingPayload: payload,
              gradingDebug: response.debugInfo,
              gradingResult: {
                'status': response.status
                    .map(
                      (item) => {
                        'flow_number': item.flowNumber,
                        'status': item.status,
                      },
                    )
                    .toList(),
                'in_panic': response.inPanic,
                'ai_opinion': response.aiOpinion,
              },
              studentImage: studentWorkImage,
              heatmapImage: heatmapImage,
              problemImage: _sendProblemImage ? problemImage : null,
              onRerunGrading: (promptOverride) async {
                final overridePayload = Map<String, dynamic>.from(payload);
                overridePayload['analysis_prompt'] = promptOverride;
                if (_debugEnabled) overridePayload['debug'] = true;
                overridePayload['gen_config'] = _buildGenConfig();
                final rerun = await ApiClient.instance.submitSolveAnalysis(
                  payload: overridePayload,
                  studentWorkImage: studentWorkImage,
                  problemImage: problemImage,
                  heatmapImage: heatmapImage,
                );
                return {
                  'payload': overridePayload,
                  'debug': rerun.debugInfo,
                  'result': {
                    'status': rerun.status
                        .map(
                          (item) => {
                            'flow_number': item.flowNumber,
                            'status': item.status,
                          },
                        )
                        .toList(),
                    'in_panic': rerun.inPanic,
                    'ai_opinion': rerun.aiOpinion,
                  },
                };
              },
            )
          : null;
      final questId = _currentQuestId();
      final problemNumber =
          questId.isNotEmpty ? questId : (_currentProblemIndex + 1).toString();
      unawaited(
        _submitRatingUpdate(
          quest: quest,
          isCorrect: isCorrect,
          stepCorrectness: stepCorrectness,
        ),
      );
      if (isCorrect) {
        try {
          await ActivityStore.recordProblemSolve(
            problemId: questId.isNotEmpty ? questId : problemNumber,
            problemNumber: problemNumber,
          );
        } catch (_) {}
      } else if (!insufficientData) {
        try {
          await ActivityStore.recordProblemIncorrect(
            problemId: questId.isNotEmpty ? questId : problemNumber,
            problemNumber: problemNumber,
          );
        } catch (_) {}
      }
      if (!mounted) return;
      final route = MaterialPageRoute<SolveAnalysisAction>(
        builder: (_) => SolveAnalysisPage(
          userAnswer: userAnswer,
          quest: quest,
          stepCorrectness: stepCorrectness,
          isCorrect: isCorrect,
          hasNextProblem: _currentProblemIndex < _problemCount - 1,
          debugSnapshot: debugSnapshot,
        ),
      );
      final action = gradingShown
          ? await navigator.pushReplacement(route)
          : await navigator.push(route);
      gradingShown = false;
      if (!mounted) return;
      if (action == SolveAnalysisAction.exit) {
        navigator.maybePop();
        return;
      }
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
      ).showSnackBar(SnackBar(content: Text('Grading failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _analysisBusy = false);
      }
    }
  }

  Future<Map<String, dynamic>> _buildLlmPayload() async {
    final titleBlocks = _currentQuestTitleBlocks();
    final problemText = titleBlocks.isEmpty
        ? _problemText
        : contentBlocksToPlainText(titleBlocks);
    final questId = _currentQuestId();
    final questModels = _currentQuestModels();

    return {
      'quest_id': questId.isEmpty ? null : questId,
      'quest_model': questModels,
      if (_currentQuest != null) 'quest_json': _currentQuest,
      if (_debugEnabled) 'debug': true,
      'gen_config': _buildGenConfig(),
      'problem': problemText,
      'problem_index': _currentProblemIndex + 1,
      'problem_count': _problemCount,
      'hash_tags': _hashTags,
    };
  }


  Map<String, dynamic> _buildGenConfig() {
    return {
      'temperature': _genTemperature,
      'top_p': _genTopP,
      'top_k': _genTopK,
      'max_output_tokens': _genMaxTokens,
    };
  }


  List<Map<String, dynamic>> _buildReferenceStepsPayload(
    List<_ReferenceSolveStep> steps,
  ) {
    final flattened = _flattenReferenceSteps(steps);
    final results = <Map<String, dynamic>>[];
    for (var i = 0; i < flattened.length; i++) {
      final step = flattened[i];
      results.add({
        'step_id': i + 1,
        'flow_text': step.flowText,
        'hint_text': step.hintText,
        'answer_text': step.answerText,
        'hash_tags': step.hashTags,
        'enter_huddle': step.enterHuddle,
      });
    }
    return results;
  }

  HeatmapResult _buildHeatmapResult() {
    final events = <HeatmapEvent>[];
    for (final stroke in _strokeHistory) {
      if (stroke.points.isEmpty) continue;
      events.add(
        HeatmapEvent.pen(
          HeatmapStroke(
            key: stroke.id,
            points: stroke.points.map((point) => point.position).toList(),
            order: stroke.endTime,
          ),
        ),
      );
    }
    for (final eraser in _eraserHistory) {
      if (eraser.points.isEmpty) continue;
      events.add(
        HeatmapEvent.eraser(
          HeatmapEraserStroke(
            points: List<Offset>.from(eraser.points),
            order: eraser.endTime,
          ),
        ),
      );
    }
    for (final event in _inputEvents) {
      if (event.type == _InputEventType.undo) {
        events.add(HeatmapEvent.undo(event.timestamp));
      }
    }
    return HeatmapEngine.build(
      size: Size(_baseWidth, _logicalHeight),
      events: events,
      config: _heatmapConfig,
    );
  }

  Map<String, dynamic> _buildHeatmapMeta(HeatmapResult result) {
    final meta = result.toMetaJson();
    if (result.highlightReasons.isEmpty) return meta;
    final boundsMap = <String, Rect>{};
    for (final stroke in _strokeHistory) {
      final bounds = stroke.resolvedBounds;
      if (bounds != null) {
        boundsMap[stroke.id] = bounds;
      }
    }
    final highlightBounds = <Map<String, dynamic>>[];
    result.highlightReasons.forEach((key, reasons) {
      final bounds = boundsMap[key];
      if (bounds == null) return;
      highlightBounds.add({
        'stroke_key': key,
        'bounds': _rectToList(bounds),
        'reasons': reasons.toList(),
      });
    });
    if (highlightBounds.isNotEmpty) {
      meta['highlight_bounds'] = highlightBounds;
    }
    return meta;
  }

  Future<void> _submitRatingUpdate({
    required Map<String, dynamic>? quest,
    required bool isCorrect,
    required List<Map<String, dynamic>> stepCorrectness,
  }) async {
    final questId = _currentQuestId();
    if (questId.isEmpty) return;
    final info = quest?['info'] as Map<String, dynamic>? ?? {};
    final rawTags = (info['hash_tag'] as List<dynamic>? ?? [])
        .map((tag) => tag.toString())
        .toList();
    final tags = rawTags.isNotEmpty ? rawTags : _hashTags;
    final answerTime = _nowSeconds();
    try {
      final rating = await ApiClient.instance.submitRating(
        questId: questId,
        isCorrect: isCorrect,
        tags: tags,
        stepCorrectness: stepCorrectness,
        answerTime: answerTime,
      );
      RatingStore.updateFromRating(rating);
    } catch (_) {
      // ignore rating failures
    }
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

  Future<Uint8List> _renderProblemToPng() async {
    final boundary =
        _problemBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return Uint8List(0);
    final pixelRatio = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes?.buffer.asUint8List() ?? Uint8List(0);
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

class _GenConfig {
  final double temperature;
  final double topP;
  final int topK;
  final int maxTokens;

  const _GenConfig({
    required this.temperature,
    required this.topP,
    required this.topK,
    required this.maxTokens,
  });
}
