part of 'package:s11/sessions/exam_paper/session/exam_paper_page.dart';

enum _ToolMode { pen, eraser, pan }

const double _paperWidth = 794;
const double _paperHeight = _paperWidth * 297 / 210;
const double _expandedHeight = 2600;
const double _eraserRadius = 26;
const double _minPointDistance = 0.6;
const Color _kGreen = Color(0xFF1B402B);
const double _zoomMin = 0.5;
const double _zoomMax = 2.0;
const double _thumbnailTargetWidth = 120;
const double _pageGap = 32.0;
const double _scrollEdgePadding = 60.0;

const Color _penRed = Color(0xFFE53935);
const Color _penBlue = Color(0xFF1E88E5);
const List<Color> _penColors = [_penRed, _penBlue, Colors.black];
const List<double> _penWidths = [5, 3, 1];

const double _secondaryHeaderHeight = 30.0;

class _NextPageIntent extends Intent {
  const _NextPageIntent();
}

class _PreviousPageIntent extends Intent {
  const _PreviousPageIntent();
}

abstract class _ExamPaperStateBase extends State<ExamPaperPage> {
  final ValueNotifier<int> _paintVersion = ValueNotifier<int>(0);

  final ValueNotifier<Matrix4> _viewMatrix = ValueNotifier<Matrix4>(
    Matrix4.identity(),
  );

  final ValueNotifier<double> _zoomScaleNotifier = ValueNotifier<double>(1.0);

  Timer? _pollTimer;
  Timer? _examCountdownTimer;
  int? _remainingSeconds;
  bool _continueLoaded = false;

  ExamStatus? _examStatus;

  bool _loadingExam = false;

  String? _examError;

  List<_PageLayout> _pageLayouts = const [];

  int _currentPageIndex = 0;

  bool _sidebarVisible = false;

  Size? _viewportSize;

  bool _hasCentered = false;

  bool _isPortrait = false;

  double _zoomScale = 1.0;

  double _currentBaseScale = 1.0;

  Offset _panOffset = Offset.zero;

  bool _gestureActive = false;

  double _gestureStartZoom = 1.0;

  final List<List<_Stroke>> _pageStrokes = <List<_Stroke>>[];

  final List<List<_UndoAction>> _pageUndoStacks = <List<_UndoAction>>[];

  final List<List<_Stroke>> _pagePendingEraseRemoved = <List<_Stroke>>[];

  final Map<int, List<HeatmapEvent>> _heatmapEventsByPage =
      <int, List<HeatmapEvent>>{};
  int _heatmapEventCounter = 0;
  List<Offset>? _currentEraserPoints;

  List<HeatmapEvent> _heatmapEventsForPage(int pageIndex) {
    return _heatmapEventsByPage.putIfAbsent(pageIndex, () => <HeatmapEvent>[]);
  }

  _Stroke? _currentStroke;
  int? _currentStrokePageIndex;

  int _nextStrokeOrder = 0;

  int? _activePointer;

  Offset? _lastFilteredPoint;

  _ToolMode _toolMode = _ToolMode.pan;

  Color _penColor = Colors.black;

  double _penWidth = 3;

  bool _scrollEnabled = true;
  double _scrollAccumulator = 0.0;
  int _scrollDirection = 0;
  DateTime? _lastScrollSwitchAt;

  Offset? _eraserPosition;
  int? _eraserPageIndex;

  bool _eraserActive = false;

  bool _grading = false;

  bool _gradingCancelled = false;
  int _gradingCompleted = 0;
  int _gradingTotal = 0;
  final Map<int, _GradeResult> _gradeResults = <int, _GradeResult>{};
  final Map<String, Map<String, dynamic>> _questCache =
      <String, Map<String, dynamic>>{};
  bool _examFinished = false;
  Uint8List? _gradingPreviewBytes;
  Rect? _gradingPreviewRegion;
  int? _gradingPreviewPageIndex;
  int? _gradingPreviewItemIndex;
  final Map<int, int?> _selectedOptions = <int, int?>{};
  DateTime? _lastFastScrollAt;

  double? _estimatedHeaderHeight;

  double? _estimatedFooterHeight;

  final Map<int, Uint8List> _thumbnailBytes = <int, Uint8List>{};
  final Set<int> _thumbnailQueue = <int>{};
  final Set<int> _thumbnailAttempted = <int>{};
  bool _thumbnailRenderBusy = false;
  int? _thumbnailRenderIndex;
  final GlobalKey _thumbnailBoundaryKey = GlobalKey();
  bool _thumbnailProcessScheduled = false;
  bool _pageSwitching = false;

