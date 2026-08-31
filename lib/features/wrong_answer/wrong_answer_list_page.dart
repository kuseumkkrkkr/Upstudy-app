import 'dart:async';

import 'package:flutter/material.dart';

import 'package:s11/sessions/review_course/review_course.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

/// 필요한 변수는 홈 학습 모달의 Navigator 문맥이다.
/// 작동 원리는 기존 학습 모달을 닫은 뒤 모바일은 둥근 복습 시트, PC는 기존 대화상자를 연다.
Future<T?> showWrongAnswerReviewPreview<T>({required BuildContext context}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  navigator.pop();
  if (isStudentDensityMobile(navigator.context)) {
    return showModalBottomSheet<T>(
      context: navigator.context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF4F4F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => const FractionallySizedBox(
        heightFactor: .66,
        child: _ReviewPreviewDialog(mobileSheet: true),
      ),
    );
  }
  return showDialog<T>(
    context: navigator.context,
    builder: (_) => const _ReviewPreviewDialog(),
  );
}

class _ReviewPreviewDialog extends StatelessWidget {
  const _ReviewPreviewDialog({this.mobileSheet = false});

  final bool mobileSheet;

  /// 필요한 변수는 최근 풀이 이력과 누적 약점 태그다.
  /// 작동 원리는 두 API 요청을 함께 조회해 모달에서는 최대 6문제와 최상위 약점만 빠르게 제시하는 것이다.
  Future<List<Object>> _load() => Future.wait<Object>([
    ApiClient.instance.fetchSolveHistory(days: 30, limit: 100, kind: 'problem'),
    ApiClient.instance.fetchWeaknessTags(),
  ]);

