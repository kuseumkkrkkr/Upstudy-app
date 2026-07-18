import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:s11/shared/data/models/content_block.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/ui/components/content_blocks_view.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/sessions/graph_tools/ui/widgets/jsx_graph_embed.dart';

const _readerBg = Color(0xFF0E2A1D);
const _readerGreen = Color(0xFF58C16A);
const _readerPaper = Color(0xFFF7F8F2);

class TeacherTextbookReaderPage extends StatefulWidget {
  const TeacherTextbookReaderPage({
    super.key,
    required this.courseId,
    required this.moduleId,
    required this.textbookId,
    required this.pageFrom,
    required this.pageTo,
    required this.minMinutes,
    this.enforceMinMinutes = false,
  });

  final String courseId;
  final String moduleId;
  final String textbookId;
  final int pageFrom;
  final int pageTo;
  final int minMinutes;
  final bool enforceMinMinutes;

  @override
  State<TeacherTextbookReaderPage> createState() =>
      _TeacherTextbookReaderPageState();
}

class _TeacherTextbookReaderPageState extends State<TeacherTextbookReaderPage> {
  static const _heartbeatSeconds = 8;

  final ValueNotifier<bool> _scrollMode = ValueNotifier<bool>(false);
  final _pageController = PageController();

  bool _loading = true;
  String? _error;

  BookData? _book;
  List<_TextbookSectionPage> _pages = [];
  int _currentPage = 1;
  int _runtimePageFrom = 1;
  int _runtimePageTo = 1;
  bool _enforceMinMinutes = false;
  int _minMinutes = 0;
  int _elapsedSeconds = 0;
  double _completion = 0.0;

  Timer? _heartbeatTimer;
  DateTime? _lastHeartbeatAt;
  DateTime? _startAt;

  String? _selectedWord;
  final Map<String, List<ContentBlock>> _latexCache = {};

