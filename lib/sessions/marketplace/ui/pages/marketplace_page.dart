import 'dart:async';

import 'package:flutter/material.dart';
import 'public_textbooks_page.dart';

import 'package:s11/sessions/course/session/course_learning_page.dart';
import 'package:s11/sessions/exam_paper/session/exam_paper_page.dart';
import 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';
import 'package:s11/shared/data/models/content_block.dart';
import 'package:s11/shared/data/models/course.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/course_service.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';

typedef MarketplacePurchaseHandler = Future<void> Function(String listingId);
typedef MarketplaceOpenHandler = void Function(String listingId);
typedef MarketplaceCoursePreviewLoader =
    Future<Course> Function(String courseId);

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({
    super.key,
    this.initialData,
    this.purchaseHandler,
    this.openHandler,
    this.coursePreviewLoader,
    this.initialScene,
  });

  final List<Map<String, dynamic>>? initialData;
  final MarketplacePurchaseHandler? purchaseHandler;
  final MarketplaceOpenHandler? openHandler;
  final MarketplaceCoursePreviewLoader? coursePreviewLoader;
  final String? initialScene;

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _queryFocusNode = FocusNode();
  List<_MarketItem> _items = const <_MarketItem>[];
  String _filter = '전체';
  String _subjectFilter = '전체';
  String _difficultyFilter = '전체';
  String _priceFilter = '전체';
  String? _recommendationGradeFilter;
  int? _nextOffset;
  bool _loading = false;
  String? _error;
  bool _initialPreviewOpened = false;

  /// 담은 자료의 실제 유형에 맞는 학습 화면을 즉시 연다.
  Future<void> _openPurchasedItem(
    _MarketItem item, {
    ApiSessionScope? expectedScope,
  }) async {
    if (expectedScope != null &&
        !ApiClient.instance.isCurrentSessionScope(expectedScope)) {
      return;
    }
    final handler = widget.openHandler;
    if (handler != null) {
      handler(item.id);
      return;
    }
    try {
      if (item.type == _MarketItemType.exam) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExamPaperPage(
              examId: item.assetId.isNotEmpty ? item.assetId : item.id,
              expectedQuestionCount: item.itemCount,
              marketplaceListingId: item.id,
            ),
          ),
        );
        return;
      }
      if (item.type == _MarketItemType.course) {
        final course = await CourseService.fetchCourse(
          item.assetId.isNotEmpty ? item.assetId : item.id,
        );
        if (expectedScope != null) {
          ApiClient.instance.assertSessionScope(expectedScope);
        }
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CourseLearningPage(course: course)),
        );
        return;
      }
      final quests = await ApiClient.instance
          .loadMarketplaceProblemSetQuestions(item.id);
      if (expectedScope != null) {
        ApiClient.instance.assertSessionScope(expectedScope);
      }
      if (!mounted) return;
      if (quests.isEmpty) throw StateError('empty_marketplace_problem_set');
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BuildpageWidget(
            config: ProblemSolveConfig(
              questionCount: quests.length,
              quests: quests,
              ratingEnabled: false,
              onComplete:
                  ({
                    required correctCount,
                    required totalCount,
                    required passed,
                    elapsedSeconds,
                  }) => ApiClient.instance.updateMarketplaceProgress(
                    listingId: item.id,
                    progressIndex: totalCount,
                    completed: passed,
                  ),
              onProblemGraded:
                  ({
                    required itemIndex,
                    required quest,
                    required isCorrect,
                    required stepCorrectness,
                    selectedIndex,
                    elapsedSeconds,
                  }) => ApiClient.instance.updateMarketplaceProgress(
                    listingId: item.id,
                    progressIndex: itemIndex,
                    completed: false,
                  ),
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('학습 자료를 열지 못했습니다. 다시 시도해주세요.')),
      );
    }
  }

  void _showPurchaseSuccess(_MarketItem item, ApiSessionScope? scope) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('내 학습 자료에 담았습니다.'),
        action: SnackBarAction(
          label: '바로가기',
          onPressed: () {
            if (scope != null &&
                !ApiClient.instance.isCurrentSessionScope(scope)) {
              return;
            }
            unawaited(_openPurchasedItem(item, expectedScope: scope));
          },
        ),
      ),
    );
  }

  static const _corners = <_MarketplaceCorner>[
    _MarketplaceCorner(
      title: '시험지',
      description: '완성된 시험지를 찾아 학습에 담아보세요.',
      icon: Icons.assignment_outlined,
      filter: '시험지',
    ),
    _MarketplaceCorner(
      title: '문제집',
      description: '주제와 난이도에 맞는 문제집을 둘러보세요.',
      icon: Icons.inventory_2_outlined,
      filter: '문제집',
    ),
    _MarketplaceCorner(
      title: '코스',
      description: '학습 순서가 구성된 코스를 둘러보세요.',
      icon: Icons.route_outlined,
      filter: '코스',
    ),
  ];

  /// 필요한 변수는 선택적 미리보기 데이터다.
  /// 작동 원리는 고정 데이터가 있으면 네트워크를 건너뛰고, 실제 화면은 사용자 학년과 첫 페이지 자료만 조회하는 것이다.
  @override
  void initState() {
    super.initState();
    if (widget.initialScene == 'market-filter') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openMarketFilter());
      });
    }
    final initialData = widget.initialData;
    if (initialData != null) {
      _items = initialData.map(_MarketItem.fromMap).toList(growable: false);
      _scheduleInitialPreview();
    } else {
      unawaited(_loadInitialResults());
    }
  }

  /// 실제 목록이 준비된 뒤에만 미리보기 장면을 연다.
  void _scheduleInitialPreview() {
    if (widget.initialScene != 'market-preview' || _initialPreviewOpened) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialPreviewOpened || _items.isEmpty) return;
      _initialPreviewOpened = true;
      unawaited(_openItem(_items.first));
    });
  }

  /// 필요한 변수는 검색 컨트롤러다.
  /// 작동 원리는 화면 종료 시 입력 리소스를 해제하는 것이다.
  @override
  void dispose() {
    _queryController.dispose();
    _queryFocusNode.dispose();
    super.dispose();
  }

  /// 필요한 변수는 사용자 프로필과 마켓 검색 API다.
  /// 작동 원리는 가입 정보의 과정·학년을 추천 조건으로 사용해 특정 학년 문구를 화면에 고정하지 않는 것이다.
  Future<void> _loadInitialResults() async {
    // 목록은 프로필 추천 조건과 독립적으로 먼저 요청해 느린 /auth/me가 마켓을 막지 않게 한다.
    final initialSearch = _search();
    try {
      final profile = await ApiClient.instance.getMyProfile();
      final grade = profile.grade?.trim() ?? '';
      // 관리자·비표준 프로필 값은 학년 조건으로 보내면 전체 마켓이 비게 된다.
      _recommendationGradeFilter = _isLearnerGrade(grade) ? grade : null;
      await initialSearch;
      if (mounted && _recommendationGradeFilter != null) {
        // 첫 목록을 먼저 보여준 뒤 학년 추천 조건으로 한 번만 보정한다.
        await _search();
      }
      return;
    } catch (_) {
      // 프로필 조회 실패 시에도 검색 기능은 사용 가능해야 한다.
    }
    await initialSearch;
  }

  /// 필요한 변수는 프로필에서 받은 학년 문자열이다.
  /// 작동 원리는 실제 학습자 학년 형식만 추천 SQL 조건으로 허용하고 admin·빈 값은 전체 자료를 보여 주는 것이다.
  bool _isLearnerGrade(String value) {
    return RegExp(r'^(초|중|고)\s?[1-3](?:-[1-3])?$').hasMatch(value);
  }

  /// 필요한 변수는 검색어·서버 필터·페이지 위치다.
  /// 작동 원리는 필터를 서버에 전달하고 첫 페이지 또는 다음 페이지만 합쳐 전체 목록 전송과 렌더링을 막는 것이다.
  Future<void> _search({bool append = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final query = _queryController.text.trim();
    try {
      final page = await ApiClient.instance.listMarketplaceListings(
        query: query.isEmpty ? null : query,
        kind: _apiKind,
        gradeBand: _recommendationGradeFilter,
        subject: _subjectFilter == '전체' ? null : _subjectFilter,
        difficulty: _difficultyFilter == '전체' ? null : _difficultyFilter,
        price: switch (_priceFilter) {
          '무료' => 'free',
          '유료' => 'paid',
          _ => null,
        },
        offset: append ? (_nextOffset ?? 0) : 0,
      );
      final items = page.items.map(_MarketItem.fromMap).toList(growable: false);
      if (!mounted) return;
      setState(() {
        _items = append ? [..._items, ...items] : items;
        _nextOffset = page.nextOffset;
      });
      if (!append) _scheduleInitialPreview();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error is ApiException && error.statusCode == 401
          ? '로그인이 필요합니다. 다시 로그인해 주세요.'
          : '마켓 자료를 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 선택한 화면 표시명을 기존 자료실 API kind로 변환한다.
  String? get _apiKind => switch (_filter) {
    '시험지' => 'exam',
    '문제집' => 'problem_set',
    '코스' => 'course',
    _ => null,
  };

  /// 필요한 변수는 위젯에 주입된 미리보기 자료다.
  /// 작동 원리는 네트워크를 쓰지 않는 미리보기·테스트만 로컬 필터를 허용하고 실제 마켓은 항상 서버 필터를 사용하게 하는 것이다.
  List<_MarketItem> get _initialFilteredItems {
    return _items
        .where(
          (item) =>
              (_filter == '전체' || item.typeLabel == _filter) &&
              (_subjectFilter == '전체' || item.subject == _subjectFilter) &&
              (_difficultyFilter == '전체' ||
                  item.difficulty == _difficultyFilter) &&
              (_priceFilter == '전체' ||
                  (_priceFilter == '무료' && item.pricePoints == 0) ||
                  (_priceFilter == '유료' && item.pricePoints > 0)),
        )
        .toList(growable: false);
  }

  /// 필요한 변수는 현재 유형·과정·가격 필터다.
  /// 작동 원리는 Atlas의 상세 필터 시트에서 조건을 임시 선택한 뒤 적용 시 한 번만 목록 상태를 갱신하는 것이다.
  Future<void> _openMarketFilter() async {
    final result =
        await showModalBottomSheet<
          ({String type, String subject, String difficulty, String price})
        >(
          context: context,
          showDragHandle: false,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: const Color(0x940C0E12),
          constraints: const BoxConstraints(maxWidth: 620),
          shape: const RoundedRectangleBorder(),
          builder: (_) => _MarketFilterSheet(
            type: _filter,
            subject: _subjectFilter,
            difficulty: _difficultyFilter,
            price: _priceFilter,
          ),
        );
    if (!mounted || result == null) return;
    setState(() {
      _filter = result.type;
      _subjectFilter = result.subject;
      _difficultyFilter = result.difficulty;
      _priceFilter = result.price;
    });
    if (widget.initialData == null) unawaited(_search());
  }

  /// 필요한 변수는 검색 패널이 전달한 자료 유형이다.
  /// 작동 원리는 유형 탭은 즉시 전환하고 상세 조건은 별도 필터 시트에서만 적용하는 것이다.
  void _handleFilterChanged(String value) {
    setState(() => _filter = value);
    if (widget.initialData == null) unawaited(_search());
  }

  /// 필요한 변수는 선택한 마켓 항목의 메타데이터다.
  /// 작동 원리는 문제 ID가 있는 자료만 문제 원문을 조회하고, 코스 카탈로그는 서버가 제공한 단계 정보로 즉시 미리보기를 구성하는 것이다.
  Future<void> _openItem(_MarketItem item) async {
    final previewIds = item.type == _MarketItemType.course
        ? const <String>[]
        : item.problemIds.take(3).toList(growable: false);
    final problems = <Map<String, dynamic>>[];
    var courseUnits = const <CourseUnit>[];
    var coursePreviewFailed = false;
    if (item.type == _MarketItemType.course) {
      try {
        final loadCourse =
            widget.coursePreviewLoader ?? CourseService.fetchCourse;
        courseUnits = (await loadCourse(
          item.assetId.isNotEmpty ? item.assetId : item.id,
        )).units;
      } catch (_) {
        coursePreviewFailed = true;
      }
    }
    if (previewIds.isNotEmpty) {
      final results = await Future.wait(
        previewIds.map((id) async {
          try {
            return await ApiClient.instance.searchQuests(
              questId: id,
              pageSize: 1,
            );
          } catch (_) {
            return const <Map<String, dynamic>>[];
          }
        }),
      );
      for (final result in results) {
        if (result.isNotEmpty) problems.add(result.first);
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _MarketplacePreviewPage(
          item: item,
          problems: problems,
          courseUnits: courseUnits,
          coursePreviewFailed: coursePreviewFailed,
          onPurchase: item.owned ? null : () => _purchaseItem(item),
          onOpenSample:
              (item.type == _MarketItemType.course
                  ? courseUnits.isEmpty
                  : problems.isEmpty)
              ? null
              : () => unawaited(_openSample(item, problems)),
        ),
      ),
    );
  }

  /// 시험지·문제집은 실제 첫 문항만 열고 구매 진도·OVR 콜백을 연결하지 않는다.
  /// 코스는 기존 학습 화면으로 이동하며, 이후 실제 학습의 저장 계약은 유지한다.
  Future<void> _openSample(
    _MarketItem item,
    List<Map<String, dynamic>> problems,
  ) async {
    if (item.type == _MarketItemType.course) {
      await _openPurchasedItem(item);
      return;
    }
    if (problems.isEmpty || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BuildpageWidget(
          config: ProblemSolveConfig(
            questionCount: 1,
            quests: [problems.first],
            ratingEnabled: false,
          ),
        ),
      ),
    );
  }

  /// 상세 화면에서 요청한 실제 구매를 서버에 전달하고 목록 상태도 갱신한다.
  Future<bool> _purchaseItem(_MarketItem item) async {
    final api = ApiClient.instance;
    ApiSessionScope? scope;
    try {
      final purchase = widget.purchaseHandler;
      if (purchase != null) {
        await purchase(item.id);
      } else {
        scope = await api.requireSessionScope();
        await api.purchaseMarketplaceListing(item.id, expectedScope: scope);
      }
      if (scope != null) api.assertSessionScope(scope);
      if (!mounted) return false;
      setState(() {
        _items = _items
            .map(
              (current) =>
                  current.id == item.id ? current.copyWithOwned() : current,
            )
            .toList(growable: false);
      });
      _showPurchaseSuccess(item.copyWithOwned(), scope);
      return true;
    } on ApiException catch (error) {
      if (scope != null && !api.isCurrentSessionScope(scope)) return false;
      if (!mounted) return false;
      final message = error.message == 'insufficient_coins'
          ? '코인이 부족합니다.'
          : '자료를 추가하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return false;
    } catch (_) {
      if (scope != null && !api.isCurrentSessionScope(scope)) return false;
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('자료를 추가하지 못했습니다.')));
      return false;
    }
  }

  /// 필요한 변수는 화면 크기·검색·필터·추천 결과 상태다.
  /// 작동 원리는 세로형 휴대폰에는 검색 중심 상품 그리드를, 태블릿·PC에는 기존 정보형 마켓을 각각 렌더링하는 것이다.
  @override
  Widget build(BuildContext context) {
    final items = _initialFilteredItems;
    final size = MediaQuery.sizeOf(context);
    final mobile = isStudentDensityMobile(context);
    return StudentHtmlShell(
      title: '자료실',
      activeRoute: '/marketplace',
      showContextAside: false,
      reserveContextTrack: true,
      railWidth: size.width > 1040 ? 84 : 72,
      mobileBackButton: true,
      onMenu: () =>
          Navigator.of(context).pushReplacementNamed('/student/dashboard'),
      onSearch: () => showStudentQuickSearch(context),
      onNotifications: () => showStudentNotifications(context),
      child: ColoredBox(
        color: Colors.white,
        child: RefreshIndicator(
          onRefresh: _search,
          child: ListView(
            key: ValueKey(
              mobile ? 'market-mobile-scroll' : 'market-wide-scroll',
            ),
            padding: EdgeInsets.zero,
            children: [
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('기본 제공 교재'),
                subtitle: const Text('공개 교재 · 0코인으로 책가방에 담기'),
                onTap: () => Navigator.of(context).push<void>(MaterialPageRoute(
                  builder: (_) => const PublicTextbooksPage(),
                )),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Padding(
                    padding: mobile
                        ? EdgeInsets.zero
                        : EdgeInsets.all((size.width * .03).clamp(20, 36)),
                    child: mobile
                        ? _MobileMarketplaceBody(
                            controller: _queryController,
                            focusNode: _queryFocusNode,
                            corners: _corners,
                            selected: _filter,
                            items: items,
                            loading: _loading,
                            error: _error,
                            hasNextPage: _nextOffset != null,
                            onSelected: _handleFilterChanged,
                            onOpenFilter: _openMarketFilter,
                            onSearch: _search,
                            onOpen: _openItem,
                            onLoadMore: () => unawaited(_search(append: true)),
                          )
                        : _WideMarketplaceBody(
                            controller: _queryController,
                            focusNode: _queryFocusNode,
                            corners: _corners,
                            selected: _filter,
                            items: items,
                            loading: _loading,
                            error: _error,
                            hasNextPage: _nextOffset != null,
                            onSelected: _handleFilterChanged,
                            onOpenFilter: _openMarketFilter,
                            onSearch: _search,
                            onOpen: _openItem,
                            onLoadMore: () => unawaited(_search(append: true)),
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
}

class _WideMarketplaceBody extends StatelessWidget {
  const _WideMarketplaceBody({
    required this.controller,
    required this.focusNode,
    required this.corners,
    required this.selected,
    required this.items,
    required this.loading,
    required this.error,
    required this.hasNextPage,
    required this.onSelected,
    required this.onOpenFilter,
    required this.onSearch,
    required this.onOpen,
    required this.onLoadMore,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<_MarketplaceCorner> corners;
  final String selected;
  final List<_MarketItem> items;
  final bool loading;
  final String? error;
  final bool hasNextPage;
  final ValueChanged<String> onSelected;
  final VoidCallback onOpenFilter;
  final VoidCallback onSearch;
  final ValueChanged<_MarketItem> onOpen;
  final VoidCallback onLoadMore;

  /// 필요한 변수는 태블릿·PC용 자료실 상태다.
  /// 작동 원리는 Atlas의 검색·유형 탭·자료 카드 구조를 넓은 화면에도 같은 정보 순서로 적용하는 것이다.
  @override
  Widget build(BuildContext context) {
    return _HtmlDesktopMarketplaceBody(
      controller: controller,
      focusNode: focusNode,
      corners: corners,
      selected: selected,
      items: items,
      loading: loading,
      error: error,
      hasNextPage: hasNextPage,
      onSelected: onSelected,
      onOpenFilter: onOpenFilter,
      onSearch: onSearch,
      onOpen: onOpen,
      onLoadMore: onLoadMore,
    );
  }
}

class _HtmlDesktopMarketplaceBody extends StatelessWidget {
  const _HtmlDesktopMarketplaceBody({
    required this.controller,
    required this.focusNode,
    required this.corners,
    required this.selected,
    required this.items,
    required this.loading,
    required this.error,
    required this.hasNextPage,
    required this.onSelected,
    required this.onOpenFilter,
    required this.onSearch,
    required this.onOpen,
    required this.onLoadMore,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<_MarketplaceCorner> corners;
  final String selected;
  final List<_MarketItem> items;
  final bool loading;
  final String? error;
  final bool hasNextPage;
  final ValueChanged<String> onSelected;
  final VoidCallback onOpenFilter;
  final VoidCallback onSearch;
  final ValueChanged<_MarketItem> onOpen;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = (width * 0.04).clamp(20.0, 52.0);
    final categories = [
      const _MarketplaceCorner(
        title: '전체',
        description: '',
        icon: Icons.grid_view_rounded,
        filter: '전체',
      ),
      for (final type in const ['코스', '시험지', '문제집'])
        corners.firstWhere((corner) => corner.filter == type),
    ];
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x1A09090B))),
          ),
          padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 18),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      key: const ValueKey('market-desktop-search-shell'),
                      constraints: const BoxConstraints(minHeight: 54),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 19),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              key: const ValueKey('market-search-field'),
                              controller: controller,
                              focusNode: focusNode,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => onSearch(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                              decoration: const InputDecoration(
                                hintText: '자료명·과목·태그 검색',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _HtmlMarketFilterButton(
                    buttonKey: const ValueKey('market-desktop-filter'),
                    width: 96,
                    fontSize: 12,
                    onPressed: onOpenFilter,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                key: const ValueKey('market-desktop-filters'),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x1A09090B)),
                ),
                child: Row(
                  children: [
                    for (var index = 0; index < categories.length; index++) ...[
                      Expanded(
                        child: _MarketplaceTypeTab(
                          category: categories[index],
                          selected: selected == categories[index].filter,
                          square: true,
                          onTap: () => onSelected(categories[index].filter),
                        ),
                      ),
                      if (index != categories.length - 1)
                        const SizedBox(
                          width: 1,
                          height: 48,
                          child: ColoredBox(color: Color(0x1A09090B)),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 48),
          child: Column(
            children: [
              if (loading && items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 64),
                  child: CircularProgressIndicator(color: Colors.black),
                )
              else if (items.isEmpty)
                _MarketplaceStateMessage(
                  message: error ?? '찾는 자료가 없습니다.',
                  action: error == null ? '전체 보기' : '다시 불러오기',
                  onPressed: error == null ? () => onSelected('전체') : onSearch,
                )
              else ...[
                if (error != null)
                  _MarketplaceErrorNotice(message: error!, onRetry: onSearch),
                _MarketplaceResourceResults(
                  rootKey: const ValueKey('market-html-desktop-results'),
                  items: items,
                  onOpen: onOpen,
                ),
              ],
              if (hasNextPage)
                TextButton(
                  onPressed: loading ? null : onLoadMore,
                  child: Text(loading ? '불러오는 중' : '더 보기'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileMarketplaceBody extends StatelessWidget {
  const _MobileMarketplaceBody({
    required this.controller,
    required this.focusNode,
    required this.corners,
    required this.selected,
    required this.items,
    required this.loading,
    required this.error,
    required this.hasNextPage,
    required this.onSelected,
    required this.onOpenFilter,
    required this.onSearch,
    required this.onOpen,
    required this.onLoadMore,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<_MarketplaceCorner> corners;
  final String selected;
  final List<_MarketItem> items;
  final bool loading;
  final String? error;
  final bool hasNextPage;
  final ValueChanged<String> onSelected;
  final VoidCallback onOpenFilter;
  final VoidCallback onSearch;
  final ValueChanged<_MarketItem> onOpen;
  final VoidCallback onLoadMore;

  /// 필요한 변수는 휴대폰 검색·필터·상품 결과다.
  /// 작동 원리는 Atlas의 검색/상세 필터 첫 줄과 자료 유형 탭 둘째 줄을 한 손 탐색 순서로 제공하는 것이다.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(10),
    child: Column(
      key: const ValueKey('market-mobile-body'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x1A09090B))),
          ),
          child: _SearchPanel(
            controller: controller,
            focusNode: focusNode,
            corners: corners,
            loading: loading,
            filter: selected,
            onFilterChanged: onSelected,
            onOpenFilter: onOpenFilter,
            onSearch: onSearch,
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 48),
          child: loading && items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 64),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.black),
                  ),
                )
              : items.isEmpty
              ? _MarketplaceStateMessage(
                  message: error ?? '조건에 맞는 자료가 없습니다.',
                  action: error == null ? '전체 보기' : '다시 불러오기',
                  onPressed: error == null ? () => onSelected('전체') : onSearch,
                )
              : Column(
                  children: [
                    if (error != null)
                      _MarketplaceErrorNotice(
                        message: error!,
                        onRetry: onSearch,
                      ),
                    _MarketplaceResourceResults(
                      rootKey: const ValueKey('market-mobile-grid'),
                      items: items,
                      onOpen: onOpen,
                    ),
                  ],
                ),
        ),
        if (hasNextPage) ...[
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                foregroundColor: Colors.black,
                side: const BorderSide(color: Color(0xFFD4D4D8)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: loading ? null : onLoadMore,
              child: Text(
                loading ? '불러오는 중' : '더 보기',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _MarketplaceResourceResults extends StatelessWidget {
  const _MarketplaceResourceResults({
    required this.rootKey,
    required this.items,
    required this.onOpen,
  });

  final Key rootKey;
  final List<_MarketItem> items;
  final ValueChanged<_MarketItem> onOpen;

  /// 필요한 변수는 실제 자료 목록·화면 폭·열기 동작이다.
  /// 작동 원리는 HTML의 번호형 자료 커버를 휴대폰 2열, 넓은 화면 3열로 배치하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    key: rootKey,
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: Color(0x1A09090B))),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        // HTML 자료실은 넓은 화면에서 3열, 모바일에서 2열 번호형 카드다.
        final columns = MediaQuery.sizeOf(context).width > 720 ? 3 : 2;
        final width = constraints.maxWidth / columns;
        return Wrap(
          spacing: 0,
          runSpacing: 0,
          children: [
            for (var index = 0; index < items.length; index++)
              Container(
                key: ValueKey('market-cell-${items[index].id}'),
                width: width,
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Color(0x1A09090B)),
                    bottom: BorderSide(color: Color(0x1A09090B)),
                  ),
                ),
                child: _HtmlMarketplaceGridCard(
                  item: items[index],
                  index: index,
                  onOpen: onOpen,
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _HtmlMarketplaceGridCard extends StatelessWidget {
  const _HtmlMarketplaceGridCard({
    required this.item,
    required this.index,
    required this.onOpen,
  });

  final _MarketItem item;
  final int index;
  final ValueChanged<_MarketItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 720;
    final textScaler = mobile
        ? studentReferenceCardTextScaler(context)
        : MediaQuery.textScalerOf(context);
    final scaledLabelGrowth = [8.0, 13.0, 9.0, 10.0].fold<double>(0, (
      sum,
      font,
    ) {
      final baseline = mobile && font < 12 ? 12.0 : font;
      return sum +
          (textScaler.scale(font) - baseline).clamp(0, double.infinity) * 1.2;
    });
    final scaledCoverNumberGrowth =
        (textScaler.scale(32) - 32).clamp(0, double.infinity) * 4;

    final action = item.owned
        ? (item.completed ? '완료' : '열기')
        : (item.pricePoints == 0 ? '무료' : '${item.pricePoints}P');

    Widget buildCover() => SizedBox(
      key: ValueKey('market-cover-${item.id}'),
      width: double.infinity,
      child: ColoredBox(
        color: const Color(0xFFF3F3F5),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: ColoredBox(
                  color: Colors.white,
                  child: Container(
                    key: ValueKey('market-cover-tag-${item.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: const BoxDecoration(color: Colors.white),
                    child: Text(
                      item.typeLabel,
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: Transform.translate(
                  offset: Offset(0, mobile ? 0 : -1),
                  child: Transform.scale(
                    scaleX: .7481,
                    alignment: Alignment.centerRight,
                    child: Text(
                      key: ValueKey('market-number-${item.id}'),
                      (index + 1).toString().padLeft(2, '0'),
                      style: const TextStyle(
                        fontSize: 32,
                        height: 1.16,
                        letterSpacing: -1.92,
                        fontWeight: FontWeight.w700,
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

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: () => onOpen(item),
          child: SizedBox(
            height:
                (mobile ? 189.0 : 209.0) +
                scaledLabelGrowth +
                scaledCoverNumberGrowth,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mobile)
                    SizedBox(
                      height: 86.0 + scaledCoverNumberGrowth,
                      child: buildCover(),
                    )
                  else
                    Expanded(child: buildCover()),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      key: ValueKey('market-title-${item.id}'),
                      item.mobileTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(height: mobile ? 5 : 9),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      item.compactSubtitle.isEmpty
                          ? item.typeLabel
                          : item.compactSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        height: 1,
                        color: const Color(0xFF71717A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: mobile ? 12 : 15),
                  Row(
                    children: [
                      Text(
                        action,
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward, size: 14),
                    ],
                  ),
                  if (mobile) const SizedBox(height: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketplaceStateMessage extends StatelessWidget {
  const _MarketplaceStateMessage({
    required this.message,
    required this.action,
    required this.onPressed,
  });

  final String message;
  final String action;
  final VoidCallback onPressed;

  /// 필요한 변수는 결과 안내 문구와 재시도·초기화 동작이다.
  /// 작동 원리는 HTML 자료실의 140px 빈 결과 행과 테두리·보조 글자 규칙을 유지하면서 복구 링크를 제공하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('market-empty-state'),
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 140),
    decoration: const BoxDecoration(
      border: Border(
        top: BorderSide(color: Color(0x1A09090B)),
        left: BorderSide(color: Color(0x1A09090B)),
      ),
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF71717A),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextButton(
            key: const ValueKey('market-empty-action'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF71717A),
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontFamily: 'Noto Sans KR',
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            onPressed: onPressed,
            child: Text(action),
          ),
        ],
      ),
    ),
  );
}

class _MarketplaceErrorNotice extends StatelessWidget {
  const _MarketplaceErrorNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFFB34A4A)),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('다시 불러오기')),
      ],
    ),
  );
}

class _MarketplaceCorner {
  const _MarketplaceCorner({
    required this.title,
    required this.description,
    required this.icon,
    required this.filter,
  });

  final String title;
  final String description;
  final IconData icon;
  final String filter;
}

class _HtmlMarketFilterButton extends StatelessWidget {
  const _HtmlMarketFilterButton({
    required this.buttonKey,
    required this.width,
    required this.fontSize,
    required this.onPressed,
  });

  final Key buttonKey;
  final double width;
  final double fontSize;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 54,
    child: OutlinedButton(
      key: buttonKey,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: StudentDensityTokens.muted,
        side: BorderSide.none,
        padding: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '필터',
            style: TextStyle(
              color: StudentDensityTokens.muted,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 7),
          const StudentHtmlGlyph(
            key: ValueKey('market-filter-glyph'),
            icon: StudentHtmlIcon.filter,
            size: 16,
            color: StudentDensityTokens.muted,
            scaleForMobile: false,
          ),
        ],
      ),
    ),
  );
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.focusNode,
    required this.corners,
    required this.loading,
    required this.filter,
    required this.onFilterChanged,
    required this.onOpenFilter,
    required this.onSearch,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<_MarketplaceCorner> corners;
  final bool loading;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onOpenFilter;
  final VoidCallback onSearch;

  /// 필요한 변수는 검색어·필터·로딩 상태다.
  /// 작동 원리는 Atlas처럼 검색과 상세 필터를 첫 줄에, 자료 유형을 둘째 줄에 두고 실제 서버 검색은 명시적으로만 요청하는 것이다.
  @override
  Widget build(BuildContext context) {
    final categories = <_MarketplaceCorner>[
      const _MarketplaceCorner(
        title: '전체',
        description: '',
        icon: Icons.grid_view_rounded,
        filter: '전체',
      ),
      for (final type in const ['코스', '시험지', '문제집'])
        corners.firstWhere((corner) => corner.filter == type),
    ];
    return Column(
      key: const ValueKey('market-mobile-search-panel'),
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 54,
                child: TextField(
                  key: const ValueKey('market-search-field'),
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSearch(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(
                    hintText: '자료명·과목·태그 검색',
                    hintStyle: TextStyle(
                      color: Color(0xFF71717A),
                      fontWeight: FontWeight.w800,
                    ),
                    prefixIcon: Icon(Icons.search, size: 19),
                    prefixIconConstraints: BoxConstraints(minWidth: 48),
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _HtmlMarketFilterButton(
              buttonKey: const ValueKey('market-mobile-filter'),
              width: 84,
              fontSize: 10,
              onPressed: loading ? null : onOpenFilter,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          key: const ValueKey('market-mobile-filters'),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x1A09090B)),
          ),
          child: Row(
            children: [
              for (var index = 0; index < categories.length; index++) ...[
                Expanded(
                  child: _MarketplaceTypeTab(
                    category: categories[index],
                    selected: filter == categories[index].filter,
                    square: true,
                    onTap: () => onFilterChanged(categories[index].filter),
                  ),
                ),
                if (index != categories.length - 1)
                  const SizedBox(
                    width: 1,
                    height: 48,
                    child: ColoredBox(color: Color(0x1A09090B)),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MarketplaceTypeTab extends StatelessWidget {
  const _MarketplaceTypeTab({
    required this.category,
    required this.selected,
    required this.onTap,
    this.square = false,
  });

  final _MarketplaceCorner category;
  final bool selected;
  final VoidCallback onTap;
  final bool square;

  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey('market-type-${category.filter}'),
    color: selected ? Colors.black : StudentDensityTokens.surface,
    borderRadius: BorderRadius.circular(square ? 0 : 9),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(square ? 0 : 9),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: square ? 48 : 42),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: square ? 4 : 13),
          child: Center(
            child: Text(
              category.title,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black,
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

class _MarketFilterSheet extends StatefulWidget {
  const _MarketFilterSheet({
    required this.type,
    required this.subject,
    required this.difficulty,
    required this.price,
  });

  final String type;
  final String subject;
  final String difficulty;
  final String price;

  @override
  State<_MarketFilterSheet> createState() => _MarketFilterSheetState();
}

class _MarketFilterSheetState extends State<_MarketFilterSheet> {
  late String _type = widget.type;
  late String _subject = widget.subject;
  late String _difficulty = widget.difficulty;
  late String _price = widget.price;

  /// 필요한 변수는 유형·과정·가격 임시 선택값이다.
  /// 작동 원리는 Atlas 상세 필터처럼 세 조건을 독립 칩으로 고르고 적용 시 부모 목록에 한 번 반환하는 것이다.
  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= 720;
    final maxHeight = MediaQuery.sizeOf(context).height * (mobile ? .91 : .88);
    final footer = Container(
      padding: EdgeInsets.fromLTRB(
        mobile ? 14 : 20,
        mobile ? 12 : 16,
        mobile ? 14 : 20,
        mobile ? 14 : 20,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x1A09090B))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 65,
            child: SizedBox(
              height: 52,
              child: TextButton(
                key: const ValueKey('market-filter-clear-all'),
                onPressed: () => setState(() {
                  _type = '전체';
                  _subject = '전체';
                  _difficulty = '전체';
                  _price = '전체';
                }),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.zero,
                  shape: const RoundedRectangleBorder(),
                  textStyle: const TextStyle(
                    fontFamily: 'Noto Sans KR',
                    fontWeight: FontWeight.w900,
                  ),
                ),
                child: const Text(
                  '초기화',
                  style: TextStyle(fontFamily: 'Noto Sans KR'),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 135,
            child: SizedBox(
              height: 52,
              child: FilledButton(
                key: const ValueKey('market-filter-apply'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(),
                ),
                onPressed: () => Navigator.of(context).pop((
                  type: _type,
                  subject: _subject,
                  difficulty: _difficulty,
                  price: _price,
                )),
                child: const Text(
                  '필터 적용',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 620, maxHeight: maxHeight),
          child: Container(
            key: const ValueKey('market-filter-sheet'),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: const BorderSide(color: Color(0xFF09090B)),
                left: mobile
                    ? BorderSide.none
                    : const BorderSide(color: Color(0xFF09090B)),
                right: mobile
                    ? BorderSide.none
                    : const BorderSide(color: Color(0xFF09090B)),
              ),
            ),
            child: SizedBox(
              height: mobile ? maxHeight : null,
              child: Column(
                mainAxisSize: mobile ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      key: const ValueKey('market-filter-scroll'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (mobile)
                            Padding(
                              padding: const EdgeInsets.only(top: 7, bottom: 1),
                              child: Container(
                                width: 42,
                                height: 4,
                                color: const Color(0x1A09090B),
                              ),
                            ),
                          Container(
                            height: mobile ? 58 : 64,
                            padding: EdgeInsets.only(
                              left: mobile ? 16 : 20,
                              right: 14,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0x1A09090B)),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    '상세 필터',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: IconButton(
                                    key: const ValueKey('market-filter-close'),
                                    tooltip: '닫기',
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    style: IconButton.styleFrom(
                                      shape: const RoundedRectangleBorder(),
                                      side: const BorderSide(
                                        color: Color(0x1A09090B),
                                      ),
                                    ),
                                    icon: const Icon(Icons.close, size: 19),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              mobile ? 14 : 19,
                              mobile ? 0 : 2,
                              mobile ? 14 : 19,
                              mobile ? 0 : 2,
                            ),
                            child: Column(
                              children: [
                                _FilterGroup(
                                  label: '자료 유형',
                                  values: const ['전체', '코스', '시험지', '문제집'],
                                  selected: _type,
                                  onSelected: (value) =>
                                      setState(() => _type = value),
                                ),
                                _FilterGroup(
                                  label: '과목',
                                  values: const [
                                    '전체',
                                    '미적분',
                                    '수학 II',
                                    '확률과 통계',
                                  ],
                                  selected: _subject,
                                  onSelected: (value) =>
                                      setState(() => _subject = value),
                                ),
                                _FilterGroup(
                                  label: '난이도',
                                  values: const ['전체', 'B1', 'B2'],
                                  selected: _difficulty,
                                  onSelected: (value) =>
                                      setState(() => _difficulty = value),
                                ),
                                _FilterGroup(
                                  label: '가격',
                                  values: const ['전체', '무료', '유료'],
                                  selected: _price,
                                  onSelected: (value) =>
                                      setState(() => _price = value),
                                ),
                              ],
                            ),
                          ),
                          if (!mobile) footer,
                        ],
                      ),
                    ),
                  ),
                  if (mobile) footer,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({
    required this.label,
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  /// 필요한 변수는 그룹명·선택지·현재 선택·변경 콜백이다.
  /// 작동 원리는 한 필터 그룹의 단일 선택 상태를 흑백 ChoiceChip으로 표시한다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0x1A09090B))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 26),
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 560 ? 2 : 4;
            final width = (constraints.maxWidth - 2) / columns;
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0x1A09090B)),
              ),
              child: Wrap(
                children: [
                  for (var index = 0; index < values.length; index++)
                    SizedBox(
                      width: width,
                      child: _MarketFilterOption(
                        optionKey: ValueKey(
                          'market-filter-option-${values[index]}-$label',
                        ),
                        label: values[index],
                        selected: selected == values[index],
                        showRightBorder:
                            index % columns != columns - 1 &&
                            index != values.length - 1,
                        showTopBorder: index >= columns,
                        onTap: () => onSelected(values[index]),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    ),
  );
}

class _MarketFilterOption extends StatelessWidget {
  const _MarketFilterOption({
    required this.optionKey,
    required this.label,
    required this.selected,
    required this.showRightBorder,
    required this.showTopBorder,
    required this.onTap,
  });

  final Key optionKey;
  final String label;
  final bool selected;
  final bool showRightBorder;
  final bool showTopBorder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? Colors.black : Colors.white,
    child: Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: InkWell(
        key: optionKey,
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              right: showRightBorder
                  ? const BorderSide(color: Color(0x1A09090B))
                  : BorderSide.none,
              top: showTopBorder
                  ? const BorderSide(color: Color(0x1A09090B))
                  : BorderSide.none,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF71717A),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    ),
  );
}

enum _MarketItemType { exam, problemSet, course }

class _MarketItem {
  const _MarketItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.subtitle,
    required this.pricePoints,
    required this.itemCount,
    required this.moduleCount,
    required this.estimatedMinutes,
    required this.recommendedDays,
    required this.problemIds,
    this.subject = '',
    this.difficulty = '',
    this.assetId = '',
    this.owned = false,
    this.progressIndex = 0,
    this.completed = false,
  });

  final String id;
  final _MarketItemType type;
  final String title;
  final String description;
  final String subtitle;
  final int pricePoints;
  final int itemCount;
  final int moduleCount;
  final int estimatedMinutes;
  final int recommendedDays;
  final List<String> problemIds;
  final String subject;
  final String difficulty;
  final String assetId;
  final bool owned;
  final int progressIndex;
  final bool completed;

  String get typeLabel => switch (type) {
    _MarketItemType.exam => '시험지',
    _MarketItemType.problemSet => '문제집',
    _MarketItemType.course => '코스',
  };
  IconData get icon => switch (type) {
    _MarketItemType.exam => Icons.assignment_outlined,
    _MarketItemType.problemSet => Icons.inventory_2_outlined,
    _MarketItemType.course => Icons.route_outlined,
  };
  String get searchText => '$title $subtitle'.toLowerCase();
  String get compactSubtitle => subtitle
      .split(' · ')
      .where((value) => value != '무료' && !value.endsWith('P'))
      .take(3)
      .join(' · ');
  String get coverSubtitle => subtitle
      .split(' · ')
      .where(
        (value) =>
            value != '무료' && !value.endsWith('P') && !value.endsWith('문항'),
      )
      .take(2)
      .join(' · ');
  String get mobileTitle => title
      .replaceAll(RegExp(r'\s*·\s*실전$'), '')
      .replaceAll(RegExp(r'\s*코스\s*·\s*'), ' · ');
  Color get mobileAccent => switch (type) {
    _MarketItemType.exam => const Color(0xFF171719),
    _MarketItemType.problemSet => const Color(0xFFE6E6EA),
    _MarketItemType.course => const Color(0xFFDCE8FF),
  };
  Color get mobileForeground =>
      type == _MarketItemType.exam ? Colors.white : Colors.black;

  /// 필요한 변수는 현재 상품 정보다.
  /// 작동 원리는 무료 담기 성공 직후 네트워크 재검색 없이 현재 카드만 보유 상태로 바꾼다.
  _MarketItem copyWithOwned() => _MarketItem(
    id: id,
    type: type,
    title: title,
    description: description,
    subtitle: subtitle,
    pricePoints: pricePoints,
    itemCount: itemCount,
    moduleCount: moduleCount,
    estimatedMinutes: estimatedMinutes,
    recommendedDays: recommendedDays,
    problemIds: problemIds,
    subject: subject,
    difficulty: difficulty,
    assetId: assetId,
    owned: true,
    progressIndex: progressIndex,
    completed: completed,
  );

  /// 필요한 변수는 마켓 목록 API 또는 미리보기 일반 맵이다.
  /// 작동 원리는 kind·수량·가격·학년 정보를 한 줄 카드 모델로 안전하게 정규화하는 것이다.
  factory _MarketItem.fromMap(Map<String, dynamic> json) {
    final kind = json['kind']?.toString() ?? json['type']?.toString() ?? '';
    final type = switch (kind) {
      'exam' => _MarketItemType.exam,
      'course' => _MarketItemType.course,
      _ => _MarketItemType.problemSet,
    };
    final pricePoints =
        int.tryParse(json['price_points']?.toString() ?? '') ?? 0;
    final itemCount = int.tryParse(json['item_count']?.toString() ?? '') ?? 0;
    final payload = json['payload'] is Map
        ? Map<String, dynamic>.from(json['payload'] as Map)
        : const <String, dynamic>{};
    final gradeBand = json['grade_band']?.toString() ?? '';
    final title = json['title']?.toString() ?? '학습 자료';
    final subject =
        json['subject']?.toString() ?? json['subject_name']?.toString() ?? '';
    final difficulty = json['difficulty']?.toString() ?? '';
    final priceLabel = pricePoints == 0 ? '무료' : '${pricePoints}P';
    final shownMetadata = '$title $gradeBand $difficulty';
    final countAlreadyShown =
        itemCount > 0 &&
        RegExp(
          '(^|[^0-9])$itemCount\\s*(?:문제|문항|개|강|단원)',
        ).hasMatch(shownMetadata);
    final countLabel = type == _MarketItemType.exam ? '문항' : '문제';
    final details = [
      if (gradeBand.isNotEmpty) gradeBand,
      if (difficulty.isNotEmpty) difficulty,
      if (itemCount > 0 && !countAlreadyShown) '$itemCount$countLabel',
      priceLabel,
    ].join(' · ');
    return _MarketItem(
      id: json['id']?.toString() ?? '',
      type: type,
      title: title,
      description: json['description']?.toString() ?? '',
      subtitle: details.isEmpty
          ? json['description']?.toString() ?? ''
          : details,
      pricePoints: pricePoints,
      itemCount: itemCount,
      moduleCount:
          int.tryParse(
            (json['module_count'] ?? payload['module_count'])?.toString() ?? '',
          ) ??
          0,
      estimatedMinutes:
          int.tryParse(json['estimated_minutes']?.toString() ?? '') ?? 0,
      recommendedDays:
          int.tryParse(
            (json['recommended_days'] ?? payload['recommended_days'])
                    ?.toString() ??
                '',
          ) ??
          0,
      problemIds: (json['problem_ids'] is List
          ? (json['problem_ids'] as List)
                .map((id) => id.toString())
                .where((id) => id.isNotEmpty)
                .toList(growable: false)
          : const <String>[]),
      subject: subject,
      difficulty: difficulty,
      assetId: json['asset_id']?.toString() ?? '',
      owned: json['owned'] == true,
      progressIndex:
          int.tryParse(json['progress_index']?.toString() ?? '') ?? 0,
      completed: json['status']?.toString() == 'completed',
    );
  }
}

String _recommendedDuration(_MarketItem item) {
  final days = item.recommendedDays;
  if (days > 0) return days % 7 == 0 ? '${days ~/ 7}주' : '$days일';
  return item.estimatedMinutes > 0 ? '${item.estimatedMinutes}분' : '정보 없음';
}

String _courseUnitSummary(CourseUnit unit) {
  final detail = unit.detail;
  if (detail is String && detail.trim().isNotEmpty) return detail.trim();
  if (detail is Map) {
    for (final key in const ['summary', 'description', 'subtitle']) {
      final value = detail[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
  }
  return switch (unit.type) {
    'textbook_view' => '개념 학습',
    'problem_solve' => '문제 풀이',
    'exam_solve' => '시험 풀이',
    _ => '',
  };
}

class _MarketplacePreviewPage extends StatefulWidget {
  const _MarketplacePreviewPage({
    required this.item,
    required this.problems,
    required this.courseUnits,
    required this.coursePreviewFailed,
    required this.onOpenSample,
    this.onPurchase,
  });

  final _MarketItem item;
  final List<Map<String, dynamic>> problems;
  final List<CourseUnit> courseUnits;
  final bool coursePreviewFailed;
  final Future<bool> Function()? onPurchase;
  final VoidCallback? onOpenSample;

  @override
  State<_MarketplacePreviewPage> createState() =>
      _MarketplacePreviewPageState();
}

class _MarketplacePreviewPageState extends State<_MarketplacePreviewPage> {
  var _guideSelected = false;
  var _purchasing = false;
  late var _owned = widget.item.owned;

  /// 상세 화면의 구매 요청은 기존 서버 계약을 사용하고, 성공 후 버튼 상태만 갱신한다.
  Future<void> _purchase() async {
    final purchase = widget.onPurchase;
    if (purchase == null || _purchasing) return;
    setState(() => _purchasing = true);
    final succeeded = await purchase();
    if (mounted) {
      setState(() {
        _purchasing = false;
        _owned = succeeded || _owned;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isMobile = MediaQuery.sizeOf(context).width <= 720;
    final kindName = item.typeLabel;
    final number = switch (item.type) {
      _MarketItemType.course => '01',
      _MarketItemType.exam => '02',
      _MarketItemType.problemSet => '03',
    };
    final stats = item.type == _MarketItemType.course
        ? [
            ('구성', item.moduleCount > 0 ? '${item.moduleCount}단원' : '정보 없음'),
            ('문제', item.itemCount > 0 ? '${item.itemCount}개' : '정보 없음'),
            ('예상', _recommendedDuration(item)),
          ]
        : [
            ('자료 유형', kindName),
            ('문항', item.itemCount > 0 ? '${item.itemCount}개' : '정보 없음'),
            ('가격', item.pricePoints == 0 ? '무료' : '${item.pricePoints}P'),
          ];

    return StudentHtmlShell(
      title: '자료 미리보기',
      activeRoute: '/marketplace',
      showContextAside: false,
      reserveContextTrack: MediaQuery.sizeOf(context).width > 1040,
      railWidth: MediaQuery.sizeOf(context).width > 1040 ? 84 : 72,
      mobileBackButton: true,
      onMenu: () => Navigator.of(context).pop(),
      onSearch: () => showStudentQuickSearch(context),
      onNotifications: () => showStudentNotifications(context),
      child: ColoredBox(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: isMobile
                  ? const EdgeInsets.fromLTRB(14, 16, 14, 20)
                  : EdgeInsets.all(
                      (MediaQuery.sizeOf(context).width * .04).clamp(24, 48),
                    ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final mobile = constraints.maxWidth <= 720;
                  final titleSize = mobile
                      ? 23.0
                      : (MediaQuery.sizeOf(context).width * .04).clamp(
                          28.0,
                          48.0,
                        );
                  final cover = SizedBox(
                    key: const ValueKey('market-preview-cover'),
                    width: mobile ? 98 : 240,
                    child: _PreviewCover(item: item, number: number),
                  );
                  final copy = Column(
                    key: const ValueKey('market-preview-copy'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        kindName,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF71717A),
                        ),
                      ),
                      SizedBox(height: mobile ? 6 : 8),
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: titleSize,
                          height: 1.05,
                          letterSpacing: mobile ? -1.8 : titleSize * -.05,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: mobile ? 7 : 10),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: mobile ? 219 : 263,
                        ),
                        child: Text(
                          item.description.isNotEmpty
                              ? item.description
                              : item.compactSubtitle,
                          style: TextStyle(
                            fontSize: mobile ? 10 : 12,
                            height: mobile ? 1.5 : 1.65,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF71717A),
                          ),
                        ),
                      ),
                      SizedBox(height: mobile ? 12 : 24),
                      _PreviewFacts(
                        key: const ValueKey('market-preview-facts'),
                        stats: stats,
                        compact: mobile,
                      ),
                      SizedBox(height: mobile ? 10 : 18),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: mobile ? 48 : 52,
                              child: FilledButton(
                                onPressed: _owned || _purchasing
                                    ? null
                                    : _purchase,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  disabledBackgroundColor: const Color(
                                    0xFFF3F3F5,
                                  ),
                                  disabledForegroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  shape: const RoundedRectangleBorder(),
                                  textStyle: TextStyle(
                                    fontFamily: 'Noto Sans KR',
                                    fontSize: mobile ? 9 : 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                child: Text(
                                  _purchasing
                                      ? '처리 중'
                                      : _owned
                                      ? '내 학습에 담김'
                                      : item.pricePoints == 0
                                      ? switch (item.type) {
                                          _MarketItemType.course => '코스 담기',
                                          _MarketItemType.exam => '시험지 담기',
                                          _MarketItemType.problemSet =>
                                            '문제집 담기',
                                        }
                                      : '${item.pricePoints}P 담기',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: mobile ? 48 : 52,
                              child: Tooltip(
                                message: widget.onOpenSample == null
                                    ? (item.type == _MarketItemType.course
                                          ? '공개된 학습 단원이 없어 미리보기를 시작할 수 없습니다.'
                                          : '미리보기 문항이 없어 시작할 수 없습니다.')
                                    : '',
                                child: OutlinedButton.icon(
                                  key: const ValueKey(
                                    'market-preview-open-sample',
                                  ),
                                  onPressed: widget.onOpenSample,
                                  iconAlignment: IconAlignment.end,
                                  icon: const Icon(
                                    Icons.arrow_forward,
                                    size: 15,
                                  ),
                                  label: Text(switch (item.type) {
                                    _MarketItemType.course => '1강 미리보기',
                                    _MarketItemType.exam => '첫 문항 풀기',
                                    _MarketItemType.problemSet => '문제 보기',
                                  }),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.black,
                                    side: BorderSide.none,
                                    backgroundColor: Colors.white,
                                    shape: const RoundedRectangleBorder(),
                                    textStyle: TextStyle(
                                      fontFamily: 'Noto Sans KR',
                                      fontSize: mobile ? 9 : 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                  if (mobile) {
                    return ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 202),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            cover,
                            const SizedBox(width: 14),
                            Expanded(child: copy),
                          ],
                        ),
                      ),
                    );
                  }
                  return ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 270),
                    child: Stack(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(width: 240 + 52),
                            Expanded(child: copy),
                          ],
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 240,
                          child: cover,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: isMobile
                  ? const EdgeInsets.fromLTRB(14, 18, 14, 36)
                  : EdgeInsets.all(
                      (MediaQuery.sizeOf(context).width * .04).clamp(22, 48),
                    ),
              child: switch (item.type) {
                _MarketItemType.exam => _ExamPreviewBody(
                  item: item,
                  problems: widget.problems,
                ),
                _MarketItemType.problemSet => _WorkbookPreviewBody(
                  item: item,
                  problems: widget.problems,
                ),
                _MarketItemType.course => _CoursePreviewBody(
                  item: item,
                  units: widget.courseUnits,
                  loadFailed: widget.coursePreviewFailed,
                  guideSelected: _guideSelected,
                  onTabChanged: (value) =>
                      setState(() => _guideSelected = value),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCover extends StatelessWidget {
  const _PreviewCover({required this.item, required this.number});

  final _MarketItem item;
  final String number;

  @override
  Widget build(BuildContext context) {
    final exam = item.type == _MarketItemType.exam;
    return Container(
      padding: EdgeInsets.all(
        MediaQuery.sizeOf(context).width <= 720 ? 12 : 18,
      ),
      decoration: BoxDecoration(
        color: exam
            ? Colors.white
            : item.type == _MarketItemType.course
            ? Colors.black
            : const Color(0xFFF3F3F5),
        border: Border.all(color: const Color(0xFF09090B)),
        boxShadow: exam
            ? const [BoxShadow(color: Color(0xFFF3F3F5), offset: Offset(12, 0))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            item.typeLabel,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: item.type == _MarketItemType.course
                  ? Colors.white
                  : Colors.black,
              letterSpacing: .7,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              number,
              style: TextStyle(
                fontSize: MediaQuery.sizeOf(context).width <= 720 ? 42 : 82,
                height: .9,
                letterSpacing: -6,
                fontWeight: FontWeight.w900,
                color: item.type == _MarketItemType.course
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ),
          Text(
            item.coverSubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: item.type == _MarketItemType.course
                  ? Colors.white
                  : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewFacts extends StatelessWidget {
  const _PreviewFacts({super.key, required this.stats, required this.compact});

  final List<(String, String)> stats;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var index = 0; index < stats.length; index++)
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 13,
              vertical: compact ? 8 : 13,
            ),
            decoration: BoxDecoration(
              border: Border(
                top: const BorderSide(color: Color(0x1A09090B)),
                bottom: const BorderSide(color: Color(0x1A09090B)),
                left: const BorderSide(color: Color(0x1A09090B)),
                right: index == stats.length - 1
                    ? const BorderSide(color: Color(0x1A09090B))
                    : BorderSide.none,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats[index].$1,
                  style: TextStyle(
                    fontSize: compact ? 8 : 9,
                    color: const Color(0xFF71717A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  stats[index].$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 11 : 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _CoursePreviewBody extends StatelessWidget {
  const _CoursePreviewBody({
    required this.item,
    required this.units,
    required this.loadFailed,
    required this.guideSelected,
    required this.onTabChanged,
  });

  final _MarketItem item;
  final List<CourseUnit> units;
  final bool loadFailed;
  final bool guideSelected;
  final ValueChanged<bool> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = const ['커리큘럼', '학습 정보'];
    return Column(
      children: [
        Container(
          key: const ValueKey('market-preview-tabs'),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x1A09090B)),
          ),
          child: Row(
            children: [
              for (var index = 0; index < tabs.length; index++)
                Expanded(
                  child: _PreviewTab(
                    label: tabs[index],
                    selected: guideSelected == (index == 1),
                    showRightBorder: index == 0,
                    onTap: () => onTabChanged(index == 1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _PreviewInfoRows(
          guide: guideSelected,
          rows: guideSelected
              ? [
                  (
                    '추천 대상',
                    item.compactSubtitle.isEmpty
                        ? item.typeLabel
                        : item.compactSubtitle,
                    '',
                    '',
                  ),
                  ('완료 기준', '실제 학습 완료 상태를 기준으로 표시', '', ''),
                  ('학습 방식', item.description, '', ''),
                ]
              : units.isEmpty
              ? [
                  (
                    '—',
                    loadFailed ? '단원 정보를 불러오지 못했습니다' : '공개된 단원이 없습니다',
                    loadFailed ? '잠시 후 다시 시도해 주세요.' : item.description,
                    '',
                  ),
                ]
              : [
                  for (var index = 0; index < units.length; index++)
                    (
                      (index + 1).toString().padLeft(2, '0'),
                      units[index].title,
                      _courseUnitSummary(units[index]),
                      units[index].estimatedMinutes > 0
                          ? '${units[index].estimatedMinutes}분'
                          : '',
                    ),
                ],
        ),
      ],
    );
  }
}

class _PreviewTab extends StatelessWidget {
  const _PreviewTab({
    required this.label,
    required this.selected,
    required this.showRightBorder,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool showRightBorder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? Colors.black : Colors.white,
    child: InkWell(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            right: showRightBorder
                ? const BorderSide(color: Color(0x1A09090B))
                : BorderSide.none,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF71717A),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ),
  );
}

class _PreviewInfoRows extends StatelessWidget {
  const _PreviewInfoRows({required this.rows, this.guide = false});

  final List<(String, String, String, String)> rows;
  final bool guide;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= 720;
    return Container(
      key: const ValueKey('market-preview-list'),
      decoration: const BoxDecoration(
        border: Border.fromBorderSide(BorderSide(color: Color(0x1A09090B))),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++)
            _buildRow(rows[index], index, mobile),
        ],
      ),
    );
  }

  Widget _buildRow(
    (String, String, String, String) row,
    int index,
    bool mobile,
  ) => Container(
    key: ValueKey('market-preview-row-$index'),
    constraints: BoxConstraints(minHeight: guide ? 70 : 78),
    padding: EdgeInsets.symmetric(
      horizontal: guide && mobile
          ? 12
          : mobile
          ? 10
          : 18,
    ),
    decoration: const BoxDecoration(
      border: Border(
        right: BorderSide(color: Color(0x1A09090B)),
        bottom: BorderSide(color: Color(0x1A09090B)),
      ),
    ),
    child: Row(
      children: [
        SizedBox(
          width: guide ? (mobile ? 82 : 110) : (mobile ? 34 : 48),
          child: Text(
            row.$1,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF71717A),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                row.$2,
                style: TextStyle(
                  fontSize: guide ? 11 : 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (row.$3.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    row.$3,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF71717A),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!guide && row.$4.isNotEmpty)
          Text(
            row.$4,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF71717A),
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    ),
  );
}

class _ExamPreviewBody extends StatelessWidget {
  const _ExamPreviewBody({required this.item, required this.problems});

  final _MarketItem item;
  final List<Map<String, dynamic>> problems;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= 720;
    return Flex(
      direction: mobile ? Axis.vertical : Axis.horizontal,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: mobile ? 0 : 4,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: AspectRatio(
                aspectRatio: 1 / 1.28,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                    border: Border.fromBorderSide(
                      BorderSide(color: Color(0xFF09090B)),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFF3F3F5),
                        offset: Offset(10, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        item.compactSubtitle,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF71717A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 20),
                      for (
                        var i = 0;
                        i <
                            (problems.isEmpty
                                ? 4
                                : problems.length.clamp(1, 4));
                        i++
                      )
                        Padding(
                          padding: const EdgeInsets.only(bottom: 17),
                          child: Row(
                            children: [
                              Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Column(
                                  children: [
                                    ColoredBox(
                                      color: Color(0xFFF3F3F5),
                                      child: SizedBox(
                                        height: 5,
                                        width: double.infinity,
                                      ),
                                    ),
                                    SizedBox(height: 7),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                        widthFactor: .72,
                                        child: ColoredBox(
                                          color: Color(0xFFF3F3F5),
                                          child: SizedBox(height: 5),
                                        ),
                                      ),
                                    ),
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
            ),
          ),
        ),
        SizedBox(width: mobile ? 0 : 46, height: mobile ? 32 : 0),
        Expanded(
          flex: mobile ? 0 : 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFF09090B)),
                    bottom: BorderSide(color: Color(0x1A09090B)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '문항 구성',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${item.itemCount}문항',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF71717A),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              for (final label in const ['개념 확인', '기본 적용', '실전 적용'])
                Container(
                  height: 62,
                  alignment: Alignment.centerLeft,
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0x1A09090B)),
                    ),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text(
                  '답안 제출 후 실제 풀이 결과와 취약 개념을 확인할 수 있습니다.',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF71717A),
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkbookPreviewBody extends StatelessWidget {
  const _WorkbookPreviewBody({required this.item, required this.problems});

  final _MarketItem item;
  final List<Map<String, dynamic>> problems;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= 720;
    final stages = [
      ('01', '학습 범위', item.description.isEmpty ? item.title : item.description),
      ('02', '수록 문항', '${item.itemCount}개 자료'),
      (
        '03',
        '학습 진행',
        problems.isEmpty
            ? '자료를 열면 실제 문항을 확인할 수 있습니다.'
            : '${problems.length}개 미리보기 문항',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '훈련 범위',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  '실제 자료 정보',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF71717A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Text(
              '${stages.length}단계',
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF71717A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = mobile ? 1 : 3;
            final width = constraints.maxWidth / columns;
            return Wrap(
              children: [
                for (var i = 0; i < stages.length; i++)
                  SizedBox(
                    width: width,
                    child: Container(
                      height: mobile ? 112 : 170,
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Color(0x1A09090B)),
                          bottom: BorderSide(color: Color(0x1A09090B)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stages[i].$1,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF71717A),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            stages[i].$2,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            stages[i].$3,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              height: 1.5,
                              color: Color(0xFF71717A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(
                            height: 5,
                            child: ColoredBox(
                              color: Color(0xFFF3F3F5),
                              child: SizedBox(width: double.infinity),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x1A09090B))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '자료 유형',
                style: TextStyle(
                  fontSize: 9,
                  color: Color(0xFF71717A),
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${item.typeLabel} · ${item.itemCount}개',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MarketplacePreviewSheet extends StatelessWidget {
  const _MarketplacePreviewSheet({
    required this.item,
    required this.problems,
    required this.onPurchase,
  });

  final _MarketItem item;
  final List<Map<String, dynamic>> problems;
  final Future<void> Function()? onPurchase;

  /// 필요한 변수는 선택한 자료의 유형·제목·학습 조건이다.
  /// 작동 원리는 설명·칩·중복 버튼을 줄이고 코스 단계와 무료 담기 동작만 큰 글자로 제공한다.
  @override
  Widget build(BuildContext context) {
    final previewLabel = switch (item.type) {
      _MarketItemType.exam => '시험지 미리보기',
      _MarketItemType.problemSet => '문제집 미리보기',
      _MarketItemType.course => '코스 미리보기',
    };
    final previewItems = problems.isNotEmpty
        ? problems
              .asMap()
              .entries
              .map(
                (entry) => (
                  (entry.key + 1).toString().padLeft(2, '0'),
                  _problemTitle(entry.value),
                ),
              )
              .toList(growable: false)
        : switch (item.type) {
            _MarketItemType.exam => const <(String, String)>[],
            _MarketItemType.problemSet => const <(String, String)>[],
            _MarketItemType.course => const <(String, String)>[],
          };
    final calculatedStageCount = (item.itemCount + 4) ~/ 5;
    final courseStageCount = calculatedStageCount.clamp(1, 3);

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .68,
        minChildSize: .42,
        maxChildSize: .86,
        builder: (context, controller) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        previewLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF6D6D73),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 27),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 30,
                    height: 1.15,
                    letterSpacing: -1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${item.compactSubtitle} · 무료',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF65656B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.45,
                      color: Color(0xFF525258),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  '학습 구성',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                if (problems.isEmpty)
                  for (var index = 0; index < courseStageCount; index++)
                    _LearningPreviewStage(
                      index: index,
                      label: _fallbackStageLabel(item.type, index),
                      last: index == courseStageCount - 1,
                    )
                else if (item.type == _MarketItemType.course)
                  for (var index = 0; index < courseStageCount; index++)
                    _LearningPreviewStage(
                      index: index,
                      label: _fallbackStageLabel(item.type, index),
                      last: index == courseStageCount - 1,
                    )
                else
                  for (var index = 0; index < previewItems.length; index++) ...[
                    _PreviewProblemCard(
                      number: previewItems[index].$1,
                      problem: problems.length > index ? problems[index] : null,
                      fallbackTitle: previewItems[index].$2,
                    ),
                    if (index != previewItems.length - 1)
                      const SizedBox(height: 9),
                  ],
                const SizedBox(height: 24),
                if (item.owned)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: item.completed
                          ? const Color(0xFFEAF7EE)
                          : const Color(0xFFF2F2F4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      item.completed ? '이수 완료' : '내 학습에 추가된 코스입니다.',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: onPurchase,
                    child: const Text(
                      '무료로 내 학습에 담기',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 필요한 변수는 문제 원문 맵이다.
  /// 작동 원리는 서버 응답의 data.quest_title을 우선 사용하고, 누락된 데이터는 안전한 안내 문구로 대체하는 것이다.
  static String _problemTitle(Map<String, dynamic> problem) {
    final data = problem['data'] is Map
        ? Map<String, dynamic>.from(problem['data'] as Map)
        : problem;
    final rawTitle = data['quest_title'] ?? problem['quest_title'];
    final title = parseContentBlocks(rawTitle)
        .map((block) => block.content.trim())
        .where((content) => content.isNotEmpty)
        .join(' ');
    if (title.isNotEmpty) return title;
    return '문제 내용을 확인할 수 없습니다.';
  }

  /// 필요한 변수는 문제·선택지 안의 텍스트 또는 콘텐츠 블록이다.
  /// 작동 원리는 수식 블록도 미리보기에서 깨지지 않도록 사람이 읽을 수 있는 문자열로만 변환하는 것이다.
  static String _contentPreviewText(dynamic value) {
    final text = parseContentBlocks(value)
        .map((block) => block.content.trim())
        .where((content) => content.isNotEmpty)
        .join(' ');
    return text.isEmpty ? value?.toString() ?? '' : text;
  }

  /// 필요한 변수는 자료 유형과 단계 번호다.
  /// 작동 원리는 원문 문제 ID가 없는 Vercel 카탈로그에서도 오류 대신 실제 자료 구성에 맞는 짧은 학습 단계를 표시한다.
  static String _fallbackStageLabel(_MarketItemType type, int index) {
    final labels = switch (type) {
      _MarketItemType.exam => ['출제 범위 확인', '10문항 실전 풀이', '결과 확인'],
      _MarketItemType.problemSet => ['핵심 유형 확인', '5문항 집중 풀이', '정답 점검'],
      _MarketItemType.course => ['핵심 개념 확인', '유형 문제 훈련', '학습 마무리'],
    };
    return labels[index];
  }
}

class _LearningPreviewStage extends StatelessWidget {
  const _LearningPreviewStage({
    required this.index,
    required this.label,
    required this.last,
  });

  final int index;
  final String label;
  final bool last;

  /// 필요한 변수는 코스 단계 번호와 마지막 단계 여부다.
  /// 작동 원리는 문제 원문 대신 학습 흐름만 한 줄로 보여 줘 비어 있는 문제 오류 문구를 노출하지 않는다.
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: last ? 0 : 9),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDEDEE2)),
      ),
      child: Row(
        children: [
          Text(
            '${index + 1}',
            style: const TextStyle(
              fontSize: 17,
              color: Color(0xFF74747A),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
          const Icon(Icons.check_circle_outline_rounded, size: 22),
        ],
      ),
    );
  }
}

class _PreviewProblemCard extends StatelessWidget {
  const _PreviewProblemCard({
    required this.number,
    required this.problem,
    required this.fallbackTitle,
  });

  final String number;
  final Map<String, dynamic>? problem;
  final String fallbackTitle;

  /// 필요한 변수는 문제 번호·문제 원문·대체 제목이다.
  /// 작동 원리는 문제와 선택지를 표시만 하고 입력 위젯이나 정답 판정은 제공하지 않아 읽기 전용 미리보기를 유지하는 것이다.
  @override
  Widget build(BuildContext context) {
    final data = problem?['data'] is Map
        ? Map<String, dynamic>.from(problem!['data'] as Map)
        : problem;
    final title = data == null
        ? fallbackTitle
        : _MarketplacePreviewSheet._problemTitle(problem!);
    final options = data?['quest_options'] ?? data?['options'];
    final optionItems = options is List
        ? options
              .map(_MarketplacePreviewSheet._contentPreviewText)
              .toList(growable: false)
        : const <String>[];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '문제 $number',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.black45,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
          ),
          if (optionItems.isNotEmpty) ...[
            const SizedBox(height: 9),
            for (var index = 0; index < optionItems.length; index++)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${index + 1}. ${optionItems[index]}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