  @override
  Widget build(BuildContext context) {
    final body = SizedBox(
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
            return const Text(
              '복습 데이터를 불러오지 못했습니다.\n상세 화면에서 다시 시도해 주세요.',
              style: TextStyle(fontSize: 15, height: 1.55),
            );
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
                      const Icon(Icons.replay_rounded, size: 18),
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
    );

    // 필요 변수: 현재 모달 Navigator와 오답 노트 명명 라우트.
    // 작동 원리: 복습 요약을 먼저 닫고 루트 Navigator에서 상세 화면을 한 번만 연다.
    void openDetails() {
      Navigator.of(context).pop();
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamed(WrongAnswerListPage.routeName);
    }

    if (mobileSheet) {
      return Material(
        key: const ValueKey('review-preview-mobile-sheet'),
        color: const Color(0xFFF4F4F6),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '오늘의 복습',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        fixedSize: const Size.square(48),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Material(
                    color: Colors.white,
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(22),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: body,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: openDetails,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    '오답 노트 보기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        '오늘의 복습',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: body,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
        FilledButton(onPressed: openDetails, child: const Text('상세보기')),
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
  ReviewCourseType _selectedPlan = ReviewCourseType.daily;
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
          occurredAt: DateTime.tryParse(latest.createdAt)?.toLocal(),
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

  /// 필요한 변수는 선택한 복습 주기와 실제 오답 이력이다.
  /// 작동 원리는 목록 API가 제공한 마지막 풀이 시각만 사용해 오늘·이번 주·이번 달 범위를
  /// 나누고, 범위 밖 또는 날짜 없는 항목은 계획 수치에 넣지 않는 것이다.
  List<_ReviewItem> _itemsForPlan(ReviewCourseType type) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    return _items
        .where((item) {
          final occurredAt = item.occurredAt;
          if (occurredAt == null) return false;
          final date = DateTime(
            occurredAt.year,
            occurredAt.month,
            occurredAt.day,
          );
          switch (type) {
            case ReviewCourseType.daily:
              return date == today;
            case ReviewCourseType.weekly:
              return !date.isBefore(weekStart) && !date.isAfter(today);
            case ReviewCourseType.monthly:
              return date.year == today.year && date.month == today.month;
            case ReviewCourseType.manual:
              return true;
          }
        })
        .toList(growable: false);
  }

  /// 필요한 변수는 현재 주기·기간 안 실제 오답·약점 태그다.
  /// 작동 원리는 시안의 복습 계획 문구를 유지하되 문제 수·진행률·태그 수를
  /// 서버 이력에서만 계산해 임의의 계획 완료 상태를 만들지 않는 것이다.
  _AtlasReviewPlan _planFor(ReviewCourseType type) {
    final scopedItems = _itemsForPlan(type);
    final pending = scopedItems.where((item) => !item.done).toList();
    final repeated = pending.where((item) => item.incorrectCount >= 2).length;
    final completed = scopedItems.where((item) => item.done).length;
    final total = scopedItems.length;
    final progress = total == 0 ? 0 : (completed / total * 100).round();
    final problemCount = pending.length;
    final minutes = problemCount == 0 ? 0 : (problemCount * 3).clamp(3, 45);
    final topTag = _weaknessTags.isEmpty ? '취약 태그 없음' : _weaknessTags.first.tag;
    final now = DateTime.now();

    switch (type) {
      case ReviewCourseType.daily:
        return _AtlasReviewPlan(
          type: type,
          label: '오늘',
          title: '오늘의 복습 코스',
          due: '오늘 안에',
          meta: '$problemCount문제 · 약 $minutes분',
          progress: progress,
          tasks: [
            _AtlasReviewTask('오늘 오답 다시 풀기', '$problemCount문제', true),
            _AtlasReviewTask('반복 오답 확인', '$repeated문제', true),
            _AtlasReviewTask('취약 태그 요약 보기', topTag, false),
          ],
        );
      case ReviewCourseType.weekly:
        return _AtlasReviewPlan(
          type: type,
          label: '이번 주',
          title: '이번 주 복습 코스',
          due: '이번 주 안에',
          meta: '$problemCount문제 · 약 $minutes분',
          progress: progress,
          tasks: [
            _AtlasReviewTask('주간 오답 다시 풀기', '$problemCount문제', true),
            _AtlasReviewTask('반복 오답 복습', '$repeated문제', true),
            _AtlasReviewTask('취약 태그 확인', topTag, false),
          ],
        );
      case ReviewCourseType.monthly:
        return _AtlasReviewPlan(
          type: type,
          label: '이번 달',
          title: '${now.month}월 다시보기',
          due: '이번 달 안에',
          meta: '$problemCount문제 · 약 $minutes분',
          progress: progress,
          tasks: [
            _AtlasReviewTask('월간 오답 다시 풀기', '$problemCount문제', true),
            _AtlasReviewTask('반복 오답 점검', '$repeated문제', true),
            _AtlasReviewTask('주요 취약 개념 확인', topTag, false),
          ],
        );
      case ReviewCourseType.manual:
        return _AtlasReviewPlan(
          type: type,
          label: '기간 선택',
          title: '기간을 골라 복습 만들기',
          due: '선택 후 7일',
          meta: '$problemCount문제 · 최근 30일 이력',
          progress: progress,
          tasks: [
            _AtlasReviewTask('선택 기간 누적 오답', '$problemCount문제', true),
            _AtlasReviewTask('취약 태그 집중 문제', topTag, true),
            _AtlasReviewTask('반복 오답 점검', '$repeated문제', true),
          ],
        );
    }
  }

  /// 필요한 변수는 현재 필터·화면 폭·복습 항목이다.
  /// 공용 셸 아래에 HTML의 페이지 헤더, 검은 복습 히어로, 목록과 약점 카드를 순서대로 배치한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final plan = _planFor(_selectedPlan);
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
                onMenu: () => toggleAppDrawer(context),
                onTitleTap: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  '/student/dashboard',
                  (route) => false,
                ),
                showLevelIndicator: false,
                showUtilityActions: true,
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
                          weaknessTags: _weaknessTags,
                          filter: _filter,
                          latestFirst: _latestFirst,
                          plan: plan,
                          selectedPlan: _selectedPlan,
                          onFilter: (value) => setState(() => _filter = value),
                          onSort: () =>
                              setState(() => _latestFirst = !_latestFirst),
                          onPlanSelected: (value) =>
                              setState(() => _selectedPlan = value),
                          onRetry: _load,
                          onAction: _showReviewAction,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _AtlasReviewCenter(
                              plan: plan,
                              selectedPlan: _selectedPlan,
                              onPlanSelected: (value) =>
                                  setState(() => _selectedPlan = value),
                              onStart: () =>
                                  _showReviewAction('복습 코스 시작', null),
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

/// 287 Atlas의 복습센터 제어 그룹을 실제 오답 데이터 위에 얹는 공용 표면이다.
/// 모바일과 PC 모두 같은 계획 선택·시작 동작을 사용한다.
class _AtlasReviewCenter extends StatelessWidget {
  const _AtlasReviewCenter({
    required this.plan,
    required this.selectedPlan,
    required this.onPlanSelected,
    required this.onStart,
  });

  final _AtlasReviewPlan plan;
  final ReviewCourseType selectedPlan;
  final ValueChanged<ReviewCourseType> onPlanSelected;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '복습센터',
            key: ValueKey('wrong-answer-atlas-title'),
            style: TextStyle(
              color: StudentDensityTokens.ink,
              fontSize: 34,
              height: 1,
              letterSpacing: -1.8,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '틀린 문제를 기간별 복습 코스로 다시 정리합니다.',
            style: TextStyle(
              color: StudentDensityTokens.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          _AtlasReviewGroup(
            number: '01',
            title: '학습 다시하기',
            description: '복습할 방식을 선택합니다.',
            child: _AtlasReviewAction(
              key: const ValueKey('wrong-answer-start-course'),
              icon: Icons.replay_outlined,
              title: '문제 풀기',
              description: '오답 코스 · 직접 다시 풀기',
              actionLabel: '시작',
              onTap: onStart,
            ),
          ),
          const SizedBox(height: 10),
          _AtlasReviewGroup(
            number: '02',
            title: '복습 정보',
            description: '코스 기간과 실제 복습 분량을 확인합니다.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AtlasCadenceTabs(
                  selected: selectedPlan,
                  onSelected: onPlanSelected,
                ),
                _AtlasPlanPanel(plan: plan, onStart: onStart),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _AtlasReviewGroup extends StatelessWidget {
  const _AtlasReviewGroup({
    required this.number,
    required this.title,
    required this.description,
    required this.child,
  });

  final String number;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: StudentDensityTokens.lineStrong),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  number,
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
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
                        fontSize: 22,
                        height: 1,
                        letterSpacing: -1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      description,
                      style: const TextStyle(
                        color: StudentDensityTokens.muted,
                        fontSize: 11,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: StudentDensityTokens.line),
        child,
      ],
    ),
  );
}

class _AtlasReviewAction extends StatelessWidget {
  const _AtlasReviewAction({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 23),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(
                      color: StudentDensityTokens.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              actionLabel,
              style: const TextStyle(
                color: StudentDensityTokens.muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 18),
          ],
        ),
      ),
    ),
  );
}