  Future<void> _loadContinueStrokesIfAny() async {
    final examId = widget.examId?.trim();
    if (examId == null || examId.isEmpty || _continueLoaded) return;
    try {
      final state = await ApiClient.instance.loadContinueStrokes(
        kind: 'exam',
        targetId: examId,
      );
      if (state == null) return;
      // 빈 스트로크라도 이어하기로 불러와 바로 적용할 수 있도록 허용
      _applyContinueStrokes(state.strokes);
      _continueLoaded = true;
      setState(() {});
    } catch (_) {
      // ignore load failures
    }
  }

  Future<void> _saveContinueStrokesIfAny() async {
    final examId = widget.examId?.trim();
    if (examId == null || examId.isEmpty) return;
    try {
      final payload = _serializeContinueStrokes();
      await ApiClient.instance.saveContinueStrokes(
        kind: 'exam',
        targetId: examId,
        strokes: payload,
        forcedExit: true,
        allowBack: true,
        completed: false,
      );
    } catch (_) {
      // best-effort; ignore failure
    }
  }

  List<Map<String, dynamic>> _serializeContinueStrokes() {
    final result = <Map<String, dynamic>>[];
    for (var page = 0; page < _pageStrokes.length; page++) {
      final strokes = _pageStrokes[page];
      if (strokes.isEmpty) continue;
      result.add({
        'page': page,
        'strokes': strokes
            .map(
              (stroke) => {
                'color': stroke.color.value,
                'width': stroke.baseWidth,
                'order': stroke.order,
                'points': stroke.points
                    .map(
                      (pt) => {
                        'x': pt.position.dx,
                        'y': pt.position.dy,
                        'p': pt.pressure,
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
      });
    }
    return result;
  }

  void _applyContinueStrokes(List<dynamic> payload) {
    for (final entry in payload) {
      if (entry is! Map) continue;
      final page = int.tryParse(entry['page']?.toString() ?? '');
      final strokesRaw = entry['strokes'];
      if (page == null || page < 0) continue;
      while (_pageStrokes.length < page + 1) {
        _pageStrokes.add(<_Stroke>[]);
        _pageUndoStacks.add(<_UndoAction>[]);
        _pagePendingEraseRemoved.add(<_Stroke>[]);
      }
      if (strokesRaw is! List) continue;
      final restored = <_Stroke>[];
      for (final raw in strokesRaw) {
        if (raw is! Map) continue;
        final colorValue =
            int.tryParse(raw['color']?.toString() ?? '') ?? Colors.black.value;
        final width = (raw['width'] as num?)?.toDouble() ?? _penWidths.first;
        final order = (raw['order'] as num?)?.toInt() ?? 0;
        final stroke = _Stroke(
          color: Color(colorValue),
          baseWidth: width,
          order: order,
        );
        final points = raw['points'];
        if (points is List) {
          for (final p in points) {
            if (p is! Map) continue;
            final dx = (p['x'] as num?)?.toDouble();
            final dy = (p['y'] as num?)?.toDouble();
            final pr = (p['p'] as num?)?.toDouble() ?? 1.0;
            if (dx == null || dy == null) continue;
            stroke.addPoint(Offset(dx, dy), pr);
          }
        }
        restored.add(stroke);
      }
      _pageStrokes[page] = restored;
    }
  }
}

class _ExamPaperPageState extends _ExamPaperStateBase
    with _ExamPaperInteractionMixin, _ExamPaperGradingMixin, _ExamPaperUiMixin {
  @override
  void initState() {
    super.initState();

    final limitMinutes = widget.timeLimitMinutes;
    if (limitMinutes != null && limitMinutes > 0) {
      _remainingSeconds = limitMinutes * 60;
      _examCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        final current = _remainingSeconds;
        if (current == null) return;
        if (current <= 0) {
          _examCountdownTimer?.cancel();
          return;
        }
        if (!mounted) return;
        setState(() => _remainingSeconds = current - 1);
      });
    }

    _ensurePageBuffers(_pageCount);

    unawaited(_loadContinueStrokesIfAny());

    if (widget.examId != null && widget.examId!.trim().isNotEmpty) {
      _loadingExam = true;
      _fetchExamStatus();
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        final status = _examStatus;
        if (status == null ||
            (status.status != 'done' && status.status != 'failed')) {
          _fetchExamStatus();
        }
      });
    }
  }

  @override
  void dispose() {
    unawaited(_saveContinueStrokesIfAny());
    _pollTimer?.cancel();
    _examCountdownTimer?.cancel();
    _paintVersion.dispose();
    _viewMatrix.dispose();
    _zoomScaleNotifier.dispose();
    super.dispose();
  }
}
