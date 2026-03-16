import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/content_block.dart';
import '../services/api_client.dart';
import '../widgets/content_blocks_view.dart';

class ExamPaperPage extends StatefulWidget {
  const ExamPaperPage({super.key, this.examId});

  final String? examId;

  @override
  State<ExamPaperPage> createState() => _ExamPaperPageState();
}

enum _ToolMode { pen, eraser }

const int _largeFlowThreshold = 5;

class _ExamPaperPageState extends State<ExamPaperPage> {
  static const double _a4Ratio = 210 / 297;
  static const double _paperWidth = 794;
  static const double _paperHeight = _paperWidth / _a4Ratio;
  static const double _expandedHeight = 2600;
  static const double _pageGap = 80;
  static const double _eraserRadius = 26;
  static const double _minPointDistance = 0.6;
  static const Color _kGreen = Color(0xFF1B402B);
  static const double _zoomMin = 0.5;
  static const double _zoomMax = 2.0;

  static const Color _penRed = Color(0xFFE53935);
  static const Color _penBlue = Color(0xFF1E88E5);
  static const List<Color> _penColors = [_penRed, _penBlue, Colors.black];
  static const List<double> _penWidths = [5, 3, 1];

  final ValueNotifier<int> _paintVersion = ValueNotifier<int>(0);

  Timer? _pollTimer;
  ExamStatus? _examStatus;
  bool _loadingExam = false;
  String? _examError;
  List<_PageLayout> _pageLayouts = const [];

  Size? _viewportSize;
  bool _hasCentered = false;
  bool _isPortrait = false;
  double _zoomScale = 1.0;
  double _currentBaseScale = 1.0;
  Offset _panOffset = Offset.zero;
  bool _gestureActive = false;
  double _gestureStartZoom = 1.0;

  final List<_Stroke> _strokes = <_Stroke>[];
  final List<_UndoAction> _undoStack = <_UndoAction>[];
  final List<_Stroke> _pendingEraseRemoved = <_Stroke>[];

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

  bool _headerVisible = false;
  double _headerDragDistance = 0.0;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  double get _contentHeight {
    if (_pageLayouts.isEmpty) {
      return _paperHeight;
    }
    return _pageLayouts.length * _paperHeight +
        math.max(0, _pageLayouts.length - 1) * _pageGap;
  }

