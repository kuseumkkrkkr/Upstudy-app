import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:s11/shared/data/models/concept_textbooks.dart';
import 'package:s11/shared/ui/ios26/ios26_modal.dart';
import 'package:s11/sessions/review_course/business/review_course_store.dart';
import 'package:s11/sessions/textbook/ui/pages/book_page.dart';
import 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';
import 'package:s11/app/student_route_registry.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';

const _green = Color(0xFF1B402B);
const _lightGreen = Color(0xFF45BF63);
const _surface = Colors.white;

Future<T?> showReviewCoursePage<T>({required BuildContext context}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final modalContext = navigator.context;
  navigator.pop();
  return showIos26Modal<T>(
    context: modalContext,
    maxWidth: 1180,
    maxHeight: 780,
    child: const Ios26ModalShell(
      title: '복습 코스',
      child: ReviewCoursePage(embedded: true),
    ),
  );
}

class ReviewCoursePage extends StatefulWidget {
  const ReviewCoursePage({
    super.key,
    this.embedded = false,
    this.initialCourseId,
    this.initialTaskId,
    this.startManualSelection = false,
    this.reviewSnapshotLoader,
  });

  final bool embedded;

  /// Existing snapshot identifiers only; a missing record is not synthesized.
  final String? initialCourseId;
  final String? initialTaskId;
  final bool startManualSelection;

  /// Tests replace reading only. Production retains the existing store initializer.
  final Future<ReviewCourseSnapshot> Function()? reviewSnapshotLoader;

  @override
  State<ReviewCoursePage> createState() => _ReviewCoursePageState();
}

