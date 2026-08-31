import 'dart:async';

import 'package:flutter/material.dart';
import 'package:s11/shared/data/models/content_block.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart' as book_page;
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/shared/ui/components/content_blocks_view.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/sessions/exam_paper/session/exam_paper_page.dart'
    as exam_page;
import 'package:s11/sessions/tryout_solve/ui/pages/solution_view_page.dart';
import 'package:s11/shared/business/repositories/exam_paper_store.dart';
import 'package:s11/shared/services/storage/local_db.dart';
import 'package:s11/shared/business/repositories/textbook_store.dart';
import 'package:s11/shared/business/repositories/bookmark_store.dart';
import 'package:s11/shared/business/repositories/problem_bookmark_store.dart';
import 'package:s11/shared/services/api/course_service.dart';
import 'package:s11/shared/data/models/course.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';
import 'package:s11/shared/ui/ios26/ios26_modal.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF202022)),
        fontFamily: 'Inter',
      ),
      home: const BookWidget(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  BigSectionItem: 히어로 빅섹션에 표시할 항목 모델
// ─────────────────────────────────────────────────────────────
enum BigItemType { textbook, exam, bookBookmark, problemBookmark }

class BigSectionItem {
  final String id;
  final String title;
  final String subtitle;
  final Color color;
  final BigItemType type;

  const BigSectionItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.type,
  });
}

class BookWidget extends StatefulWidget {
  const BookWidget({super.key, this.previewMode = false});

  final bool previewMode;

  static const Color primaryGreen = Colors.black;
  static const Color brightGreen = Color(0xFF707075);
  static const Color darkGreen = Color(0xFF202024);
  static const Color mediumGreen = Color(0xFF4B4B50);
  static const Color borderColor = Color(0xFFE0E3E7);
  static const Color bgColor = Color(0xFFF8F8F8);

  @override
  State<BookWidget> createState() => _BookWidgetState();
}

class _BookWidgetState extends State<BookWidget> {
  // The desktop header remains available from 781px, but the library body
  // needs more room before its cards and actions can safely sit side by side.
  static const double _bodyStackBreakpoint = 1000;

  // ── storage keys ──────────────────────────────────────────
  static const String _pinnedBookKey = 'pinned_textbook_id';
  static const String _pinnedExamKey = 'pinned_exam_id_v1';
  static const String _pinnedBookBookmarkKey = 'pinned_book_bookmark_id_v1';
  static const String _pinnedProblemBookmarkKey =
      'pinned_problem_bookmark_id_v1';
  static const String _recentPagesKey = 'recent_pages_json_v1';

  // ── search ────────────────────────────────────────────────
  final ValueNotifier<String> _bookSearchQuery = ValueNotifier<String>('');
  final ValueNotifier<String> _globalSearchQuery = ValueNotifier<String>('');
  final TextEditingController _bookSearchController = TextEditingController();
  final TextEditingController _globalSearchController = TextEditingController();
  String? _expandedLibrarySection;

  // ── state ─────────────────────────────────────────────────
  BookData? _pinnedBook;
  List<BookData> _libraryBooks = const [];
  Course? _activeCourse;
  List<Course> _activeCourses = const [];
  List<BookmarkItem> _bookBookmarks = const [];
  ProblemBookmarkSnapshot _problemBookmarks = const ProblemBookmarkSnapshot(
    serverItems: <ProblemBookmarkItem>[],
    localOverflowItems: <ProblemBookmarkItem>[],
  );
  String? _pinnedBookBookmarkId;
  String? _pinnedProblemBookmarkId;
  String? _pinnedExamId;

  /// 최근 방문 항목 (최대 4개, 최신 순)
  List<BigSectionItem> _recentItems = const [];

