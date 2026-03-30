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

class BookWidget extends StatelessWidget {
  const BookWidget({super.key});

  static const Color primaryGreen = Color(0xFF1B402B);
  static const Color brightGreen = Color(0xFF39D276);
  static const Color darkGreen = Color(0xFF134D23);
  static const Color mediumGreen = Color(0xFF25B04C);
  static const Color borderColor = Color(0xFFE0E3E7);
  static const Color bgColor = Color(0xFFF8F8F8);
  static const double _examPreviewHeight = 250;
  static const double _textbookPreviewHeight = 640;

  double _uiScale(BuildContext context, {double min = 0.6, double max = 1.0}) {
    final width = MediaQuery.of(context).size.width;
    final scale = width / 1100;
    if (scale < min) return min;
    if (scale > max) return max;
    return scale;
  }

  @override
  Widget build(BuildContext context) {
    unawaited(ExamPaperStore.load());
    unawaited(TextbookStore.loadLibrary());
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: bgColor,
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

  // ── 상단 헤더 ──────────────────────────────────────────────────────────────
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
            icon: const Icon(Icons.menu_outlined, color: primaryGreen),
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
                color: primaryGreen,
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
                      '학습터',
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
                      '문서고',
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
          color: primaryGreen,
          fontSize: fontSize,
          fontWeight: FontWeight.normal,
        ),
      ),
    ),
  );
  // ── 히어로 배너 ────────────────────────────────────────────────────────────
  Widget _buildHeroSection(BuildContext context) {
    final ImageProvider heroImage = kIsWeb
        ? const NetworkImage('http://localhost:8000/assets/bookshelf.png')
        : const AssetImage('assets/bookshelf.png');
    const List<double> recentRowVerticalPaddings = [12, 12, 12, 12];
    return Container(
      width: double.infinity,
      height: 750,
      decoration: BoxDecoration(
        image: DecorationImage(fit: BoxFit.cover, image: heroImage),
      ),
      child: Column(
        children: [
          const SizedBox(height: 120),
          // 제목 + 검색창
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '문서고함',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(width: 40),
                _buildSearchBar(),
              ],
            ),
          ),
          const SizedBox(height: 0),
          // 최근 문서 카드 그리드
          ..._buildRecentRows(rowVerticalPaddings: recentRowVerticalPaddings),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: 500,
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
      child: const Row(
        children: [SizedBox(width: 20), Icon(Icons.search_sharp, size: 28)],
      ),
    );
  }

  List<Widget> _buildRecentRows({
    List<double>? rowVerticalPaddings,
    double defaultRowVerticalPadding = 12,
  }) {
    final rows = [
      [_recentCard(label: '대학수학능력시험 문제집', sub: '최근 학습 5분전'), _recentCard()],
      [_recentCard(), _recentCard()],
      [_recentCard(), _recentCard()],
      [_recentCard(), _recentCard()],
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

  Widget _recentCard({String? label, String? sub}) {
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
              color: brightGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.book_outlined,
              color: Colors.white,
              size: 36,
            ),
          ),
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (sub != null)
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
  }

  // ── 하단 콘텐츠 영역 ───────────────────────────────────────────────────────
  Widget _buildBottomSection(BuildContext context) {
    const double sectionVerticalGap = 15;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 왼쪽 컬럼
          Expanded(
            child: Column(
              children: [
                _buildSectionCard(
                  title: '시험지',
                  child: ValueListenableBuilder<List<ExamPaperEntry>>(
                    valueListenable: ExamPaperStore.notifier,
                    builder: (context, items, _) {
                      final hasItems = items.isNotEmpty;
                      final previewItems = items.take(2).toList();
                      final placeholders = hasItems
                          ? 2 - previewItems.length
                          : 0;
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
                            color: mediumGreen,
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
                          minHeight: _examPreviewHeight,
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
                      _flashcardItem(title: '수열', subtitle: '중간고사 범위'),
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
            ),
          ),
          const SizedBox(width: 20),
          // 오른쪽 컬럼
          Expanded(
            child: Column(
              children: [
                _buildSectionCard(
                  title: '교재',
                  child: FutureBuilder<List<BookData>>(
                    future: TextbookStore.loadLibrary(),
                    builder: (context, snapshot) {
                      final books = snapshot.data ?? const <BookData>[];
                      final hasItems = books.isNotEmpty;
                      final previewBooks = books.take(5).toList();
                      final placeholders = hasItems
                          ? 5 - previewBooks.length
                          : 0;
                      final children = <Widget>[];
                      if (snapshot.connectionState ==
                              ConnectionState.waiting &&
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
                            color: book.coverColor ?? darkGreen,
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
                          minHeight: _textbookPreviewHeight,
                        ),
                        child: Column(children: _withSpacing(children, 10)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
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
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.arrow_forward_ios_sharp, size: 20),
              ),
            ],
          ),
          const Divider(thickness: 2, height: 0),
          Padding(padding: const EdgeInsets.fromLTRB(0, 8, 0, 8), child: child),
        ],
      ),
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
        border: Border.all(color: borderColor, width: 2),
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
        border: Border.all(color: borderColor, width: 2),
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
    return '이수율 $progressLabel / 생성일 $dateLabel';
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
              '보고서 보기',
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
}