  double get _logicalHeight {
    if (_scrollEnabled) {
      return math.max(_expandedHeight, _contentHeight);
    }
    return _contentHeight;
  }
  double get _currentScale => _currentBaseScale * _zoomScale;

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
    });
  }

  void _setZoom(double value) {
    final next = value.clamp(_zoomMin, _zoomMax);
    if (next == _zoomScale) return;
    setState(() => _zoomScale = next);
  }

  void _zoomIn() => _setZoom(_zoomScale + 0.1);

  void _zoomOut() => _setZoom(_zoomScale - 0.1);

  void _resetZoom() => _setZoom(1.0);

  void _handleScaleStart(ScaleStartDetails details) {
    if (details.pointerCount < 2) return;
    _gestureActive = true;
    _gestureStartZoom = _zoomScale;
    if (_activePointer != null) {
      _finishStroke();
      _activePointer = null;
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (!_gestureActive || details.pointerCount < 2) return;
    final nextZoom =
        (_gestureStartZoom * details.scale).clamp(_zoomMin, _zoomMax);
    final oldScale = _currentScale;
    final newScale = _currentBaseScale * nextZoom;
    final scaleChange = newScale / oldScale;
    final focal = details.focalPoint;
    final updatedPan =
        focal - (focal - _panOffset) * scaleChange + details.focalPointDelta;
    setState(() {
      _zoomScale = nextZoom;
      _panOffset = updatedPan;
    });
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _gestureActive = false;
  }

  void _scheduleCenterIfNeeded(Size viewport, {required bool isPortrait}) {
    if (!isPortrait || _hasCentered) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasCentered) return;
      final scale = _currentScale;
      final contentSize = Size(
        _paperWidth * scale,
        _logicalHeight * scale,
      );
      final dx = (viewport.width - contentSize.width) / 2;
      final dy = contentSize.height <= viewport.height
          ? (viewport.height - contentSize.height) / 2
          : 16.0;
      setState(() {
        _panOffset = Offset(dx, dy);
        _hasCentered = true;
      });
    });
  }

  Future<void> _fetchExamStatus() async {
    final examId = widget.examId;
    if (examId == null || examId.trim().isEmpty) {
      return;
    }
    try {
      final status = await ApiClient.instance.getExamStatus(examId);
      if (!mounted) {
        return;
      }
      setState(() {
        _examStatus = status;
        _loadingExam = false;
        _examError = null;
        _pageLayouts = status.items.isEmpty ? const [] : _layoutItems(status.items);
        _hasCentered = false;
      });
      if (status.status == 'done' || status.status == 'failed') {
        _pollTimer?.cancel();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _examError = '시험지를 불러오지 못했습니다.';
        _loadingExam = false;
        _pageLayouts = const [];
        _hasCentered = false;
      });
    }
  }

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

  void _handlePointerDown(PointerDownEvent event) {
    if (_gestureActive || _activePointer != null) return;
    final position = _toLogicalPosition(event.localPosition);
    if (!_withinCanvas(position)) return;
    _activePointer = event.pointer;
    if (_toolMode == _ToolMode.pen) {
      _startStroke(position, _normalizePressure(event));
    } else {
      _startEraser(position);
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_gestureActive || _activePointer != event.pointer) return;
    final position = _toLogicalPosition(event.localPosition);
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
    final stroke = _Stroke(
      color: _penColor,
      baseWidth: _penWidth,
      order: _nextStrokeOrder++,
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
    stroke.addPoint(filtered, pressure);
    _bumpPaint();
  }

  void _finishStroke() {
    final stroke = _currentStroke;
    if (stroke != null && stroke.points.isNotEmpty) {
      _strokes.add(stroke);
      _undoStack.add(_AddAction(stroke));
    }
    _currentStroke = null;
    _lastFilteredPoint = null;
    _bumpPaint();
  }

  void _startEraser(Offset position) {
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
    _strokes.removeWhere(toRemove.contains);
    _pendingEraseRemoved.addAll(toRemove);
  }

  bool _withinCanvas(Offset position) {
    return position.dx >= 0 &&
        position.dy >= 0 &&
        position.dx <= _paperWidth &&
        position.dy <= _logicalHeight;
  }

  Offset _toLogicalPosition(Offset localPosition) {
    final scale = _currentScale;
    if (scale <= 0) return localPosition;
    return Offset(
      (localPosition.dx - _panOffset.dx) / scale,
      (localPosition.dy - _panOffset.dy) / scale,
    );
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
    final headerHeight = 72 * _uiScale(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: _buildCanvasArea()),
              _buildZoomControls(),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                top: _headerVisible ? 0 : -headerHeight,
                left: 0,
                right: 0,
                child: _buildHeader(),
              ),
              Positioned(
                top: _headerVisible ? headerHeight - 12 : 8,
                left: 0,
                right: 0,
                child: _buildHeaderPullHandle(),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildToolbar(),
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

  void _setHeaderVisible(bool value) {
    if (_headerVisible == value) return;
    setState(() => _headerVisible = value);
  }

  void _handleHeaderDragUpdate(DragUpdateDetails details) {
    _headerDragDistance += details.delta.dy;
  }

  void _handleHeaderDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 200 || _headerDragDistance > 24) {
      _setHeaderVisible(true);
    } else if (velocity < -200 || _headerDragDistance < -24) {
      _setHeaderVisible(false);
    }
    _headerDragDistance = 0;
  }

  Widget _buildHeaderPullHandle() {
    final scale = _uiScale(context);
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _setHeaderVisible(!_headerVisible),
        onVerticalDragUpdate: _handleHeaderDragUpdate,
        onVerticalDragEnd: _handleHeaderDragEnd,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12 * scale,
            vertical: 4 * scale,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20 * scale),
            boxShadow: const [
              BoxShadow(
                blurRadius: 6,
                color: Color(0x33000000),
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            _headerVisible
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: 24 * scale,
            color: _kGreen,
          ),
        ),
      ),
    );
  }

  Widget _buildCanvasArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = constraints.biggest;
        if (_viewportSize != viewportSize) {
          _viewportSize = viewportSize;
          _hasCentered = false;
        }
        final isPortrait = viewportSize.height >= viewportSize.width;
        if (_isPortrait != isPortrait) {
          _isPortrait = isPortrait;
          _hasCentered = false;
          if (!isPortrait) {
            _panOffset = Offset.zero;
          }
        }
        final viewportWidth = viewportSize.width;
        final viewportHeight = viewportSize.height;
        if (isPortrait) {
          final fitScale = math.min(
            viewportWidth / _paperWidth,
            viewportHeight / _paperHeight,
          );
          _currentBaseScale = fitScale * 0.94;
        } else {
          _currentBaseScale =
              viewportWidth <= 0 ? 1.0 : viewportWidth / _paperWidth;
        }
        final scale = _currentScale;
        final transform = Matrix4.identity()
          ..translate(_panOffset.dx, _panOffset.dy)
          ..scale(scale);

        _scheduleCenterIfNeeded(viewportSize, isPortrait: isPortrait);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _handleScaleStart,
          onScaleUpdate: _handleScaleUpdate,
          onScaleEnd: _handleScaleEnd,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(color: const Color(0xFFF0F0F0)),
                ),
                Transform(
                  transform: transform,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: _paperWidth,
                    height: _logicalHeight,
                    child: Stack(
                      children: [
                        _buildPaperLayer(),
                        CustomPaint(
                          painter: _StrokePainter(
                            strokes: _strokes,
                            currentStroke: _currentStroke,
                            eraserPosition:
                                _eraserActive ? _eraserPosition : null,
                            eraserRadius: _eraserRadius,
                            logicalSize: Size(_paperWidth, _logicalHeight),
                            backgroundColor: Colors.transparent,
                            repaint: _paintVersion,
                          ),
                          size: Size(_paperWidth, _logicalHeight),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _handlePointerDown,
                    onPointerMove: _handlePointerMove,
                    onPointerUp: _handlePointerUp,
                    onPointerCancel: _handlePointerCancel,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildZoomControls() {
    return Positioned(
      top: 16,
      right: 16,
      child: Material(
        color: Colors.white.withOpacity(0.92),
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ZoomIcon(icon: Icons.add, onTap: _zoomIn),
              GestureDetector(
                onTap: _resetZoom,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    '${(_zoomScale * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              _ZoomIcon(icon: Icons.remove, onTap: _zoomOut),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaperLayer() {
    final layouts = _pageLayouts;
    final hasExamId =
        widget.examId != null && widget.examId!.trim().isNotEmpty;
    final status = _examStatus;
    final isGenerating = _loadingExam ||
        (status != null &&
            status.status != 'done' &&
            status.status != 'failed');
    final statusMessage = isGenerating
        ? '시험지를 생성 중입니다...'
        : _examError ?? (hasExamId ? '시험지 문제가 없습니다.' : null);
    final pages = <Widget>[];
    if (layouts.isEmpty) {
      pages.add(
        _buildPaperSheet(
          child: _ExamPaperContent(
            pageNumber: 1,
            totalPages: 1,
            statusMessage: statusMessage,
          ),
        ),
      );
    } else {
      for (var i = 0; i < layouts.length; i++) {
        pages.add(
          _buildPaperSheet(
            child: _ExamPaperContent(
              layout: layouts[i],
              pageNumber: i + 1,
              totalPages: layouts.length,
            ),
          ),
        );
        if (i < layouts.length - 1) {
          pages.add(SizedBox(height: _pageGap));
        }
      }
    }

    return SizedBox(
      width: _paperWidth,
      height: _logicalHeight,
      child: Align(
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: pages,
        ),
      ),
    );
  }

  Widget _buildPaperSheet({required Widget child}) {
    return Container(
      width: _paperWidth,
      height: _paperHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: Color(0x1A000000),
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(56, 56, 56, 38),
      child: child,
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
          ],
        ),
      ),
    );
  }
}

class _ExamPaperContent extends StatelessWidget {
  const _ExamPaperContent({
    this.layout,
    required this.pageNumber,
    required this.totalPages,
    this.statusMessage,
  });

  final _PageLayout? layout;
  final int pageNumber;
  final int totalPages;
  final String? statusMessage;

  static const TextStyle _baseStyle = TextStyle(
    fontSize: 13.5,
    height: 1.5,
    fontFamily: 'Batang',
    color: Colors.black,
  );
  static const TextStyle _questionNumberStyle = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.bold,
    fontFamily: 'Batang',
  );
  static const TextStyle _pointsStyle = TextStyle(
    fontSize: 11.5,
    fontFamily: 'Batang',
  );
  static const TextStyle _optionStyle = TextStyle(
    fontSize: 11,
    fontFamily: 'Batang',
  );

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: _baseStyle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          Expanded(child: _buildContent()),
          const SizedBox(height: 16),
          _buildFooter(pageNumber: pageNumber, totalPages: totalPages),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black, width: 2)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _outlinePill('제 2 교시', fontSize: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '2025학년도 대학수학능력시험 문제지',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontFamily: 'Batang',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _outlineBox('가형', fontSize: 22),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '수학 영역',
            style: TextStyle(
              fontSize: 41,
              fontWeight: FontWeight.bold,
              letterSpacing: 14,
              fontFamily: 'Batang',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (statusMessage != null) {
      return Center(
        child: Text(
          statusMessage!,
          style: _baseStyle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (layout != null) {
      return _buildDynamicContent(layout!);
    }
    return _buildStaticContent();
  }

  Widget _buildDynamicContent(_PageLayout page) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = constraints.maxWidth / 2;
        final rowHeight = constraints.maxHeight / 2;
        return Stack(
          children: [
            ...page.entries.map((entry) {
              final left = entry.column * columnWidth;
              final top = entry.row * rowHeight;
              final height = rowHeight * entry.rowSpan;
              return Positioned(
                left: left,
                top: top,
                width: columnWidth,
                height: height,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: entry.column == 0 ? 0 : 20,
                    right: entry.column == 0 ? 20 : 0,
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: _buildExamItemCell(entry.item),
                  ),
                ),
              );
            }),
            Positioned(
              left: constraints.maxWidth / 2,
              top: 0,
              bottom: 0,
              child: Container(width: 1, color: Colors.black),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExamItemCell(ExamItem item) {
    final titleBlocks = parseContentBlocks(item.questTitle);
    final displayTitleBlocks = titleBlocks.isEmpty
        ? [const ContentBlock(type: 'text', content: 'Generating...')]
        : titleBlocks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${item.itemIndex}.',
          style: _questionNumberStyle,
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ClipRect(
            child: ContentBlocksView(
              blocks: displayTitleBlocks,
              textStyle: _baseStyle.copyWith(fontSize: 12),
              latexStyle: _baseStyle.copyWith(fontSize: 12),
              spacing: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStaticContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildTopLeft()),
                      const SizedBox(width: 40),
                      Expanded(child: _problemBlock(_problem3())),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _problemBlock(_problem2())),
                      const SizedBox(width: 40),
                      Expanded(child: _problemBlock(_problem4())),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: constraints.maxWidth / 2,
              top: 0,
              bottom: 0,
              child: Container(width: 1, color: Colors.black),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopLeft() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _problemTypeHeader('5????'),
        const SizedBox(height: 18),
        _problem1(),
      ],
    );
  }

  Widget _problemBlock(Widget child) {
    return Align(alignment: Alignment.topLeft, child: child);
  }

  Widget _problem1() {
    final mathStyle = _mathStyle(13.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _problemLine(
          number: '1.',
          text: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '3√5 × ', style: mathStyle),
                TextSpan(text: '25', style: mathStyle),
                WidgetSpan(
                  alignment: PlaceholderAlignment.top,
                  child: Transform.translate(
                    offset: const Offset(0, -4),
                    child: Text('1/3', style: mathStyle.copyWith(fontSize: 9)),
                  ),
                ),
                const TextSpan(text: ' 의 값은?'),
              ],
            ),
          ),
          points: '2점',
        ),
        const SizedBox(height: 12),
        _optionsRow(const ['①', '②', '③', '④', '⑤']),
      ],
    );
  }

  Widget _problem2() {
    final mathStyle = _mathStyle(13.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _problemLine(
          number: '2.',
          text: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '함수 '),
                TextSpan(text: 'f(x) = x', style: mathStyle),
                WidgetSpan(
                  alignment: PlaceholderAlignment.top,
                  child: Transform.translate(
                    offset: const Offset(0, -4),
                    child: Text('3', style: mathStyle.copyWith(fontSize: 9)),
                  ),
                ),
                TextSpan(text: ' - 8x + 7', style: mathStyle),
                const TextSpan(text: '에 대하여 '),
                TextSpan(text: 'lim', style: mathStyle),
                WidgetSpan(
                  alignment: PlaceholderAlignment.bottom,
                  child: Transform.translate(
                    offset: const Offset(0, 4),
                    child: Text('h→0', style: mathStyle.copyWith(fontSize: 9)),
                  ),
                ),
                TextSpan(
                  text: ' (f(2+h)-f(2))/h 의 값은?',
                  style: mathStyle,
                ),
              ],
            ),
          ),
          points: '2점',
        ),
        const SizedBox(height: 12),
        _optionsRow(const ['①', '②', '③', '④', '⑤']),
      ],
    );
  }

  Widget _problem3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _problemLine(
          number: '3.',
          text: const Text('첫째항과 공비가 모두 정수 k인 등비수열 {a_n}이'),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'a₁/a₂ + a₃/a₄ = 30',
            style: _mathStyle(13.5),
          ),
        ),
        const SizedBox(height: 10),
        _problemLine(
          number: '',
          text: const Text('을 만족시킬 때, k의 값은?'),
          points: '3점',
        ),
        const SizedBox(height: 12),
        _optionsRow(const ['①', '②', '③', '④', '⑤']),
      ],
    );
  }

  Widget _problem4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _problemLine(
          number: '4.',
          text: const Text('함수 f(x)가 실수 전체의 집합에서 연속일 때 …'),
          points: '3점',
        ),
        const SizedBox(height: 12),
        _optionsRow(const ['⑥', '⑦', '⑧', '⑨', '⑩']),
      ],
    );
  }

  Widget _buildFooter({required int pageNumber, required int totalPages}) {
    final safeTotal = totalPages < 1 ? 1 : totalPages;
    final safePage = pageNumber.clamp(1, safeTotal);
    return Align(
      alignment: Alignment.center,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: const BoxDecoration(
                color: Color(0xFFE0E0E0),
                border: Border(right: BorderSide(color: Colors.black, width: 1)),
              ),
              child: Text('$safePage'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Text('$safeTotal'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _problemTypeHeader(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _problemLine({
    required String number,
    required Widget text,
    String? points,
  }) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 6,
      runSpacing: 4,
      children: [
        if (number.isNotEmpty)
          Text(number, style: _questionNumberStyle),
        DefaultTextStyle.merge(style: _baseStyle, child: text),
        if (points != null && points.isNotEmpty)
          Text('[$points]', style: _pointsStyle),
      ],
    );
  }

  Widget _optionsRow(List<String> options) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: options
          .map((opt) => Text(opt, style: _optionStyle))
          .toList(),
    );
  }

  Widget _outlinePill(String text, {double fontSize = 20}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _outlineBox(String text, {double fontSize = 20}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
      ),
    );
  }

  TextStyle _mathStyle(double size) => TextStyle(
    fontFamily: 'Times New Roman',
    fontStyle: FontStyle.italic,
    fontSize: size,
    height: 1.5,
  );
}