  @override
  void initState() {
    super.initState();
    _enforceMinMinutes = widget.enforceMinMinutes;
    _minMinutes = max(0, widget.minMinutes);
    _runtimePageFrom = max(1, widget.pageFrom);
    _runtimePageTo = max(_runtimePageFrom, widget.pageTo);
    _startAt = DateTime.now();
    _initRuntime();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    unawaited(_completeRuntime(reason: 'exit'));
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initRuntime() async {
    try {
      final start = await ApiClient.instance.startCourseTextbookRuntime(
        courseId: widget.courseId,
        moduleId: widget.moduleId,
        textbookId: widget.textbookId,
        pageFrom: widget.pageFrom,
        pageTo: widget.pageTo,
        minMinutes: _minMinutes > 0 ? _minMinutes : null,
        enforceMinMinutes: _enforceMinMinutes,
      );
      await _loadTextbook();
      _applyRuntimePayload(start);

      _heartbeatTimer = Timer.periodic(
        const Duration(seconds: _heartbeatSeconds),
        (_) => unawaited(_heartbeatRuntime()),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetIndex = _toZeroBased(_currentPage);
      if (targetIndex >= 0 &&
          targetIndex < _pages.length &&
          _pageController.hasClients) {
        _pageController.jumpToPage(targetIndex);
      }
    });
  }

  Future<void> _loadTextbook() async {
    final raw = await ApiClient.instance.getCourseTextbook(
      widget.courseId,
      widget.textbookId,
    );
    final book = BookData.fromJson(raw);
    _pages = _flattenBookPages(book);
    final total = max(1, _runtimePageTo - _runtimePageFrom + 1);
    _runtimePageTo = min(_runtimePageFrom + total - 1, _pages.length);
    setState(() {
      _book = book;
    });
  }

  Future<void> _heartbeatRuntime({bool force = false}) async {
    if (_loading || _book == null) return;
    if (_isCooldownActive() && !force) return;
    _lastHeartbeatAt = DateTime.now();

    try {
      final elapsed = _calcElapsedSeconds();
      if (elapsed > 0) _elapsedSeconds = max(_elapsedSeconds, elapsed);
      final runtime = await ApiClient.instance.heartbeatCourseTextbookRuntime(
        courseId: widget.courseId,
        moduleId: widget.moduleId,
        textbookId: widget.textbookId,
        currentPage: _currentPage,
        pageFrom: _runtimePageFrom,
        pageTo: _runtimePageTo,
      );
      _applyRuntimePayload(runtime);
    } catch (_) {
      // silent
    }
  }

  Future<void> _completeRuntime({String reason = 'exit'}) async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (_book == null) return;
    try {
      final runtime = await ApiClient.instance.completeCourseTextbookRuntime(
        courseId: widget.courseId,
        moduleId: widget.moduleId,
        textbookId: widget.textbookId,
        currentPage: _currentPage,
        pageFrom: _runtimePageFrom,
        pageTo: _runtimePageTo,
      );
      _applyRuntimePayload(runtime);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              runtime['passed'] == true
                  ? '??곷땾 鈺곌퀗援??겸뫗?? ${_completionPercent(_completion)}'
                  : '??곷땾?? ${_completionPercent(_completion)} (??る┛)',
            ),
          ),
        );
      }
    } catch (_) {}
  }

  bool _isCooldownActive() {
    final last = _lastHeartbeatAt;
    if (last == null) return false;
    return DateTime.now().difference(last).inSeconds < _heartbeatSeconds;
  }

  Future<bool> _onWillPop() async {
    await _completeRuntime(reason: 'exit');
    return true;
  }

  void _applyRuntimePayload(Map<String, dynamic> runtime) {
    final from = _safeInt(runtime['page_from']);
    final to = _safeInt(runtime['page_to']);
    if (from != null && to != null) {
      _runtimePageFrom = min(from, to);
      _runtimePageTo = max(from, to);
    }

    final progress = runtime['progress'];
    if (progress is Map) {
      final completion = (progress['completion_ratio'] as num?)?.toDouble();
      if (completion != null) _completion = completion;
      _enforceMinMinutes =
          (progress['enforce_min_minutes'] as bool?) ?? _enforceMinMinutes;
      _minMinutes = (progress['required_minutes'] as num?)?.toInt() ?? _minMinutes;
    }

    final current = _safeInt(runtime['current_page']);
    if (current != null) {
      _currentPage = _clampPage(current);
    }
    if (runtime['student_state'] is Map<String, dynamic>) {
      final studentState = runtime['student_state'] as Map<String, dynamic>;
      final textbookStates = studentState['textbook_view'];
      if (textbookStates is Map) {
        dynamic active;
        for (final element in textbookStates.values) {
          if (element is! Map) continue;
          final matchId = element['textbook_id']?.toString();
          if (matchId == widget.textbookId) {
            active = element;
            break;
          }
        }
        if (active is Map) {
          final rawSeconds = active['total_open_seconds'];
          final parsed = _safeInt(rawSeconds);
          if (parsed != null) {
            _elapsedSeconds = max(_elapsedSeconds, parsed);
          }
        }
      }
    }
    if (_pageController.hasClients) {
      final targetIndex = _toZeroBased(_currentPage);
      if (targetIndex >= 0 && targetIndex < _pages.length) {
        _pageController.animateToPage(
          targetIndex,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    }
    if (mounted) setState(() {});
  }

  void _onPageChanged(int index) {
    final newCurrent = _toOneBased(index);
    if (newCurrent == _currentPage) return;
    setState(() {
      _currentPage = newCurrent;
    });
    unawaited(_heartbeatRuntime(force: true));
  }

  Future<void> _toggleMode() async {
    _scrollMode.value = !_scrollMode.value;
    await HapticFeedback.selectionClick();
  }

  void _openWordSheet(String word) {
    if (word.trim().isEmpty) return;
    final key = word.trim().toLowerCase();
    final definition = _wordGlossary[key];
    setState(() {
      _selectedWord = word;
    });
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => _ReaderAuxPanel(
        title: word,
        content: definition ?? '?袁⑹삺 ?대Ŋ??癒?뮉 ????λ선???????類ㅼ벥揶쎛 ?源낆쨯????? ??녿뮸??덈뼄.',
      ),
    );
  }

  Future<void> _openLink(String rawUrl) async {
    final normalized = rawUrl.trim();
    final fixed = normalized.startsWith('http')
        ? normalized
        : 'https://$normalized';
    final uri = Uri.parse(fixed);
    if (!mounted) return;
    setState(() {
      _selectedWord = null;
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('筌띻낱寃뺟몴???????곷뮸??덈뼄.')),
      );
    }
  }

  int? _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse('$value');
  }

  int _toZeroBased(int oneBased) => max(0, min(_pages.length - 1, oneBased - 1));

  int _toOneBased(int zeroBased) => zeroBased + 1;

  int _clampPage(int oneBased) {
    return max(
      _runtimePageFrom,
      min(_runtimePageTo, max(1, oneBased)),
    );
  }

  int _calcElapsedSeconds() {
    final start = _startAt;
    if (start == null) return 0;
    return DateTime.now().difference(start).inSeconds;
  }

  String _completionPercent(double ratio) =>
      '${(ratio.clamp(0.0, 1.0) * 100).round()}%';

  /// ?섏씠吏 ?됰㈃?? sections(援щ쾭?? ???pages(紐낆떆???몄쭛 ?섏씠吏)媛 ?덉쑝硫?洹멸쾬??理쒖슦???ъ슜?쒕떎.
  /// ?꾩슂 蹂?섎뒗 book, index, result?대ŉ, ?묐룞? 梨뺥꽣 ?쒗쉶 ??chapter.pages ?곗꽑 梨꾩슦湲????놁쑝硫??뱀뀡 ?대갚?대떎.
  /// 함수 설명: 교재 본문을 렌더링 가능한 페이지 단위로 평탄화한다.
  /// 작동 원리:
  /// - chapter.pages가 있으면 개념서 명시 지면을 우선 사용한다.
  /// - 없으면 기존 intro/sections 텍스트를 폴백으로 변환한다.
  List<_TextbookSectionPage> _flattenBookPages(BookData book) {
    final result = <_TextbookSectionPage>[];
    var index = 1;
    for (final chapter in book.chapters) {
      if (chapter.pages.isNotEmpty) {
        for (final page in chapter.pages) {
          result.add(
            _TextbookSectionPage(
              index: index++,
              title: page.title,
              body: '',
              chapterTitle: chapter.title,
              editorialPage: page,
            ),
          );
        }
        continue;
      }
      final introTitle = "${chapter.title} (개요)";
      result.add(
        _TextbookSectionPage(
          index: index++,
          title: introTitle,
          body: chapter.intro.isEmpty
              ? '내용이 비어 있습니다.'
              : chapter.intro.join("\\n"),
          chapterTitle: chapter.title,
        ),
      );
      for (final section in chapter.sections) {
        final paragraphBody = section.paragraphs.isEmpty
            ? '내용이 비어 있습니다.'
            : section.paragraphs.join("\\n\\n");
        result.add(
          _TextbookSectionPage(
            index: index++,
            title: section.title.isEmpty ? chapter.title : section.title,
            body: paragraphBody,
            chapterTitle: chapter.title,
          ),
        );
      }
    }
    if (result.isEmpty) {
      result.add(
        _TextbookSectionPage(
          index: 1,
          title: book.title,
          body: book.subtitle.isNotEmpty
              ? book.subtitle
              : '내용이 비어 있습니다.',
          chapterTitle: book.title,
        ),
      );
    }
    return result;
  }
  Widget _buildPageBody(_TextbookSectionPage page) {
    final editorialPage = page.editorialPage;
    if (editorialPage != null) {
      return _buildEditorialPageContent(editorialPage);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            page.title,
            style: GoogleFonts.notoSerif(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            _buildNumberLabel(page.index),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 14),
          ..._buildParagraphs(page.body),
        ],
      ),
    );
  }

  Widget _buildEditorialPageContent(BookPage page) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (page.kicker.isNotEmpty) ...[
          Text(
            page.kicker,
            style: const TextStyle(
              color: Color(0xFF2D6B4F),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Icon(_bookPageTemplateIcon(page.template), size: 14),
            const SizedBox(width: 7),
            Text(
              _bookPageTemplateLabel(page.template),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF406A58),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          page.title,
          style: GoogleFonts.notoSerif(
            fontSize: 30,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF183027),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _buildEditorialBlocks(page),
        ),
      ],
    );
  }

  Widget _buildEditorialBlocks(BookPage page) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (page.blocks.isEmpty)
          const Text('지면 블록이 비어 있습니다.', style: TextStyle(fontSize: 14)),
        for (var i = 0; i < page.blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _TextbookContentBlockView(
            block: page.blocks[i],
            buildParagraph: _buildLatexAware,
          ),
        ],
      ],
    );
  }
  String _buildNumberLabel(int index) {
    final clipped = index.clamp(_runtimePageFrom, _runtimePageTo);
    return '페이지 $clipped / $_runtimePageFrom~$_runtimePageTo';
  }

  List<Widget> _buildParagraphs(String text) {
    return text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Text.rich(
              _buildTextSpan(line),
              style: GoogleFonts.inter(
                fontSize: 16,
                height: 1.72,
                color: const Color(0xFF101820),
              ),
            ),
          ),
        )
        .toList();
  }

  InlineSpan _buildTextSpan(String text) {
    final nodes = <InlineSpan>[];
    final tokens = text.split(RegExp(r'(\s+)'));
    for (final token in tokens) {
      if (token.isEmpty) continue;
      if (_isUrl(token)) {
        nodes.add(
          TextSpan(
            text: token,
            style: const TextStyle(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => unawaited(_openLink(token)),
          ),
        );
      } else if (token.trim().isNotEmpty) {
        final wordOnly = _normalizeWord(token);
        nodes.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () => _openWordSheet(wordOnly),
              child: Text(
                token,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          ),
        );
      } else {
        nodes.add(TextSpan(text: token));
      }
    }
    return TextSpan(children: nodes);
  }

  bool _isUrl(String token) {
    final trimmed = token.trim();
    return trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('www.');
  }

  String _normalizeWord(String text) {
    return text
        .replaceAll(RegExp(r'^[\[\(\{\"\'`<]+'), '')
        .replaceAll(RegExp(r'[\]\\)\"\'.,!?:;>]+$'), '')
        .trim();
  }

  IconData _bookPageTemplateIcon(BookPageTemplate template) => switch (template) {
        BookPageTemplate.opening => Icons.play_circle_outline_rounded,
        BookPageTemplate.concept => Icons.lightbulb_outline_rounded,
        BookPageTemplate.principle => Icons.auto_awesome_rounded,
        BookPageTemplate.experiment => Icons.science_outlined,
        BookPageTemplate.example => Icons.edit_note_rounded,
        BookPageTemplate.solution => Icons.fact_check_outlined,
        BookPageTemplate.practice => Icons.assignment_turned_in_rounded,
        BookPageTemplate.summary => Icons.summarize_rounded,
      };

  String _bookPageTemplateLabel(BookPageTemplate template) => switch (template) {
        BookPageTemplate.opening => '도입',
        BookPageTemplate.concept => '개념',
        BookPageTemplate.principle => '원리',
        BookPageTemplate.experiment => '실험',
        BookPageTemplate.example => '예제 1',
        BookPageTemplate.solution => '예제 2',
        BookPageTemplate.practice => '연습',
        BookPageTemplate.summary => '정리',
      };

  Widget _buildLatexAware(String text) {
    final cacheKey = text.trim();
    if (cacheKey.isEmpty) return const SizedBox.shrink();
    final blocks = _latexCache.putIfAbsent(
      cacheKey,
      () => parseTextWithLatex(cacheKey),
    );
    return ContentBlocksView(
      blocks: blocks,
      textStyle: GoogleFonts.inter(
        fontSize: 16,
        height: 1.72,
        color: const Color(0xFF101820),
      ),
      latexStyle: const TextStyle(
        fontSize: 17,
        color: Color(0xFF101820),
        fontWeight: FontWeight.w600,
      ),
      spacing: 2,
    );
  }

  Widget _buildWideChrome() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _readerBg,
        foregroundColor: Colors.white,
        title: Text(_book?.title ?? ''),
        actions: [
          IconButton(
            onPressed: _toggleMode,
            icon: ValueListenableBuilder<bool>(
              valueListenable: _scrollMode,
              builder: (_, value, __) => Icon(
                value ? Icons.auto_stories : Icons.picture_as_pdf,
                color: Colors.white,
              ),
            ),
            tooltip: '癰귣떯由?筌뤴뫀諭?癰궰野?,
          ),
          IconButton(
            onPressed: () => unawaited(_completeRuntime(reason: 'manual')),
            icon: const Icon(Icons.check_circle_outline),
            tooltip: '??덈뮸 ?ル굝利?,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ProgressHeader(
              bookTitle: _book?.title ?? '',
              currentPage: _currentPage,
              from: _runtimePageFrom,
              to: _runtimePageTo,
              completion: _completion,
              elapsedSeconds: _elapsedSeconds,
              minMinutes: _minMinutes,
              enforceMinMinutes: _enforceMinMinutes,
            ),
            Expanded(
              child: Row(
                children: [
                  _TableOfContents(
                    pages: _pages,
                    currentIndex: _toZeroBased(_currentPage),
                    onSelect: (idx) {
                      setState(() {
                        _currentPage = _toOneBased(idx);
                      });
                      _pageController.animateToPage(
                        idx,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                      );
                    },
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _scrollMode,
                      builder: (_, isScroll, __) {
                        if (isScroll) {
                          return _buildScrollViewer();
                        }
                        return _buildPageViewer();
                      },
                    ),
                  ),
                  _ReaderRightRail(
                    textbookTitle: _book?.title ?? '',
                    minMinutes: _minMinutes,
                    enforceMinMinutes: _enforceMinMinutes,
                    completion: _completion,
                    elapsedSeconds: _elapsedSeconds,
                    links: _extractLinksFromCurrentPage(),
                    selectedWord: _selectedWord,
                    onOpenLink: _openLink,
                    onClearSelection: () {
                      setState(() {
                        _selectedWord = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _extractLinksFromCurrentPage() {
    if (_pages.isEmpty) return const [];
    final idx = _toZeroBased(_currentPage);
    if (idx < 0 || idx >= _pages.length) return const [];
    final page = _pages[idx];
    final candidates = <String>[...page.body.split(RegExp(r'\s+'))];
    final editorialPage = page.editorialPage;
    if (editorialPage != null) {
      for (final block in editorialPage.blocks) {
        if (block.title.isNotEmpty) {
          candidates.addAll(block.title.split(RegExp(r'\s+')));
        }
        if (block.text.isNotEmpty) {
          candidates.addAll(block.text.split(RegExp(r'\s+')));
        }
        if (block.formula.isNotEmpty) {
          candidates.add(block.formula);
        }
        for (final item in block.items) {
          candidates.addAll(item.split(RegExp(r'\s+')));
        }
      }
    }
    return candidates.where(_isUrl).toList(growable: false);
  }

  Widget _buildPageViewer() {
    return Container(
      color: _readerPaper,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _pages.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (_, index) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Card(
              elevation: 5,
              color: Colors.white,
              child: _buildPageBody(_pages[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScrollViewer() {
    return Container(
      color: _readerPaper,
      child: ListView.builder(
        itemCount: _pages.length,
        itemBuilder: (_, index) {
          final page = _pages[index];
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Card(
              elevation: 2,
              child: Container(
                color: Colors.white,
                child: _buildPageBody(page),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _readerBg,
        body: Center(child: CircularProgressIndicator(color: _readerGreen)),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: _readerBg,
          foregroundColor: Colors.white,
          title: const Text('?대Ŋ????????쎈솭'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 960;
    return WillPopScope(
      onWillPop: _onWillPop,
      child: isWide
          ? _buildWideChrome()
          : Scaffold(
              backgroundColor: _readerPaper,
              appBar: AppBar(
                backgroundColor: _readerBg,
                foregroundColor: Colors.white,
                title: Text(_book?.title ?? ''),
                actions: [
                  IconButton(
                    onPressed: _toggleMode,
                    icon: ValueListenableBuilder<bool>(
                      valueListenable: _scrollMode,
                      builder: (_, value, __) => Icon(
                        value ? Icons.auto_stories : Icons.picture_as_pdf,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.info_outline),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'toc',
                        child: Text('筌뤴뫗媛???猷?),
                      ),
                      const PopupMenuItem(
                        value: 'condition',
                        child: Text('筌욊쑵六?鈺곌퀗援?癰귣떯由?),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'toc') {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          showDragHandle: true,
                          builder: (_) => _MobileTocSheet(
                            pages: _pages,
                            currentIndex: _toZeroBased(_currentPage),
                            onSelect: (index) {
                              setState(() {
                                _currentPage = _toOneBased(index);
                                Navigator.pop(context);
                              });
                              _pageController.jumpToPage(index);
                            },
                          ),
                        );
                      } else if (value == 'condition') {
                        showModalBottomSheet(
                          context: context,
                          showDragHandle: true,
                          builder: (_) => _ReaderAuxPanel(
                            title: '筌욊쑵六?鈺곌퀗援?,
                            content:
                                '甕곕뗄?? $_runtimePageFrom ~ $_runtimePageTo\n'
                                '筌ㅼ뮇???덈뮸??볦퍢: ${_minMinutes <= 0 ? '??곸벉' : '$_minMinutes??}\n'
                                '筌욊쑵六양몴? ${_completionPercent(_completion)}',
                          ),
                        );
                      }
                    },
                  ),
                  IconButton(
                    onPressed: () => unawaited(_completeRuntime(reason: 'manual')),
                    icon: const Icon(Icons.check_circle),
                  ),
                ],
              ),
              body: SafeArea(
                child: Column(
                  children: [
                    _ProgressHeader(
                      bookTitle: _book?.title ?? '',
                      currentPage: _currentPage,
                      from: _runtimePageFrom,
                      to: _runtimePageTo,
                      completion: _completion,
                      elapsedSeconds: _elapsedSeconds,
                      minMinutes: _minMinutes,
                      enforceMinMinutes: _enforceMinMinutes,
                    ),
                    Expanded(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _scrollMode,
                        builder: (_, isScroll, __) =>
                            isScroll ? _buildScrollViewer() : _buildPageViewer(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.bookTitle,
    required this.currentPage,
    required this.from,
    required this.to,
    required this.completion,
    required this.elapsedSeconds,
    required this.minMinutes,
    required this.enforceMinMinutes,
  });

  final String bookTitle;
  final int currentPage;
  final int from;
  final int to;
  final double completion;
  final int elapsedSeconds;
  final int minMinutes;
  final bool enforceMinMinutes;

  @override
  Widget build(BuildContext context) {
    final total = max(1, to - from + 1);
    final minSeconds = max(0, minMinutes * 60);
    final timeLabel = '$elapsedSeconds??/ ${minSeconds == 0 ? '??쀫립 ??곸벉' : '${minSeconds}??}';
    final pageRatio = ((currentPage - from + 1) / total).clamp(0.0, 1.0);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bookTitle,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: completion,
                  color: _readerGreen,
                  backgroundColor: Colors.grey[300],
                  minHeight: 8,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(completion * 100).round()}%',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _MiniBadge(
                icon: Icons.menu_book_rounded,
                text: '?袁⑹삺 ${max(from, min(to, currentPage))} / $to',
              ),
              _MiniBadge(
                icon: Icons.timeline,
                text: '甕곕뗄??筌욊쑵六?${((pageRatio).clamp(0.0, 1.0) * 100).round()}%',
              ),
              _MiniBadge(
                icon: Icons.timer,
                text: '?????볦퍢 $timeLabel',
              ),
              if (enforceMinMinutes && minMinutes > 0)
                _MiniBadge(
                  icon: Icons.lock_clock,
                  text: '筌ㅼ뮇???볦퍢 ${minMinutes}??,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3EE),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black87),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _TableOfContents extends StatelessWidget {
  const _TableOfContents({
    required this.pages,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<_TextbookSectionPage> pages;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF2F4F0),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.list_alt, size: 16),
                const SizedBox(width: 8),
                Text(
                  '筌뤴뫗媛?,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: pages.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final page = pages[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    '${page.chapterTitle} 夷?${page.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  selected: index == currentIndex,
                  onTap: () => onSelect(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderRightRail extends StatelessWidget {
  const _ReaderRightRail({
    required this.textbookTitle,
    required this.minMinutes,
    required this.enforceMinMinutes,
    required this.completion,
    required this.elapsedSeconds,
    required this.links,
    required this.selectedWord,
    required this.onOpenLink,
    required this.onClearSelection,
  });

  final String textbookTitle;
  final int minMinutes;
  final bool enforceMinMinutes;
  final double completion;
  final int elapsedSeconds;
  final List<String> links;
  final String? selectedWord;
  final Future<void> Function(String) onOpenLink;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context) {
    final completionPercent = '${(completion * 100).round()}%';
    return SizedBox(
      width: 280,
      child: Container(
        color: const Color(0xFFF8FAF2),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              textbookTitle,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Text(
              '筌욊쑵六?鈺곌퀗援?,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('筌ㅼ뮇????볦퍢: ${minMinutes <= 0 ? '??곸벉' : '$minMinutes??}'),
            Text('揶쏅벡???怨몄뒠: ${enforceMinMinutes ? '?? : '?袁⑤빍??}'),
            Text('??곷땾?? $completionPercent'),
            const SizedBox(height: 16),
            if (selectedWord != null) ...[
              Text(
                '??λ선',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  _wordGlossary[selectedWord!.trim().toLowerCase()] ??
                      '?醫뤾문????λ선 ??살구???源낆쨯??? ??녿릭??щ빍??',
                  style: GoogleFonts.inter(fontSize: 12, height: 1.5),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onClearSelection,
                  child: const Text('??る┛'),
                ),
              ),
            ] else
              const SizedBox.shrink(),
            const SizedBox(height: 12),
            Text(
              '?대Ŋ??筌띻낱寃?,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: links.isEmpty
                  ? const Text(
                      '?袁⑹삺 ??륁뵠筌왖??筌띻낱寃뺝첎? ??곷뮸??덈뼄.',
                      style: TextStyle(fontSize: 12),
                    )
                  : ListView.separated(
                      itemCount: links.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final link = links[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            link,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          leading: const Icon(Icons.link, size: 14),
                          onTap: () => onOpenLink(link),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderAuxPanel extends StatelessWidget {
  const _ReaderAuxPanel({required this.title, required this.content});
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(content, style: GoogleFonts.inter(height: 1.45)),
        ],
      ),
    );
  }
}

class _MobileTocSheet extends StatelessWidget {
  const _MobileTocSheet({
    required this.pages,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<_TextbookSectionPage> pages;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Text('筌뤴뫗媛?, style: TextStyle(fontWeight: FontWeight.w700)),
          const Divider(),
          Expanded(
            child: ListView.separated(
              itemCount: pages.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final page = pages[index];
                return ListTile(
                  dense: true,
                  selected: currentIndex == index,
                  title: Text(
                    '${page.chapterTitle} 夷?${page.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onSelect(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TextbookContentBlockView extends StatelessWidget {
  const _TextbookContentBlockView({
    required this.block,
    required this.buildParagraph,
  });

  final BookContentBlock block;
  final Widget Function(String text) buildParagraph;

  @override
  Widget build(BuildContext context) {
    if (block.type == BookContentBlockType.graph && block.graph != null) {
      return _TextbookGraphCard(document: block.graph!);
    }
    if (block.type == BookContentBlockType.visual && block.visual != null) {
      return _BookVisualCard(visual: block.visual!);
    }
    if (block.type == BookContentBlockType.formula) {
      return _formulaCard();
    }

    final palette = _paletteFor(block.type);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: palette.$1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.$3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (block.title.isNotEmpty) ...[
            Row(
              children: [
                Icon(_iconFor(block.type), size: 14, color: palette.$2),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    block.title,
                    style: TextStyle(
                      color: palette.$2,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (block.text.isNotEmpty) buildParagraph(block.text),
          if (block.items.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < block.items.length; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 19,
                          height: 19,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: palette.$2.withValues(alpha: .1),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: palette.$2,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: buildParagraph(block.items[i])),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _formulaCard() {
    final content = block.formula.isEmpty ? block.text : block.formula;
    final blocks = parseTextWithLatex(r'$' + content + r'$');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F1),
        border: const Border(
          left: BorderSide(color: Color(0xFF1B402B), width: 3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (block.title.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                block.title,
                style: const TextStyle(
                  color: Color(0xFF557060),
                  fontSize: 10,
                  letterSpacing: .4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if (block.title.isNotEmpty) const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: ContentBlocksView(
              inline: false,
              blocks: blocks,
              latexStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (block.text.isNotEmpty && block.formula.isNotEmpty) ...[
            const SizedBox(height: 4),
            buildParagraph(block.text),
          ],
        ],
      ),
    );
  }

  (Color, Color, Color) _paletteFor(BookContentBlockType type) => switch (type) {
    BookContentBlockType.question => (
      const Color(0xFFF5F3EC),
      const Color(0xFF745B18),
      const Color(0x22745B18),
    ),
    BookContentBlockType.hint || BookContentBlockType.thinking => (
      const Color(0xFFF1F5F8),
      const Color(0xFF38627A),
      const Color(0x2238627A),
    ),
    BookContentBlockType.answer || BookContentBlockType.verification => (
      const Color(0xFFF0F7F2),
      const Color(0xFF276544),
      const Color(0x22276544),
    ),
    BookContentBlockType.misconception => (
      const Color(0xFFFFF3F1),
      const Color(0xFFA24738),
      const Color(0x22A24738),
    ),
    _ => (
      const Color(0xFFF7F9F6),
      const Color(0xFF1B5A3B),
      const Color(0x221B5A3B),
    ),
  };

  IconData _iconFor(BookContentBlockType type) => switch (type) {
    BookContentBlockType.question => Icons.help_outline_rounded,
    BookContentBlockType.thinking => Icons.lightbulb_outline_rounded,
    BookContentBlockType.solutionStep ||
    BookContentBlockType.derivation => Icons.format_list_numbered_rounded,
    BookContentBlockType.verification => Icons.fact_check_outlined,
    BookContentBlockType.hint => Icons.tips_and_updates_outlined,
    BookContentBlockType.answer => Icons.check_circle_outline_rounded,
    BookContentBlockType.misconception => Icons.warning_amber_rounded,
    BookContentBlockType.definition => Icons.menu_book_outlined,
    _ => Icons.auto_awesome_outlined,
  };
}

class _TextbookGraphCard extends StatelessWidget {
  const _TextbookGraphCard({required this.document});

  final AiFlowGraphDocument document;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return Container(
      height: compact ? 225 : 286,
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x22345D43)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
            decoration: const BoxDecoration(
              color: Color(0xFFEAF3EC),
              border: Border(bottom: BorderSide(color: Color(0x22345D43))),
            ),
            child: const Row(
              children: [
                Icon(Icons.tune_rounded, size: 15, color: Color(0xFF1B402B)),
                SizedBox(width: 7),
                Text(
                  'INTERACTIVE FIGURE',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B402B),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '슬라이더를 조정해 원리를 직접 탐색해요.',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Color(0xFF557060)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: buildJsxGraphEmbed(document)),
        ],
      ),
    );
  }
}

class _BookVisualCard extends StatelessWidget {
  const _BookVisualCard({required this.visual});

  final BookVisual visual;

  @override
  Widget build(BuildContext context) {
    final visualWidget = switch (visual.kind) {
      'formula' => _buildFormula(),
      'table' || 'signChart' => _buildTable(),
      'steps' || 'flow' => _buildSequence(),
      'image' => _buildImage(),
      _ => _buildCallout(),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF7),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFF3DBE68), width: 3),
          top: BorderSide(color: Color(0x1A1B402B)),
          right: BorderSide(color: Color(0x1A1B402B)),
          bottom: BorderSide(color: Color(0x1A1B402B)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  visual.title,
                  style: const TextStyle(
                    color: Color(0xFF1B402B),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                visual.kind.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF789080),
                  fontSize: 9,
                  letterSpacing: .7,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          visualWidget,
          if (visual.caption.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              visual.caption,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormula() {
    if (visual.formula.trim().isEmpty) {
      return _buildCallout();
    }
    final nodes = parseTextWithLatex(r'$' + visual.formula + r'$');
    return ContentBlocksView(
      inline: false,
      blocks: nodes,
      latexStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1B402B),
      ),
    );
  }

  Widget _buildTable() {
    if (visual.rows.isEmpty && visual.items.isEmpty) {
      return _buildCallout();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in visual.rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (final cell in row)
                  Expanded(
                    child: Text(
                      cell,
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        if (visual.items.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in visual.items)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '• $item',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildSequence() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < visual.items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1B5A3B),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(visual.items[i], style: const TextStyle(fontSize: 12))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildImage() {
    if (visual.imageSource.isEmpty) {
      return const Text('이미지 데이터가 없습니다.', style: TextStyle(fontSize: 12));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        visual.imageSource,
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Text(
          '이미지를 불러오지 못했습니다.',
          style: TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildCallout() {
    if (visual.formula.isNotEmpty) return _buildFormula();
    if (visual.items.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in visual.items) Text(item, style: const TextStyle(fontSize: 12)),
        ],
      );
    }
    return Text(
      visual.formula.isNotEmpty ? visual.formula : '그래프 보조 정보를 확인해 보세요.',
      style: const TextStyle(fontSize: 12),
    );
  }
}

class _TextbookSectionPage {
  _TextbookSectionPage({
    required this.index,
    required this.title,
    required this.body,
    required this.chapterTitle,
    this.editorialPage,
  });

  final int index;
  final String title;
  final String body;
  final String chapterTitle;
  final BookPage? editorialPage;
}

const _wordGlossary = <String, String>{
  '??λ땾': '??낆젾 揶쏅???獄쏆룇釉??곗뮆??揶쏅????④쑴沅????????묐린??域뱀뮇???癒?뮉 ?袁⑥쨮域밸챶???닌딄쉐 ?遺용꺖??낅빍??',
  '癰궰??: '揶쏅??????館釉????已??곗쨮 ?紐꾪뀱??롫뮉 ??묐린/?袁⑥쨮域밸챶?믦쳸?우벥 疫꿸퀣????μ맄??낅빍??',
  '沃섎챶??: '癰궰?遺우몛???④쑴沅??롫뮉 沃섎챷?삯겫??怨쀪텦??곗쨮 ??볦퍢 癰궰?遺우벥 疫꿸퀣?길묾怨? ?????낅빍??',
  '?怨룻뀋': '筌롫똻???癒?뮉 ?袁⑹읅??깆뱽 ????????④쑴沅??곗쨮, ??λ땾??沃섎챶???椰꾧퀗?嚥??紐껊뮉 ?怨쀪텦??낅빍??',
  '?類ㅼ벥': '??밸선???類μ넇??????? 甕곕뗄?욅몴????????疫꿸퀣?????살구??낅빍??',
  '?대Ŋ??: '??덈뮸????곸뒠???類ｂ봺?????닌듼?遺얜쭆 ??용뮞???닌딄쉐 ?얜챷苑??낅빍??',
};


