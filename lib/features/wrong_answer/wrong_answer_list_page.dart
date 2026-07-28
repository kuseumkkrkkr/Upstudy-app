import 'dart:async';

import 'package:flutter/material.dart';

import 'package:s11/sessions/review_course/review_course.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

/// 필요한 변수는 홈 학습 모달의 Navigator 문맥이다.
/// 작동 원리는 기존 학습 모달을 닫은 뒤 실제 복습 데이터의 요약을 열고, 상세 화면은 오답 목록 라우트로 단일화하는 것이다.
Future<T?> showWrongAnswerReviewPreview<T>({required BuildContext context}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  navigator.pop();
  return showDialog<T>(
    context: navigator.context,
    builder: (_) => const _ReviewPreviewDialog(),
  );
}

class _ReviewPreviewDialog extends StatelessWidget {
  const _ReviewPreviewDialog();

  /// 필요한 변수는 최근 풀이 이력과 누적 약점 태그다.
  /// 작동 원리는 두 API 요청을 함께 조회해 모달에서는 최대 6문제와 최상위 약점만 빠르게 제시하는 것이다.
  Future<List<Object>> _load() => Future.wait<Object>([
    ApiClient.instance.fetchSolveHistory(days: 30, limit: 100, kind: 'problem'),
    ApiClient.instance.fetchWeaknessTags(),
  ]);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        '오늘의 복습',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 390,
        child: FutureBuilder<List<Object>>(
          future: _load(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Text('복습 데이터를 불러오지 못했습니다. 상세 화면에서 다시 시도해 주세요.');
            }
            final history = snapshot.data![0] as List<SolveHistoryItem>;
            final tags = snapshot.data![1] as List<WeaknessTag>;
            final incorrect = history.where(_previewIncorrect).toList();
            final items = incorrect.take(6).toList();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘은 ${items.length}문제만 다시 보면 돼요.',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tags.isEmpty
                      ? '최근 오답을 먼저 복습해 보세요.'
                      : '가장 약한 개념: ${tags.first.tag}',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.replay_rounded, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.questTitleRaw?.trim().isNotEmpty == true
                                ? item.questTitleRaw!
                                : '복습 문제',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (items.isEmpty) const Text('오늘 복습할 것이 없어요.'),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(
              context,
              rootNavigator: true,
            ).pushNamed(WrongAnswerListPage.routeName);
          },
          child: const Text('상세보기'),
        ),
      ],
    );
  }
}

bool _previewIncorrect(SolveHistoryItem item) {
  final data = item.data ?? const <String, dynamic>{};
  final value = data['is_correct'] ?? data['correct'] ?? data['pass'];
  if (value is bool) return !value;
  return const {
    'incorrect',
    'wrong',
    'fail',
  }.contains((data['status'] ?? data['result'] ?? '').toString().toLowerCase());
}

/// HTML 시안의 오늘 복습 우선순위와 약점 요약을 제공하는 화면이다.
class WrongAnswerListPage extends StatefulWidget {
  const WrongAnswerListPage({super.key});

  static const routeName = '/wrong_answers';

  /// 필요한 변수는 필터와 재풀이 상태다.
  /// 화면 내부에서 선택 필터를 유지할 State를 생성한다.
  @override
  State<WrongAnswerListPage> createState() => _WrongAnswerListPageState();
}

class _WrongAnswerListPageState extends State<WrongAnswerListPage> {
  String _filter = '전체';
  bool _latestFirst = true;
  bool _loading = true;
  String? _error;
  List<_ReviewItem> _items = const <_ReviewItem>[];
  List<WeaknessTag> _weaknessTags = const <WeaknessTag>[];

