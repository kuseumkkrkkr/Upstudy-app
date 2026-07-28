import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:s11/shared/data/models/content_block.dart';
import 'package:s11/shared/ui/components/content_blocks_view.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/business/repositories/bookmark_store.dart';
import 'package:s11/shared/services/storage/local_db.dart';
import 'package:s11/shared/business/repositories/textbook_store.dart';
import 'package:s11/shared/services/textbook_reader_preferences.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';
import 'package:s11/sessions/graph_tools/ui/widgets/jsx_graph_embed.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';

// 필요 변수: 교재 목록·선택 태그·카테고리. 작동 원리: 블러 배경 위에 필터된 교재함 모달을 연다.
Future<T?> showBookLibraryModal<T>({
  required BuildContext context,
  String headerTitle = '교재보기',
  String libraryTitle = '교재함',
  List<BookData>? books,
  List<String> selectedTags = const [],
  String? notice,
  String? category,
}) {
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
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),
            Center(
              child: BookLibraryModal(
                headerTitle: headerTitle,
                libraryTitle: libraryTitle,
                books: books,
                selectedTags: selectedTags,
                notice: notice,
                category: category,
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<T?> showCommonBookLibraryModal<T>({
  required BuildContext context,
  List<String> selectedTags = const [],
}) {
  return showBookLibraryModal(
    context: context,
    headerTitle: '개념학습 교재',
    libraryTitle: '공통교재',
    selectedTags: selectedTags,
    notice: '해시태그와 연결되지 않은 기본 제공 교재입니다.',
    category: 'common',
  );
}

class BookWidget extends StatefulWidget {
  const BookWidget({
    super.key,
    this.book,
    this.initialEntryIndex,
    this.persistenceEnabled = true,
  });

  final BookData? book;
  final int? initialEntryIndex;
  final bool persistenceEnabled;

  static String routeName = 'book';
  static String routePath = '/book';

  @override
  State<BookWidget> createState() => _BookWidgetState();
}

class ResponsiveBookbagPage extends StatelessWidget {
  const ResponsiveBookbagPage({super.key});

  /// 필요한 변수는 현재 화면 너비와 방향이다.
  /// 작동 원리는 세로형 720px 이하에서만 모바일 책가방 목록을 열고, 태블릿·PC는 기존 교재 리더 진입을 유지하는 것이다.
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mobile = size.width <= 720 && size.height > size.width;
    return mobile
        ? const BookLibraryPage(libraryTitle: '책가방')
        : const BookWidget();
  }
}

class BookLibraryPage extends StatelessWidget {
  const BookLibraryPage({
    super.key,
    this.libraryTitle = '교재함',
    this.books,
    this.selectedTags = const [],
    this.notice,
    this.category,
    this.enableDownload = false,
  });

  final String libraryTitle;
  final List<BookData>? books;
  final List<String> selectedTags;
  final String? notice;
  final String? category;
  final bool enableDownload;

  Future<void> _downloadBook(BuildContext context, BookData book) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('웹에서는 교재를 기기에 저장할 수 없습니다.')));
      return;
    }
    try {
      final full = await TextbookStore.getById(book.id);
      if (full == null) {
        throw Exception('missing book');
      }
      await TextbookStore.download(full);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('교재를 저장했습니다.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('교재 저장에 실패했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mobile = size.width <= 720 && size.height > size.width;
    if (mobile) {
      return Scaffold(
        key: const ValueKey('bookbag-mobile-redesign'),
        backgroundColor: StudentDensityTokens.background,
        drawer: const AppDrawer(),
        body: SafeArea(
          child: Column(
            children: [
              Builder(
                builder: (headerContext) => Ios26TopBar(
                  brandColor: Colors.black,
                  showLevelIndicator: false,
                  onMenu: () => toggleAppDrawer(headerContext),
                  onTitleTap: () =>
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/student/dashboard',
                        (route) => false,
                      ),
                  items: studentTopNavItems(
                    context,
                    active: StudentTopDestination.bookbag,
                  ),
                ),
              ),
              Expanded(
                child: _BookLibraryLoader(
                  onSelect: (book) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => BookWidget(book: book)),
                    );
                  },
                  books: books,
                  title: libraryTitle,
                  selectedTags: selectedTags,
                  notice: notice,
                  category: category,
                  useLibrary: true,
                  enableDownload: enableDownload,
                  onDownload: enableDownload
                      ? (book) => _downloadBook(context, book)
                      : null,
                ),
              ),
            ],
          ),
        ),
      );
    }

    const primary = Color(0xFF202022);
    const bg = Color(0xFFF8F8F8);
    const border = Color(0x1A000000);

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
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF3B3B3B),
                    ),
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
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 14,
                          color: Color(0x14000000),
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.menu_book_rounded, color: primary, size: 24),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '문서고',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _BookLibraryLoader(
                      onSelect: (book) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BookWidget(book: book),
                          ),
                        );
                      },
                      books: books,
                      title: libraryTitle,
                      selectedTags: selectedTags,
                      notice: notice,
                      category: category,
                      useLibrary: true,
                      enableDownload: enableDownload,
                      onDownload: enableDownload
                          ? (book) => _downloadBook(context, book)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookLibraryModal extends StatelessWidget {
  const BookLibraryModal({
    super.key,
    this.headerTitle = '교재보기',
    this.libraryTitle = '교재함',
    this.books,
    this.selectedTags = const [],
    this.notice,
    this.category,
  });

  final String headerTitle;
  final String libraryTitle;
  final List<BookData>? books;
  final List<String> selectedTags;
  final String? notice;
  final String? category;

  @override
  /// 필요한 변수는 화면 크기와 교재 목록이다.
  /// 작동 원리는 데스크톱에서는 집중형 다이얼로그를, 작은 화면에서는 여백을 보존한 전체 높이 패널을 사용해 같은 교재함 흐름을 제공하는 것이다.
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final width = compact
            ? constraints.maxWidth - 24
            : constraints.maxWidth.clamp(720.0, 1120.0) * .82;
        final height = compact
            ? constraints.maxHeight - 24
            : constraints.maxHeight.clamp(560.0, 760.0) * .82;
        return Container(
          width: width,
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFFCFDFC),
            borderRadius: BorderRadius.circular(compact ? 24 : 28),
            border: Border.all(color: const Color(0x1A1F4D38)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x550A1D14),
                blurRadius: 48,
                offset: Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(context, compact: compact),
              const Divider(height: 1, color: Color(0xFFE0E8E2)),
              Expanded(
                child: _BookLibraryLoader(
                  onSelect: (book) {
                    final navigator = Navigator.of(
                      context,
                      rootNavigator: true,
                    );
                    navigator.pop();
                    navigator.push(
                      MaterialPageRoute(builder: (_) => BookWidget(book: book)),
                    );
                  },
                  books: books,
                  title: libraryTitle,
                  selectedTags: selectedTags,
                  notice: notice,
                  category: category,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 필요한 변수는 모달 제목과 작은 화면 여부다.
  /// 작동 원리는 닫기·현재 위치·교재 수 안내를 한 행에 묶어 목록을 읽기 전에 화면 목적을 명확히 하는 것이다.
  Widget _buildHeader(BuildContext context, {required bool compact}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 20,
        12,
        compact ? 16 : 24,
        12,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '닫기',
            icon: const Icon(Icons.close_rounded, size: 24),
            color: const Color(0xFF1F4D38),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headerTitle,
                  style: TextStyle(
                    color: const Color(0xFF183C2C),
                    fontSize: compact ? 20 : 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '학습 중인 교재와 공개 교재를 한 곳에서 이어 읽어요.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Color(0xFF68766E)),
                ),
              ],
            ),
          ),
          if (!compact)
            const Icon(Icons.auto_stories_rounded, color: Color(0xFF3DBE68)),
        ],
      ),
    );
  }
}

class _BookLibraryLoader extends StatelessWidget {
  const _BookLibraryLoader({
    required this.onSelect,
    required this.title,
    required this.selectedTags,
    this.books,
    this.notice,
    this.category,
    this.useLibrary = false,
    this.enableDownload = false,
    this.onDownload,
  });

  final ValueChanged<BookData> onSelect;
  final List<BookData>? books;
  final String title;
  final List<String> selectedTags;
  final String? notice;
  final String? category;
  final bool useLibrary;
  final bool enableDownload;
  final ValueChanged<BookData>? onDownload;

  @override
  Widget build(BuildContext context) {
    if (books != null) {
      return _BookLibraryBody(
        onSelect: onSelect,
        books: books!,
        title: title,
        selectedTags: selectedTags,
        notice: notice,
        enableDownload: enableDownload,
        onDownload: onDownload,
      );
    }
    if (useLibrary) {
      return FutureBuilder<List<BookData>>(
        future: TextbookStore.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data ?? const <BookData>[];
          return _BookLibraryBody(
            onSelect: onSelect,
            books: data,
            title: title,
            selectedTags: selectedTags,
            notice: notice,
            enableDownload: enableDownload,
            onDownload: onDownload,
          );
        },
      );
    }
    return FutureBuilder<List<BookData>>(
      future: TextbookStore.load(category: category, tags: selectedTags),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data ?? TextbookStore.fallbackBooks;
        return _BookLibraryBody(
          onSelect: onSelect,
          books: data,
          title: title,
          selectedTags: selectedTags,
          notice: notice,
          enableDownload: enableDownload,
          onDownload: onDownload,
        );
      },
    );
  }
}

class _BookLibraryBody extends StatelessWidget {
  const _BookLibraryBody({
    required this.onSelect,
    required this.books,
    this.title = '교재함',
    this.selectedTags = const [],
    this.notice,
    this.enableDownload = false,
    this.onDownload,
  });

  final ValueChanged<BookData> onSelect;
  final List<BookData> books;
  final String title;
  final List<String> selectedTags;
  final String? notice;
  final bool enableDownload;
  final ValueChanged<BookData>? onDownload;

  @override
  /// 필요한 변수는 교재 메타데이터·진행률·선택 태그다.
  /// 작동 원리는 목록 전체를 한 번만 순회해 표지, 학습 상태, 재개 행동을 같은 카드에 배치하고 교재 수가 많아도 지연 렌더링을 유지하는 것이다.
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mobile = size.width <= 720 && size.height > size.width;
    if (mobile) {
      return _MobileBookLibraryBody(
        onSelect: onSelect,
        books: books,
        title: title,
        selectedTags: selectedTags,
        notice: notice,
        enableDownload: enableDownload,
        onDownload: onDownload,
      );
    }

