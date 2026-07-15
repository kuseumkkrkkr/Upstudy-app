part of 'package:s11/sessions/exam_paper/session/exam_paper_page.dart';

mixin _ExamPaperInteractionMixin on _ExamPaperStateBase {
  /// 필요한 변수는 서버 페이지 수와 선택적 페이지 수 힌트다.
  /// 작동 원리는 서버 결과가 없을 때도 미리보기·로컬 시험지의 연속 페이지 캔버스를 같은 방식으로 구성하는 것이다.
  int get _pageCount =>
      math.max(1, math.max(_pageLayouts.length, widget.pageCountHint));

  List<_Stroke> get _strokes => _pageStrokes[_currentPageIndex];

  List<_UndoAction> get _undoStack => _pageUndoStacks[_currentPageIndex];

  List<_Stroke> get _pendingEraseRemoved =>
      _pagePendingEraseRemoved[_currentPageIndex];

  double get _contentHeight => _pageCount == 0
      ? _paperHeight
      : _paperHeight * _pageCount + _pageGap * (_pageCount - 1);

  double get _pageSpanHeight => _paperHeight + _pageGap;

  double _pageOffsetY(int index) => index * _pageSpanHeight;

  double get _logicalHeight => _contentHeight;

  double get _currentScale => _currentBaseScale * _zoomScale;
  bool get _fastScrollActive =>
      _lastFastScrollAt != null &&
      DateTime.now().difference(_lastFastScrollAt!).inMilliseconds < 160;

  void _updateViewMatrix() {
    final scale = _currentScale;
    _viewMatrix.value = Matrix4.identity()
      ..translateByDouble(_panOffset.dx, _panOffset.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _clampPanOffset({bool bounce = false}) {
    final viewport = _viewportSize;
    if (viewport == null) return;
    final scale = _currentScale <= 0 ? 1.0 : _currentScale;
    final contentHeight = _logicalHeight * scale;
    final contentWidth = _paperWidth * scale;
    final rawMinY = viewport.height - contentHeight - _scrollEdgePadding;
    final rawMaxY = _scrollEdgePadding;
    final rawMinX = viewport.width - contentWidth - _scrollEdgePadding;
    final rawMaxX = _scrollEdgePadding;
    final minY = math.min(rawMinY, rawMaxY);
    final maxY = math.max(rawMinY, rawMaxY);
    final minX = math.min(rawMinX, rawMaxX);
    final maxX = math.max(rawMinX, rawMaxX);
    final allowHorizontal = contentWidth > viewport.width + 1.0;
    final centerX = (viewport.width - contentWidth) / 2;
    final nextX = allowHorizontal ? _panOffset.dx.clamp(minX, maxX) : centerX;
    final nextY = _panOffset.dy.clamp(minY, maxY);
    if (bounce && (nextX != _panOffset.dx || nextY != _panOffset.dy)) {
      _panOffset = Offset(
        ui.lerpDouble(_panOffset.dx, nextX, 0.35)!,
        ui.lerpDouble(_panOffset.dy, nextY, 0.35)!,
      );
    } else {
      _panOffset = Offset(nextX, nextY);
    }
  }

  void _centerInViewport([Size? viewport]) {
    final effectiveViewport = viewport ?? _viewportSize;
    if (effectiveViewport == null) return;
    final scale = _currentScale;
    final contentSize = Size(_paperWidth * scale, _logicalHeight * scale);
    final centerX = (effectiveViewport.width - contentSize.width) / 2;
    final double nextY;
    if (contentSize.height > effectiveViewport.height + 0.5) {
      final minY =
          effectiveViewport.height - contentSize.height - _scrollEdgePadding;
      final maxY = _scrollEdgePadding;
      nextY = _panOffset.dy.clamp(minY, maxY);
    } else {
      nextY = (effectiveViewport.height - contentSize.height) / 2;
    }
    final nextOffset = Offset(centerX, nextY);
    if ((nextOffset - _panOffset).distance < 0.01) return;
    _panOffset = nextOffset;
  }

  double _thumbnailPixelRatio() {
    final ratio = _thumbnailTargetWidth / _paperWidth;

    return ratio.clamp(0.12, 0.35);
  }

  bool get _isGenerating {
    final status = _examStatus;

    return _loadingExam ||
        (status != null &&
            status.status != 'done' &&
            status.status != 'failed');
  }

  int get _totalQuestionCount {
    final items = _examStatus?.items ?? const <ExamItem>[];

    if (items.isNotEmpty) {
      return items.length;
    }

    return widget.expectedQuestionCount ?? 0;
  }

  int get _completedQuestionCount {
    final items = _examStatus?.items ?? const <ExamItem>[];

    if (items.isEmpty) return 0;

    var completed = 0;

    for (final item in items) {
      if (item.status == 'done' ||
          item.status == 'reused' ||
          item.status == 'failed') {
        completed += 1;
      }
    }

    return completed;
  }

  void _ensurePageBuffers(int count) {
    while (_pageStrokes.length < count) {
      _pageStrokes.add(<_Stroke>[]);

      _pageUndoStacks.add(<_UndoAction>[]);

      _pagePendingEraseRemoved.add(<_Stroke>[]);
    }

    if (_currentPageIndex >= count) {
      _currentPageIndex = math.max(0, count - 1);
    }
  }

  void _setCurrentPage(int index) {
    _ensurePageBuffers(_pageCount);
    final clamped = index.clamp(0, _pageCount - 1).toInt();
    if (_currentPageIndex == clamped) return;
    if (_currentStroke != null) {
      _finishStroke();
    }

    if (_eraserActive) {
      _finishEraser();
    }
    setState(() {
      _currentPageIndex = clamped;
    });
    _pageSwitching = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusCurrentPage();
      _pageSwitching = false;
    });
  }

  void _setCurrentPageIndex(int index) {
    _ensurePageBuffers(_pageCount);
    final clamped = index.clamp(0, _pageCount - 1).toInt();
    if (_currentPageIndex == clamped) return;
    setState(() => _currentPageIndex = clamped);
  }

  void _centerCurrentPage() {
    final viewport = _viewportSize;
    if (viewport == null) return;
    final scale = _currentScale <= 0 ? 1.0 : _currentScale;
    final contentWidth = _paperWidth * scale;
    final dx = (viewport.width - contentWidth) / 2;
    final pageTop = _pageOffsetY(_currentPageIndex) * scale;
    final dy = _isPortrait
        ? 72 - pageTop
        : (viewport.height - _paperHeight * scale) / 2 - pageTop;
    _panOffset = Offset(dx, dy);
  }

  void _syncCurrentPageToViewport() {
    final viewport = _viewportSize;
    if (viewport == null) return;
    final scale = _currentScale;
    if (scale <= 0) return;
    final centerY = (viewport.height / 2 - _panOffset.dy) / scale;
    final index = _pageIndexForGlobalY(centerY);
    _setCurrentPageIndex(index);
  }

  void _goToNextPage() => _setCurrentPage(_currentPageIndex + 1);

  void _goToPreviousPage() => _setCurrentPage(_currentPageIndex - 1);

  void _bumpPaint() {
    _paintVersion.value = _paintVersion.value + 1;
  }

  void _setZoom(double value) {
    final next = value.clamp(_zoomMin, _zoomMax);
    if (next == _zoomScale) return;
    _zoomScale = next;
    _zoomScaleNotifier.value = next;
    _centerInViewport();
    _updateViewMatrix();
  }

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
    final nextZoom = (_gestureStartZoom * details.scale).clamp(
      _zoomMin,
      _zoomMax,
    );
    _zoomScale = nextZoom;
    _zoomScaleNotifier.value = nextZoom;

    // Allow two-finger panning while pinching.
    _panOffset += details.focalPointDelta;
    _lastFastScrollAt = DateTime.now();
    _clampPanOffset(bounce: true);
    _updateViewMatrix();
    _syncCurrentPageToViewport();
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _gestureActive = false;
    if (_zoomScale < _zoomMin) {
      final snapUp = (_zoomMin + 0.05).clamp(_zoomMin, _zoomMin + 0.15);
      _setZoom(snapUp);
      _centerInViewport();
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        _setZoom(_zoomMin);
        _centerInViewport();
      });
    } else {
      _clampPanOffset(bounce: true);
      _updateViewMatrix();
    }
  }

  void _scheduleCenterIfNeeded(Size viewport) {
    if (!_hasCentered) {
      _focusCurrentPage();
    } else {
      _centerInViewport(viewport);
      _updateViewMatrix();
    }
  }

  /// 필요한 변수는 현재 viewport·기준 배율·페이지 위치다.
  /// 작동 원리는 종이를 모바일 가로 폭에 맞춘 1배 기준으로 초기화한 뒤 현재 페이지를 상단에 배치하는 것이다.
  void _focusCurrentPage() {
    if (_viewportSize == null) return;
    _setZoom(1);
    _centerCurrentPage();
    _updateViewMatrix();
    _hasCentered = true;
  }

  Future<void> _fetchExamStatus() async {
    final examId = widget.examId;

    if (examId == null || examId.trim().isEmpty) {
      return;
    }

    try {
      final status = await ApiClient.instance.getExamStatus(
        examId,
        courseId: widget.courseId,
      );

      if (!mounted) {
        return;
      }

      final shouldResetThumbs = status.status == 'done';

      setState(() {
        _examStatus = status;

        _loadingExam = false;

        _examError = null;

        if (status.status == 'done' && status.items.isNotEmpty) {
          _pageLayouts = _layoutItems(status.items);
          _thumbnailBytes.clear();
          _thumbnailQueue.clear();
        } else {
          _pageLayouts = const [];
        }

        _hasCentered = false;

        _ensurePageBuffers(_pageCount);

        if (shouldResetThumbs) {
          _thumbnailBytes.clear();
          _thumbnailQueue.clear();
          _thumbnailAttempted.clear();
          _thumbnailRenderIndex = null;
          _thumbnailRenderBusy = false;
          _gradeResults.clear();
          _examFinished = false;
        }
      });

      if (status.status == 'done' || status.status == 'failed') {
        _pollTimer?.cancel();
      }
      if (status.status == 'done' && status.items.isNotEmpty) {
        unawaited(_indexExamForArchiveSearch(status));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _examError = '시험지 불러오기에 실패했습니다.';

        _loadingExam = false;

        _pageLayouts = const [];

        _hasCentered = false;
      });
    }
  }

  Future<void> _indexExamForArchiveSearch(ExamStatus status) async {
    final index = _examStatusSearchText(status);
    if (index.trim().isEmpty) return;
    await ExamPaperStore.updateSearchIndex(
      examId: status.examId,
      searchIndex: index,
    );
  }

  String _examStatusSearchText(ExamStatus status) {
    final buffer = StringBuffer(status.examId);
    for (final item in status.items) {
      buffer
        ..write(' ')
        ..write(item.title ?? '')
        ..write(' ')
        ..write(item.subjectKey ?? '')
        ..write(' ')
        ..write(item.questionType ?? '')
        ..write(' ')
        ..write(item.questId ?? '')
        ..write(' ')
        ..write(item.hashTags?.join(' ') ?? '')
        ..write(' ')
        ..write(_plainSearchText(item.questTitle))
        ..write(' ')
        ..write(_plainSearchText(item.questOptions));
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _plainSearchText(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Iterable) {
      return value
          .map(_plainSearchText)
          .where((text) => text.isNotEmpty)
          .join(' ');
    }
    if (value is Map) {
      return value.values
          .map(_plainSearchText)
          .where((text) => text.isNotEmpty)
          .join(' ');
    }
    return value.toString();
  }

  // ignore: unused_element
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

                        child: const Text('ì·¨ì'),
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

                        child: const Text('확인'),
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

    _heatmapEventsForPage(
      _currentPageIndex,
    ).add(HeatmapEvent.undo((_heatmapEventCounter++).toDouble()));
    _bumpPaint();
  }

  bool _isPanPointer(PointerEvent event) {
    // In pan mode, any pointer is used for navigation.
    // In stroke mode, single pointers are reserved for writing; panning happens only via pinch/zoom gestures.
    return _scrollEnabled;
  }

  int _pageIndexForGlobalY(double y) {
    if (_pageSpanHeight <= 0) return 0;
    return (y / _pageSpanHeight).floor().clamp(0, _pageCount - 1);
  }

  Offset _toPageLocal(Offset globalPosition, int pageIndex) {
    return globalPosition.translate(0, -_pageOffsetY(pageIndex));
  }

  bool _withinPage(Offset position) {
    return position.dx >= 0 &&
        position.dy >= 0 &&
        position.dx <= _paperWidth &&
        position.dy <= _paperHeight;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (!_scrollEnabled) return;
    if (event is PointerScrollEvent) {
      _handleScrollDelta(event.scrollDelta.dy);
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_gestureActive || _activePointer != null) return;

    if (_selectOptionAt(event.position)) return;

    if (_isPanPointer(event)) {
      _activePointer = event.pointer;
      return;
    }

    final globalPosition = _toLogicalPosition(event.localPosition);

    if (!_withinCanvas(globalPosition)) return;

    final pageIndex = _pageIndexForGlobalY(globalPosition.dy);
    final localPosition = _toPageLocal(globalPosition, pageIndex);
    if (!_withinPage(localPosition)) return;

    _setCurrentPageIndex(pageIndex);
    _activePointer = event.pointer;

    if (_toolMode == _ToolMode.pen) {
      _currentStrokePageIndex = pageIndex;
      _startStroke(localPosition, _normalizePressure(event));
    } else {
      _eraserPageIndex = pageIndex;
      _startEraser(localPosition);
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_gestureActive || _activePointer != event.pointer) return;

    if (_isPanPointer(event)) {
      // Free panning with a single pointer when pan mode is active.
      _panOffset += event.delta;
      _lastFastScrollAt = DateTime.now();
      _clampPanOffset(bounce: true);
      _updateViewMatrix();
      _syncCurrentPageToViewport();
      return;
    }

    final globalPosition = _toLogicalPosition(event.localPosition);

    if (!_withinCanvas(globalPosition)) return;

    if (_toolMode == _ToolMode.pen) {
      final pageIndex = _currentStrokePageIndex ?? _currentPageIndex;
      final localPosition = _toPageLocal(globalPosition, pageIndex);
      if (!_withinPage(localPosition)) return;
      _appendStroke(localPosition, _normalizePressure(event));
    } else {
      final pageIndex = _eraserPageIndex ?? _currentPageIndex;
      final localPosition = _toPageLocal(globalPosition, pageIndex);
      if (!_withinPage(localPosition)) return;
      _updateEraser(localPosition);
    }
  }

  /// 지우개 모드에서 호버 좌표를 논리 페이지 좌표로 변환한다.
  /// 클릭 전에도 지우개 원형 커서를 보여 펜과 동일하게 포인터를 따라가게 한다.
  void _handlePointerHover(PointerHoverEvent event) {
    if (_toolMode != _ToolMode.eraser || _gestureActive) return;
    final globalPosition = _toLogicalPosition(event.localPosition);
    if (!_withinCanvas(globalPosition)) {
      if (_eraserCursorPosition != null) {
        _eraserCursorPosition = null;
        _eraserCursorPageIndex = null;
        _bumpPaint();
      }
      return;
    }
    final pageIndex = _pageIndexForGlobalY(globalPosition.dy);
    final localPosition = _toPageLocal(globalPosition, pageIndex);
    if (!_withinPage(localPosition)) return;
    _eraserCursorPageIndex = pageIndex;
    _eraserCursorPosition = localPosition;
    _bumpPaint();
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;

    if (_isPanPointer(event)) {
      _activePointer = null;
      return;
    }

    if (_toolMode == _ToolMode.pen) {
      _finishStroke();
    } else {
      _finishEraser();
    }

    _activePointer = null;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;

    if (_isPanPointer(event)) {
      _activePointer = null;
      return;
    }

    if (_toolMode == _ToolMode.pen) {
      _finishStroke();
    } else {
      _finishEraser();
    }

    _activePointer = null;
  }

  void _handleScrollDelta(double delta, {bool allowWhenDisabled = false}) {
    if ((!_scrollEnabled && !allowWhenDisabled) || delta == 0) return;
    final viewport = _viewportSize;
    if (viewport == null) return;

    final contentHeight = _logicalHeight * _currentScale;
    final viewportHeight = viewport.height;
    final minY = viewportHeight - contentHeight - _scrollEdgePadding;
    final maxY = _scrollEdgePadding;
    final nextY =
        (_panOffset.dy - delta).clamp(
              math.min(minY, maxY),
              math.max(minY, maxY),
            )
            as double;
    _panOffset = Offset(_panOffset.dx, nextY);
    _lastFastScrollAt = DateTime.now();
    _updateViewMatrix();
    _syncCurrentPageToViewport();
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

      final pageIndex = _currentStrokePageIndex ?? _currentPageIndex;
      _heatmapEventsForPage(pageIndex).add(
        HeatmapEvent.pen(
          HeatmapStroke(
            key: 'p${pageIndex}_${stroke.order}',
            points: stroke.points.map((point) => point.position).toList(),
            order: (_heatmapEventCounter++).toDouble(),
          ),
        ),
      );
    }

    _currentStroke = null;
    _currentStrokePageIndex = null;

    _lastFilteredPoint = null;

    _bumpPaint();
  }

  void _startEraser(Offset position) {
    _pendingEraseRemoved.clear();

    _eraserActive = true;

    _eraserPosition = position;
    _eraserCursorPosition = position;
    _eraserCursorPageIndex = _eraserPageIndex;
    _currentEraserPoints = <Offset>[position];

    _eraseAt(position);

    _bumpPaint();
  }

  void _updateEraser(Offset position) {
    _eraserActive = true;

    _eraserPosition = position;
    _eraserCursorPosition = position;
    _eraserCursorPageIndex = _eraserPageIndex;
    _currentEraserPoints?.add(position);

    _eraseAt(position);

    _bumpPaint();
  }

  void _finishEraser() {
    final lastPosition = _eraserPosition;
    if (lastPosition != null) {
      _currentEraserPoints?.add(lastPosition);
    }
    if (_pendingEraseRemoved.isNotEmpty) {
      _undoStack.add(_RemoveAction(List<_Stroke>.from(_pendingEraseRemoved)));

      _pendingEraseRemoved.clear();
    }

    _eraserActive = false;

    _eraserPosition = null;

    final points = _currentEraserPoints;
    if (points != null && points.isNotEmpty) {
      final pageIndex = _eraserPageIndex ?? _currentPageIndex;
      _heatmapEventsForPage(pageIndex).add(
        HeatmapEvent.eraser(
          HeatmapEraserStroke(
            points: List<Offset>.from(points),
            order: (_heatmapEventCounter++).toDouble(),
          ),
        ),
      );
    }
    _currentEraserPoints = null;
    _eraserPageIndex = null;

    _bumpPaint();
  }

  /// 객관식 보기의 글로벌 렌더 영역을 등록한다.
  /// 입력 레이어가 시험지보다 위에 배치된 구조에서도 보기 클릭을 정확히 전달한다.
  GlobalKey _optionHitRegionKey(int itemIndex, int optionIndex) {
    final key = '${itemIndex}_$optionIndex';
    return _optionHitRegionKeys.putIfAbsent(key, GlobalKey.new);
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
}