class _ReviewCoursePageState extends State<ReviewCoursePage> {
  final _store = ReviewCourseStore.instance;
  ReviewCourseSnapshot? _snapshot;
  ReviewCourse? _selectedCourse;
  bool _loading = true;
  String? _error;
  bool _initialActionOpened = false;
  int _detailTab = 0;

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
      final loader =
          widget.reviewSnapshotLoader ?? _store.generateMissingCourses;
      final snapshot = await loader();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _selectedCourse = _syncSelected(snapshot);
        _loading = false;
      });
      if (!_initialActionOpened) {
        if (widget.startManualSelection) {
          _initialActionOpened = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_createManualCourse());
          });
        } else if (widget.initialCourseId != null) {
          ReviewCourse? course;
          for (final candidate in snapshot.visibleCourses) {
            if (candidate.id == widget.initialCourseId) {
              course = candidate;
              break;
            }
          }
          ReviewTask? task;
          if (course != null) {
            for (final candidate in course.tasks) {
              if (candidate.id == widget.initialTaskId &&
                  !candidate.completed) {
                task = candidate;
                break;
              }
            }
          }
          if (course == null ||
              (widget.initialTaskId != null && task == null)) {
            setState(() => _error = '저장된 복습 코스 또는 과제를 찾을 수 없습니다.');
          } else {
            _initialActionOpened = true;
            final selectedCourse = course;
            final selectedTask = task;
            setState(() => _selectedCourse = selectedCourse);
            if (selectedTask != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  unawaited(_startTask(selectedCourse, selectedTask));
                }
              });
            }
          }
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '복습 코스를 준비하지 못했어요. 잠시 후 다시 시도해 주세요.';
        _loading = false;
      });
    }
  }

  ReviewCourse? _syncSelected(ReviewCourseSnapshot snapshot) {
    final selected = _selectedCourse;
    if (selected == null) return null;
    for (final course in snapshot.visibleCourses) {
      if (course.id == selected.id) return course;
    }
    return null;
  }

  Future<void> _markTaskComplete(
    ReviewCourse course,
    ReviewTask task, {
    int elapsedSeconds = 0,
    int correctCount = 0,
    int totalCount = 0,
  }) async {
    final snapshot = await _store.markTaskComplete(
      courseId: course.id,
      taskId: task.id,
      elapsedSeconds: elapsedSeconds,
      correctCount: correctCount,
      totalCount: totalCount,
    );
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _selectedCourse = _syncSelected(snapshot);
    });
  }

  Future<void> _startTask(ReviewCourse course, ReviewTask task) async {
    switch (task.kind) {
      case ReviewTaskKind.conceptReading:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BookWidget(book: buildConceptBook(task.tags)),
          ),
        );
        if (!mounted) return;
        await _markTaskComplete(course, task, elapsedSeconds: 180);
        return;
      case ReviewTaskKind.tagSummary:
      case ReviewTaskKind.stats:
        await _showInfoDialog(course, task);
        if (!mounted) return;
        if (task.required) {
          await _markTaskComplete(course, task, elapsedSeconds: 60);
        }
        return;
      case ReviewTaskKind.redoProblems:
      case ReviewTaskKind.conceptProblems:
      case ReviewTaskKind.memoryCheck:
      case ReviewTaskKind.advancedProblems:
      case ReviewTaskKind.timedMock:
        await _startProblemTask(course, task);
        return;
    }
  }

  Future<void> _startProblemTask(ReviewCourse course, ReviewTask task) async {
    final scaffold = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _loading = true);
    final quests = await _store.loadQuestsForTask(task);
    if (!mounted) return;
    setState(() => _loading = false);
    if (quests.isEmpty) {
      scaffold.showSnackBar(
        const SnackBar(content: Text('복습할 문제를 찾을 수 없습니다.')),
      );
      return;
    }

    var graded = 0;
    var correct = 0;
    final startedAt = DateTime.now();
    final config = ProblemSolveConfig(
      questionCount: quests.length,
      hashTags: task.tags,
      gradeImmediately: true,
      minDifficultyTier: task.kind == ReviewTaskKind.advancedProblems ? 4 : 3,
      maxDifficultyTier: task.kind == ReviewTaskKind.advancedProblems ? 5 : 3,
      passRate: ReviewCourseStore.requiredAccuracyPercent,
      quests: quests,
      ratingEnabled: true,
      onProblemGraded:
          ({
            required int itemIndex,
            required Map<String, dynamic>? quest,
            required bool isCorrect,
            required List<Map<String, dynamic>> stepCorrectness,
            int? selectedIndex,
            int? elapsedSeconds,
          }) async {
            graded += 1;
            if (isCorrect) correct += 1;
            if (graded < quests.length) return;

            final accuracy = (correct / quests.length * 100).round();
            if (accuracy < ReviewCourseStore.requiredAccuracyPercent) {
              if (!mounted) return;
              scaffold.showSnackBar(
                SnackBar(content: Text('정답률 $accuracy%입니다. 80% 이상이어야 이수됩니다.')),
              );
              return;
            }

            await _markTaskComplete(
              course,
              task,
              elapsedSeconds:
                  elapsedSeconds ??
                  DateTime.now().difference(startedAt).inSeconds,
              correctCount: correct,
              totalCount: quests.length,
            );
          },
    );
    await navigator.push(
      MaterialPageRoute(builder: (_) => BuildpageWidget(config: config)),
    );
  }

  Future<void> _showInfoDialog(ReviewCourse course, ReviewTask task) {
    final stats = _snapshot?.stats ?? const ReviewStats();
    final tags = course.summaryTags.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(task.title),
          content: SizedBox(
            width: 420,
            child: task.kind == ReviewTaskKind.stats
                ? _StatsSummary(stats: stats)
                : _TagSummary(tags: tags.take(10).toList()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createManualCourse() async {
    final today = DateTime.now();
    final first = DateTime(today.year, today.month, today.day).subtract(
      const Duration(days: ReviewCourseStore.maxActivityStoredDays - 1),
    );
    final range = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: today.subtract(const Duration(days: 6)),
        end: today,
      ),
      helpText: '중간복습 기간 선택',
      saveText: '중간복습 하기',
    );
    if (range == null) return;
    setState(() => _loading = true);
    final snapshot = await _store.addManualCourse(
      startDate: range.start,
      endDate: range.end,
    );
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _selectedCourse = snapshot.visibleCourses.isNotEmpty
          ? snapshot.visibleCourses.first
          : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Material(
        color: _surface,
        child: Column(
          children: [
            _EmbeddedToolbar(
              onManualReview: _createManualCourse,
              onRefresh: _load,
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    return StudentHtmlShell(
      key: const ValueKey('standalone-review-course-page'),
      title: '복습 코스',
      activeRoute: StudentRouteRegistry.byId('home')!.route,
      railWidth: width > 1040 ? 84 : 72,
      showContextAside: width > 1040,
      mobileBackButton: true,
      onMenu: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushReplacementNamed(
            StudentRouteRegistry.byId('wrong-list')!.route,
          );
        }
      },
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : _selectedCourse != null
          ? _ReviewDetailBody(
              course: _selectedCourse!,
              selectedTab: _detailTab,
              onTab: (value) => setState(() => _detailTab = value),
              onStartTask: (task) =>
                  unawaited(_startTask(_selectedCourse!, task)),
              onList: () => Navigator.of(
                context,
              ).pushNamed(StudentRouteRegistry.byId('wrong-list')!.route),
            )
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    '실제 복습 코스를 선택해 주세요.',
                    key: ValueKey('review-course-selection-required'),
                  ),
                ),
                Expanded(child: _buildContent()),
              ],
            ),
    );
  }

  Widget _buildContent() {
    final snapshot = _snapshot;
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _green));
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }
    if (snapshot == null) {
      return _ErrorState(message: '복습 데이터를 불러오지 못했습니다.', onRetry: _load);
    }

    final selected = _selectedCourse;
    if (selected != null) {
      return _CourseDetail(
        course: selected,
        onBack: () => setState(() => _selectedCourse = null),
        onStartTask: _startTask,
      );
    }

    return _CourseList(
      snapshot: snapshot,
      onSelectCourse: (course) => setState(() => _selectedCourse = course),
      onManualReview: _createManualCourse,
    );
  }
}

