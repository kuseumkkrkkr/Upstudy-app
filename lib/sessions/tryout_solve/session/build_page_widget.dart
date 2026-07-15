part of 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';

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
  static const Color _surfaceColor = Colors.white;
  static const Color _lineColor = Color(0xFFE1E6DF);
  static const double _problemCardMinWidth = 920;
  static const double _problemCardMaxWidth = 1380;
  static const double _problemCardMinHeight = 108;
  static const double _noteLineStartY = 28;
  static const double _noteLineSpacing = 28;
  static const double _noteLeftMargin = 60;
  static const bool _debugEnabled = true;
  // Gemini prompt/model is handled on the server.
  static const HeatmapConfig _heatmapConfig = HeatmapConfig();
  static const bool _sendProblemImage = false;

  static const Color _penRed = Color(0xFFE53935);
  static const Color _penBlue = Color(0xFF1E88E5);
  static const List<Color> _penColors = [Colors.black, _penBlue, _penRed];
  static const List<double> _penWidths = [1, 3, 5, 8];
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
  Timer? _solveTimer;

  final List<_Stroke> _strokes = <_Stroke>[];
  final List<_Stroke> _strokeHistory = <_Stroke>[];
  final List<_UndoAction> _undoStack = <_UndoAction>[];
  final List<_Stroke> _pendingEraseRemoved = <_Stroke>[];
  final List<_InputEvent> _inputEvents = <_InputEvent>[];
  final List<_EraserStroke> _eraserHistory = <_EraserStroke>[];
  _EraserStroke? _currentEraserStroke;
  final List<_ProblemSnapshot?> _problemSnapshots = <_ProblemSnapshot?>[];
  final Stopwatch _problemClock = Stopwatch();
  final Stopwatch _sessionClock = Stopwatch();
  // 필요 변수: 현재 풀이 화면 생명주기. 작동 원리: 네트워크 재시도에도 같은 제출 키를 재사용해 중복 레이팅을 방지한다.
  late final String _ratingSessionId;
  bool _continueLoaded = false;

  double _problemElapsedOffset = 0.0;
  int _nextStrokeId = 0;

  _Stroke? _currentStroke;
  int _nextStrokeOrder = 0;
  int? _activePointer;
  Offset? _lastFilteredPoint;

  _ToolMode _toolMode = _ToolMode.pen;
  Color _penColor = Colors.black;
  double _penWidth = 3;
  static const double _fixedGenTemperature = 0.1;
  static const double _fixedGenTopP = 0.95;
  static const int _fixedGenTopK = 40;
  static const int _fixedGenMaxTokens = 1024;

  bool _scrollEnabled = false;
  bool _noteLinesEnabled = true;
  int _timerDisplaySeconds = 0;

  Offset? _eraserPosition;
  bool _eraserActive = false;

  int _problemCount = 1;
  int _currentProblemIndex = 0;
  List<String> _hashTags = <String>[];
  bool _gradeImmediately = true;
  bool _ratingEnabled = true;
  int _minDifficultyTier = 3;
  int _maxDifficultyTier = 3;
  int _passRate = 100;
  int _correctCount = 0;
  int _gradedCount = 0;
  bool _completionReported = false;
  bool _analysisBusy = false;
  bool _questLoading = false;
  double _generationProgress = 0.0;
  String? _questError;
  final List<Map<String, dynamic>?> _quests = <Map<String, dynamic>?>[];
  final List<int?> _selectedChoices = <int?>[];
  final List<bool> _problemGraded = <bool>[];

  @override
  void initState() {
    super.initState();
    _ratingSessionId = DateTime.now().microsecondsSinceEpoch.toString();
    _applyConfig(widget.config ?? const ProblemSolveConfig());
    _sessionClock.start();
    _scheduleSolveTimerTick(updateNow: true);
    if (_quests.whereType<Map<String, dynamic>>().isEmpty) {
      _loadQuestsForTags();
    } else {
      unawaited(_loadContinueForCurrentQuest());
    }
  }

  @override
  void dispose() {
    unawaited(_saveContinueForCurrentQuest());
    _scrollController.dispose();
    _paintVersion.dispose();
    _solveTimer?.cancel();
    _problemClock.stop();
    _sessionClock.stop();
    super.dispose();
  }

  double get _logicalHeight => _scrollEnabled ? _expandedHeight : _baseHeight;

  int get _generatedQuestCount =>
      _quests.whereType<Map<String, dynamic>>().length.clamp(0, _problemCount);

  bool get _hasPendingGeneration =>
      _questError == null && _generatedQuestCount < _problemCount;

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

  void _toggleNoteLines(bool value) {
    setState(() => _noteLinesEnabled = value);
  }

  void _applyConfig(ProblemSolveConfig config) {
    final clampedCount = config.questionCount.clamp(1, 40).toInt();
    _problemCount = config.quests.isNotEmpty
        ? config.quests.length
        : clampedCount;
    _hashTags = List<String>.from(config.hashTags);
    _gradeImmediately = config.gradeImmediately;
    _ratingEnabled = config.ratingEnabled;
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
    _passRate = config.passRate;
    _correctCount = 0;
    _gradedCount = 0;
    _completionReported = false;
    _problemSnapshots
      ..clear()
      ..addAll(List<_ProblemSnapshot?>.filled(_problemCount, null));
    _currentProblemIndex = 0;
    _problemElapsedOffset = 0.0;
    _problemClock.stop();
    _problemClock.reset();
    _sessionClock
      ..reset()
      ..start();
    _strokeHistory.clear();
    _eraserHistory.clear();
    _currentEraserStroke = null;
    _quests
      ..clear()
      ..addAll(
        config.quests.isNotEmpty
            ? config.quests
                  .map<Map<String, dynamic>?>((e) => e)
                  .toList(growable: false)
            : List<Map<String, dynamic>?>.filled(_problemCount, null),
      );
    _selectedChoices
      ..clear()
      ..addAll(
        List<int?>.filled(
          config.quests.isNotEmpty ? config.quests.length : _problemCount,
          null,
        ),
      );
    _problemGraded
      ..clear()
      ..addAll(List<bool>.filled(_problemCount, false));
    _questError = null;
    _questLoading = false;
    if (config.quests.isNotEmpty) {
      _problemCount = config.quests.length;
    }
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

  String _problemFingerprint(Map<String, dynamic>? quest, int index) {
    final data = quest == null ? null : quest['data'] as Map<String, dynamic>?;
    final codebaseId = data?['codebase_id'];
    final seedValue = data?['seed'];
    if (codebaseId != null && seedValue != null) {
      return 'cb${codebaseId}_s${seedValue}';
    }
    final questId = (quest?['header']?['quest_id'] ?? '').toString().trim();
    if (questId.isNotEmpty) return questId;
    return (index + 1).toString();
  }

  Map<String, dynamic> _problemMeta(Map<String, dynamic>? quest) {
    final data = quest == null ? null : quest['data'] as Map<String, dynamic>?;
    final questId = (quest?['header']?['quest_id'] ?? '').toString().trim();
    final meta = <String, dynamic>{};
    if (questId.isNotEmpty) meta['quest_id'] = questId;
    if (data != null) {
      if (data['codebase_id'] != null)
        meta['codebase_id'] = data['codebase_id'];
      if (data['seed'] != null) meta['seed'] = data['seed'];
    }
    return meta;
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
      _generationProgress = 0.0;
      _questError = null;
    });

    int loadedCount = 0;
    try {
      await for (final quest in ApiClient.instance.generateProblemSetStream(
        hashTags: _hashTags,
        minDifficultyTier: _minDifficultyTier,
        maxDifficultyTier: _maxDifficultyTier,
        questionCount: _problemCount,
      )) {
        if (!mounted) break;
        final slot = loadedCount++;
        if (slot < _quests.length) {
          setState(() {
            _quests[slot] = quest;
            _generationProgress = loadedCount / _problemCount;
            if (loadedCount == 1) _questLoading = false;
          });
          if (loadedCount == 1) {
            unawaited(_loadContinueForCurrentQuest());
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _questLoading = false;
        _generationProgress = 1.0;
        _questError = null;
        _continueLoaded = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[ProblemSolve] Failed to load quests: $error');
      debugPrint(stackTrace.toString());
      if (!mounted) return;
      setState(() {
        _questLoading = false;
        _generationProgress = 0.0;
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

  void _scheduleSolveTimerTick({bool updateNow = false}) {
    _solveTimer?.cancel();
    if (!mounted && !updateNow) return;

    final elapsed = _sessionClock.elapsed.inSeconds;
    final displaySeconds = elapsed >= 40 * 60 ? 40 * 60 : elapsed;
    if (displaySeconds != _timerDisplaySeconds) {
      if (mounted && !updateNow) {
        setState(() => _timerDisplaySeconds = displaySeconds);
      } else {
        _timerDisplaySeconds = displaySeconds;
      }
    }
    if (elapsed >= 40 * 60) return;

    final delay = elapsed < 5 * 60
        ? const Duration(seconds: 1)
        : Duration(seconds: 60 - (elapsed % 60));
    _solveTimer = Timer(delay, _scheduleSolveTimerTick);
  }

  String _solveTimerLabel() {
    final recommended = _recommendedMinutesForCurrentQuest();
    final recommendedText = recommended == null ? '--' : '$recommended분';
    return '권장 시간 $recommendedText / 현재 풀이 시간 ${_formatSolveElapsed(_timerDisplaySeconds)}';
  }

  String _formatSolveElapsed(int seconds) {
    final clamped = seconds.clamp(0, 40 * 60).toInt();
    if (clamped < 5 * 60) {
      final minutes = clamped ~/ 60;
      final remain = clamped % 60;
      if (minutes <= 0) return '$remain초';
      return '$minutes분 ${remain.toString().padLeft(2, '0')}초';
    }
    return '${clamped ~/ 60}분';
  }

  int? _recommendedMinutesForCurrentQuest() {
    final quest = _currentQuest;
    if (quest == null) return null;
    for (final sectionName in const ['info', 'data', 'header']) {
      final section = quest[sectionName];
      if (section is! Map) continue;
      final minutes = _readPositiveInt(section, const [
        'recommended_minutes',
        'recommend_minutes',
        'recommended_time_minutes',
        'recommended_solve_minutes',
        'estimated_minutes',
        'expected_minutes',
        'solve_minutes',
        'time_limit_minutes',
        'duration_minutes',
      ]);
      if (minutes != null) return minutes;
      final seconds = _readPositiveInt(section, const [
        'recommended_seconds',
        'recommended_time_seconds',
        'recommended_solve_seconds',
        'time_limit_seconds',
        'solve_seconds',
      ]);
      if (seconds != null) return (seconds / 60).ceil();
    }
    return null;
  }

  int? _readPositiveInt(Map<dynamic, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final raw = source[key];
      final value = raw is num
          ? raw.toInt()
          : int.tryParse(raw?.toString() ?? '');
      if (value != null && value > 0) return value;
    }
    return null;
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
    unawaited(_saveContinueForCurrentQuest());
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
    unawaited(_loadContinueForCurrentQuest());
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
      _continueLoaded = false;
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
      final resolvedStroke = _alignStrokeToNearestNoteLine(stroke);
      _strokes.add(resolvedStroke);
      _strokeHistory.add(resolvedStroke);
      _undoStack.add(_AddAction(resolvedStroke));
    }
    _currentStroke = null;
    _lastFilteredPoint = null;
    _bumpPaint();
  }

  _Stroke _alignStrokeToNearestNoteLine(_Stroke stroke) {
    if (!_noteLinesEnabled) return stroke;
    final bounds = stroke.resolvedBounds;
    if (bounds == null) return stroke;
    if (stroke.points.length < 2) return stroke;
    if (bounds.top < _noteLineStartY - _noteLineSpacing * 0.55) return stroke;
    if (!_looksLikeLineSnapCandidate(stroke, bounds)) return stroke;

    final offsets = _lineSnapOffsetsForStroke(stroke, bounds);
    if (offsets == null) return stroke;
    if (offsets.every((dy) => dy == 0)) return stroke;
    return _translatedStrokeByOffsets(stroke, offsets);
  }

  bool _looksLikeLineSnapCandidate(_Stroke stroke, Rect bounds) {
    if (stroke.length < 4) return false;
    if (bounds.height > _noteLineSpacing * 2.35) return false;
    final isTallMark = bounds.height > bounds.width * 1.8 && bounds.height > 18;
    if (isTallMark) return false;
    final isDiagramLike =
        bounds.width > _baseWidth * 0.18 && bounds.height > _noteLineSpacing;
    if (isDiagramLike) return false;
    return true;
  }

  List<double>? _lineSnapOffsetsForStroke(_Stroke stroke, Rect bounds) {
    final groups = _lineGroupsForStroke(stroke);
    if (groups.isEmpty) return null;
    final totalPointCount = stroke.points.length;
    final meaningfulGroups =
        groups.entries
            .where(
              (entry) =>
                  entry.value.length >= math.max(2, totalPointCount * 0.08),
            )
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    if (meaningfulGroups.isEmpty || meaningfulGroups.length > 4) return null;

    if (meaningfulGroups.length > 1) {
      final tooVertical = bounds.width < bounds.height * 1.15;
      if (tooVertical) return null;
      final minGroupSize = math.max(3, totalPointCount * 0.14);
      if (meaningfulGroups.any((entry) => entry.value.length < minGroupSize)) {
        return null;
      }
    }

    final offsets = List<double>.filled(totalPointCount, 0);
    var changed = false;
    var minY = double.infinity;
    var maxY = -double.infinity;
    for (final entry in meaningfulGroups) {
      final dy = _snapOffsetForGroup(stroke, entry.key, entry.value);
      if (dy == null) return null;
      if (dy.abs() > 0) changed = true;
      for (final pointIndex in entry.value) {
        offsets[pointIndex] = dy;
        final y = stroke.points[pointIndex].position.dy + dy;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }

    if (!changed) return null;
    if (minY < 0 || maxY > _logicalHeight) return null;
    return offsets;
  }

  Map<int, List<int>> _lineGroupsForStroke(_Stroke stroke) {
    final groups = <int, List<int>>{};
    for (var i = 0; i < stroke.points.length; i++) {
      final y = stroke.points[i].position.dy;
      if (y < _noteLineStartY - _noteLineSpacing * 0.55) continue;
      final lineIndex = _nearestNoteLineIndex(y);
      (groups[lineIndex] ??= <int>[]).add(i);
    }
    return groups;
  }

  double? _snapOffsetForGroup(
    _Stroke stroke,
    int lineIndex,
    List<int> pointIndexes,
  ) {
    final baseline = _baselineYForPointIndexes(stroke, pointIndexes);
    final target = _noteLineYForIndex(lineIndex);
    final dy = target - baseline;
    if (dy.abs() < 5) return 0;
    if (dy.abs() > _noteLineSpacing * 0.44) return null;
    return dy;
  }

  double _baselineYForPointIndexes(_Stroke stroke, List<int> pointIndexes) {
    final ys =
        pointIndexes.map((index) => stroke.points[index].position.dy).toList()
          ..sort();
    if (ys.length == 1) return ys.first;
    final index = ((ys.length - 1) * 0.82).round().clamp(0, ys.length - 1);
    return ys[index];
  }

  int _nearestNoteLineIndex(double y) {
    final index = ((y - _noteLineStartY) / _noteLineSpacing).round();
    return index < 0 ? 0 : index;
  }

  double _noteLineYForIndex(int index) {
    final safeIndex = index < 0 ? 0 : index;
    return _noteLineStartY + safeIndex * _noteLineSpacing;
  }

  _Stroke _translatedStrokeByOffsets(_Stroke source, List<double> offsets) {
    final copy = _Stroke(
      id: source.id,
      color: source.color,
      baseWidth: source.baseWidth,
      order: source.order,
      startTime: source.startTime,
    );
    for (var i = 0; i < source.points.length; i++) {
      final point = source.points[i];
      copy.addPoint(
        point.position + Offset(0, offsets[i]),
        point.pressure,
        point.timestamp,
      );
    }
    copy.endTime = source.endTime;
    return copy;
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
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: _surfaceColor,
            body: SafeArea(
              top: true,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildCanvasArea()),
                  _buildToolbar(),
                ],
              ),
            ),
          ),
          if (_questLoading) _buildGenerationOverlay(),
          if (!_questLoading && _hasPendingGeneration)
            _buildGenerationStatusBadge(),
        ],
      ),
    );
  }

  Future<void> _saveContinueForCurrentQuest() async {
    final questId = _currentQuestId().trim();
    if (questId.isEmpty) return;
    try {
      final payload = _serializeStrokes(_strokes);
      await ApiClient.instance.saveContinueStrokes(
        kind: 'problem',
        targetId: questId,
        strokes: payload,
        forcedExit: true,
        allowBack: true,
        completed: false,
      );
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _loadContinueForCurrentQuest() async {
    if (_continueLoaded) return;
    final questId = _currentQuestId().trim();
    if (questId.isEmpty) return;
    try {
      final state = await ApiClient.instance.loadContinueStrokes(
        kind: 'problem',
        targetId: questId,
      );
      if (state == null) return;
      // 빈 스트로크라도 바로 적용해 이어하기 진입이 끊기지 않도록 허용
      _applyStrokes(state.strokes);
      _continueLoaded = true;
      _bumpPaint();
    } catch (_) {
      // ignore load failure
    }
  }

  List<Map<String, dynamic>> _serializeStrokes(List<_Stroke> strokes) {
    return strokes
        .map(
          (stroke) => {
            'id': stroke.id,
            'color': stroke.color.value,
            'width': stroke.baseWidth,
            'order': stroke.order,
            'start': stroke.startTime,
            'points': stroke.points
                .map(
                  (pt) => {
                    'x': pt.position.dx,
                    'y': pt.position.dy,
                    'p': pt.pressure,
                    't': pt.timestamp,
                  },
                )
                .toList(),
          },
        )
        .toList();
  }

  void _applyStrokes(List<dynamic> payload) {
    final restored = <_Stroke>[];
    for (final raw in payload) {
      if (raw is! Map) continue;
      final id = (raw['id'] ?? 'restored').toString();
      final colorValue =
          int.tryParse(raw['color']?.toString() ?? '') ?? Colors.black.value;
      final width = (raw['width'] as num?)?.toDouble() ?? 3.0;
      final order = (raw['order'] as num?)?.toInt() ?? 0;
      final start =
          (raw['start'] as num?)?.toDouble() ??
          _problemClock.elapsedMicroseconds / 1e6;
      final stroke = _Stroke(
        id: id,
        color: Color(colorValue),
        baseWidth: width,
        order: order,
        startTime: start,
      );
      final points = raw['points'];
      if (points is List) {
        for (final p in points) {
          if (p is! Map) continue;
          final dx = (p['x'] as num?)?.toDouble();
          final dy = (p['y'] as num?)?.toDouble();
          final pr = (p['p'] as num?)?.toDouble() ?? 1.0;
          final ts =
              (p['t'] as num?)?.toDouble() ??
              (p['timestamp'] as num?)?.toDouble() ??
              start;
          if (dx == null || dy == null) continue;
          stroke.addPoint(Offset(dx, dy), pr, ts);
        }
      }
      restored.add(stroke);
    }
    _strokes
      ..clear()
      ..addAll(restored);
  }

  Widget _buildGenerationOverlay() {
    final generatedCount = _generatedQuestCount;
    final totalCount = math.max(1, _problemCount);
    final progressValue = generatedCount > 0
        ? (generatedCount / totalCount).clamp(0.0, 1.0)
        : (_generationProgress > 0 && _generationProgress < 1)
        ? _generationProgress
        : null;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          color: Colors.black.withValues(alpha: 0.28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 22),
                padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE4EAE3)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 26,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _kGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: _kGreen,
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$generatedCount/$totalCount개 생성중',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF17251C),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                '문제를 준비하고 있습니다',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Color(0xFF667067),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progressValue,
                        minHeight: 10,
                        backgroundColor: const Color(0xFFEAF0EA),
                        color: _kGreen,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '생성된 문제부터 순서대로 배치됩니다. 문제 수가 많으면 최대 6분까지 걸릴 수 있습니다.',
                      style: TextStyle(
                        color: Color(0xFF465248),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenerationStatusBadge() {
    final generatedCount = _generatedQuestCount;
    final totalCount = math.max(1, _problemCount);
    final progressValue = (generatedCount / totalCount).clamp(0.0, 1.0);
    return Positioned(
      top: 92,
      right: 24,
      child: IgnorePointer(
        ignoring: true,
        child: Container(
          width: 280,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE4EAE3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: _kGreen,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$generatedCount/$totalCount개 생성중',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF17251C),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFEAF0EA),
                  color: _kGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final scale = _uiScale(context);
    return Container(
      color: Colors.white,
      height: 72 * scale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Center(
              child: IgnorePointer(
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
          ),
          Positioned(
            left: 16 * scale,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                iconSize: 28 * scale,
                icon: const Icon(Icons.arrow_back, color: _kGreen),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          Positioned(
            right: 8 * scale,
            top: 0,
            bottom: 0,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAppBarTimer(scale),
                  SizedBox(width: 12 * scale),
                  IconButton(
                    iconSize: 28 * scale,
                    icon: const Icon(Icons.info_outline, color: _kGreen),
                    onPressed: _showSolveInfo,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarTimer(double scale) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 360 * scale),
      child: Text(
        _solveTimerLabel(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: _kGreen,
          fontSize: 13 * scale,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }

  void _showSolveInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('문제풀이 안내'),
        content: const Text(
          '문제를 읽고 노트 공간에 풀이를 작성하세요.\n'
          '긴 풀이공간은 화면을 키우지 않고 아래로만 확장됩니다.\n'
          '노트 줄은 하단 스위치로 켜고 끌 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rightPadding = _scrollEnabled ? _scrollbarThickness + 6 : 0.0;
        final viewportWidth = math.max(0.0, constraints.maxWidth);
        final drawableWidth = math.max(0.0, viewportWidth - rightPadding);
        final widthScale = viewportWidth <= 0
            ? 1.0
            : viewportWidth / _baseWidth;
        // 풀이판은 화면 폭을 기준으로 채운다. 긴 풀이공간은 이 배율을
        // 그대로 유지하고 논리 높이만 늘려서 아래로 확장한다.
        final scale = widthScale;
        final displayWidth = _baseWidth * scale;
        final displayHeight = _logicalHeight * scale;
        final viewportHeight = _scrollEnabled
            ? displayHeight
            : constraints.maxHeight;
        final leftOffset = math.min(0.0, (drawableWidth - displayWidth) / 2);
        const topOffset = 0.0;

        Widget buildCanvasStack() {
          return SizedBox(
            width: viewportWidth,
            height: viewportHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _noteLinesEnabled
                      ? CustomPaint(
                          painter: _NotebookPaperPainter(
                            lineStartY: _noteLineStartY * scale + topOffset,
                            lineSpacing: _noteLineSpacing * scale,
                            leftMargin: _noteLeftMargin * scale + leftOffset,
                          ),
                        )
                      : const ColoredBox(color: Colors.white),
                ),
                Positioned(
                  left: leftOffset,
                  top: topOffset,
                  width: displayWidth,
                  height: displayHeight,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: Colors.transparent),
                    child: ClipRect(
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
                ),
                Positioned(
                  left: leftOffset,
                  top: topOffset,
                  width: displayWidth,
                  height: displayHeight,
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
                            size: Size(displayWidth, displayHeight),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          color: Colors.white,
          padding: EdgeInsets.only(right: rightPadding),
          child: Scrollbar(
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
              child: buildCanvasStack(),
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
    return Stack(
      children: [
        Positioned(
          left: 150,
          right: 150,
          top: 42,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _problemCardMinWidth,
                maxWidth: _problemCardMaxWidth,
                minHeight: _problemCardMinHeight,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _lineColor),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(34, 24, 34, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildProblemPrompt(displayBlocks: displayBlocks),
                      if (optionBlocks.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _buildOptionPreview(
                          optionBlocks,
                          selectedIndex: _currentSelectedChoice(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProblemPrompt({required List<ContentBlock> displayBlocks}) {
    if (_questLoading) {
      return Row(
        children: const [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('문제를 불러오는 중입니다...'),
        ],
      );
    }
    if (_questError != null) {
      return Text(
        _questError!,
        style: const TextStyle(color: Colors.redAccent),
      );
    }
    return ContentBlocksView(
      blocks: displayBlocks,
      textStyle: const TextStyle(
        fontSize: 24,
        height: 1.45,
        color: Color(0xFF242924),
      ),
      latexStyle: const TextStyle(
        fontSize: 24,
        height: 1.45,
        color: Color(0xFF242924),
      ),
      inline: true,
    );
  }

  Widget _buildOptionPreview(
    List<List<ContentBlock>> options, {
    required int? selectedIndex,
  }) {
    const activeColor = Color(0xFF1B402B);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(options.length, (index) {
        final isSelected = selectedIndex == index;
        final textColor = isSelected ? activeColor : const Color(0xFF242924);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _toggleChoice(index),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOptionCircle(_optionLabel(index), isSelected),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ContentBlocksView(
                        blocks: options[index],
                        textStyle: TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          color: textColor,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                        latexStyle: TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          color: textColor,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                        inline: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
    final hasStudentWork = _strokes.isNotEmpty || _currentStroke != null;
    final canSubmit = hasOptions ? selectedIndex != null : hasStudentWork;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.min(constraints.maxWidth - 48, 1260.0);
        return Container(
          color: _surfaceColor,
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
          child: Center(
            child: Container(
              width: math.max(0.0, maxWidth),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _lineColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Wrap(
                    spacing: 14,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _ToolbarIcon(
                        icon: Icons.edit_outlined,
                        tooltip: '펜',
                        size: 25,
                        color: _toolMode == _ToolMode.pen
                            ? activeColor
                            : inactiveColor,
                        onTap: () => _setToolMode(_ToolMode.pen),
                      ),
                      _ToolbarIcon(
                        icon: Icons.cleaning_services_outlined,
                        tooltip: '지우개',
                        size: 24,
                        color: _toolMode == _ToolMode.eraser
                            ? activeColor
                            : inactiveColor,
                        onTap: () => _setToolMode(_ToolMode.eraser),
                      ),
                      _ToolbarIcon(
                        icon: Icons.color_lens_outlined,
                        tooltip: '색상',
                        size: 25,
                        color: _penColor,
                        onTap: _openPenSettings,
                      ),
                      _buildNoteLineSwitch(activeColor),
                      const SizedBox(
                        height: 32,
                        child: VerticalDivider(
                          thickness: 2,
                          color: Color(0xFFE0E3E7),
                        ),
                      ),
                      _ToolbarIcon(
                        icon: Icons.undo_outlined,
                        tooltip: '되돌리기',
                        size: 24,
                        color: _undoStack.isEmpty ? inactiveColor : activeColor,
                        onTap: _undoStack.isEmpty ? null : _undo,
                      ),
                      _ToolbarIcon(
                        icon: Icons.delete_outline,
                        tooltip: '전체 지우기',
                        size: 25,
                        color: (_strokes.isEmpty && _currentStroke == null)
                            ? inactiveColor
                            : activeColor,
                        onTap: (_strokes.isEmpty && _currentStroke == null)
                            ? null
                            : _clearAll,
                      ),
                      const SizedBox(
                        height: 32,
                        child: VerticalDivider(
                          thickness: 2,
                          color: Color(0xFFE0E3E7),
                        ),
                      ),
                      _ToolbarIcon(
                        icon: Icons.expand_more_rounded,
                        tooltip: _scrollEnabled ? '기본 풀이 공간' : '긴 풀이 공간',
                        size: 27,
                        color: _scrollEnabled ? activeColor : inactiveColor,
                        onTap: _toggleScroll,
                      ),
                      const SizedBox(
                        height: 32,
                        child: VerticalDivider(
                          thickness: 2,
                          color: Color(0xFFE0E3E7),
                        ),
                      ),
                      if (hasOptions)
                        _buildChoiceMenuButton(
                          optionCount: optionBlocks.length,
                          selectedIndex: selectedIndex,
                          activeColor: activeColor,
                          inactiveColor: inactiveColor,
                        ),
                      if (_gradeImmediately)
                        _ToolbarIcon(
                          icon: Icons.arrow_forward,
                          tooltip: '제출',
                          size: 26,
                          color: !canSubmit || _analysisBusy
                              ? inactiveColor
                              : activeColor,
                          onTap: !canSubmit || _analysisBusy
                              ? null
                              : _handleGrade,
                        )
                      else ...[
                        _ToolbarIcon(
                          icon: Icons.arrow_back_ios_new,
                          tooltip: '이전 문제',
                          size: 21,
                          color: _currentProblemIndex == 0
                              ? inactiveColor
                              : activeColor,
                          onTap: _currentProblemIndex == 0
                              ? null
                              : _goToPreviousProblem,
                        ),
                        Text(
                          '${_currentProblemIndex + 1}/$_problemCount',
                          style: TextStyle(
                            color: activeColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        _ToolbarIcon(
                          icon: Icons.arrow_forward_ios,
                          tooltip: '다음 문제',
                          size: 21,
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoteLineSwitch(Color activeColor) {
    return Tooltip(
      message: '노트 줄',
      child: SizedBox(
        height: 40,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notes_rounded,
              size: 23,
              color: _noteLinesEnabled ? activeColor : const Color(0xFF6B6B6B),
            ),
            const SizedBox(width: 2),
            Transform.scale(
              scale: 0.72,
              child: Switch(
                value: _noteLinesEnabled,
                onChanged: _toggleNoteLines,
                activeThumbColor: activeColor,
                activeTrackColor: activeColor.withValues(alpha: 0.28),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceMenuButton({
    required int optionCount,
    required int? selectedIndex,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final hasSelection = selectedIndex != null;
    return Tooltip(
      message: '객관식 선택',
      child: PopupMenuButton<int>(
        tooltip: '',
        offset: const Offset(0, -56),
        onSelected: _toggleChoice,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _lineColor),
        ),
        itemBuilder: (context) => List.generate(optionCount, (index) {
          final isSelected = selectedIndex == index;
          return PopupMenuItem<int>(
            value: index,
            height: 40,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildOptionCircle(_optionLabel(index), isSelected),
                const SizedBox(width: 8),
                Text(
                  '${index + 1}번',
                  style: TextStyle(
                    color: isSelected ? activeColor : const Color(0xFF242924),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
        child: SizedBox(
          width: 44,
          height: 40,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.format_list_numbered_rounded,
                  size: 24,
                  color: hasSelection ? activeColor : inactiveColor,
                ),
                if (hasSelection) ...[
                  const SizedBox(width: 2),
                  Text(
                    '${selectedIndex + 1}',
                    style: TextStyle(
                      color: activeColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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

  Future<void> _handleObjectiveGrade() async {
    final selectedIndex = _currentSelectedChoice();
    if (selectedIndex == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('보기를 선택해 주세요.')));
      return;
    }
    if (_currentProblemIndex < _problemGraded.length &&
        _problemGraded[_currentProblemIndex]) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미 제출한 문제입니다.')));
      return;
    }
    final questId = _currentQuestId();
    if (questId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('문제 ID가 없습니다.')));
      return;
    }
    setState(() => _analysisBusy = true);
    try {
      final result = await ApiClient.instance.gradeVariantSolve(
        questId: questId,
        selectedIndex: selectedIndex,
      );
      final isCorrect = result['raw_correct'] == true || result['pass'] == true;
      final quest = _currentQuest;
      final fingerprint = _problemFingerprint(quest, _currentProblemIndex);
      final problemMeta = _problemMeta(quest);
      if (_currentProblemIndex < _problemGraded.length) {
        _problemGraded[_currentProblemIndex] = true;
      }
      _gradedCount += 1;
      if (isCorrect) _correctCount += 1;
      await widget.config?.onProblemGraded?.call(
        itemIndex: _currentProblemIndex + 1,
        quest: quest,
        isCorrect: isCorrect,
        stepCorrectness: const <Map<String, dynamic>>[],
        selectedIndex: selectedIndex,
        elapsedSeconds: _sessionClock.elapsed.inSeconds,
      );
      try {
        if (isCorrect) {
          await ActivityStore.recordProblemSolve(
            problemId: fingerprint,
            problemNumber: fingerprint,
            difficultyTier: _tierForProblemIndex(_currentProblemIndex),
            meta: problemMeta.isEmpty ? null : problemMeta,
          );
        } else {
          await ActivityStore.recordProblemIncorrect(
            problemId: fingerprint,
            problemNumber: fingerprint,
            meta: problemMeta.isEmpty ? null : problemMeta,
          );
        }
      } catch (_) {}
      if (!mounted) return;
      final elapsed = _sessionClock.elapsed.inSeconds;
      final hasNext = _currentProblemIndex < _problemCount - 1;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(isCorrect ? '정답' : '오답'),
          content: Text('풀이 시간 ${elapsed}초'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (hasNext) _goToNextProblem();
              },
              child: Text(hasNext ? '다음 문제' : '확인'),
            ),
          ],
        ),
      );
      _completeCourseModuleIfNeeded();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('채점 실패: $error')));
    } finally {
      if (mounted) setState(() => _analysisBusy = false);
    }
  }

  void _completeCourseModuleIfNeeded() {
    if (_completionReported || _passRate <= 0 || _gradedCount < _problemCount) {
      return;
    }
    _completionReported = true;
    final achieved = (_correctCount / _problemCount * 100).round();
    final passed = achieved >= _passRate;
    final elapsed = _sessionClock.elapsed.inSeconds;
    widget.config?.onComplete?.call(
      correctCount: _correctCount,
      totalCount: _problemCount,
      passed: passed,
      elapsedSeconds: elapsed,
    );
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(passed ? '통과' : '미통과'),
        content: Text('정답률 $achieved% (요구 $_passRate%)\n풀이 시간 ${elapsed}초'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
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
    if (_currentQuestOptionBlocks().isNotEmpty) {
      await _handleObjectiveGrade();
      return;
    }
    if (_strokes.length <= 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('올바른 풀이를 작성해주세요')));
      return;
    }
    setState(() => _analysisBusy = true);
    final navigator = Navigator.of(context);
    var gradingShown = false;
    navigator.push(MaterialPageRoute(builder: (_) => const _GradingScreen()));
    gradingShown = true;
    try {
      final studentWorkImage = await _renderStrokesToPng();
      final problemImage = _sendProblemImage
          ? await _renderProblemToPng()
          : Uint8List(0);
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
                  (response.debugInfo?['ocr'] as Map<String, dynamic>?) ??
                  const {},
              gradingPayload: payload,
              gradingDebug: response.debugInfo,
              gradingResult: {
                'status': response.status
                    .map(
                      (item) => {
                        'flow_number': item['flow_number'],
                        'status': item['status'],
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
                            'flow_number': item['flow_number'],
                            'status': item['status'],
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
      final fingerprint = _problemFingerprint(quest, _currentProblemIndex);
      final problemMeta = _problemMeta(quest);
      if (_ratingEnabled) {
        unawaited(
          _submitRatingUpdate(
            quest: quest,
            isCorrect: isCorrect,
            stepCorrectness: stepCorrectness,
          ),
        );
      }
      await widget.config?.onProblemGraded?.call(
        itemIndex: _currentProblemIndex + 1,
        quest: quest,
        isCorrect: isCorrect,
        stepCorrectness: stepCorrectness,
        selectedIndex: null,
        elapsedSeconds: _sessionClock.elapsed.inSeconds,
      );
      if (isCorrect) {
        try {
          await ActivityStore.recordProblemSolve(
            problemId: fingerprint,
            problemNumber: fingerprint,
            difficultyTier: _tierForProblemIndex(_currentProblemIndex),
            meta: problemMeta.isEmpty ? null : problemMeta,
          );
        } catch (_) {}
      } else if (!insufficientData) {
        try {
          await ActivityStore.recordProblemIncorrect(
            problemId: fingerprint,
            problemNumber: fingerprint,
            meta: problemMeta.isEmpty ? null : problemMeta,
          );
        } catch (_) {}
      }
      _gradedCount += 1;
      if (isCorrect) {
        _correctCount += 1;
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
        _completeCourseModuleIfNeeded();
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
      'temperature': _fixedGenTemperature,
      'top_p': _fixedGenTopP,
      'top_k': _fixedGenTopK,
      'max_output_tokens': _fixedGenMaxTokens,
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
    final answerTime = _nowSeconds();
    try {
      final rating = await ApiClient.instance.submitRating(
        questId: questId,
        isCorrect: isCorrect,
        stepCorrectness: stepCorrectness,
        answerTime: answerTime,
        submissionId: 'solve:$_ratingSessionId:$_currentProblemIndex:$questId',
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

class _NotebookPaperPainter extends CustomPainter {
  const _NotebookPaperPainter({
    required this.lineStartY,
    required this.lineSpacing,
    required this.leftMargin,
  });

  final double lineStartY;
  final double lineSpacing;
  final double leftMargin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    final linePaint = Paint()
      ..color = const Color(0xFFE8E8ED)
      ..strokeWidth = 0.8;
    for (var y = lineStartY; y <= size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final marginPaint = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..strokeWidth = 0.6;
    canvas.drawLine(
      Offset(leftMargin, 0),
      Offset(leftMargin, size.height),
      marginPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _NotebookPaperPainter oldDelegate) {
    return oldDelegate.lineStartY != lineStartY ||
        oldDelegate.lineSpacing != lineSpacing ||
        oldDelegate.leftMargin != leftMargin;
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