    const primaryLight = Color(0xFF3DBE68);
    const border = Color(0xFFDCE7DE);
    final hasTags = selectedTags.isNotEmpty;
    final showNotice = notice != null && notice!.trim().isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '총 ${books.length}권',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
        ),
        if (hasTags || showNotice)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasTags) ...[
                  const Text(
                    '선택한 개념',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: selectedTags
                        .map(
                          (tag) => Chip(
                            label: Text(
                              tag,
                              style: const TextStyle(fontSize: 11),
                            ),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (hasTags && showNotice) const SizedBox(height: 6),
                if (showNotice)
                  Text(
                    notice!,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
              ],
            ),
          ),
        Expanded(
          child: books.isEmpty
              ? const Center(
                  child: Text(
                    '표시할 교재가 없습니다.',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    final book = books[index];
                    final progress = book.progress.clamp(0.0, 1.0);
                    final label = book.progressLabel.isNotEmpty
                        ? book.progressLabel
                        : '${(progress * 100).round()}% 완료';
                    final showDownload = enableDownload && onDownload != null;
                    return TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 220),
                      tween: Tween(begin: 0, end: 1),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, child) => Transform.translate(
                        offset: Offset(0, (1 - t) * 8),
                        child: Opacity(opacity: t, child: child),
                      ),
                      child: InkWell(
                        onTap: () => onSelect(book),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFFFF),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: border, width: 1),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 12,
                                color: Color(0x120B301E),
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 62,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: book.coverColor ?? primaryLight,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x220B301E),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.auto_stories_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  ),
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
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 6,
                                        backgroundColor: const Color(
                                          0xFFE8E8E8,
                                        ),
                                        color: primaryLight,
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
                              if (showDownload)
                                InkWell(
                                  onTap: () => onDownload?.call(book),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: border,
                                        width: 1,
                                      ),
                                      color: Colors.white,
                                    ),
                                    child: Row(
                                      children: const [
                                        Icon(
                                          Icons.download,
                                          size: 14,
                                          color: Colors.black87,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          '다운로드',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (showDownload) const SizedBox(width: 10),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 20,
                                color: Color(0xFF6B8D78),
                              ),
                            ],
                          ),
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

class _MobileBookLibraryBody extends StatelessWidget {
  const _MobileBookLibraryBody({
    required this.onSelect,
    required this.books,
    required this.title,
    required this.selectedTags,
    required this.enableDownload,
    this.notice,
    this.onDownload,
  });

  final ValueChanged<BookData> onSelect;
  final List<BookData> books;
  final String title;
  final List<String> selectedTags;
  final String? notice;
  final bool enableDownload;
  final ValueChanged<BookData>? onDownload;