/// The reference's final renderer contains a toolbar, metrics and item list,
/// not the obsolete hero/headline declarations earlier in its stylesheet.
class _ReviewDetailBody extends StatelessWidget {
  const _ReviewDetailBody({
    required this.course,
    required this.selectedTab,
    required this.onTab,
    required this.onStartTask,
    required this.onList,
  });
  final ReviewCourse course;
  final int selectedTab;
  final ValueChanged<int> onTab;
  final ValueChanged<ReviewTask> onStartTask;
  final VoidCallback onList;

  ReviewTask? get nextTask {
    if (course.status == ReviewCourseStatus.completed) return null;
    for (final task in course.tasks) {
      if (task.required && !task.completed && task.id.isNotEmpty) return task;
    }
    return null;
  }

  Widget _surface(Widget child, {Key? key}) => Container(
    key: key,
    decoration: BoxDecoration(
      color: const Color(0xFFFDFDFE),
      border: Border.all(color: const Color(0x1A09090B)),
    ),
    child: child,
  );

  Widget _action(
    String label,
    VoidCallback? onTap,
    bool mobile, {
    bool primary = false,
  }) => SizedBox(
    height: mobile ? 38 : 42,
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.symmetric(horizontal: mobile ? 11 : 16),
        shape: const RoundedRectangleBorder(),
        side: const BorderSide(color: Color(0xFF09090B)),
        foregroundColor: primary ? Colors.white : const Color(0xFF09090B),
        backgroundColor: primary
            ? const Color(0xFF09090B)
            : const Color(0xFFFDFDFE),
        textStyle: const TextStyle(
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      child: Row(
        mainAxisSize: primary && !mobile ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: primary
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.center,
        children: [
          Text(label),
          if (primary) ...[
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward, size: 18),
          ],
        ],
      ),
    ),
  );

  Widget _toolbar(bool mobile) => _surface(
    Padding(
      padding: EdgeInsets.all(mobile ? 5 : 6),
      child: Row(
        children: [
          if (mobile) Expanded(child: _tabs(mobile)) else _tabs(mobile),
          SizedBox(width: mobile ? 6 : 8),
          SizedBox(
            width: mobile ? null : 180,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: mobile ? 118 : 180),
              child: _action(
                '${course.estimatedMinutes}분 복습 시작',
                nextTask == null ? null : () => onStartTask(nextTask!),
                mobile,
                primary: true,
              ),
            ),
          ),
          if (!mobile) ...[
            const SizedBox(width: 9),
            _action('문제 목록', onList, mobile),
          ],
        ],
      ),
    ),
    key: const ValueKey('review-detail-toolbar'),
  );

  Widget _tabs(bool mobile) => _surface(
    Row(
      mainAxisSize: mobile ? MainAxisSize.max : MainAxisSize.min,
      children: List.generate(3, (index) {
        final tab = Semantics(
          selected: selectedTab == index,
          button: true,
          child: Container(
            height: mobile ? 38 : 40,
            width: mobile ? null : 64,
            foregroundDecoration: index == 2
                ? null
                : const BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0x1A09090B))),
                  ),
            child: TextButton(
              onPressed: () => onTab(index),
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.symmetric(horizontal: mobile ? 9 : 14),
                shape: const RoundedRectangleBorder(),
                backgroundColor: selectedTab == index
                    ? const Color(0xFF09090B)
                    : const Color(0xFFFDFDFE),
                foregroundColor: selectedTab == index
                    ? Colors.white
                    : const Color(0xFF71717A),
                textStyle: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              child: Text(['개요', '구성', '기록'][index]),
            ),
          ),
        );
        return mobile ? Expanded(child: tab) : tab;
      }),
    ),
  );

  Widget _metrics(bool mobile, double viewportWidth) {
    final target = course.tasks
        .where((task) => task.isProblemTask)
        .fold<int>(0, (sum, task) => sum + task.targetQuestionCount);
    final concepts = {
      ...course.summaryTags.keys,
      ...course.tasks.expand((task) => task.tags),
    };
    final values = [
      '$target',
      '${concepts.length}',
      '${course.estimatedMinutes}분',
    ];
    final size = mobile ? 18.0 : (viewportWidth * .02).clamp(19.0, 28.0);
    return _surface(
      Row(
        children: List.generate(
          3,
          (index) => Expanded(
            child: Container(
              height: mobile ? 74 : 90,
              padding: mobile
                  ? const EdgeInsets.symmetric(horizontal: 10, vertical: 12)
                  : const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: !mobile || index == 2
                    ? null
                    : const Border(right: BorderSide(color: Color(0x1A09090B))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  Text(
                    values[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: size,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -size * .06,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ['문제', '개념', '예상'][index],
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF71717A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      key: const ValueKey('review-detail-metrics'),
    );
  }

  String _kind(ReviewTask task) => switch (task.kind) {
    ReviewTaskKind.redoProblems => '오답',
    ReviewTaskKind.conceptReading => '교재',
    ReviewTaskKind.tagSummary => '태그',
    ReviewTaskKind.stats => '통계',
    _ => '개념',
  };

  Widget _list(bool mobile) => _surface(
    ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 238),
      child: Padding(
        padding: mobile
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          children: [
            for (final task in course.tasks)
              Material(
                color: const Color(0xFFFDFDFE),
                child: InkWell(
                  key: ValueKey('review-detail-task-${task.id}'),
                  onTap:
                      task.completed ||
                          course.status == ReviewCourseStatus.completed
                      ? null
                      : () => onStartTask(task),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 62),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0x1A09090B)),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: mobile ? 50 : 62,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: IntrinsicWidth(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                height: 28,
                                alignment: Alignment.center,
                                color: const Color(0xFFF3F3F5),
                                child: Text(
                                  _kind(task),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: mobile ? 9 : 14),
                        Expanded(
                          child: Text(
                            task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: mobile ? 13 : 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        SizedBox(width: mobile ? 9 : 14),
                        Container(
                          constraints: const BoxConstraints(minWidth: 44),
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0x1A09090B)),
                          ),
                          child: Text(
                            task.completed
                                ? '완료'
                                : task.required
                                ? '필수'
                                : '선택',
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
        ),
      ),
    ),
    key: const ValueKey('review-detail-list'),
  );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = isStudentDensityMobile(context);
    final padding = mobile
        ? 10.0
        : width > 1040
        ? 38.0
        : 28.0;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toolbar(mobile),
            SizedBox(height: mobile ? 2 : 20),
            _metrics(mobile, width),
            SizedBox(height: mobile ? 12 : 18),
            if (mobile)
              _list(true)
            else
              LayoutBuilder(
                builder: (_, constraints) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(child: SizedBox()),
                    const SizedBox(width: 18),
                    SizedBox(
                      width: math.max(
                        230,
                        (constraints.maxWidth - 18) * .55 / 1.75,
                      ),
                      child: _list(false),
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

class _EmbeddedToolbar extends StatelessWidget {
  const _EmbeddedToolbar({
    required this.onManualReview,
    required this.onRefresh,
  });

  final VoidCallback onManualReview;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '망각곡선 기반 복습 코스',
              style: GoogleFonts.inter(
                color: _green,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onManualReview,
            icon: const Icon(Icons.calendar_month),
            label: const Text('중간복습 하기'),
          ),
          IconButton(
            tooltip: '새로고침',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, color: _green),
          ),
        ],
      ),
    );
  }
}

class _CourseList extends StatelessWidget {
  const _CourseList({
    required this.snapshot,
    required this.onSelectCourse,
    required this.onManualReview,
  });

  final ReviewCourseSnapshot snapshot;
  final ValueChanged<ReviewCourse> onSelectCourse;
  final VoidCallback onManualReview;

  @override
  Widget build(BuildContext context) {
    final courses = snapshot.visibleCourses;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
      children: [
        _StatsHeader(stats: snapshot.stats),
        const SizedBox(height: 16),
        if (courses.isEmpty)
          _EmptyCourseState(onManualReview: onManualReview)
        else
          for (final course in courses)
            _CourseListTile(
              course: course,
              onTap: () => onSelectCourse(course),
            ),
      ],
    );
  }
}

class _CourseListTile extends StatelessWidget {
  const _CourseListTile({required this.course, required this.onTap});

  final ReviewCourse course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isClear = course.status == ReviewCourseStatus.completed;
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE1E6DF)),
      ),
      elevation: 0,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          isClear ? Icons.check_circle : Icons.pending_actions,
          color: isClear ? _lightGreen : _green,
        ),
        title: Text(
          course.title,
          style: GoogleFonts.inter(
            color: _green,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          isClear
              ? '클리어 · 삭제까지 1일 이내'
              : '만료일 ${course.dueDateKey} · 정답률 ${course.accuracyPercent}%',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _CourseDetail extends StatelessWidget {
  const _CourseDetail({
    required this.course,
    required this.onBack,
    required this.onStartTask,
  });

  final ReviewCourse course;
  final VoidCallback onBack;
  final Future<void> Function(ReviewCourse course, ReviewTask task) onStartTask;

  @override
  Widget build(BuildContext context) {
    final requiredCount = math.max(course.requiredCount, 1);
    final progress = course.completedRequiredCount / requiredCount;
    final tags = course.summaryTags.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('코스 목록'),
          ),
        ),
        Text(
          course.title,
          style: GoogleFonts.inter(
            color: _green,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          color: _lightGreen,
          backgroundColor: const Color(0xFFE7ECE5),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Pill('필수 ${course.completedRequiredCount}/$requiredCount'),
            _Pill('정답률 ${course.accuracyPercent}%'),
            _Pill('80% 이상 이수'),
            if (course.status == ReviewCourseStatus.completed)
              const _Pill('클리어'),
          ],
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags.take(8).map((entry) {
              return Chip(
                visualDensity: VisualDensity.compact,
                label: Text('${entry.key} ${entry.value}'),
                backgroundColor: const Color(0xFFEFF5EA),
                side: BorderSide.none,
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 18),
        for (final task in course.tasks)
          _TaskTile(
            task: task,
            locked: course.status == ReviewCourseStatus.completed,
            onTap:
                task.completed || course.status == ReviewCourseStatus.completed
                ? null
                : () => onStartTask(course, task),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5EA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(color: _green, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.stats});

  final ReviewStats stats;

  @override
  Widget build(BuildContext context) {
    final minutes = (stats.totalReviewSeconds / 60).round();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E5DD)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _Metric(label: '완료 코스', value: '${stats.completedTotal}'),
          _Metric(label: '연속 복습', value: '${stats.currentStreak}일'),
          _Metric(label: '최고 연속', value: '${stats.bestStreak}일'),
          _Metric(label: '총 복습 시간', value: '$minutes분'),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              color: _green,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.locked,
    required this.onTap,
  });

  final ReviewTask task;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icon = task.completed
        ? Icons.check_circle
        : task.required
        ? Icons.radio_button_unchecked
        : Icons.info_outline;
    final score = task.totalCount > 0
        ? ' · ${((task.correctCount / task.totalCount) * 100).round()}%'
        : '';
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE1E6DF)),
      ),
      child: ListTile(
        leading: Icon(icon, color: task.completed ? _lightGreen : _green),
        title: Text(
          '${task.title}$score',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _green),
        ),
        subtitle: Text(task.description),
        trailing: onTap == null || locked
            ? null
            : const Icon(Icons.chevron_right),
        onTap: locked ? null : onTap,
      ),
    );
  }
}

