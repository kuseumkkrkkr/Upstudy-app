part of 'package:s11/pages/exam_paper_page.dart';

mixin _ExamPaperUiMixin on
    _ExamPaperStateBase,
    _ExamPaperInteractionMixin,
    _ExamPaperGradingMixin {
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
            LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _PreviousPageIntent(),
            LogicalKeySet(LogicalKeyboardKey.arrowUp): const _PreviousPageIntent(),
            LogicalKeySet(LogicalKeyboardKey.arrowRight): const _NextPageIntent(),
            LogicalKeySet(LogicalKeyboardKey.arrowDown): const _NextPageIntent(),
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

                  backgroundColor: Colors.white,

                  body: SafeArea(

                    child: Row(

                      children: [

                        if (showSidebar)

                          SizedBox(

                            width: sidebarWidth,

                            child: _buildSidebar(),

                          ),

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



  Widget _buildMainPanel({

    required double maxWidth,

    required bool isCompact,

  }) {

    final headerHeight = 72 * _uiScale(context);

    const toolbarHeight = 70.0;

    final showGeneratingOverlay = _isGenerating;

    return Stack(

      clipBehavior: Clip.none,

      children: [

        Positioned.fill(child: _buildCanvasArea()),

        _buildZoomControls(),
        if (isCompact) _buildCompactThumbnailButton(),

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

        AnimatedPositioned(

          duration: const Duration(milliseconds: 220),

          curve: Curves.easeOut,

          left: 0,

          right: 0,

          bottom: _toolbarVisible ? 0 : -toolbarHeight,

          child: Align(

            alignment: Alignment.bottomCenter,

            child: _buildToolbar(maxWidth),

          ),

        ),

        Positioned(

          left: 0,

          right: 0,

          bottom: _toolbarVisible ? toolbarHeight - 12 : 8,

          child: _buildToolbarPullHandle(),

        ),

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



  Widget _buildHeader() {
    final scale = _uiScale(context);
    final sidebarActive = !_isCompactLayout && _sidebarVisible;
    return Container(
      height: 72 * scale,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0x22000000))),
      ),
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

                iconSize: 26 * scale,

                icon: Icon(

                  sidebarActive

                      ? Icons.view_sidebar

                      : Icons.view_sidebar_outlined,

                  color: _kGreen,

                ),

                onPressed: _handleSidebarToggle,

              ),

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

            color: Colors.white.withValues(alpha: 0.9),

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



  bool get _isCompactLayout =>

      MediaQuery.of(context).size.width < 980;



  void _handleSidebarToggle() {

    if (_isCompactLayout) {

      _openThumbnailsSheet();

      return;

    }

    setState(() => _sidebarVisible = !_sidebarVisible);

  }



  Widget _buildCompactThumbnailButton() {

    return Positioned(

      top: 16,

      left: 16,

      child: Material(

        color: Colors.white.withValues(alpha: 0.92),

        elevation: 4,

        borderRadius: BorderRadius.circular(12),

        child: IconButton(

          icon: const Icon(Icons.view_sidebar, color: _kGreen),

          onPressed: _openThumbnailsSheet,

        ),

      ),

    );

  }



  Widget _buildSidebar() {

    return Container(

      decoration: const BoxDecoration(

        color: Color(0xFFF4F4F4),

        border: Border(

          right: BorderSide(color: Color(0x22000000)),

        ),

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

                    style: TextStyle(

                      fontSize: 16,

                      fontWeight: FontWeight.w700,

                    ),

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

    final statusMessage =
        layout == null && _isGenerating ? 'Generating...' : null;
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
    if (_thumbnailAttempted.contains(index)) return;
    if (_thumbnailQueue.contains(index)) return;
    if (index < 0 || index >= _pageCount) return;
    _thumbnailAttempted.add(index);
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
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black45,
            ),
          ),
        ],
      ),
    );
  }


  void _processThumbnailQueue() {

    if (_thumbnailRenderBusy || _thumbnailQueue.isEmpty || !mounted) return;

    _thumbnailRenderBusy = true;

    final index = _thumbnailQueue.first;

    _thumbnailQueue.remove(index);

    _thumbnailRenderIndex = index;

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) async {

      if (!mounted) return;

      final boundary = _thumbnailBoundaryKey.currentContext

          ?.findRenderObject() as RenderRepaintBoundary?;

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

        final bytes =

            await image.toByteData(format: ui.ImageByteFormat.png);

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

              style: const TextStyle(

                fontSize: 12,

                fontWeight: FontWeight.w600,

              ),

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



  void _setToolbarVisible(bool value) {

    if (_toolbarVisible == value) return;

    setState(() => _toolbarVisible = value);

  }



  void _handleToolbarDragUpdate(DragUpdateDetails details) {

    _toolbarDragDistance += details.delta.dy;

  }



  void _handleToolbarDragEnd(DragEndDetails details) {

    final velocity = details.primaryVelocity ?? 0;

    if (velocity < -200 || _toolbarDragDistance < -24) {

      _setToolbarVisible(true);

    } else if (velocity > 200 || _toolbarDragDistance > 24) {

      _setToolbarVisible(false);

    }

    _toolbarDragDistance = 0;

  }



  Widget _buildToolbarPullHandle() {

    final scale = _uiScale(context);

    return Center(

      child: GestureDetector(

        behavior: HitTestBehavior.opaque,

        onTap: () => _setToolbarVisible(!_toolbarVisible),

        onVerticalDragUpdate: _handleToolbarDragUpdate,

        onVerticalDragEnd: _handleToolbarDragEnd,

        child: Container(

          padding: EdgeInsets.symmetric(

            horizontal: 12 * scale,

            vertical: 4 * scale,

          ),

          decoration: BoxDecoration(

            color: Colors.white.withValues(alpha: 0.6),

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

            _toolbarVisible

                ? Icons.keyboard_arrow_down_rounded

                : Icons.keyboard_arrow_up_rounded,

            size: 24 * scale,

            color: _kGreen,

          ),

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

                    style: TextStyle(

                      fontSize: 18,

                      fontWeight: FontWeight.w700,

                    ),

                  ),

                  const SizedBox(height: 12),

                  LinearProgressIndicator(

                    value: progress,

                    backgroundColor: const Color(0xFFE0E0E0),

                    valueColor:

                        const AlwaysStoppedAnimation<Color>(_kGreen),

                  ),

                  const SizedBox(height: 8),

                  Text(

                    total > 0

                        ? '$completed / $total 문항'

                        : '문항 수 계산 중...',

                    style:

                        const TextStyle(fontSize: 12, color: Colors.black54),

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
        ? (previewRegion.width / previewRegion.height).clamp(0.3, 3.0).toDouble()
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

                    style: TextStyle(

                      fontSize: 18,

                      fontWeight: FontWeight.w700,

                    ),

                  ),

                  const SizedBox(height: 12),

                  LinearProgressIndicator(

                    value: progress,

                    backgroundColor: const Color(0xFFE0E0E0),

                    valueColor:

                        const AlwaysStoppedAnimation<Color>(_kGreen),

                  ),

                  const SizedBox(height: 8),

                  Text(

                    total > 0

                        ? '$completed / $total 문항'

                        : '문항 수 계산 중...',

                    style:

                        const TextStyle(fontSize: 12, color: Colors.black54),

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
          nextBaseScale = viewportWidth <= 0 ? 1.0 : viewportWidth / _paperWidth;
        }

        if (_currentBaseScale != nextBaseScale) {
          _currentBaseScale = nextBaseScale;
          _updateViewMatrix();
        }

        _scheduleCenterIfNeeded(viewportSize);

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
                child: SizedBox(
                  width: _paperWidth,
                  height: _logicalHeight,
                  child: Stack(
                    children: [
                      _buildPaperLayer(),
                      ..._buildStrokeLayers(),
                      ..._buildGradingLayers(),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _handleScaleStart,
                  onScaleUpdate: _handleScaleUpdate,
                  onScaleEnd: _handleScaleEnd,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _handlePointerDown,
                    onPointerMove: _handlePointerMove,
                    onPointerUp: _handlePointerUp,
                    onPointerCancel: _handlePointerCancel,
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


  Widget _buildZoomControls() {

    return Positioned(

      top: 16,

      right: 16,

      child: Material(

        color: Colors.white.withValues(alpha: 0.92),

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
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Icon(Icons.refresh, size: 16),
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
    final totalPages = _pageCount;
    final hasExamId =
        widget.examId != null && widget.examId!.trim().isNotEmpty;
    final status = _examStatus;
    final isFailed = status != null && status.status == 'failed';
    final isGenerating = _loadingExam ||
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(totalPages, (index) {
          final layout =
              index < layouts.length ? layouts[index] : null;
          final effectiveStatusMessage =
              layout == null && index == 0 ? statusMessage : null;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == totalPages - 1 ? 0 : _pageGap,
            ),
            child: _buildPaperSheet(
              child: _ExamPaperContent(
                layout: layout,
                pageNumber: index + 1,
                totalPages: totalPages,
                statusMessage: effectiveStatusMessage,
              ),
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _buildStrokeLayers() {
    _ensurePageBuffers(_pageCount);
    return List<Widget>.generate(_pageCount, (index) {
      final strokes = _pageStrokes.length > index
          ? _pageStrokes[index]
          : const <_Stroke>[];
      final currentStroke =
          _currentStrokePageIndex == index ? _currentStroke : null;
      final eraserPosition = _eraserActive && _eraserPageIndex == index
          ? _eraserPosition
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
    });
  }

  List<Widget> _buildGradingLayers() {
    if (!_grading) return const [];
    final regions = _currentQuestionRegions();
    if (regions.isEmpty) return const [];
    final activeItemIndex =
        _gradingPreviewPageIndex == _currentPageIndex
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



  Widget _buildToolbar(double maxWidth) {

    final activeColor = const Color(0xFF1B402B);

    final inactiveColor = const Color(0xFF6B6B6B);
    final toolbarWidth = math.min(800.0, math.max(320.0, maxWidth - 24));
    final canFinish =
        !_examFinished && !_isGenerating && _pageLayouts.isNotEmpty;
    return Container(

      width: toolbarWidth,

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

        padding: const EdgeInsets.symmetric(horizontal: 12),

        child: SingleChildScrollView(

          scrollDirection: Axis.horizontal,

          child: Row(

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

              const SizedBox(width: 16),

              _ToolbarIcon(

                icon: Icons.cleaning_services_outlined,

                size: 40,

                color: _toolMode == _ToolMode.eraser

                    ? activeColor

                    : inactiveColor,

                onTap: () => _setToolMode(_ToolMode.eraser),

              ),

              const SizedBox(width: 16),

              _ToolbarIcon(

                icon: Icons.color_lens_outlined,

                size: 48,

                color: _penColor,

                onTap: _openPenSettings,

              ),

              const SizedBox(width: 16),

              const SizedBox(

                height: 100,

                child: VerticalDivider(

                  thickness: 2,

                  color: Color(0xFFE0E3E7),

                ),

              ),

              const SizedBox(width: 16),

              _ToolbarIcon(

                icon: Icons.undo_outlined,

                size: 40,

                color: _undoStack.isEmpty ? inactiveColor : activeColor,

                onTap: _undoStack.isEmpty ? null : _undo,

              ),

              const SizedBox(width: 16),

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

              const SizedBox(width: 16),

              const SizedBox(

                height: 100,

                child: VerticalDivider(

                  thickness: 2,

                  color: Color(0xFFE0E3E7),

                ),

              ),

              const SizedBox(width: 16),

              _ToolbarIcon(

                icon: Icons.auto_fix_high,

                size: 40,

                color: _scrollEnabled ? activeColor : inactiveColor,

                onTap: _toggleScroll,

              ),

              const SizedBox(width: 16),

              const SizedBox(

                height: 100,

                child: VerticalDivider(

                  thickness: 2,

                  color: Color(0xFFE0E3E7),

                ),

              ),

              const SizedBox(width: 16),

              _ToolbarIcon(
                icon: _examFinished ? Icons.flag : Icons.flag_outlined,
                size: 38,
                color: canFinish ? activeColor : inactiveColor,
                onTap: canFinish ? _confirmFinishExam : null,
              ),
            ],
          ),
        ),
      ),
    );

  }
}
