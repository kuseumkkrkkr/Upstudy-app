import 'package:flutter/material.dart';

import 'package:s11/app/student_route_registry.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/student_facing_api_error.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';

/// HTML group-find: an independent search page, not an invitation dialog.
class GroupFindPage extends StatefulWidget {
  const GroupFindPage({super.key, this.initialGroups});

  /// A verified membership snapshot from the real group hub; null is unknown.
  final List<StudyGroup>? initialGroups;

  @override
  State<GroupFindPage> createState() => _GroupFindPageState();
}

class _GroupFindPageState extends State<GroupFindPage> {
  final _query = TextEditingController();
  final _queryFocus = FocusNode();
  List<StudyGroup>? _mine;
  List<StudyGroup> _results = const [];
  bool _loadingMine = false;
  bool _searching = false;
  bool _searched = false;
  bool _joined = false;
  String? _membershipError;
  String? _searchError;

  bool get _atLimit => _mine != null && _mine!.length >= 3;
  bool get _canSearch =>
      !_loadingMine &&
      _membershipError == null &&
      _mine != null &&
      !_atLimit &&
      !_searching;

  @override
  void initState() {
    super.initState();
    _queryFocus.addListener(_onQueryFocusChanged);
    final initial = widget.initialGroups;
    if (initial != null) {
      _mine = List.of(initial);
    } else {
      _loadMine();
    }
  }

