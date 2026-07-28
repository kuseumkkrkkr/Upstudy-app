import 'dart:async';

import 'package:flutter/material.dart';

import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
import 'package:s11/shared/data/models/content_block.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key, this.initialData});

  final List<Map<String, dynamic>>? initialData;

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  final TextEditingController _queryController = TextEditingController();
  List<_MarketItem> _items = const <_MarketItem>[];
  String _filter = '전체';
  String _courseFilter = '전체 과정';
  String _priceFilter = '전체 가격';
  String? _recommendationGrade;
  String? _recommendationGradeFilter;
  int? _nextOffset;
  int _total = 0;
  bool _loading = false;
  String? _error;

  static const _corners = <_MarketplaceCorner>[
    _MarketplaceCorner(
      title: '시험지',
      description: '완성된 시험지를 찾아 학습에 담아보세요.',
      icon: Icons.assignment_outlined,
      filter: '시험지',
    ),
    _MarketplaceCorner(
      title: '문제세트',
      description: '주제와 난이도에 맞는 문제세트를 둘러보세요.',
      icon: Icons.inventory_2_outlined,
      filter: '문제세트',
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
    final initialData = widget.initialData;
    if (initialData != null) {
      _items = initialData.map(_MarketItem.fromMap).toList(growable: false);
      _total = _items.length;
    } else {
      unawaited(_loadInitialResults());
    }
  }

  /// 필요한 변수는 검색 컨트롤러다.
  /// 작동 원리는 화면 종료 시 입력 리소스를 해제하는 것이다.
  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  /// 필요한 변수는 사용자 프로필과 마켓 검색 API다.
  /// 작동 원리는 가입 정보의 과정·학년을 추천 조건으로 사용해 특정 학년 문구를 화면에 고정하지 않는 것이다.
  Future<void> _loadInitialResults() async {
    // 목록은 프로필 추천 조건과 독립적으로 먼저 요청해 느린 /auth/me가 마켓을 막지 않게 한다.
    final initialSearch = _search();
    try {
      final profile = await ApiClient.instance.getMyProfile();
      final track = profile.track?.trim() ?? '';
      final grade = profile.grade?.trim() ?? '';
      // 관리자·비표준 프로필 값은 학년 조건으로 보내면 전체 마켓이 비게 된다.
      _recommendationGradeFilter = _isLearnerGrade(grade) ? grade : null;
      _recommendationGrade = [
        track,
        _recommendationGradeFilter ?? '',
      ].where((value) => value.isNotEmpty).join(' ');
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
        gradeBand: _courseFilter == '전체 과정'
            ? _recommendationGradeFilter
            : _courseFilter,
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
        _total = page.total;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '마켓 자료를 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? get _apiKind => switch (_filter) {
    '시험지' => 'exam',
    '문제세트' => 'problem_set',
    '코스' => 'course',
    _ => null,
  };

  String get _recommendationTitle {
    final grade = _recommendationGrade?.trim() ?? '';
    return grade.isEmpty ? '맞춤 추천' : '$grade 추천';
  }

  /// 필요한 변수는 위젯에 주입된 미리보기 자료다.
  /// 작동 원리는 네트워크를 쓰지 않는 미리보기·테스트만 로컬 필터를 허용하고 실제 마켓은 항상 서버 필터를 사용하게 하는 것이다.
  List<_MarketItem> get _initialFilteredItems {
    if (widget.initialData == null) return _items;
    return _items
        .where(
          (item) =>
              _filter == '전체' ||
              (_filter == '시험지' && item.type == _MarketItemType.exam) ||
              (_filter == '문제세트' && item.type == _MarketItemType.problemSet) ||
              (_filter == '코스' && item.type == _MarketItemType.course),
        )
        .toList(growable: false);
  }

  /// 필요한 변수는 현재 유형·과정·가격 필터다.
  /// 작동 원리는 HTML의 필터+ 바텀시트에서 조건을 임시 선택한 뒤 적용 시 한 번만 목록 상태를 갱신한다.
  Future<void> _openMarketFilter() async {
    final result = await showModalBottomSheet<(String, String, String)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _MarketFilterSheet(
        type: _filter,
        course: _courseFilter,
        price: _priceFilter,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _filter = result.$1;
      _courseFilter = result.$2;
      _priceFilter = result.$3;
    });
    if (widget.initialData == null) unawaited(_search());
  }

  /// 필요한 변수는 검색 패널이 전달한 기본 필터명이다.
  /// 작동 원리는 필터+만 상세 시트를 열고 나머지 유형은 즉시 로컬 전환한다.
  void _handleFilterChanged(String value) {
    if (value == '필터+') {
      unawaited(_openMarketFilter());
      return;
    }
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
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 680),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _MarketplacePreviewSheet(
        item: item,
        problems: problems,
        onPurchase: item.owned
            ? null
            : () async {
                try {
                  await ApiClient.instance.purchaseMarketplaceListing(item.id);
                  if (!mounted) return;
                  setState(() {
                    _items = _items
                        .map(
                          (current) => current.id == item.id
                              ? current.copyWithOwned()
                              : current,
                        )
                        .toList(growable: false);
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('내 학습 자료에 담았습니다.')),
                  );
                } on ApiException catch (error) {
                  if (!mounted) return;
                  final message = error.message == 'insufficient_coins'
                      ? '코인이 부족합니다.'
                      : '자료를 추가하지 못했습니다. 잠시 후 다시 시도해 주세요.';
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('자료를 추가하지 못했습니다.')),
                  );
                }
              },
      ),
    );
  }

  /// 필요한 변수는 현재 화면 문맥이다.
  /// 작동 원리는 PC 공용 메뉴에서 마켓을 활성화하고 모바일에서는 같은 AppDrawer를 여는 것이다.
  Widget _buildHeader(BuildContext context) {
    return Ios26TopBar(
      brandColor: Colors.black,
      showLevelIndicator: false,
      onMenu: () => MediaQuery.sizeOf(context).width <= 720
          ? MobileStudentBottomAppBar.openMore(context)
          : toggleAppDrawer(context),
      onTitleTap: () => Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainStudentPage()),
        (route) => false,
      ),
      items: studentTopNavItems(
        context,
        active: StudentTopDestination.marketplace,
      ),
    );
  }

  /// 필요한 변수는 화면 크기·검색·필터·추천 결과 상태다.
  /// 작동 원리는 세로형 휴대폰에는 검색 중심 상품 그리드를, 태블릿·PC에는 기존 정보형 마켓을 각각 렌더링하는 것이다.
  @override
  Widget build(BuildContext context) {
    final items = _initialFilteredItems;
    final size = MediaQuery.sizeOf(context);
    final desktop = size.width >= 1000;
    // 웹의 600~720px 세로 뷰포트도 휴대폰 UI로 분류해 태블릿형 정보 카드가 노출되지 않게 한다.
    final portraitMobile = size.width <= 720 && size.height > size.width;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      drawer: portraitMobile ? null : const AppDrawer(),
      bottomNavigationBar: portraitMobile
          ? const MobileStudentBottomAppBar()
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Builder(builder: _buildHeader),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _search,
                child: ListView(
                  key: ValueKey(
                    portraitMobile
                        ? 'market-mobile-scroll'
                        : 'market-wide-scroll',
                  ),
                  padding: EdgeInsets.fromLTRB(
                    portraitMobile ? 16 : (desktop ? 40 : 14),
                    portraitMobile ? 18 : 24,
                    portraitMobile ? 16 : (desktop ? 40 : 14),
                    portraitMobile ? 28 : 40,
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: portraitMobile
                            ? _MobileMarketplaceBody(
                                controller: _queryController,
                                corners: _corners,
                                selected: _filter,
                                courseFilter: _courseFilter,
                                priceFilter: _priceFilter,
                                items: items,
                                loading: _loading,
                                error: _error,
                                hasNextPage: _nextOffset != null,
                                onSelected: _handleFilterChanged,
                                onOpenFilter: _openMarketFilter,
                                onSearch: _search,
                                onOpen: _openItem,
                                onLoadMore: () =>
                                    unawaited(_search(append: true)),
                              )
                            : _WideMarketplaceBody(
                                controller: _queryController,
                                corners: _corners,
                                selected: _filter,
                                items: items,
                                title: _recommendationTitle,
                                total: _total,
                                loading: _loading,
                                error: _error,
                                desktop: desktop,
                                hasNextPage: _nextOffset != null,
                                onSelected: _handleFilterChanged,
                                onSearch: _search,
                                onOpen: _openItem,
                                onLoadMore: () =>
                                    unawaited(_search(append: true)),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WideMarketplaceBody extends StatelessWidget {
  const _WideMarketplaceBody({
    required this.controller,
    required this.corners,
    required this.selected,
    required this.items,
    required this.title,
    required this.total,
    required this.loading,
    required this.error,
    required this.desktop,
    required this.hasNextPage,
    required this.onSelected,
    required this.onSearch,
    required this.onOpen,
    required this.onLoadMore,
  });

  final TextEditingController controller;
  final List<_MarketplaceCorner> corners;
  final String selected;
  final List<_MarketItem> items;
  final String title;
  final int total;
  final bool loading;
  final String? error;
  final bool desktop;
  final bool hasNextPage;
  final ValueChanged<String> onSelected;
  final VoidCallback onSearch;
  final ValueChanged<_MarketItem> onOpen;
  final VoidCallback onLoadMore;

  /// 필요한 변수는 태블릿·PC용 마켓 상태다.
  /// 작동 원리는 기존 넓은 화면 정보 구조를 그대로 보존해 모바일 전용 변경이 태블릿 레이아웃에 영향을 주지 않게 한다.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'COMMUNITY',
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 1.7,
          color: Colors.black54,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '마켓',
        style: TextStyle(
          fontSize: desktop ? 50 : 32,
          letterSpacing: desktop ? -2.4 : -1.4,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        '필요한 학습 자료를 찾아 내 학습으로 연결합니다.',
        style: TextStyle(color: Colors.black45),
      ),
      const SizedBox(height: 28),
      _MarketplaceCorners(
        corners: corners,
        selected: selected,
        onSelected: onSelected,
      ),
      const SizedBox(height: 12),
      _SearchPanel(
        controller: controller,
        loading: loading,
        filter: selected,
        desktop: desktop,
        onFilterChanged: onSelected,
        onSearch: onSearch,
      ),
      const SizedBox(height: 12),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(error!, style: const TextStyle(color: Colors.red)),
        ),
      _RecommendationCard(
        items: items.take(3).toList(),
        title: title,
        total: total,
        onOpen: onOpen,
      ),
      if (items.length > 3) ...[
        const SizedBox(height: 12),
        _MoreResultsCard(items: items.skip(3).toList(), onOpen: onOpen),
      ],
      if (hasNextPage) ...[
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton(
            onPressed: loading ? null : onLoadMore,
            child: Text(loading ? '불러오는 중' : '더 보기'),
          ),
        ),
      ],
    ],
  );
}