  /// 필요한 변수는 서버 풀이 이력과 약점 태그다.
  /// 작동 원리는 최근 풀이를 문제별로 묶어 오답 횟수·최근 상태를 계산하고, 네트워크 실패는 빈 상태로 격리하는 것이다.
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait<Object>([
        ApiClient.instance.fetchSolveHistory(
          days: 30,
          limit: 200,
          kind: 'problem',
        ),
        ApiClient.instance.fetchWeaknessTags(),
      ]);
      if (!mounted) return;
      final history = result[0] as List<SolveHistoryItem>;
      setState(() {
        _items = _itemsFromHistory(history);
        _weaknessTags = result[1] as List<WeaknessTag>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '복습 데이터를 불러오지 못했습니다.';
        _loading = false;
      });
    }
  }

  /// 필요한 변수는 최신순 풀이 이력이다.
  /// 작동 원리는 같은 문제의 오답 수를 누적하고 마지막 결과가 정답이면 완료 항목으로 표시하는 것이다.
  List<_ReviewItem> _itemsFromHistory(List<SolveHistoryItem> history) {
    final grouped = <String, List<SolveHistoryItem>>{};
    for (final item in history) {
      final key = item.questId?.isNotEmpty == true
          ? 'quest:${item.questId}'
          : 'seed:${item.codebaseId}:${item.seed}';
      if (key == 'seed:null:null') continue;
      grouped.putIfAbsent(key, () => <SolveHistoryItem>[]).add(item);
    }
    final items = <_ReviewItem>[];
    for (final entries in grouped.values) {
      final latest = entries.first;
      final incorrectCount = entries.where(_isIncorrect).length;
      if (incorrectCount == 0) continue;
      final title = latest.questTitleRaw?.trim();
      final tags = latest.hashTags
          .where((tag) => tag.trim().isNotEmpty)
          .toList();
      final done = !_isIncorrect(latest);
      items.add(
        _ReviewItem(
          number: '${items.length + 1}'.padLeft(2, '0'),
          title: title == null || title.isEmpty ? '복습 문제' : title,
          source: '문제 풀이 · ${_dateLabel(latest.createdAt)}',
          reason: done ? '최근 재풀이에서 정답을 맞혀 복습을 완료했어요.' : '최근 풀이에서 오답이었던 문제예요.',
          tags: tags.isEmpty
              ? const ['#복습']
              : tags.map((tag) => tag.startsWith('#') ? tag : '#$tag').toList(),
          attempts: done ? '복습 완료' : '$incorrectCount회 틀림',
          done: done,
        ),
      );
    }
    return items;
  }

  bool _isIncorrect(SolveHistoryItem item) {
    final data = item.data ?? const <String, dynamic>{};
    final value = data['is_correct'] ?? data['correct'] ?? data['pass'];
    if (value is bool) return !value;
    return const {'incorrect', 'wrong', 'fail'}.contains(
      (data['status'] ?? data['result'] ?? '').toString().toLowerCase(),
    );
  }

  String _dateLabel(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return '최근';
    final today = DateTime.now();
    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return '오늘';
    }
    return '${date.month}월 ${date.day}일';
  }

  /// 필요한 변수는 현재 화면 문맥과 선택 문제다.
  /// 실제 이력과 약점 태그로 구성된 기존 복습 코스를 열어 풀이 흐름을 재사용한다.
  void _showReviewAction(String action, _ReviewItem? item) {
    // 복습 코스는 실제 이력·약점 태그로 문제를 구성하고 기존 풀이 화면까지 연결한다.
    unawaited(showReviewCoursePage(context: context));
  }

  /// 필요한 변수는 선택한 필터 이름이다.
  /// 완료 필터만 완료 문항으로 제한하고 나머지는 우선순위 목록을 유지한다.
  List<_ReviewItem> get _visibleItems {
    if (_filter == '완료') return _items.where((item) => item.done).toList();
    if (_filter == '반복 오답') {
      return _items.where((item) => item.incorrectCount >= 2).toList();
    }
    if (_filter == '최근 오답') return _items.where((item) => !item.done).toList();
    final items = List<_ReviewItem>.from(_items);
    return _latestFirst ? items : items.reversed.toList(growable: false);
  }

  /// 필요한 변수는 현재 필터·화면 폭·복습 항목이다.
  /// 공용 셸 아래에 HTML의 페이지 헤더, 검은 복습 히어로, 목록과 약점 카드를 순서대로 배치한다.
  @override
  Widget build(BuildContext context) {
    final pending = _items.where((item) => !item.done).length;
    final completed = _items.where((item) => item.done).length;
    final mobile = isStudentDensityMobile(context);
    return Scaffold(
      key: const ValueKey('wrong-answers-screen'),
      backgroundColor: StudentDensityTokens.background,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (context) => Ios26TopBar(
                brandColor: StudentDensityTokens.dark,
                onMenu: () => Scaffold.of(context).openDrawer(),
                showLevelIndicator: false,
                items: studentTopNavItems(
                  context,
                  active: StudentTopDestination.learning,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: StudentDensityPage(
                  child: mobile
                      ? _MobileReviewContent(
                          loading: _loading,
                          hasLoadError: _error != null,
                          items: _visibleItems,
                          pendingCount: pending,
                          completedCount: completed,
                          weaknessTags: _weaknessTags,
                          filter: _filter,
                          latestFirst: _latestFirst,
                          onFilter: (value) => setState(() => _filter = value),
                          onSort: () =>
                              setState(() => _latestFirst = !_latestFirst),
                          onRetry: _load,
                          onAction: _showReviewAction,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ReviewHeading(
                              onStart: () =>
                                  _showReviewAction('맞춤 복습 시작', null),
                            ),
                            const SizedBox(height: 16),
                            _ReviewHero(
                              pendingCount: pending,
                              completedCount: completed,
                              weaknessTags: _weaknessTags,
                              onStart: () =>
                                  _showReviewAction('6문제 이어서 풀기', null),
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final mobile = constraints.maxWidth <= 780;
                                final list = _loading
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(36),
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    : _ReviewList(
                                        items: _visibleItems,
                                        filter: _filter,
                                        onFilter: (value) =>
                                            setState(() => _filter = value),
                                        latestFirst: _latestFirst,
                                        onSort: () => setState(
                                          () => _latestFirst = !_latestFirst,
                                        ),
                                        onAction: _showReviewAction,
                                      );
                                final side = _WeakPoints(tags: _weaknessTags);
                                if (mobile) {
                                  return Column(
                                    children: [
                                      list,
                                      const SizedBox(height: 14),
                                      side,
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 7, child: list),
                                    const SizedBox(width: 14),
                                    Expanded(flex: 3, child: side),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileReviewContent extends StatelessWidget {
  const _MobileReviewContent({
    required this.loading,
    required this.hasLoadError,
    required this.items,
    required this.pendingCount,
    required this.completedCount,
    required this.weaknessTags,
    required this.filter,
    required this.latestFirst,
    required this.onFilter,
    required this.onSort,
    required this.onRetry,
    required this.onAction,
  });

  final bool loading;
  final bool hasLoadError;
  final List<_ReviewItem> items;
  final int pendingCount;
  final int completedCount;
  final List<WeaknessTag> weaknessTags;
  final String filter;
  final bool latestFirst;
  final ValueChanged<String> onFilter;
  final VoidCallback onSort;
  final VoidCallback onRetry;
  final void Function(String, _ReviewItem?) onAction;

  /// 필요한 변수는 복습 수치·필터·서버 상태·화면 동작 콜백이다.
  /// 작동 원리는 모바일에서 핵심 행동과 문제 목록만 한 열로 보여 주고, 빈 약점 카드처럼 불필요한 정보는 숨기는 것이다.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 8),
      const StudentDensityEyebrow('REVIEW'),
      const SizedBox(height: 8),
      const Text(
        '오늘 복습',
        style: TextStyle(
          color: StudentDensityTokens.ink,
          fontSize: 30,
          height: 1.05,
          letterSpacing: -1.4,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        '틀린 문제 중 지금 다시 볼 것만 모았어요.',
        style: TextStyle(
          color: StudentDensityTokens.muted,
          fontSize: 13,
          height: 1.45,
        ),
      ),
      const SizedBox(height: 20),
      _MobileReviewSummary(
        pendingCount: pendingCount,
        completedCount: completedCount,
        onStart: () => onAction('맞춤 복습 시작', null),
      ),
      if (hasLoadError) ...[
        const SizedBox(height: 10),
        _MobileLoadNotice(onRetry: onRetry),
      ],
      const SizedBox(height: 28),
      Row(
        children: [
          const Expanded(
            child: Text(
              '다시 볼 문제',
              style: TextStyle(
                fontSize: 20,
                letterSpacing: -.6,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            '${items.length}개',
            style: const TextStyle(
              color: StudentDensityTokens.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _MobileReviewFilters(
        filter: filter,
        latestFirst: latestFirst,
        onFilter: onFilter,
        onSort: onSort,
      ),
      const SizedBox(height: 14),
      if (loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 52),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (items.isEmpty)
        const _MobileReviewEmpty()
      else
        for (var index = 0; index < items.length; index++) ...[
          _MobileReviewRow(item: items[index], onAction: onAction),
          if (index != items.length - 1) const SizedBox(height: 10),
        ],
      if (weaknessTags.isNotEmpty) ...[
        const SizedBox(height: 28),
        _MobileWeakPoints(tags: weaknessTags),
      ],
      const SizedBox(height: 32),
    ],
  );
}

class _MobileReviewSummary extends StatelessWidget {
  const _MobileReviewSummary({
    required this.pendingCount,
    required this.completedCount,
    required this.onStart,
  });

  final int pendingCount;
  final int completedCount;
  final VoidCallback onStart;

  /// 필요한 변수는 대기·완료 문제 수와 시작 콜백이다.
  /// 작동 원리는 큰 원형 그래프와 삼단 지표를 제거하고 오늘 할 일과 단일 행동만 압축해 보여 주는 것이다.
  @override
  Widget build(BuildContext context) {
    final hasPending = pendingCount > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: StudentDensityTokens.dark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hasPending ? '오늘 $pendingCount문제' : '오늘 완료',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              if (completedCount > 0)
                Text(
                  '$completedCount문제 완료',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            hasPending ? '$pendingCount문제만 다시 보면 돼요.' : '지금은 복습할 문제가 없어요.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              height: 1.12,
              letterSpacing: -1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasPending ? '최근 오답부터 짧게 끝내보세요.' : '문제를 풀면 틀린 문항이 여기에 자동으로 모여요.',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (hasPending) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Colors.white,
                foregroundColor: StudentDensityTokens.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '복습 시작',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MobileLoadNotice extends StatelessWidget {
  const _MobileLoadNotice({required this.onRetry});

  final VoidCallback onRetry;

  /// 필요한 변수는 API 재요청 콜백이다.
  /// 작동 원리는 별도 오류 카드를 만들지 않고 목록 상단의 작은 상태 행에서 재시도만 제공하는 것이다.
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(
        child: Text(
          '최신 복습 기록을 확인하지 못했어요.',
          style: TextStyle(color: StudentDensityTokens.muted, fontSize: 11),
        ),
      ),
      TextButton(onPressed: onRetry, child: const Text('다시 불러오기')),
    ],
  );
}

class _MobileReviewFilters extends StatelessWidget {
  const _MobileReviewFilters({
    required this.filter,
    required this.latestFirst,
    required this.onFilter,
    required this.onSort,
  });

  final String filter;
  final bool latestFirst;
  final ValueChanged<String> onFilter;
  final VoidCallback onSort;

  /// 필요한 변수는 선택 필터·정렬 상태와 변경 콜백이다.
  /// 작동 원리는 한 줄 가로 스크롤 칩으로 줄바꿈을 막아 세로 공간을 절약하는 것이다.
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final value in const ['전체', '최근 오답', '반복 오답', '완료']) ...[
          ChoiceChip(
            label: Text(value),
            selected: filter == value,
            onSelected: (_) => onFilter(value),
            selectedColor: StudentDensityTokens.dark,
            labelStyle: TextStyle(
              color: filter == value ? Colors.white : StudentDensityTokens.ink,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
            side: const BorderSide(color: StudentDensityTokens.line),
            showCheckmark: false,
          ),
          const SizedBox(width: 6),
        ],
        ActionChip(
          label: Text(latestFirst ? '최신순' : '오래된순'),
          avatar: const Icon(Icons.swap_vert_rounded, size: 16),
          onPressed: onSort,
          side: const BorderSide(color: StudentDensityTokens.line),
        ),
      ],
    ),
  );
}

class _MobileReviewEmpty extends StatelessWidget {
  const _MobileReviewEmpty();

  /// 필요한 변수는 없다.
  /// 작동 원리는 오류처럼 보이는 큰 카드 대신 여백과 짧은 안내로 정상적인 빈 상태를 표현하는 것이다.
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 42, horizontal: 20),
    child: Column(
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          color: StudentDensityTokens.muted,
          size: 32,
        ),
        SizedBox(height: 12),
        Text(
          '지금 다시 볼 문제가 없어요.',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 6),
        Text(
          '새 오답이 생기면 이곳에서 바로 복습할 수 있어요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: StudentDensityTokens.muted, fontSize: 11),
        ),
      ],
    ),
  );
}

class _MobileReviewRow extends StatelessWidget {
  const _MobileReviewRow({required this.item, required this.onAction});

  final _ReviewItem item;
  final void Function(String, _ReviewItem?) onAction;

  /// 필요한 변수는 복습 문제와 풀이 진입 콜백이다.
  /// 작동 원리는 설명·보조 버튼을 줄이고 문제 제목, 오답 횟수, 주 행동만 터치 가능한 한 행에 배치하는 것이다.
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onAction(item.done ? '한 번 더 풀기' : '다시 풀기', item),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: StudentDensityTokens.line),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: StudentDensityTokens.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.number,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${item.attempts} · ${item.source}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StudentDensityTokens.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 22),
          ],
        ),
      ),
    ),
  );
}

class _MobileWeakPoints extends StatelessWidget {
  const _MobileWeakPoints({required this.tags});

  final List<WeaknessTag> tags;

  /// 필요한 변수는 누적 약점 태그다.
  /// 작동 원리는 데이터가 있을 때만 상위 태그를 작은 칩으로 노출해 별도 대형 카드와 빈 안내를 없애는 것이다.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '먼저 볼 개념',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final tag in tags.take(4))
            Chip(
              label: Text(tag.tag),
              backgroundColor: StudentDensityTokens.surfaceMuted,
              side: BorderSide.none,
            ),
        ],
      ),
    ],
  );
}

