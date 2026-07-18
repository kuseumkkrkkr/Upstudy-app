import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:s11/shared/business/repositories/bookmark_store.dart';
import 'package:s11/shared/data/models/content_block.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/components/content_blocks_view.dart';
import 'package:s11/sessions/course/session/course_textbook_annotation_canvas.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_example_catalog.dart';
import 'package:s11/sessions/graph_tools/ui/widgets/jsx_graph_embed.dart';

class TeacherCourseTextbookReaderPage extends StatefulWidget {
  const TeacherCourseTextbookReaderPage({
    super.key,
    required this.courseId,
    required this.moduleId,
    required this.textbookId,
    required this.pageFrom,
    required this.pageTo,
    required this.minMinutes,
    this.enforceMinMinutes = false,
    this.previewBook,
    this.previewElapsedSeconds = 0,
  });

  final String courseId;
  final String moduleId;
  final String textbookId;
  final int pageFrom;
  final int pageTo;
  final int minMinutes;
  final bool enforceMinMinutes;
  final BookData? previewBook;
  final int previewElapsedSeconds;

  @override
  State<TeacherCourseTextbookReaderPage> createState() =>
      _TeacherCourseTextbookReaderPageState();
}

class _TeacherCourseTextbookReaderPageState
    extends State<TeacherCourseTextbookReaderPage> {
  static const _green = Colors.black;
  static const _paper = Color(0xFFFFFEF9);
  static const _ink = Color(0xFF151515);

  final _pageController = PageController();
  Timer? _heartbeatTimer;

  BookData? _book;
  List<_ReaderPage> _pages = const [];
  bool _loading = true;
  bool _scrollMode = false;
  bool _tocCollapsed = false;
  double _textScale = 1;
  String? _error;
  int _currentPage = 1;
  int _elapsedSeconds = 0;
  int _serverElapsedSeconds = 0;
  double? _serverCompletion;
  DateTime? _startedAt;
  bool _runtimeCompleted = false;
  bool _allowPop = false;
  bool _bookmarkBusy = false;
  List<BookmarkItem> _bookmarks = const <BookmarkItem>[];

  int get _pageFrom => max(1, widget.pageFrom);

  int get _pageTo => max(_pageFrom, widget.pageTo);

  int get _minSeconds => max(0, widget.minMinutes) * 60;

  double get _pageProgress {
    if (_pages.isEmpty) return 0;
    final range = max(1, _pageTo - _pageFrom + 1);
    final read = (_currentPage - _pageFrom + 1).clamp(0, range);
    return read / range;
  }

  double get _timeProgress {
    if (_minSeconds <= 0) return 1;
    return ((_elapsedSeconds + _serverElapsedSeconds) / _minSeconds).clamp(
      0,
      1,
    );
  }

  double get _completion => max(
    _serverCompletion ?? 0,
    min(_pageProgress, _timeProgress),
  ).clamp(0, 1);

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _currentPage = _pageFrom;
    final previewBook = widget.previewBook;
    if (previewBook == null) {
      _load();
    } else {
      _loadPreview(previewBook);
    }
  }

  /// 필요한 변수는 캡처·테스트용 교재와 초기 체류 시간이다.
  /// 작동 원리는 네트워크 런타임을 만들지 않고 실제 페이지 변환과 필기·북마크 UI만 동일하게 초기화하는 것이다.
  void _loadPreview(BookData book) {
    final pages = _buildPages(book)
        .where((page) => page.number >= _pageFrom && page.number <= _pageTo)
        .toList(growable: false);
    _book = book;
    _pages = pages.isEmpty ? _buildFallbackPages(book) : pages;
    _currentPage = _pages.first.number;
    _serverElapsedSeconds = widget.previewElapsedSeconds;
    _loading = false;
    unawaited(_loadBookmarks());
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    if (!_runtimeCompleted && widget.previewBook == null) {
      unawaited(_completeRuntime());
    }
    _pageController.dispose();
    super.dispose();
  }

  // 필요 변수: 코스 런타임과 교재 응답. 작동 원리: 런타임을 먼저 연 뒤 페이지·북마크를 복원하고 heartbeat를 시작한다.
  Future<void> _load() async {
    try {
      final runtime = await ApiClient.instance.startCourseTextbookRuntime(
        courseId: widget.courseId,
        moduleId: widget.moduleId,
        textbookId: widget.textbookId,
        pageFrom: _pageFrom,
        pageTo: _pageTo,
        minMinutes: widget.minMinutes,
        enforceMinMinutes: widget.enforceMinMinutes,
      );
      _applyRuntime(runtime);

      final payload = await ApiClient.instance.getCourseTextbook(
        widget.courseId,
        widget.textbookId,
      );
      final book = BookData.fromJson(_extractBookPayload(payload));
      final pages = _buildPages(book)
          .where((page) {
            return page.number >= _pageFrom && page.number <= _pageTo;
          })
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _book = book;
        _pages = pages.isEmpty ? _buildFallbackPages(book) : pages;
        _currentPage = _pages.first.number;
        _loading = false;
      });
      unawaited(_loadBookmarks());
      _heartbeatTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _sendHeartbeat(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // 필요 변수: 공용 BookmarkStore. 작동 원리: 현재 사용자 로컬 북마크를 한 번 읽어 페이지별 활성 상태를 계산한다.
  Future<void> _loadBookmarks() async {
    final bookmarks = await BookmarkStore.load();
    if (!mounted) return;
    setState(() => _bookmarks = bookmarks);
  }

  // 필요 변수: textbookId와 현재 페이지. 작동 원리: 동일 교재·페이지에 저장된 항목 존재 여부를 반환한다.
  bool get _isCurrentPageBookmarked => _bookmarks.any(
    (item) =>
        item.bookId == widget.textbookId && item.entryIndex == _currentPage,
  );

  // 필요 변수: 현재 페이지, 교재 제목, 북마크 저장 상태. 작동 원리: 같은 버튼으로 현재 페이지 북마크를 추가하거나 제거한다.
  Future<void> _toggleBookmark() async {
    if (_bookmarkBusy) return;
    _bookmarkBusy = true;
    try {
      final current = _bookmarks.where(
        (item) =>
            item.bookId == widget.textbookId && item.entryIndex == _currentPage,
      );
      final List<BookmarkItem> updated;
      if (current.isNotEmpty) {
        updated = await BookmarkStore.remove(current.first.id);
      } else {
        final now = DateTime.now().microsecondsSinceEpoch;
        updated = await BookmarkStore.add(
          BookmarkItem(
            id: now.toString(),
            bookId: widget.textbookId,
            bookTitle: _book?.title ?? '코스 교재',
            entryIndex: _currentPage,
            entryTitle: _pages
                .firstWhere((page) => page.number == _currentPage)
                .title,
            createdAt: now,
          ),
        );
      }
      if (!mounted) return;
      setState(() => _bookmarks = updated);
    } finally {
      _bookmarkBusy = false;
    }
  }

  // 필요 변수: 코스·모듈·교재·페이지 식별자. 작동 원리: 다른 학습 범위와 충돌하지 않는 페이지별 로컬 필기 키를 만든다.
  String _annotationStorageKey(int pageNumber) {
    return 'course_textbook_annotation_v1:${widget.courseId}:'
        '${widget.moduleId}:${widget.textbookId}:$pageNumber';
  }

  Map<String, dynamic> _extractBookPayload(Map<String, dynamic> payload) {
    final textbook = payload['textbook'];
    if (textbook is Map) return Map<String, dynamic>.from(textbook);
    final document = payload['document'];
    if (document is Map) return Map<String, dynamic>.from(document);
    return payload;
  }

  /// 필요한 변수는 API 교재의 장·절·문단과 태그다.
  /// 작동 원리는 비정상적으로 JSON 배열 한 줄로 저장된 문단도 UTF-8 문자열 목록으로 복원하고,
  /// 원문을 정의·원리·예제·정리 역할별 실제 페이지로 나누며 첫 개념 페이지에 JSXGraph 삽화를 연결하는 것이다.
  List<_ReaderPage> _buildPages(BookData book) {
    final pages = <_ReaderPage>[];
    var pageNo = 1;
    for (final chapter in book.chapters) {
      final intro = _normalizeParagraphs(chapter.intro);
      final generatedIntro =
          intro.length == 1 &&
          intro.first.endsWith('개념 학습') &&
          chapter.sections.isNotEmpty;
      if (intro.isNotEmpty && !generatedIntro) {
        pages.add(
          _ReaderPage(
            number: pageNo++,
            chapter: chapter.title,
            title: chapter.title,
            paragraphs: intro,
            kind: _ReaderPageKind.opening,
            kicker: '단원 열기',
            tags: book.tags,
            graph: _findConceptGraph(
              '${book.title} ${chapter.title} ${book.tags.join(' ')}',
            ),
          ),
        );
      }
      for (final section in chapter.sections) {
        final paragraphs = _normalizeParagraphs(section.paragraphs);
        final graph = _findConceptGraph(
          '${book.title} ${chapter.title} ${section.title} ${book.tags.join(' ')}',
        );
        for (var index = 0; index < paragraphs.length; index++) {
          final paragraph = paragraphs[index];
          final kind = _classifyPageKind(
            paragraph: paragraph,
            index: index,
            total: paragraphs.length,
          );
          pages.add(
            _ReaderPage(
              number: pageNo++,
              chapter: chapter.title,
              title: _editorialPageTitle(section.title, kind),
              sectionTitle: section.title,
              kicker: _pageKicker(kind),
              kind: kind,
              paragraphs: [paragraph],
              images: index < section.images.length
                  ? [section.images[index]]
                  : const [],
              tags: book.tags,
              graph: index == 0 ? graph : null,
              sectionPage: index + 1,
              sectionPageCount: paragraphs.length,
            ),
          );
        }
      }
    }
    return pages;
  }

  List<_ReaderPage> _buildFallbackPages(BookData book) {
    return [
      _ReaderPage(
        number: _pageFrom,
        chapter: book.title,
        title: book.title,
        paragraphs: [
          book.subtitle.isEmpty ? '교재 본문을 불러왔지만 표시할 페이지가 없습니다.' : book.subtitle,
        ],
        kind: _ReaderPageKind.opening,
        kicker: '교재 안내',
        tags: book.tags,
        graph: _findConceptGraph('${book.title} ${book.tags.join(' ')}'),
      ),
    ];
  }

  /// 필요한 변수는 문단 내용과 절 안의 순서다.
  /// 작동 원리는 정의·원리·예제·정리 신호를 읽어 같은 원문도 목적에 맞는 편집 페이지로 분류하는 것이다.
  _ReaderPageKind _classifyPageKind({
    required String paragraph,
    required int index,
    required int total,
  }) {
    if (index == 0) return _ReaderPageKind.concept;
    final normalized = paragraph.replaceAll(RegExp(r'\s+'), '');
    if (RegExp(r'예제|문제|구체적|단계별|구해봅시다|풀어봅시다').hasMatch(normalized)) {
      return _ReaderPageKind.example;
    }
    if (index == total - 1 ||
        RegExp(r'주의|기억|정리|결론|마지막으로').hasMatch(normalized)) {
      return _ReaderPageKind.summary;
    }
    return _ReaderPageKind.principle;
  }

  /// 필요한 변수는 절 제목과 페이지 역할이다.
  /// 작동 원리는 목차에서 전문의 흐름이 보이도록 짧고 일관된 편집 제목을 만든다.
  String _editorialPageTitle(String sectionTitle, _ReaderPageKind kind) {
    return switch (kind) {
      _ReaderPageKind.opening => sectionTitle,
      _ReaderPageKind.concept => sectionTitle,
      _ReaderPageKind.principle => '$sectionTitle의 원리',
      _ReaderPageKind.example => '$sectionTitle · 예제',
      _ReaderPageKind.summary => '$sectionTitle · 정리',
    };
  }

  /// 필요한 변수는 페이지 역할이다.
  /// 작동 원리는 종이 상단과 목차에 표시할 한국어 학습 단계명을 반환하는 것이다.
  String _pageKicker(_ReaderPageKind kind) {
    return switch (kind) {
      _ReaderPageKind.opening => '단원 열기',
      _ReaderPageKind.concept => '개념 이해',
      _ReaderPageKind.principle => '원리 탐구',
      _ReaderPageKind.example => '예제 풀이',
      _ReaderPageKind.summary => '핵심 정리',
    };
  }

  /// 필요한 변수는 원본 문단 목록이다.
  /// 작동 원리는 생성 데이터에 문자열로 중첩된 JSON 배열을 한 번 더 해석해 문단 단위로 펼치는 것이다.
  List<String> _normalizeParagraphs(List<String> source) {
    final normalized = <String>[];
    for (final paragraph in source) {
      final trimmed = paragraph.trim();
      if (!(trimmed.startsWith('[') && trimmed.endsWith(']'))) {
        if (trimmed.isNotEmpty) normalized.add(trimmed);
        continue;
      }
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          normalized.addAll(
            decoded
                .map((item) => item?.toString().trim() ?? '')
                .where((item) => item.isNotEmpty),
          );
          continue;
        }
      } catch (_) {
        // 생성 원문이 JSON이 아니면 내용 손실 없이 일반 문단으로 표시한다.
      }
      normalized.add(trimmed);
    }
    return normalized;
  }

  /// 필요한 변수는 교재명·장·절·태그를 합친 검색 문장이다.
  /// 작동 원리는 그래프가 의미 있는 수학 개념만 허용한 뒤 기존 JSXGraph 카탈로그와 가장 많이 겹치는 예제를 고른다.
  AiFlowGraphDocument? _findConceptGraph(String query) {
    final normalized = query.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (normalized.contains('두점을지나는직선') || normalized.contains('기울기')) {
      return const AiFlowGraphDocument(
        items: [
          AiFlowGraphItem(
            id: 'concept-slope-line',
            type: AiFlowGraphItemType.function,
            label: '두 점을 지나는 직선 y = 2x',
            colorHex: '#202024',
            expression: '2*x',
          ),
          AiFlowGraphItem(
            id: 'concept-slope-points',
            type: AiFlowGraphItemType.scatter,
            label: 'A(1, 2), B(3, 6)',
            colorHex: '#245CFF',
            xValues: [1, 3],
            yValues: [2, 6],
          ),
        ],
        settings: AiFlowGraphSettings(
          lockViewport: true,
          viewport: AiFlowGraphViewport(left: -1, right: 5, top: 9, bottom: -2),
        ),
      );
    }
    const graphConcepts = <String>[
      '함수',
      '그래프',
      '기울기',
      '직선',
      '좌표',
      '부등식',
      '수열',
      '미분',
      '적분',
      '삼각',
      '지수',
      '로그',
      '원',
    ];
    if (!graphConcepts.any(normalized.contains)) return null;

    AiFlowGraphDocument? best;
    var bestScore = 0;
    for (final subject in aiFlowGraphCatalog) {
      for (final example in subject.examples) {
        final candidates = <String>[
          example.unit,
          example.title,
          ...example.searchTerms,
        ];
        var score = 0;
        for (final candidate in candidates) {
          final token = candidate.toLowerCase().replaceAll(RegExp(r'\s+'), '');
          if (token.length >= 2 && normalized.contains(token)) {
            score += token.length;
          }
        }
        if (score > bestScore) {
          bestScore = score;
          best = example.document;
        }
      }
    }
    return bestScore >= 2 ? best : null;
  }

  void _applyRuntime(Map<String, dynamic> runtime) {
    final elapsed = _readInt(
      runtime['elapsed_seconds'] ??
          runtime['total_seconds'] ??
          runtime['view_seconds'],
    );
    final progress = runtime['progress'];
    final completion = _readDouble(
      runtime['completion_rate'] ??
          runtime['completion'] ??
          (progress is Map
              ? progress['completion_ratio'] ?? progress['completion_rate']
              : progress),
    );
    _serverElapsedSeconds = elapsed;
    _serverCompletion = completion == null
        ? null
        : (completion > 1 ? completion / 100 : completion);
  }

  Future<void> _sendHeartbeat() async {
    if (!mounted || _loading || _pages.isEmpty) return;
    setState(() => _elapsedSeconds = _localElapsedSeconds());
    if (widget.previewBook != null) return;
    try {
      final runtime = await ApiClient.instance.heartbeatCourseTextbookRuntime(
        courseId: widget.courseId,
        moduleId: widget.moduleId,
        textbookId: widget.textbookId,
        currentPage: _currentPage,
        pageFrom: _pageFrom,
        pageTo: _pageTo,
      );
      if (!mounted) return;
      setState(() => _applyRuntime(runtime));
    } catch (_) {}
  }

  Future<void> _completeRuntime() async {
    if (_runtimeCompleted) return;
    if (widget.previewBook != null) {
      _runtimeCompleted = true;
      return;
    }
    try {
      final runtime = await ApiClient.instance.completeCourseTextbookRuntime(
        courseId: widget.courseId,
        moduleId: widget.moduleId,
        textbookId: widget.textbookId,
        currentPage: _currentPage,
        pageFrom: _pageFrom,
        pageTo: _pageTo,
      );
      _runtimeCompleted = true;
      _applyRuntime(runtime);
    } catch (_) {}
  }

  Future<void> _closeReader() async {
    await _completeRuntime();
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  int _localElapsedSeconds() {
    final startedAt = _startedAt;
    if (startedAt == null) return 0;
    return DateTime.now().difference(startedAt).inSeconds;
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remain = seconds % 60;
    return '$minutes:${remain.toString().padLeft(2, '0')}';
  }

  void _jumpToPage(int number) {
    final index = _pages.indexWhere((page) => page.number == number);
    if (index < 0) return;
    setState(() => _currentPage = number);
    if (!_scrollMode) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _closeReader();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE9E9E7),
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : _error != null
              ? _ErrorView(message: _error!)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 780;
                    return Column(
                      children: [
                        _buildTopBar(book, compact: !wide),
                        Expanded(
                          child: wide
                              ? _buildWideReader(book)
                              : _buildCompactReader(book),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  /// 필요한 변수는 교재 제목·현재 페이지·이수율·화면 형식이다.
  /// 작동 원리는 가로형에는 브랜드·진행률·북마크·완료를 모두 배치하고 세로형에는 읽기에 필요한 요소만 남기는 것이다.
  Widget _buildTopBar(BookData? book, {required bool compact}) {
    return Container(
      height: compact ? 62 : 72,
      padding: EdgeInsets.fromLTRB(compact ? 8 : 16, 7, compact ? 9 : 16, 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        border: Border(
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '닫기',
            onPressed: _closeReader,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          if (!compact) ...[
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Text(
                'A',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book?.title ?? '교재 보기',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansKr(
                    fontSize: compact ? 12 : 15,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
                Text(
                  'p.$_currentPage / $_pageFrom–$_pageTo · 학습 시간 ${_formatTime(_elapsedSeconds + _serverElapsedSeconds)}',
                  style: TextStyle(
                    fontSize: compact ? 8 : 9,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (!compact) ...[
            SizedBox(
              width: 150,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '이수율',
                        style: TextStyle(fontSize: 9, color: Colors.black54),
                      ),
                      Text(
                        '${(_completion * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  LinearProgressIndicator(
                    value: _completion,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(9),
                    color: Colors.black,
                    backgroundColor: const Color(0xFFE5E5E7),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            IconButton(
              key: const ValueKey('course-textbook-bookmark'),
              tooltip: _isCurrentPageBookmarked ? '북마크 해제' : '북마크 추가',
              onPressed: _bookmarkBusy ? null : _toggleBookmark,
              icon: Icon(
                _isCurrentPageBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
              ),
            ),
          ],
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F3),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Row(
              children: [
                _ReaderModeButton(
                  tooltip: '한 쪽씩',
                  icon: Icons.view_carousel_outlined,
                  selected: !_scrollMode,
                  onPressed: () => setState(() => _scrollMode = false),
                ),
                _ReaderModeButton(
                  tooltip: '스크롤',
                  icon: Icons.view_agenda_outlined,
                  selected: _scrollMode,
                  onPressed: () => setState(() => _scrollMode = true),
                ),
              ],
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _closeReader,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                minimumSize: const Size(72, 38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                textStyle: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text('학습 완료'),
            ),
          ],
        ],
      ),
    );
  }

  /// 필요한 변수는 가로 화면용 교재·목차 접힘 상태다.
  /// 작동 원리는 좌측 목차와 도구, 접기 손잡이, 중앙 문서 작업공간을 시안과 같은 3열 구조로 배치하는 것이다.
  Widget _buildWideReader(BookData? book) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: _tocCollapsed ? 0 : 260,
          child: _tocCollapsed
              ? const SizedBox.shrink()
              : _buildTableOfContents(),
        ),
        SizedBox(
          width: 22,
          child: Center(
            child: IconButton(
              tooltip: _tocCollapsed ? '목차 펼치기' : '목차 접기',
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(16),
                  ),
                  side: const BorderSide(color: Color(0xFFD8D8DA)),
                ),
              ),
              onPressed: () => setState(() => _tocCollapsed = !_tocCollapsed),
              icon: Icon(
                _tocCollapsed
                    ? Icons.chevron_right_rounded
                    : Icons.chevron_left_rounded,
                size: 16,
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _buildDocumentStrip(book, compact: false),
              Expanded(child: _buildReaderSurface(wide: true)),
            ],
          ),
        ),
      ],
    );
  }

  /// 필요한 변수는 세로 화면용 교재와 현재 진행 상태다.
  /// 작동 원리는 문서바·종이·페이지 이동·학습 진행을 위에서 아래로 고정해 한 손 조작 흐름을 만드는 것이다.
  Widget _buildCompactReader(BookData? book) {
    return Column(
      children: [
        _buildDocumentStrip(book, compact: true),
        Expanded(child: _buildReaderSurface(wide: false)),
        _buildCompactPageNavigation(),
        _buildCompactProgressRail(),
      ],
    );
  }

  /// 필요한 변수는 교재명과 현재 페이지 북마크 상태다.
  /// 작동 원리는 HTML의 두 번째 문서 스트립에 자료명과 북마크 동작을 분리해 표시하는 것이다.
  Widget _buildDocumentStrip(BookData? book, {required bool compact}) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F7),
        border: Border(bottom: BorderSide(color: Color(0xFFE1E1E1))),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_book_outlined, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              book?.title ?? '교재 보기',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          if (!compact) ...[
            _TextScaleButton(
              label: 'A−',
              onPressed: () =>
                  setState(() => _textScale = max(.8, _textScale - .1)),
            ),
            SizedBox(
              width: 48,
              child: Text(
                '${(_textScale * 100).round()}%',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _TextScaleButton(
              label: 'A＋',
              onPressed: () =>
                  setState(() => _textScale = min(1.3, _textScale + .1)),
            ),
          ] else
            IconButton(
              key: const ValueKey('course-textbook-mobile-bookmark'),
              tooltip: _isCurrentPageBookmarked ? '북마크 해제' : '북마크 추가',
              onPressed: _bookmarkBusy ? null : _toggleBookmark,
              icon: Icon(
                _isCurrentPageBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReaderSurface({required bool wide}) {
    if (_pages.isEmpty) {
      return const Center(child: Text('표시할 교재 페이지가 없습니다.'));
    }
    return Container(
      color: const Color(0xFFE9E9E7),
      padding: EdgeInsets.fromLTRB(
        wide ? 24 : 10,
        wide ? 24 : 16,
        wide ? 24 : 10,
        wide ? 24 : 12,
      ),
      child: _scrollMode
          ? _buildScrollReader(wide: wide)
          : _buildPageReader(wide: wide),
    );
  }

  // 필요 변수: 페이지 목록과 PageController. 작동 원리: 좌우 페이지 이동 시 위치를 heartbeat에 반영하고 페이지별 필기 캔버스를 유지한다.
  Widget _buildPageReader({required bool wide}) {
    final currentIndex = _pages.indexWhere(
      (page) => page.number == _currentPage,
    );
    return Row(
      children: [
        if (wide)
          _PageArrow(
            icon: Icons.chevron_left_rounded,
            enabled: currentIndex > 0,
            onPressed: () => _jumpToPage(_pages[currentIndex - 1].number),
          ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (index) {
              setState(() => _currentPage = _pages[index].number);
              _sendHeartbeat();
            },
            itemBuilder: (context, index) => LayoutBuilder(
              builder: (context, constraints) {
                final width = wide
                    ? min(
                        610.0,
                        min(
                          constraints.maxWidth - 16,
                          constraints.maxHeight * .707,
                        ),
                      )
                    : min(360.0, constraints.maxWidth);
                return Center(
                  child: SizedBox(
                    width: width,
                    height: width / .707,
                    child: CourseTextbookAnnotationCanvas(
                      key: ValueKey(
                        'course-textbook-annotation-${_pages[index].number}',
                      ),
                      storageKey: _annotationStorageKey(_pages[index].number),
                      collapseToolbar: true,
                      child: _PaperPage(
                        page: _pages[index],
                        compact: !wide,
                        textScale: _textScale,
                        renderGraph: _pages[index].number == _currentPage,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (wide)
          _PageArrow(
            icon: Icons.chevron_right_rounded,
            enabled: currentIndex >= 0 && currentIndex < _pages.length - 1,
            onPressed: () => _jumpToPage(_pages[currentIndex + 1].number),
          ),
      ],
    );
  }

  // 필요 변수: 페이지 목록. 작동 원리: 세로 읽기에서도 각 종이에 독립 필기 저장 키를 부여한다.
  Widget _buildScrollReader({required bool wide}) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _pages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final page = _pages[index];
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 680 : 360),
            child: CourseTextbookAnnotationCanvas(
              key: ValueKey('course-textbook-annotation-${page.number}'),
              storageKey: _annotationStorageKey(page.number),
              collapseToolbar: true,
              child: _PaperPage(
                page: page,
                compact: !wide,
                textScale: _textScale,
                renderGraph: true,
                onVisible: () => _currentPage = page.number,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableOfContents() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE1E1E3))),
            ),
            child: const _PanelTitle(icon: Icons.toc_rounded, title: '목차'),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                final page = _pages[index];
                final selected = page.number == _currentPage;
                return InkWell(
                  onTap: () => _jumpToPage(page.number),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 54),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    color: selected
                        ? Colors.black
                        : (index.isOdd
                              ? const Color(0xFFFAFAFA)
                              : Colors.white),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 38,
                          child: Text(
                            '${page.number}'.padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: selected ? Colors.white70 : Colors.black45,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                page.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: selected ? Colors.white : _ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selected
                                    ? '${page.number}쪽 · 현재 위치'
                                    : '${page.kicker} · ${page.sectionPage}/${page.sectionPageCount}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 8,
                                  color: selected
                                      ? Colors.white60
                                      : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          selected ? '●' : '›',
                          style: TextStyle(
                            fontSize: 9,
                            color: selected ? Colors.white : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildSidebarTools(),
        ],
      ),
    );
  }

  /// 필요한 변수는 현재 페이지와 북마크·필기 기능이다.
  /// 작동 원리는 가로 시안의 좌측 하단에 학습 도구와 페이지 이동을 두 줄로 고정한다.
  Widget _buildSidebarTools() {
    final currentIndex = _pages.indexWhere(
      (page) => page.number == _currentPage,
    );
    final hasPrevious = currentIndex > 0;
    final hasNext = currentIndex >= 0 && currentIndex < _pages.length - 1;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE1E1E3))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SidebarTool(
                icon: _isCurrentPageBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                tooltip: _isCurrentPageBookmarked ? '북마크 해제' : '북마크 추가',
                selected: _isCurrentPageBookmarked,
                onPressed: _toggleBookmark,
              ),
              _SidebarTool(
                icon: Icons.edit_outlined,
                tooltip: '필기',
                onPressed: _showAnnotationGuide,
              ),
              _SidebarTool(
                icon: Icons.border_color_outlined,
                tooltip: '형광펜',
                onPressed: _showAnnotationGuide,
              ),
              _SidebarTool(
                icon: Icons.palette_outlined,
                tooltip: '색상',
                onPressed: _showAnnotationGuide,
              ),
              _SidebarTool(
                icon: Icons.auto_fix_off_outlined,
                tooltip: '지우개',
                onPressed: _showAnnotationGuide,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              _SidebarTool(
                icon: Icons.search_rounded,
                tooltip: '검색',
                onPressed: _showSearch,
              ),
              const SizedBox(width: 7),
              _SidebarTool(
                icon: Icons.chevron_left_rounded,
                tooltip: '이전 페이지',
                onPressed: hasPrevious
                    ? () => _jumpToPage(_pages[currentIndex - 1].number)
                    : null,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F4),
                    border: Border.all(color: const Color(0xFFE0E0E2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_currentPage / $_pageTo',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              _SidebarTool(
                icon: Icons.chevron_right_rounded,
                tooltip: '다음 페이지',
                onPressed: hasNext
                    ? () => _jumpToPage(_pages[currentIndex + 1].number)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 필요한 변수는 현재 페이지 위치다.
  /// 작동 원리는 모바일 종이 아래에 이전·페이지 번호·다음 버튼을 고정한다.
  Widget _buildCompactPageNavigation() {
    final index = _pages.indexWhere((page) => page.number == _currentPage);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CompactNavButton(
            label: '이전',
            icon: Icons.chevron_left_rounded,
            iconFirst: true,
            onPressed: index > 0
                ? () => _jumpToPage(_pages[index - 1].number)
                : null,
          ),
          Text(
            '$_currentPage / $_pageTo',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
          ),
          _CompactNavButton(
            label: '다음',
            icon: Icons.chevron_right_rounded,
            onPressed: index >= 0 && index < _pages.length - 1
                ? () => _jumpToPage(_pages[index + 1].number)
                : null,
          ),
        ],
      ),
    );
  }

  /// 필요한 변수는 학습 시간·최소 시간·이수율이다.
  /// 작동 원리는 모바일 최하단에 시간 진행 막대와 목차 진입을 분리해 항상 노출한다.
  Widget _buildCompactProgressRail() {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE1E1E3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '학습 시간 ${_formatTime(_elapsedSeconds + _serverElapsedSeconds)} · 최소 ${_formatTime(_minSeconds)}',
                  style: const TextStyle(fontSize: 8, color: Colors.black54),
                ),
                const SizedBox(height: 7),
                LinearProgressIndicator(
                  value: _timeProgress,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(9),
                  color: Colors.black,
                  backgroundColor: const Color(0xFFE5E5E7),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _showCompactToc,
            icon: const Icon(Icons.toc_rounded, size: 17),
            label: const Text('목차'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(64, 36),
              textStyle: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 필요한 변수는 현재 페이지 목록이다.
  /// 작동 원리는 모바일에서 전체 높이를 차지하지 않는 하단 시트로 목차를 열고 선택 즉시 이동한다.
  void _showCompactToc() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SizedBox(height: 460, child: _buildTableOfContents()),
    );
  }

  /// 필요한 변수는 현재 BuildContext다.
  /// 작동 원리는 종이 우측 상단의 필기 도구 위치를 짧게 안내해 가로형 도구 버튼과 실제 캔버스를 연결한다.
  void _showAnnotationGuide() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('종이 오른쪽 위 필기 도구에서 펜·지우개·색상을 선택할 수 있습니다.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 필요한 변수는 교재 페이지 목록이다.
  /// 작동 원리는 제목 또는 장 이름을 입력받아 첫 일치 페이지로 이동한다.
  Future<void> _showSearch() async {
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('교재 검색'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '개념 또는 단원명'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('검색'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || query == null || query.trim().isEmpty) return;
    final needle = query.trim().toLowerCase();
    final index = _pages.indexWhere(
      (page) => '${page.chapter} ${page.title} ${page.paragraphs.join(' ')}'
          .toLowerCase()
          .contains(needle),
    );
    if (index >= 0) _jumpToPage(_pages[index].number);
  }
}

enum _ReaderPageKind { opening, concept, principle, example, summary }

class _ReaderPage {
  const _ReaderPage({
    required this.number,
    required this.chapter,
    required this.title,
    required this.paragraphs,
    required this.kind,
    required this.kicker,
    this.sectionTitle = '',
    this.sectionPage = 1,
    this.sectionPageCount = 1,
    this.images = const [],
    this.tags = const [],
    this.graph,
  });

  final int number;
  final String chapter;
  final String title;
  final String sectionTitle;
  final String kicker;
  final _ReaderPageKind kind;
  final int sectionPage;
  final int sectionPageCount;
  final List<String> paragraphs;
  final List<String> images;
  final List<String> tags;
  final AiFlowGraphDocument? graph;
}

class _PaperPage extends StatelessWidget {
  const _PaperPage({
    required this.page,
    required this.compact,
    required this.textScale,
    required this.renderGraph,
    this.onVisible,
  });

  final _ReaderPage page;
  final bool compact;
  final double textScale;
  final bool renderGraph;
  final VoidCallback? onVisible;

  /// 필요한 변수는 페이지 문단 전체다.
  /// 작동 원리는 첫 번째 표시 수식 또는 첫 번째 인라인 수식을 찾아 핵심 개념 카드에 재사용한다.
  String? _keyFormula() {
    final source = page.paragraphs.join('\n');
    final displayCandidates = RegExp(r'\$\$(.+?)\$\$', dotAll: true)
        .allMatches(source)
        .map((match) => match.group(1)?.trim() ?? '')
        .where((formula) => formula.isNotEmpty)
        .toList(growable: false);
    if (displayCandidates.isNotEmpty) {
      displayCandidates.sort(
        (left, right) => right.length.compareTo(left.length),
      );
      return '\$\$${displayCandidates.first}\$\$';
    }

    final inlineCandidates = RegExp(r'(?<!\$)\$(?!\$)(.+?)(?<!\$)\$(?!\$)')
        .allMatches(source)
        .map((match) => match.group(1)?.trim() ?? '')
        .where((formula) => formula.length >= 4)
        .toList(growable: false);
    if (inlineCandidates.isEmpty) return null;
    inlineCandidates.sort((left, right) {
      int score(String value) {
        final structureBonus =
            RegExp(r'=|\\frac|\\sum|\\lim|\\sqrt').hasMatch(value) ? 1000 : 0;
        return structureBonus + value.length;
      }

      return score(right).compareTo(score(left));
    });
    return '\$${inlineCandidates.first}\$';
  }

  /// 필요한 변수는 페이지 역할이다.
  /// 작동 원리는 원문을 바꾸지 않으면서 각 지면의 학습 목적을 한 문장으로 먼저 안내한다.
  String _editorialDeck() {
    return switch (page.kind) {
      _ReaderPageKind.opening => '이번 단원에서 연결될 개념과 학습 방향을 먼저 살펴봅니다.',
      _ReaderPageKind.concept => '정의를 문장·수식·그림으로 연결하며 개념의 기준을 세웁니다.',
      _ReaderPageKind.principle => '공식이 성립하는 이유와 적용 조건을 차례대로 이해합니다.',
      _ReaderPageKind.example => '주어진 조건을 읽고 풀이의 순서를 따라가며 개념을 적용합니다.',
      _ReaderPageKind.summary => '헷갈리기 쉬운 조건과 결론을 마지막으로 정확하게 정리합니다.',
    };
  }

  /// 필요한 변수는 원문 한 문단이다.
  /// 작동 원리는 예제 지면에서만 문장 경계를 찾아 번호를 붙이고, 모든 문장을 순서와 내용 손실 없이 배치한다.
  List<String> _exampleSteps(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final matches = RegExp(r'.+?(?:[.!?](?=\s|$)|다\.(?=\s|$)|$)')
        .allMatches(normalized)
        .map((match) => match.group(0)?.trim() ?? '')
        .where((sentence) => sentence.isNotEmpty)
        .toList(growable: false);
    return matches.isEmpty ? [normalized] : matches;
  }

  @override
  Widget build(BuildContext context) {
    onVisible?.call();
    final body = page.paragraphs.isEmpty
        ? '핵심 개념을 차근차근 살펴봅시다.'
        : page.paragraphs.join('\n\n');
    final formula = _keyFormula();
    final horizontalPadding = compact ? 22.0 : 48.0;
    final titleSize = (compact ? 19.0 : 27.0) * textScale;
    final bodySize = (compact ? 7.2 : 10.5) * textScale;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _TeacherCourseTextbookReaderPageState._paper,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          compact ? 25 : 42,
          horizontalPadding,
          compact ? 16 : 27,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${page.kicker.toUpperCase()} · ${page.chapter}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 6 : 9,
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  page.title,
                  style: TextStyle(
                    fontSize: compact ? 6 : 9,
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 8 : 10),
            const Divider(height: 1, color: Color(0xFFD8D8D8)),
            SizedBox(height: compact ? 14 : 25),
            Text(
              page.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSansKr(
                fontSize: titleSize,
                height: 1.25,
                letterSpacing: -0.7,
                fontWeight: FontWeight.w900,
                color: _TeacherCourseTextbookReaderPageState._ink,
              ),
            ),
            SizedBox(height: compact ? 7 : 10),
            Text(
              _editorialDeck(),
              style: GoogleFonts.notoSansKr(
                fontSize: (compact ? 7 : 10) * textScale,
                height: 1.65,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: compact ? 11 : 18),
            Expanded(
              child: SingleChildScrollView(
                child: _buildEditorialBody(
                  body: body,
                  formula: formula,
                  bodySize: bodySize,
                ),
              ),
            ),
            SizedBox(height: compact ? 8 : 14),
            const Divider(height: 1, color: Color(0xFFD8D8D8)),
            SizedBox(height: compact ? 7 : 9),
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      ...page.tags.take(2).map((tag) => '#$tag'),
                      if (page.sectionPageCount > 1)
                        '${page.sectionPage}/${page.sectionPageCount}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 6 : 8,
                      color: Colors.black45,
                    ),
                  ),
                ),
                Text(
                  '${page.number}',
                  style: TextStyle(
                    fontSize: compact ? 6 : 8,
                    fontWeight: FontWeight.w800,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 필요한 변수는 원문·대표 수식·본문 크기와 페이지 역할이다.
  /// 작동 원리는 원문 전체를 한 번도 생략하지 않고 역할별 지면 컴포넌트로 배치하는 것이다.
  Widget _buildEditorialBody({
    required String body,
    required String? formula,
    required double bodySize,
  }) {
    return switch (page.kind) {
      _ReaderPageKind.opening => _buildOpeningBody(body, bodySize),
      _ReaderPageKind.concept => _buildConceptBody(body, formula, bodySize),
      _ReaderPageKind.principle => _buildPrincipleBody(body, formula, bodySize),
      _ReaderPageKind.example => _buildExampleBody(body, formula, bodySize),
      _ReaderPageKind.summary => _buildSummaryBody(body, formula, bodySize),
    };
  }

  /// 필요한 변수는 단원 소개 원문과 본문 크기다.
  /// 작동 원리는 넓은 여백과 시작 번호를 사용해 새로운 학습 단원의 진입점을 만든다.
  Widget _buildOpeningBody(String body, double bodySize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '01',
          style: GoogleFonts.notoSansKr(
            fontSize: compact ? 34 : 54,
            fontWeight: FontWeight.w900,
            height: 1,
            color: const Color(0xFFE0E0E2),
          ),
        ),
        SizedBox(height: compact ? 12 : 20),
        _LatexText(text: body, fontSize: bodySize, height: 1.85),
      ],
    );
  }

  /// 필요한 변수는 정의 원문·대표 수식·본문 크기다.
  /// 작동 원리는 핵심 수식, 원문 전문, JSXGraph 삽화를 한 시야에 연결한다.
  Widget _buildConceptBody(String body, String? formula, double bodySize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (formula != null)
          _FormulaCard(
            formula: formula,
            compact: compact,
            textScale: textScale,
            label: 'CORE FORMULA',
          ),
        if (formula != null) SizedBox(height: compact ? 12 : 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _EditorialSection(
                label: '개념 읽기',
                child: _LatexText(text: body, fontSize: bodySize, height: 1.82),
              ),
            ),
            if (page.graph != null && renderGraph) ...[
              SizedBox(width: compact ? 10 : 22),
              _TextbookGraph(
                document: page.graph!,
                pageNumber: page.number,
                compact: compact,
                caption: '${page.sectionTitle}을 좌표평면에서 확인해 보세요.',
              ),
            ],
          ],
        ),
        ..._networkImages(),
      ],
    );
  }

  /// 필요한 변수는 원리 원문·대표 수식·본문 크기다.
  /// 작동 원리는 원문 전문을 세로 리듬으로 읽게 하고 조건 수식을 하단 증명 메모처럼 분리한다.
  Widget _buildPrincipleBody(String body, String? formula, double bodySize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            compact ? 12 : 20,
            compact ? 12 : 18,
            compact ? 12 : 20,
            compact ? 14 : 22,
          ),
          color: const Color(0xFFF3F3F4),
          child: _EditorialSection(
            label: 'WHY IT WORKS',
            child: _LatexText(text: body, fontSize: bodySize, height: 1.9),
          ),
        ),
        if (formula != null) ...[
          SizedBox(height: compact ? 12 : 20),
          _FormulaCard(
            formula: formula,
            compact: compact,
            textScale: textScale,
            label: '조건과 관계식',
            outlined: true,
          ),
        ],
        ..._networkImages(),
      ],
    );
  }

  /// 필요한 변수는 예제 원문·대표 수식·본문 크기다.
  /// 작동 원리는 원문의 모든 문장을 번호가 있는 풀이 단계로 바꿔 계산 흐름을 빠르게 훑게 한다.
  Widget _buildExampleBody(String body, String? formula, double bodySize) {
    final steps = _exampleSteps(body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 16,
            vertical: compact ? 8 : 11,
          ),
          color: Colors.black,
          child: Text(
            'WORKED EXAMPLE · 풀이의 흐름',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 6 : 8,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
        ),
        SizedBox(height: compact ? 9 : 14),
        for (var index = 0; index < steps.length; index++)
          Padding(
            padding: EdgeInsets.only(bottom: compact ? 8 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: compact ? 20 : 28,
                  height: compact ? 20 : 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0F0F1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: compact ? 6 : 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(width: compact ? 8 : 12),
                Expanded(
                  child: _LatexText(
                    text: steps[index],
                    fontSize: bodySize,
                    height: 1.75,
                  ),
                ),
              ],
            ),
          ),
        if (formula != null)
          _FormulaCard(
            formula: formula,
            compact: compact,
            textScale: textScale,
            label: '계산 포인트',
            outlined: true,
          ),
        ..._networkImages(),
      ],
    );
  }

  /// 필요한 변수는 정리 원문·대표 수식·본문 크기다.
  /// 작동 원리는 마지막 원문을 체크 포인트 카드로 강조해 복습할 때 빠르게 찾게 한다.
  Widget _buildSummaryBody(String body, String? formula, double bodySize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 14 : 22),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1.3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: compact ? 18 : 24,
                    height: compact ? 18 : 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: compact ? 11 : 15,
                    ),
                  ),
                  SizedBox(width: compact ? 7 : 10),
                  Text(
                    '마지막 체크',
                    style: TextStyle(
                      fontSize: compact ? 8 : 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 10 : 16),
              _LatexText(text: body, fontSize: bodySize, height: 1.9),
            ],
          ),
        ),
        if (formula != null) ...[
          SizedBox(height: compact ? 12 : 20),
          _FormulaCard(
            formula: formula,
            compact: compact,
            textScale: textScale,
            label: '기억할 식',
          ),
        ],
        ..._networkImages(),
      ],
    );
  }

  /// 필요한 변수는 현재 페이지의 원격 이미지 목록이다.
  /// 작동 원리는 이미지가 있는 교재도 전문 아래에 같은 지면 규격으로 표시하고 실패 이미지는 읽기를 방해하지 않게 숨긴다.
  List<Widget> _networkImages() {
    return [
      for (final image in page.images) ...[
        SizedBox(height: compact ? 10 : 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            image,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ],
    ];
  }
}