  void _onQueryFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _query.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  Future<void> _loadMine() async {
    if (_loadingMine) return;
    setState(() {
      _loadingMine = true;
      _membershipError = null;
    });
    try {
      final groups = await ApiClient.instance.listStudyGroups();
      if (!mounted) return;
      setState(() {
        _mine = groups;
        _results = _eligible(_results);
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _membershipError = studentFacingApiError(
          error,
          fallback: '내 그룹 정보를 확인하지 못했어요.',
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingMine = false);
    }
  }

  // Presentation filtering only. The authenticated server decides join rights.
  List<StudyGroup> _eligible(List<StudyGroup> groups) {
    final joined = _mine?.map((group) => group.id).toSet() ?? <String>{};
    return groups
        .where(
          (group) =>
              group.isPublic &&
              !group.isTeacherGroup &&
              !joined.contains(group.id),
        )
        .take(10)
        .toList(growable: false);
  }

  Future<void> _search() async {
    if (!_canSearch) return;
    final query = _query.text.trim();
    if (query.isEmpty) {
      _queryFocus.requestFocus();
      return;
    }
    setState(() {
      _searching = true;
      _searched = true;
      _searchError = null;
      _results = const [];
    });
    try {
      final groups = await ApiClient.instance.searchStudyGroups(
        query: query,
        limit: 10,
      );
      if (!mounted) return;
      setState(() => _results = _eligible(groups));
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _searchError = studentFacingApiError(
          error,
          fallback: '그룹을 검색하지 못했어요.',
          unavailable: '그룹 검색 연결이 잠시 불안정해요. 잠시 후 다시 시도해 주세요.',
        ),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _openPreview(StudyGroup group) async {
    if (group.id.trim().isEmpty) {
      setState(() => _searchError = '그룹 식별 정보를 확인하지 못했어요. 다시 검색해 주세요.');
      return;
    }
    final joined = await Navigator.of(context).pushNamed<bool>(
      StudentRouteRegistry.byId('group-join')!.route,
      arguments: group,
    );
    if (!mounted) return;
    _joined = _joined || joined == true;
    await _loadMine();
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(_joined);
    } else {
      navigator.pushReplacementNamed(
        StudentRouteRegistry.byId('groups')!.route,
      );
    }
  }

  Widget _searchForm(BuildContext context, bool compact) => ColoredBox(
    color: Colors.white,
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 8 : 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              key: const ValueKey('group-find-search-box'),
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: _queryFocus.hasFocus
                      ? const Color(0xFF2458D6)
                      : const Color(0xFFCFD3D9),
                ),
              ),
              child: Row(
                children: [
                  const StudentHtmlGlyph(
                    icon: StudentHtmlIcon.pageSearch,
                    color: Color(0xFF111317),
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextField(
                        key: const ValueKey('group-find-query'),
                        controller: _query,
                        focusNode: _queryFocus,
                        maxLength: 80,
                        enabled: !_searching,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black,
                        ),
                        // Non-outline InputDecorator already centers its
                        // 48px interactive container; center would add twice.
                        textAlignVertical: TextAlignVertical.top,
                        onSubmitted: (_) => _search(),
                        onTap: () => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: '그룹 이름',
                          counterText: '',
                          isDense: false,
                          filled: false,
                          constraints: BoxConstraints.tightFor(height: 48),
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: compact ? 72 : 88,
            child: FilledButton(
              key: const ValueKey('group-find-search'),
              onPressed: _canSearch ? _search : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 54),
                visualDensity: VisualDensity.standard,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                backgroundColor: const Color(0xFF111317),
                disabledBackgroundColor: const Color(0xFF111317),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white54,
                shape: const RoundedRectangleBorder(),
                textStyle: Theme.of(context).textTheme.labelLarge!.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              child: _searching
                  ? const SizedBox.square(
                      dimension: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                        semanticsLabel: '그룹 검색 중',
                      ),
                    )
                  : const Text('검색'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _message(
    String title,
    String description, {
    bool searchIcon = false,
  }) => Container(
    constraints: const BoxConstraints(minHeight: 180),
    padding: const EdgeInsets.all(30),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (searchIcon) ...[
          const SizedBox.square(
            dimension: 48,
            child: ColoredBox(
              color: Color(0xFFF3F4F6),
              child: Center(
                child: StudentHtmlGlyph(
                  icon: StudentHtmlIcon.pageSearch,
                  color: Color(0xFF666B73),
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111317),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            height: 19 / 13,
            color: Color(0xFF666B73),
          ),
        ),
      ],
    ),
  );

  Widget _resultsBody(BuildContext context, bool compact) {
    if (_searching)
      return SizedBox(
        height: 180,
        child: Center(
          child: Semantics(
            label: '그룹 검색 중',
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    if (_searchError != null)
      return Semantics(
        liveRegion: true,
        child: Column(
          children: [
            _message('그룹을 검색하지 못했어요.', _searchError!),
            TextButton(onPressed: _search, child: const Text('다시 시도')),
          ],
        ),
      );
    if (!_searched)
      return _message(
        '그룹 이름을 검색해 주세요.',
        '검색 후 참여 가능한 학생 그룹만 보여드려요.',
        searchIcon: true,
      );
    if (_results.isEmpty) return _message('검색 결과가 없어요.', '다른 그룹 이름으로 검색해 주세요.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            height: 34,
            child: Row(
              children: [
                const Text(
                  '검색 결과',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_results.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF666B73),
                  ),
                ),
              ],
            ),
          ),
        ),
        for (var index = 0; index < _results.length; index++)
          _GroupDiscoveryRow(
            group: _results[index],
            index: index,
            compact: compact,
            onConfirm: () => _openPreview(_results[index]),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width <= 600;
    final horizontal = groupSceneHorizontalPadding(width);
    final form = _searchForm(context, compact);
    return StudentHtmlShell(
      key: const ValueKey('group-find-page'),
      title: '공개 그룹 찾기',
      activeRoute: '/groups',
      mobileBackButton: true,
      onMenu: _goBack,
      showHeaderActions: false,
      showBottomNavigation: !compact,
      child: ColoredBox(
        color: compact ? Colors.white : const Color(0xFFF7F7F8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    groupSceneTopPadding(width),
                    horizontal,
                    0,
                  ),
                  sliver: const SliverToBoxAdapter(
                    child: GroupTaskHeading(
                      title: '공개 그룹 찾기',
                      description: '이미 참여한 그룹과 교사 그룹은 제외돼요.',
                    ),
                  ),
                ),
                if (_loadingMine)
                  const SliverToBoxAdapter(
                    child: SizedBox(
                      height: 40,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (_membershipError != null)
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: horizontal),
                    sliver: SliverToBoxAdapter(
                      child: Semantics(
                        liveRegion: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _membershipError!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFB42318),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadMine,
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_atLimit)
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: horizontal),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '현재 그룹을 3개 이용 중이에요.',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('새 그룹에 참여하려면 이용 중인 그룹 수를 먼저 줄여야 해요.'),
                          TextButton(
                            onPressed: _goBack,
                            child: const Text('그룹으로 돌아가기'),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: horizontal),
                    sliver: compact
                        ? SliverPersistentHeader(
                            pinned: true,
                            delegate: _GroupSearchHeader(form),
                          )
                        : SliverToBoxAdapter(child: form),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 0 : horizontal,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        key: const ValueKey('group-find-results'),
                        constraints: const BoxConstraints(minHeight: 280),
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? horizontal : 22,
                          vertical: compact ? 18 : 22,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: compact
                              ? const Border(
                                  top: BorderSide(color: Color(0xFFDFE2E6)),
                                  bottom: BorderSide(color: Color(0xFFDFE2E6)),
                                )
                              : Border.all(color: const Color(0xFFDFE2E6)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [_resultsBody(context, compact)],
                        ),
                      ),
                    ),
                  ),
                ],
                SliverToBoxAdapter(
                  child: SizedBox(height: groupSceneBottomPadding(width)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

double groupSceneHorizontalPadding(double width) => width <= 380
    ? 12
    : width <= 600
    ? 14
    : width <= 820
    ? 20
    : 28;
double groupSceneTopPadding(double width) => width <= 600
    ? 12
    : width <= 820
    ? 20
    : 24;
double groupSceneBottomPadding(double width) => width <= 600
    ? 24
    : width <= 820
    ? 108
    : 48;

/// Shared only by the two real group task pages in this feature.
class GroupTaskHeading extends StatelessWidget {
  const GroupTaskHeading({
    super.key,
    required this.title,
    required this.description,
  });
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 600;
    return Padding(
      padding: EdgeInsets.fromLTRB(0, compact ? 12 : 18, 0, compact ? 16 : 18),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: compact ? 21 : 24,
                  height: 1.2,
                  letterSpacing: -.035 * (compact ? 21 : 24),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111317),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  height: 1.45,
                  color: const Color(0xFF666B73),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupSearchHeader extends SliverPersistentHeaderDelegate {
  _GroupSearchHeader(this.child);
  final Widget child;
  @override
  double get minExtent => 70;
  @override
  double get maxExtent => 70;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;
  @override
  bool shouldRebuild(covariant _GroupSearchHeader oldDelegate) =>
      oldDelegate.child != child;
}

class _GroupDiscoveryRow extends StatelessWidget {
  const _GroupDiscoveryRow({
    required this.group,
    required this.index,
    required this.compact,
    required this.onConfirm,
  });
  final StudyGroup group;
  final int index;
  final bool compact;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: compact ? 44 : 52,
      height: compact ? 44 : 52,
      alignment: Alignment.center,
      color: const Color(0xFFE8EBF1),
      child: Text(
        group.name.isEmpty ? '그' : group.name.substring(0, 1),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        if (group.description?.isNotEmpty == true)
          Text(
            group.description!,
            style: const TextStyle(fontSize: 12, color: Color(0xFF666B73)),
          ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            _GroupStatus(
              '${group.memberCount} / ${group.maxMembers > 0 ? group.maxMembers : '—'}명',
            ),
            _GroupStatus(
              group.lockEnabled ? '비밀번호 필요' : '바로 참여',
              done: !group.lockEnabled,
            ),
          ],
        ),
      ],
    );
    final button = OutlinedButton(
      key: ValueKey('group-find-confirm-${group.id}'),
      onPressed: onConfirm,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 15),
        backgroundColor: const Color(0xFF111317),
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF111317)),
        shape: const RoundedRectangleBorder(),
        textStyle: Theme.of(context).textTheme.labelLarge!.copyWith(
          fontSize: compact ? 16 : 13,
          fontWeight: compact ? FontWeight.w400 : FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      child: const Text('확인'),
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 110),
      padding: EdgeInsets.symmetric(vertical: compact ? 16 : 13),
      decoration: BoxDecoration(
        border: index == 0
            ? null
            : const Border(top: BorderSide(color: Color(0xFFDFE2E6))),
      ),
      child: Row(
        children: [
          logo,
          SizedBox(width: compact ? 10 : 14),
          Expanded(child: copy),
          SizedBox(width: compact ? 10 : 14),
          if (compact) SizedBox(width: 64, child: button) else button,
        ],
      ),
    );
  }
}

class _GroupStatus extends StatelessWidget {
  const _GroupStatus(this.text, {this.done = false});
  final String text;
  final bool done;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 24),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    color: done ? const Color(0xFFEAF5EF) : const Color(0xFFF3F4F6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: done ? const Color(0xFF16754A) : const Color(0xFF666B73),
      ),
    ),
  );
}