class _ReviewHeading extends StatelessWidget {
  const _ReviewHeading({required this.onStart});

  final VoidCallback onStart;

  /// 필요한 변수는 맞춤 복습 시작 콜백과 화면 폭이다.
  /// 모바일은 전체 폭 버튼, PC는 제목 우측 버튼을 사용한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    const copy = StudentDensityPageHeader(
      eyebrow: 'REVIEW',
      title: '복습',
      description: '틀린 문제를 쌓아두지 않고, 지금 다시 풀 문제부터 차례로 끝냅니다.',
    );
    final button = FilledButton(
      onPressed: onStart,
      style: FilledButton.styleFrom(
        backgroundColor: StudentDensityTokens.dark,
        minimumSize: Size(mobile ? double.infinity : 112, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: const Text(
        '맞춤 복습 시작',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [copy, const SizedBox(height: 16), button],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(child: copy),
        button,
      ],
    );
  }
}

class _ReviewHero extends StatelessWidget {
  const _ReviewHero({
    required this.onStart,
    required this.pendingCount,
    required this.completedCount,
    required this.weaknessTags,
  });

  final VoidCallback onStart;
  final int pendingCount;
  final int completedCount;
  final List<WeaknessTag> weaknessTags;

  /// 필요한 변수는 복습 시작 콜백과 화면 폭이다.
  /// 오늘 분량·완료 링·주간 지표를 검은 단일 카드 안에 HTML 비율로 배치한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(mobile ? 24 : 28),
      child: Container(
        color: const Color(0xFF1F1F20),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                mobile ? 22 : 34,
                mobile ? 22 : 30,
                mobile ? 18 : 28,
                mobile ? 18 : 24,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const StudentDensityEyebrow(
                          'TODAY’S REVIEW',
                          color: Colors.white54,
                        ),
                        SizedBox(height: mobile ? 26 : 40),
                        Text(
                          '오늘은 ${pendingCount.clamp(0, 6)}문제만\n다시 보면 돼요.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: mobile ? 34 : 52,
                            height: .92,
                            letterSpacing: -2.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (!mobile) ...[
                          const SizedBox(height: 36),
                          const Text(
                            '최근 오답과 반복해서 놓친 개념을 우선순위로 정리했습니다.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: onStart,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: StudentDensityTokens.ink,
                          ),
                          child: const Text(
                            '6문제 이어서 풀기',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ReviewRing(
                    completed: completedCount,
                    total: pendingCount + completedCount,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Row(
              children: [
                Expanded(child: _HeroMetric('복습 대기', '$pendingCount문제')),
                Expanded(child: _HeroMetric('복습 완료', '$completedCount문제')),
                Expanded(
                  child: _HeroMetric(
                    '가장 약한 개념',
                    weaknessTags.isEmpty ? '-' : weaknessTags.first.tag,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewRing extends StatelessWidget {
  const _ReviewRing({required this.completed, required this.total});
  final int completed;
  final int total;

  /// 필요한 변수는 오늘 완료 수 2/8이다.
  /// 원형 진행 테두리 안에 완료 수를 표시한다.
  @override
  Widget build(BuildContext context) => Container(
    width: isStudentDensityMobile(context) ? 82 : 108,
    height: isStudentDensityMobile(context) ? 82 : 108,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white24, width: 8),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$completed',
          style: TextStyle(
            color: Colors.white,
            fontSize: 38,
            height: .9,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          '/ $total 완료',
          style: const TextStyle(color: Colors.white60, fontSize: 8),
        ),
      ],
    ),
  );
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric(this.label, this.value);

  final String label;
  final String value;

  /// 필요한 변수는 히어로 하단 지표 이름과 값이다.
  /// 동일한 3열 셀에 작은 이름과 굵은 값을 표시한다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: Colors.white12)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _ReviewList extends StatelessWidget {
  const _ReviewList({
    required this.items,
    required this.filter,
    required this.onFilter,
    required this.latestFirst,
    required this.onSort,
    required this.onAction,
  });

  final List<_ReviewItem> items;
  final String filter;
  final ValueChanged<String> onFilter;
  final bool latestFirst;
  final VoidCallback onSort;
  final void Function(String, _ReviewItem?) onAction;

  /// 필요한 변수는 복습 목록·선택 필터·행동 콜백이다.
  /// HTML 필터 막대와 우선순위 행을 하나의 흰 카드로 표시한다.
  @override
  Widget build(BuildContext context) {
    const filters = ['전체', '최근 오답', '반복 오답', '완료'];
    return StudentDensitySurface(
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final value in filters)
                ChoiceChip(
                  label: Text(value),
                  selected: filter == value,
                  onSelected: (_) => onFilter(value),
                  selectedColor: StudentDensityTokens.dark,
                  labelStyle: TextStyle(
                    color: filter == value
                        ? Colors.white
                        : StudentDensityTokens.ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                  side: BorderSide.none,
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onSort,
            child: Text(latestFirst ? '최신순 ↕' : '오래된순 ↕'),
          ),
          const Divider(height: 28),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  '오늘 복습할 것이 없어요.',
                  style: TextStyle(color: StudentDensityTokens.muted),
                ),
              ),
            )
          else
            for (var index = 0; index < items.length; index++) ...[
              _ReviewRow(item: items[index], onAction: onAction),
              if (index != items.length - 1) const Divider(height: 28),
            ],
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.item, required this.onAction});

  final _ReviewItem item;
  final void Function(String, _ReviewItem?) onAction;

  /// 필요한 변수는 복습 문제 메타와 행동 콜백이다.
  /// 모바일은 행동을 아래 2열, PC는 우측에 배치한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 58,
          decoration: BoxDecoration(
            color: StudentDensityTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.number,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                item.done ? '완료' : '복습',
                style: const TextStyle(
                  fontSize: 8,
                  color: StudentDensityTokens.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudentDensityEyebrow(item.source),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.attempts,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.reason,
                style: const TextStyle(
                  fontSize: 11,
                  color: StudentDensityTokens.muted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [for (final tag in item.tags) _Tag(tag)],
              ),
            ],
          ),
        ),
        if (!mobile) ...[
          const SizedBox(width: 10),
          _ReviewActions(item: item, onAction: onAction),
        ],
      ],
    );
    if (!mobile) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        body,
        const SizedBox(height: 14),
        _ReviewActions(item: item, onAction: onAction),
      ],
    );
  }
}

