import 'dart:async';

import 'package:flutter/material.dart';

import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
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
  bool _loading = false;
  String? _error;

  /// 필요한 변수는 선택적 미리보기 데이터다.
  /// 작동 원리는 고정 데이터가 있으면 네트워크를 건너뛰고, 실제 화면은 문제·교재를 한 번씩 병렬 조회하는 것이다.
  @override
  void initState() {
    super.initState();
    final initialData = widget.initialData;
    if (initialData != null) {
      _items = initialData.map(_MarketItem.fromMap).toList(growable: false);
    } else {
      unawaited(_search());
    }
  }

  /// 필요한 변수는 검색 컨트롤러다.
  /// 작동 원리는 화면 종료 시 입력 리소스를 해제하는 것이다.
  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  /// 필요한 변수는 검색어와 문제·교재 API다.
  /// 작동 원리는 버튼을 누른 시점에 두 GET을 병렬 실행하고 교재는 클라이언트에서 제목·태그를 한 번 필터링하는 것이다.
  Future<void> _search() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final query = _queryController.text.trim();
    try {
      final results = await Future.wait<Object>([
        ApiClient.instance.searchQuests(
          text: query.isEmpty ? null : query,
          pageSize: 12,
        ),
        ApiClient.instance.listTextbooks(),
      ]);
      final quests = results[0] as List<Map<String, dynamic>>;
      final textbooks = results[1] as List<Map<String, dynamic>>;
      final normalized = query.toLowerCase();
      final items = <_MarketItem>[
        ...quests.map((item) => _MarketItem.fromQuest(item)),
        ...textbooks
            .map((item) => _MarketItem.fromTextbook(item))
            .where(
              (item) =>
                  normalized.isEmpty || item.searchText.contains(normalized),
            ),
      ];
      if (!mounted) return;
      setState(() => _items = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '마켓 자료를 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_MarketItem> get _filteredItems {
    return _items
        .where((item) {
          return switch (_filter) {
            '문제' => item.type == _MarketItemType.quest,
            '교재' => item.type == _MarketItemType.textbook,
            _ => true,
          };
        })
        .where(
          (item) =>
              _courseFilter == '전체 과정' ||
              item.searchText.contains(_courseFilter.toLowerCase()),
        )
        .where((item) {
          if (_priceFilter == '무료') {
            return item.subtitle.contains('무료') || item.subtitle.contains('0P');
          }
          if (_priceFilter == '유료') {
            return !item.subtitle.contains('무료') &&
                !item.subtitle.contains('0P');
          }
          return true;
        })
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
  }

  /// 필요한 변수는 검색 패널이 전달한 기본 필터명이다.
  /// 작동 원리는 필터+만 상세 시트를 열고 나머지 유형은 즉시 로컬 전환한다.
  void _handleFilterChanged(String value) {
    if (value == '필터+') {
      unawaited(_openMarketFilter());
      return;
    }
    setState(() => _filter = value);
  }

  /// 필요한 변수는 현재 항목의 제목·유형·설명·가격이다.
  /// 작동 원리는 상세 버튼에서 같은 데이터를 바텀시트로 확장해 목록 위치를 잃지 않게 하는 것이다.
  void _openItem(_MarketItem item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.typeLabel.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.black45,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                item.subtitle,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('확인'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 필요한 변수는 현재 화면 문맥이다.
  /// 작동 원리는 PC 공용 메뉴에서 마켓을 활성화하고 모바일에서는 같은 AppDrawer를 여는 것이다.
  Widget _buildHeader(BuildContext context) {
    return Ios26TopBar(
      brandColor: Colors.black,
      showLevelIndicator: false,
      onMenu: () => toggleAppDrawer(context),
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

  /// 필요한 변수는 검색·필터·추천 결과 상태다.
  /// 작동 원리는 HTML 마켓의 1280px 검색 한 줄·결과 카드와 780px 이하 단일 열을 같은 데이터·동작으로 재배치하는 것이다.
  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;
    final desktop = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Builder(builder: _buildHeader),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _search,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(desktop ? 40 : 14, 24, desktop ? 40 : 14, 40),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('COMMUNITY', style: TextStyle(fontSize: 10, letterSpacing: 1.7, color: Colors.black54, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            Text('마켓', style: TextStyle(fontSize: desktop ? 50 : 32, letterSpacing: desktop ? -2.4 : -1.4, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            const Text('필요한 문제와 교재를 찾아 내 학습으로 연결합니다.', style: TextStyle(color: Colors.black45)),
                            const SizedBox(height: 28),
                            _SearchPanel(
                              controller: _queryController,
                              loading: _loading,
                              filter: _filter,
                              desktop: desktop,
                              onFilterChanged: _handleFilterChanged,
                              onSearch: _search,
                            ),
                            const SizedBox(height: 12),
                            if (_error != null)
                              Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                            _RecommendationCard(items: items.take(3).toList(), onOpen: _openItem),
                            if (items.length > 3) ...[
                              const SizedBox(height: 12),
                              _MoreResultsCard(items: items.skip(3).toList(), onOpen: _openItem),
                            ],
                          ],
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
        hintText: '문제 · 교재 · 태그 검색',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: const Color(0xFFF7F7F8),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFDEDEE1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.black, width: 1.2)),
      ),
    );
    final button = FilledButton(
      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF202022), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      onPressed: loading ? null : onSearch,
      child: Text(loading ? '검색 중' : '검색'),
    );
    final filters = Wrap(
      key: ValueKey(desktop ? 'market-desktop-filters' : 'market-mobile-filters'),
      spacing: 8,
      runSpacing: 8,
      children: ['전체', '문제', '교재', '필터+'].map((label) => ChoiceChip(label: Text(label), selected: filter == label, showCheckmark: false, selectedColor: Colors.black, side: BorderSide(color: filter == label ? Colors.black : const Color(0xFFDEDEE1)), labelStyle: TextStyle(color: filter == label ? Colors.white : Colors.black, fontSize: 11, fontWeight: FontWeight.w800), onSelected: (_) => onFilterChanged(label))).toList(growable: false),
    );
    return Container(
      key: ValueKey(desktop ? 'market-desktop-search-panel' : 'market-mobile-search-panel'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E0E2)),
      ),
      child: desktop
          ? Row(children: [Expanded(child: field), const SizedBox(width: 8), button, const SizedBox(width: 12), Flexible(child: filters)])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [field, const SizedBox(height: 8), SizedBox(width: double.infinity, child: button), const SizedBox(height: 8), Align(alignment: Alignment.centerLeft, child: filters)]),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.items, required this.onOpen});
  final List<_MarketItem> items;
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RECOMMENDED',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.6,
                        color: Colors.black54,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '중학교 2학년 추천',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _CountBadge(count: items.length),
            ],
          ),
          const SizedBox(height: 28),
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
  /// 작동 원리는 첫 추천만 검은 배경으로 강조하고 나머지는 같은 높이의 흰 행으로 정렬하는 것이다.
  @override
  Widget build(BuildContext context) {
    final foreground = featured ? Colors.white : Colors.black;
    return Material(
      color: featured ? const Color(0xFF202022) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onOpen(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: featured ? Colors.white : const Color(0xFFF5F5F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E2)),
                ),
                child: Icon(item.icon, size: 18, color: Colors.black),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.typeLabel,
                      style: TextStyle(
                        fontSize: 8,
                        color: foreground.withValues(alpha: .5),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        color: foreground.withValues(alpha: .5),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '보기 ›',
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w900,
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
              '카테고리와 과정, 가격 조건으로 문제와 교재를 좁힙니다.',
              style: TextStyle(color: Colors.black45),
            ),
            const SizedBox(height: 18),
            _FilterGroup(
              label: '카테고리',
              values: const ['전체', '문제', '교재'],
              selected: _type,
              onSelected: (value) => setState(() => _type = value),
            ),
            _FilterGroup(
              label: '과정',
              values: const ['전체 과정', '중학교', '고등학교'],
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

enum _MarketItemType { quest, textbook }

class _MarketItem {
  const _MarketItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final _MarketItemType type;
  final String title;
  final String subtitle;

  String get typeLabel => type == _MarketItemType.quest ? '문제' : '교재';
  IconData get icon => type == _MarketItemType.quest
      ? Icons.edit_outlined
      : Icons.menu_book_outlined;
  String get searchText => '$title $subtitle'.toLowerCase();

  /// 필요한 변수는 서버 문제 응답이다.
  /// 작동 원리는 헤더·정보·본문에서 식별자·제목·태그를 안전하게 추출하는 것이다.
  factory _MarketItem.fromQuest(Map<String, dynamic> json) {
    final header = Map<String, dynamic>.from(
      json['header'] as Map? ?? const {},
    );
    final info = Map<String, dynamic>.from(json['info'] as Map? ?? const {});
    final data = Map<String, dynamic>.from(json['data'] as Map? ?? const {});
    final tags = (info['hash_tag'] as List? ?? const []).join(' · ');
    return _MarketItem(
      id: header['quest_id']?.toString() ?? json['quest_id']?.toString() ?? '',
      type: _MarketItemType.quest,
      title:
          data['quest_title']?.toString() ??
          info['title']?.toString() ??
          '수학 문제',
      subtitle: tags.isEmpty ? '문제 자료' : tags,
    );
  }

  /// 필요한 변수는 서버 교재 응답이다.
  /// 작동 원리는 교재 식별자·제목·부제목을 목록 행 모델로 변환하는 것이다.
  factory _MarketItem.fromTextbook(Map<String, dynamic> json) => _MarketItem(
    id: json['textbook_id']?.toString() ?? json['id']?.toString() ?? '',
    type: _MarketItemType.textbook,
    title: json['title']?.toString() ?? '수학 교재',
    subtitle: json['subtitle']?.toString() ?? '교재 자료',
  );

  /// 필요한 변수는 캡처·테스트용 일반 맵이다.
  /// 작동 원리는 type 값에 따라 문제·교재를 구분하고 나머지 표시 필드를 그대로 읽는 것이다.
  factory _MarketItem.fromMap(Map<String, dynamic> json) => _MarketItem(
    id: json['id']?.toString() ?? '',
    type: json['type'] == 'textbook'
        ? _MarketItemType.textbook
        : _MarketItemType.quest,
    title: json['title']?.toString() ?? '학습 자료',
    subtitle: json['subtitle']?.toString() ?? '',
  );
}
