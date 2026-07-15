import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:s11/shared/business/repositories/bookmark_store.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/course/session/course_textbook_annotation_canvas.dart';

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
  static const _mint = Colors.black;
  static const _paper = Color(0xFFFFFEF9);
  static const _ink = Color(0xFF151515);

  final _pageController = PageController();
  Timer? _heartbeatTimer;

  BookData? _book;
  List<_ReaderPage> _pages = const [];
  bool _loading = true;
  bool _scrollMode = false;
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

  List<_ReaderPage> _buildPages(BookData book) {
    final pages = <_ReaderPage>[];
    var pageNo = 1;
    for (final chapter in book.chapters) {
      if (chapter.intro.isNotEmpty) {
        pages.add(
          _ReaderPage(
            number: pageNo++,
            chapter: chapter.title,
            title: chapter.title,
            paragraphs: chapter.intro,
          ),
        );
      }
      for (final section in chapter.sections) {
        pages.add(
          _ReaderPage(
            number: pageNo++,
            chapter: chapter.title,
            title: section.title,
            paragraphs: section.paragraphs,
            images: section.images,
          ),
        );
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
      ),
    ];
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
                    final wide = constraints.maxWidth >= 980;
                    return Column(
                      children: [
                        _buildTopBar(book),
                        _buildDocumentStrip(book),
                        Expanded(
                          child: Row(
                            children: [
                              if (wide) _buildTableOfContents(),
                              Expanded(child: _buildReaderSurface()),
                            ],
                          ),
                        ),
                        _buildReaderFooter(wide: wide),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  // 필요 변수: 교재 제목, 현재 페이지, 목차 표시 여부. 작동 원리: 진행 상태와 북마크·보기 모드를 한 행에서 제어한다.
  Widget _buildTopBar(BookData? book) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
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
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF3F3F3),
              side: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            icon: const Icon(Icons.close_rounded),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book?.title ?? '교재 보기',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
                Text(
                  '$_currentPage / $_pageTo페이지  ·  ${_formatTime(_elapsedSeconds + _serverElapsedSeconds)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
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
        ],
      ),
    );
  }

  /// 필요한 변수는 교재명과 현재 페이지 북마크 상태다.
  /// 작동 원리는 HTML의 두 번째 문서 스트립에 자료명과 북마크 동작을 분리해 표시하는 것이다.
  Widget _buildDocumentStrip(BookData? book) {
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
          IconButton(
            key: const ValueKey('course-textbook-bookmark'),
            tooltip: _isCurrentPageBookmarked ? '북마크 해제' : '북마크 추가',
            onPressed: _bookmarkBusy ? null : _toggleBookmark,
            icon: Icon(
              _isCurrentPageBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReaderSurface() {
    if (_pages.isEmpty) {
      return const Center(child: Text('표시할 교재 페이지가 없습니다.'));
    }
    return Container(
      color: const Color(0xFFE9E9E7),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: _scrollMode ? _buildScrollReader() : _buildPageReader(),
    );
  }

  // 필요 변수: 페이지 목록과 PageController. 작동 원리: 좌우 페이지 이동 시 위치를 heartbeat에 반영하고 페이지별 필기 캔버스를 유지한다.
  Widget _buildPageReader() {
    return PageView.builder(
      controller: _pageController,
      itemCount: _pages.length,
      onPageChanged: (index) {
        setState(() => _currentPage = _pages[index].number);
        _sendHeartbeat();
      },
      itemBuilder: (context, index) {
        final compact = MediaQuery.sizeOf(context).width < 700;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 360 : 760),
            child: CourseTextbookAnnotationCanvas(
              key: ValueKey(
                'course-textbook-annotation-${_pages[index].number}',
              ),
              storageKey: _annotationStorageKey(_pages[index].number),
              collapseToolbar: compact,
              child: _PaperPage(page: _pages[index]),
            ),
          ),
        );
      },
    );
  }

  // 필요 변수: 페이지 목록. 작동 원리: 세로 읽기에서도 각 종이에 독립 필기 저장 키를 부여한다.
  Widget _buildScrollReader() {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _pages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final page = _pages[index];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: CourseTextbookAnnotationCanvas(
              key: ValueKey('course-textbook-annotation-${page.number}'),
              storageKey: _annotationStorageKey(page.number),
              collapseToolbar: MediaQuery.sizeOf(context).width < 700,
              child: _PaperPage(
                page: page,
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
      width: 240,
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const _PanelTitle(icon: Icons.toc_rounded, title: '목차'),
          const SizedBox(height: 8),
          for (final page in _pages)
            ListTile(
              dense: true,
              selected: page.number == _currentPage,
              selectedTileColor: _mint.withValues(alpha: 0.14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              leading: Text('${page.number}'),
              title: Text(
                page.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                page.chapter,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _jumpToPage(page.number),
            ),
        ],
      ),
    );
  }

  /// 필요한 변수는 현재 페이지 위치·이수율·화면 폭이다.
  /// 작동 원리는 HTML 리더처럼 이전·현재 페이지·다음과 진행 막대·목차를 하단 고정 영역에 배치하는 것이다.
  Widget _buildReaderFooter({required bool wide}) {
    final currentIndex = _pages.indexWhere(
      (page) => page.number == _currentPage,
    );
    final hasPrevious = currentIndex > 0;
    final hasNext = currentIndex >= 0 && currentIndex < _pages.length - 1;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(wide ? 24 : 12, 8, wide ? 24 : 12, 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: hasPrevious
                    ? () => _jumpToPage(_pages[currentIndex - 1].number)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 17),
                label: const Text('이전'),
              ),
              Text(
                '$_currentPage / $_pageTo',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              OutlinedButton(
                onPressed: hasNext
                    ? () => _jumpToPage(_pages[currentIndex + 1].number)
                    : null,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('다음'),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 17),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '학습 시간 ${_formatTime(_elapsedSeconds + _serverElapsedSeconds)}',
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LinearProgressIndicator(
                  value: _completion,
                  minHeight: 4,
                  color: _mint,
                  backgroundColor: Colors.black.withValues(alpha: 0.08),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(_completion * 100).round()}%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: '목차',
                icon: const Icon(Icons.toc_rounded, size: 19),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (_) =>
                      SizedBox(height: 420, child: _buildTableOfContents()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReaderPage {
  const _ReaderPage({
    required this.number,
    required this.chapter,
    required this.title,
    required this.paragraphs,
    this.images = const [],
  });

  final int number;
  final String chapter;
  final String title;
  final List<String> paragraphs;
  final List<String> images;
}

class _PaperPage extends StatelessWidget {
  const _PaperPage({required this.page, this.onVisible});

  final _ReaderPage page;
  final VoidCallback? onVisible;

  @override
  Widget build(BuildContext context) {
    onVisible?.call();
    return AspectRatio(
      aspectRatio: 0.72,
      child: DecoratedBox(
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
          padding: const EdgeInsets.fromLTRB(34, 30, 34, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                page.chapter,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Text(
                page.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansKr(
                  fontSize: 24,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  color: _TeacherCourseTextbookReaderPageState._ink,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final paragraph in page.paragraphs)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ReaderParagraph(text: paragraph),
                        ),
                      for (final image in page.images)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 14),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${page.number}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderParagraph extends StatelessWidget {
  const _ReaderParagraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final words = text.split(RegExp(r'(\s+)')).where((e) => e.isNotEmpty);
    return Wrap(
      spacing: 4,
      runSpacing: 6,
      children: [
        for (final word in words)
          Text(
            word,
            style: GoogleFonts.notoSansKr(
              fontSize: 16,
              height: 1.55,
              color: Colors.black.withValues(alpha: 0.82),
            ),
          ),
      ],
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
