import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:s11/app/student_route_registry.dart';

import 'package:s11/sessions/review_course/review_course.dart';
import 'package:s11/features/wrong_answer/wrong_answer_solve_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/server_chat_page.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';
import 'package:s11/sessions/tryout_solve/ui/pages/solution_view_page.dart';
import 'package:s11/sessions/tryout_solve/ui/modals/weakness_review_mode.dart';

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
  const WrongAnswerListPage({
    super.key,
    this.initialScene,
    this.reviewSnapshotLoader,
  });

  final String? initialScene;

  /// Tests may supply an isolated snapshot. Production uses the existing store initializer.
  final Future<ReviewCourseSnapshot> Function()? reviewSnapshotLoader;

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
  ReviewCourseSnapshot? _reviewSnapshot;
  bool _reviewLoading = true;
  String? _reviewError;
  int _reviewLoadVersion = 0;
  VoidCallback? _refreshCourseSheet;

  /// 필요한 변수는 서버 풀이 이력과 약점 태그다.
  /// 최근 풀이의 오답·최근 상태와 저장된 복습 계획을 각각 조회한다.
  /// 조회 실패는 오류·재시도로 표시하며 정상 빈 결과와 구분한다.
  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_loadReviewSnapshot());
    if (widget.initialScene == 'weakness-review') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(showWeaknessReviewModal<void>(context: context));
      });
    }
  }

  @override
  void dispose() {
    _reviewLoadVersion++;
    _refreshCourseSheet = null;
    super.dispose();
  }

  /// Reads the existing course/stats snapshot without fabricating missing plans.
  Future<void> _loadReviewSnapshot() async {
    final version = ++_reviewLoadVersion;
    setState(() {
      _reviewLoading = true;
      _reviewError = null;
    });
    _refreshCourseSheet?.call();
    try {
      final loader =
          widget.reviewSnapshotLoader ??
          ReviewCourseStore.instance.generateMissingCourses;
      final snapshot = await loader();
      if (!mounted || version != _reviewLoadVersion) return;
      setState(() => _reviewSnapshot = snapshot);
    } catch (_) {
      if (!mounted || version != _reviewLoadVersion) return;
      setState(() => _reviewError = '복습 계획과 통계를 불러오지 못했습니다.');
    } finally {
      if (mounted && version == _reviewLoadVersion) {
        setState(() => _reviewLoading = false);
        _refreshCourseSheet?.call();
      }
    }
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
          questId: latest.questId,
          incorrectAttempts: incorrectCount,
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
    // 실제 이력·약점 태그를 기반으로 한 풀이 위젯으로 진입한다.
    final source = action.contains('습관') ? 'habit' : 'weakness';
    unawaited(
      Navigator.of(
        context,
      ).pushNamed('${WrongAnswerSolvePage.routeName}?source=$source'),
    );
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

  /// 실제 snapshot의 해당 기간 course/tasks를 표시 데이터로 투영한다.
  /// 진도는 실제 필수 task 완료비율이며 문항수는 저장된 목표수합이다.
  /// 조회된 문제수나 서버권위 완료를 뜻하지 않으며 없는 record를 만들지 않는다.
  _AtlasReviewPlan _planFor(ReviewCourseType type) {
    ReviewCourse? course;
    for (final candidate
        in _reviewSnapshot?.visibleCourses ?? const <ReviewCourse>[]) {
      if (candidate.type == type && candidate.id.isNotEmpty) {
        course = candidate;
        break;
      }
    }
    if (course == null) {
      return _AtlasReviewPlan(
        type: type,
        label: type.label,
        title: '생성된 복습 코스가 없습니다.',
        due: '',
        meta: '실제 코스를 선택해 주세요.',
        progress: 0,
        problemCount: 0,
        tasks: const [],
      );
    }
    final requiredCount = course.requiredCount;
    final progress = requiredCount == 0
        ? 0
        : (course.completedRequiredCount / requiredCount * 100).round();
    final plannedQuestions = course.tasks
        .where((task) => task.isProblemTask)
        .fold<int>(0, (sum, task) => sum + task.targetQuestionCount);
    return _AtlasReviewPlan(
      type: type,
      label: type.label,
      title: course.title,
      due: course.dueDateKey,
      meta: '$plannedQuestions문제 · 약 ${course.estimatedMinutes}분',
      progress: progress,
      problemCount: plannedQuestions,
      sourceCourse: course,
      tasks: course.tasks
          .map(_AtlasReviewTask.fromTask)
          .toList(growable: false),
    );
  }

  Future<void> _openStoredCourse(_AtlasReviewPlan plan) async {
    final course = plan.sourceCourse;
    ReviewTask? first;
    if (course != null && plan.type != ReviewCourseType.manual) {
      for (final task in course.tasks) {
        if (task.required && !task.completed && task.id.isNotEmpty) {
          first = task;
          break;
        }
      }
      if (first == null) return;
    }
    final base = Uri.parse(StudentRouteRegistry.byId('review-course')!.route);
    final destination = base.replace(
      queryParameters: plan.type == ReviewCourseType.manual
          ? {'start_manual': '1'}
          : {'course_id': course!.id, 'task_id': first!.id},
    );
    await Navigator.of(context).pushNamed(destination.toString());
    if (mounted) {
      await _loadReviewSnapshot();
      await _load();
    }
  }

  Future<void> _openCenterSheet(String scene) async {
    if (scene == 'tutor' || scene == 'blank') {
      return _openMethodSheet(scene);
    }
    if (scene == 'course')
      setState(() => _selectedPlan = ReviewCourseType.daily);
    _ReviewItem? selectedItem;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFDFDFE),
      barrierColor: Colors.black.withValues(alpha: .52),
      shape: const RoundedRectangleBorder(),
      constraints: const BoxConstraints(maxWidth: 620),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, updateSheet) {
          Future<void> reloadSheet() async {
            final request = scene == 'course' ? _loadReviewSnapshot() : _load();
            updateSheet(() {});
            await request;
            if (sheetContext.mounted) updateSheet(() {});
          }

          final mobile = isStudentDensityMobile(sheetContext);
          if (scene == 'course')
            _refreshCourseSheet = () {
              if (sheetContext.mounted) updateSheet(() {});
            };
          final title = selectedItem != null
              ? '문제 상세'
              : switch (scene) {
                  'course' => '복습 코스',
                  'queue' => '다시 볼 문제',
                  _ => '학습 현황',
                };
          final content = switch (scene) {
            'queue' =>
              selectedItem == null
                  ? _ReviewQueueSheet(
                      items: _items,
                      loading: _loading,
                      hasError: _error != null,
                      onRetry: reloadSheet,
                      onSelect: (item) =>
                          updateSheet(() => selectedItem = item),
                    )
                  : _ReviewProblemDetail(
                      item: selectedItem!,
                      onSolution: () {
                        final item = selectedItem!;
                        Navigator.pop(sheetContext);
                        unawaited(_showSolution(item));
                      },
                      onRetry: () {
                        final item = selectedItem!;
                        Navigator.pop(sheetContext);
                        _showReviewAction('다시 풀기', item);
                      },
                    ),
            'summary' => _ReviewSummarySheet(
              items: _items,
              weaknessTags: _weaknessTags,
              loading: _loading,
              hasError: _error != null,
              onRetry: reloadSheet,
            ),
            _ => Column(
              children: [
                _AtlasCadenceTabs(
                  selected: _selectedPlan,
                  onSelected: (value) {
                    setState(() => _selectedPlan = value);
                    updateSheet(() {});
                  },
                ),
                _AtlasPlanPanel(
                  plan: _planFor(_selectedPlan),
                  loading: _reviewLoading,
                  hasError: _reviewError != null,
                  onRetry: reloadSheet,
                  onStart: () {
                    final plan = _planFor(_selectedPlan);
                    Navigator.pop(sheetContext);
                    unawaited(_openStoredCourse(plan));
                  },
                ),
              ],
            ),
          };
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 620,
              maxHeight: math.min(
                760,
                MediaQuery.sizeOf(sheetContext).height * (mobile ? .86 : .88),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(top: 9, bottom: 3),
                  color: const Color(0x3309090B),
                ),
                Container(
                  height: 56,
                  padding: const EdgeInsets.fromLTRB(18, 0, 14, 0),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0x1A09090B)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            side: const BorderSide(color: Color(0x1A09090B)),
                            shape: const RoundedRectangleBorder(),
                          ),
                          child: const Tooltip(
                            message: '닫기',
                            child: Text(
                              '×',
                              style: TextStyle(
                                fontSize: 22,
                                color: Color(0xFF09090B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        mobile ? 12 : 18,
                        mobile ? 14 : 16,
                        mobile ? 12 : 18,
                        mobile ? 18 : 20,
                      ),
                      child: content,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (scene == 'course') _refreshCourseSheet = null;
  }

  Future<void> _showSolution(_ReviewItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SolutionViewPage(
          initialQuestId: item.questId,
          initialTextQuery: item.questId == null ? item.title : null,
          autoSearch: true,
        ),
      ),
    );
  }

  /// 내용 높이에 맞춰 HTML 학습 방법 시트를 연다. 짧은 화면은 내부 스크롤한다.
  Future<void> _openMethodSheet(String scene) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFDFDFE),
    barrierColor: Colors.black.withValues(alpha: .52),
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints(maxWidth: 620),
    builder: (sheetContext) {
      final mobile = isStudentDensityMobile(sheetContext);
      final tutor = scene == 'tutor';
      void openTool() {
        Navigator.pop(sheetContext);
        if (tutor) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/review/socratic'),
              builder: (_) => const ServerChatPage(
                standalone: true,
                ephemeral: true,
                initialMode: 'socratic',
                initialPrompt:
                    'Socratic 방식으로 복습을 진행해 주세요. 정답이나 완성 풀이를 먼저 알려주지 말고, 한 번에 질문 하나만 해주세요. 제가 답하면 그 답에서 맞는 점과 빠진 점을 짚고 다음 질문을 이어가 주세요. 제가 막힐 때만 작은 힌트를 주세요.',
              ),
            ),
          );
          return;
        }
        Navigator.of(context).pushNamed('/learning-tools?scene=notepad');
      }

      final lines = tutor
          ? ['조건을 자꾸 놓치는 이유 찾기', '취약 개념을 질문으로 확인하기', '내 풀이를 말로 설명하기']
          : ['핵심 개념을 한 문장으로 쓰기', '풀이 순서를 기억해서 적기', '틀렸던 이유를 직접 설명하기'];
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.sizeOf(sheetContext).height * (mobile ? .86 : .88),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(top: 9, bottom: 3),
                color: const Color(0x3309090B),
              ),
              Container(
                height: 56,
                padding: const EdgeInsets.fromLTRB(18, 0, 14, 0),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0x1A09090B))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tutor ? 'Socratic 복습' : '백지 복습',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: const BorderSide(color: Color(0x1A09090B)),
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: const Tooltip(
                          message: '닫기',
                          child: Text(
                            '×',
                            style: TextStyle(
                              fontSize: 22,
                              color: Color(0xFF09090B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  mobile ? 12 : 18,
                  mobile ? 14 : 16,
                  mobile ? 12 : 18,
                  mobile ? 18 : 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3F3F5),
                        border: Border(
                          left: BorderSide(color: Color(0xFF09090B), width: 6),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            tutor ? 'Socratic 복습' : '백지 복습',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF71717A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tutor
                                ? '정답 대신 질문을 따라가며 이해해요.'
                                : '보지 않고 꺼내 쓸수록 오래 기억해요.',
                            style: TextStyle(
                              fontSize: 21,
                              letterSpacing: 0,
                              height: tutor ? null : 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: tutor ? 16 : 18),
                          for (var i = 0; i < lines.length; i++) ...[
                            if (i > 0) const SizedBox(height: 1),
                            Material(
                              color: const Color(0xFFFDFDFE),
                              child: InkWell(
                                onTap: tutor ? openTool : null,
                                child: Container(
                                  height: 46,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      if (!tutor) ...[
                                        Text(
                                          '0${i + 1}',
                                          style: const TextStyle(
                                            fontSize: 8,
                                            color: Color(0xFF71717A),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      Expanded(
                                        child: Text(
                                          lines[i],
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: TextButton(
                        onPressed: openTool,
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF09090B),
                          foregroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(),
                          textStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        child: Text(tutor ? 'Socratic 복습 시작 →' : '백지 노트 열기 →'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  /// 필요한 변수는 현재 필터·화면 폭·복습 항목이다.
  /// 공용 셸 아래에 HTML의 페이지 헤더, 검은 복습 히어로, 목록과 약점 카드를 순서대로 배치한다.
  @override
  Widget build(BuildContext context) {
    final plan = _planFor(ReviewCourseType.daily);
    return StudentHtmlShell(
      key: const ValueKey('wrong-answers-screen'),
      title: '복습센터',
      activeRoute: '/wrong_answers',
      showContextAside: false,
      mobileBackButton: true,
      onMenu: () =>
          Navigator.of(context).pushReplacementNamed('/student/dashboard'),
      onSearch: () => showStudentQuickSearch(context),
      onNotifications: () => showStudentNotifications(context),
      child: SingleChildScrollView(
        child: _ReviewCenterMenu(
          plan: plan,
          loading: _loading,
          hasError: _error != null,
          planLoading: _reviewLoading,
          planHasError: _reviewError != null,
          pending: _items.where((item) => !item.done).length,
          weaknesses: _weaknessTags.length,
          onOpen: _openCenterSheet,
        ),
      ),
    );
  }
}

/// 287 Atlas의 복습센터 제어 그룹을 실제 오답 데이터 위에 얹는 공용 표면이다.
/// 모바일과 PC 모두 같은 계획 선택·시작 동작을 사용한다.
class _ReviewCenterMenu extends StatelessWidget {
  const _ReviewCenterMenu({
    required this.plan,
    required this.loading,
    required this.hasError,
    required this.planLoading,
    required this.planHasError,
    required this.pending,
    required this.weaknesses,
    required this.onOpen,
  });
  final _AtlasReviewPlan plan;
  final bool loading;
  final bool hasError;
  final bool planLoading;
  final bool planHasError;
  final int pending;
  final int weaknesses;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    Widget group(
      String number,
      String title,
      String description,
      List<(IconData, String, String, String)> items,
    ) => Container(
      padding: EdgeInsets.fromLTRB(
        mobile ? 18 : 34,
        mobile ? 24 : 30,
        mobile ? 18 : 34,
        mobile ? 22 : 28,
      ),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Color(0x3309090B)),
          bottom: BorderSide(color: Color(0x3309090B)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mobile) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  number,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 8),
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: Color(0xFF71717A),
                ),
              ),
            ),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      description,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: Color(0xFF71717A),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          SizedBox(height: mobile ? 20 : 24),
          for (final item in items)
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x1A09090B))),
              ),
              child: InkWell(
                key: ValueKey('review-center-${item.$4}-${item.$2}'),
                onTap: () => onOpen(item.$4),
                child: SizedBox(
                  height: mobile ? 78 : 82,
                  child: Row(
                    children: [
                      Icon(item.$1, size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$2,
                              style: TextStyle(
                                fontSize: mobile ? 13 : 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.$3,
                              style: TextStyle(
                                fontSize: mobile ? 9 : 10,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF71717A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!mobile)
                        const Text(
                          '보기',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF71717A),
                          ),
                        ),
                      const SizedBox(width: 14),
                      const Text(
                        '→',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 0 : 18,
        vertical: mobile ? 0 : 22,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFDFDFE),
              border: Border(
                top: BorderSide(color: Color(0xFF09090B)),
                right: BorderSide(color: Color(0xFF09090B)),
              ),
            ),
            child: Column(
              children: [
                group('01', '학습 다시하기', '복습할 방식을 선택합니다.', [
                  (
                    Icons.replay_outlined,
                    '문제 풀기',
                    '오답 코스 · 직접 다시 풀기',
                    'course',
                  ),
                  (
                    Icons.auto_awesome_outlined,
                    'Socratic 복습',
                    'AI 질문 · 풀이 과정을 말로 설명',
                    'tutor',
                  ),
                  (Icons.edit_note, '백지 복습', '노트패드 · 기억에서 꺼내 쓰기', 'blank'),
                ]),
                group('02', '복습 정보', '코스, 문제와 학습 현황을 확인합니다.', [
                  (
                    Icons.menu_book_outlined,
                    '오늘의 복습 코스',
                    planLoading
                        ? '불러오는 중'
                        : planHasError
                        ? '복습 데이터를 불러오지 못했습니다.'
                        : plan.sourceCourse == null
                        ? plan.title
                        : '${plan.meta} · 진행 ${plan.progress}%',
                    'course',
                  ),
                  (
                    Icons.list_alt,
                    '다시 볼 문제',
                    loading
                        ? '불러오는 중'
                        : hasError
                        ? '다시 시도 필요'
                        : '대기 $pending',
                    'queue',
                  ),
                  (
                    Icons.bar_chart,
                    '학습 현황',
                    loading
                        ? '불러오는 중'
                        : hasError
                        ? '다시 시도 필요'
                        : '자주 놓친 개념 $weaknesses개',
                    'summary',
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewQueueSheet extends StatefulWidget {
  const _ReviewQueueSheet({
    required this.items,
    required this.loading,
    required this.hasError,
    required this.onRetry,
    required this.onSelect,
  });

  final List<_ReviewItem> items;
  final bool loading;
  final bool hasError;
  final VoidCallback onRetry;
  final ValueChanged<_ReviewItem> onSelect;

  @override
  State<_ReviewQueueSheet> createState() => _ReviewQueueSheetState();
}

class _ReviewQueueSheetState extends State<_ReviewQueueSheet> {
  String _filter = 'pending';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final query = _query.trim().toLowerCase();
    final items = widget.items
        .where((item) {
          final matchesState = switch (_filter) {
            'recurring' => !item.done && item.incorrectCount >= 2,
            'complete' => item.done,
            _ => !item.done,
          };
          final matchesQuery =
              query.isEmpty ||
              '${item.title} ${item.source} ${item.tags.join(' ')}'
                  .toLowerCase()
                  .contains(query);
          return matchesState && matchesQuery;
        })
        .toList(growable: false);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFE),
        border: Border.all(color: const Color(0x1A09090B)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: mobile ? 52 : 56),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0x1A09090B))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '다시 볼 문제',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: mobile
                        ? 112
                        : math.min(
                            190,
                            (MediaQuery.sizeOf(context).width.clamp(0, 620) -
                                    38) *
                                .4,
                          ),
                    height: 34,
                    child: TextField(
                      key: const ValueKey('review-queue-search'),
                      onChanged: (value) => setState(() => _query = value),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: const InputDecoration(
                        hintText: '문제 검색',
                        hintStyle: TextStyle(fontSize: 9),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                        filled: true,
                        fillColor: Color(0xFFF3F3F5),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: Color(0x1A09090B)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: Color(0x3309090B)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x1A09090B))),
            ),
            child: Row(
              children: [
                for (final entry in const [
                  ('pending', '복습 대기'),
                  ('recurring', '반복 오답'),
                  ('complete', '완료'),
                ])
                  Expanded(
                    child: Semantics(
                      selected: _filter == entry.$1,
                      button: true,
                      child: InkWell(
                        key: ValueKey('review-queue-filter-${entry.$1}'),
                        onTap: () => setState(() => _filter = entry.$1),
                        child: Container(
                          height: mobile ? 42 : 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDFDFE),
                            border: Border(
                              right: entry.$1 == 'complete'
                                  ? BorderSide.none
                                  : const BorderSide(color: Color(0x1A09090B)),
                              bottom: BorderSide(
                                color: _filter == entry.$1
                                    ? const Color(0xFF09090B)
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Text(
                            entry.$2,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: _filter == entry.$1
                                  ? const Color(0xFF09090B)
                                  : const Color(0xFF71717A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.loading)
            const Padding(
              padding: EdgeInsets.all(36),
              child: CircularProgressIndicator(),
            )
          else if (widget.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '복습 데이터를 불러오지 못했습니다.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF71717A)),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onRetry,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            )
          else if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 52),
              child: Text(
                '조건에 맞는 문제가 없습니다.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF71717A),
                ),
              ),
            )
          else
            for (final item in items)
              _ReviewQueueRow(item: item, onTap: () => widget.onSelect(item)),
        ],
      ),
    );
  }
}

class _ReviewQueueRow extends StatelessWidget {
  const _ReviewQueueRow({required this.item, required this.onTap});

  final _ReviewItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final repeated = !item.done && item.incorrectCount >= 2;
    final state = item.done
        ? '완료'
        : repeated
        ? '반복'
        : '복습';
    return Material(
      color: const Color(0xFFFDFDFE),
      child: InkWell(
        key: ValueKey('review-queue-row-${item.questId ?? item.title}'),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: mobile ? 64 : 68),
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? 10 : 14,
            vertical: mobile ? 9 : 8,
          ),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x1A09090B))),
          ),
          child: Opacity(
            opacity: item.done ? .5 : 1,
            child: Row(
              children: [
                Container(
                  width: mobile ? 4 : 5,
                  height: mobile ? 26 : 30,
                  color: repeated
                      ? const Color(0xFF09090B)
                      : const Color(0x1A09090B),
                ),
                SizedBox(width: mobile ? 10 : 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: mobile ? 12 : 13,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.done
                            ? '복습 완료'
                            : '${item.incorrectCount}회 오답${repeated ? ' · 반복' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF71717A),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: mobile ? 10 : 12),
                SizedBox(
                  width: mobile ? 40 : 44,
                  child: Text(
                    state,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: mobile ? 8 : 9,
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
}

class _ReviewProblemDetail extends StatelessWidget {
  const _ReviewProblemDetail({
    required this.item,
    required this.onSolution,
    required this.onRetry,
  });

  final _ReviewItem item;
  final VoidCallback onSolution;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final state = item.done
        ? '복습 완료'
        : item.incorrectCount >= 2
        ? '반복 오답'
        : '복습 대기';
    final last = item.source.replaceFirst('문제 풀이 · ', '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF71717A),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              item.tags.isEmpty ? '문제 풀이 기록' : item.tags.join(' · '),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0xFF71717A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x1A09090B)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _ReviewFact(
                  label: '누적 오답',
                  value: '${item.incorrectCount}회',
                ),
              ),
              Container(width: 1, height: 58, color: const Color(0x1A09090B)),
              Expanded(
                child: _ReviewFact(label: '마지막 풀이', value: last),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(color: Color(0xFFF3F3F5)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '선정 이유',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF71717A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.reason,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (item.tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.tags.join(' · '),
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF71717A),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onSolution,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: const RoundedRectangleBorder(),
                  side: const BorderSide(color: Color(0xFF09090B)),
                  foregroundColor: const Color(0xFF09090B),
                ),
                child: const Text(
                  '해설 보기',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: const Color(0xFF09090B),
                  shape: const RoundedRectangleBorder(),
                ),
                child: const Text(
                  '다시 풀기 →',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewFact extends StatelessWidget {
  const _ReviewFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: Color(0xFF71717A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class _ReviewSummarySheet extends StatelessWidget {
  const _ReviewSummarySheet({
    required this.items,
    required this.weaknessTags,
    required this.loading,
    required this.hasError,
    required this.onRetry,
  });

  final List<_ReviewItem> items;
  final List<WeaknessTag> weaknessTags;
  final bool loading;
  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final weekStart = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    final pending = items.where((item) => !item.done).length;
    final resolved = items
        .where(
          (item) =>
              item.done &&
              item.occurredAt != null &&
              !item.occurredAt!.isBefore(weekStart),
        )
        .length;
    final maxCount = weaknessTags.isEmpty
        ? 1
        : weaknessTags.first.count.clamp(1, 999999);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFE),
        border: Border.all(color: const Color(0x1A09090B)),
      ),
      child: Column(
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x1A09090B))),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    '이번 주 요약',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '복습 정보',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF71717A),
                  ),
                ),
              ],
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(36),
              child: CircularProgressIndicator(),
            )
          else if (hasError)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const Text('복습 데이터를 불러오지 못했습니다.'),
                  TextButton(onPressed: onRetry, child: const Text('다시 시도')),
                ],
              ),
            )
          else ...[
            Row(
              children: [
                _ReviewSummaryMetric(value: '$pending', label: '대기'),
                _ReviewSummaryMetric(value: '$resolved', label: '해결'),
                const _ReviewSummaryMetric(value: '—', label: '연속'),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          '코스 완료 기준',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF71717A),
                          ),
                        ),
                      ),
                      Text(
                        '80%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(
                    value: .8,
                    minHeight: 4,
                    color: Color(0xFF09090B),
                    backgroundColor: Color(0x1A09090B),
                  ),
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFF0F0F2), width: 8),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0x1A09090B)),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Text(
                            '자주 놓친 개념',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '누적',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF71717A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (weaknessTags.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(22),
                      child: Text(
                        '표시할 취약 태그가 없습니다.',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF71717A),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                      child: Column(
                        children: [
                          for (var i = 0; i < weaknessTags.length; i++)
                            _ReviewWeaknessRow(
                              tag: weaknessTags[i],
                              maxCount: maxCount,
                              last: i == weaknessTags.length - 1,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewSummaryMetric extends StatelessWidget {
  const _ReviewSummaryMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0x1A09090B))),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: Color(0xFF71717A),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReviewWeaknessRow extends StatelessWidget {
  const _ReviewWeaknessRow({
    required this.tag,
    required this.maxCount,
    required this.last,
  });

  final WeaknessTag tag;
  final int maxCount;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 46),
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: Color(0x1A09090B))),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 82,
          child: Text(
            tag.tag,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: LinearProgressIndicator(
            value: tag.count / maxCount,
            minHeight: 4,
            color: const Color(0xFF09090B),
            backgroundColor: const Color(0x1A09090B),
          ),
        ),
        const SizedBox(width: 9),
        SizedBox(
          width: 18,
          child: Text(
            '${tag.count}',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
}

class _ReviewPlanAccuracyGate extends StatelessWidget {
  const _ReviewPlanAccuracyGate({required this.requiredAccuracy});

  final int requiredAccuracy;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      '필수 문제 과제는 정답률 $requiredAccuracy% 이상이어야 완료됩니다.',
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: Color(0xFF71717A),
      ),
    ),
  );
}

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
    final mobile = isStudentDensityMobile(context);
    return Container(
      key: const ValueKey('review-course-cadence-tabs'),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x1A09090B)),
      ),
      child: Row(
        children: [
          for (final type in types)
            Expanded(
              child: Semantics(
                selected: selected == type,
                button: true,
                child: Material(
                  color: selected == type
                      ? const Color(0xFF09090B)
                      : const Color(0xFFFDFDFE),
                  child: InkWell(
                    key: ValueKey('wrong-answer-plan-${type.storageName}'),
                    onTap: () => onSelected(type),
                    child: Container(
                      height: mobile ? 50 : 54,
                      decoration: BoxDecoration(
                        border: Border(
                          right: type == ReviewCourseType.manual
                              ? BorderSide.none
                              : const BorderSide(color: Color(0x1A09090B)),
                        ),
                      ),
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
                                  : StudentDensityTokens.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (!mobile) ...[
                            const SizedBox(height: 3),
                            Text(
                              type.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected == type
                                    ? Colors.white
                                    : StudentDensityTokens.muted,
                                fontSize: 7,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AtlasPlanPanel extends StatelessWidget {
  const _AtlasPlanPanel({
    required this.plan,
    required this.onStart,
    this.loading = false,
    this.hasError = false,
    this.onRetry,
  });
  final _AtlasReviewPlan plan;
  final VoidCallback onStart;
  final bool loading;
  final bool hasError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    if (loading)
      return const Padding(
        padding: EdgeInsets.all(36),
        child: Center(child: CircularProgressIndicator()),
      );
    if (hasError)
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Text(
              '복습 데이터를 불러오지 못했습니다.',
              style: TextStyle(fontSize: 11, color: Color(0xFF71717A)),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      );
    if (plan.sourceCourse == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              plan.title,
              key: const ValueKey('review-course-empty'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF71717A)),
            ),
            const SizedBox(height: 18),
            TextButton(
              key: const ValueKey('wrong-answer-plan-start'),
              onPressed: plan.type == ReviewCourseType.manual ? onStart : null,
              child: Text(
                plan.type == ReviewCourseType.manual
                    ? '기간 선택하기 →'
                    : '첫 과제 시작 →',
              ),
            ),
          ],
        ),
      );
    }
    final requiredCount = plan.tasks.where((task) => task.required).length;
    final titleSize = mobile ? 19.0 : 22.0;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          plan.due,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Color(0xFF71717A),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          plan.title,
          style: TextStyle(
            fontSize: titleSize,
            letterSpacing: -titleSize * .04,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '${plan.meta} · ${requiredCount}단계',
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Color(0xFF71717A),
          ),
        ),
      ],
    );
    final progress = Row(
      children: [
        Expanded(
          child: Semantics(
            value: '${plan.progress}%',
            child: SizedBox(
              height: 5,
              child: LayoutBuilder(
                builder: (_, constraints) => Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Color(0xFFF3F3F5)),
                    ),
                    SizedBox(
                      width:
                          constraints.maxWidth *
                          plan.progress.clamp(0, 100) /
                          100,
                      height: 5,
                      child: const ColoredBox(color: Color(0xFF09090B)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 34,
          child: Text(
            '${plan.progress}%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
    return Column(
      key: ValueKey('wrong-answer-plan-panel-${plan.type.storageName}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 1),
        Container(
          constraints: mobile ? null : const BoxConstraints(minHeight: 126),
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? 14 : 20,
            vertical: mobile ? 15 : 18,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFFDFDFE),
            border: Border(
              left: BorderSide(color: Color(0x1A09090B)),
              right: BorderSide(color: Color(0x1A09090B)),
              bottom: BorderSide(color: Color(0x1A09090B)),
            ),
          ),
          child: mobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [copy, const SizedBox(height: 14), progress],
                )
              : Row(
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 24),
                    SizedBox(width: 170, child: progress),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 5, 2, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${plan.type.label} · ${plan.due}',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF71717A),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                plan.title,
                style: TextStyle(
                  fontSize: mobile ? 20 : 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                plan.meta,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF71717A),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x1A09090B)),
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
        const _ReviewPlanAccuracyGate(requiredAccuracy: 80),
        SizedBox(
          height: 48,
          child: TextButton(
            key: const ValueKey('wrong-answer-plan-start'),
            onPressed:
                plan.type == ReviewCourseType.manual ||
                    plan.tasks.any(
                      (task) =>
                          task.required &&
                          !task.sourceTask.completed &&
                          task.sourceTask.id.isNotEmpty,
                    )
                ? onStart
                : null,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF09090B),
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(),
              textStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            child: Text(
              plan.type == ReviewCourseType.manual ? '기간 선택하기 →' : '첫 과제 시작 →',
            ),
          ),
        ),
      ],
    );
  }
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
    key: ValueKey('review-course-task-${task.sourceTask.id}'),
    constraints: const BoxConstraints(minHeight: 64),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      border: isLast
          ? null
          : const Border(bottom: BorderSide(color: StudentDensityTokens.line)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(
            '${index + 1}'.padLeft(2, '0'),
            style: const TextStyle(
              color: StudentDensityTokens.muted,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                task.meta,
                style: const TextStyle(
                  color: StudentDensityTokens.muted,
                  fontSize: 8,
                  height: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Text(
          task.required ? '필수' : '선택',
          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700),
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
    required this.incorrectAttempts,
    required this.source,
    required this.reason,
    required this.tags,
    required this.attempts,
    this.done = false,
    this.occurredAt,
    this.questId,
  });

  final String number;
  final String title;
  final int incorrectAttempts;
  final String source;
  final String reason;
  final List<String> tags;
  final String attempts;
  final bool done;
  final DateTime? occurredAt;
  final String? questId;
  int get incorrectCount => incorrectAttempts;
}

class _AtlasReviewPlan {
  const _AtlasReviewPlan({
    required this.type,
    required this.label,
    required this.title,
    required this.due,
    required this.meta,
    required this.progress,
    required this.problemCount,
    required this.tasks,
    this.sourceCourse,
  });

  final ReviewCourseType type;
  final String label;
  final String title;
  final String due;
  final String meta;
  final int progress;

  /// 저장된 task의 목표 문항수합. 실제 조회수나 완료판정이 아니다.
  final int problemCount;
  final List<_AtlasReviewTask> tasks;
  final ReviewCourse? sourceCourse;
}

class _AtlasReviewTask {
  const _AtlasReviewTask.fromTask(this.sourceTask);
  final ReviewTask sourceTask;
  String get title => sourceTask.title;
  bool get required => sourceTask.required;
  String get meta => sourceTask.isProblemTask
      ? '${sourceTask.targetQuestionCount}문제'
      : sourceTask.kind == ReviewTaskKind.stats
      ? '기록'
      : sourceTask.kind == ReviewTaskKind.tagSummary
      ? '${sourceTask.tags.length}개 태그'
      : sourceTask.tags.take(3).join(' · ');
}
