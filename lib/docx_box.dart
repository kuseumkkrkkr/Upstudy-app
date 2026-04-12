import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:s11/book_page.dart' as book_page;
import 'package:s11/models/textbook.dart';
import 'widgets/app_drawer.dart';
import 'friend.dart';
import 'mainstudent.dart';
import 'pages/exam_paper_page.dart';
import 'services/exam_paper_store.dart';
import 'services/local_db.dart';
import 'services/textbook_store.dart';
import 'study_center.dart' as study_center;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B402B)),
        fontFamily: 'Inter',
      ),
      home: const BookWidget(),
    );
  }
}

class BookWidget extends StatefulWidget {
  const BookWidget({super.key});

  static const Color primaryGreen = Color(0xFF1B402B);
  static const Color brightGreen = Color(0xFF39D276);
  static const Color darkGreen = Color(0xFF134D23);
  static const Color mediumGreen = Color(0xFF25B04C);
  static const Color borderColor = Color(0xFFE0E3E7);
  static const Color bgColor = Color(0xFFF8F8F8);
  static const double _examPreviewHeight = 250;
  static const double _textbookPreviewHeight = 640;

  @override
  State<BookWidget> createState() => _BookWidgetState();
}

class _BookWidgetState extends State<BookWidget> {
  static const String _pinnedBookKey = 'pinned_textbook_id';
  final ValueNotifier<String> _bookSearchQuery = ValueNotifier<String>('');
  final ValueNotifier<String> _globalSearchQuery = ValueNotifier<String>('');
  final TextEditingController _bookSearchController = TextEditingController();
  final TextEditingController _globalSearchController = TextEditingController();
  BookData? _pinnedBook;
  // Tracks whether pinned book has been resolved; currently unused but kept for future loading states.
  bool _pinnedLoaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(ExamPaperStore.load());
    unawaited(TextbookStore.loadLibrary());
    _loadPinnedBook();
  }

  @override
  void dispose() {
    _bookSearchController.dispose();
    _globalSearchController.dispose();
    _bookSearchQuery.dispose();
    _globalSearchQuery.dispose();
    super.dispose();
  }

  double _uiScale(BuildContext context, {double min = 0.6, double max = 1.05}) {
    final width = MediaQuery.of(context).size.width;
    final scale = width / 1200;
    if (scale < min) return min;
    if (scale > max) return max;
    return scale;
  }

  Future<void> _loadPinnedBook() async {
    try {
      final pinnedId = await LocalDb.instance.getString(_pinnedBookKey);
      if (pinnedId == null || pinnedId.isEmpty) {
        setState(() => _pinnedLoaded = true);
        return;
      }
      final library = await TextbookStore.loadLibrary();
      BookData? match;
      for (final book in library) {
        if (book.id == pinnedId) {
          match = book;
          break;
        }
      }
      if (match != null) {
        setState(() {
          _pinnedBook = match;
          _pinnedLoaded = true;
        });
        return;
      }
      final fetched = await TextbookStore.getById(pinnedId);
      setState(() {
        _pinnedBook = fetched;
        _pinnedLoaded = true;
      });
    } catch (_) {
      setState(() => _pinnedLoaded = true);
    }
  }

  Future<void> _pinBook(BookData book) async {
    await LocalDb.instance.setString(_pinnedBookKey, book.id);
    setState(() {
      _pinnedBook = book;
      _pinnedLoaded = true;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('\'${book.title}\' has been pinned to the hero bookshelf.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: BookWidget.bgColor,
        drawer: const AppDrawer(),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Builder(builder: (context) => _buildHeader(context)),
                _buildHeroSection(context),
                _buildBottomSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ?�?� ?�단 ?�더 ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�
  Widget _buildHeader(BuildContext context) {
    final scale = _uiScale(context);
    return Container(
      width: double.infinity,
      height: 72 * scale,
      color: Colors.white,
      child: Row(
        children: [
          SizedBox(width: 16 * scale),
          IconButton(
            iconSize: 28 * scale,
            icon: const Icon(Icons.menu_outlined, color: BookWidget.primaryGreen),
            onPressed: () => toggleAppDrawer(context),
          ),
          SizedBox(width: 12 * scale),
          SizedBox(width: 12 * scale),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainStudentPage()),
                (route) => false,
              );
            },
            child: Text(
              'AIFlow',
              style: TextStyle(
                color: BookWidget.primaryGreen,
                fontSize: 36 * scale,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 120 * scale),
          Expanded(
            child: Container(
              color: Colors.white,
              height: 72 * scale,
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _navItem(
                      '학습지',
                      fontSize: 16 * scale,
                      horizontalPadding: 12 * scale,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const study_center.SoWidget(),
                          ),
                        );
                      },
                    ),
                    _navItem(
                      '문서함',
                      fontSize: 16 * scale,
                      horizontalPadding: 12 * scale,
                    ),
                    _navItem(
                      '친구/소셜',
                      fontSize: 16 * scale,
                      horizontalPadding: 12 * scale,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SoWidget()),
                        );
                      },
                    ),
                    Padding(
                      padding: EdgeInsets.only(right: 24 * scale),
                      child: _navItem(
                        '마켓플레이스',
                        fontSize: 16 * scale,
                        horizontalPadding: 12 * scale,
                      ),
                    ),
                    SizedBox(width: 16 * scale),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    String label, {
    required double fontSize,
    required double horizontalPadding,
    VoidCallback? onTap,
  }) => Padding(
    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
    child: GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: BookWidget.primaryGreen,
          fontSize: fontSize,
          fontWeight: FontWeight.normal,
        ),
      ),
    ),
  );
  // ?�?� ?�어�?배너 ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�
  Widget _buildHeroSection(BuildContext context) {
    final ImageProvider heroImage = kIsWeb
        ? const NetworkImage('http://localhost:8000/assets/bookshelf.png')
        : const AssetImage('assets/bookshelf.png');
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 980;
    final heroHeight = isCompact ? 620.0 : 750.0;
    final List<double> recentRowVerticalPaddings =
        isCompact ? [8, 8, 8, 8] : [12, 12, 12, 12];
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: heroHeight),
      decoration: BoxDecoration(
        image: DecorationImage(fit: BoxFit.cover, image: heroImage),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 16 : 40,
          vertical: isCompact ? 24 : 32,
        ),
        child: Column(
          children: [
            SizedBox(height: isCompact ? 72 : 120),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      '문서고함',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 40 : 52,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  SizedBox(width: isCompact ? 14 : 32),
                  Flexible(child: _buildSearchBar(isCompact: isCompact)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ..._buildPinnedGrid(rowVerticalPaddings: recentRowVerticalPaddings),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar({bool isCompact = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showGlobalSearch(context),
        child: Container(
          width: isCompact ? 320 : 500,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                blurRadius: 4,
                color: Color(0x33000000),
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.search_sharp, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '교재, 시험지, 자료 전체 검색',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: isCompact ? 14 : 15,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPinnedGrid({
    List<double>? rowVerticalPaddings,
    double defaultRowVerticalPadding = 12,
  }) {
    final slots = List<Widget>.generate(8, (index) {
      if (index == 0 && _pinnedBook != null) {
        return _recentCard(book: _pinnedBook!);
      }
      return _recentPlaceholderCard();
    });
    final rows = [
      [slots[0], slots[1]],
      [slots[2], slots[3]],
      [slots[4], slots[5]],
      [slots[6], slots[7]],
    ];
    final paddings =
        rowVerticalPaddings ??
        List.filled(rows.length, defaultRowVerticalPadding);
    return List.generate(rows.length, (index) {
      final padding = index < paddings.length
          ? paddings[index]
          : defaultRowVerticalPadding;
      final row = rows[index];
      return Padding(
        padding: EdgeInsets.symmetric(vertical: padding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [row[0], const SizedBox(width: 40), row[1]],
        ),
      );
    });
  }

  Widget _recentCard({BookData? book, String? label, String? sub}) {
    final displayLabel = book != null ? book.title : label;
    final displaySub =
        book != null ? _bookSubtitle(book) : (sub ?? '핀으로 고정하면 표시됩니다');
    return Container(
      width: 380,
      height: 82,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 4,
            color: Color(0x33000000),
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: BookWidget.brightGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.book_outlined,
              color: Colors.white,
              size: 36,
            ),
          ),
          if (displayLabel != null)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayLabel,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (displaySub != null)
                    Text(
                      displaySub,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ?�?� ?�단 콘텐�??�역 ?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�?�
  Widget _buildBottomSection(BuildContext context) {
    const double sectionVerticalGap = 15;

    Widget leftColumn() => Column(
          children: [
            _buildSectionCard(
              title: '시험지',
              helper: '최대 30개 보관',
              onArrowTap: () => _showExamModal(context),
              child: ValueListenableBuilder<List<ExamPaperEntry>>(
                valueListenable: ExamPaperStore.notifier,
                builder: (context, items, _) {
                  final hasItems = items.isNotEmpty;
                  final previewItems = items.take(2).toList();
                  final placeholders = hasItems ? 2 - previewItems.length : 0;
                  final children = <Widget>[];
                  if (!hasItems) {
                    children.add(
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          '시험지가 없어요!',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    );
                  }
                  for (final entry in previewItems) {
                    children.add(
                      _documentItem(
                        color: BookWidget.mediumGreen,
                        icon: Icons.library_books_outlined,
                        title: _examTitle(entry),
                        sub: _examSubtitle(entry),
                        onTap: () => _openExamPaper(context, entry),
                      ),
                    );
                  }
                  for (var i = 0; i < placeholders; i++) {
                    children.add(_emptyDocItem());
                  }
                  return ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: BookWidget._examPreviewHeight,
                    ),
                    child: Column(children: _withSpacing(children, 10)),
                  );
                },
              ),
            ),
            _buildSectionCard(
              title: '플래시카드',
              child: Column(
                children: [
                  _flashcardItem(title: '미열', subtitle: '중간고사 범위'),
                  _flashcardItem(title: 'Title', subtitle: 'Subtitle'),
                  _flashcardItem(title: 'Title', subtitle: 'Subtitle'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: sectionVerticalGap),
              child: _reportButton(),
            ),
          ],
        );

    Widget rightColumn() => Column(
          children: [
            _buildSectionCard(
              title: '교재',
              helper: '최대 10개 보관',
              onArrowTap: () => _showTextbookModal(context),
              child: FutureBuilder<List<BookData>>(
                future: TextbookStore.loadLibrary(),
                builder: (context, snapshot) {
                  final books = snapshot.data ?? const <BookData>[];
                  final hasItems = books.isNotEmpty;
                  final previewBooks = books.take(5).toList();
                  final placeholders = hasItems ? 5 - previewBooks.length : 0;
                  final children = <Widget>[];
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    children.add(
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          '교재를 불러오는 중...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    );
                  } else if (!hasItems) {
                    children.add(
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          '교재가 없어요!',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    );
                  }
                  for (final book in previewBooks) {
                    children.add(
                      _documentItem(
                        color: book.coverColor ?? BookWidget.darkGreen,
                        icon: Icons.book_outlined,
                        title: book.title,
                        sub: _bookSubtitle(book),
                        onTap: () => _openTextbook(context, book),
                      ),
                    );
                  }
                  for (var i = 0; i < placeholders; i++) {
                    children.add(_emptyDocItem());
                  }
                  return ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: BookWidget._textbookPreviewHeight,
                    ),
                    child: Column(children: _withSpacing(children, 10)),
                  );
                },
              ),
            ),
          ],
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1100;
        final horizontalPadding = isNarrow ? 12.0 : 20.0;
        if (isNarrow) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                leftColumn(),
                const SizedBox(height: 20),
                rightColumn(),
              ],
            ),
          );
        }
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: leftColumn()),
              const SizedBox(width: 20),
              Expanded(child: rightColumn()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
    VoidCallback? onArrowTap,
    String? helper,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 0, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (helper != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          helper,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onArrowTap,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.arrow_forward_ios_sharp, size: 20),
                ),
              ),
            ],
          ),
          const Divider(thickness: 2, height: 0),
          Padding(padding: const EdgeInsets.fromLTRB(0, 8, 0, 8), child: child),
        ],
      ),
    );
  }

  void _showExamModal(BuildContext context) {
    final rootContext = context;
    final selected = <String>{};
    var editMode = false;

    Future<void> deleteSelected() async {
      final ids = List<String>.from(selected);
      for (final id in ids) {
        await ExamPaperStore.remove(id);
      }
      selected.clear();
      editMode = false;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 700),
            child: StatefulBuilder(
              builder: (context, setState) {
                void toggleEdit() {
                  setState(() {
                    if (editMode && selected.isEmpty) {
                      editMode = false;
                    } else if (!editMode) {
                      editMode = true;
                    } else if (editMode && selected.isNotEmpty) {
                      // ignore here, handled by delete icon
                    }
                  });
                }

                Future<void> handleDelete() async {
                  await deleteSelected();
                  setState(() {});
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('선택한 시험지를 삭제했습니다.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                '보관된 시험지',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '최대 30개까지 보관됩니다.',
                                style:
                                    TextStyle(color: Colors.black54, fontSize: 13),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                tooltip: selected.isNotEmpty
                                    ? '선택 시험지 삭제'
                                    : (editMode ? '편집 종료' : '편집'),
                                icon: Icon(
                                  selected.isNotEmpty
                                      ? Icons.delete_outline
                                      : Icons.edit_outlined,
                                ),
                                onPressed: selected.isNotEmpty
                                    ? handleDelete
                                    : () {
                                        if (editMode) {
                                          setState(() {
                                            editMode = false;
                                            selected.clear();
                                          });
                                        } else {
                                          toggleEdit();
                                        }
                                      },
                              ),
              IconButton(
                tooltip: '닫기',
                icon: const Icon(Icons.close),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ValueListenableBuilder<List<ExamPaperEntry>>(
                          valueListenable: ExamPaperStore.notifier,
                          builder: (context, items, _) {
                            if (items.isEmpty) {
                              return const Center(
                                child: Text(
                                  '시험지가 없습니다.',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              );
                            }
                            return Scrollbar(
                              thumbVisibility: true,
                              child: ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final entry = items[index];
                                  final checked = selected.contains(entry.examId);
                                  return ListTile(
                                    leading: editMode
                                        ? Checkbox(
                                            value: checked,
                                            onChanged: (value) {
                                              setState(() {
                                                if (value == true) {
                                                  selected.add(entry.examId);
                                                } else {
                                                  selected.remove(entry.examId);
                                                }
                                              });
                                            },
                                          )
                                        : CircleAvatar(
                                            backgroundColor: BookWidget.mediumGreen,
                                            child: const Icon(
                                              Icons.library_books_outlined,
                                              color: Colors.white,
                                            ),
                                          ),
                                    title: Text(_examTitle(entry)),
                                    subtitle: Text(_examSubtitle(entry)),
                                    trailing: editMode
                                        ? null
                                        : const Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 16,
                                          ),
                                    onTap: () {
                                      if (editMode) {
                                        setState(() {
                                          if (checked) {
                                            selected.remove(entry.examId);
                                          } else {
                                            selected.add(entry.examId);
                                          }
                                        });
                                      } else {
                                        Navigator.of(dialogContext).pop();
                                        _openExamPaper(rootContext, entry);
                                      }
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _recentPlaceholderCard() {
    return SizedBox(
      width: 380,
      height: 82,
      child: _dashedPlaceholderBox(
        width: 380,
        height: 82,
        title: '비어 있음',
        description: '교재를 고정하면 여기에 표시돼요',
        color: Colors.white70,
      ),
    );
  }

  void _showTextbookModal(BuildContext context) {
    final rootContext = context;
    _bookSearchController.text = _bookSearchQuery.value;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 700),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _modalHeader(
                    title: '보관된 교재',
                    subtitle: '최대 10개까지 보관됩니다.',
                    onClose: () => Navigator.of(dialogContext).pop(),
                  ),
                  const SizedBox(height: 12),
                  _searchField(
                    controller: _bookSearchController,
                    hintText: '교재 제목 또는 태그 검색',
                    onChanged: (value) => _bookSearchQuery.value = value.trim(),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: FutureBuilder<List<BookData>>(
                      future: TextbookStore.loadLibrary(),
                      builder: (context, snapshot) {
                        final books = snapshot.data ?? const <BookData>[];
                        if (snapshot.connectionState == ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return ValueListenableBuilder<String>(
                          valueListenable: _bookSearchQuery,
                          builder: (context, query, __) {
                            final lower = query.toLowerCase();
                            final filtered = books.where((book) {
                              final title = book.title.toLowerCase();
                              final subtitle = book.subtitle.toLowerCase();
                              final tags = book.tags.join(' ').toLowerCase();
                              if (lower.isEmpty) return true;
                              return title.contains(lower) ||
                                  subtitle.contains(lower) ||
                                  tags.contains(lower);
                            }).toList();
                            if (filtered.isEmpty) {
                              return const Center(
                                child: Text(
                                  '조건에 맞는 교재가 없습니다.',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              );
                            }
                            return Scrollbar(
                              thumbVisibility: true,
                              child: ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final book = filtered[index];
                                  final isPinned =
                                      _pinnedBook != null && _pinnedBook!.id == book.id;
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          book.coverColor ?? BookWidget.darkGreen,
                                      child: const Icon(
                                        Icons.book_outlined,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Text(book.title),
                                    subtitle: Text(_bookSubtitle(book)),
                                    trailing: Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 8,
                                      children: [
                                        TextButton.icon(
                                          icon: Icon(
                                            isPinned
                                                ? Icons.push_pin
                                                : Icons.push_pin_outlined,
                                            size: 18,
                                          ),
                                          label: Text(isPinned ? '고정됨' : '고정'),
                                          onPressed: () {
                                            _pinBook(book);
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 16,
                                          ),
                                          onPressed: () {
                                            Navigator.of(dialogContext).pop();
                                            _openTextbook(rootContext, book);
                                          },
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.of(dialogContext).pop();
                                      _openTextbook(rootContext, book);
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showGlobalSearch(BuildContext context) {
    _globalSearchController.text = _globalSearchQuery.value;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880, maxHeight: 720),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _modalHeader(
                    title: '전체 검색',
                    subtitle: '교재(제목/내부정보), 시험지, 자료를 한 번에 찾아요',
                    onClose: () => Navigator.of(dialogContext).pop(),
                  ),
                  const SizedBox(height: 12),
                  _searchField(
                    controller: _globalSearchController,
                    hintText: '예: 미적분 모의고사 / 한국사 교재 / 그래프 단원',
                    onChanged: (value) => _globalSearchQuery.value = value.trim(),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: _globalSearchQuery,
                      builder: (context, query, _) {
                        final q = query.toLowerCase();
                        return DefaultTabController(
                          length: 3,
                          child: Column(
                            children: [
                              const TabBar(
                                labelColor: Colors.black,
                                tabs: [
                                  Tab(text: '교재 제목'),
                                  Tab(text: '교재 내부정보'),
                                  Tab(text: '시험지'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    _globalTextbookTitleList(dialogContext, q),
                                    _globalTextbookContentList(dialogContext, q),
                                    _globalExamList(dialogContext, q),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _globalTextbookTitleList(BuildContext dialogContext, String query) {
    return FutureBuilder<List<BookData>>(
      future: TextbookStore.loadLibrary(),
      builder: (context, snapshot) {
        final books = snapshot.data ?? const <BookData>[];
        final filtered = books.where((book) {
          if (query.isEmpty) return true;
          final title = book.title.toLowerCase();
          final subtitle = book.subtitle.toLowerCase();
          return title.contains(query) || subtitle.contains(query);
        }).toList();
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (filtered.isEmpty) {
          return const Center(
            child: Text('일치하는 교재 제목이 없습니다.', style: TextStyle(color: Colors.black54)),
          );
        }
        return Scrollbar(
          thumbVisibility: true,
          child: ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final book = filtered[index];
              final isPinned = _pinnedBook?.id == book.id;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: book.coverColor ?? BookWidget.darkGreen,
                  child: const Icon(Icons.book_outlined, color: Colors.white),
                ),
                title: Text(book.title),
                subtitle: Text(_bookSubtitle(book)),
                trailing: isPinned
                    ? const Icon(Icons.push_pin, color: Colors.orange)
                    : null,
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _openTextbook(context, book);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _globalTextbookContentList(BuildContext dialogContext, String query) {
    return FutureBuilder<List<BookData>>(
      future: TextbookStore.loadLibrary(),
      builder: (context, snapshot) {
        final books = snapshot.data ?? const <BookData>[];
        final filtered = books.where((book) {
          if (query.isEmpty) return true;
          final haystack = _bookContentText(book).toLowerCase();
          return haystack.contains(query);
        }).toList();
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (filtered.isEmpty) {
          return const Center(
            child: Text('내부정보에 일치하는 교재가 없습니다.', style: TextStyle(color: Colors.black54)),
          );
        }
        return Scrollbar(
          thumbVisibility: true,
          child: ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final book = filtered[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: book.coverColor ?? BookWidget.darkGreen,
                  child: const Icon(Icons.menu_book, color: Colors.white),
                ),
                title: Text(book.title),
                subtitle: Text(
                  _bookSubtitle(book),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _openTextbook(context, book);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _globalExamList(BuildContext dialogContext, String query) {
    return ValueListenableBuilder<List<ExamPaperEntry>>(
      valueListenable: ExamPaperStore.notifier,
      builder: (context, items, _) {
        final filtered = items.where((entry) {
          if (query.isEmpty) return true;
          final title = _examTitle(entry).toLowerCase();
          final id = entry.examId.toLowerCase();
          return title.contains(query) || id.contains(query);
        }).toList();
        if (filtered.isEmpty) {
          return const Center(
            child: Text('일치하는 시험지가 없습니다.', style: TextStyle(color: Colors.black54)),
          );
        }
        return Scrollbar(
          thumbVisibility: true,
          child: ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = filtered[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: BookWidget.mediumGreen,
                  child: const Icon(Icons.assignment_outlined, color: Colors.white),
                ),
                title: Text(_examTitle(entry)),
                subtitle: Text(_examSubtitle(entry)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _openExamPaper(context, entry);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _searchField({
    required TextEditingController controller,
    required String hintText,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: hintText,
        filled: true,
        fillColor: const Color(0xFFF4F5F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E3E7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E3E7)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      ),
    );
  }

  Widget _modalHeader({
    required String title,
    required String subtitle,
    required VoidCallback onClose,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: onClose,
        ),
      ],
    );
  }

  Widget _documentItem({
    required Color color,
    required IconData icon,
    required String title,
    required String sub,
    VoidCallback? onTap,
  }) {
    final card = Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: BookWidget.borderColor, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 120,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sub,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: card,
      ),
    );
  }

  Widget _emptyDocItem() {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: BookWidget.borderColor, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> children, double spacing) {
    if (children.isEmpty) return const <Widget>[];
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spaced.add(children[i]);
      if (i < children.length - 1) {
        spaced.add(SizedBox(height: spacing));
      }
    }
    return spaced;
  }

  void _openExamPaper(BuildContext context, ExamPaperEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamPaperPage(
          examId: entry.examId,
          expectedQuestionCount: entry.questionCount > 0
              ? entry.questionCount
              : null,
        ),
      ),
    );
  }

  void _openTextbook(BuildContext context, BookData book) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => book_page.BookWidget(book: book)),
    );
  }

  Widget _flashcardItem({required String title, required String subtitle}) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 18,
        color: Colors.grey,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  String _examTitle(ExamPaperEntry entry) {
    final typeLabel = _examTypeLabel(entry.paperType);
    return '$typeLabel 시험지';
  }

  String _examSubtitle(ExamPaperEntry entry) {
    final count = entry.questionCount > 0 ? entry.questionCount : 0;
    final dateLabel = _formatExamDate(entry.createdAt);
    return '문항수 $count / 생성일 $dateLabel';
  }

  String _bookSubtitle(BookData book) {
    final progress = book.progress.clamp(0.0, 1.0);
    final progressLabel = book.progressLabel.isNotEmpty
        ? book.progressLabel
        : '${(progress * 100).round()}%';
    final dateLabel = _formatBookDate(book.createdAt);
    return '완료율 $progressLabel / 생성일 $dateLabel';
  }

  String _bookContentText(BookData book) {
    final buffer = StringBuffer();
    buffer.write('${book.title} ${book.subtitle} ');
    if (book.tags.isNotEmpty) {
      buffer.write(book.tags.join(' '));
      buffer.write(' ');
    }
    for (final chapter in book.chapters) {
      buffer.write(chapter.title);
      buffer.write(' ');
      for (final paragraph in chapter.intro) {
        buffer.write(paragraph);
        buffer.write(' ');
      }
      for (final section in chapter.sections) {
        buffer.write(section.title);
        buffer.write(' ');
        for (final p in section.paragraphs) {
          buffer.write(p);
          buffer.write(' ');
        }
      }
    }
    return buffer.toString();
  }

  String _examTypeLabel(String raw) {
    switch (raw) {
      case 'aiflow':
        return 'AIflow';
      case 'csat':
      default:
        return '수능';
    }
  }

  String _formatExamDate(int millis) {
    if (millis <= 0) return '--.--.--';
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final year = (date.year % 100).toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year.$month.$day';
  }

  String _formatBookDate(DateTime? date) {
    if (date == null) return '--.--.--';
    final year = (date.year % 100).toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year.$month.$day';
  }

  Widget _reportButton() {
    return Container(
      width: double.infinity,
      height: 87,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 24),
            child: Text(
              '보고??보기',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.arrow_forward_ios_sharp, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _dashedPlaceholderBox({
    required double width,
    required double height,
    required String title,
    String? description,
    Color color = Colors.white70,
  }) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color),
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Opacity(
          opacity: 0.9,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    this.color = Colors.white70,
    this.strokeWidth = 2,
    this.gap = 8,
    this.dash = 10,
  });

  final Color color;
  final double strokeWidth;
  final double gap;
  final double dash;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final radius = const Radius.circular(16);
    final rect = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: radius,
      topRight: radius,
      bottomLeft: radius,
      bottomRight: radius,
    );
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


