import 'package:flutter/material.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/course_service.dart';
import 'confirmed_course_completion.dart';

import 'package:s11/shared/services/api/student_facing_api_error.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';

/// Displays curriculum events supplied by the product API in the HTML timeline layout.
class CurriculumHistoryPage extends StatefulWidget {
  const CurriculumHistoryPage({super.key, this.historyItems, this.courseId});

  /// Only confirmed server history belongs here; the prototype's sample entries are not data.
  final List<Map<String, String>>? historyItems;
  final String? courseId;

  static const routeName = '/schedule/history';

  @override
  State<CurriculumHistoryPage> createState() => _CurriculumHistoryPageState();
}

class _CurriculumHistoryPageState extends State<CurriculumHistoryPage> {
  static const _tabs = ['일정', '완료', '기록'];
  int _selectedTab = 0;
  late DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());

  List<Map<String, String>> _runtimeItems = const [];
  bool _confirmedRuntimeLoaded = false;
  String _status = '커리큘럼 이력 데이터가 연결되지 않았습니다.';
  bool _loading = false;
  bool _failed = false;
  List<Map<String, String>> get _items => widget.historyItems ?? _runtimeItems;

  @override
  void initState() {
    super.initState();
    if (widget.historyItems == null) _loadConfirmedCompletions();
  }

  /// Uses the existing selected-course storage and enrolled-course contract.
  /// No arbitrary course or today's date is substituted when metadata is absent.
  Future<void> _loadConfirmedCompletions() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
      _status = '완료 기록을 확인하고 있습니다.';
    });
    try {
      final selected =
          widget.courseId ??
          await ApiClient.instance.getUserStorage('student.active_course.v1');
      if (selected == null || selected.trim().isEmpty) {
        if (mounted) {
          setState(
            () => _status = '현재 코스를 먼저 선택해 주세요. 전체 상태변경 이력은 아직 제공되지 않습니다.',
          );
        }
        return;
      }
      final courses = await CourseService.fetchMyCourses();
      if (!courses.any(
        (course) => course.id == selected.trim() && !course.isDemo,
      )) {
        if (mounted) setState(() => _status = '선택한 실제 수강 코스를 확인할 수 없습니다.');
        return;
      }
      final runtime = await CourseService.runtimeState(selected.trim());
      final state = runtime['student_state'];
      if (state is! Map ||
          state['started_day'] is! int ||
          state['module_completed_day'] is! Map ||
          state['completed_modules'] is! List) {
        if (mounted) {
          setState(
            () => _status = '서버 완료 기록을 확인할 수 없습니다. 전체 상태변경 이력은 아직 제공되지 않습니다.',
          );
        }
        return;
      }
      final confirmed = ConfirmedCourseCompletion.fromRuntime(runtime);
      if (!mounted) return;
      setState(() {
        _confirmedRuntimeLoaded = true;
        _runtimeItems = confirmed
            .map((event) => event.toHistoryItem())
            .toList(growable: false);
        _status = '현재 코스에서 확인된 완료 기록이 없습니다.';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _failed = true;
          _status = studentFacingApiError(
            error,
            fallback: '완료 기록을 불러오지 못했습니다.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final metrics = _confirmedRuntimeLoaded
        ? <int?>[_items.length, null, null]
        : _historyMetrics(_items);
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth <= 720;
        final page = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: EdgeInsets.all(compact ? 10 : 24),
            child: Column(
              children: [
                _HistoryToolbar(
                  tabs: _tabs,
                  selectedTab: _selectedTab,
                  onSelect: (index) => setState(() => _selectedTab = index),
                  onReassign: () =>
                      Navigator.of(context).pushNamed('/schedule'),
                ),
                const SizedBox(height: 12),
                if (_confirmedRuntimeLoaded)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      '현재 코스의 확인된 완료 기록만 표시합니다. 실패·재분배·전체 상태변경 이력은 제공되지 않습니다.',
                      style: TextStyle(
                        fontSize: 10,
                        color: StudentDensityTokens.muted,
                      ),
                    ),
                  ),
                if (_failed)
                  TextButton(
                    onPressed: _loadConfirmedCompletions,
                    child: const Text('다시 시도'),
                  ),
                _HistoryWeekStrip(
                  selectedDate: _selectedDate,
                  onSelect: (date) => setState(() => _selectedDate = date),
                ),
                const SizedBox(height: 12),
                if (compact) ...[
                  _HistoryMetrics(metrics: metrics),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _HistoryList(items: _items, emptyMessage: _status),
                  ),
                ] else
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _HistoryList(
                            items: _items,
                            emptyMessage: _status,
                          ),
                        ),
                        const SizedBox(width: 18),
                        SizedBox(
                          width: 240,
                          child: _HistoryMetrics(metrics: metrics),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
        return Align(alignment: Alignment.topCenter, child: page);
      },
    );

    return StudentHtmlShell(
      key: const ValueKey('curriculum-history-screen'),
      title: '커리큘럼 이력',
      activeRoute: '/schedule',
      showContextAside: false,
      onSearch: () => showStudentQuickSearch(context),
      onNotifications: () => showStudentNotifications(context),
      child: ColoredBox(
        color: StudentDensityTokens.background,
        child: mobile ? content : SafeArea(top: false, child: content),
      ),
    );
  }
}