class _ReviewActions extends StatelessWidget {
  const _ReviewActions({required this.item, required this.onAction});

  final _ReviewItem item;
  final void Function(String, _ReviewItem?) onAction;

  /// 필요한 변수는 복습 항목·완료 상태·행동 콜백이다.
  /// 해설과 재풀이를 동일 폭 흑백 버튼으로 표시한다.
  @override
  Widget build(BuildContext context) {
    final solution = OutlinedButton(
      onPressed: () => onAction('해설 보기', item),
      child: const Text('해설 보기'),
    );
    final retry = FilledButton(
      onPressed: () => onAction(item.done ? '한 번 더 풀기' : '다시 풀기', item),
      style: FilledButton.styleFrom(backgroundColor: StudentDensityTokens.dark),
      child: Text(item.done ? '한 번 더 풀기' : '다시 풀기'),
    );
    if (isStudentDensityMobile(context)) {
      return Row(
        children: [
          Expanded(child: solution),
          const SizedBox(width: 6),
          Expanded(child: retry),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [solution, const SizedBox(width: 6), retry],
    );
  }
}

class _WeakPoints extends StatelessWidget {
  const _WeakPoints({required this.tags});
  final List<WeaknessTag> tags;

  /// 필요한 변수는 세 약점 이름과 비율이다.
  /// 데스크톱 우측 카드와 모바일 하단 카드에 진행 막대를 표시한다.
  @override
  Widget build(BuildContext context) {
    final maxCount = tags.isEmpty ? 1 : tags.first.count.clamp(1, 999999);
    return StudentDensitySurface(
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StudentDensityEyebrow('WEAK POINTS'),
          const SizedBox(height: 12),
          const Text(
            '먼저 볼 개념',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const Divider(height: 28),
          if (tags.isEmpty)
            const Text(
              '아직 누적된 약점 데이터가 없습니다.',
              style: TextStyle(fontSize: 12, color: StudentDensityTokens.muted),
            )
          else
            for (final tag in tags.take(3))
              _WeakSkill(tag.tag, (tag.count / maxCount * 100).round()),
        ],
      ),
    );
  }
}

class _WeakSkill extends StatelessWidget {
  const _WeakSkill(this.label, this.percent);

  final String label;
  final int percent;

  /// 필요한 변수는 약점 이름과 비율이다.
  /// 이름·퍼센트·검은 진행 막대를 세로로 표시한다.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: percent / 100,
          minHeight: 6,
          color: StudentDensityTokens.dark,
          backgroundColor: StudentDensityTokens.line,
        ),
      ],
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  /// 필요한 변수는 복습 태그 문구다.
  /// 문제 행의 연회색 소형 태그로 표시한다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: StudentDensityTokens.surfaceMuted,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 8, color: StudentDensityTokens.muted),
    ),
  );
}

class _ReviewItem {
  const _ReviewItem({
    required this.number,
    required this.title,
    required this.source,
    required this.reason,
    required this.tags,
    required this.attempts,
    this.done = false,
  });

  final String number;
  final String title;
  final String source;
  final String reason;
  final List<String> tags;
  final String attempts;
  final bool done;
  int get incorrectCount => int.tryParse(attempts.split('회').first) ?? 0;
}
