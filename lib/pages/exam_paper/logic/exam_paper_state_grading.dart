part of 'package:s11/pages/exam_paper_page.dart';

mixin _ExamPaperGradingMixin on _ExamPaperStateBase, _ExamPaperInteractionMixin {
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
    if (relevant.isEmpty) {
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
    final titleBlocks = parseContentBlocks(item.questTitle);
    final problemText = contentBlocksToPlainText(titleBlocks);
    final payload = {
      'quest_id': item.questId,
      'quest_model': const <String>[],

      'problem': problemText,

      'problem_index': item.itemIndex,

      'problem_count': totalQuestions,

      'hash_tags': item.hashTags,

      'student_work_image': base64Encode(imageBytes),

      'recognized_text': const <dynamic>[],

      'writing_events': const <dynamic>[],
      'step_correctness': const <dynamic>[],
      'time_weakness': const <dynamic>[],
    };
    final response = await ApiClient.instance.submitSolveAnalysis(
      payload: payload,
    );
    final analysis = response.analysis.trim();
    final imageSize = Size(
      math.max(1, targetRegion.width.round()).toDouble(),
      math.max(1, targetRegion.height.round()).toDouble(),
    );
    final referenceSteps = _ReferenceSolveStep.fromQuest(
      quest == null ? null : quest['solves'],
    );
    final referenceCount = _flattenReferenceSteps(referenceSteps).length;
    final stepCorrectness = _resolveStepCorrectness(
      response: response,
      questSteps: referenceSteps,
      imageSize: imageSize,
    );
    final isCorrect = _resolveIsCorrect(
      response: response,
      stepCorrectness: stepCorrectness,
      referenceCount: referenceCount,
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
    required List<_ReferenceSolveStep> questSteps,
    required Size imageSize,
  }) {
    if (response.stepCorrectness.isNotEmpty) {
      return response.stepCorrectness;
    }
    final ocrBlocks =
        _parseOcrBlocksFromResponse(response.recognizedText, imageSize);
    if (ocrBlocks.isEmpty || questSteps.isEmpty) {
      return const [];
    }
    return _evaluateStepCorrectness(ocrBlocks, questSteps);
  }

  bool? _resolveIsCorrect({
    required SolveAnalysisResponse response,
    required List<Map<String, dynamic>> stepCorrectness,
    required int referenceCount,
  }) {
    if (response.isCorrect != null) {
      return response.isCorrect;
    }
    if (referenceCount <= 0 || stepCorrectness.isEmpty) {
      return null;
    }
    if (stepCorrectness.length < referenceCount) {
      return null;
    }
    for (var i = 0; i < referenceCount; i++) {
      final correct = stepCorrectness[i]['correct'];
      if (correct == null) {
        return null;
      }
      if (correct != true) {
        return false;
      }
    }
    return true;
  }

  List<_OcrBlock> _parseOcrBlocksFromResponse(
    List<dynamic> rawBlocks,
    Size imageSize,
  ) {
    if (rawBlocks.isEmpty) return <_OcrBlock>[];
    final blocks = <_OcrBlock>[];
    for (final entry in rawBlocks) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry as Map);
      final text = map['text']?.toString() ?? '';
      final rect = _parseOcrRect(map['bbox'], imageSize);
      if (rect == null) continue;
      blocks.add(_OcrBlock(text: text, bbox: rect));
    }
    return blocks;
  }

  Rect? _parseOcrRect(dynamic value, Size imageSize) {
    List<double>? coords;
    if (value is List && value.length >= 4) {
      coords = value.take(4).map(_toDouble).toList();
    } else if (value is Map) {
      final map = Map<String, dynamic>.from(value as Map);
      if (map.containsKey('x1') &&
          map.containsKey('y1') &&
          map.containsKey('x2') &&
          map.containsKey('y2')) {
        coords = [
          _toDouble(map['x1']),
          _toDouble(map['y1']),
          _toDouble(map['x2']),
          _toDouble(map['y2']),
        ];
      }
    }
    if (coords == null) return null;

    final maxValue = coords.reduce((a, b) => a > b ? a : b);
    final isNormalized = maxValue <= 1.5;
    var left = coords[0];
    var top = coords[1];
    var right = coords[2];
    var bottom = coords[3];

    if (isNormalized) {
      left *= imageSize.width;
      right *= imageSize.width;
      top *= imageSize.height;
      bottom *= imageSize.height;
    }

    final l = math.min(left, right).clamp(0.0, imageSize.width).toDouble();
    final r = math.max(left, right).clamp(0.0, imageSize.width).toDouble();
    final t = math.min(top, bottom).clamp(0.0, imageSize.height).toDouble();
    final b = math.max(top, bottom).clamp(0.0, imageSize.height).toDouble();
    if (r <= l || b <= t) return null;
    return Rect.fromLTRB(l, t, r, b);
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  List<Map<String, dynamic>> _evaluateStepCorrectness(
    List<_OcrBlock> blocks,
    List<_ReferenceSolveStep> referenceSteps,
  ) {
    if (blocks.isEmpty) return const [];
    final flattened = _flattenReferenceSteps(referenceSteps);
    if (flattened.isEmpty) return const [];
    final orderedBlocks = List<_OcrBlock>.from(blocks)
      ..sort((a, b) {
        final dy = a.bbox.top.compareTo(b.bbox.top);
        if (dy != 0) return dy;
        return a.bbox.left.compareTo(b.bbox.left);
      });
    final results = <Map<String, dynamic>>[];
    for (var i = 0; i < orderedBlocks.length; i++) {
      final block = orderedBlocks[i];
      final reference = i < flattened.length ? flattened[i] : null;
      if (reference == null) {
        results.add({
          'step_id': i + 1,
          'correct': null,
        });
        continue;
      }
      final similarity = _textSimilarity(block.text, reference.flowText);
      final isCorrect = similarity >= 0.6;
      results.add({
        'step_id': i + 1,
        'correct': isCorrect,
        'similarity': similarity,
      });
    }
    return results;
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

  double _textSimilarity(String a, String b) {
    final tokensA = _tokenize(a);
    final tokensB = _tokenize(b);
    if (tokensA.isEmpty && tokensB.isEmpty) return 1.0;
    if (tokensA.isEmpty || tokensB.isEmpty) return 0.0;
    final intersection = tokensA.intersection(tokensB).length;
    final union = tokensA.union(tokensB).length;
    return union == 0 ? 0.0 : intersection / union;
  }

  Set<String> _tokenize(String text) {
    final regex = RegExp(r'[A-Za-z0-9가-힣ㄱ-ㅎㅏ-ㅣ]+');
    final matches = regex.allMatches(text);
    return matches.map((m) => m.group(0)!.toLowerCase()).toSet();
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