class _MobileMarketplaceBody extends StatelessWidget {
  const _MobileMarketplaceBody({
    required this.controller,
    required this.corners,
    required this.selected,
    required this.courseFilter,
    required this.priceFilter,
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
  final List<_MarketplaceCorner> corners;
  final String selected;
  final String courseFilter;
  final String priceFilter;
  final List<_MarketItem> items;
  final bool loading;
  final String? error;
  final bool hasNextPage;
  final ValueChanged<String> onSelected;
  final VoidCallback onOpenFilter;
  final VoidCallback onSearch;
  final ValueChanged<_MarketItem> onOpen;
  final VoidCallback onLoadMore;

  /// 필요한 변수는 휴대폰 검색·카테고리·상품 결과다.
  /// 작동 원리는 긴 소개 영역을 제거하고 검색, 카테고리, 2열 상품 순서로 한 손 탐색 동선을 만든다.
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('market-mobile-body'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '코스 찾기',
        style: TextStyle(
          fontSize: 40,
          height: 1,
          letterSpacing: -2,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 18),
      _MobileMarketSearch(
        controller: controller,
        loading: loading,
        onSearch: onSearch,
      ),
      const SizedBox(height: 14),
      _MobileMarketCategories(
        corners: corners,
        selected: selected,
        onSelected: onSelected,
      ),
      const SizedBox(height: 22),
      Row(
        children: [
          Expanded(
            child: Text(
              selected == '전체' ? '추천 자료' : selected,
              style: const TextStyle(
                fontSize: 28,
                letterSpacing: -.8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton.filledTonal(
            key: const ValueKey('market-mobile-filter'),
            onPressed: onOpenFilter,
            tooltip: '상세 필터',
            icon: const Icon(Icons.tune_rounded, size: 23),
          ),
        ],
      ),
      if (courseFilter != '전체 과정' || priceFilter != '전체 가격') ...[
        const SizedBox(height: 8),
        Text(
          [
            courseFilter,
            priceFilter,
          ].where((value) => !value.startsWith('전체')).join(' · '),
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF5E5E64),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
      const SizedBox(height: 14),
      if (loading && items.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator(color: Colors.black)),
        )
      else if (error != null)
        _MobileMarketMessage(
          icon: Icons.cloud_off_rounded,
          message: error!,
          action: '다시 불러오기',
          onPressed: onSearch,
        )
      else if (items.isEmpty)
        _MobileMarketMessage(
          icon: Icons.search_off_rounded,
          message: '조건에 맞는 자료가 없습니다.',
          action: '전체 보기',
          onPressed: () => onSelected('전체'),
        )
      else
        _MobileMarketGrid(items: items, onOpen: onOpen),
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    ],
  );
}

class _MobileMarketSearch extends StatelessWidget {
  const _MobileMarketSearch({
    required this.controller,
    required this.loading,
    required this.onSearch,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSearch;

  /// 필요한 변수는 검색어·로딩 상태다.
  /// 작동 원리는 별도 검색 버튼 대신 입력창 안의 52px 동작 버튼으로 모바일 공간과 터치 동선을 줄인다.
  @override
  Widget build(BuildContext context) => TextField(
    key: const ValueKey('market-search-field'),
    controller: controller,
    textInputAction: TextInputAction.search,
    onSubmitted: (_) => onSearch(),
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    decoration: InputDecoration(
      hintText: '코스 · 시험지 검색',
      hintStyle: const TextStyle(
        fontSize: 17,
        color: Color(0xFF88888E),
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: const Icon(Icons.search_rounded, size: 26),
      suffixIcon: Padding(
        padding: const EdgeInsets.all(5),
        child: IconButton.filled(
          key: const ValueKey('market-mobile-search-button'),
          onPressed: loading ? null : onSearch,
          style: IconButton.styleFrom(backgroundColor: Colors.black),
          icon: loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.arrow_forward_rounded, color: Colors.white),
        ),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD9D9DD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD9D9DD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
    ),
  );
}

class _MobileMarketCategories extends StatelessWidget {
  const _MobileMarketCategories({
    required this.corners,
    required this.selected,
    required this.onSelected,
  });

  final List<_MarketplaceCorner> corners;
  final String selected;
  final ValueChanged<String> onSelected;

  /// 필요한 변수는 전체 항목과 세 마켓 카테고리다.
  /// 작동 원리는 설명 카드 대신 네 개의 동일 폭 터치 영역을 사용해 한 화면에서 유형을 즉시 바꾸게 한다.
  @override
  Widget build(BuildContext context) {
    final categories = [
      const _MarketplaceCorner(
        title: '전체',
        description: '',
        icon: Icons.grid_view_rounded,
        filter: '전체',
      ),
      ...corners,
    ];
    return Row(
      key: const ValueKey('market-mobile-categories'),
      children: [
        for (var index = 0; index < categories.length; index++) ...[
          Expanded(
            child: _MobileMarketCategory(
              corner: categories[index],
              selected: selected == categories[index].filter,
              onTap: () => onSelected(categories[index].filter),
            ),
          ),
          if (index != categories.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _MobileMarketCategory extends StatelessWidget {
  const _MobileMarketCategory({
    required this.corner,
    required this.selected,
    required this.onTap,
  });

  final _MarketplaceCorner corner;
  final bool selected;
  final VoidCallback onTap;

  /// 필요한 변수는 카테고리·선택 상태다.
  /// 작동 원리는 최소 72px 높이의 아이콘 버튼으로 모바일에서 현재 유형을 명확히 표시한다.
  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey('market-corner-${corner.filter}'),
    color: selected ? Colors.black : Colors.white,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? Colors.black : const Color(0xFFDCDCE0),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              corner.icon,
              size: 22,
              color: selected ? Colors.white : Colors.black,
            ),
            const SizedBox(height: 5),
            Text(
              corner.title,
              maxLines: 1,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MobileMarketGrid extends StatelessWidget {
  const _MobileMarketGrid({required this.items, required this.onOpen});

  final List<_MarketItem> items;
  final ValueChanged<_MarketItem> onOpen;

  /// 필요한 변수는 현재 페이지 상품 목록과 열기 동작이다.
  /// 작동 원리는 각 항목을 큰 캡슐로 반복하지 않고 하나의 흰 목록 안에서 구분선으로 나눠 스크롤 길이와 시각 소음을 줄인다.
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('market-mobile-grid'),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFDEDEE2)),
    ),
    child: Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _MobileMarketCard(item: items[index], onOpen: onOpen),
          if (index != items.length - 1)
            const Divider(height: 1, indent: 72, color: Color(0xFFE8E8EB)),
        ],
      ],
    ),
  );
}

class _MobileMarketCard extends StatelessWidget {
  const _MobileMarketCard({required this.item, required this.onOpen});

  final _MarketItem item;
  final ValueChanged<_MarketItem> onOpen;

  /// 필요한 변수는 상품 유형·제목·학습 조건이다.
  /// 작동 원리는 유형별 아이콘 표식과 한 줄 제목·조건만 사용해 시험지, 문제세트, 코스를 빠르게 구분하게 한다.
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => onOpen(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: item.mobileAccent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, size: 22, color: item.mobileForeground),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.mobileTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.2,
                      letterSpacing: -.4,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${item.typeLabel} · ${item.compactSubtitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF707076),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '무료',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 24),
          ],
        ),
      ),
    ),
  );
}

class _MobileMarketMessage extends StatelessWidget {
  const _MobileMarketMessage({
    required this.icon,
    required this.message,
    required this.action,
    required this.onPressed,
  });