  // ── lifecycle ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (widget.previewMode) {
      _recentItems = const [
        BigSectionItem(
          id: 'preview-book-1',
          title: '중2 일차함수 개념서',
          subtitle: '교재 · 42쪽',
          color: Color(0xFFECECEF),
          type: BigItemType.textbook,
        ),
        BigSectionItem(
          id: 'preview-exam-1',
          title: '함수 형성평가',
          subtitle: '시험지 · 4/20',
          color: Color(0xFFECECEF),
          type: BigItemType.exam,
        ),
        BigSectionItem(
          id: 'preview-bookmark-1',
          title: '기울기는 변화의 비율',
          subtitle: '책 북마크',
          color: Color(0xFF202024),
          type: BigItemType.bookBookmark,
        ),
        BigSectionItem(
          id: 'preview-problem-1',
          title: '그래프 해석 문제',
          subtitle: '문제 북마크',
          color: Color(0xFF202024),
          type: BigItemType.problemBookmark,
        ),
      ];
      return;
    }
    unawaited(ExamPaperStore.load());
    unawaited(_loadLibraryBooks());
    _loadPinnedBook();
    unawaited(_loadPinnedExam());
    unawaited(_loadActiveCourse());
    unawaited(_loadBookmarks());
    unawaited(_loadRecentItems());
  }

  /// 필요한 변수는 감사 프리뷰 여부와 실제 저장소 항목 수다.
  /// 작동 원리는 운영 화면은 실제 개수를 쓰고 프리뷰만 HTML 시안의 자료 수치를 고정해 시각 비교를 안정화하는 것이다.
  int get _bookCount => widget.previewMode ? 14 : _libraryBooks.length;
  int get _examCount =>
      widget.previewMode ? 6 : ExamPaperStore.notifier.value.length;
  int get _bookBookmarkCount => widget.previewMode ? 18 : _bookBookmarks.length;
  int get _problemBookmarkCount =>
      widget.previewMode ? 27 : _problemBookmarks.allItems.length;

  @override
  void dispose() {
    _bookSearchController.dispose();
    _globalSearchController.dispose();
    _bookSearchQuery.dispose();
    _globalSearchQuery.dispose();
    super.dispose();
  }

  // ── data loading ──────────────────────────────────────────
  Future<void> _loadLibraryBooks() async {
    try {
      final books = await TextbookStore.loadLibrary();
      if (mounted) setState(() => _libraryBooks = books);
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadPinnedBook() async {
    try {
      final pinnedId = await LocalDb.instance.getString(_pinnedBookKey);
      if (pinnedId == null || pinnedId.isEmpty) {
        setState(() {});
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
        setState(() => _pinnedBook = match);
        return;
      }
      final fetched = await TextbookStore.getById(pinnedId);
      setState(() => _pinnedBook = fetched);
    } catch (_) {
      setState(() {});
    }
  }

  Future<void> _loadActiveCourse() async {
    try {
      final courses = await CourseService.fetchMyCourses();
      if (!mounted) return;
      if (courses.isEmpty) {
        setState(() {
          _activeCourse = null;
          _activeCourses = const [];
        });
        return;
      }
      final sorted = List<Course>.from(courses)
        ..sort((a, b) {
          final ad = DateTime.tryParse(a.lastAction ?? '') ?? DateTime(1970);
          final bd = DateTime.tryParse(b.lastAction ?? '') ?? DateTime(1970);
          return bd.compareTo(ad);
        });
      setState(() {
        _activeCourse = sorted.first;
        _activeCourses = sorted
            .where((course) => !course.isCompleted)
            .toList(growable: false);
      });
    } catch (_) {}
  }

  Future<void> _loadBookmarks() async {
    final bookMarks = await BookmarkStore.load();
    final problemMarks = await ProblemBookmarkStore.load();
    final pinnedBookId = await LocalDb.instance.getString(
      _pinnedBookBookmarkKey,
    );
    final pinnedProblemId = await LocalDb.instance.getString(
      _pinnedProblemBookmarkKey,
    );
    if (!mounted) return;
    setState(() {
      _bookBookmarks = bookMarks;
      _problemBookmarks = problemMarks;
      _pinnedBookBookmarkId = pinnedBookId;
      _pinnedProblemBookmarkId = pinnedProblemId;
    });
  }

  /// 최근 방문 목록 로드 (LocalDb JSON 문자열로 저장된 id+type 목록)
  Future<void> _loadRecentItems() async {
    try {
      final raw = await LocalDb.instance.getString(_recentPagesKey);
      if (raw == null || raw.isEmpty) return;
      // 포맷: "type:id,type:id,..." (단순 CSV)
      final parts = raw.split(',').where((s) => s.contains(':')).toList();
      final library = await TextbookStore.loadLibrary();
      final exams = ExamPaperStore.notifier.value;
      final items = <BigSectionItem>[];
      for (final part in parts.take(4)) {
        final idx = part.indexOf(':');
        final type = part.substring(0, idx);
        final id = part.substring(idx + 1);
        if (type == 'book') {
          final b = library.where((b) => b.id == id).firstOrNull;
          if (b != null) {
            items.add(
              BigSectionItem(
                id: b.id,
                title: b.title,
                subtitle: '교재',
                color: b.coverColor ?? BookWidget.darkGreen,
                type: BigItemType.textbook,
              ),
            );
          }
        } else if (type == 'exam') {
          final e = exams.where((e) => e.examId == id).firstOrNull;
          if (e != null) {
            items.add(
              BigSectionItem(
                id: e.examId,
                title: _examTitle(e),
                subtitle: '시험지',
                color: BookWidget.mediumGreen,
                type: BigItemType.exam,
              ),
            );
          }
        }
      }
      if (mounted) setState(() => _recentItems = items);
    } catch (_) {}
  }

  /// 교재/시험지 열람 시 최근 방문에 기록
  Future<void> _recordRecentVisit(String type, String id) async {
    try {
      final raw = await LocalDb.instance.getString(_recentPagesKey) ?? '';
      final parts = raw.split(',').where((s) => s.contains(':')).toList();
      final entry = '$type:$id';
      final updated = [
        entry,
        ...parts.where((p) => p != entry),
      ].take(4).join(',');
      await LocalDb.instance.setString(_recentPagesKey, updated);
      unawaited(_loadRecentItems());
    } catch (_) {}
  }

  // ── pin actions ───────────────────────────────────────────
  Future<void> _pinBookmark({required bool isBook, required String? id}) async {
    if (isBook) {
      await LocalDb.instance.setString(_pinnedBookBookmarkKey, id ?? '');
    } else {
      await LocalDb.instance.setString(_pinnedProblemBookmarkKey, id ?? '');
    }
    if (!mounted) return;
    setState(() {
      if (isBook) {
        _pinnedBookBookmarkId = id;
      } else {
        _pinnedProblemBookmarkId = id;
      }
    });
  }

  Future<void> _pinBook(BookData book) async {
    final shouldUnpin = _pinnedBook != null && _pinnedBook!.id == book.id;
    await LocalDb.instance.setString(
      _pinnedBookKey,
      shouldUnpin ? '' : book.id,
    );
    setState(() => _pinnedBook = shouldUnpin ? null : book);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shouldUnpin
                ? '\'${book.title}\' 고정이 해제되었습니다.'
                : '\'${book.title}\' 이(가) 고정되었습니다.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadPinnedExam() async {
    try {
      final id = await LocalDb.instance.getString(_pinnedExamKey);
      if (!mounted) return;
      setState(() => _pinnedExamId = (id == null || id.isEmpty) ? null : id);
    } catch (_) {}
  }

  Future<void> _setPinnedExam(String? examId) async {
    await LocalDb.instance.setString(_pinnedExamKey, examId ?? '');
    if (!mounted) return;
    setState(() => _pinnedExamId = examId);
  }

  // ── build root ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    if (mobile) return _buildMobileBookbag(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: BookWidget.bgColor,
        drawer: const AppDrawer(),
        body: SafeArea(
          child: Column(
            children: [
              Builder(builder: (ctx) => _buildHeader(ctx)),
              Expanded(
                // 필요 변수: 본문 섹션과 남은 화면 높이. 작동 원리: 항상 스크롤
                // 가능한 뷰포트를 사용해 데스크톱 휠·트랙패드와 모바일 드래그가
                // 짧은 화면에서도 같은 방식으로 다음 섹션까지 이동하게 한다.
                child: CustomScrollView(
                  key: const ValueKey('bookbag-desktop-body'),
                  primary: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeroSection(context)),
                    SliverToBoxAdapter(child: _buildBottomSection(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 필요한 변수는 교재·시험지·북마크 개수와 최근·고정 자료다.
  /// 작동 원리는 세로형 모바일에서 긴 소개·통계·보관함·코스 섹션을 제거하고 이어 보기와 네 자료 입구를 한 화면에 압축한다.
  Widget _buildMobileBookbag(BuildContext context) {
    final pinned = _buildPinnedItems();
    final seen = <String>{};
    final items = <BigSectionItem>[];
    for (final item in [..._recentItems, ...pinned]) {
      final key = '${item.type.name}:${item.id}';
      if (seen.add(key)) items.add(item);
    }
    final featured = items.firstOrNull;
    final recent = items.skip(1).take(3).toList(growable: false);
    final total =
        _bookCount + _examCount + _bookBookmarkCount + _problemBookmarkCount;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: const ValueKey('bookbag-mobile-redesign'),
        backgroundColor: const Color(0xFFF2F2F4),
        drawer: const AppDrawer(),
        bottomNavigationBar: const MobileStudentBottomAppBar(
          activeRoute: '/bookbag',
        ),
        body: SafeArea(
          child: Column(
            children: [
              Builder(builder: (headerContext) => _buildHeader(headerContext)),
              Expanded(
                child: CustomScrollView(
                  key: const ValueKey('bookbag-mobile-scroll'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
                      sliver: SliverList.list(
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  '자료실',
                                  style: TextStyle(
                                    fontSize: 40,
                                    height: 1,
                                    letterSpacing: -2,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              IconButton.filled(
                                key: const ValueKey('bookbag-mobile-search'),
                                tooltip: '자료실 검색',
                                onPressed: () => _showGlobalSearch(context),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  minimumSize: const Size(48, 48),
                                ),
                                icon: const Icon(
                                  Icons.search_rounded,
                                  color: Colors.white,
                                  size: 25,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '내 학습 자료 $total개',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF71717A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _buildMobileFeatured(featured),
                          const SizedBox(height: 26),
                          const Text(
                            '내 자료',
                            style: TextStyle(
                              fontSize: 27,
                              letterSpacing: -1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            key: const ValueKey(
                              'bookbag-mobile-shortcut-group',
                            ),
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              children: [
                                _buildMobileShortcut(
                                  icon: Icons.menu_book_rounded,
                                  label: '교재',
                                  count: _bookCount,
                                  onTap: () => _showTextbookModal(context),
                                ),
                                _buildMobileShortcut(
                                  icon: Icons.description_rounded,
                                  label: '시험지',
                                  count: _examCount,
                                  onTap: () => _showExamModal(context),
                                ),
                                _buildMobileShortcut(
                                  icon: Icons.bookmark_rounded,
                                  label: '책 북마크',
                                  count: _bookBookmarkCount,
                                  onTap: () =>
                                      _showBookmarkDetailModal(isBook: true),
                                ),
                                _buildMobileShortcut(
                                  icon: Icons.edit_note_rounded,
                                  label: '문제 북마크',
                                  count: _problemBookmarkCount,
                                  onTap: () =>
                                      _showBookmarkDetailModal(isBook: false),
                                ),
                              ],
                            ),
                          ),
                          if (recent.isNotEmpty) ...[
                            const SizedBox(height: 28),
                            const Text(
                              '최근 항목',
                              style: TextStyle(
                                fontSize: 27,
                                letterSpacing: -1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: const Color(0x1F09090B),
                                ),
                              ),
                              child: Column(
                                children: [
                                  for (
                                    var index = 0;
                                    index < recent.length;
                                    index++
                                  ) ...[
                                    _buildMobileRecentItem(recent[index]),
                                    if (index != recent.length - 1)
                                      const Divider(
                                        height: 1,
                                        indent: 67,
                                        color: Color(0xFFE7E7EA),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 필요한 변수는 최근 또는 고정 자료 한 건이다.
  /// 작동 원리는 모바일 첫 화면에서 가장 최근 자료의 제목·종류·열기 동작만 큰 검은 카드로 강조한다.
  Widget _buildMobileFeatured(BigSectionItem? item) {
    return Material(
      key: const ValueKey('bookbag-mobile-featured'),
      color: const Color(0xFF202023),
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: item == null ? null : () => _openBigItem(item),
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      item == null
                          ? Icons.auto_stories_outlined
                          : _bigItemIcon(item.type),
                      color: Colors.black,
                      size: 25,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                item == null ? '최근 학습 없음' : '이어서 보기',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              _LatexLine(
                item?.title ?? '교재나 시험지를 열어보세요',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.8,
                ),
              ),
              if (item != null) ...[
                const SizedBox(height: 7),
                _LatexLine(
                  item.subtitle,
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 필요한 변수는 자료 유형·개수·열기 동작이다.
  /// 작동 원리는 개별 카드 대신 한 그룹 안의 큰 Material 행으로 자료 입구를 배치한다.
  Widget _buildMobileShortcut({
    required IconData icon,
    required String label,
    required int count,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 68,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF8A8A91),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 필요한 변수는 최근 자료 한 건이다.
  /// 작동 원리는 아이콘·제목·종류만 68px 행에 배치해 반복 카드로 인한 긴 스크롤을 막는다.
  Widget _buildMobileRecentItem(BigSectionItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openBigItem(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(_bigItemIcon(item.type), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LatexLine(
                      item.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _LatexLine(
                      item.subtitle,
                      style: const TextStyle(
                        color: Color(0xFF71717A),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  HEADER
  // ══════════════════════════════════════════════════════════
  /// 필요한 변수는 현재 책가방 화면 문맥이다.
  /// PC·모바일 모두 공용 학생 상단바와 오버레이 메뉴를 유지한다.
  Widget _buildHeader(BuildContext context) {
    return Ios26TopBar(
      brandColor: BookWidget.primaryGreen,
      showUtilityActions: true,
      onMenu: () => toggleAppDrawer(context),
      onTitleTap: () => Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/student/dashboard', (route) => false),
      items: studentTopNavItems(context, active: StudentTopDestination.bookbag),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  HERO SECTION
  // ══════════════════════════════════════════════════════════
  /// 필요한 변수는 교재·시험지·북마크 수와 화면 폭이다.
  /// 작동 원리는 중복된 책가방 제목 행만 제거하고, 자료를 여는 최근·고정 및
  /// 보관함 진입 기능은 레퍼런스 순서대로 유지하는 것이다.
  Widget _buildHeroSection(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final vertical = width < _bodyStackBreakpoint;
    final horizontalPadding = vertical ? 16.0 : 54.0;

    return Center(
      child: ConstrainedBox(
        key: ValueKey(
          vertical ? 'bookbag-hero-stacked' : 'bookbag-hero-columns',
        ),
        constraints: const BoxConstraints(maxWidth: 1440),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            vertical ? 28 : 54,
            horizontalPadding,
            14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLibraryOverview(vertical: vertical),
              SizedBox(height: vertical ? 36 : 44),
              const Divider(height: 1, color: Color(0xFFDCDCE0)),
              SizedBox(height: vertical ? 28 : 22),
              _buildRecentAndPinned(vertical: vertical),
              const SizedBox(height: 14),
              _buildLibraryActions(vertical: vertical),
            ],
          ),
        ),
      ),
    );
  }

  /// 필요한 변수는 화면 방향과 검색·마켓 이동 콜백이다.
  /// 작동 원리는 시안처럼 제목과 설명을 왼쪽에 두고, 모바일에서는 두 행동 버튼을 아래에 전체 폭으로 쌓는 것이다.
  Widget _buildBookbagTitle({required bool vertical}) {
    final copy = const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BookbagEyebrow('STUDENT LIBRARY'),
        SizedBox(height: 10),
        Text(
          '자료실',
          style: TextStyle(
            fontSize: 38,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.9,
          ),
        ),
        SizedBox(height: 18),
        Text(
          '교재와 시험지, 책·문제 북마크를 빠르게 열고 마지막 위치에서 이어서 학습합니다.',
          style: TextStyle(color: Color(0xFF77777E), fontSize: 14, height: 1.7),
        ),
      ],
    );
    final actions = Flex(
      direction: vertical ? Axis.vertical : Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: vertical
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.center,
      children: [
        _BookbagButton(
          label: '전체 검색',
          primary: true,
          onTap: () => _showGlobalSearch(context),
        ),
        SizedBox(width: vertical ? 0 : 10, height: vertical ? 10 : 0),
        _BookbagButton(
          label: '마켓플레이스',
          onTap: () => Navigator.of(context).pushNamed('/marketplace'),
        ),
      ],
    );
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [copy, const SizedBox(height: 20), actions],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: copy),
        actions,
      ],
    );
  }

  /// 필요한 변수는 화면 방향과 네 종류의 실제 자료 개수다.
  /// 작동 원리는 가로 화면에서 소개와 2x2 통계를 나란히, 세로 화면에서는 같은 통계를 소개 아래에 배치하는 것이다.
  Widget _buildLibraryOverview({required bool vertical}) {
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BookbagEyebrow('ALL LEARNING MATERIALS'),
        SizedBox(height: vertical ? 42 : 58),
        Text(
          '찾고, 고정하고,\n바로 이어서.',
          style: TextStyle(
            fontSize: vertical ? 36 : 48,
            height: 1.32,
            fontWeight: FontWeight.w900,
            letterSpacing: vertical ? -2.2 : -3.0,
          ),
        ),
        SizedBox(height: vertical ? 46 : 68),
        const Text(
          '교재 목차와 요약, 시험지 내용까지 한 번에 검색할 수 있습니다.',
          style: TextStyle(color: Color(0xFF77777E), fontSize: 14, height: 1.7),
        ),
      ],
    );
    final metrics = ValueListenableBuilder<List<ExamPaperEntry>>(
      valueListenable: ExamPaperStore.notifier,
      builder: (_, exams, __) => _BookbagMetrics(
        bookCount: _bookCount,
        examCount: widget.previewMode ? _examCount : exams.length,
        bookBookmarkCount: _bookBookmarkCount,
        problemBookmarkCount: _problemBookmarkCount,
        onTextbooks: () => _showTextbookModal(context),
        onExams: () => _showExamModal(context),
        onBookBookmarks: () => _showBookmarkDetailModal(isBook: true),
        onProblemBookmarks: () => _showBookmarkDetailModal(isBook: false),
      ),
    );
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          intro,
          const SizedBox(height: 18),
          Align(alignment: Alignment.centerRight, child: metrics),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: intro),
        const SizedBox(width: 32),
        Align(alignment: Alignment.bottomRight, child: metrics),
      ],
    );
  }

  /// 필요한 변수는 최근 방문·고정 자료 목록과 화면 방향이다.
  /// 작동 원리는 데스크톱에서 두 목록을 1:1로 나누고 모바일에서 한 카드 안에 위아래로 쌓는 것이다.
  Widget _buildRecentAndPinned({required bool vertical}) {
    final pinnedItems = _buildPinnedItems();
    final recent = _bigColumn(
      label: '최근 방문',
      items: _recentItems,
      isPinnedCol: false,
    );
    final pinned = _bigColumn(
      label: '고정됨',
      items: pinnedItems,
      isPinnedCol: true,
    );
    return _buildSectionCard(
      title: '',
      child: Padding(
        padding: EdgeInsets.all(vertical ? 20 : 22),
        child: vertical
            ? Column(
                children: [
                  recent,
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Divider(height: 1, color: Color(0xFFE0E0E3)),
                  ),
                  pinned,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: recent),
                  const SizedBox(
                    height: 190,
                    child: VerticalDivider(width: 44, color: Color(0xFFE0E0E3)),
                  ),
                  Expanded(child: pinned),
                ],
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  빅섹션: 최근 방문 4 + 고정됨 4
  // ─────────────────────────────────────────────────────────
  Widget _buildBigSection({required bool isCompact}) {
    final pinnedItems = _buildPinnedItems();
    return _bigColumn(
      label: 'RECENT',
      items: [..._recentItems, ...pinnedItems],
      isPinnedCol: false,
    );
  }

  /// 고정된 항목들을 BigSectionItem 목록으로 변환
  List<BigSectionItem> _buildPinnedItems() {
    if (widget.previewMode) {
      return const [
        BigSectionItem(
          id: 'preview-pinned-book',
          title: '일차함수 개념서',
          subtitle: '교재',
          color: Color(0xFFF5F5F7),
          type: BigItemType.textbook,
        ),
        BigSectionItem(
          id: 'preview-pinned-exam',
          title: '함수 형성평가',
          subtitle: '시험지',
          color: Color(0xFFF5F5F7),
          type: BigItemType.exam,
        ),
        BigSectionItem(
          id: 'preview-pinned-bookmark',
          title: '기울기 핵심',
          subtitle: '책 북마크',
          color: Color(0xFFF5F5F7),
          type: BigItemType.bookBookmark,
        ),
        BigSectionItem(
          id: 'preview-pinned-problem',
          title: '문제 1',
          subtitle: '문제 북마크',
          color: Color(0xFFF5F5F7),
          type: BigItemType.problemBookmark,
        ),
      ];
    }
    final items = <BigSectionItem>[];

    // 고정된 교재
    if (_pinnedBook != null) {
      items.add(
        BigSectionItem(
          id: _pinnedBook!.id,
          title: _pinnedBook!.title,
          subtitle: '교재',
          color: _pinnedBook!.coverColor ?? BookWidget.darkGreen,
          type: BigItemType.textbook,
        ),
      );
    }

    // 고정된 시험지
    if (_pinnedExamId != null) {
      final exam = ExamPaperStore.notifier.value
          .where((e) => e.examId == _pinnedExamId)
          .firstOrNull;
      if (exam != null) {
        items.add(
          BigSectionItem(
            id: exam.examId,
            title: _examTitle(exam),
            subtitle: '시험지',
            color: BookWidget.mediumGreen,
            type: BigItemType.exam,
          ),
        );
      }
    }

    // 고정된 책 북마크
    if (_pinnedBookBookmarkId != null) {
      final bm = _bookBookmarks
          .where((b) => b.id == _pinnedBookBookmarkId)
          .firstOrNull;
      if (bm != null) {
        items.add(
          BigSectionItem(
            id: bm.id,
            title: bm.entryTitle,
            subtitle: '책 북마크 · ${bm.bookTitle}',
            color: BookWidget.primaryGreen,
            type: BigItemType.bookBookmark,
          ),
        );
      }
    }

    // 고정된 문제 북마크
    if (_pinnedProblemBookmarkId != null) {
      final bm = _problemBookmarks.allItems
          .where((b) => b.id == _pinnedProblemBookmarkId)
          .firstOrNull;
      if (bm != null) {
        items.add(
          BigSectionItem(
            id: bm.id,
            title: bm.title,
            subtitle: '문제 북마크 · ${bm.source}',
            color: BookWidget.mediumGreen,
            type: BigItemType.problemBookmark,
          ),
        );
      }
    }

    return items;
  }

  Widget _bigColumn({
    required String label,
    required List<BigSectionItem> items,
    required bool isPinnedCol,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
            ),
            _BookbagCountBadge(
              label: isPinnedCol ? '${items.length}개' : '최대 4개',
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          const SizedBox(
            height: 126,
            child: Center(
              child: Text(
                '아직 없어요',
                style: TextStyle(color: Color(0xFF77777D), fontSize: 13),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 14) / 2;
              return Wrap(
                spacing: 14,
                runSpacing: 0,
                children: items
                    .take(4)
                    .map(
                      (item) => SizedBox(
                        width: itemWidth,
                        child: _bigCard(item: item, showPin: isPinnedCol),
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }

  /// 필요한 변수는 자료 항목과 고정 표시 여부다.
  /// 작동 원리는 시안의 작은 아이콘·제목·종류·고정 마름모를 한 행에 배치하고 누르면 실제 자료를 연다.
  Widget _bigCard({required BigSectionItem item, required bool showPin}) {
    final icon = _bigItemIcon(item.type);
    return InkWell(
      onTap: () => _openBigItem(item),
      child: SizedBox(
        height: 72,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE0E0E2))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F9),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFDDDDE1)),
                ),
                child: Icon(icon, color: Colors.black, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LatexLine(
                      item.title,
                      style: const TextStyle(
                        color: Color(0xFF171719),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _LatexLine(
                      item.subtitle,
                      style: TextStyle(
                        color: const Color(0xFF707075),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (showPin) ...[
                const SizedBox(width: 6),
                const Icon(Icons.diamond, size: 9, color: Colors.black),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _bigItemIcon(BigItemType type) {
    switch (type) {
      case BigItemType.textbook:
        return Icons.menu_book_rounded;
      case BigItemType.exam:
        return Icons.description_rounded;
      case BigItemType.bookBookmark:
        return Icons.bookmark_rounded;
      case BigItemType.problemBookmark:
        return Icons.bookmark_rounded;
    }
  }

  void _openBigItem(BigSectionItem item) {
    switch (item.type) {
      case BigItemType.textbook:
        final book = _libraryBooks.where((b) => b.id == item.id).firstOrNull;
        if (book != null) _openTextbook(context, book);
      case BigItemType.exam:
        final exam = ExamPaperStore.notifier.value
            .where((e) => e.examId == item.id)
            .firstOrNull;
        if (exam != null) _openExamPaper(context, exam);
      case BigItemType.bookBookmark:
        _showBookmarkDetailModal(isBook: true);
        break;
      case BigItemType.problemBookmark:
        _showBookmarkDetailModal(isBook: false);
        break;
    }
  }

  // ══════════════════════════════════════════════════════════
  //  BOTTOM SECTION
  // ══════════════════════════════════════════════════════════
  /// 필요한 변수는 화면 방향과 네 자료 보관함 열기 콜백이다.
  /// 작동 원리는 데스크톱에서는 네 칸, 모바일에서는 네 행으로 자료별 설명과 진입 버튼을 배치하는 것이다.
  Widget _buildLibraryActions({required bool vertical}) {
    final actions = <Widget>[
      _BookbagLibraryAction(
        icon: Icons.menu_book_outlined,
        title: '교재보기',
        description: '제목·태그 검색, 교재 상세, 최근 읽기와 고정',
        buttonLabel: '보관된 교재',
        onTap: () => _showTextbookModal(context),
      ),
      _BookbagLibraryAction(
        icon: Icons.description_outlined,
        title: '시험지보기',
        description: '시험지 검색, 응시 상태, 이어풀기와 고정',
        buttonLabel: '보관된 시험지',
        onTap: () => _showExamModal(context),
      ),
      _BookbagLibraryAction(
        icon: Icons.bookmark,
        title: '책 북마크',
        description: '교재 장·절 위치 검색, 상세 보기와 고정',
        buttonLabel: '책 북마크',
        onTap: () => _showBookmarkDetailModal(isBook: true),
      ),
      _BookbagLibraryAction(
        icon: Icons.edit_outlined,
        title: '문제 북마크',
        description: '서버·로컬 문항 병합, 출처 검색과 고정',
        buttonLabel: '문제 북마크',
        onTap: () => _showBookmarkDetailModal(isBook: false),
      ),
    ];
    return _buildSectionCard(
      title: '',
      child: vertical
          ? Column(
              children: [
                for (var index = 0; index < actions.length; index++) ...[
                  actions[index],
                  if (index < actions.length - 1)
                    const Divider(height: 1, color: Color(0xFFE0E0E3)),
                ],
              ],
            )
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < actions.length; index++) ...[
                    Expanded(child: actions[index]),
                    if (index < actions.length - 1)
                      const VerticalDivider(width: 1, color: Color(0xFFE0E0E3)),
                  ],
                ],
              ),
            ),
    );
  }

  /// 필요한 변수는 진행 중인 코스와 화면 폭이다.
  /// 작동 원리는 책가방 자료 카드 아래에 현재 코스·추천 코스·새 코스 찾기를 가로 또는 세로 목록으로 표시하는 것이다.
  Widget _buildBottomSection(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final vertical = width < _bodyStackBreakpoint;
    return Center(
      child: ConstrainedBox(
        key: ValueKey(
          vertical ? 'bookbag-bottom-stacked' : 'bookbag-bottom-columns',
        ),
        constraints: const BoxConstraints(maxWidth: 1440),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            vertical ? 16 : 54,
            14,
            vertical ? 16 : 54,
            44,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(height: 1, color: Color(0xFFDCDCE0)),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BookbagEyebrow('ACTIVE COURSES'),
                        SizedBox(height: 16),
                        Text(
                          '진행 중인 코스',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _BookbagButton(
                    label: '코스 전체 보기',
                    onTap: () => Navigator.of(context).pushNamed('/courses'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _buildCourseStrip(vertical: vertical),
            ],
          ),
        ),
      ),
    );
  }

  /// 필요한 변수는 서버에서 조회한 미완료 코스 목록과 화면 방향이다.
  /// 작동 원리는 최근 학습 순서의 실제 코스 최대 두 개를 표시하고, 데이터가 없으면 빈 상태와 탐색 동작만 제공하는 것이다.
  Widget _buildCourseStrip({required bool vertical}) {
    final items = <Widget>[
      if (_activeCourses.isEmpty)
        _BookbagCourseItem(
          title: '진행 중인 코스가 없습니다',
          detail: '나에게 맞는 코스를 찾아 학습을 시작하세요',
          icon: Icons.school_outlined,
          onTap: () => Navigator.of(context).pushNamed('/courses'),
        )
      else
        for (final course in _activeCourses.take(2))
          _BookbagCourseItem(
            title: course.title,
            detail: _courseProgressDetail(course),
            icon: Icons.play_arrow_rounded,
            onTap: () => Navigator.of(context).pushNamed('/courses'),
          ),
      _BookbagCourseItem(
        title: '새 코스 찾기',
        detail: 'OVR에 맞는 코스 탐색',
        icon: Icons.add_rounded,
        onTap: () => Navigator.of(context).pushNamed('/courses'),
      ),
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFDCDCE0)),
          bottom: BorderSide(color: Color(0xFFDCDCE0)),
        ),
      ),
      child: vertical
          ? Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  items[index],
                  if (index < items.length - 1)
                    const Divider(height: 1, color: Color(0xFFE0E0E3)),
                ],
              ],
            )
          : Row(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  Expanded(child: items[index]),
                  if (index < items.length - 1)
                    const SizedBox(
                      height: 86,
                      child: VerticalDivider(
                        width: 1,
                        color: Color(0xFFE0E0E3),
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  /// 필요한 변수는 코스의 진행률과 유닛 상태다.
  /// 작동 원리는 진행률을 서버 값에서 계산하고 활성 유닛이 있으면 다음 학습 항목을 함께 안내하는 것이다.
  String _courseProgressDetail(Course course) {
    final progress = (course.progress.clamp(0.0, 1.0) * 100).round();
    final nextUnit = course.units.cast<CourseUnit?>().firstWhere(
      (unit) => unit?.status == CourseUnitStatus.active,
      orElse: () => null,
    );
    if (nextUnit == null || nextUnit.title.trim().isEmpty) {
      return '진행률 $progress%';
    }
    return '진행률 $progress% · 다음: ${nextUnit.title}';
  }

  /// 필요한 변수는 선택한 자료 구역 ID와 현재 펼침 ID다.
  /// 작동 원리는 같은 행을 다시 누르면 닫고 다른 행을 누르면 해당 실제 자료 미리보기만 펼치는 것이다.
  void _toggleLibrarySection(String section) {
    if (_expandedLibrarySection == section) {
      switch (section) {
        case 'books':
          _showTextbookModal(context);
        case 'exams':
          _showExamModal(context);
        case 'bookmarks':
          _showBookmarkDetailModal(isBook: true);
        case 'problems':
          _showBookmarkDetailModal(isBook: false);
      }
      return;
    }
    setState(() {
      _expandedLibrarySection = section;
    });
  }

  // ─────────────────────────────────────────────────────────
  //  교재 미리보기 (오버플로우 해결: 자연 높이)
  // ─────────────────────────────────────────────────────────
  Widget _buildCompactTextbookPreview() {
    final books = _libraryBooks.take(2).toList();
    final slots = List<BookData?>.generate(
      2,
      (i) => i < books.length ? books[i] : null,
    );
    final showEmptyLabel = books.isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            children: slots
                .asMap()
                .entries
                .map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(
                      bottom: entry.key == slots.length - 1 ? 0 : 8,
                    ),
                    child: entry.value == null
                        ? const _DocEmptySlot(label: '아직 없어요')
                        : _docItem(
                            icon: Icons.menu_book_rounded,
                            title: entry.value!.title,
                            sub: _bookSubtitle(entry.value!),
                            onTap: () => _openTextbook(context, entry.value!),
                          ),
                  ),
                )
                .toList(),
          ),
          if (showEmptyLabel)
            const IgnorePointer(
              child: Text(
                '아직 없어요',
                style: TextStyle(fontSize: 18, color: Colors.black45),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  시험지 미리보기 (오버플로우 해결)
  // ─────────────────────────────────────────────────────────
  Widget _buildCompactExamPreview() {
    return ValueListenableBuilder<List<ExamPaperEntry>>(
      valueListenable: ExamPaperStore.notifier,
      builder: (context, all, _) {
        final items = all.take(2).toList();
        final slots = List<ExamPaperEntry?>.generate(
          2,
          (i) => i < items.length ? items[i] : null,
        );
        final showEmptyLabel = items.isEmpty;
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                children: slots
                    .asMap()
                    .entries
                    .map(
                      (slot) => Padding(
                        padding: EdgeInsets.only(
                          bottom: slot.key == slots.length - 1 ? 0 : 8,
                        ),
                        child: slot.value == null
                            ? const _DocEmptySlot(label: '아직 없어요')
                            : _docItem(
                                icon: Icons.description_rounded,
                                title: _examTitle(slot.value!),
                                sub: _examSubtitle(slot.value!),
                                onTap: () =>
                                    _openExamPaper(context, slot.value!),
                              ),
                      ),
                    )
                    .toList(),
              ),
              if (showEmptyLabel)
                const IgnorePointer(
                  child: Text(
                    '아직 없어요',
                    style: TextStyle(fontSize: 18, color: Colors.black45),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────
  //  교재/시험지 개별 아이템
  //  ▸ border 제거, shadow만, 배경 흰색
  // ─────────────────────────────────────────────────────────
  Widget _docItem({
    required IconData icon,
    required String title,
    required String sub,
    VoidCallback? onTap,
  }) {
    final inner = Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: BookWidget.primaryGreen.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 56,
            child: Center(
              child: Icon(icon, color: BookWidget.primaryGreen, size: 24),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LatexLine(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _LatexLine(
                    sub,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return inner;
    return GestureDetector(onTap: onTap, child: inner);
  }

  // ─────────────────────────────────────────────────────────
  //  북마크 패널
  //  ▸ border 제거, shadow만, 배경 흰색
  // ─────────────────────────────────────────────────────────
  Widget _buildBookmarkPanelContent({required bool isBook}) {
    final items = isBook
        ? _bookBookmarks
              .map(
                (e) => _BmItem(id: e.id, title: e.entryTitle, sub: e.bookTitle),
              )
              .toList()
        : _problemBookmarks.allItems.toList().asMap().entries.map((entry) {
            final e = entry.value;
            return _BmItem(
              id: e.id,
              title: '문제 ${entry.key + 1}',
              sub: e.source.trim().isEmpty ? '풀이 흐름' : e.source,
            );
          }).toList();

    final pinnedId = isBook ? _pinnedBookBookmarkId : _pinnedProblemBookmarkId;
    final preview = items.take(2).toList();
    final showEmptyLabel = preview.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: showEmptyLabel
          ? const SizedBox(
              height: 52,
              child: Center(
                child: Text(
                  '아직 없어요',
                  style: TextStyle(fontSize: 15, color: Colors.black45),
                ),
              ),
            )
          : Column(
              children: preview.asMap().entries.map((entry) {
                final item = entry.value;
                final isPinned = item.id == pinnedId;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == preview.length - 1 ? 0 : 6,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: BookWidget.primaryGreen.withValues(alpha: 0.2),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: Center(
                            child: Icon(
                              Icons.bookmark_rounded,
                              color: BookWidget.primaryGreen,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _LatexLine(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                              ),
                              const SizedBox(height: 2),
                              _LatexLine(
                                item.sub,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.2,
                                  color: Colors.black54,
                                ),
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        if (isPinned)
                          const Text(
                            '고정',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: BookWidget.mediumGreen,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  코스 섹션 (퍼센트 텍스트만, 게이지 제거)
  // ─────────────────────────────────────────────────────────
  Widget _buildCourseSection() {
    if (_activeCourse == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: _EmptyState(label: '아직 코스가 없어요!'),
      );
    }
    final units = _activeCourse!.units;
    final completed = units
        .where((u) => u.status == CourseUnitStatus.completed)
        .length;
    final total = units.isEmpty ? 3 : units.length;
    final pct = total > 0 ? ((completed / total) * 100).round() : 0;

    final current = units.indexWhere(
      (u) => u.status == CourseUnitStatus.active,
    );
    final currentIndex = current >= 0 ? current : completed.clamp(0, total - 1);

    final trackTypes = List.generate(total, (i) {
      if (i < currentIndex) return _TrackNode.done;
      if (i == currentIndex) return _TrackNode.current;
      return _TrackNode.next;
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LatexLine(
            _activeCourse!.title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          // 트랙
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < trackTypes.length; i++) ...[
                  if (i > 0)
                    Container(
                      width: 20,
                      height: 2.5,
                      color: trackTypes[i] == _TrackNode.next
                          ? const Color(0xFFE8EDF0)
                          : BookWidget.mediumGreen,
                    ),
                  _trackNode(trackTypes[i]),
                ],
                const SizedBox(width: 6),
                Icon(
                  completed >= total
                      ? Icons.flag_rounded
                      : Icons.arrow_forward_rounded,
                  color: BookWidget.primaryGreen,
                  size: 18,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 퍼센트 텍스트 (게이지 없음)
          _LatexLine(
            '$completed / $total 단계 완료  ·  $pct%',
            style: const TextStyle(
              fontSize: 12,
              color: BookWidget.primaryGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trackNode(_TrackNode type) {
    final bg = type == _TrackNode.done
        ? BookWidget.mediumGreen
        : type == _TrackNode.current
        ? BookWidget.primaryGreen
        : Colors.white;

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: Border.all(color: BookWidget.primaryGreen, width: 2),
      ),
      child: type == _TrackNode.done
          ? const Icon(Icons.check, color: Colors.white, size: 10)
          : type == _TrackNode.current
          ? const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 11)
          : null,
    );
  }

  // ══════════════════════════════════════════════════════════
  //  SECTION CARD WRAPPER
  // ══════════════════════════════════════════════════════════
  Widget _buildSectionCard({
    required String title,
    required Widget child,
    VoidCallback? onArrowTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0E0E2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (onArrowTap != null)
                    InkWell(
                      borderRadius: BorderRadius.circular(7),
                      onTap: onArrowTap,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 8),
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }

  /// 필요한 변수는 모바일 여부와 전체 검색 모달 콜백이다.
  /// 작동 원리는 HTML 히어로 우측의 검정 캡슐 버튼으로 모든 학습 자료 검색을 여는 것이다.
  Widget _buildSearchBar({bool isCompact = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showGlobalSearch(context),
        child: Container(
          width: isCompact ? 88 : 120,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: const Text(
            '전체 검색',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  MODALS (기존 유지)
  // ══════════════════════════════════════════════════════════
  void _showExamModal(BuildContext context) =>
      _showArchiveModal(context, archiveType: _ArchiveType.exam);

  void _showTextbookModal(BuildContext context) =>
      _showArchiveModal(context, archiveType: _ArchiveType.textbook);

  void _showArchiveModal(
    BuildContext context, {
    required _ArchiveType archiveType,
  }) {
    final rootContext = context;
    final selected = <String>{};
    var editMode = false;
    final isExam = archiveType == _ArchiveType.exam;
    _bookSearchController.text = _bookSearchQuery.value;

    showIos26Modal(
      context: context,
      maxWidth: 760,
      maxHeight: 700,
      child: StatefulBuilder(
        builder: (context, setState) {
          final dialogContext = context;
          Future<void> deleteSelected() async {
            final ids = List<String>.from(selected);
            if (isExam) {
              for (final id in ids) {
                await ExamPaperStore.remove(id);
              }
            } else {
              for (final id in ids) {
                await TextbookStore.removeFromLibrary(id);
                if (_pinnedBook?.id == id) {
                  await LocalDb.instance.setString(_pinnedBookKey, '');
                  _pinnedBook = null;
                }
              }
              await _loadLibraryBooks();
            }
            selected.clear();
            editMode = false;
            setState(() {});
          }

          Widget listWidget() {
            if (isExam) {
              return ValueListenableBuilder<List<ExamPaperEntry>>(
                valueListenable: ExamPaperStore.notifier,
                builder: (context, items, _) {
                  final query = _bookSearchQuery.value.trim().toLowerCase();
                  final ordered = items.where((entry) {
                    if (query.isEmpty) return true;
                    return _examSearchText(entry).toLowerCase().contains(query);
                  }).toList();
                  if (_pinnedExamId != null) {
                    ordered.sort((a, b) {
                      if (a.examId == _pinnedExamId) return -1;
                      if (b.examId == _pinnedExamId) return 1;
                      return b.createdAt.compareTo(a.createdAt);
                    });
                  }
                  if (ordered.isEmpty) {
                    return const Center(
                      child: Text(
                        '아직 없어요!',
                        style: TextStyle(color: Colors.black54),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: ordered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = ordered[index];
                      final checked = selected.contains(entry.examId);
                      final isPinned = _pinnedExamId == entry.examId;
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: editMode
                              ? Checkbox(
                                  value: checked,
                                  onChanged: (v) => setState(() {
                                    if (v == true) {
                                      selected.add(entry.examId);
                                    } else {
                                      selected.remove(entry.examId);
                                    }
                                  }),
                                )
                              : CircleAvatar(
                                  backgroundColor: BookWidget.mediumGreen,
                                  child: const Icon(
                                    Icons.file_copy_outlined,
                                    color: Colors.white,
                                  ),
                                ),
                          title: _LatexLine(_examTitle(entry)),
                          subtitle: _LatexLine(
                            _examSubtitle(entry),
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12.5,
                            ),
                          ),
                          trailing: editMode
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: isPinned ? '고정해제' : '고정',
                                      onPressed: () => _setPinnedExam(
                                        isPinned ? null : entry.examId,
                                      ),
                                      icon: Icon(
                                        isPinned
                                            ? Icons.push_pin
                                            : Icons.push_pin_outlined,
                                        size: 18,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 16,
                                    ),
                                  ],
                                ),
                          onTap: () {
                            if (editMode) return;
                            Navigator.of(dialogContext).pop();
                            _openExamPaper(rootContext, entry);
                          },
                        ),
                      );
                    },
                  );
                },
              );
            }

            return FutureBuilder<List<BookData>>(
              future: TextbookStore.loadLibrary(),
              builder: (context, snapshot) {
                final books = snapshot.data ?? const <BookData>[];
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ValueListenableBuilder<String>(
                  valueListenable: _bookSearchQuery,
                  builder: (context, query, _) {
                    final lower = query.toLowerCase();
                    final filtered = books.where((book) {
                      if (lower.isEmpty) return true;
                      return book.title.toLowerCase().contains(lower) ||
                          book.subtitle.toLowerCase().contains(lower) ||
                          book.tags.join(' ').toLowerCase().contains(lower);
                    }).toList();
                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text(
                          '아직 없어요!',
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final book = filtered[index];
                        final checked = selected.contains(book.id);
                        final isPinned = _pinnedBook?.id == book.id;
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            leading: editMode
                                ? Checkbox(
                                    value: checked,
                                    onChanged: (v) => setState(() {
                                      if (v == true) {
                                        selected.add(book.id);
                                      } else {
                                        selected.remove(book.id);
                                      }
                                    }),
                                  )
                                : CircleAvatar(
                                    backgroundColor:
                                        book.coverColor ?? BookWidget.darkGreen,
                                    child: const Icon(
                                      Icons.book_outlined,
                                      color: Colors.white,
                                    ),
                                  ),
                            title: _LatexLine(book.title),
                            subtitle: _LatexLine(
                              _bookSubtitle(book),
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12.5,
                              ),
                            ),
                            trailing: editMode
                                ? null
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: isPinned ? '고정해제' : '고정',
                                        onPressed: () => _pinBook(book),
                                        icon: Icon(
                                          isPinned
                                              ? Icons.push_pin
                                              : Icons.push_pin_outlined,
                                          size: 18,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                            onTap: () {
                              if (editMode) return;
                              Navigator.of(dialogContext).pop();
                              _openTextbook(rootContext, book);
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          }

          return Ios26ModalShell(
            title: isExam ? '보관된 시험지' : '보관된 교재',
            onClose: () => Navigator.of(dialogContext).pop(),
            trailing: IconButton(
              tooltip: selected.isNotEmpty
                  ? '선택 삭제'
                  : (editMode ? '편집 종료' : '편집'),
              icon: Icon(
                selected.isNotEmpty
                    ? Icons.delete_outline
                    : Icons.edit_outlined,
                color: BookWidget.primaryGreen,
              ),
              onPressed: selected.isNotEmpty
                  ? deleteSelected
                  : () => setState(() {
                      if (editMode) {
                        editMode = false;
                        selected.clear();
                      } else {
                        editMode = true;
                      }
                    }),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  _searchField(
                    controller: _bookSearchController,
                    hintText: isExam ? '시험지 내용 또는 유형 검색' : '교재 제목 또는 태그 검색',
                    onChanged: (v) =>
                        setState(() => _bookSearchQuery.value = v.trim()),
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: listWidget()),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showBookmarkDetailModal({required bool isBook}) {
    final rootContext = context;
    final rawItems = isBook
        ? _bookBookmarks
              .map(
                (e) => {
                  'id': e.id,
                  'title': e.entryTitle,
                  'sub': e.bookTitle,
                  'created': e.createdAt,
                  'bookmark': e,
                },
              )
              .toList()
        : _problemBookmarks.allItems
              .toList()
              .asMap()
              .entries
              .map(
                (entry) => {
                  'id': entry.value.id,
                  'title': '문제 ${entry.key + 1}',
                  'sub': entry.value.source.trim().isEmpty
                      ? '풀이 흐름'
                      : entry.value.source,
                  'search': entry.value.title,
                  'created': entry.value.createdAt,
                  'bookmark': entry.value,
                },
              )
              .toList();
    final selected = <String>{};
    var editMode = false;

    showIos26Modal<void>(
      context: context,
      maxWidth: 780,
      maxHeight: 640,
      child: Builder(
        builder: (dialogContext) {
          final filterController = TextEditingController();
          var filter = '';
          return StatefulBuilder(
            builder: (context, setModalState) {
              final pinnedId = isBook
                  ? _pinnedBookBookmarkId
                  : _pinnedProblemBookmarkId;
              final visibleItems = rawItems.where((item) {
                final q = filter.trim().toLowerCase();
                if (q.isEmpty) return true;
                return '${item['title']} ${item['sub']} ${item['search'] ?? ''}'
                    .toLowerCase()
                    .contains(q);
              }).toList();

              Future<void> deleteSelected() async {
                for (final id in selected) {
                  if (isBook) {
                    await BookmarkStore.remove(id);
                    if (_pinnedBookBookmarkId == id) {
                      await _pinBookmark(isBook: true, id: null);
                    }
                  } else {
                    await ProblemBookmarkStore.remove(id);
                    if (_pinnedProblemBookmarkId == id) {
                      await _pinBookmark(isBook: false, id: null);
                    }
                  }
                }
                await _loadBookmarks();
                rawItems.removeWhere(
                  (item) => selected.contains(item['id']?.toString()),
                );
                selected.clear();
                editMode = false;
                setModalState(() {});
              }

              Widget listWidget() {
                if (visibleItems.isEmpty) {
                  return const Center(
                    child: Text(
                      '북마크가 없습니다.',
                      style: TextStyle(color: Color(0xFF69756D)),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: visibleItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = visibleItems[index];
                    final id = item['id']?.toString();
                    final isPinned =
                        id != null && id.isNotEmpty && id == pinnedId;
                    final checked = id != null && selected.contains(id);

                    return ListTile(
                      minVerticalPadding: 10,
                      leading: editMode
                          ? Checkbox(
                              value: checked,
                              onChanged: id == null
                                  ? null
                                  : (value) => setModalState(() {
                                      if (value == true) {
                                        selected.add(id);
                                      } else {
                                        selected.remove(id);
                                      }
                                    }),
                            )
                          : CircleAvatar(
                              backgroundColor: BookWidget.darkGreen,
                              child: Icon(
                                isBook
                                    ? Icons.bookmark_outline_rounded
                                    : Icons.quiz_outlined,
                                color: Colors.white,
                              ),
                            ),
                      title: _LatexLine(
                        item['title']?.toString() ?? '-',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LatexLine(
                            item['sub']?.toString() ?? '',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12.5,
                            ),
                            maxLines: 1,
                          ),
                          Text(
                            '저장일 ${_formatExamDate((item['created'] as int?) ?? 0)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black38,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                      trailing: editMode
                          ? null
                          : IconButton(
                              tooltip: isPinned ? '고정해제' : '고정',
                              onPressed: id == null || id.isEmpty
                                  ? null
                                  : () async {
                                      await _pinBookmark(
                                        isBook: isBook,
                                        id: isPinned ? null : id,
                                      );
                                      if (!mounted) return;
                                      setModalState(() {});
                                    },
                              icon: Icon(
                                isPinned
                                    ? Icons.push_pin
                                    : Icons.push_pin_outlined,
                                color: BookWidget.primaryGreen,
                                size: 20,
                              ),
                            ),
                      onTap: editMode || id == null
                          ? null
                          : () {
                              final bookmark = item['bookmark'];
                              Navigator.of(dialogContext).pop();
                              if (isBook && bookmark is BookmarkItem) {
                                final book = _libraryBooks
                                    .where(
                                      (entry) => entry.id == bookmark.bookId,
                                    )
                                    .firstOrNull;
                                if (book != null) {
                                  Navigator.of(rootContext).push(
                                    MaterialPageRoute(
                                      builder: (_) => book_page.BookWidget(
                                        book: book,
                                        initialEntryIndex: bookmark.entryIndex,
                                      ),
                                    ),
                                  );
                                }
                              } else if (bookmark is ProblemBookmarkItem) {
                                Navigator.of(rootContext).push(
                                  MaterialPageRoute(
                                    builder: (_) => SolutionViewPage(
                                      initialQuestId: bookmark.questId,
                                      initialTextQuery: bookmark.questId == null
                                          ? bookmark.title
                                          : null,
                                      autoSearch: true,
                                    ),
                                  ),
                                );
                              }
                            },
                    );
                  },
                );
              }

              return Ios26ModalShell(
                title: isBook ? '책 북마크' : '문제 북마크',
                onClose: () => Navigator.of(dialogContext).pop(),
                trailing: IconButton(
                  tooltip: selected.isNotEmpty
                      ? '선택 삭제'
                      : (editMode ? '편집 종료' : '편집'),
                  icon: Icon(
                    selected.isNotEmpty
                        ? Icons.delete_outline
                        : Icons.edit_outlined,
                    color: BookWidget.primaryGreen,
                  ),
                  onPressed: selected.isNotEmpty
                      ? deleteSelected
                      : () => setModalState(() {
                          editMode = !editMode;
                          if (!editMode) selected.clear();
                        }),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      _searchField(
                        controller: filterController,
                        hintText: isBook
                            ? '책 북마크 제목 또는 교재 검색'
                            : '문제 북마크 제목 또는 출처 검색',
                        onChanged: (value) =>
                            setModalState(() => filter = value.trim()),
                      ),
                      const SizedBox(height: 12),
                      Expanded(child: listWidget()),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showGlobalSearch(BuildContext context) {
    _globalSearchController.text = _globalSearchQuery.value;
    showIos26Modal(
      context: context,
      maxWidth: 880,
      maxHeight: 720,
      child: Builder(
        builder: (dialogContext) {
          return Ios26ModalShell(
            title: '전체 검색',
            onClose: () => Navigator.of(dialogContext).pop(),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '교재 목차/요약과 시험지를 한 번에 찾아요',
                    style: TextStyle(color: Color(0xFF69756D), fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  _searchField(
                    controller: _globalSearchController,
                    hintText: '예: 미적분 모의고사 / 한국사 교재 / 그래프 단원',
                    onChanged: (v) => _globalSearchQuery.value = v.trim(),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: _globalSearchQuery,
                      builder: (context, query, _) {
                        final q = query.toLowerCase();
                        return _globalUnifiedSearchList(dialogContext, q);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _globalUnifiedSearchList(BuildContext dialogContext, String query) {
    return FutureBuilder<List<BookData>>(
      future: TextbookStore.loadLibrary(),
      builder: (context, snapshot) {
        final books = snapshot.data ?? const <BookData>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ValueListenableBuilder<List<ExamPaperEntry>>(
          valueListenable: ExamPaperStore.notifier,
          builder: (context, exams, _) {
            final rows = <_ArchiveSearchRow>[];
            for (final book in books) {
              final haystack = _bookContentText(book).toLowerCase();
              if (query.isEmpty || haystack.contains(query)) {
                rows.add(
                  _ArchiveSearchRow.book(
                    title: book.title,
                    subtitle: _bookSearchSnippet(book, query),
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      _openTextbook(context, book);
                    },
                    color: book.coverColor ?? BookWidget.darkGreen,
                  ),
                );
              }
            }
            for (final exam in exams) {
              final haystack = _examSearchText(exam).toLowerCase();
              if (query.isEmpty || haystack.contains(query)) {
                rows.add(
                  _ArchiveSearchRow.exam(
                    title: _examTitle(exam),
                    subtitle: _examSearchSnippet(exam, query),
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      _openExamPaper(context, exam);
                    },
                  ),
                );
              }
            }

            if (rows.isEmpty) {
              return const Center(
                child: Text(
                  '일치하는 항목이 없습니다.',
                  style: TextStyle(color: Colors.black54),
                ),
              );
            }

            return Scrollbar(
              thumbVisibility: true,
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) => rows[index].build(),
              ),
            );
          },
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════
  //  NAVIGATION
  // ══════════════════════════════════════════════════════════
  void _openExamPaper(BuildContext context, ExamPaperEntry entry) {
    unawaited(_recordRecentVisit('exam', entry.examId));
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => exam_page.ExamPaperPage(
          examId: entry.examId,
          expectedQuestionCount: entry.questionCount > 0
              ? entry.questionCount
              : null,
        ),
      ),
    );
  }

  void _openTextbook(BuildContext context, BookData book) {
    unawaited(_recordRecentVisit('book', book.id));
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => book_page.BookWidget(book: book)));
  }

  // ══════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ══════════════════════════════════════════════════════════
  Widget _searchField({
    required TextEditingController controller,
    required String hintText,
    required ValueChanged<String> onChanged,
  }) => TextField(
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

  // ══════════════════════════════════════════════════════════
  //  FORMATTERS / HELPERS
  // ══════════════════════════════════════════════════════════
  String _examTitle(ExamPaperEntry entry) =>
      '${_examTypeLabel(entry.paperType)} 시험지';

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
    final b = StringBuffer();
    b.write('${book.title} ${book.subtitle} ');
    if (book.tags.isNotEmpty) b.write('${book.tags.join(' ')} ');
    for (final ch in book.chapters) {
      b.write('${ch.title} ');
      for (final p in ch.intro) {
        b.write('$p ');
      }
      for (final s in ch.sections) {
        b.write('${s.title} ');
        for (final p in s.paragraphs) {
          b.write('$p ');
        }
      }
    }
    return b.toString();
  }

  String _bookSearchSnippet(BookData book, String query) {
    final target = query.trim().toLowerCase();
    if (target.isEmpty) return _bookSubtitle(book);
    for (final chapter in book.chapters) {
      for (final text in <String>[
        chapter.title,
        ...chapter.intro,
        for (final section in chapter.sections) section.title,
        for (final section in chapter.sections) ...section.paragraphs,
      ]) {
        final lower = text.toLowerCase();
        final index = lower.indexOf(target);
        if (index < 0) continue;
        final start = (index - 24).clamp(0, text.length).toInt();
        final end = (index + target.length + 52).clamp(0, text.length).toInt();
        return '${start > 0 ? '...' : ''}${text.substring(start, end)}${end < text.length ? '...' : ''}';
      }
    }
    return _bookSubtitle(book);
  }

  String _examSearchText(ExamPaperEntry entry) {
    return [
      _examTitle(entry),
      _examSubtitle(entry),
      entry.examId,
      entry.paperType,
      '${entry.questionCount}',
      entry.searchIndex,
    ].join(' ');
  }

  String _examSearchSnippet(ExamPaperEntry entry, String query) {
    final target = query.trim().toLowerCase();
    if (target.isEmpty || entry.searchIndex.trim().isEmpty) {
      return _examSubtitle(entry);
    }
    final lower = entry.searchIndex.toLowerCase();
    final index = lower.indexOf(target);
    if (index < 0) return _examSubtitle(entry);
    final start = (index - 24).clamp(0, entry.searchIndex.length).toInt();
    final end = (index + target.length + 52)
        .clamp(0, entry.searchIndex.length)
        .toInt();
    final snippet =
        '${start > 0 ? '...' : ''}${entry.searchIndex.substring(start, end)}${end < entry.searchIndex.length ? '...' : ''}';
    return '시험지 내부 문제 · $snippet';
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
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${(d.year % 100).toString().padLeft(2, '0')}'
        '.${d.month.toString().padLeft(2, '0')}'
        '.${d.day.toString().padLeft(2, '0')}';
  }

  String _formatBookDate(DateTime? date) {
    if (date == null) return '--.--.--';
    return '${(date.year % 100).toString().padLeft(2, '0')}'
        '.${date.month.toString().padLeft(2, '0')}'
        '.${date.day.toString().padLeft(2, '0')}';
  }
}

// ══════════════════════════════════════════════════════════
//  SMALL HELPERS
// ══════════════════════════════════════════════════════════

/// 북마크 패널 내부용 간단 모델
class _BmItem {
  final String id;
  final String title;
  final String sub;
  const _BmItem({required this.id, required this.title, required this.sub});
}

class _LatexLine extends StatelessWidget {
  const _LatexLine(
    this.text, {
    this.style = const TextStyle(color: Colors.black87, fontSize: 14),
    this.maxLines,
  });

  final String text;
  final TextStyle style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: maxLines == null
          ? const BoxConstraints()
          : BoxConstraints(
              maxHeight: (style.fontSize ?? 14) * 1.35 * maxLines!,
            ),
      child: ClipRect(
        child: ContentBlocksView(
          inline: true,
          blocks: parseTextWithLatex(text),
          textStyle: style,
          latexStyle: style,
        ),
      ),
    );
  }
}

class _ArchiveSearchRow {
  const _ArchiveSearchRow._({
    required this.icon,
    required this.color,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  factory _ArchiveSearchRow.book({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return _ArchiveSearchRow._(
      icon: Icons.menu_book_rounded,
      color: color,
      label: '교재 목차/요약',
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }

  factory _ArchiveSearchRow.exam({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return _ArchiveSearchRow._(
      icon: Icons.assignment_outlined,
      color: BookWidget.mediumGreen,
      label: '시험지',
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }

  final IconData icon;
  final Color color;
  final String label;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  Widget build() {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color,
        child: Icon(icon, color: Colors.white),
      ),
      title: _LatexLine(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: BookWidget.primaryGreen,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          ContentBlocksView(
            inline: true,
            blocks: parseTextWithLatex(subtitle),
            textStyle: const TextStyle(color: Colors.black54, fontSize: 12.5),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 16),
      onTap: onTap,
    );
  }
}

class _DocEmptySlot extends StatelessWidget {
  final String label;
  const _DocEmptySlot({required this.label});

  @override
  Widget build(BuildContext context) {
    return const Opacity(
      opacity: 0,
      child: IgnorePointer(child: _DocGhostCard()),
    );
  }
}

class _DocGhostCard extends StatelessWidget {
  const _DocGhostCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x17000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: const [
          SizedBox(width: 44, height: 56),
          SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '더미 제목',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '더미 보조 텍스트',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.chevron_right_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

enum _TrackNode { done, current, next }

class _BookbagEyebrow extends StatelessWidget {
  const _BookbagEyebrow(this.label);

  final String label;

  /// 필요한 변수는 영문 구역 이름이다.
  /// 작동 원리는 책가방 시안의 작은 대문자 구역 표식을 동일한 자간과 농도로 출력하는 것이다.
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: Color(0xFF77777E),
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.5,
    ),
  );
}

class _BookbagButton extends StatelessWidget {
  const _BookbagButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  /// 필요한 변수는 버튼 문구·강조 상태·실행 콜백이다.
  /// 작동 원리는 검정 또는 옅은 회색 캡슐 버튼을 만들고 모든 화면 크기에서 최소 터치 높이를 보장하는 것이다.
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: Material(
      color: primary ? Colors.black : const Color(0xFFF7F7F9),
      shape: StadiumBorder(
        side: BorderSide(
          color: primary ? Colors.black : const Color(0xFFDCDCE0),
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: primary ? Colors.white : Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _BookbagMetrics extends StatelessWidget {
  const _BookbagMetrics({
    required this.bookCount,
    required this.examCount,
    required this.bookBookmarkCount,
    required this.problemBookmarkCount,
    required this.onTextbooks,
    required this.onExams,
    required this.onBookBookmarks,
    required this.onProblemBookmarks,
  });

  final int bookCount;
  final int examCount;
  final int bookBookmarkCount;
  final int problemBookmarkCount;
  final VoidCallback onTextbooks;
  final VoidCallback onExams;
  final VoidCallback onBookBookmarks;
  final VoidCallback onProblemBookmarks;

  /// 필요한 변수는 네 자료 종류의 개수다.
  /// 작동 원리는 중요도가 낮은 통계를 우측 구석의 작은 보조 텍스트로만 표시하는 것이다.
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 4,
    alignment: WrapAlignment.end,
    children: [
      _BookbagMetricText(label: '교재', value: bookCount, onTap: onTextbooks),
      _BookbagMetricText(label: '시험지', value: examCount, onTap: onExams),
      _BookbagMetricText(
        label: '책 북마크',
        value: bookBookmarkCount,
        onTap: onBookBookmarks,
      ),
      _BookbagMetricText(
        label: '문제 북마크',
        value: problemBookmarkCount,
        onTap: onProblemBookmarks,
      ),
    ],
  );
}

class _BookbagMetricText extends StatelessWidget {
  const _BookbagMetricText({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final int value;
  final VoidCallback onTap;

  /// 필요한 변수는 자료 종류 이름과 해당 개수다.
  /// 작동 원리는 한 항목을 작은 회색 보조 텍스트로 표시해 본문 시선을 방해하지 않는 것이다.
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(6),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: Color(0xFF8A8A91),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _BookbagCountBadge extends StatelessWidget {
  const _BookbagCountBadge({required this.label});

  final String label;

  /// 필요한 변수는 목록 개수 문구다.
  /// 작동 원리는 최근 방문과 고정 목록 제목 오른쪽에 작은 회색 캡슐을 표시하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F7F9),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFFDCDCE0)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF66666D),
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _BookbagLibraryAction extends StatelessWidget {
  const _BookbagLibraryAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onTap;

  /// 필요한 변수는 자료 종류의 아이콘·제목·설명·버튼 문구와 열기 콜백이다.
  /// 작동 원리는 시안의 네 자료 진입 칸을 만들고 하단 버튼으로 실제 보관함을 연다.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F9),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFDCDCE0)),
            ),
            child: Icon(icon, size: 21, color: Colors.black),
          ),
        ),
        const SizedBox(height: 38),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: const TextStyle(
            color: Color(0xFF77777E),
            fontSize: 11,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        _BookbagButton(label: buttonLabel, onTap: onTap),
      ],
    ),
  );
}

class _BookbagCourseItem extends StatelessWidget {
  const _BookbagCourseItem({
    required this.title,
    required this.detail,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;

  /// 필요한 변수는 코스 제목·진행 설명·아이콘과 이동 콜백이다.
  /// 작동 원리는 코스 스트립 한 칸을 만들고 누르면 코스 목록으로 이동한다.
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDCDCE0)),
            ),
            child: Icon(icon, color: Colors.black, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF77777E),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 17, color: Colors.black54),
        ],
      ),
    ),
  );
}

class _LibraryStat extends StatelessWidget {
  const _LibraryStat({required this.value, required this.label});

  final int value;
  final String label;

  /// 필요한 변수는 자료 개수와 종류 이름이다.
  /// 작동 원리는 HTML 책가방 히어로의 3열 통계 셀로 교재·시험지·북마크 수를 표시하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: Color(0xFFE0E0E3))),
    ),
    child: Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.black45, fontSize: 10),
        ),
      ],
    ),
  );
}

class _LibraryLinkRow extends StatelessWidget {
  const _LibraryLinkRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final int count;
  final VoidCallback onTap;

  /// 필요한 변수는 자료 아이콘·이름·요약·개수·열기 콜백이다.
  /// 작동 원리는 HTML MY LIBRARY의 구분선 행을 만들고 선택한 실제 자료 목록으로 연결하는 것이다.
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0E3))),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDCDCE0)),
            ),
            child: Icon(icon, color: Colors.black, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(color: Colors.black45, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: Colors.black45),
        ],
      ),
    ),
  );
}

enum _ArchiveType { exam, textbook }

/// 공통 빈 상태 위젯
class _EmptyState extends StatelessWidget {
  final String label;
  const _EmptyState({this.label = '아직 없어요!'});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(color: Colors.black38, fontSize: 13),
        ),
      ),
    );
  }
}