class _AtlasCadenceTabs extends StatelessWidget {
  const _AtlasCadenceTabs({required this.selected, required this.onSelected});

  final ReviewCourseType selected;
  final ValueChanged<ReviewCourseType> onSelected;

  @override
  Widget build(BuildContext context) {
    const types = [
      ReviewCourseType.daily,
      ReviewCourseType.weekly,
      ReviewCourseType.monthly,
      ReviewCourseType.manual,
    ];
    return Row(
      children: [
        for (final type in types)
          Expanded(
            child: Semantics(
              selected: selected == type,
              button: true,
              child: Material(
                color: selected == type
                    ? StudentDensityTokens.dark
                    : Colors.white,
                child: InkWell(
                  key: ValueKey('wrong-answer-plan-${type.storageName}'),
                  onTap: () => onSelected(type),
                  child: SizedBox(
                    height: 58,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          switch (type) {
                            ReviewCourseType.daily => '오늘',
                            ReviewCourseType.weekly => '이번 주',
                            ReviewCourseType.monthly => '이번 달',
                            ReviewCourseType.manual => '기간 선택',
                          },
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected == type
                                ? Colors.white
                                : StudentDensityTokens.ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          type.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected == type
                                ? Colors.white70
                                : StudentDensityTokens.muted,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AtlasPlanPanel extends StatelessWidget {
  const _AtlasPlanPanel({required this.plan, required this.onStart});

  final _AtlasReviewPlan plan;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('wrong-answer-plan-panel-${plan.type.storageName}'),
    padding: const EdgeInsets.all(18),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: StudentDensityTokens.line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${plan.type.label} · ${plan.due}',
          style: const TextStyle(
            color: StudentDensityTokens.muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          plan.title,
          style: const TextStyle(
            fontSize: 23,
            height: 1,
            letterSpacing: -1.1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          plan.meta,
          style: const TextStyle(
            color: StudentDensityTokens.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: plan.progress / 100,
                minHeight: 5,
                color: StudentDensityTokens.dark,
                backgroundColor: StudentDensityTokens.surfaceMuted,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${plan.progress}%',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: StudentDensityTokens.line),
          ),
          child: Column(
            children: [
              for (var index = 0; index < plan.tasks.length; index++)
                _AtlasPlanTaskRow(
                  index: index,
                  task: plan.tasks[index],
                  isLast: index == plan.tasks.length - 1,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('wrong-answer-plan-start'),
          onPressed: onStart,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: StudentDensityTokens.dark,
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(),
          ),
          child: Text(
            plan.type == ReviewCourseType.manual ? '기간 선택하기' : '첫 과제 시작 →',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
}

class _AtlasPlanTaskRow extends StatelessWidget {
  const _AtlasPlanTaskRow({
    required this.index,
    required this.task,
    required this.isLast,
  });

  final int index;
  final _AtlasReviewTask task;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      border: isLast
          ? null
          : const Border(bottom: BorderSide(color: StudentDensityTokens.line)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(
            '${index + 1}'.padLeft(2, '0'),
            style: const TextStyle(
              color: StudentDensityTokens.muted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                task.meta,
                style: const TextStyle(
                  color: StudentDensityTokens.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Text(
          task.required ? '필수' : '선택',
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class _MobileReviewContent extends StatelessWidget {
  const _MobileReviewContent({
    required this.loading,
    required this.hasLoadError,
    required this.items,
    required this.weaknessTags,
    required this.filter,
    required this.latestFirst,
    required this.plan,
    required this.selectedPlan,
    required this.onFilter,
    required this.onSort,
    required this.onPlanSelected,
    required this.onRetry,
    required this.onAction,
  });

  final bool loading;
  final bool hasLoadError;
  final List<_ReviewItem> items;
  final List<WeaknessTag> weaknessTags;
  final String filter;
  final bool latestFirst;
  final _AtlasReviewPlan plan;
  final ReviewCourseType selectedPlan;
  final ValueChanged<String> onFilter;
  final VoidCallback onSort;
  final ValueChanged<ReviewCourseType> onPlanSelected;
  final VoidCallback onRetry;
  final void Function(String, _ReviewItem?) onAction;

  /// 필요한 변수는 복습 수치·필터·서버 상태·화면 동작 콜백이다.
  /// 작동 원리는 빈 목록에서는 한 번만 안내하고, 문제가 있을 때만 요약·필터·목록을 차례로 표시한다.
  @override
  Widget build(BuildContext context) {
    final hasItems = items.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _AtlasReviewCenter(
          plan: plan,
          selectedPlan: selectedPlan,
          onPlanSelected: onPlanSelected,
          onStart: () => onAction('복습 코스 시작', null),
        ),
        const SizedBox(height: 24),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 72),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (!hasItems) ...[
          if (hasLoadError) _MobileLoadNotice(onRetry: onRetry),
          const _MobileReviewEmpty(),
        ] else ...[
          if (hasLoadError) ...[
            const SizedBox(height: 10),
            _MobileLoadNotice(onRetry: onRetry),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '다시 풀 문제',
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
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MobileReviewFilters(
            filter: filter,
            latestFirst: latestFirst,
            onFilter: onFilter,
            onSort: onSort,
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < items.length; index++) ...[
            _MobileReviewRow(item: items[index], onAction: onAction),
            if (index != items.length - 1) const SizedBox(height: 8),
          ],
        ],
        if (weaknessTags.isNotEmpty) ...[
          const SizedBox(height: 26),
          _MobileWeakPoints(tags: weaknessTags),
        ],
        const SizedBox(height: 32),
      ],
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
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
            side: BorderSide.none,
            backgroundColor: StudentDensityTokens.surfaceMuted,
            showCheckmark: false,
          ),
          const SizedBox(width: 6),
        ],
        ActionChip(
          label: Text(latestFirst ? '최신순' : '오래된순'),
          avatar: const Icon(Icons.swap_vert_rounded, size: 16),
          onPressed: onSort,
          side: BorderSide.none,
          backgroundColor: StudentDensityTokens.surfaceMuted,
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
    padding: EdgeInsets.symmetric(vertical: 72, horizontal: 24),
    child: Column(
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          color: StudentDensityTokens.muted,
          size: 38,
        ),
        SizedBox(height: 12),
        Text(
          '복습할 문제가 없어요',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 6),
        Text(
          '새 오답이 생기면 여기에 모아둘게요.',
          textAlign: TextAlign.center,
          style: TextStyle(color: StudentDensityTokens.muted, fontSize: 14),
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
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
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
    this.occurredAt,
  });

  final String number;
  final String title;
  final String source;
  final String reason;
  final List<String> tags;
  final String attempts;
  final bool done;
  final DateTime? occurredAt;
  int get incorrectCount => int.tryParse(attempts.split('회').first) ?? 0;
}

class _AtlasReviewPlan {
  const _AtlasReviewPlan({
    required this.type,
    required this.label,
    required this.title,
    required this.due,
    required this.meta,
    required this.progress,
    required this.tasks,
  });

  final ReviewCourseType type;
  final String label;
  final String title;
  final String due;
  final String meta;
  final int progress;
  final List<_AtlasReviewTask> tasks;
}

class _AtlasReviewTask {
  const _AtlasReviewTask(this.title, this.meta, this.required);

  final String title;
  final String meta;
  final bool required;
}