  final IconData icon;
  final String message;
  final String action;
  final VoidCallback onPressed;

  /// 필요한 변수는 빈 결과 또는 오류 안내와 복구 동작이다.
  /// 작동 원리는 모바일 그리드 자리에 큰 아이콘과 단일 버튼을 제공해 다음 행동을 바로 선택하게 한다.
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 42),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFDEDEE2)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 34, color: const Color(0xFF65656B)),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    ),
  );
}

class _MarketplaceCorners extends StatelessWidget {
  const _MarketplaceCorners({
    required this.corners,
    required this.selected,
    required this.onSelected,
  });

  final List<_MarketplaceCorner> corners;
  final String selected;
  final ValueChanged<String> onSelected;

  /// 필요한 변수는 마켓에서 제공할 코너 목록과 화면 너비다.
  /// 작동 원리는 시험지·문제세트·코스를 동일한 카드 규격으로 보여 주고 좁은 화면에서는 세로로 재배치하는 것이다.
  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 760;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0E0E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MARKET CORNERS',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.6,
              color: Colors.black54,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '마켓 코너',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          desktop
              ? Row(
                  children: [
                    for (var index = 0; index < corners.length; index++) ...[
                      Expanded(
                        child: _MarketplaceCornerCard(
                          corner: corners[index],
                          selected: selected == corners[index].filter,
                          onTap: () => onSelected(corners[index].filter),
                        ),
                      ),
                      if (index != corners.length - 1)
                        const SizedBox(width: 10),
                    ],
                  ],
                )
              : Column(
                  children: [
                    for (var index = 0; index < corners.length; index++) ...[
                      _MarketplaceCornerCard(
                        corner: corners[index],
                        selected: selected == corners[index].filter,
                        onTap: () => onSelected(corners[index].filter),
                      ),
                      if (index != corners.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                ),
        ],
      ),
    );
  }
}