class _EmptyCourseState extends StatelessWidget {
  const _EmptyCourseState({required this.onManualReview});

  final VoidCallback onManualReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E6DF)),
      ),
      child: Column(
        children: [
          const Icon(Icons.fact_check_outlined, size: 52, color: _green),
          const SizedBox(height: 12),
          Text(
            '생성된 복습 코스가 없습니다.',
            style: GoogleFonts.inter(
              color: _green,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text('이번 주나 이번 달에 학습 기록이 생기면 복습 코스가 자동 생성됩니다.'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onManualReview,
            icon: const Icon(Icons.calendar_month),
            label: const Text('중간복습 하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

class _TagSummary extends StatelessWidget {
  const _TagSummary({required this.tags});

  final List<MapEntry<String, int>> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const Text('표시할 취약 태그가 없습니다.');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < tags.length; i++)
          ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              child: Text('${i + 1}'),
            ),
            title: Text(tags[i].key),
            trailing: Text('${tags[i].value}회'),
          ),
      ],
    );
  }
}

class _StatsSummary extends StatelessWidget {
  const _StatsSummary({required this.stats});

  final ReviewStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DialogMetric(label: '전체 완료', value: '${stats.completedTotal}회'),
        _DialogMetric(label: '1일 복습', value: '${stats.completedDaily}회'),
        _DialogMetric(label: '주간 복습', value: '${stats.completedWeekly}회'),
        _DialogMetric(label: '월간 복습', value: '${stats.completedMonthly}회'),
        _DialogMetric(label: '중간복습', value: '${stats.completedManual}회'),
        const Divider(),
        const Text('오답 감소율, 태그 개선율, 장기 기억 유지율은 데이터 축적 후 제공됩니다.'),
      ],
    );
  }
}

class _DialogMetric extends StatelessWidget {
  const _DialogMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