  /// 필요한 변수는 모바일 교재 목록·선택 태그·이어 읽기 상태다.
  /// 작동 원리는 첫 교재를 큰 재개 카드로 분리하고 나머지는 구분선 목록으로 압축해 한 화면의 정보량을 줄인다.
  @override
  Widget build(BuildContext context) {
    final showNotice = notice?.trim().isNotEmpty == true;
    final firstBook = books.isEmpty ? null : books.first;
    final remaining = books.length <= 1
        ? const <BookData>[]
        : books.skip(1).toList(growable: false);

    return CustomScrollView(
      key: const ValueKey('bookbag-mobile-scroll'),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 40,
                    height: 1,
                    letterSpacing: -2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${books.length}권의 교재',
                  style: const TextStyle(
                    fontSize: 16,
                    color: StudentDensityTokens.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (selectedTags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final tag in selectedTags)
                          Container(
                            margin: const EdgeInsets.only(right: 7),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: StudentDensityTokens.lineStrong,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (showNotice) ...[
                  const SizedBox(height: 12),
                  Text(
                    notice!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: StudentDensityTokens.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
        if (firstBook == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _MobileBookEmptyState(),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            sliver: SliverToBoxAdapter(
              child: _MobileContinueBookCard(
                book: firstBook,
                onTap: () => onSelect(firstBook),
              ),
            ),
          ),
          if (remaining.isNotEmpty) ...[
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(18, 26, 18, 12),
              sliver: SliverToBoxAdapter(
                child: Text(
                  '다른 교재',
                  style: TextStyle(
                    fontSize: 25,
                    letterSpacing: -.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
              sliver: SliverToBoxAdapter(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: StudentDensityTokens.lineStrong),
                  ),
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < remaining.length;
                        index++
                      ) ...[
                        _MobileBookRow(
                          book: remaining[index],
                          enableDownload: enableDownload,
                          onTap: () => onSelect(remaining[index]),
                          onDownload: onDownload == null
                              ? null
                              : () => onDownload!(remaining[index]),
                        ),
                        if (index != remaining.length - 1)
                          const Divider(
                            height: 1,
                            indent: 76,
                            color: Color(0xFFE7E7EA),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ] else
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ],
    );
  }
}

class _MobileContinueBookCard extends StatelessWidget {
  const _MobileContinueBookCard({required this.book, required this.onTap});

  final BookData book;
  final VoidCallback onTap;

  /// 필요한 변수는 첫 교재와 진행률이다.
  /// 작동 원리는 마지막 학습 교재를 검은 단일 카드로 강조하고 제목·진행·재개 동작만 보여 준다.
  @override
  Widget build(BuildContext context) {
    final progress = book.progress.clamp(0.0, 1.0);
    final started = progress > 0;
    return Material(
      key: const ValueKey('bookbag-mobile-continue'),
      color: const Color(0xFF202023),
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 60,
                    decoration: BoxDecoration(
                      color: book.coverColor ?? const Color(0xFF5E7C68),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.black,
                      size: 25,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                started ? '이어 읽기' : '첫 교재 시작',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  height: 1.2,
                  letterSpacing: -.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (book.subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  book.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ],
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                book.progressLabel.isNotEmpty
                    ? book.progressLabel
                    : '${(progress * 100).round()}% 읽음',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileBookRow extends StatelessWidget {
  const _MobileBookRow({
    required this.book,
    required this.enableDownload,
    required this.onTap,
    this.onDownload,
  });

  final BookData book;
  final bool enableDownload;
  final VoidCallback onTap;
  final VoidCallback? onDownload;

  /// 필요한 변수는 교재 표지·제목·진행률과 선택 동작이다.
  /// 작동 원리는 부가 설명을 한 줄로 제한하고 76px 안에서 읽기·다운로드 동작을 제공한다.
  @override
  Widget build(BuildContext context) {
    final progress = book.progress.clamp(0.0, 1.0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 62,
                decoration: BoxDecoration(
                  color: book.coverColor ?? const Color(0xFF5E7C68),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        letterSpacing: -.3,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book.progressLabel.isNotEmpty
                          ? book.progressLabel
                          : '${(progress * 100).round()}% 읽음',
                      style: const TextStyle(
                        fontSize: 13,
                        color: StudentDensityTokens.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (enableDownload && onDownload != null)
                IconButton(
                  tooltip: '교재 저장',
                  onPressed: onDownload,
                  icon: const Icon(Icons.download_rounded, size: 22),
                )
              else
                const Icon(Icons.chevron_right_rounded, size: 25),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileBookEmptyState extends StatelessWidget {
  const _MobileBookEmptyState();

  /// 필요한 변수는 없음이다.
  /// 작동 원리는 비어 있는 책가방에서 긴 안내 대신 큰 아이콘과 한 문장만 표시한다.
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.auto_stories_outlined,
            size: 48,
            color: StudentDensityTokens.muted,
          ),
          SizedBox(height: 14),
          Text(
            '아직 담긴 교재가 없습니다.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
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
    unawaited(TextbookStore.load());
  }

  Future<void> _refresh() async {
    final items = await BookmarkStore.load();
    if (!mounted) return;
    setState(() => _future = Future.value(items));
  }

  BookData? _findBook(String id) {
    for (final book in TextbookStore.cachedBooks) {
      if (book.id == id) return book;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF202022);
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
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF3B3B3B),
                    ),
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
                        '저장한 북마크가 없습니다.',
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
  static const Color kPrimary = StudentDensityTokens.ink;
  static const Color kBg = StudentDensityTokens.background;
  static const Color kCanvas = Color(0xFFE9EAED);
  static const Color kBorder = Color(0xFFE2E2E7);

  static const double _eraserRadius = 24;
  static const double _minPointDistance = 1.2;
  static const String _annotationKeyPrefix = 'textbook_annotations_v1_';

  final ScrollController _tocController = ScrollController();
  final ScrollController _contentController = ScrollController();
  final PageController _readerPageController = PageController();
  final GlobalKey _listViewKey = GlobalKey();
  double _averageItemHeight = 400;
  final ValueNotifier<int> _paintVersion = ValueNotifier<int>(0);
  Timer? _annotationSaveTimer;
  Timer? _scrollThrottleTimer;
  bool _paintFrameScheduled = false;

  List<BookChapter> _chapters = const [];
  List<_ContentEntry> _contentEntries = const [];
  List<_ParsedBookPage> _readerPagesCache = const [];
  List<GlobalKey> _sectionKeys = const [];
  List<bool> _chapterExpanded = const [];
  bool _initialized = false;
  bool _contentListenerAttached = false;
  final ValueNotifier<bool> _sidebarCollapsedNotifier = ValueNotifier<bool>(
    false,
  );
  bool _loadingFullBook = false;
  bool _pageMode = true;
  String _currentBookId = '';
  String _currentBookTitle = '';
  BookData? _currentBook;
  int? _pendingInitialEntryIndex;
  List<BookmarkItem> _bookmarks = <BookmarkItem>[];

  List<double> _sectionOffsets = <double>[];
  int _activeEntryIndex = 0;
  int _activeReaderPageIndex = 0;
  final ValueNotifier<int> _activeEntryNotifier = ValueNotifier<int>(0);

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
    if (widget.persistenceEnabled) {
      _loadBookmarks();
      _loadReaderPreference();
    }
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
      _annotationSaveTimer?.cancel();
      unawaited(_persistAnnotations());
      _initialized = false;
      _sectionOffsets = <double>[];
      _activeEntryIndex = 0;
      _activeReaderPageIndex = 0;
      _strokes.clear();
      _currentStroke = null;
      _eraserPosition = null;
      _highlighterStart = null;
      _pendingInitialEntryIndex = widget.initialEntryIndex;
      _currentBook = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_contentController.hasClients) _contentController.jumpTo(0);
        _initializeIfNeeded();
      });
      if (widget.persistenceEnabled) _loadBookmarks();
    }
  }

  @override
  void dispose() {
    _annotationSaveTimer?.cancel();
    _scrollThrottleTimer?.cancel();
    if (widget.persistenceEnabled) unawaited(_persistAnnotations());
    _tocController.dispose();
    _contentController.dispose();
    _readerPageController.dispose();
    _paintVersion.dispose();
    _activeEntryNotifier.dispose();
    _sidebarCollapsedNotifier.dispose();
    super.dispose();
  }

  bool get _supportsAnnotations => true;

  bool get _canPersistAnnotations => widget.persistenceEnabled && !kIsWeb;

  bool get _isDrawingTool => _toolMode != _ToolMode.none;

  Color get _activeInkColor =>
      _toolMode == _ToolMode.highlighter ? _highlighterColor : _penColor;

  List<_ParsedBookPage> get _readerPages => _readerPagesCache;

  /// 필요 변수: [_contentEntries]에 현재 교재의 장·절 콘텐츠가 준비되어 있어야 합니다.
  /// 작동 원리: 페이지 분할 결과를 교재 콘텐츠가 바뀔 때 한 번만 계산해 보관합니다.
  /// 빌드 및 페이지 이동 중에는 캐시를 재사용하여 전체 교재 재분할을 방지합니다.
  void _rebuildReaderPages() {
    _readerPagesCache = _paginateContentEntries(_contentEntries);
  }

  Future<void> _loadReaderPreference() async {
    final enabled = await TextbookReaderPreferences.loadPageMode();
    if (!mounted) return;
    setState(() {
      _pageMode = enabled;
      if (enabled) _syncReaderPageToActiveEntry();
    });
    if (enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncReaderPageToActiveEntry(jump: true);
      });
    }
  }

  Future<void> _setPageMode(bool value) async {
    if (_pageMode == value) return;
    setState(() {
      _pageMode = value;
      _toolMode = _ToolMode.none;
      if (value) {
        _syncReaderPageToActiveEntry(jump: true);
      }
    });
    await TextbookReaderPreferences.savePageMode(value);
  }

  void _bumpPaint() {
    if (_paintFrameScheduled) return;
    _paintFrameScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _paintFrameScheduled = false;
      if (_paintVersion.value < 0x7FFFFFFF) {
        _paintVersion.value = _paintVersion.value + 1;
      } else {
        _paintVersion.value = 0;
      }
    });
  }

  void _setToolMode(_ToolMode mode) {
    if (!_supportsAnnotations) {
      _showAnnotationBlocked();
      return;
    }
    setState(() => _toolMode = _toolMode == mode ? _ToolMode.none : mode);
  }

  void _initializeIfNeeded({bool attachListeners = false}) {
    if (!_initialized) {
      final book = widget.book ?? TextbookStore.cachedBooks.first;
      _currentBook = book;
      _currentBookId = book.id;
      _currentBookTitle = book.title;
      if (widget.persistenceEnabled) _recordBookView(book);
      _chapters = book.chapters;
      _contentEntries = _buildContentEntries(_chapters);
      _rebuildReaderPages();
      _sectionKeys = List<GlobalKey>.generate(
        _contentEntries.length,
        (_) => GlobalKey(),
      );
      // 처음에는 장 제목만 보여 주어 본문 선택지를 한눈에 파악하게 한다.
      // 현재 절로 이동하면 _setActiveReaderPage/_handleTocTap이 해당 장만 연다.
      _chapterExpanded = List<bool>.filled(_chapters.length, false);
      _pendingInitialEntryIndex ??= widget.initialEntryIndex;
      _initialized = true;
      if (widget.persistenceEnabled) {
        _loadAnnotations();
        _ensureFullBookLoaded();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cacheSectionOffsets();
        _applyInitialScroll();
        if (_pageMode) _syncReaderPageToActiveEntry(jump: true);
      });
    }
    if (attachListeners && !_contentListenerAttached) {
      _contentController.addListener(_handleContentScroll);
      _contentListenerAttached = true;
    }
  }

  void _recordBookView(BookData book) {
    final number = TextbookStore.displayNumberFor(book);
    unawaited(
      ActivityStore.recordBookView(
        bookId: book.id,
        bookNumber: number,
      ).catchError((_) {}),
    );
  }

  void _syncReaderPageToActiveEntry({bool jump = false}) {
    final pages = _readerPages;
    if (pages.isEmpty) {
      _activeReaderPageIndex = 0;
      return;
    }
    final targetIndex = pages.indexWhere(
      (page) => page.entryIndex == _activeEntryIndex,
    );
    final nextIndex = targetIndex < 0 ? 0 : targetIndex;
    _activeReaderPageIndex = nextIndex;
    if (!jump || !_readerPageController.hasClients) return;
    _readerPageController.jumpToPage(nextIndex);
  }

  void _jumpToReaderPageForEntry(int entryIndex) {
    final pages = _readerPages;
    if (pages.isEmpty) return;
    final index = pages.indexWhere((page) => page.entryIndex == entryIndex);
    if (index < 0) return;
    _setActiveReaderPage(index);
    if (_readerPageController.hasClients) {
      _readerPageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _setActiveReaderPage(int pageIndex) {
    final pages = _readerPages;
    if (pages.isEmpty || pageIndex < 0 || pageIndex >= pages.length) return;
    final entryIndex = pages[pageIndex].entryIndex;
    setState(() {
      _activeReaderPageIndex = pageIndex;
      _activeEntryIndex = entryIndex;
      _activeEntryNotifier.value = entryIndex;
      final chapterIndex = _contentEntries[entryIndex].chapterIndex;
      if (!_chapterExpanded[chapterIndex]) {
        _chapterExpanded[chapterIndex] = true;
      }
    });
  }

  Future<void> _ensureFullBookLoaded() async {
    if (_loadingFullBook) return;
    final book = _currentBook;
    if (book == null || book.chapters.isNotEmpty) return;
    if (book.id.trim().isEmpty) return;
    _loadingFullBook = true;
    try {
      final fetched = await TextbookStore.getById(book.id);
      if (!mounted) return;
      if (fetched == null || fetched.chapters.isEmpty) return;
      setState(() {
        _currentBook = fetched;
        _currentBookId = fetched.id;
        _currentBookTitle = fetched.title;
        _chapters = fetched.chapters;
        _contentEntries = _buildContentEntries(_chapters);
        _rebuildReaderPages();
        _sectionKeys = List<GlobalKey>.generate(
          _contentEntries.length,
          (_) => GlobalKey(),
        );
        // 교재를 다시 불러와도 목차는 접힌 상태로 시작해 모바일·데스크톱 밀도를 맞춘다.
        _chapterExpanded = List<bool>.filled(_chapters.length, false);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cacheSectionOffsets();
        _applyInitialScroll();
        if (_pageMode) _syncReaderPageToActiveEntry(jump: true);
      });
    } finally {
      _loadingFullBook = false;
    }
  }

  String _annotationKey() => '$_annotationKeyPrefix$_currentBookId';

  void _showAnnotationBlocked() {
    if (!mounted) return;
    final message = _pageMode
        ? '페이지 보기에서는 필기 도구를 사용할 수 없습니다.'
        : '웹에서는 필기 저장이 지원되지 않습니다.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadAnnotations() async {
    if (!_canPersistAnnotations) return;
    if (_currentBookId.isEmpty) return;
    final raw = await LocalDb.instance.getString(_annotationKey());
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final loaded = <_Stroke>[];
      for (final item in decoded) {
        if (item is Map) {
          loaded.add(_strokeFromJson(Map<String, dynamic>.from(item)));
        }
      }
      if (!mounted) return;
      setState(() {
        _strokes
          ..clear()
          ..addAll(loaded);
      });
      _bumpPaint();
    } catch (_) {
      // Ignore corrupted annotation payloads.
    }
  }

  void _scheduleAnnotationSave() {
    if (!_canPersistAnnotations) return;
    _annotationSaveTimer?.cancel();
    _annotationSaveTimer = Timer(
      const Duration(milliseconds: 600),
      () => unawaited(_persistAnnotations()),
    );
  }

  Future<void> _persistAnnotations() async {
    if (!_canPersistAnnotations) return;
    if (_currentBookId.isEmpty) return;
    final key = _annotationKey();
    if (_strokes.isEmpty) {
      await LocalDb.instance.delete(key);
      return;
    }
    final payload = jsonEncode(_strokes.map(_strokeToJson).toList());
    await LocalDb.instance.setString(key, payload);
  }

  // 필요 변수: 필기 획의 색상·굵기·좌표. 작동 원리: 로컬 DB에 저장할 JSON 호환 맵으로 직렬화한다.
  Map<String, dynamic> _strokeToJson(_Stroke stroke) {
    return {
      'color': stroke.color.toARGB32(),
      'width': stroke.width,
      'points': stroke.points
          .map((point) => [point.dx, point.dy])
          .toList(growable: false),
    };
  }

  // 필요 변수: 저장된 필기 JSON. 작동 원리: 색상과 좌표를 검증해 화면 획 객체로 복원한다.
  _Stroke _strokeFromJson(Map<String, dynamic> json) {
    final colorValue =
        (json['color'] as num?)?.toInt() ?? Colors.black.toARGB32();
    final width = (json['width'] as num?)?.toDouble() ?? 3.0;
    final stroke = _Stroke(color: Color(colorValue), width: width);
    final points = json['points'];
    if (points is List) {
      for (final entry in points) {
        if (entry is List && entry.length >= 2) {
          final dx = (entry[0] as num?)?.toDouble();
          final dy = (entry[1] as num?)?.toDouble();
          if (dx != null && dy != null) {
            stroke.addPoint(Offset(dx, dy));
          }
        }
      }
    }
    return stroke;
  }

  void _cacheSectionOffsets() {
    if (_contentEntries.isEmpty) return;

    final listBox =
        _listViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (listBox == null) return;

    final exact = <int, double>{};
    var totalKnownHeight = 0.0;
    var knownCount = 0;

    for (var i = 0; i < _sectionKeys.length; i++) {
      final box =
          _sectionKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final viewportPosition = box.localToGlobal(
          Offset.zero,
          ancestor: listBox,
        );
        exact[i] = viewportPosition.dy + _contentController.offset;
        totalKnownHeight += box.size.height;
        knownCount++;
      }
    }

    if (knownCount > 0) {
      _averageItemHeight = totalKnownHeight / knownCount;
    }

    // Precompute next known index for each position in a single backward pass
    final nextKnown = List<int>.filled(_sectionKeys.length, -1);
    var lastKnown = -1;
    for (var i = _sectionKeys.length - 1; i >= 0; i--) {
      nextKnown[i] = lastKnown;
      if (exact.containsKey(i)) {
        lastKnown = i;
      }
    }

    final offsets = List<double>.filled(_sectionKeys.length, 0);
    var lastIndex = -1;
    var lastOffset = 0.0;

    for (var i = 0; i < _sectionKeys.length; i++) {
      if (exact.containsKey(i)) {
        offsets[i] = exact[i]!;
        lastIndex = i;
        lastOffset = exact[i]!;
        continue;
      }

      final nextIndex = nextKnown[i];
      final nextOffset = nextIndex >= 0 ? exact[nextIndex] : null;

      if (lastIndex >= 0 && nextOffset != null) {
        final fraction = (i - lastIndex) / (nextIndex - lastIndex);
        offsets[i] = lastOffset + (nextOffset - lastOffset) * fraction;
      } else if (nextOffset != null) {
        final estimatedHeightPerItem = nextIndex > 0
            ? nextOffset / nextIndex
            : _averageItemHeight;
        offsets[i] = i * estimatedHeightPerItem;
      } else if (lastIndex >= 0) {
        offsets[i] = lastOffset + (i - lastIndex) * _averageItemHeight;
      } else {
        offsets[i] = i * _averageItemHeight;
      }
    }

    _sectionOffsets = offsets;
  }

  void _applyInitialScroll() {
    final target = _pendingInitialEntryIndex;
    if (target == null) return;
    if (target < 0 || target >= _contentEntries.length) {
      _pendingInitialEntryIndex = null;
      return;
    }
    _pendingInitialEntryIndex = null;
    if (_pageMode) {
      _activeEntryIndex = target;
      _activeEntryNotifier.value = target;
      _jumpToReaderPageForEntry(target);
      return;
    }
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BookmarkListPage()));
  }

  void _handleContentScroll() {
    if (_sectionOffsets.isEmpty) return;
    final timer = _scrollThrottleTimer;
    if (timer != null && timer.isActive) {
      return;
    }
    _scrollThrottleTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) _updateActiveEntry();
    });
  }

  void _updateActiveEntry() {
    if (_sectionOffsets.isEmpty) return;
    if (!_contentController.hasClients) return;

    final maxExtent = _contentController.position.maxScrollExtent;
    final currentOffset = _contentController.offset;

    int newIndex;
    // If scrolled to the bottom, force last entry
    if (currentOffset >= maxExtent - 1) {
      newIndex = _sectionOffsets.length - 1;
    } else {
      final offset = currentOffset + 12;
      newIndex = 0;
      for (var i = 0; i < _sectionOffsets.length; i++) {
        if (_sectionOffsets[i] <= offset) {
          newIndex = i;
        } else {
          break;
        }
      }
    }

    if (newIndex == _activeEntryIndex) return;
    _activeEntryIndex = newIndex;
    _activeEntryNotifier.value = newIndex;

    final chapterIndex = _contentEntries[newIndex].chapterIndex;
    if (!_chapterExpanded[chapterIndex]) {
      setState(() {
        _chapterExpanded[chapterIndex] = true;
      });
    }
  }

  Future<void> _scrollToEntry(int entryIndex) async {
    final context = _sectionKeys[entryIndex].currentContext;
    if (context != null) {
      await Scrollable.ensureVisible(
        context,
        alignment: 0.1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }

    if (_sectionOffsets.length > entryIndex) {
      final target = _sectionOffsets[entryIndex];
      if (_contentController.hasClients) {
        _contentController.jumpTo(
          target.clamp(
            _contentController.position.minScrollExtent,
            _contentController.position.maxScrollExtent,
          ),
        );
      }
    }
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
    if (_pageMode) {
      _jumpToReaderPageForEntry(entry.entryIndex);
      return;
    }
    _scrollToEntry(entry.entryIndex);
  }

  void _goToPreviousEntry() {
    if (_pageMode) {
      if (_activeReaderPageIndex <= 0) return;
      final next = _activeReaderPageIndex - 1;
      _setActiveReaderPage(next);
      if (_readerPageController.hasClients) {
        _readerPageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    if (_activeEntryIndex <= 0) return;
    _scrollToEntry(_activeEntryIndex - 1);
  }

  void _goToNextEntry() {
    if (_pageMode) {
      final pages = _readerPages;
      if (_activeReaderPageIndex >= pages.length - 1) return;
      final next = _activeReaderPageIndex + 1;
      _setActiveReaderPage(next);
      if (_readerPageController.hasClients) {
        _readerPageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
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
                                          if (_pageMode) {
                                            _jumpToReaderPageForEntry(
                                              result.entryIndex,
                                            );
                                            return;
                                          }
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
      final combined = [entry.title, ...entry.paragraphs].join(' ');
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
    if (!_supportsAnnotations) {
      _showAnnotationBlocked();
      return;
    }
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
                  const Text(
                    'Highlighter Color',
                    style: TextStyle(fontSize: 14),
                  ),
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
                  const Text(
                    'Highlighter Width',
                    style: TextStyle(fontSize: 14),
                  ),
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

  Offset _eventToContentPosition(PointerEvent event) {
    const topPadding = 20.0;
    const leftPadding = 20.0;
    return Offset(
      event.localPosition.dx - leftPadding,
      event.localPosition.dy + _contentController.offset - topPadding,
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_isDrawingTool) return;
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    final position = _eventToContentPosition(event);
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
    final position = _eventToContentPosition(event);
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
    _scheduleAnnotationSave();
    _bumpPaint();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;
    _activePointer = null;
    _currentStroke = null;
    _eraserPosition = null;
    _highlighterStart = null;
    _scheduleAnnotationSave();
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

  // 필요 변수: 시작 위치와 형광펜 설정. 작동 원리: 반투명 직선 획을 현재 입력으로 만든다.
  void _startHighlighter(Offset position) {
    _highlighterStart = position;
    _currentStroke = _Stroke(
      color: _highlighterColor.withValues(alpha: 0.45),
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact =
                        constraints.maxWidth <=
                        StudentDensityTokens.mobileBreakpoint;
                    return Column(
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!compact) _buildSidebar(context),
                              Expanded(child: _buildContent(context)),
                            ],
                          ),
                        ),
                        if (compact) _buildMobileReaderRail(),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 필요한 변수는 현재 페이지·전체 페이지 수와 목차 항목이다.
  /// 작동 원리: 모바일에서는 사이드바를 숨기되 하단에 진행률과 목차 진입점을 고정해
  /// 읽는 중에도 페이지 이동과 장 선택을 잃지 않게 한다.
  Widget _buildMobileReaderRail() {
    final total = _pageMode ? _readerPages.length : _contentEntries.length;
    final current = total == 0
        ? 0
        : (_pageMode ? _activeReaderPageIndex + 1 : _activeEntryIndex + 1)
              .clamp(1, total);
    final progress = total == 0 ? 0.0 : current / total;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '학습 진행  $current/${total == 0 ? 0 : total}',
                  style: const TextStyle(
                    color: StudentDensityTokens.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    value: progress,
                    backgroundColor: StudentDensityTokens.surfaceMuted,
                    valueColor: const AlwaysStoppedAnimation(Colors.black),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _openMobileToc,
            icon: const Icon(Icons.menu_book_outlined, size: 15),
            label: const Text('목차'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              minimumSize: const Size(80, 36),
              padding: const EdgeInsets.symmetric(horizontal: 11),
              side: const BorderSide(color: Colors.black),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 필요한 변수는 현재 목차의 보이는 항목과 선택 콜백이다.
  /// 작동 원리: 모바일 하단 목차 버튼을 누르면 장·절만 담은 바텀시트를 열고,
  /// 항목 선택 뒤에는 기존 페이지 이동 로직을 재사용한다.
  Future<void> _openMobileToc() async {
    final entries = _visibleTocEntries();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '목차',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '목차 닫기',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final isChapter = entry.level == 0;
                    final active = entry.entryIndex == _activeEntryIndex;
                    return ListTile(
                      contentPadding: EdgeInsets.fromLTRB(
                        isChapter ? 20 : 42,
                        2,
                        16,
                        2,
                      ),
                      leading: Icon(
                        isChapter
                            ? Icons.menu_book_outlined
                            : Icons.article_outlined,
                        color: active ? kPrimary : Colors.black45,
                        size: 18,
                      ),
                      title: Text(
                        entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? kPrimary : Colors.black87,
                          fontSize: isChapter ? 14 : 13,
                          fontWeight: isChapter || active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _handleTocTap(entry);
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
  }

  /// 필요한 변수는 현재 교재 제목·페이지 진행률·보기 모드와 화면 너비다.
  /// 작동 원리: 학생 디자인의 학습 헤더를 유지하면서 모바일에서는 핵심 조작만 남기고,
  /// 데스크톱에서는 교재 식별·진행률·북마크·보기 전환·학습 완료를 한 줄에 배치한다.
  Widget _buildHeader(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth <= StudentDensityTokens.mobileBreakpoint;
        final totalPages = _readerPages.length;
        final currentPage = totalPages == 0
            ? 0
            : (_activeReaderPageIndex + 1).clamp(1, totalPages);
        final progress = totalPages == 0 ? 0.0 : currentPage / totalPages;
        return Container(
          height: compact ? 62 : 68,
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 22),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: kBorder)),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: '교재함으로 돌아가기',
                iconSize: compact ? 27 : 30,
                icon: const Icon(Icons.arrow_back_rounded, color: kPrimary),
                onPressed: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 4),
              Container(
                width: compact ? 30 : 34,
                height: compact ? 30 : 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'A',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 15 : 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: compact ? 1 : 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentBookTitle.isEmpty ? '교재 읽기' : _currentBookTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: compact ? 13 : 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (!compact)
                      Text(
                        'p. $currentPage / $totalPages · 학습 위치를 이어 읽기',
                        style: const TextStyle(
                          color: StudentDensityTokens.muted,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
              if (!compact) ...[
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${(progress * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 150,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                minHeight: 6,
                                value: progress,
                                backgroundColor:
                                    StudentDensityTokens.surfaceMuted,
                                valueColor: const AlwaysStoppedAnimation(
                                  Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _headerAction(
                  icon: _isBookmarked(_activeEntryIndex)
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  onTap: _contentEntries.isEmpty ? null : _handleAddBookmark,
                ),
                const SizedBox(width: 8),
                _headerViewMode(compact: compact),
                const SizedBox(width: 8),
                if (!compact)
                  FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(88, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      '학습 완료',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 필요한 변수는 버튼 아이콘과 탭 동작이다.
  /// 작동 원리: 리더 헤더의 작은 조작 버튼을 공통 외형으로 렌더링한다.
  Widget _headerAction({required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, color: Colors.black, size: 21),
      ),
    );
  }

  /// 필요한 변수는 현재 지면/스크롤 모드와 화면 너비다.
  /// 작동 원리: 기준 디자인의 두 상태 토글을 유지하되 작은 화면에서는 텍스트를 감춘다.
  Widget _headerViewMode({required bool compact}) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: StudentDensityTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _headerModeIcon(
            icon: Icons.view_carousel_outlined,
            active: _pageMode,
            onTap: () => unawaited(_setPageMode(true)),
          ),
          if (!compact)
            _headerModeIcon(
              icon: Icons.view_agenda_outlined,
              active: !_pageMode,
              onTap: () => unawaited(_setPageMode(false)),
            ),
        ],
      ),
    );
  }

  /// 필요한 변수는 보기 모드의 아이콘·활성 상태·탭 동작이다.
  /// 작동 원리: 활성 모드만 검은 원형 배경으로 강조해 현재 읽기 방식을 즉시 보여 준다.
  Widget _headerModeIcon({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: active ? Colors.black : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: active ? Colors.white : Colors.black54,
          size: 17,
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _sidebarCollapsedNotifier,
      builder: (context, collapsed, _) {
        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: collapsed ? 0 : 280,
              child: ClipRect(
                child: collapsed
                    ? const SizedBox.shrink()
                    : Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(right: BorderSide(color: kBorder)),
                        ),
                        child: Column(
                          children: [
                            _buildTocHeader(),
                            Expanded(child: _buildTocList()),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: kBorder,
                            ),
                            _buildSidebarTools(),
                          ],
                        ),
                      ),
              ),
            ),
            SizedBox(
              width: 24,
              child: Align(
                alignment: Alignment.center,
                child: _buildCollapseHandle(collapsed: collapsed),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTocHeader() {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONTENTS',
            style: TextStyle(
              color: StudentDensityTokens.muted,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 3),
          Text(
            '목차',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildTocList() {
    return ValueListenableBuilder<int>(
      valueListenable: _activeEntryNotifier,
      builder: (context, activeEntryIndex, _) {
        final entries = _visibleTocEntries();
        return Scrollbar(
          thumbVisibility: true,
          controller: _tocController,
          child: ListView.builder(
            controller: _tocController,
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final isChapter = entry.level == 0;
              final isExpanded = _chapterExpanded[entry.chapterIndex];
              final hasActiveEntry =
                  activeEntryIndex >= 0 &&
                  activeEntryIndex < _contentEntries.length;
              final activeChapterIndex = hasActiveEntry
                  ? _contentEntries[activeEntryIndex].chapterIndex
                  : -1;
              final isCurrentChapter =
                  isChapter && entry.chapterIndex == activeChapterIndex;
              final isCurrentSection =
                  !isChapter && entry.entryIndex == activeEntryIndex;
              final editorialPage =
                  entry.entryIndex >= 0 &&
                      entry.entryIndex < _contentEntries.length
                  ? _contentEntries[entry.entryIndex].editorialPage
                  : null;
              final selectedIconColor = isCurrentSection
                  ? kPrimary
                  : StudentDensityTokens.muted;

              return InkWell(
                onTap: () => _handleTocTap(entry),
                child: Container(
                  height: isChapter ? 58 : 44,
                  padding: EdgeInsets.only(
                    left: isChapter ? 18 : 34,
                    right: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isChapter
                        ? isCurrentChapter
                              ? kPrimary
                              : Colors.white
                        : isCurrentSection
                        ? StudentDensityTokens.surfaceMuted
                        : Colors.white,
                    border: Border(
                      left: BorderSide(
                        color: isCurrentSection || isCurrentChapter
                            ? kPrimary
                            : Colors.transparent,
                        width: 3,
                      ),
                      bottom: const BorderSide(color: kBorder, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (isChapter)
                        Container(
                          width: 34,
                          height: 19,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isCurrentChapter
                                ? const Color(0x33FFFFFF)
                                : StudentDensityTokens.surfaceMuted,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'CH${entry.chapterIndex + 1}',
                            style: TextStyle(
                              color: isCurrentChapter
                                  ? Colors.white
                                  : StudentDensityTokens.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .2,
                            ),
                          ),
                        ),
                      if (isChapter) const SizedBox(width: 8),
                      Icon(
                        isChapter
                            ? Icons.menu_book_rounded
                            : (editorialPage != null
                                  ? _bookPageTemplateIcon(
                                      editorialPage.template,
                                    )
                                  : Icons.article_outlined),
                        size: 15,
                        color: isChapter
                            ? isCurrentChapter
                                  ? Colors.white
                                  : StudentDensityTokens.muted
                            : selectedIconColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.title,
                          style: TextStyle(
                            color: isChapter
                                ? isCurrentChapter
                                      ? Colors.white
                                      : Colors.black87
                                : isCurrentSection
                                ? kPrimary
                                : StudentDensityTokens.ink,
                            fontSize: isChapter ? 14 : 13,
                            fontWeight: isChapter || isCurrentSection
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (entry.hasChildren)
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_down_sharp
                              : Icons.keyboard_arrow_right_sharp,
                          size: 22,
                          color: isChapter
                              ? isCurrentChapter
                                    ? Colors.white
                                    : StudentDensityTokens.muted
                              : isCurrentSection
                              ? kPrimary
                              : StudentDensityTokens.ink,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSidebarTools() {
    final total = _pageMode ? _readerPages.length : _contentEntries.length;
    final hasEntries = _contentEntries.isNotEmpty;
    final annotationsEnabled = _supportsAnnotations && !_pageMode;
    return ValueListenableBuilder<int>(
      valueListenable: _activeEntryNotifier,
      builder: (context, activeEntryIndex, _) {
        final isBookmarked = hasEntries && _isBookmarked(activeEntryIndex);
        final currentNumber = _pageMode
            ? (_readerPages.isEmpty ? 0 : _activeReaderPageIndex + 1)
            : (total == 0 ? 0 : activeEntryIndex + 1);
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
                    active: annotationsEnabled && _toolMode == _ToolMode.pen,
                    onTap: annotationsEnabled
                        ? () => _setToolMode(_ToolMode.pen)
                        : _showAnnotationBlocked,
                  ),
                  const SizedBox(width: 8),
                  _toolIcon(
                    icon: Icons.brush,
                    active:
                        annotationsEnabled &&
                        _toolMode == _ToolMode.highlighter,
                    onTap: annotationsEnabled
                        ? () => _setToolMode(_ToolMode.highlighter)
                        : _showAnnotationBlocked,
                  ),
                  const SizedBox(width: 8),
                  _toolIcon(
                    icon: Icons.color_lens_sharp,
                    active: false,
                    onTap: annotationsEnabled
                        ? _openPenSettings
                        : _showAnnotationBlocked,
                    foreground: _activeInkColor,
                  ),
                  const SizedBox(width: 8),
                  _toolIcon(
                    icon: Icons.cleaning_services_outlined,
                    active: annotationsEnabled && _toolMode == _ToolMode.eraser,
                    onTap: annotationsEnabled
                        ? () => _setToolMode(_ToolMode.eraser)
                        : _showAnnotationBlocked,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _navIcon(Icons.search_sharp, kPrimary, onTap: _openSearch),
                  const SizedBox(width: 8),
                  _navIcon(
                    Icons.arrow_back_ios_sharp,
                    StudentDensityTokens.surfaceMuted,
                    onTap: _goToPreviousEntry,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 92,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(width: 1, color: kBorder),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$currentNumber / $total',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _navIcon(
                    Icons.arrow_forward_ios_sharp,
                    StudentDensityTokens.surfaceMuted,
                    onTap: _goToNextEntry,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _toolIcon({
    required IconData icon,
    required bool active,
    required VoidCallback? onTap,
    Color? foreground,
  }) {
    final bg = active ? kPrimary : Colors.white;
    final fg = foreground ?? (active ? Colors.white : StudentDensityTokens.ink);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder, width: 1),
        ),
        child: Icon(icon, color: fg, size: 20),
      ),
    );
  }

  Widget _navIcon(IconData icon, Color bg, {VoidCallback? onTap}) {
    final foreground = bg == kPrimary ? Colors.white : StudentDensityTokens.ink;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bg == kPrimary ? kPrimary : kBorder),
        ),
        child: Icon(icon, color: foreground, size: 19),
      ),
    );
  }

  Widget _buildCollapseHandle({required bool collapsed}) {
    return GestureDetector(
      onTap: () => _sidebarCollapsedNotifier.value = !collapsed,
      child: Container(
        width: 18,
        height: 80,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: kBorder),
            right: BorderSide(color: kBorder),
            bottom: BorderSide(color: kBorder),
          ),
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: Icon(
            collapsed ? Icons.chevron_right : Icons.chevron_left,
            key: ValueKey<bool>(collapsed),
            size: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_pageMode) {
      return _buildPagedContent(context);
    }

    final showAnnotationOverlay =
        _isDrawingTool ||
        _strokes.isNotEmpty ||
        _currentStroke != null ||
        _eraserPosition != null;

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          Scrollbar(
            thumbVisibility: true,
            child: ListView.builder(
              key: _listViewKey,
              controller: _contentController,
              physics: _isDrawingTool
                  ? const NeverScrollableScrollPhysics()
                  : null,
              padding: const EdgeInsets.fromLTRB(20, 20, 24, 40),
              itemCount: _contentEntries.length,
              itemBuilder: (context, i) => _buildContentBlock(i),
            ),
          ),
          if (showAnnotationOverlay)
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
                      scrollOffset: _contentController.hasClients
                          ? _contentController.offset
                          : 0.0,
                      repaint: _paintVersion,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPagedContent(BuildContext context) {
    final pages = _readerPages;
    if (pages.isEmpty) {
      return const Center(child: Text('표시할 교재 페이지가 없습니다.'));
    }

    final pageIndex = _activeReaderPageIndex.clamp(0, pages.length - 1).toInt();
    if (_activeReaderPageIndex != pageIndex) {
      _activeReaderPageIndex = pageIndex;
    }

    return Container(
      color: kCanvas,
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: StudentDensityTokens.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.menu_book_outlined,
                    size: 17,
                    color: kPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'READING',
                        style: TextStyle(
                          color: StudentDensityTokens.muted,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        _currentBookTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: StudentDensityTokens.surfaceMuted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${pageIndex + 1} / ${pages.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showPageButtons = constraints.maxWidth >= 860;
                return Stack(
                  children: [
                    PageView.builder(
                      controller: _readerPageController,
                      itemCount: pages.length,
                      onPageChanged: _setActiveReaderPage,
                      itemBuilder: (context, index) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: showPageButtons ? 72 : 18,
                              vertical: 18,
                            ),
                            child: _BookPaperPage(
                              page: pages[index],
                              pageNumber: index + 1,
                              totalPages: pages.length,
                              resolveImage: _resolveImageProvider,
                              buildParagraph: (text) => _buildLatexAware(
                                text,
                                compact: pages[index].editorialPage != null,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (showPageButtons) ...[
                      Positioned(
                        left: 20,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _buildPageTurnButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: '이전 페이지',
                            enabled: pageIndex > 0,
                            onTap: _goToPreviousEntry,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 20,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _buildPageTurnButton(
                            icon: Icons.arrow_forward_rounded,
                            tooltip: '다음 페이지',
                            enabled: pageIndex < pages.length - 1,
                            onTap: _goToNextEntry,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 필요한 변수는 이동 방향·활성 여부·페이지 이동 콜백이다.
  /// 작동 원리는 넓은 화면에서 종이 양옆에 중성 버튼을 고정해 스와이프 없이도 다음 지면으로 이동하게 한다.
  Widget _buildPageTurnButton({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled ? Colors.white : const Color(0x66FFFFFF),
        shape: const CircleBorder(side: BorderSide(color: kBorder)),
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 20,
              color: enabled
                  ? StudentDensityTokens.ink
                  : StudentDensityTokens.faint,
            ),
          ),
        ),
      ),
    );
  }

  static const double _viewportOverscan = 800.0; // ~50 lines worth of pixels

  Widget _buildContentBlock(int i) {
    final entry = _contentEntries[i];
    final graphDocument = entry.graph;

    // Viewport culling: skip rendering far outside visible area
    if (_contentController.hasClients && _sectionOffsets.length > i) {
      final itemTop = _sectionOffsets[i];
      final viewportTop = _contentController.offset - _viewportOverscan;
      final viewportBottom =
          _contentController.offset +
          _contentController.position.viewportDimension +
          _viewportOverscan;
      if (itemTop + _averageItemHeight < viewportTop ||
          itemTop > viewportBottom) {
        // Return placeholder WITHOUT key to avoid "Multiple widgets used the
        // same GlobalKey" when the real block also uses _sectionKeys[i].
        return Container(
          height: _averageItemHeight,
          margin: EdgeInsets.only(top: i == 0 ? 0 : 24),
        );
      }
    }

    return Container(
      key: _sectionKeys[i],
      margin: EdgeInsets.only(top: i == 0 ? 0 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.title,
            style: TextStyle(
              fontSize: entry.level == 0 ? 24 : 18,
              fontWeight: entry.level == 0 ? FontWeight.w800 : FontWeight.w700,
              color: kPrimary,
            ),
          ),
          const SizedBox(height: 10),
          for (final paragraph in entry.paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RepaintBoundary(child: _buildLatexAware(paragraph)),
            ),
          for (final visual in entry.visuals) _BookVisualCard(visual: visual),
          if (graphDocument != null) ...[
            const SizedBox(height: 16),
            _TextbookGraphCard(document: graphDocument),
          ],
          for (final image in entry.images)
            if (image.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image(
                    image: _resolveImageProvider(image),
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, __) => Container(
                      height: 180,
                      color: const Color(0xFFEDEDED),
                      alignment: Alignment.center,
                      child: const Text(
                        '이미지를 불러올 수 없습니다.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  final Map<String, List<ContentBlock>> _latexCache =
      <String, List<ContentBlock>>{};

  Widget _buildLatexAware(String text, {bool compact = false}) {
    final isCompactWidth = MediaQuery.sizeOf(context).width < 420;
    final blocks = _latexCache.putIfAbsent(
      text,
      () => parseTextWithLatex(text),
    );
    return ContentBlocksView(
      inline: true,
      blocks: blocks,
      textStyle: TextStyle(
        fontSize: (isCompactWidth || compact) ? 12 : 13,
        height: compact ? 1.4 : 1.45,
        color: const Color(0xFF242526),
      ),
      latexStyle: TextStyle(
        fontSize: (isCompactWidth || compact) ? 12 : 13,
        color: const Color(0xFF242526),
      ),
    );
  }

  ImageProvider _resolveImageProvider(String source) {
    final trimmed = source.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return NetworkImage(trimmed);
    }
    if (trimmed.startsWith('/')) {
      return NetworkImage(ApiClient.resourceUrl(trimmed));
    }
    return AssetImage(trimmed);
  }

  List<_TocEntry> _visibleTocEntries() {
    final entries = <_TocEntry>[];
    for (var i = 0; i < _contentEntries.length; i++) {
      final entry = _contentEntries[i];
      if (entry.level == 0) {
        final chapter = _chapters[entry.chapterIndex];
        final chapterHasChildren = chapter.pages.isNotEmpty
            ? chapter.pages.length > 1
            : chapter.sections.isNotEmpty;
        entries.add(
          _TocEntry(
            entryIndex: i,
            chapterIndex: entry.chapterIndex,
            level: 0,
            title: entry.title,
            hasChildren: chapterHasChildren,
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

class _ContentEntry {
  const _ContentEntry({
    required this.chapterIndex,
    required this.level,
    required this.title,
    required this.paragraphs,
    required this.images,
    this.graph,
    this.visuals = const [],
    this.editorialPage,
  });

  final int chapterIndex;
  final int level;
  final String title;
  final List<String> paragraphs;
  final List<String> images;
  final AiFlowGraphDocument? graph;
  final List<BookVisual> visuals;
  final BookPage? editorialPage;
}

class _ParsedBookPage {
  const _ParsedBookPage({
    required this.entryIndex,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.chapterNumber,
    required this.title,
    required this.paragraphs,
    required this.images,
    required this.partNumber,
    required this.partTotal,
    this.graph,
    this.visuals = const [],
    this.editorialPage,
  });

  final int entryIndex;
  final int chapterIndex;
  final String chapterTitle;
  final int chapterNumber;
  final String title;
  final List<String> paragraphs;
  final List<String> images;
  final int partNumber;
  final int partTotal;
  final AiFlowGraphDocument? graph;
  final List<BookVisual> visuals;
  final BookPage? editorialPage;
}

/// 필요한 변수는 절의 JSXGraph 문서다.
/// 작동 원리는 실제 지면 안에 그래프와 조작 안내를 함께 배치해 설명과 실험을 한 시야에서 연결하는 것이다.
class _TextbookGraphCard extends StatelessWidget {
  const _TextbookGraphCard({required this.document});

  final AiFlowGraphDocument document;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return Container(
      height: compact ? 192 : 228,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StudentDensityTokens.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
            decoration: const BoxDecoration(
              color: StudentDensityTokens.surfaceMuted,
              border: Border(
                bottom: BorderSide(color: StudentDensityTokens.line),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 15,
                  color: StudentDensityTokens.ink,
                ),
                SizedBox(width: 7),
                Text(
                  'INTERACTIVE FIGURE',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w800,
                    color: StudentDensityTokens.ink,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '슬라이더로 그래프의 변화를 관찰하세요.',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: StudentDensityTokens.muted,
                    ),
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

/// 필요한 변수는 시각 블록의 종류와 표시 데이터다.
/// 작동 원리는 공식·표·풀이 단계·부호표를 텍스트와 분리된 카드로 보여 주어 실제 교재의 편집 지면을 만든다.
class _BookVisualCard extends StatelessWidget {
  const _BookVisualCard({required this.visual});

  final BookVisual visual;

  @override
  Widget build(BuildContext context) {
    final content = switch (visual.kind) {
      'formula' => _buildFormula(),
      'table' || 'signChart' => _buildTable(),
      'steps' || 'flow' => _buildSequence(),
      'image' => _buildImage(),
      _ => _buildCallout(),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StudentDensityTokens.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            decoration: const BoxDecoration(
              color: StudentDensityTokens.ink,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 13),
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
                            color: StudentDensityTokens.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        visual.kind.toUpperCase(),
                        style: const TextStyle(
                          color: StudentDensityTokens.muted,
                          fontSize: 9,
                          letterSpacing: .7,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  content,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormula() {
    final blocks = parseTextWithLatex(r'$' + visual.formula + r'$');
    return Center(
      child: ContentBlocksView(
        inline: false,
        blocks: blocks,
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        latexStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildTable() {
    final rows = visual.rows.isEmpty ? [visual.items] : visual.rows;
    return Table(
      border: TableBorder.all(color: StudentDensityTokens.lineStrong),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        for (final row in rows)
          TableRow(
            children: [
              for (final cell in row)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Text(
                    cell,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, height: 1.3),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildSequence() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < visual.items.length; index++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: index == visual.items.length - 1
                  ? StudentDensityTokens.ink
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: StudentDensityTokens.lineStrong),
            ),
            child: Text(
              '${index + 1}. ${visual.items[index]}',
              style: TextStyle(
                color: index == visual.items.length - 1
                    ? Colors.white
                    : StudentDensityTokens.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImage() {
    if (visual.imageSource.trim().isEmpty) return _buildCallout();
    return Image(
      image: AssetImage(visual.imageSource),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          const Text('그림 자료를 불러올 수 없습니다.'),
    );
  }

  Widget _buildCallout() {
    return Text(
      visual.caption.isEmpty ? visual.formula : visual.caption,
      style: const TextStyle(fontSize: 13, height: 1.5),
    );
  }
}

class _EditorialPageBody extends StatelessWidget {
  const _EditorialPageBody({
    required this.page,
    required this.buildParagraph,
    this.compact = false,
  });

  final BookPage page;
  final Widget Function(String text) buildParagraph;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 5.0 : 7.0;
    return SingleChildScrollView(
      // 분할 추정치보다 실제 수식·한글 줄바꿈 높이가 커지는 마지막 경우에도
      // RenderFlex overflow를 내지 않고 지면 안에서만 안전하게 읽게 한다.
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < page.blocks.length; index++) ...[
            _BookContentBlockView(
              block: page.blocks[index],
              buildParagraph: buildParagraph,
              compact: compact,
            ),
            if (index != page.blocks.length - 1) SizedBox(height: gap),
          ],
        ],
      ),
    );
  }
}

/// 필요한 변수는 명시적 지면의 역할이다.
/// 작동 원리는 역할마다 익숙한 아이콘을 연결해 목차에서 학습 흐름을 빠르게 파악하게 한다.
IconData _bookPageTemplateIcon(BookPageTemplate template) => switch (template) {
  BookPageTemplate.opening => Icons.flag_outlined,
  BookPageTemplate.concept => Icons.menu_book_outlined,
  BookPageTemplate.principle => Icons.account_tree_outlined,
  BookPageTemplate.experiment => Icons.tune_rounded,
  BookPageTemplate.example => Icons.edit_note_rounded,
  BookPageTemplate.solution => Icons.fact_check_outlined,
  BookPageTemplate.practice => Icons.assignment_outlined,
  BookPageTemplate.summary => Icons.checklist_rounded,
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

/// 필요한 변수는 한 지면의 의미 블록과 LaTeX 본문 렌더러다.
/// 작동 원리는 정의·예제·풀이·주의 등 역할별 색과 위계를 적용하고,
/// 명시적 페이지에서는 내부 스크롤 없이 저자가 정한 순서 그대로 배치한다.
class _BookContentBlockView extends StatelessWidget {
  const _BookContentBlockView({
    required this.block,
    required this.buildParagraph,
    this.compact = false,
  });

  final BookContentBlock block;
  final Widget Function(String text) buildParagraph;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (block.type == BookContentBlockType.graph && block.graph != null) {
      return _TextbookGraphCard(document: block.graph!);
    }
    if (block.type == BookContentBlockType.visual && block.visual != null) {
      return _BookVisualCard(visual: block.visual!);
    }
    if (block.type == BookContentBlockType.formula) {
      return _formulaCard(context);
    }
    if (block.type == BookContentBlockType.paragraph) {
      return _plainParagraph();
    }

    final palette = _paletteFor(block.type);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 14,
        compact ? 8 : 12,
        compact ? 10 : 14,
        compact ? 9 : 13,
      ),
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
                      fontSize: compact ? 10 : 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 6 : 8),
          ],
          if (block.text.isNotEmpty) buildParagraph(block.text),
          if (block.items.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < block.items.length; index++)
                  Padding(
                    padding: EdgeInsets.only(
                      top: index == 0 ? 0 : (compact ? 3 : 5),
                    ),
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
                            '${index + 1}',
                            style: TextStyle(
                              color: palette.$2,
                              fontSize: compact ? 7 : 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        SizedBox(width: compact ? 6 : 8),
                        Expanded(child: buildParagraph(block.items[index])),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _plainParagraph() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (block.title.isNotEmpty) ...[
        Text(
          block.title,
          style: const TextStyle(
            color: StudentDensityTokens.ink,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
      ],
      if (block.text.isNotEmpty) buildParagraph(block.text),
    ],
  );

  Widget _formulaCard(BuildContext context) {
    final blocks = parseTextWithLatex(r'$' + block.formula + r'$');
    final isCompact =
        MediaQuery.sizeOf(context).width < 560 ||
        block.title.isNotEmpty && block.title.length > 24;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 16,
        vertical: isCompact ? 11 : 13,
      ),
      decoration: BoxDecoration(
        color: StudentDensityTokens.surfaceMuted,
        border: Border.all(color: StudentDensityTokens.lineStrong),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: StudentDensityTokens.ink,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (block.title.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        block.title,
                        style: const TextStyle(
                          color: StudentDensityTokens.muted,
                          fontSize: 9,
                          letterSpacing: .4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ContentBlocksView(
                      inline: false,
                      blocks: blocks,
                      latexStyle: TextStyle(
                        fontSize: isCompact ? 16 : 20,
                        fontWeight: FontWeight.w700,
                      ),
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

  (Color, Color, Color) _paletteFor(BookContentBlockType type) =>
      switch (type) {
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
          const Color(0xFFF1F3F9),
          const Color(0xFF4C5D87),
          const Color(0x224C5D87),
        ),
        BookContentBlockType.misconception => (
          const Color(0xFFFFF3F1),
          const Color(0xFFA24738),
          const Color(0x22A24738),
        ),
        _ => (
          StudentDensityTokens.surfaceMuted,
          StudentDensityTokens.ink,
          StudentDensityTokens.lineStrong,
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

class _BookPaperPage extends StatelessWidget {
  const _BookPaperPage({
    required this.page,
    required this.pageNumber,
    required this.totalPages,
    required this.resolveImage,
    required this.buildParagraph,
  });

  final _ParsedBookPage page;
  final int pageNumber;
  final int totalPages;
  final ImageProvider Function(String source) resolveImage;
  final Widget Function(String text) buildParagraph;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final editorialPage = page.editorialPage;

        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        final hasDenseEditorialBlock =
            editorialPage?.blocks.any(
              (block) =>
                  block.visual != null ||
                  block.graph != null ||
                  block.formula.isNotEmpty ||
                  block.rows.isNotEmpty,
            ) ??
            false;
        final hasManyItems =
            editorialPage?.blocks.any((block) => block.items.length >= 4) ??
            false;
        final estimatedEditorialChars =
            editorialPage?.blocks.fold<int>(
              0,
              (sum, block) =>
                  sum +
                  block.title.length +
                  block.text.length +
                  block.formula.length +
                  block.rows.fold<int>(
                    0,
                    (rowSum, row) =>
                        rowSum + row.fold<int>(0, (cSum, c) => cSum + c.length),
                  ) +
                  block.items.fold<int>(
                    0,
                    (itemSum, item) => itemSum + item.length,
                  ),
            ) ??
            0;
        final isDensePage =
            editorialPage != null &&
            (editorialPage.blocks.length >= 5 ||
                hasDenseEditorialBlock ||
                hasManyItems ||
                estimatedEditorialChars > 700 ||
                editorialPage.blocks.length >= 6 &&
                    editorialPage.blocks
                            .where(
                              (item) =>
                                  item.type == BookContentBlockType.question,
                            )
                            .length >=
                        2 &&
                    editorialPage.blocks.fold<int>(
                          0,
                          (sum, block) =>
                              sum +
                              block.title.length +
                              block.text.length +
                              block.formula.length,
                        ) >
                        900);

        final isCompact = maxWidth < 560.0 || isDensePage;
        final width = isCompact ? maxWidth : 820.0.clamp(420.0, maxWidth);
        final height = isCompact ? maxHeight : maxHeight.clamp(420.0, 900.0);
        final textScale = isCompact ? (maxWidth < 560.0 ? 0.9 : 0.94) : 1.0;

        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: SizedBox(
            width: width,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: StudentDensityTokens.line),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 34,
                    color: Color(0x1F000000),
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  width < 420 ? 16 : 42,
                  width < 420 ? 16 : 32,
                  width < 420 ? 16 : 42,
                  isCompact ? 14 : 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'CH ${page.chapterNumber.toString().padLeft(2, '0')}  ·  ${page.chapterTitle}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          'P  ${pageNumber.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.black38,
                            letterSpacing: .8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isCompact ? 4 : 6),
                    const Divider(height: 1, color: Color(0x22000000)),
                    if (editorialPage != null) ...[
                      SizedBox(height: isCompact ? 8 : 10),
                      Row(
                        children: [
                          Icon(
                            _bookPageTemplateIcon(editorialPage.template),
                            size: 14,
                            color: StudentDensityTokens.ink,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _bookPageTemplateLabel(editorialPage.template),
                            style: const TextStyle(
                              color: StudentDensityTokens.ink,
                              fontSize: 10,
                              letterSpacing: .4,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$pageNumber / $totalPages',
                            style: const TextStyle(
                              color: StudentDensityTokens.muted,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      SizedBox(height: isCompact ? 8 : 12),
                      Text(
                        'CH ${page.chapterNumber.toString().padLeft(2, '0')} | ${page.partNumber}/${page.partTotal}',
                        style: const TextStyle(
                          color: StudentDensityTokens.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                    SizedBox(height: isCompact ? 8 : 12),
                    if (editorialPage != null &&
                        editorialPage.kicker.isNotEmpty) ...[
                      Text(
                        editorialPage.kicker,
                        style: const TextStyle(
                          color: StudentDensityTokens.muted,
                          fontSize: 10,
                          letterSpacing: .5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: isCompact ? 4 : 6),
                    ],
                    Text(
                      page.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _BookWidgetState.kPrimary,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                      ).copyWith(fontSize: isCompact ? 22 : 24),
                    ),
                    if (page.partTotal > 1) ...[
                      SizedBox(height: isCompact ? 3 : 4),
                      Text(
                        '${page.partNumber} / ${page.partTotal}',
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    SizedBox(height: isCompact ? 8 : 12),
                    Expanded(
                      child: editorialPage != null
                          ? _EditorialPageBody(
                              page: editorialPage,
                              buildParagraph: buildParagraph,
                              compact: isCompact,
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final paragraph in page.paragraphs)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: RepaintBoundary(
                                      child: buildParagraph(paragraph),
                                    ),
                                  ),
                                for (final visual in page.visuals)
                                  _BookVisualCard(visual: visual),
                                if (page.graph != null) ...[
                                  const SizedBox(height: 8),
                                  _TextbookGraphCard(document: page.graph!),
                                ],
                                for (final image in page.images)
                                  if (image.trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image(
                                          image: resolveImage(image),
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, _, __) =>
                                              Container(
                                                height: 160,
                                                color: const Color(0xFFEDEDED),
                                                alignment: Alignment.center,
                                                child: const Text(
                                                  '이미지를 불러올 수 없습니다.',
                                                  style: TextStyle(
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                              ),
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'AIFlow',
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.38),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$pageNumber / $totalPages',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
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
          color: selected ? const Color(0xFF202022) : Colors.white,
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
    required this.scrollOffset,
    super.repaint,
  });

  final List<_Stroke> strokes;
  final _Stroke? currentStroke;
  final Offset? eraserPosition;
  final double eraserRadius;
  final double scrollOffset;

  static const double _leftPadding = 20.0;
  static const double _topPadding = 20.0;

  @override
  // 필요 변수: 필기 획·지우개 위치·스크롤 값. 작동 원리: 현재 뷰 좌표로 변환해 획과 지우개 표시를 그린다.
  void paint(Canvas canvas, Size size) {
    canvas.translate(_leftPadding, _topPadding - scrollOffset);

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
        ..color = Colors.black.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(eraserPosition!, eraserRadius, fillPaint);
      canvas.drawCircle(eraserPosition!, eraserRadius, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) {
    if (oldDelegate.strokes.length != strokes.length) return true;
    if (oldDelegate.currentStroke != currentStroke) return true;
    if (oldDelegate.eraserPosition != eraserPosition) return true;
    if (oldDelegate.scrollOffset != scrollOffset) return true;
    for (var i = 0; i < strokes.length; i++) {
      if (!identical(oldDelegate.strokes[i], strokes[i])) return true;
    }
    return false;
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
    if (chapter.pages.isNotEmpty) {
      for (var pageIndex = 0; pageIndex < chapter.pages.length; pageIndex++) {
        final page = chapter.pages[pageIndex];
        entries.add(
          _ContentEntry(
            chapterIndex: i,
            level: pageIndex == 0 ? 0 : 1,
            title: page.title,
            paragraphs: _editorialPageSearchText(page),
            images: const [],
            editorialPage: page,
          ),
        );
      }
      continue;
    }
    entries.add(
      _ContentEntry(
        chapterIndex: i,
        level: 0,
        title: chapter.title,
        paragraphs: chapter.intro,
        images: const [],
        visuals: chapter.visuals,
      ),
    );
    for (final section in chapter.sections) {
      entries.add(
        _ContentEntry(
          chapterIndex: i,
          level: 1,
          title: section.title,
          paragraphs: section.paragraphs,
          images: section.images,
          graph: section.graph,
          visuals: section.visuals,
        ),
      );
    }
  }
  return entries;
}

/// 필요 변수: [entries]는 장 항목(level 0)이 각 절보다 먼저 배치된 목록이어야 합니다.
/// 작동 원리: 장 제목을 단일 순회 중 캐시하고 문단을 정해진 글자 수로 나눠 페이지를 만듭니다.
/// 각 항목마다 전체 목록을 다시 검색하지 않아 큰 교재에서도 선형 시간으로 처리됩니다.
List<_ParsedBookPage> _paginateContentEntries(List<_ContentEntry> entries) {
  const maxPageChars = 780;
  final pages = <_ParsedBookPage>[];
  final chapterTitles = <int, String>{};
  final chapterSectionTitles = <int, List<String>>{};

  // 장 소개가 비어도 첫 지면이 비어 보이지 않도록, 각 장의 절 제목을 한 번만 수집한다.
  // 이 선행 순회는 이후 페이지 분할 중 목록 재검색을 막아 큰 교재에서도 선형 시간을 유지한다.
  for (final entry in entries) {
    if (entry.level != 1) continue;
    chapterSectionTitles
        .putIfAbsent(entry.chapterIndex, () => <String>[])
        .add(entry.title);
  }

  for (var entryIndex = 0; entryIndex < entries.length; entryIndex++) {
    final entry = entries[entryIndex];
    if (entry.level == 0) {
      chapterTitles[entry.chapterIndex] = entry.title;
    }
    final chapterTitle = chapterTitles[entry.chapterIndex] ?? entry.title;

    if (entry.editorialPage != null) {
      pages.addAll(
        _splitEditorialPage(
          entryIndex: entryIndex,
          entry: entry,
          chapterTitle: chapterTitle,
        ),
      );
      continue;
    }

    final chapterSections =
        chapterSectionTitles[entry.chapterIndex] ?? const <String>[];
    final fallbackIntro = entry.level == 0 && chapterSections.isNotEmpty
        ? '${entry.title} 단원에서는 ${chapterSections.join(', ')} 내용을 순서대로 학습합니다. 목차에서 원하는 절을 선택하거나 다음 페이지로 이동해 시작하세요.'
        : '내용이 비어 있습니다.';
    final paragraphs = entry.paragraphs.isEmpty
        ? <String>[fallbackIntro]
        : entry.paragraphs;
    final chunks = <List<String>>[];
    var current = <String>[];
    var currentLength = 0;

    void flush() {
      if (current.isEmpty) return;
      chunks.add(current);
      current = <String>[];
      currentLength = 0;
    }

    for (final paragraph in paragraphs) {
      final pieces = _splitParagraphForPage(paragraph, maxPageChars);
      for (final piece in pieces) {
        final nextLength = currentLength + piece.length;
        if (current.isNotEmpty && nextLength > maxPageChars) {
          flush();
        }
        current.add(piece);
        currentLength += piece.length;
      }
    }
    flush();

    if (chunks.isEmpty) {
      chunks.add(const <String>['내용이 비어 있습니다.']);
    }

    final partTotal = chunks.length + entry.images.length;
    for (var i = 0; i < chunks.length; i++) {
      pages.add(
        _ParsedBookPage(
          entryIndex: entryIndex,
          chapterIndex: entry.chapterIndex,
          chapterTitle: chapterTitle,
          chapterNumber: entry.chapterIndex + 1,
          title: entry.title,
          paragraphs: chunks[i],
          images: const [],
          partNumber: i + 1,
          partTotal: partTotal,
          graph: i == 0 ? entry.graph : null,
          visuals: i == 0 ? entry.visuals : const [],
        ),
      );
    }

    for (var i = 0; i < entry.images.length; i++) {
      pages.add(
        _ParsedBookPage(
          entryIndex: entryIndex,
          chapterIndex: entry.chapterIndex,
          chapterTitle: chapterTitle,
          chapterNumber: entry.chapterIndex + 1,
          title: entry.title,
          paragraphs: const ['이미지 자료'],
          images: [entry.images[i]],
          partNumber: chunks.length + i + 1,
          partTotal: partTotal,
        ),
      );
    }
  }

  return pages;
}

/// 필요한 변수: 에디토리얼 지면, 해당 항목 인덱스, 장 제목.
/// 작동 원리: 블록 단위로 밀도를 계산해 한 페이지 허용치 초과 시 다음 지면으로 분할한다.
List<_ParsedBookPage> _splitEditorialPage({
  required int entryIndex,
  required _ContentEntry entry,
  required String chapterTitle,
}) {
  final page = entry.editorialPage!;
  // 필요한 변수는 에디토리얼 지면 하나의 허용 밀도다.
  // 작동 원리: 390x844 모바일에서도 렌더 오버플로우가 생기지 않도록
  // 데스크톱 기준 상한도 약간 더 보수적으로 낮춰 분할 기준을 강화한다.
  // 실제 모바일 지면의 줄바꿈·수식·그래프 여백을 감안한 보수적 상한이다.
  const maxChars = 960;
  final chunks = _splitEditorialBlocksForRender(
    page.blocks,
    maxChars: maxChars,
  );
  final partTotal = chunks.isEmpty ? 1 : chunks.length;

  final parsed = <_ParsedBookPage>[];
  for (var i = 0; i < partTotal; i++) {
    final blocks = chunks.isEmpty ? page.blocks : chunks[i];
    parsed.add(
      _ParsedBookPage(
        entryIndex: entryIndex,
        chapterIndex: entry.chapterIndex,
        chapterTitle: chapterTitle,
        chapterNumber: entry.chapterIndex + 1,
        title: page.title,
        paragraphs: const [],
        images: const [],
        partNumber: i + 1,
        partTotal: partTotal,
        editorialPage: BookPage(
          id: '${page.id}#p${i + 1}',
          template: page.template,
          title: page.title,
          kicker: partTotal > 1
              ? '${page.kicker} (${i + 1}/$partTotal)'
              : page.kicker,
          blocks: blocks,
        ),
      ),
    );
  }
  return parsed;
}

/// 필요한 변수: 렌더 대상 블록 목록과 한 페이지 상한치.
/// 작동 원리: 블록 텍스트와 항목의 길이를 더한 값을 근사치로 사용해
/// 페이지를 여러 파트로 분할한다.
List<List<BookContentBlock>> _splitEditorialBlocksForRender(
  List<BookContentBlock> blocks, {
  required int maxChars,
}) {
  final result = <List<BookContentBlock>>[];
  var current = <BookContentBlock>[];
  var currentScore = 0;

  void flush() {
    if (current.isEmpty) return;
    result.add(current);
    current = <BookContentBlock>[];
    currentScore = 0;
  }

  for (final block in blocks) {
    final split = _splitEditorialBlock(block, maxChars: maxChars);
    for (final piece in split) {
      final score = _estimateEditorialBlockScore(piece);

      if (current.isNotEmpty && currentScore + score > maxChars) {
        flush();
      }

      current.add(piece);
      currentScore += score;

      if (currentScore >= maxChars * 0.9 && split.length > 1) {
        flush();
      }
    }
  }
  flush();
  return result;
}

/// 필요한 변수: 단일 블록.
/// 작동 원리: 텍스트는 제목/본문/항목 수치로, 시각/그래프는 보수적으로 고정값으로
/// 환산해 한 블록의 렌더 높이 추정을 수행한다.
int _estimateEditorialBlockScore(BookContentBlock block) {
  var score = block.title.length + block.text.length + block.formula.length;
  score += block.rows.fold<int>(
    0,
    (sum, row) =>
        sum + row.fold<int>(0, (inner, cell) => inner + cell.length + 6),
  );
  score += block.items.fold<int>(0, (sum, item) => sum + item.length + 12);

  if (block.graph != null) score += 800;
  if (block.visual != null) score += 500;
  if (block.type == BookContentBlockType.formula) score += 320;
  return score;
}

/// 필요한 변수: 단일 블록과 한 페이지 상한치.
/// 작동 원리: 분할 가능한 블록은 타입 특성에 맞춰 조각을 나누고,
/// 시각/그래프 블록은 블록 단위로 유지한다.
List<BookContentBlock> _splitEditorialBlock(
  BookContentBlock block, {
  required int maxChars,
}) {
  if (_estimateEditorialBlockScore(block) <= maxChars) return [block];

  if (block.items.isNotEmpty && block.items.length > 1) {
    final result = <BookContentBlock>[];
    var currentItems = <String>[];
    var currentScore = 0;

    BookContentBlock makePiece() {
      final isFirst = result.isEmpty;
      return BookContentBlock(
        type: block.type,
        // 제목·설명·수식은 첫 조각에만 두어 분할 후 내용이 중복되지 않게 한다.
        title: isFirst ? block.title : '',
        text: isFirst ? block.text : '',
        formula: isFirst ? block.formula : '',
        items: List<String>.of(currentItems),
        rows: isFirst ? block.rows : const [],
      );
    }

    for (final item in block.items) {
      final itemScore = item.length + 12;
      if (currentItems.isNotEmpty && currentScore + itemScore > maxChars) {
        result.add(makePiece());
        currentItems = <String>[];
        currentScore = 0;
      }
      currentItems.add(item);
      currentScore += itemScore;
    }
    if (currentItems.isNotEmpty) {
      result.add(makePiece());
    }
    return result;
  }

  if (block.text.isNotEmpty) {
    final pieces = _splitParagraphForPage(block.text, 250);
    if (pieces.length > 1) {
      return pieces
          .map(
            (text) => BookContentBlock(
              type: block.type,
              title: block.title,
              text: text,
              formula: block.formula,
              items: block.items,
              rows: block.rows,
              visual: block.visual,
              graph: block.graph,
            ),
          )
          .toList(growable: false);
    }
  }

  if (block.formula.isNotEmpty) {
    final parts = _splitParagraphForPage(block.formula, 100);
    return parts
        .map(
          (formula) => BookContentBlock(
            type: block.type,
            title: block.title,
            text: block.text,
            formula: formula,
            items: block.items,
            rows: block.rows,
            visual: block.visual,
            graph: block.graph,
          ),
        )
        .toList(growable: false);
  }

  return [block];
}

List<String> _editorialPageSearchText(BookPage page) => [
  if (page.kicker.isNotEmpty) page.kicker,
  for (final block in page.blocks) ...[
    if (block.title.isNotEmpty) block.title,
    if (block.text.isNotEmpty) block.text,
    if (block.formula.isNotEmpty) block.formula,
    ...block.items,
  ],
];

List<String> _splitParagraphForPage(String paragraph, int maxChars) {
  final text = paragraph.trim();
  if (text.isEmpty) return const <String>[];
  if (text.length <= maxChars) return [text];

  final result = <String>[];
  var start = 0;
  while (start < text.length) {
    var end = (start + maxChars).clamp(0, text.length).toInt();
    if (end < text.length) {
      final boundary = text.lastIndexOf(RegExp(r'[\s.!?。！？]'), end);
      if (boundary > start + maxChars * 0.55) {
        end = boundary + 1;
      }
    }
    result.add(text.substring(start, end).trim());
    start = end;
  }
  return result.where((item) => item.isNotEmpty).toList(growable: false);
}