class _MarketplaceCornerCard extends StatelessWidget {
  const _MarketplaceCornerCard({
    required this.corner,
    required this.selected,
    required this.onTap,
  });

  final _MarketplaceCorner corner;
  final bool selected;
  final VoidCallback onTap;

  /// 필요한 변수는 코너의 제목·설명·아이콘이다.
  /// 작동 원리는 새 자료 탐색 기능을 연결하기 전에도 각 마켓 영역의 목적을 독립 카드로 명확히 안내하는 것이다.
  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : Colors.black;
    return Material(
      key: ValueKey('market-corner-${corner.filter}'),
      color: selected ? const Color(0xFF202022) : const Color(0xFFF7F7F8),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(corner.icon, size: 22, color: foreground),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                corner.title,
                style: TextStyle(
                  color: foreground,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                corner.description,
                style: TextStyle(
                  fontSize: 12,
                  color: foreground.withValues(alpha: .58),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.loading,
    required this.filter,
    required this.desktop,
    required this.onFilterChanged,
    required this.onSearch,
  });

  final TextEditingController controller;
  final bool loading;
  final String filter;
  final bool desktop;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onSearch;

  /// 필요한 변수는 검색어·필터·로딩 상태다.
  /// 작동 원리는 한 개 입력과 명시적 검색 버튼으로 요청 수를 제한하고 세 유형 필터는 로컬 결과만 전환하는 것이다.
  @override
  Widget build(BuildContext context) {
    final field = TextField(
      key: const ValueKey('market-search-field'),
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSearch(),
      decoration: InputDecoration(
        hintText: '시험지 · 문제세트 · 코스 · 태그 검색',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: const Color(0xFFF7F7F8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDEDEE1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.black, width: 1.2),
        ),
      ),
    );
    final button = FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF202022),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: loading ? null : onSearch,
      child: Text(loading ? '검색 중' : '검색'),
    );
    final filters = Wrap(
      key: ValueKey(
        desktop ? 'market-desktop-filters' : 'market-mobile-filters',
      ),
      spacing: 8,
      runSpacing: 8,
      children: ['전체', '시험지', '문제세트', '코스', '필터+']
          .map(
            (label) => ChoiceChip(
              label: Text(label),
              selected: filter == label,
              showCheckmark: false,
              selectedColor: Colors.black,
              side: BorderSide(
                color: filter == label ? Colors.black : const Color(0xFFDEDEE1),
              ),
              labelStyle: TextStyle(
                color: filter == label ? Colors.white : Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
              onSelected: (_) => onFilterChanged(label),
            ),
          )
          .toList(growable: false),
    );
    return Container(
      key: ValueKey(
        desktop ? 'market-desktop-search-panel' : 'market-mobile-search-panel',
      ),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E0E2)),
      ),
      child: desktop
          ? Row(
              children: [
                Expanded(child: field),
                const SizedBox(width: 8),
                button,
                const SizedBox(width: 12),
                Flexible(child: filters),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: button),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: filters),
              ],
            ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.items,
    required this.title,
    required this.total,
    required this.onOpen,
  });
  final List<_MarketItem> items;
  final String title;
  final int total;
  final ValueChanged<_MarketItem> onOpen;

  /// 필요한 변수는 최대 세 추천 자료다.
  /// 작동 원리는 HTML의 RECOMMENDED 제목과 구분선 행을 한 카드 안에 구성하는 것이다.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0E0E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RECOMMENDED',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.6,
                        color: Colors.black54,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _CountBadge(count: total),
            ],
          ),
          const SizedBox(height: 18),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('검색 결과가 없습니다.')),
            )
          else
            for (var index = 0; index < items.length; index++) ...[
              _MarketRow(
                item: items[index],
                featured: index == 0,
                onOpen: onOpen,
              ),
              if (index != items.length - 1)
                const Divider(height: 1, color: Color(0xFFE3E3E5)),
            ],
        ],
      ),
    );
  }
}