class _HistoryToolbar extends StatelessWidget {
  const _HistoryToolbar({
    required this.tabs,
    required this.selectedTab,
    required this.onSelect,
    required this.onReassign,
  });

  final List<String> tabs;
  final int selectedTab;
  final ValueChanged<int> onSelect;
  final VoidCallback onReassign;

  @override
  Widget build(BuildContext context) => Container(
    height: 50,
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: StudentDensityTokens.line),
    ),
    child: Row(
      children: [
        for (var index = 0; index < tabs.length; index++)
          Expanded(
            child: TextButton(
              key: ValueKey('curriculum-history-tab-${tabs[index]}'),
              onPressed: () => onSelect(index),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: index == selectedTab
                    ? Colors.white
                    : StudentDensityTokens.ink,
                backgroundColor: index == selectedTab
                    ? StudentDensityTokens.ink
                    : Colors.white,
                shape: const RoundedRectangleBorder(),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: Text(tabs[index]),
            ),
          ),
        const SizedBox(width: 6),
        Expanded(
          flex: 2,
          child: FilledButton(
            key: const ValueKey('curriculum-history-reassign'),
            onPressed: onReassign,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: Colors.white,
              backgroundColor: StudentDensityTokens.ink,
              shape: const RoundedRectangleBorder(),
              textStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('실패 항목 재배정'),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _HistoryWeekStrip extends StatelessWidget {
  const _HistoryWeekStrip({required this.selectedDate, required this.onSelect});

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final monday = DateUtils.dateOnly(
      selectedDate,
    ).subtract(Duration(days: selectedDate.weekday - 1));
    const weekdays = ['월', '화', '수', '목', '금'];
    return SizedBox(
      height: 72,
      child: Row(
        children: List.generate(5, (index) {
          final date = monday.add(Duration(days: index));
          final active = DateUtils.isSameDay(date, selectedDate);
          return Expanded(
            child: Material(
              color: active ? StudentDensityTokens.ink : Colors.white,
              child: InkWell(
                key: ValueKey('curriculum-history-day-${_dateKey(date)}'),
                onTap: () => onSelect(date),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: StudentDensityTokens.line),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        weekdays[index],
                        style: TextStyle(
                          color: active
                              ? Colors.white70
                              : StudentDensityTokens.muted,
                          fontSize: 9,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : StudentDensityTokens.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _HistoryMetrics extends StatelessWidget {
  const _HistoryMetrics({required this.metrics});

  final List<int?> metrics;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 74,
    child: Row(
      children: List.generate(3, (index) {
        const labels = ['완료', '재분배', '실패'];
        return Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 8, 7),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: StudentDensityTokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metrics[index]?.toString() ?? '—',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  labels[index],
                  style: const TextStyle(
                    color: StudentDensityTokens.muted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    ),
  );
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.items, required this.emptyMessage});

  final List<Map<String, String>> items;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 310),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: StudentDensityTokens.line),
    ),
    child: items.isEmpty
        ? Center(
            child: Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: StudentDensityTokens.muted,
                fontSize: 12,
              ),
            ),
          )
        : Column(children: [for (final item in items) _HistoryRow(item: item)]),
  );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});

  final Map<String, String> item;

  @override
  Widget build(BuildContext context) {
    final status = _value(item, 'newStatus');
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: StudentDensityTokens.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 28,
            alignment: Alignment.center,
            color: StudentDensityTokens.surfaceMuted,
            child: Text(
              _compactDate(_value(item, 'date')),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _value(item, 'title', fallback: '학습 항목'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_value(item, 'oldStatus').isNotEmpty)
                  Text(
                    '${_value(item, 'oldStatus')} → $status',
                    style: const TextStyle(
                      color: StudentDensityTokens.muted,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 34),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: StudentDensityTokens.surface,
              border: Border.all(color: StudentDensityTokens.line),
            ),
            child: Text(
              status.isEmpty ? '확인' : status,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

List<int?> _historyMetrics(List<Map<String, String>> items) {
  if (items.isEmpty) return const [null, null, null];
  return [
    items.where((item) => _isCompleted(_value(item, 'newStatus'))).length,
    items.where((item) => _value(item, 'newStatus') == '재분배').length,
    items.where((item) => _value(item, 'newStatus') == '실패').length,
  ];
}

bool _isCompleted(String status) => status == '성공' || status == '완료';

String _value(Map<String, String> item, String key, {String fallback = ''}) =>
    item[key]?.trim().isNotEmpty == true ? item[key]!.trim() : fallback;

String _compactDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
