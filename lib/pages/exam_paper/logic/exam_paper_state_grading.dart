part of 'package:s11/pages/exam_paper_page.dart';

mixin _ExamPaperGradingMixin on _ExamPaperStateBase, _ExamPaperInteractionMixin {
  // Gemini prompt/model is handled on the server.
  static const HeatmapConfig _heatmapConfig = HeatmapConfig();
  int _resolveExamQuestionCount() {
    final expected = widget.expectedQuestionCount;
    if (expected != null && expected > 0) return expected;
    final status = _examStatus;
    if (status != null && status.items.isNotEmpty) {
      return status.items.length;
    }
    return 0;
  }

  int _resolveExamDifficultyTier() {
    final status = _examStatus;
    if (status == null || status.items.isEmpty) return 3;
    var sum = 0;
    for (final item in status.items) {
      sum += item.difficultyTier;
    }
    final average = (sum / status.items.length).round();
    return average.clamp(1, 5);
  }

  String _resolveExamNumber() {
    final examId = widget.examId?.trim();
    if (examId != null && examId.isNotEmpty) return examId;
    return 'local-${DateTime.now().millisecondsSinceEpoch}';
  }

  void _showMessage(String message) {

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(content: Text(message)),

    );

  }



  Future<void> _confirmFinishExam() async {

    if (_examFinished) return;

    final confirmed = await showDialog<bool>(

      context: context,

      builder: (context) {

        return AlertDialog(

          title: const Text('시험 종료'),

          content: const Text(

            '시험을 종료하면\n더 이상 답안을 수정할 수 없습니다.',

          ),

          actions: [

            TextButton(

              onPressed: () => Navigator.of(context).pop(false),

              child: const Text('ì·¨ì'),

            ),

            ElevatedButton(

              onPressed: () => Navigator.of(context).pop(true),

              style: ElevatedButton.styleFrom(

                backgroundColor: const Color(0xFF1B402B),

                foregroundColor: Colors.white,

              ),

              child: const Text('종료'),

            ),

          ],

        );

      },

    );

    if (confirmed == true && mounted) {
      setState(() => _examFinished = true);
      _showMessage('시험이 종료되었습니다.');
      final examNumber = _resolveExamNumber();
      unawaited(
        ActivityStore.recordExamCompletion(
          examId: examNumber,
          examNumber: examNumber,
          questionCount: _resolveExamQuestionCount(),
          difficultyTier: _resolveExamDifficultyTier(),
        ).catchError((_) {}),
      );
      await _startBatchGrading();

    }
  }


  Future<void> _startBatchGrading() async {

    if (_grading) return;

    if (!_examFinished) {

      _showMessage('시험을 먼저 종료해 주세요.');

      return;

    }

    final status = _examStatus;

    if (status == null || status.status != 'done') {

      _showMessage('시험지 생성이 완료된 후에 채점할 수 있습니다.');

      return;

    }

    if (_pageLayouts.isEmpty) {

      _showMessage('채점할 문제가 없습니다.');

      return;

    }

    if (_toolMode == _ToolMode.pen && _currentStroke != null) {

      _finishStroke();

    } else if (_toolMode == _ToolMode.eraser && _eraserActive) {

      _finishEraser();

    }

    final totalQuestions = _pageLayouts.fold<int>(

      0,

      (sum, page) => sum + page.entries.length,

    );

    if (totalQuestions == 0) {

      _showMessage('채점할 문제가 없습니다.');

      return;

    }

    setState(() {

      _grading = true;

      _gradingCancelled = false;

      _gradingCompleted = 0;

      _gradingTotal = totalQuestions;

      _gradeResults.clear();
      _gradingPreviewBytes = null;
      _gradingPreviewRegion = null;
      _gradingPreviewPageIndex = null;
      _gradingPreviewItemIndex = null;

    });



    for (var pageIndex = 0; pageIndex < _pageLayouts.length; pageIndex++) {

      if (!mounted || _gradingCancelled) break;

      final layout = _pageLayouts[pageIndex];

      final regions = _questionRegionsForPage(
        layout,
        isFirstPage: pageIndex == 0,
      );
      for (final region in regions) {

        if (!mounted || _gradingCancelled) break;

        try {

          final strokes = _pageStrokes.length > pageIndex

              ? _pageStrokes[pageIndex]

              : const <_Stroke>[];

          final result = await _gradeQuestion(

            item: region.item,
            pageIndex: pageIndex,

            region: region.rect,

            strokes: strokes,

            totalQuestions: totalQuestions,

          );

          if (!mounted) return;

          setState(() {

            _gradeResults[region.item.itemIndex] = result;

            _gradingCompleted += 1;

          });

        } catch (error) {
          if (!mounted) return;
          final quest = await _loadQuest(region.item.questId);
          if (!mounted) return;
          setState(() {
            _gradeResults[region.item.itemIndex] = _GradeResult.failure(
              region.item.itemIndex,
              error.toString(),
              quest: quest,
            );
            _gradingCompleted += 1;
          });
        }
      }

    }



    if (!mounted) return;

    final wasCancelled = _gradingCancelled;

    setState(() {
      _grading = false;
      _gradingPreviewBytes = null;
      _gradingPreviewRegion = null;
      _gradingPreviewPageIndex = null;
      _gradingPreviewItemIndex = null;
    });

    if (wasCancelled) {

      _showMessage('채점이 취소되었습니다.');

      return;

    }

    unawaited(_submitExamRatings());
    _openGradingReport();

  }



  Future<_GradeResult> _gradeQuestion({
    required ExamItem item,
    required int pageIndex,
    required Rect region,
    required List<_Stroke> strokes,
    required int totalQuestions,
  }) async {
    final quest = await _loadQuest(item.questId);
    final targetRegion = region;
    final relevant = _extractStrokesInRegion(strokes, targetRegion);
    if (relevant.length <= 2) {
      return _GradeResult.empty(item.itemIndex, quest: quest);
    }
    final imageBytes =
        await _renderStrokesToPngForRegion(relevant, targetRegion);
    if (mounted) {
      setState(() {
        _gradingPreviewBytes = imageBytes;
        _gradingPreviewRegion = targetRegion;
        _gradingPreviewPageIndex = pageIndex;
        _gradingPreviewItemIndex = item.itemIndex;
      });
    }
    final heatmapPayload = _buildHeatmapForRegion(
      pageIndex: pageIndex,
      region: targetRegion,
    );
    final heatmapImage = await heatmapPayload.result.renderImage();
    debugPrint(
      '[exam grading] images: student=${imageBytes.lengthInBytes}B '
      'heatmap=${heatmapImage.lengthInBytes}B',
    );
    final titleBlocks = parseContentBlocks(item.questTitle);
    final problemText = contentBlocksToPlainText(titleBlocks);
    final referenceSteps = _ReferenceSolveStep.fromQuest(
      quest == null ? null : quest['solves'],
    );
    final referencePayload = _buildReferenceStepsPayload(referenceSteps);
    final payload = {
      'quest_id': item.questId,
      'quest_model': const <String>[],

      if (quest != null) 'quest_json': quest,
      'problem': problemText,

      'problem_index': item.itemIndex,

      'problem_count': totalQuestions,

      'hash_tags': item.hashTags,
      'reference_steps': referencePayload,
      'reference_flow_count': referencePayload.length,
      'recognized_text': const <dynamic>[],
      'writing_events': const <dynamic>[],
      'step_correctness': const <dynamic>[],
      'time_weakness': const <dynamic>[],
    };
    final response = await ApiClient.instance.submitSolveAnalysis(
      payload: payload,
      studentWorkImage: imageBytes,
      heatmapImage: heatmapImage,
    );
    final analysis = '';
    final stepCorrectness = _resolveStepCorrectness(
      response: response,
    );
    final isCorrect = _resolveIsCorrect(
      response: response,
    );
    return _GradeResult.success(
      item.itemIndex,
      analysis: analysis,
      warnings: response.warnings,
      isCorrect: isCorrect,
      stepCorrectness: stepCorrectness,
      quest: quest,
    );
  }


  Future<Uint8List> _renderStrokesToPngForRegion(
    List<_Stroke> strokes,
    Rect region,
  ) async {
    final width = math.max(1, region.width.round());

    final height = math.max(1, region.height.round());

    final recorder = ui.PictureRecorder();

    final canvas = Canvas(recorder);

    final size = Size(width.toDouble(), height.toDouble());

    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    canvas.save();

    canvas.clipRect(Offset.zero & size);

    canvas.translate(-region.left, -region.top);

    _StrokePainter.drawStrokes(canvas, strokes);

    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes?.buffer.asUint8List() ?? Uint8List(0);
  }

  Future<Map<String, dynamic>?> _loadQuest(String? questId) async {
    if (questId == null || questId.trim().isEmpty) {
      return null;
    }
    final cached = _questCache[questId];
    if (cached != null) {
      return cached;
    }
    try {
      final quests = await ApiClient.instance.searchQuests(
        questId: questId,
        pageSize: 1,
      );
      if (quests.isEmpty) {
        return null;
      }
      final quest = quests.first;
      _questCache[questId] = quest;
      return quest;
    } catch (_) {
      return null;
    }
  }

  List<_Stroke> _extractStrokesInRegion(
    List<_Stroke> strokes,
    Rect region,
  ) {
    final filtered = <_Stroke>[];
    for (final stroke in strokes) {
      final bounds = stroke.bounds;
      if (bounds == null || !bounds.overlaps(region)) {
        continue;
      }
      _Stroke? current;
      for (final point in stroke.points) {
        if (region.contains(point.position)) {
          current ??= _Stroke(
            color: stroke.color,
            baseWidth: stroke.baseWidth,
            order: stroke.order,
          );
          current.addPoint(point.position, point.pressure);
        } else if (current != null) {
          filtered.add(current);
          current = null;
        }
      }
      if (current != null) {
        filtered.add(current);
      }
    }
    return filtered;
  }

  List<Map<String, dynamic>> _resolveStepCorrectness({
    required SolveAnalysisResponse response,
  }) {
    if (response.stepCorrectness.isNotEmpty) {
      return response.stepCorrectness;
    }
    return const [];
  }

  bool? _resolveIsCorrect({
    required SolveAnalysisResponse response,
  }) {
    return response.isCorrect;
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

  _HeatmapPayload _buildHeatmapForRegion({
    required int pageIndex,
    required Rect region,
  }) {
    final events = _heatmapEventsByPage[pageIndex] ?? const <HeatmapEvent>[];
    if (events.isEmpty) {
      return _HeatmapPayload(
        result: HeatmapEngine.build(
          size: Size(region.width, region.height),
          events: const <HeatmapEvent>[],
          config: _heatmapConfig,
        ),
        highlightBounds: const [],
      );
    }
    final filtered = <HeatmapEvent>[];
    final strokeBounds = <String, Rect>{};
    for (final event in events) {
      switch (event.type) {
        case HeatmapEventType.undo:
          filtered.add(event);
          break;
        case HeatmapEventType.penStroke:
          final stroke = event.stroke;
          if (stroke == null) break;
          final points = _filterPointsToRegion(stroke.points, region);
          if (points.isEmpty) break;
          final bounds = _boundsForPoints(points);
          if (bounds != null) {
            strokeBounds[stroke.key] = bounds;
          }
          filtered.add(
            HeatmapEvent.pen(
              HeatmapStroke(
                key: stroke.key,
                points: points,
                order: event.order,
              ),
            ),
          );
          break;
        case HeatmapEventType.eraserStroke:
          final eraser = event.eraser;
          if (eraser == null) break;
          final points = _filterPointsToRegion(eraser.points, region);
          if (points.isEmpty) break;
          filtered.add(
            HeatmapEvent.eraser(
              HeatmapEraserStroke(
                points: points,
                order: event.order,
              ),
            ),
          );
          break;
      }
    }
    final result = HeatmapEngine.build(
      size: Size(region.width, region.height),
      events: filtered,
      config: _heatmapConfig,
    );
    final highlightBounds = <Map<String, dynamic>>[];
    result.highlightReasons.forEach((key, reasons) {
      final bounds = strokeBounds[key];
      if (bounds == null) return;
      highlightBounds.add({
        'stroke_key': key,
        'bounds': _rectToList(bounds),
        'reasons': reasons.toList(),
      });
    });
    return _HeatmapPayload(
      result: result,
      highlightBounds: highlightBounds,
    );
  }

  List<Offset> _filterPointsToRegion(List<Offset> points, Rect region) {
    if (points.isEmpty) return const [];
    final filtered = <Offset>[];
    for (final point in points) {
      if (!region.contains(point)) continue;
      filtered.add(Offset(point.dx - region.left, point.dy - region.top));
    }
    return filtered;
  }

  Rect? _boundsForPoints(List<Offset> points) {
    if (points.isEmpty) return null;
    var minX = points.first.dx;
    var maxX = points.first.dx;
    var minY = points.first.dy;
    var maxY = points.first.dy;
    for (final point in points.skip(1)) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }
    if (maxX <= minX || maxY <= minY) return null;
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  List<double> _rectToList(Rect rect) {
    return <double>[rect.left, rect.top, rect.right, rect.bottom];
  }

  List<_QuestionRegion> _currentQuestionRegions() {
    if (_pageLayouts.isEmpty) return const [];
    final pageIndex = _currentPageIndex
        .clamp(0, _pageLayouts.length - 1)
        .toInt();
    final layout = _pageLayouts[pageIndex];
    return _questionRegionsForPage(
      layout,
      isFirstPage: pageIndex == 0,
    );
  }

  List<_QuestionRegion> _questionRegionsForPage(
    _PageLayout layout, {
    required bool isFirstPage,
  }) {
    _ensureHeaderFooterMetrics();
    final headerHeight =
        isFirstPage ? (_estimatedHeaderHeight ?? 0) : _secondaryHeaderHeight;
    final footerHeight = _estimatedFooterHeight ?? 0;

    const headerGap = 18.0;

    const footerGap = 16.0;

    const padding = EdgeInsets.fromLTRB(56, 56, 56, 38);

    final contentWidth = _paperWidth - padding.left - padding.right;

    final contentHeight = _paperHeight -

        padding.top -

        padding.bottom -

        headerHeight -

        footerHeight -

        headerGap -

        footerGap;

    if (contentHeight <= 0 || contentWidth <= 0) {

      return const [];

    }

    final contentTop = padding.top + headerHeight + headerGap;

    final contentLeft = padding.left;

    final columnWidth = contentWidth / 2;

    final rowHeight = contentHeight / 2;

    return layout.entries

        .map(

          (entry) => _QuestionRegion(

            item: entry.item,

            rect: Rect.fromLTWH(

              contentLeft + entry.column * columnWidth,

              contentTop + entry.row * rowHeight,

              columnWidth,

              rowHeight * entry.rowSpan,

            ),

          ),

        )

        .toList();

  }



  void _ensureHeaderFooterMetrics() {

    if (_estimatedHeaderHeight != null && _estimatedFooterHeight != null) {

      return;

    }

    final textScaler = MediaQuery.textScalerOf(context);

    const baseStyle = TextStyle(

      fontSize: 13.5,

      height: 1.5,

      fontFamily: 'Batang',

    );

    final pillStyle = baseStyle.copyWith(

      fontSize: 22,

      fontWeight: FontWeight.bold,

    );

    final titleStyle = baseStyle.copyWith(fontSize: 21);

    final headerTitleStyle = baseStyle.copyWith(

      fontSize: 41,

      fontWeight: FontWeight.bold,

      letterSpacing: 14,

    );

    final pillTextHeight = _measureTextHeight(

      '제 2 교시',

      pillStyle,

      textScaler,

    );

    final boxTextHeight = _measureTextHeight(

      '가형',

      pillStyle,

      textScaler,

    );

    final titleHeight = _measureTextHeight(

      '2025학년도 대학수학능력시험 문제지',

      titleStyle,

      textScaler,

    );

    final rowHeight = math.max(

      pillTextHeight + 10,

      math.max(boxTextHeight + 12, titleHeight),

    );

    final subjectHeight = _measureTextHeight(

      '수학 영역',

      headerTitleStyle,

      textScaler,

    );

    _estimatedHeaderHeight = rowHeight + 10 + subjectHeight + 12;

    final footerTextHeight =

        _measureTextHeight('1', baseStyle, textScaler);

    _estimatedFooterHeight = footerTextHeight + 4;

  }



  double _measureTextHeight(

    String text,

    TextStyle style,

    TextScaler textScaler,

  ) {

    final painter = TextPainter(

      text: TextSpan(text: text, style: style),

      textDirection: TextDirection.ltr,

      textScaler: textScaler,

    )..layout();

    return painter.height;

  }





  void _openGradingReport() {

    if (_gradeResults.isEmpty) return;

    final results = _gradeResults.values.toList()

      ..sort((a, b) => a.itemIndex.compareTo(b.itemIndex));

    Navigator.of(context).push(

      MaterialPageRoute(

        builder: (_) => _ExamGradingReportPage(

          results: results,

          totalQuestions: _gradingTotal,

          examId: widget.examId,

        ),

      ),

    );

  }

  Future<void> _submitExamRatings() async {
    if (_gradeResults.isEmpty) return;
    final futures = <Future<void>>[];
    for (final result in _gradeResults.values) {
      if (result.quest == null) continue;
      if (result.isCorrect == null) continue;
      final quest = result.quest!;
      final header = quest['header'] as Map<String, dynamic>? ?? {};
      final info = quest['info'] as Map<String, dynamic>? ?? {};
      final questId = header['quest_id']?.toString() ?? '';
      if (questId.isEmpty) continue;
      final tags = (info['hash_tag'] as List<dynamic>? ?? [])
          .map((tag) => tag.toString())
          .toList();
      futures.add(
        ApiClient.instance
            .submitRating(
              questId: questId,
              isCorrect: result.isCorrect ?? false,
              tags: tags,
              stepCorrectness: result.stepCorrectness,
            )
            .then(RatingStore.updateFromRating)
            .catchError((_) {}),
      );
    }
    if (futures.isEmpty) return;
    try {
      await Future.wait(futures);
    } catch (_) {}
  }



}

class _HeatmapPayload {
  const _HeatmapPayload({
    required this.result,
    required this.highlightBounds,
  });

  final HeatmapResult result;
  final List<Map<String, dynamic>> highlightBounds;

  Map<String, dynamic> toMetaJson() {
    final meta = result.toMetaJson();
    if (highlightBounds.isNotEmpty) {
      meta['highlight_bounds'] = highlightBounds;
    }
    return meta;
  }
}
