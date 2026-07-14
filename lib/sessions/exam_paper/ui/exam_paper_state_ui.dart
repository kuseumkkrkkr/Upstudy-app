part of 'package:s11/sessions/exam_paper/session/exam_paper_page.dart';

mixin _ExamPaperUiMixin
    on _ExamPaperStateBase, _ExamPaperInteractionMixin, _ExamPaperGradingMixin {
  void _handleOptionSelection(int itemIndex, int optionIndex) {
    setState(() {
      final current = _selectedOptions[itemIndex];
      if (current == optionIndex) {
        _selectedOptions.remove(itemIndex);
      } else {
        _selectedOptions[itemIndex] = optionIndex;
      }
    });
  }

  /// 보기 위젯이 실제로 렌더링된 화면 영역을 저장한다.
  /// 확대·이동된 시험지에서도 상단 입력 레이어가 같은 글로벌 좌표로 선택을 판별한다.
  void _updateOptionHitRegion(int itemIndex, int optionIndex, Rect region) {
    _optionHitRegions.putIfAbsent(itemIndex, () => <int, Rect>{})[optionIndex] =
        region;
  }

  /// 등록된 보기 영역 안을 클릭했으면 선택 상태를 바꾸고 캔버스 입력을 막는다.
  /// 이미 선택한 보기를 다시 누르면 선택을 해제한다.
  @override
  bool _selectOptionAt(Offset globalPosition) {
    for (final itemEntry in _optionHitRegions.entries) {
      for (final optionEntry in itemEntry.value.entries) {
        final key = _optionHitRegionKey(itemEntry.key, optionEntry.key);
        final renderObject = key.currentContext?.findRenderObject();
        final region = renderObject is RenderBox && renderObject.hasSize
            ? renderObject.localToGlobal(Offset.zero) & renderObject.size
            : optionEntry.value;
        if (!region.contains(globalPosition)) continue;
        _handleOptionSelection(itemEntry.key, optionEntry.key);
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 980;
        final showSidebar = _sidebarVisible && !isCompact;
        final sidebarWidth = showSidebar ? 200.0 : 0.0;
        final mainWidth = width - sidebarWidth;
        return Shortcuts(
          shortcuts: <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.arrowLeft):
                const _PreviousPageIntent(),
            LogicalKeySet(LogicalKeyboardKey.arrowUp):
                const _PreviousPageIntent(),
            LogicalKeySet(LogicalKeyboardKey.arrowRight):
                const _NextPageIntent(),
            LogicalKeySet(LogicalKeyboardKey.arrowDown):
                const _NextPageIntent(),
          },

          child: Actions(
            actions: <Type, Action<Intent>>{
              _PreviousPageIntent: CallbackAction<_PreviousPageIntent>(
                onInvoke: (_) {
                  _goToPreviousPage();
                  return null;
                },
              ),
              _NextPageIntent: CallbackAction<_NextPageIntent>(
                onInvoke: (_) {
                  _goToNextPage();
                  return null;
                },
              ),
            },

            child: Focus(
              autofocus: true,
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: Scaffold(
                  backgroundColor: const Color(0xFFF1F1F1),
                  body: SafeArea(
                    child: Row(
                      children: [
                        if (showSidebar)
                          SizedBox(width: sidebarWidth, child: _buildSidebar()),
                        Expanded(
                          child: _buildMainPanel(
                            maxWidth: mainWidth,
                            isCompact: isCompact,
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
      },
    );
  }

  /// 필요한 변수는 화면 폭·모바일 여부·시험 생성 상태다.
  /// 작동 원리는 종이 캔버스 위에 HTML형 상단 상태바·도구 레일·진행 오버레이를 계층별로 배치하는 것이다.
  Widget _buildMainPanel({required double maxWidth, required bool isCompact}) {
    final showGeneratingOverlay = _isGenerating;
    return Stack(
      key: _mainStackKey,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: _buildCanvasArea()),
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          height: 72,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F4),
              border: Border(
                bottom: BorderSide(color: Colors.black.withValues(alpha: 0.04)),
              ),
            ),
          ),
        ),
        if (_remainingSeconds != null)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formatRemaining(_remainingSeconds!),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        if (isCompact) _buildCompactThumbnailButton(),
        Positioned(
          left: 12,
          top: 80,
          child: _buildIconRail(isCompact: isCompact),
        ),
        if (_colorPickerOpen) _buildColorPickerOverlay(),
        if (_widthPickerOpen) _buildWidthPickerOverlay(),
        if (_thumbnailRenderIndex != null)
          Positioned(
            left: -_paperWidth - 40,
            top: -_paperHeight - 40,
            child: _buildThumbnailRenderSurface(),
          ),
        if (showGeneratingOverlay) _buildGeneratingOverlay(),
        if (_grading) _buildGradingOverlay(),
      ],
    );
  }

  String _formatRemaining(int seconds) {
    final clamped = seconds < 0 ? 0 : seconds;
    final m = (clamped ~/ 60).toString().padLeft(2, '0');
    final s = (clamped % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // header removed

  /// 필요한 변수는 현재 페이지와 전체 페이지 수다.
  /// 작동 원리는 HTML의 좌측 상단 페이지 배지를 누르면 기존 썸네일 바텀시트를 여는 것이다.
  Widget _buildCompactThumbnailButton() {
    return Positioned(
      top: 16,

      left: 16,

      child: Material(
        color: Colors.white.withValues(alpha: 0.92),

        elevation: 4,

        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _openThumbnailsSheet,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.description_outlined, size: 19),
                const SizedBox(width: 8),
                Text(
                  '${_currentPageIndex + 1} / $_pageCount',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF4F4F4),

        border: Border(right: BorderSide(color: Color(0x22000000))),
      ),

      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),

            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '페이지',

                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),

                Text(
                  '$_pageCount 페이지',

                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),

                IconButton(
                  icon: const Icon(Icons.chevron_left),

                  onPressed: () => setState(() => _sidebarVisible = false),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(child: _buildThumbnailList()),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: _buildPageControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailList({bool closeOnTap = false}) {
    final pageCount = _pageCount;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),

      itemCount: pageCount,

      itemBuilder: (context, index) =>
          _buildThumbnailItem(index, closeOnTap: closeOnTap),
    );
  }

  Widget _buildThumbnailItem(int index, {required bool closeOnTap}) {
    final isSelected = index == _currentPageIndex;

    final layout = _pageLayouts.isEmpty ? null : _pageLayouts[index];

    final statusMessage = layout == null && _isGenerating
        ? 'Generating...'
        : null;
    final bytes = _thumbnailBytes[index];
    if (bytes == null && layout != null) {
      _enqueueThumbnailRender(index);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),

      child: InkWell(
        onTap: () {
          _setCurrentPage(index);

          if (closeOnTap) {
            Navigator.of(context).maybePop();
          }
        },

        borderRadius: BorderRadius.circular(10),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),

              padding: const EdgeInsets.all(4),

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius: BorderRadius.circular(10),

                border: Border.all(
                  color: isSelected ? _kGreen : const Color(0xFFD0D0D0),

                  width: isSelected ? 2 : 1,
                ),

                boxShadow: const [
                  BoxShadow(
                    blurRadius: 6,

                    color: Color(0x14000000),

                    offset: Offset(0, 2),
                  ),
                ],
              ),

              child: AspectRatio(
                aspectRatio: _paperWidth / _paperHeight,

                child: bytes != null
                    ? Image.memory(
                        bytes,

                        fit: BoxFit.contain,

                        gaplessPlayback: true,
                      )
                    : _buildThumbnailPlaceholder(message: statusMessage),
              ),
            ),
            const SizedBox(height: 6),

            Text(
              '${index + 1} / $_pageCount',

              textAlign: TextAlign.center,

              style: TextStyle(
                fontSize: 12,

                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,

                color: isSelected ? _kGreen : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _enqueueThumbnailRender(int index) {
    if (_thumbnailBytes.containsKey(index)) return;
    if (_thumbnailQueue.contains(index)) return;
    // allow rerender only when page content changes; otherwise reuse cached
    if (index < 0 || index >= _pageCount) return;
    _thumbnailQueue.add(index);
    if (_thumbnailProcessScheduled) return;
    _thumbnailProcessScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _thumbnailProcessScheduled = false;
      if (!mounted) return;
      _processThumbnailQueue();
    });
  }

  Widget _buildThumbnailPlaceholder({String? message}) {
    return Container(
      color: const Color(0xFFF7F7F7),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_outlined, color: Colors.black26, size: 28),
          const SizedBox(height: 6),
          Text(
            message ?? 'Loading preview...',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  void _processThumbnailQueue() {
    if (_thumbnailRenderBusy || _thumbnailQueue.isEmpty || !mounted) return;
    if (_pageSwitching) return;

    _thumbnailRenderBusy = true;

    final index = _thumbnailQueue.first;

    _thumbnailQueue.remove(index);

    _thumbnailRenderIndex = index;

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final boundary =
          _thumbnailBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) {
        _thumbnailRenderBusy = false;

        _thumbnailRenderIndex = null;

        if (mounted) {
          _processThumbnailQueue();
        }

        return;
      }

      try {
        final image = await boundary.toImage(
          pixelRatio: _thumbnailPixelRatio(),
        );

        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

        if (!mounted) return;

        if (bytes != null) {
          setState(() {
            _thumbnailBytes[index] = bytes.buffer.asUint8List();
          });
        }
      } finally {
        _thumbnailRenderBusy = false;

        _thumbnailRenderIndex = null;

        if (mounted) {
          _processThumbnailQueue();
        }
      }
    });
  }

  Widget _buildThumbnailRenderSurface() {
    final index = _thumbnailRenderIndex;

    if (index == null) return const SizedBox.shrink();

    if (_pageLayouts.isEmpty || index >= _pageLayouts.length) {
      return const SizedBox.shrink();
    }

    final layout = _pageLayouts[index];

    return RepaintBoundary(
      key: _thumbnailBoundaryKey,

      child: SizedBox(
        width: _paperWidth,

        height: _paperHeight,

        child: _buildPaperSheet(
          child: _ExamPaperContent(
            layout: layout,

            pageNumber: index + 1,

            totalPages: _pageCount,
            selectedOptions: _selectedOptions,
            onOptionSelected: _handleOptionSelection,
            optionHitRegionKeyFor: _optionHitRegionKey,
            onOptionHitRegionChanged: _updateOptionHitRegion,
            lowDetail: _fastScrollActive,
          ),
        ),
      ),
    );
  }

  Widget _buildPageControls() {
    final totalPages = _pageCount;
    final canPrev = _currentPageIndex > 0;
    final canNext = _currentPageIndex < totalPages - 1;

    return Material(
      color: Colors.white,

      elevation: 0,

      borderRadius: BorderRadius.circular(12),

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),

        child: Row(
          mainAxisSize: MainAxisSize.min,

          children: [
            IconButton(
              iconSize: 20,

              visualDensity: VisualDensity.compact,

              icon: const Icon(Icons.chevron_left),

              onPressed: canPrev ? _goToPreviousPage : null,
            ),

            Text(
              '${_currentPageIndex + 1} / $totalPages',

              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),

            IconButton(
              iconSize: 20,

              visualDensity: VisualDensity.compact,

              icon: const Icon(Icons.chevron_right),

              onPressed: canNext ? _goToNextPage : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratingOverlay() {
    final total = _totalQuestionCount;

    final completed = _completedQuestionCount;

    final progress = total > 0 ? completed / total : null;

    return Positioned.fill(
      child: Stack(
        children: [
          ModalBarrier(
            color: Colors.white.withValues(alpha: 0.9),

            dismissible: false,
          ),

          Center(
            child: Container(
              width: 360,

              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius: BorderRadius.circular(16),

                boxShadow: const [
                  BoxShadow(
                    blurRadius: 12,

                    color: Color(0x22000000),

                    offset: Offset(0, 4),
                  ),
                ],
              ),

              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  const Text(
                    '시험지 생성 중',

                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),

                  const SizedBox(height: 12),

                  LinearProgressIndicator(
                    value: progress,

                    backgroundColor: const Color(0xFFE0E0E0),

                    valueColor: const AlwaysStoppedAnimation<Color>(_kGreen),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    total > 0 ? '$completed / $total 문항' : '문항 수 계산 중...',

                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradingOverlay() {
    final total = _gradingTotal;

    final completed = _gradingCompleted;

    final progress = total > 0 ? completed / total : null;

    final previewBytes = _gradingPreviewBytes;
    final previewRegion = _gradingPreviewRegion;
    final previewAspect = previewRegion != null && previewRegion.height > 0
        ? (previewRegion.width / previewRegion.height)
              .clamp(0.3, 3.0)
              .toDouble()
        : 1.0;
    final previewLabelParts = <String>[];
    if (_gradingPreviewPageIndex != null) {
      previewLabelParts.add('Page ${_gradingPreviewPageIndex! + 1}');
    }
    if (_gradingPreviewItemIndex != null) {
      previewLabelParts.add('Item ${_gradingPreviewItemIndex!}');
    }
    if (previewRegion != null) {
      previewLabelParts.add(
        'Region ${previewRegion.width.round()}x${previewRegion.height.round()}',
      );
    }
    final previewLabel = previewLabelParts.join(' | ');

    return Positioned.fill(
      child: Stack(
        children: [
          ModalBarrier(
            color: Colors.white.withValues(alpha: 0.6),

            dismissible: false,
          ),

          Center(
            child: Container(
              width: 360,

              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius: BorderRadius.circular(16),

                boxShadow: const [
                  BoxShadow(
                    blurRadius: 12,

                    color: Color(0x22000000),

                    offset: Offset(0, 4),
                  ),
                ],
              ),

              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  const Text(
                    '채점 진행 중',

                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),

                  const SizedBox(height: 12),

                  LinearProgressIndicator(
                    value: progress,

                    backgroundColor: const Color(0xFFE0E0E0),

                    valueColor: const AlwaysStoppedAnimation<Color>(_kGreen),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    total > 0 ? '$completed / $total 문항' : '문항 수 계산 중...',

                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),

                  const SizedBox(height: 12),

                  if (previewBytes != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x22000000)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Preview',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AspectRatio(
                            aspectRatio: previewAspect,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                previewBytes,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              ),
                            ),
                          ),
                          if (previewLabel.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              previewLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  TextButton(
                    onPressed: _gradingCancelled
                        ? null
                        : () => setState(() => _gradingCancelled = true),

                    child: Text(
                      _gradingCancelled ? '취소됨' : '채점 취소',

                      style: const TextStyle(color: _kGreen),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openThumbnailsSheet() async {
    await showModalBottomSheet<void>(
      context: context,

      backgroundColor: Colors.white,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),

      builder: (context) {
        final height = MediaQuery.of(context).size.height;

        return SafeArea(
          child: SizedBox(
            height: height * 0.65,

            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),

                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '페이지 미리보기',

                          style: TextStyle(
                            fontSize: 16,

                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      IconButton(
                        icon: const Icon(Icons.close),

                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                Expanded(child: _buildThumbnailList(closeOnTap: true)),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: _buildPageControls(),
                ),
              ],
            ),
          ),
        );
      },
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
        }
        final viewportWidth = viewportSize.width;
        final viewportHeight = viewportSize.height;

        double nextBaseScale;
        if (isPortrait) {
          final fitScale = math.min(
            viewportWidth / _paperWidth,
            viewportHeight / _paperHeight,
          );
          nextBaseScale = fitScale * 0.94;
        } else {
          nextBaseScale = viewportWidth <= 0
              ? 1.0
              : viewportWidth / _paperWidth;
        }

        if (_currentBaseScale != nextBaseScale) {
          _currentBaseScale = nextBaseScale;
          _updateViewMatrix();
        }

        _scheduleCenterIfNeeded(viewportSize);
        final visiblePages = _visiblePagesForViewport(viewportSize);

        return ClipRect(
          child: Stack(
            children: [
              ValueListenableBuilder<Matrix4>(
                valueListenable: _viewMatrix,
                builder: (context, matrix, child) {
                  return Transform(
                    transform: matrix,
                    alignment: Alignment.topLeft,
                    child: child,
                  );
                },
                child: OverflowBox(
                  minWidth: _paperWidth,
                  maxWidth: _paperWidth,
                  minHeight: _logicalHeight,
                  maxHeight: _logicalHeight,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: _paperWidth,
                    height: _logicalHeight,
                    child: Stack(
                      children: [
                        _buildPaperLayer(visiblePages),
                        ..._buildStrokeLayers(visiblePages),
                        ..._buildGradingLayers(),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _handleScaleStart,
                  onScaleUpdate: _handleScaleUpdate,
                  onScaleEnd: _handleScaleEnd,
                  onDoubleTap: _resetViewToCenter,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _handlePointerDown,
                    onPointerMove: _handlePointerMove,
                    onPointerUp: _handlePointerUp,
                    onPointerCancel: _handlePointerCancel,
                    onPointerHover: _handlePointerHover,
                    onPointerSignal: _handlePointerSignal,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Set<int> _visiblePagesForViewport(Size viewport) {
    final pageCount = _pageCount;
    if (pageCount == 0) return const {0};
    if (viewport.isEmpty) {
      return {_currentPageIndex.clamp(0, pageCount - 1)};
    }
    final scale = _currentScale <= 0 ? 1.0 : _currentScale;
    final top = (-_panOffset.dy) / scale - _pageGap;
    final bottom = (viewport.height - _panOffset.dy) / scale + _pageGap;
    var start = (top / _pageSpanHeight).floor();
    var end = (bottom / _pageSpanHeight).ceil();
    start = start.clamp(0, pageCount - 1);
    end = end.clamp(0, pageCount - 1);

    // 현재를 중심으로 이전/현재/다음 우선 노출
    final current = _currentPageIndex.clamp(0, pageCount - 1);
    final pages = <int>{
      for (var i = start; i <= end; i++) i,
      current,
      if (current - 1 >= 0) current - 1,
      if (current + 1 < pageCount) current + 1,
    };
    final sorted = pages.toList()
      ..sort((a, b) => (a - current).abs().compareTo((b - current).abs()));
    return sorted.take(3).toSet();
  }

  void _resetViewToCenter() {
    _setZoom(1);
    _centerCurrentPage();
    _updateViewMatrix();
  }

  bool _colorPickerOpen = false;
  bool _widthPickerOpen = false;
  final GlobalKey _mainStackKey = GlobalKey();
  final GlobalKey _penButtonKey = GlobalKey();
  final GlobalKey _paletteButtonKey = GlobalKey();

  void _toggleColorPicker() {
    setState(() {
      _colorPickerOpen = !_colorPickerOpen;
      if (_colorPickerOpen) _widthPickerOpen = false;
    });
  }

  void _toggleWidthPicker() {
    setState(() {
      _widthPickerOpen = !_widthPickerOpen;
      if (_widthPickerOpen) _colorPickerOpen = false;
    });
  }

  @override
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

  Widget _buildPaperLayer(Set<int> visiblePages) {
    final layouts = _pageLayouts;
    final totalPages = _pageCount;
    final hasExamId = widget.examId != null && widget.examId!.trim().isNotEmpty;
    final status = _examStatus;
    final isFailed = status != null && status.status == 'failed';
    final isGenerating =
        _loadingExam ||
        (status != null &&
            status.status != 'done' &&
            status.status != 'failed');
    final statusMessage = isGenerating
        ? '시험지 생성 중입니다...'
        : isFailed
        ? '시험지 생성에 실패했습니다.'
        : _examError ?? (hasExamId ? '시험지를 불러올 수 없습니다.' : null);

    return SizedBox(
      width: _paperWidth,
      height: _logicalHeight,
      child: Stack(
        children: [
          for (final index in visiblePages)
            Positioned(
              left: 0,
              top: _pageOffsetY(index),
              child: _buildPaperSheet(
                child: _ExamPaperContent(
                  layout: index < layouts.length ? layouts[index] : null,
                  pageNumber: index + 1,
                  totalPages: totalPages,
                  statusMessage: (index == 0 && index >= layouts.length)
                      ? statusMessage
                      : null,
                  selectedOptions: _selectedOptions,
                  onOptionSelected: _handleOptionSelection,
                  optionHitRegionKeyFor: _optionHitRegionKey,
                  onOptionHitRegionChanged: _updateOptionHitRegion,
                  lowDetail: _fastScrollActive,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildStrokeLayers(Set<int> visiblePages) {
    _ensurePageBuffers(_pageCount);
    return visiblePages.map((index) {
      final strokes = _pageStrokes.length > index
          ? _pageStrokes[index]
          : const <_Stroke>[];
      final currentStroke = _currentStrokePageIndex == index
          ? _currentStroke
          : null;
      final eraserPosition = _eraserActive && _eraserPageIndex == index
          ? _eraserPosition
          : _toolMode == _ToolMode.eraser && _eraserCursorPageIndex == index
          ? _eraserCursorPosition
          : null;
      return Positioned(
        left: 0,
        top: _pageOffsetY(index),
        child: CustomPaint(
          painter: _StrokePainter(
            strokes: strokes,
            currentStroke: currentStroke,
            eraserPosition: eraserPosition,
            eraserRadius: _eraserRadius,
            logicalSize: const Size(_paperWidth, _paperHeight),
            backgroundColor: Colors.transparent,
            repaint: _paintVersion,
          ),
          size: const Size(_paperWidth, _paperHeight),
        ),
      );
    }).toList();
  }

  List<Widget> _buildGradingLayers() {
    if (!_grading) return const [];
    final regions = _currentQuestionRegions();
    if (regions.isEmpty) return const [];
    final activeItemIndex = _gradingPreviewPageIndex == _currentPageIndex
        ? _gradingPreviewItemIndex
        : null;
    return [
      Positioned(
        left: 0,
        top: _pageOffsetY(_currentPageIndex),
        child: CustomPaint(
          painter: _GradingGridPainter(
            regions: regions,
            activeItemIndex: activeItemIndex,
          ),
          size: const Size(_paperWidth, _paperHeight),
        ),
      ),
    ];
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

  /// 필요한 변수는 현재 필기 도구·완료 가능 상태·모바일 여부다.
  /// 작동 원리는 모든 시험 조작을 하나의 흰색 세로 캡슐 안에 유지하고 선택 도구만 검게 강조하는 것이다.
  Widget _buildIconRail({required bool isCompact}) {
    final active = Colors.black;
    final inactive = const Color(0xFF6B6B6B);
    final canFinish =
        !_examFinished && !_isGenerating && _pageLayouts.isNotEmpty;
    void selectTool(_ToolMode mode) {
      setState(() {
        if (_toolMode == mode && mode == _ToolMode.pen) {
          _toggleWidthPicker();
          return;
        }
        _toolMode = mode;
        if (mode != _ToolMode.eraser) {
          _eraserCursorPosition = null;
          _eraserCursorPageIndex = null;
        }
        _scrollEnabled = mode == _ToolMode.pan;
        if (mode != _ToolMode.pan) {
          _colorPickerOpen = false;
        }
        if (mode != _ToolMode.pen) {
          _widthPickerOpen = false;
        }
      });
    }

    Widget railButton(
      IconData icon, {
      required String tooltip,
      required VoidCallback? onTap,
      bool selected = false,
      Key? key,
    }) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: selected ? active : Colors.transparent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              key: key,
              size: 20,
              color: selected ? Colors.white : inactive,
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      elevation: 3,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            railButton(
              Icons.view_sidebar_outlined,
              tooltip: '페이지 목록',
              onTap: () => setState(() => _sidebarVisible = !_sidebarVisible),
              selected: _sidebarVisible,
            ),
            railButton(
              Icons.edit_outlined,
              tooltip: '펜',
              onTap: () => selectTool(_ToolMode.pen),
              selected: _toolMode == _ToolMode.pen,
              key: _penButtonKey,
            ),
            railButton(
              Icons.cleaning_services_outlined,
              tooltip: '지우개',
              onTap: () => selectTool(_ToolMode.eraser),
              selected: _toolMode == _ToolMode.eraser,
            ),
            railButton(
              Icons.pan_tool_alt,
              tooltip: '이동',
              onTap: () => selectTool(_ToolMode.pan),
              selected: _toolMode == _ToolMode.pan,
            ),
            railButton(
              Icons.color_lens_outlined,
              tooltip: '팔레트',
              onTap: _toggleColorPicker,
              key: _paletteButtonKey,
            ),
            railButton(
              Icons.undo_outlined,
              tooltip: '실행 취소',
              onTap: _undoStack.isEmpty ? null : _undo,
              selected: false,
            ),
            railButton(
              _examFinished ? Icons.flag : Icons.flag_outlined,
              tooltip: '시험 종료',
              onTap: canFinish ? _confirmFinishExam : null,
              selected: false,
            ),
            railButton(
              Icons.exit_to_app,
              tooltip: '나가기',
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPickerOverlay() {
    final rect = _buttonRect(_paletteButtonKey);
    if (rect == null) return const SizedBox.shrink();
    const gap = 6.0;
    return Positioned(
      left: rect.right + gap,
      top: rect.top,
      child: _MiniChooser(
        height: rect.height,
        children: _penColors
            .map(
              (c) => _MiniChoice(
                onTap: () {
                  setState(() {
                    _penColor = c;
                    _toolMode = _ToolMode.pen;
                    _colorPickerOpen = false;
                  });
                },
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black12),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildWidthPickerOverlay() {
    final rect = _buttonRect(_penButtonKey);
    if (rect == null) return const SizedBox.shrink();
    const gap = 6.0;
    return Positioned(
      left: rect.right + gap,
      top: rect.top,
      child: _MiniChooser(
        height: rect.height,
        children: _penWidths
            .map(
              (w) => _MiniChoice(
                onTap: () {
                  setState(() {
                    _penWidth = w;
                    _toolMode = _ToolMode.pen;
                    _widthPickerOpen = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Container(
                    width: w * 4,
                    height: w * 4,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Rect? _buttonRect(GlobalKey key) {
    final stackBox =
        _mainStackKey.currentContext?.findRenderObject() as RenderBox?;
    final btnBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || btnBox == null || !btnBox.attached) return null;
    final topLeft = btnBox.localToGlobal(Offset.zero, ancestor: stackBox);
    final size = btnBox.size;
    return topLeft & size;
  }
}
