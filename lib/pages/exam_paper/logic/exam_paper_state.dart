part of 'package:s11/pages/exam_paper_page.dart';


enum _ToolMode { pen, eraser }


const double _paperWidth = 794;
const double _paperHeight = _paperWidth * 297 / 210;
const double _expandedHeight = 2600;
const double _eraserRadius = 26;
const double _minPointDistance = 0.6;
const Color _kGreen = Color(0xFF1B402B);
const double _zoomMin = 0.5;
const double _zoomMax = 2.0;
const double _thumbnailTargetWidth = 120;
const double _pageScrollThreshold = 160.0;
const Duration _pageScrollCooldown = Duration(milliseconds: 320);
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

  final ValueNotifier<Matrix4> _viewMatrix =

      ValueNotifier<Matrix4>(Matrix4.identity());

  final ValueNotifier<double> _zoomScaleNotifier = ValueNotifier<double>(1.0);


  Timer? _pollTimer;

  ExamStatus? _examStatus;

  bool _loadingExam = false;

  String? _examError;

  List<_PageLayout> _pageLayouts = const [];


  int _currentPageIndex = 0;

  bool _sidebarVisible = true;


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


  _Stroke? _currentStroke;
  int? _currentStrokePageIndex;

  int _nextStrokeOrder = 0;

  int? _activePointer;

  Offset? _lastFilteredPoint;


  _ToolMode _toolMode = _ToolMode.pen;

  Color _penColor = Colors.black;

  double _penWidth = 3;


  bool _scrollEnabled = false;
  double _scrollAccumulator = 0.0;
  int _scrollDirection = 0;
  DateTime? _lastScrollSwitchAt;


  Offset? _eraserPosition;
  int? _eraserPageIndex;

  bool _eraserActive = false;


  bool _headerVisible = false;

  double _headerDragDistance = 0.0;


  bool _toolbarVisible = true;

  double _toolbarDragDistance = 0.0;


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


  double? _estimatedHeaderHeight;

  double? _estimatedFooterHeight;


  final Map<int, Uint8List> _thumbnailBytes = <int, Uint8List>{};
  final Set<int> _thumbnailQueue = <int>{};
  final Set<int> _thumbnailAttempted = <int>{};
  bool _thumbnailRenderBusy = false;
  int? _thumbnailRenderIndex;
  final GlobalKey _thumbnailBoundaryKey = GlobalKey();
  bool _thumbnailProcessScheduled = false;
}

class _ExamPaperPageState extends _ExamPaperStateBase
    with
        _ExamPaperInteractionMixin,
        _ExamPaperGradingMixin,
        _ExamPaperUiMixin {
  @override
  void initState() {
    super.initState();

    _ensurePageBuffers(_pageCount);

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
    _pollTimer?.cancel();
    _paintVersion.dispose();
    _viewMatrix.dispose();
    _zoomScaleNotifier.dispose();
    super.dispose();
  }
}