class _EditorialSection extends StatelessWidget {
  const _EditorialSection({required this.label, required this.child});

  final String label;
  final Widget child;

  /// 필요한 변수는 섹션 레이블과 전문 위젯이다.
  /// 작동 원리는 작은 대문자형 레이블 아래에 본문을 두어 교재 지면의 정보 계층을 통일한다.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: .65,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _FormulaCard extends StatelessWidget {
  const _FormulaCard({
    required this.formula,
    required this.compact,
    required this.textScale,
    required this.label,
    this.outlined = false,
  });

  final String formula;
  final bool compact;
  final double textScale;
  final String label;
  final bool outlined;

  /// 필요한 변수는 수식·화면 형식·배율·카드 종류다.
  /// 작동 원리는 핵심 수식을 중앙 정렬하고 채움 또는 외곽선 카드로 본문과 구분한다.
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 20,
        vertical: compact ? 10 : 16,
      ),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : const Color(0xFFF1F1F2),
        border: outlined
            ? Border.all(color: const Color(0xFFD1D1D3))
            : const Border(left: BorderSide(color: Colors.black, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 6 : 8,
              fontWeight: FontWeight.w900,
              letterSpacing: .65,
            ),
          ),
          SizedBox(height: compact ? 5 : 8),
          Center(
            child: _LatexText(
              text: formula,
              fontSize: (compact ? 11 : 17) * textScale,
              height: 1.25,
              center: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextbookGraph extends StatelessWidget {
  const _TextbookGraph({
    required this.document,
    required this.pageNumber,
    required this.compact,
    required this.caption,
  });

  final AiFlowGraphDocument document;
  final int pageNumber;
  final bool compact;
  final String caption;

  /// 필요한 변수는 JSXGraph 문서·페이지 번호·화면 형식·캡션이다.
  /// 작동 원리는 교재 본문 옆에 잠긴 좌표평면 삽화와 설명을 같은 폭으로 배치한다.
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 105 : 180,
      child: Column(
        children: [
          Container(
            height: compact ? 105 : 180,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD8D8D8)),
            ),
            clipBehavior: Clip.antiAlias,
            child: buildJsxGraphEmbed(
              document,
              key: ValueKey('textbook-jsx-graph-$pageNumber'),
            ),
          ),
          SizedBox(height: compact ? 4 : 7),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 5 : 7,
              height: 1.4,
              color: Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}

class _LatexText extends StatelessWidget {
  const _LatexText({
    required this.text,
    required this.fontSize,
    required this.height,
    this.center = false,
  });

  final String text;
  final double fontSize;
  final double height;
  final bool center;

  /// 필요한 변수는 LaTeX가 섞인 UTF-8 본문과 글자 크기다.
  /// 작동 원리는 공용 콘텐츠 블록 파서를 사용해 일반 문장과 수식을 한 흐름으로 렌더링하는 것이다.
  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.notoSansKr(
      fontSize: fontSize,
      height: height,
      color: Colors.black.withValues(alpha: .84),
    );
    return Align(
      alignment: center ? Alignment.center : Alignment.centerLeft,
      child: ContentBlocksView(
        inline: true,
        blocks: parseTextWithLatex(text),
        textStyle: style,
        latexStyle: style,
      ),
    );
  }
}

