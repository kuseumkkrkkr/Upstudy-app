import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:s11/services/bookmark_store.dart';

Future<T?> showBookLibraryModal<T>({required BuildContext context}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (context) {
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
            const Center(child: BookLibraryModal()),
          ],
        ),
      );
    },
  );
}

class BookWidget extends StatefulWidget {
  const BookWidget({super.key, this.book, this.initialEntryIndex});

  final BookData? book;
  final int? initialEntryIndex;

  static String routeName = 'book';
  static String routePath = '/book';

  @override
  State<BookWidget> createState() => _BookWidgetState();
}

class BookLibraryPage extends StatelessWidget {
  const BookLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1B402B);
    const bg = Color(0xFFF8F8F8);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 80,
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF3B3B3B)),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  Text(
                    'AIFlow',
                    style: TextStyle(
                      color: primary,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: _BookLibraryBody(
                onSelect: (book) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => BookWidget(book: book)),
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


class BookLibraryModal extends StatelessWidget {
  const BookLibraryModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1000,
      height: 650,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: IconButton(
                  icon: const Icon(Icons.close, size: 26),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const Text(
                '교재보기',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: _BookLibraryBody(
              onSelect: (book) {
                final navigator = Navigator.of(context, rootNavigator: true);
                navigator.pop();
                navigator.push(
                  MaterialPageRoute(builder: (_) => BookWidget(book: book)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BookLibraryBody extends StatelessWidget {
  const _BookLibraryBody({required this.onSelect});

  final ValueChanged<BookData> onSelect;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1B402B);
    const primaryLight = Color(0xFF45BF63);
    const border = Color(0xFFE0E3E7);
    const shadow = BoxShadow(
      blurRadius: 4,
      color: Color(0x22000000),
      offset: Offset(0, 2),
    );
    final books = _libraryBooks;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Owned Books',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Text(
                '${books.length} items',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: books.isEmpty
              ? const Center(
                  child: Text(
                    'No books available.',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    final book = books[index];
                    final progress = book.progress.clamp(0.0, 1.0) as double;
                    final label = book.progressLabel.isNotEmpty
                        ? book.progressLabel
                        : '${(progress * 100).round()}% complete';
                    return InkWell(
                      onTap: () => onSelect(book),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border, width: 1),
                          boxShadow: const [shadow],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 58,
                              height: 74,
                              decoration: BoxDecoration(
                                color: book.coverColor ?? primaryLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.menu_book,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    book.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    book.subtitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 6,
                                      backgroundColor: const Color(0xFFE8E8E8),
                                      color: primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    label,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.black26,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class BookmarkListPage extends StatefulWidget {
  const BookmarkListPage({super.key});

  @override
  State<BookmarkListPage> createState() => _BookmarkListPageState();
}

class _BookmarkListPageState extends State<BookmarkListPage> {
  late Future<List<BookmarkItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = BookmarkStore.load();
  }

  Future<void> _refresh() async {
    final items = await BookmarkStore.load();
    if (!mounted) return;
    setState(() => _future = Future.value(items));
  }

  BookData? _findBook(String id) {
    for (final book in _libraryBooks) {
      if (book.id == id) return book;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1B402B);
    const bg = Color(0xFFF8F8F8);
    const border = Color(0xFFE0E3E7);
    const shadow = BoxShadow(
      blurRadius: 4,
      color: Color(0x22000000),
      offset: Offset(0, 2),
    );

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 80,
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF3B3B3B)),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  Text(
                    'Bookmarks',
                    style: TextStyle(
                      color: primary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<BookmarkItem>>(
                future: _future,
                builder: (context, snapshot) {
                  final items = [...(snapshot.data ?? const [])]
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        'No bookmarks yet.',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final book = _findBook(item.bookId);
                        final title = book?.title ?? item.bookTitle;
                        return InkWell(
                          onTap: book == null
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => BookWidget(
                                        book: book,
                                        initialEntryIndex: item.entryIndex,
                                      ),
                                    ),
                                  );
                                },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: border, width: 1),
                              boxShadow: const [shadow],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: book?.coverColor ?? primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.bookmark,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.entryTitle,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.black26,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
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

enum _ToolMode { none, pen, highlighter, eraser }

class _BookWidgetState extends State<BookWidget> {
  static const Color kPrimary = Color(0xFF1B402B);
  static const Color kPrimaryLight = Color(0xFF45BF63);
  static const Color kBg = Color(0xFFF8F8F8);
  static const Color kBorder = Color(0xFFE0E3E7);

  static const double _eraserRadius = 24;
  static const double _minPointDistance = 1.2;

  final ScrollController _tocController = ScrollController();
  final ScrollController _contentController = ScrollController();
  final GlobalKey _contentKey = GlobalKey();
  final ValueNotifier<int> _paintVersion = ValueNotifier<int>(0);

  List<BookChapter> _chapters = const [];
  List<_ContentEntry> _contentEntries = const [];
  List<GlobalKey> _sectionKeys = const [];
  List<bool> _chapterExpanded = const [];
  bool _initialized = false;
  bool _contentListenerAttached = false;
  String _currentBookId = '';
  String _currentBookTitle = '';
  int? _pendingInitialEntryIndex;
  List<BookmarkItem> _bookmarks = <BookmarkItem>[];

  List<double> _sectionOffsets = <double>[];
  int _activeEntryIndex = 0;

  _ToolMode _toolMode = _ToolMode.none;
  Color _penColor = Colors.black;
  Color _highlighterColor = const Color(0xFFFFF59D);
  double _penWidth = 3;
  double _highlighterWidth = 14;

  final List<_Stroke> _strokes = <_Stroke>[];
  _Stroke? _currentStroke;
  int? _activePointer;
  Offset? _eraserPosition;
  Offset? _highlighterStart;

  @override
  void initState() {
    super.initState();
    _initializeIfNeeded(attachListeners: true);
    _loadBookmarks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cacheSectionOffsets());
  }

  @override
  void didUpdateWidget(covariant BookWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bookChanged = widget.book != oldWidget.book;
    final entryChanged =
        widget.initialEntryIndex != oldWidget.initialEntryIndex;
    if (bookChanged || entryChanged) {
      _initialized = false;
      _sectionOffsets = <double>[];
      _activeEntryIndex = 0;
      _strokes.clear();
      _currentStroke = null;
      _eraserPosition = null;
      _highlighterStart = null;
      _pendingInitialEntryIndex = widget.initialEntryIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _contentController.jumpTo(0);
        _initializeIfNeeded();
      });
      _loadBookmarks();
    }
  }

  @override
  void dispose() {
    _tocController.dispose();
    _contentController.dispose();
    _paintVersion.dispose();
    super.dispose();
  }

  bool get _isDrawingTool => _toolMode != _ToolMode.none;

  Color get _activeInkColor =>
      _toolMode == _ToolMode.highlighter ? _highlighterColor : _penColor;

  void _bumpPaint() {
    _paintVersion.value = _paintVersion.value + 1;
  }

  void _setToolMode(_ToolMode mode) {
    setState(() => _toolMode = _toolMode == mode ? _ToolMode.none : mode);
  }

  void _initializeIfNeeded({bool attachListeners = false}) {
    if (!_initialized) {
      final book = widget.book ?? _libraryBooks.first;
      _currentBookId = book.id;
      _currentBookTitle = book.title;
      _chapters = book.chapters;
      _contentEntries = _buildContentEntries(_chapters);
      _sectionKeys = List<GlobalKey>.generate(
        _contentEntries.length,
        (_) => GlobalKey(),
      );
      _chapterExpanded = List<bool>.filled(_chapters.length, true);
      _pendingInitialEntryIndex ??= widget.initialEntryIndex;
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cacheSectionOffsets();
        _applyInitialScroll();
      });
    }
    if (attachListeners && !_contentListenerAttached) {
      _contentController.addListener(_handleContentScroll);
      _contentListenerAttached = true;
    }
  }

  void _cacheSectionOffsets() {
    final contentBox =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (contentBox == null) return;

    final offsets = <double>[];
    var missing = false;
    for (final key in _sectionKeys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) {
        missing = true;
        offsets.add(0);
        continue;
      }
      final position = box.localToGlobal(Offset.zero, ancestor: contentBox);
      offsets.add(position.dy);
    }

    if (missing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _cacheSectionOffsets());
      return;
    }

    _sectionOffsets = offsets;
    _updateActiveEntry();
  }

  void _applyInitialScroll() {
    final target = _pendingInitialEntryIndex;
    if (target == null) return;
    if (target < 0 || target >= _contentEntries.length) {
      _pendingInitialEntryIndex = null;
      return;
    }
    _pendingInitialEntryIndex = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToEntry(target);
    });
  }

  Future<void> _loadBookmarks() async {
    final items = await BookmarkStore.load();
    if (!mounted) return;
    setState(() => _bookmarks = items);
  }

  bool _isBookmarked(int entryIndex) {
    return _bookmarks.any(
      (item) => item.bookId == _currentBookId && item.entryIndex == entryIndex,
    );
  }

  Future<void> _handleAddBookmark() async {
    if (_contentEntries.isEmpty) return;
    final entry = _contentEntries[_activeEntryIndex];
    final now = DateTime.now().microsecondsSinceEpoch;
    final item = BookmarkItem(
      id: now.toString(),
      bookId: _currentBookId,
      bookTitle: _currentBookTitle,
      entryIndex: _activeEntryIndex,
      entryTitle: entry.title,
      createdAt: now,
    );
    final updated = await BookmarkStore.add(item);
    if (!mounted) return;
    setState(() => _bookmarks = updated);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BookmarkListPage()),
    );
  }

  void _handleContentScroll() {
    if (_sectionOffsets.isEmpty) return;
    _updateActiveEntry();
  }

  void _updateActiveEntry() {
    if (_sectionOffsets.isEmpty) return;
    final offset = _contentController.offset + 12;
    var index = 0;
    for (var i = 0; i < _sectionOffsets.length; i++) {
      if (_sectionOffsets[i] <= offset) {
        index = i;
      } else {
        break;
      }
    }

    if (index == _activeEntryIndex) return;
    setState(() {
      _activeEntryIndex = index;
      final chapterIndex = _contentEntries[index].chapterIndex;
      if (!_chapterExpanded[chapterIndex]) {
        _chapterExpanded[chapterIndex] = true;
      }
    });
  }

  Future<void> _scrollToEntry(int entryIndex) async {
    final context = _sectionKeys[entryIndex].currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      alignment: 0.1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _toggleChapter(int chapterIndex) {
    setState(() {
      _chapterExpanded[chapterIndex] = !_chapterExpanded[chapterIndex];
    });
  }

  void _handleTocTap(_TocEntry entry) {
    if (entry.level == 0 && entry.hasChildren) {
      _toggleChapter(entry.chapterIndex);
    }
    _scrollToEntry(entry.entryIndex);
  }

  void _goToPreviousEntry() {
    if (_activeEntryIndex <= 0) return;
    _scrollToEntry(_activeEntryIndex - 1);
  }

  void _goToNextEntry() {
    if (_activeEntryIndex >= _contentEntries.length - 1) return;
    _scrollToEntry(_activeEntryIndex + 1);
  }

  Future<void> _openSearch() async {
    if (_contentEntries.isEmpty) return;
    final controller = TextEditingController();
    var results = <_SearchResult>[];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void runSearch(String value) {
              final query = value.trim();
              setState(() {
                results = query.isEmpty ? [] : _runSearch(query);
              });
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SizedBox(
                height: 420,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Search in Book',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'Type keyword',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: runSearch,
                      onSubmitted: runSearch,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: results.isEmpty
                          ? const Center(
                              child: Text(
                                'No results.',
                                style: TextStyle(color: Colors.black54),
                              ),
                            )
                          : ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (context, index) {
                                final result = results[index];
                                return ListTile(
                                  title: Text(
                                    result.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    result.snippet,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      _scrollToEntry(result.entryIndex);
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<_SearchResult> _runSearch(String query) {
    final keyword = query.toLowerCase();
    final results = <_SearchResult>[];
    for (var i = 0; i < _contentEntries.length; i++) {
      final entry = _contentEntries[i];
      final combined = [
        entry.title,
        ...entry.paragraphs,
      ].join(' ');
      if (!combined.toLowerCase().contains(keyword)) continue;
      results.add(
        _SearchResult(
          entryIndex: i,
          title: entry.title,
          snippet: _buildSnippet(entry.paragraphs, keyword),
        ),
      );
    }
    return results;
  }

  String _buildSnippet(List<String> paragraphs, String keyword) {
    if (paragraphs.isEmpty) return '';
    for (final paragraph in paragraphs) {
      final lower = paragraph.toLowerCase();
      final idx = lower.indexOf(keyword);
      if (idx == -1) continue;
      final start = idx > 24 ? idx - 24 : 0;
      final end = (idx + keyword.length + 48).clamp(0, paragraph.length);
      final snippet = paragraph.substring(start, end);
      return (start > 0 ? '...' : '') +
          snippet +
          (end < paragraph.length ? '...' : '');
    }
    final fallback = paragraphs.first;
    return fallback.length > 80 ? '${fallback.substring(0, 80)}...' : fallback;
  }

  Future<void> _openPenSettings() async {
    final result = await showModalBottomSheet<_ToolSettings>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        var tempPenColor = _penColor;
        var tempPenWidth = _penWidth;
        var tempHighlighterColor = _highlighterColor;
        var tempHighlighterWidth = _highlighterWidth;
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pen Settings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  const Text('Pen Color', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      for (final color in _penPalette)
                        _ColorChip(
                          color: color,
                          selected: tempPenColor == color,
                          onTap: () => setState(() => tempPenColor = color),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Pen Width', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      for (final width in _penWidths)
                        _WidthChip(
                          width: width,
                          selected: tempPenWidth == width,
                          onTap: () => setState(() => tempPenWidth = width),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Highlighter Color', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      for (final color in _highlighterPalette)
                        _ColorChip(
                          color: color,
                          selected: tempHighlighterColor == color,
                          onTap: () =>
                              setState(() => tempHighlighterColor = color),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Highlighter Width', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      for (final width in _highlighterWidths)
                        _WidthChip(
                          width: width,
                          selected: tempHighlighterWidth == width,
                          onTap: () =>
                              setState(() => tempHighlighterWidth = width),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(
                            _ToolSettings(
                              penColor: tempPenColor,
                              penWidth: tempPenWidth,
                              highlighterColor: tempHighlighterColor,
                              highlighterWidth: tempHighlighterWidth,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Apply'),
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
      _penColor = result.penColor;
      _penWidth = result.penWidth;
      _highlighterColor = result.highlighterColor;
      _highlighterWidth = result.highlighterWidth;
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_isDrawingTool) return;
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    final position = event.localPosition;
    if (_toolMode == _ToolMode.eraser) {
      _eraserPosition = position;
      _eraseAt(position);
    } else if (_toolMode == _ToolMode.highlighter) {
      _startHighlighter(position);
    } else {
      _startPenStroke(position);
    }
    _bumpPaint();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_isDrawingTool) return;
    if (_activePointer != event.pointer) return;
    final position = event.localPosition;
    if (_toolMode == _ToolMode.eraser) {
      _eraserPosition = position;
      _eraseAt(position);
    } else if (_toolMode == _ToolMode.highlighter) {
      _updateHighlighterLine(position);
    } else {
      _appendPenStroke(position);
    }
    _bumpPaint();
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;
    if (_toolMode == _ToolMode.eraser) {
      _eraserPosition = null;
    } else {
      _finishStroke();
    }
    if (_toolMode == _ToolMode.highlighter) {
      _highlighterStart = null;
    }
    _activePointer = null;
    _bumpPaint();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;
    _activePointer = null;
    _currentStroke = null;
    _eraserPosition = null;
    _highlighterStart = null;
    _bumpPaint();
  }

  void _startPenStroke(Offset position) {
    _currentStroke = _Stroke(color: _penColor, width: _penWidth)
      ..addPoint(position);
  }

  void _appendPenStroke(Offset position) {
    final stroke = _currentStroke;
    if (stroke == null) return;
    if (stroke.points.isNotEmpty) {
      final lastPoint = stroke.points.last;
      if ((position - lastPoint).distance < _minPointDistance) return;
    }
    stroke.addPoint(position);
  }

  void _startHighlighter(Offset position) {
    _highlighterStart = position;
    _currentStroke = _Stroke(
      color: _highlighterColor.withOpacity(0.45),
      width: _highlighterWidth,
    )..setLine(position, position);
  }

  void _updateHighlighterLine(Offset position) {
    final stroke = _currentStroke;
    final start = _highlighterStart;
    if (stroke == null || start == null) return;
    stroke.setLine(start, position);
  }

  void _finishStroke() {
    final stroke = _currentStroke;
    if (stroke != null && stroke.points.isNotEmpty) {
      _strokes.add(stroke);
    }
    _currentStroke = null;
  }

  void _eraseAt(Offset position) {
    if (_strokes.isEmpty) return;
    _strokes.removeWhere((stroke) => stroke.hitTest(position, _eraserRadius));
  }

  @override
  Widget build(BuildContext context) {
    _initializeIfNeeded();
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSidebar(context),
                    Expanded(child: _buildContent(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 80,
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            iconSize: 36,
            icon: const Icon(Icons.arrow_back, color: Color(0xFF3B3B3B)),
            onPressed: () => Navigator.maybePop(context),
          ),
          const Text(
            'AIFlow',
            style: TextStyle(
              color: kPrimary,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 260,
          color: Colors.white,
          child: Column(
            children: [
              _buildTocHeader(),
              Expanded(child: _buildTocList()),
              const Divider(height: 1, thickness: 1, color: kBorder),
              _buildSidebarTools(),
            ],
          ),
        ),
        _buildCollapseHandle(context),
      ],
    );
  }

  Widget _buildTocHeader() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: const Text(
        'Table of Contents',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildTocList() {
    final entries = _visibleTocEntries();
    return Scrollbar(
      controller: _tocController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _tocController,
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final isActive = entry.entryIndex == _activeEntryIndex;
          final isChapter = entry.level == 0;
          final isExpanded = _chapterExpanded[entry.chapterIndex];
          return InkWell(
            onTap: () => _handleTocTap(entry),
            child: Container(
              height: isChapter ? 52 : 40,
              padding: EdgeInsets.only(
                left: isChapter ? 16 : 32,
                right: 12,
              ),
              decoration: BoxDecoration(
                color: isActive ? kPrimary : Colors.white,
                border: const Border(
                  bottom: BorderSide(color: kBorder, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.title,
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.black,
                        fontSize: isChapter ? 15 : 13,
                        fontWeight:
                            isChapter ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (entry.hasChildren)
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down_sharp
                          : Icons.keyboard_arrow_right_sharp,
                      size: 22,
                      color: isActive ? Colors.white : Colors.black,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSidebarTools() {
    final total = _contentEntries.length;
    final current = total == 0 ? 0 : _activeEntryIndex + 1;
    final hasEntries = _contentEntries.isNotEmpty;
    final isBookmarked = hasEntries && _isBookmarked(_activeEntryIndex);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        children: [
          Row(
            children: [
              _toolIcon(
                icon: isBookmarked ? Icons.bookmark : Icons.bookmark_add,
                active: isBookmarked,
                onTap: hasEntries ? _handleAddBookmark : null,
              ),
              const SizedBox(width: 8),
              _toolIcon(
                icon: Icons.create,
                active: _toolMode == _ToolMode.pen,
                onTap: () => _setToolMode(_ToolMode.pen),
              ),
              const SizedBox(width: 8),
              _toolIcon(
                icon: Icons.brush,
                active: _toolMode == _ToolMode.highlighter,
                onTap: () => _setToolMode(_ToolMode.highlighter),
              ),
              const SizedBox(width: 8),
              _toolIcon(
                icon: Icons.color_lens_sharp,
                active: false,
                onTap: _openPenSettings,
                foreground: _activeInkColor,
              ),
              const SizedBox(width: 8),
              _toolIcon(
                icon: Icons.cleaning_services_outlined,
                active: _toolMode == _ToolMode.eraser,
                onTap: () => _setToolMode(_ToolMode.eraser),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _navIcon(Icons.search_sharp, kPrimaryLight, onTap: _openSearch),
              const SizedBox(width: 8),
              _navIcon(
                Icons.arrow_back_ios_sharp,
                kPrimaryLight,
                onTap: _goToPreviousEntry,
              ),
              const SizedBox(width: 8),
              Container(
                width: 92,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(width: 1, color: kBorder),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$current / $total',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              _navIcon(
                Icons.arrow_forward_ios_sharp,
                kPrimaryLight,
                onTap: _goToNextEntry,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toolIcon({
    required IconData icon,
    required bool active,
    required VoidCallback? onTap,
    Color? foreground,
  }) {
    final bg = active ? kPrimary : Colors.white;
    final fg = foreground ?? (active ? Colors.white : kPrimary);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder, width: 1),
        ),
        child: Icon(icon, color: fg, size: 20),
      ),
    );
  }

  Widget _navIcon(IconData icon, Color bg, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildCollapseHandle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Container(
        width: 18,
        height: 80,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: const Icon(Icons.arrow_forward_ios, size: 10),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Scrollbar(
        controller: _contentController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _contentController,
          padding: const EdgeInsets.fromLTRB(20, 20, 24, 40),
          child: Stack(
            children: [
              Column(
                key: _contentKey,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildContentBlocks(),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_isDrawingTool,
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: _handlePointerDown,
                    onPointerMove: _handlePointerMove,
                    onPointerUp: _handlePointerUp,
                    onPointerCancel: _handlePointerCancel,
                    child: CustomPaint(
                      painter: _AnnotationPainter(
                        strokes: _strokes,
                        currentStroke: _currentStroke,
                        eraserPosition: _eraserPosition,
                        eraserRadius: _eraserRadius,
                        repaint: _paintVersion,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContentBlocks() {
    final blocks = <Widget>[];
    for (var i = 0; i < _contentEntries.length; i++) {
      final entry = _contentEntries[i];
      blocks.add(
        Container(
          key: _sectionKeys[i],
          margin: EdgeInsets.only(top: i == 0 ? 0 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style: TextStyle(
                  fontSize: entry.level == 0 ? 24 : 18,
                  fontWeight:
                      entry.level == 0 ? FontWeight.w800 : FontWeight.w700,
                  color: kPrimary,
                ),
              ),
              const SizedBox(height: 10),
              for (final paragraph in entry.paragraphs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    paragraph,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return blocks;
  }

  List<_TocEntry> _visibleTocEntries() {
    final entries = <_TocEntry>[];
    for (var i = 0; i < _contentEntries.length; i++) {
      final entry = _contentEntries[i];
      if (entry.level == 0) {
        entries.add(
          _TocEntry(
            entryIndex: i,
            chapterIndex: entry.chapterIndex,
            level: 0,
            title: entry.title,
            hasChildren: _chapters[entry.chapterIndex].sections.isNotEmpty,
          ),
        );
      } else if (_chapterExpanded[entry.chapterIndex]) {
        entries.add(
          _TocEntry(
            entryIndex: i,
            chapterIndex: entry.chapterIndex,
            level: 1,
            title: entry.title,
            hasChildren: false,
          ),
        );
      }
    }
    return entries;
  }
}

class BookData {
  const BookData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.chapters,
    this.progress = 0,
    this.progressLabel = '',
    this.coverColor,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<BookChapter> chapters;
  final double progress;
  final String progressLabel;
  final Color? coverColor;
}

class BookChapter {
  const BookChapter({
    required this.title,
    required this.intro,
    required this.sections,
  });

  final String title;
  final List<String> intro;
  final List<BookSection> sections;
}

class BookSection {
  const BookSection({required this.title, required this.paragraphs});

  final String title;
  final List<String> paragraphs;
}

class _ContentEntry {
  const _ContentEntry({
    required this.chapterIndex,
    required this.level,
    required this.title,
    required this.paragraphs,
  });

  final int chapterIndex;
  final int level;
  final String title;
  final List<String> paragraphs;
}

class _TocEntry {
  const _TocEntry({
    required this.entryIndex,
    required this.chapterIndex,
    required this.level,
    required this.title,
    required this.hasChildren,
  });

  final int entryIndex;
  final int chapterIndex;
  final int level;
  final String title;
  final bool hasChildren;
}

class _SearchResult {
  const _SearchResult({
    required this.entryIndex,
    required this.title,
    required this.snippet,
  });

  final int entryIndex;
  final String title;
  final String snippet;
}

class _ToolSettings {
  const _ToolSettings({
    required this.penColor,
    required this.penWidth,
    required this.highlighterColor,
    required this.highlighterWidth,
  });

  final Color penColor;
  final double penWidth;
  final Color highlighterColor;
  final double highlighterWidth;
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 28,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1B402B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E3E7)),
        ),
        alignment: Alignment.center,
        child: Container(
          width: width,
          height: width,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.black,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _Stroke {
  _Stroke({required this.color, required this.width});

  final Color color;
  final double width;
  final List<Offset> points = <Offset>[];

  void addPoint(Offset point) {
    points.add(point);
  }

  void setLine(Offset start, Offset end) {
    points
      ..clear()
      ..add(start)
      ..add(end);
  }

  bool hitTest(Offset center, double radius) {
    if (points.isEmpty) return false;
    final threshold = radius + width * 0.5;
    if (points.length == 1) {
      return (points.first - center).distance <= threshold;
    }
    for (var i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if (_distanceToSegment(center, p1, p2) <= threshold) {
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

class _AnnotationPainter extends CustomPainter {
  _AnnotationPainter({
    required this.strokes,
    required this.currentStroke,
    required this.eraserPosition,
    required this.eraserRadius,
    Listenable? repaint,
  }) : super(repaint: repaint);

  final List<_Stroke> strokes;
  final _Stroke? currentStroke;
  final Offset? eraserPosition;
  final double eraserRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    void drawStroke(_Stroke stroke) {
      if (stroke.points.isEmpty) return;
      paint
        ..color = stroke.color
        ..strokeWidth = stroke.width;
      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first, stroke.width * 0.5, paint);
        return;
      }
      for (var i = 0; i < stroke.points.length - 1; i++) {
        canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
      }
    }

    for (final stroke in strokes) {
      drawStroke(stroke);
    }
    if (currentStroke != null) {
      drawStroke(currentStroke!);
    }

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
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) {
    return oldDelegate.eraserPosition != eraserPosition;
  }
}

const List<Color> _penPalette = [
  Colors.black,
  Color(0xFFEF5350),
  Color(0xFF1E88E5),
  Color(0xFF2E7D32),
];

const List<Color> _highlighterPalette = [
  Color(0xFFFFF59D),
  Color(0xFFFFCC80),
  Color(0xFFA5D6A7),
  Color(0xFFB39DDB),
];

const List<double> _penWidths = [2, 3, 5];
const List<double> _highlighterWidths = [10, 14, 18];

List<_ContentEntry> _buildContentEntries(List<BookChapter> chapters) {
  final entries = <_ContentEntry>[];
  for (var i = 0; i < chapters.length; i++) {
    final chapter = chapters[i];
    entries.add(
      _ContentEntry(
        chapterIndex: i,
        level: 0,
        title: chapter.title,
        paragraphs: chapter.intro,
      ),
    );
    for (final section in chapter.sections) {
      entries.add(
        _ContentEntry(
          chapterIndex: i,
          level: 1,
          title: section.title,
          paragraphs: section.paragraphs,
        ),
      );
    }
  }
  return entries;
}

const List<BookData> _libraryBooks = [
  BookData(
    id: 'counting_combinatorics',
    title: 'Counting & Combinatorics',
    subtitle: 'Permutation, combination, binomial',
    progress: 0.72,
    progressLabel: '72% complete',
    coverColor: Color(0xFF1B402B),
    chapters: [
      BookChapter(
        title: '1. Permutation',
        intro: [
          'Permutation is the study of ordered arrangements. Changing the order '
              'creates a new outcome, even if the elements are the same.',
        ],
        sections: [
          BookSection(
            title: '1-1. Basic Counting',
            paragraphs: [
              'Choose r items from n and arrange them. The count is written as '
                  'nPr and computed with factorials.',
              'Factorials grow quickly, so always simplify expressions before '
                  'calculating large values.',
            ],
          ),
          BookSection(
            title: '1-2. Permutation With Repetition',
            paragraphs: [
              'When repetition is allowed, each position can reuse any of the n '
                  'items. The total becomes n^r.',
              'Use this model for passwords, sequences, and codes where items '
                  'can repeat.',
            ],
          ),
          BookSection(
            title: '1-3. Circular Arrangements',
            paragraphs: [
              'For a circle, rotations are considered the same. Fix one element '
                  'and arrange the rest to avoid overcounting.',
              'If reflections are also identical, divide by two once rotations '
                  'are handled.',
            ],
          ),
        ],
      ),
      BookChapter(
        title: '2. Combination',
        intro: [
          'Combination ignores order. We only care about which elements are '
              'selected, not how they are arranged.',
        ],
        sections: [
          BookSection(
            title: '2-1. Definition',
            paragraphs: [
              'Choosing r items from n without order is nCr. It is computed as '
                  'n! / (r!(n-r)!).',
              'Notice that nCr = nC(n-r). Use this symmetry to simplify work.',
            ],
          ),
          BookSection(
            title: '2-2. Pascal Relation',
            paragraphs: [
              'Pascal\'s identity states nCr = (n-1)C(r-1) + (n-1)Cr.',
              'This relation builds Pascal\'s triangle and helps in recursive '
                  'counting problems.',
            ],
          ),
          BookSection(
            title: '2-3. Applications',
            paragraphs: [
              'Combinations appear in probability, sampling, and grouping tasks.',
              'Always check whether order matters before choosing between '
                  'permutations and combinations.',
            ],
          ),
        ],
      ),
      BookChapter(
        title: '3. Binomial Theorem',
        intro: [
          'The binomial theorem expands (a + b)^n into a sum of n+1 terms with '
              'combination coefficients.',
        ],
        sections: [
          BookSection(
            title: '3-1. Expansion',
            paragraphs: [
              'Each term takes the form nCk * a^(n-k) * b^k.',
              'The coefficients match the row of Pascal\'s triangle for n.',
            ],
          ),
          BookSection(
            title: '3-2. Coefficient Practice',
            paragraphs: [
              'Identify the term by matching the exponents. Then read the '
                  'coefficient directly from nCk.',
              'Use symmetry in coefficients to reduce the number of cases.',
            ],
          ),
          BookSection(
            title: '3-3. Approximations',
            paragraphs: [
              'When b is small, only a few terms of the expansion may dominate.',
              'This idea leads to useful approximations in algebra and calculus.',
            ],
          ),
        ],
      ),
    ],
  ),
  BookData(
    id: 'calculus_supplement',
    title: 'Calculus Supplement',
    subtitle: 'Limits, derivatives, integrals',
    progress: 0.46,
    progressLabel: '46% complete',
    coverColor: Color(0xFF1E88E5),
    chapters: [
      BookChapter(
        title: '1. Limits',
        intro: [
          'Limits describe the value a function approaches near a point.',
        ],
        sections: [
          BookSection(
            title: '1-1. Graphical Limits',
            paragraphs: [
              'Use graphs to estimate a limit from both sides.',
              'Check for jumps, holes, or asymptotes that block continuity.',
            ],
          ),
          BookSection(
            title: '1-2. Algebraic Limits',
            paragraphs: [
              'Factor or rationalize expressions to remove indeterminate forms.',
              'After simplification, substitute the target value.',
            ],
          ),
        ],
      ),
      BookChapter(
        title: '2. Derivatives',
        intro: [
          'Derivatives measure instantaneous change and slope.',
        ],
        sections: [
          BookSection(
            title: '2-1. Definition',
            paragraphs: [
              'The derivative is the limit of the difference quotient.',
              'It captures the slope of the tangent line at a point.',
            ],
          ),
          BookSection(
            title: '2-2. Rules',
            paragraphs: [
              'Use the product, quotient, and chain rules to differentiate.',
              'Keep track of constants and simplify the final expression.',
            ],
          ),
        ],
      ),
      BookChapter(
        title: '3. Integrals',
        intro: [
          'Integrals accumulate area and invert differentiation.',
        ],
        sections: [
          BookSection(
            title: '3-1. Indefinite Integrals',
            paragraphs: [
              'Find an antiderivative and add the constant of integration.',
              'Reverse common derivative rules to integrate quickly.',
            ],
          ),
          BookSection(
            title: '3-2. Definite Integrals',
            paragraphs: [
              'Evaluate the antiderivative at upper and lower bounds.',
              'Use area interpretation to check if the value is reasonable.',
            ],
          ),
        ],
      ),
    ],
  ),
  BookData(
    id: 'geometry_practice',
    title: 'Geometry Practice',
    subtitle: 'Vectors, transformations, solids',
    progress: 0.18,
    progressLabel: '18% complete',
    coverColor: Color(0xFFEF5350),
    chapters: [
      BookChapter(
        title: '1. Vectors',
        intro: [
          'Vectors encode magnitude and direction in the plane.',
        ],
        sections: [
          BookSection(
            title: '1-1. Components',
            paragraphs: [
              'Represent vectors by their x and y components.',
              'Add and subtract vectors by combining components.',
            ],
          ),
          BookSection(
            title: '1-2. Dot Product',
            paragraphs: [
              'The dot product connects angle and magnitude.',
              'Use it to test perpendicularity or project vectors.',
            ],
          ),
        ],
      ),
      BookChapter(
        title: '2. Transformations',
        intro: [
          'Transformations move or reshape figures in the plane.',
        ],
        sections: [
          BookSection(
            title: '2-1. Rotation',
            paragraphs: [
              'Rotations preserve distance and angle but change orientation.',
              'Track points using rotation matrices or geometry.',
            ],
          ),
          BookSection(
            title: '2-2. Reflection',
            paragraphs: [
              'Reflections flip a figure across a line.',
              'Identify the mirror line and map each point across it.',
            ],
          ),
        ],
      ),
      BookChapter(
        title: '3. Solid Geometry',
        intro: [
          'Solids extend plane geometry into three dimensions.',
        ],
        sections: [
          BookSection(
            title: '3-1. Volume',
            paragraphs: [
              'Use standard formulas for prisms, cylinders, and cones.',
              'Decompose complex solids into simpler parts.',
            ],
          ),
          BookSection(
            title: '3-2. Surface Area',
            paragraphs: [
              'Unfold solids into nets to compute surface area.',
              'Sum the areas of all faces carefully.',
            ],
          ),
        ],
      ),
    ],
  ),
];




