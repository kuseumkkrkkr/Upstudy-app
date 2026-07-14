part of 'package:s11/sessions/exam_paper/session/exam_paper_page.dart';

enum _ToolMode { pen, eraser, pan }

const double _paperWidth = 794;
const double _paperHeight = _paperWidth * 297 / 210;
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
  /// 상단 입력 레이어에서 객관식 보기 클릭 여부를 판별한다.
  /// 실제 구현은 보기의 화면 좌표를 관리하는 UI 믹스인이 제공한다.
  bool _selectOptionAt(Offset globalPosition);

  final ValueNotifier<int> _paintVersion = ValueNotifier<int>(0);

  final ValueNotifier<Matrix4> _viewMatrix = ValueNotifier<Matrix4>(
    Matrix4.identity(),
  );

  final ValueNotifier<double> _zoomScaleNotifier = ValueNotifier<double>(1.0);

  Timer? _pollTimer;
  Timer? _examCountdownTimer;
  int? _remainingSeconds;
  final DateTime _examStartedAt = DateTime.now();
  bool _courseModuleCompletionSubmitted = false;
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

  Offset? _eraserPosition;
  int? _eraserPageIndex;

  bool _eraserActive = false;

  /// 지우개 도구 선택 시 포인터를 따라 그릴 미리보기 위치와 페이지다.
  /// 드래그 여부와 분리해 마우스를 누르지 않아도 지우개 위치를 안정적으로 표시한다.
  Offset? _eraserCursorPosition;
  int? _eraserCursorPageIndex;

  /// 객관식 보기의 화면 좌표를 문항·보기 번호별로 보관한다.
  /// 캔버스 입력 레이어가 보기 위에 있으므로 포인터 위치로 선택 대상을 판별할 때 사용한다.
  final Map<int, Map<int, Rect>> _optionHitRegions = <int, Map<int, Rect>>{};

  /// 객관식 보기의 렌더 영역을 안정적으로 조회하기 위한 키다.
  /// 시험지 재빌드 후에도 같은 키를 재사용해 실제 화면 좌표를 갱신한다.
  final Map<String, GlobalKey> _optionHitRegionKeys = <String, GlobalKey>{};

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
                'color': stroke.color.toARGB32(),
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
            int.tryParse(raw['color']?.toString() ?? '') ??
            Colors.black.toARGB32();
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
  /// 필요한 변수는 제한 시간·페이지 수 힌트·초기 페이지다.
  /// 작동 원리는 타이머와 캔버스 버퍼를 먼저 만든 뒤 서버 시험지가 있으면 비동기 상태 갱신을 시작하는 것이다.
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
    _currentPageIndex = widget.initialPageIndex.clamp(0, _pageCount - 1);

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