class _ReaderModeButton extends StatelessWidget {
  const _ReaderModeButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  /// 필요한 변수는 보기 모드 아이콘·선택 상태·전환 콜백이다.
  /// 작동 원리는 HTML의 두 칸 보기 전환에서 선택된 방식만 검은 원으로 강조하는 것이다.
  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: selected ? Colors.black : Colors.transparent,
        foregroundColor: selected ? Colors.white : Colors.black54,
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
    );
  }
}

class _TextScaleButton extends StatelessWidget {
  const _TextScaleButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  /// 필요한 변수는 배율 레이블과 변경 콜백이다.
  /// 작동 원리는 문서바의 작은 사각 버튼으로 교재 본문 배율을 한 단계씩 조절하는 것이다.
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 30,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          textStyle: const TextStyle(fontSize: 9),
          side: const BorderSide(color: Color(0xFFDDDDDF)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _PageArrow extends StatelessWidget {
  const _PageArrow({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  /// 필요한 변수는 방향·이동 가능 여부·페이지 이동 콜백이다.
  /// 작동 원리는 가로형 종이 양쪽에 반투명 페이지 이동 버튼을 고정하는 것이다.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 54),
          backgroundColor: Colors.white.withValues(alpha: .82),
          disabledBackgroundColor: Colors.white.withValues(alpha: .35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        icon: Icon(icon, size: 22),
      ),
    );
  }
}

class _SidebarTool extends StatelessWidget {
  const _SidebarTool({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  /// 필요한 변수는 도구 아이콘·선택 상태·실행 콜백이다.
  /// 작동 원리는 좌측 도구 영역의 모든 조작을 같은 38px 버튼 규격으로 표현하는 것이다.
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: selected ? Colors.black : Colors.white,
          foregroundColor: selected ? Colors.white : Colors.black54,
          disabledForegroundColor: Colors.black26,
          side: const BorderSide(color: Color(0xFFDEDEE0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

class _CompactNavButton extends StatelessWidget {
  const _CompactNavButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.iconFirst = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool iconFirst;

  /// 필요한 변수는 모바일 이동 문구·방향 아이콘·실행 콜백이다.
  /// 작동 원리는 이전 버튼은 아이콘을 앞에, 다음 버튼은 뒤에 배치해 이동 방향을 즉시 알게 하는 것이다.
  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 16);
    final textWidget = Text(label);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(58, 34),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
        backgroundColor: const Color(0xFFF5F5F6),
        side: const BorderSide(color: Color(0xFFDEDEE0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: iconFirst
            ? [iconWidget, const SizedBox(width: 3), textWidget]
            : [textWidget, const SizedBox(width: 3), iconWidget],
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: _TeacherCourseTextbookReaderPageState._green,
        ),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }
}