class _LayoutEntry {
  final ExamItem item;
  final int column;
  final int row;
  final int rowSpan;

  _LayoutEntry(
    this.item, {
    required this.column,
    required this.row,
    required this.rowSpan,
  });
}

class _PageLayout {
  final List<_LayoutEntry> entries;
  final List<bool> columnSpans;

  _PageLayout({
    required this.entries,
    required this.columnSpans,
  });
}

List<_PageLayout> _layoutItems(List<ExamItem> items) {
  final pages = <_PageLayout>[];
  var entries = <_LayoutEntry>[];
  var columnSpans = [false, false];
  var occupied = [
    [false, false],
    [false, false],
  ];

  void flush() {
    if (entries.isNotEmpty) {
      pages.add(_PageLayout(entries: entries, columnSpans: columnSpans));
    }
    entries = <_LayoutEntry>[];
    columnSpans = [false, false];
    occupied = [
      [false, false],
      [false, false],
    ];
  }

  int? findFreeColumn() {
    for (var col = 0; col < 2; col++) {
      if (!occupied[col][0] && !occupied[col][1]) {
        return col;
      }
    }
    return null;
  }

  List<int>? findFreeSlot() {
    for (var col = 0; col < 2; col++) {
      for (var row = 0; row < 2; row++) {
        if (!occupied[col][row]) {
          return [col, row];
        }
      }
    }
    return null;
  }

  for (final item in items) {
    final flowCount = item.flowCount ?? item.solvesCount;
    final isLarge = flowCount > _largeFlowThreshold;

    if (isLarge) {
      var column = findFreeColumn();
      if (column == null) {
        flush();
        column = findFreeColumn() ?? 0;
      }
      entries.add(
        _LayoutEntry(
          item,
          column: column,
          row: 0,
          rowSpan: 2,
        ),
      );
      columnSpans[column] = true;
      occupied[column][0] = true;
      occupied[column][1] = true;
      continue;
    }

    var slot = findFreeSlot();
    if (slot == null) {
      flush();
      slot = findFreeSlot() ?? [0, 0];
    }
    entries.add(
      _LayoutEntry(
        item,
        column: slot[0],
        row: slot[1],
        rowSpan: 1,
      ),
    );
    occupied[slot[0]][slot[1]] = true;
  }

  if (entries.isNotEmpty) {
    pages.add(_PageLayout(entries: entries, columnSpans: columnSpans));
  }

  return pages;
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

class _ZoomIcon extends StatelessWidget {
  const _ZoomIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 18,
      child: Icon(icon, size: 20, color: const Color(0xFF1B402B)),
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

class _Stroke {
  _Stroke({required this.color, required this.baseWidth, required this.order});

  final Color color;
  final double baseWidth;
  final int order;
  final List<_StrokePoint> points = <_StrokePoint>[];
  Rect? bounds;

  void addPoint(Offset position, double pressure) {
    points.add(_StrokePoint(position, pressure));
    final radius = baseWidth / 2;
    final pointRect = Rect.fromCircle(center: position, radius: radius);
    bounds = bounds == null ? pointRect : bounds!.expandToInclude(pointRect);
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
  const _StrokePoint(this.position, this.pressure);

  final Offset position;
  final double pressure;
}

class _StrokePainter extends CustomPainter {
  static const double _pressureMinFactor = 0.35;

  _StrokePainter({
    required this.strokes,
    required this.currentStroke,
    required this.eraserPosition,
    required this.eraserRadius,
    required this.logicalSize,
    required this.backgroundColor,
    Listenable? repaint,
  }) : super(repaint: repaint);

  final List<_Stroke> strokes;
  final _Stroke? currentStroke;
  final Offset? eraserPosition;
  final double eraserRadius;
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
    return oldDelegate.logicalSize != logicalSize ||
        oldDelegate.eraserPosition != eraserPosition ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