class _MoreResultsCard extends StatelessWidget {
  const _MoreResultsCard({required this.items, required this.onOpen});
  final List<_MarketItem> items;
  final ValueChanged<_MarketItem> onOpen;

  /// 필요한 변수는 추천 이후의 나머지 자료다.
  /// 작동 원리는 동일한 행 컴포넌트를 재사용해 추가 API 없이 전체 결과를 이어서 표시하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE0E0E2)),
    ),
    child: Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _MarketRow(item: items[index], featured: false, onOpen: onOpen),
          if (index != items.length - 1)
            const Divider(height: 1, color: Color(0xFFE3E3E5)),
        ],
      ],
    ),
  );
}

class _MarketRow extends StatelessWidget {
  const _MarketRow({
    required this.item,
    required this.featured,
    required this.onOpen,
  });
  final _MarketItem item;
  final bool featured;
  final ValueChanged<_MarketItem> onOpen;

  /// 필요한 변수는 자료 정보와 대표 강조 여부다.
  /// 작동 원리는 유형·제목·학습 조건·가격을 서로 다른 시각 계층으로 나누고,
  /// 행 전체를 하나의 큰 클릭 영역으로 제공해 긴 목록에서도 빠르게 훑게 하는 것이다.
  @override
  Widget build(BuildContext context) {
    final foreground = featured ? Colors.white : Colors.black;
    final muted = featured ? Colors.white70 : const Color(0xFF68686D);
    final surface = featured ? Colors.white : const Color(0xFFF5F5F6);
    return Material(
      color: featured ? const Color(0xFF202022) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onOpen(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: featured ? Colors.white : const Color(0xFFE0E0E2),
                  ),
                ),
                child: Icon(
                  item.icon,
                  size: 21,
                  color: featured ? Colors.black : const Color(0xFF303034),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: featured
                                ? Colors.white.withValues(alpha: .16)
                                : const Color(0xFFEDEDEF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.typeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: featured ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            item.pricePoints == 0
                                ? '무료'
                                : '${item.pricePoints}P',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 17,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: featured ? Colors.white : Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '열기',
                  style: TextStyle(
                    color: featured ? Colors.black : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
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

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  /// 필요한 변수는 결과 개수다.
  /// 작동 원리는 작은 회색 캡슐로 현재 추천 행 수를 표시하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F6),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: const Color(0xFFE0E0E2)),
    ),
    child: Text(
      '$count개',
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
    ),
  );
}

class _MarketFilterSheet extends StatefulWidget {
  const _MarketFilterSheet({
    required this.type,
    required this.course,
    required this.price,
  });

  final String type;
  final String course;
  final String price;

  @override
  State<_MarketFilterSheet> createState() => _MarketFilterSheetState();
}

class _MarketFilterSheetState extends State<_MarketFilterSheet> {
  late String _type = widget.type == '필터+' ? '전체' : widget.type;
  late String _course = widget.course;
  late String _price = widget.price;

  /// 필요한 변수는 유형·과정·가격 임시 선택값이다.
  /// 작동 원리는 HTML 필터 모달처럼 세 조건을 독립 칩으로 고르고 적용 시 부모 목록에 한 번 반환한다.
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'MARKET FILTER',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.7,
                color: Colors.black54,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              '마켓 필터',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            const Text(
              '카테고리와 과정, 가격 조건으로 마켓 자료를 좁힙니다.',
              style: TextStyle(color: Colors.black45),
            ),
            const SizedBox(height: 18),
            _FilterGroup(
              label: '카테고리',
              values: const ['전체', '시험지', '문제세트', '코스'],
              selected: _type,
              onSelected: (value) => setState(() => _type = value),
            ),
            _FilterGroup(
              label: '과정',
              values: const ['전체 과정', '고1', '고2', '고3'],
              selected: _course,
              onSelected: (value) => setState(() => _course = value),
            ),
            _FilterGroup(
              label: '가격',
              values: const ['전체 가격', '무료', '유료'],
              selected: _price,
              onSelected: (value) => setState(() => _price = value),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF202022),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () =>
                  Navigator.of(context).pop((_type, _course, _price)),
              child: const Text('필터 적용'),
            ),
          ],
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in values)
              ChoiceChip(
                label: Text(value),
                selected: selected == value,
                showCheckmark: false,
                selectedColor: const Color(0xFF202022),
                labelStyle: TextStyle(
                  color: selected == value ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w800,
                ),
                onSelected: (_) => onSelected(value),
              ),
          ],
        ),
      ],
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
    required this.problemIds,
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
  final List<String> problemIds;
  final bool owned;
  final int progressIndex;
  final bool completed;

  String get typeLabel => switch (type) {
    _MarketItemType.exam => '시험지',
    _MarketItemType.problemSet => '문제세트',
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
    problemIds: problemIds,
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
    final gradeBand = json['grade_band']?.toString() ?? '';
    final difficulty = json['difficulty']?.toString() ?? '';
    final priceLabel = pricePoints == 0 ? '무료' : '${pricePoints}P';
    final details = [
      if (gradeBand.isNotEmpty) gradeBand,
      if (difficulty.isNotEmpty) difficulty,
      if (itemCount > 0) '$itemCount문항',
      priceLabel,
    ].join(' · ');
    return _MarketItem(
      id: json['id']?.toString() ?? '',
      type: type,
      title: json['title']?.toString() ?? '학습 자료',
      description: json['description']?.toString() ?? '',
      subtitle: details.isEmpty
          ? json['description']?.toString() ?? ''
          : details,
      pricePoints: pricePoints,
      itemCount: itemCount,
      problemIds: (json['problem_ids'] is List
          ? (json['problem_ids'] as List)
                .map((id) => id.toString())
                .where((id) => id.isNotEmpty)
                .toList(growable: false)
          : const <String>[]),
      owned: json['owned'] == true,
      progressIndex:
          int.tryParse(json['progress_index']?.toString() ?? '') ?? 0,
      completed: json['status']?.toString() == 'completed',
    );
  }
}

class _MarketplacePreviewSheet extends StatelessWidget {
  const _MarketplacePreviewSheet({
    required this.item,
    required this.problems,
    this.onPurchase,
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
      _MarketItemType.problemSet => '문제세트 미리보기',
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
