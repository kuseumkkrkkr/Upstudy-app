import 'package:flutter/material.dart';

import 'package:s11/app/router.dart';
import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';

/// 전체 활동 기록을 HTML의 독립 화면 구조로 표시합니다.
class StudentActivityHistoryPage extends StatefulWidget {
  const StudentActivityHistoryPage({super.key, this.now});

  /// Optional date anchor for deterministic widget captures.
  final DateTime? now;

  @override
  State<StudentActivityHistoryPage> createState() =>
      _StudentActivityHistoryPageState();
}

class _StudentActivityHistoryPageState
    extends State<StudentActivityHistoryPage> {
  int _selectedTab = 0;
  late int _selectedDayOffset;

  @override
  void initState() {
    super.initState();
    final today = widget.now ?? DateTime.now();
    _selectedDayOffset = today.weekday <= 5 ? today.weekday - 1 : 4;
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    return ValueListenableBuilder<ActivitySnapshot>(
      valueListenable: ActivityStore.notifier,
      builder: (context, snapshot, _) => StudentHtmlShell(
        key: const ValueKey('activity-history-page'),
        title: '전체 활동 보고서',
        activeRoute: AppRoutes.studentDashboard,
        mobileBackButton: true,
        onMenu: () => Navigator.of(context).maybePop(),
        railWidth: 84,
        showContextAside: true,
        contextAside: _ActivityHistoryContextAside(
          snapshot: snapshot,
          now: now,
        ),
        child: _buildReport(context, snapshot),
      ),
    );
  }

  Widget _buildReport(BuildContext context, ActivitySnapshot snapshot) {
    final mobile = isStudentDensityMobile(context);
    final recent = ActivityStore.recentDays(snapshot, 56, now: widget.now);
    final week = recent.skip(recent.length - 7).toList();
    final weekScore = week.fold<int>(0, (sum, day) => sum + day.score);
    final activeDays = recent.where((day) => day.score > 0).length;
    final streakDays = _currentStreak(recent);
    final now = widget.now ?? DateTime.now();
    final todayPercent =
        (ActivityStore.activityPercentFromScore(
                  ActivityStore.scoreForDate(snapshot, now),
                ) *
                100)
            .round();
    final rows = <_HistoryRowData>[
      _HistoryRowData(
        tag: '이번 주',
        title: '활동 점수 ${_formatNumber(weekScore)}',
        action: '상세',
      ),
      _HistoryRowData(
        tag: '누적',
        title: '문제 ${_formatNumber(snapshot.totalSolvedCount)}개 풀이',
        action: '기록',
      ),
      _HistoryRowData(
        tag: '최근',
        title: snapshot.lastEvent == null ? '학습 기록' : '최근 풀이 기록',
        action: snapshot.lastEvent == null ? '확인' : '완료',
      ),
    ];

    final selectedRows = switch (_selectedTab) {
      1 => rows.skip(1).toList(),
      2 => rows.take(2).toList(),
      _ => rows,
    };
    final report = LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth > 760;
        return SingleChildScrollView(
          padding: EdgeInsets.all(desktop ? 38 : 10),
          child: Column(
            children: [
              _buildToolbar(context, mobile),
              SizedBox(height: mobile ? 5 : 22),
              _buildDayStrip(now),
              SizedBox(height: mobile ? 12 : 18),
              if (desktop)
                Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(child: SizedBox(height: 270)),
                        const SizedBox(width: 18),
                        SizedBox(
                          width: 240,
                          height: 270,
                          child: _buildMetrics(
                            activeDays: activeDays,
                            streakDays: streakDays,
                            todayPercent: todayPercent,
                            vertical: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildList(selectedRows)),
                        const SizedBox(width: 258),
                      ],
                    ),
                  ],
                )
              else ...[
                _buildMetrics(
                  activeDays: activeDays,
                  streakDays: streakDays,
                  todayPercent: todayPercent,
                ),
                const SizedBox(height: 12),
                _buildList(selectedRows),
              ],
            ],
          ),
        );
      },
    );

    return report;
  }

  Widget _buildToolbar(BuildContext context, bool mobile) {
    final tabs = ['일정', '완료', '기록'];
    return Container(
      height: mobile ? 48 : 56,
      color: StudentDensityTokens.surface,
      padding: EdgeInsets.fromLTRB(
        mobile ? 5 : 8,
        mobile ? 5 : 7,
        5,
        mobile ? 5 : 7,
      ),
      child: Row(
        children: [
          for (var index = 0; index < tabs.length; index++)
            if (mobile)
              Expanded(
                flex: const [5, 5, 4][index],
                child: _toolbarTab(index, tabs[index]),
              )
            else
              SizedBox(width: 64, child: _toolbarTab(index, tabs[index])),
          if (!mobile) const SizedBox(width: 8),
          if (mobile)
            Expanded(
              flex: 9,
              child: _ToolbarAction(
                label: '계속하기',
                primary: true,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.schedule),
              ),
            )
          else
            SizedBox(
              width: 180,
              child: _ToolbarAction(
                label: '계속하기',
                primary: true,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.schedule),
              ),
            ),
          if (!mobile) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: _ToolbarAction(
                label: '나중에',
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.scheduleHistory),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayStrip(DateTime today) {
    final monday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return Row(
      children: [
        for (var index = 0; index < 5; index++)
          Expanded(
            child: _DayButton(
              weekday: weekdays[index],
              day: monday.add(Duration(days: index)).day,
              height: isStudentDensityMobile(context) ? 62 : 72,
              selected: _selectedDayOffset == index,
              onTap: () => setState(() => _selectedDayOffset = index),
            ),
          ),
      ],
    );
  }

  Widget _toolbarTab(int index, String label) => _ToolbarTab(
    label: label,
    selected: _selectedTab == index,
    onTap: () => setState(() => _selectedTab = index),
  );

  Widget _buildMetrics({
    required int activeDays,
    required int streakDays,
    required int todayPercent,
    bool vertical = false,
  }) {
    final values = [
      ('활동일', '$activeDays일'),
      ('연속 학습', '$streakDays일'),
      ('오늘', '$todayPercent%'),
    ];
    return Container(
      color: StudentDensityTokens.surface,
      child: Flex(
        direction: vertical ? Axis.vertical : Axis.horizontal,
        children: [
          for (var index = 0; index < values.length; index++)
            Expanded(
              flex: vertical ? 1 : 1,
              child: Container(
                height: vertical ? 90 : 75,
                padding: EdgeInsets.symmetric(
                  horizontal: vertical ? 14 : 10,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    right: !vertical && index < values.length - 1
                        ? const BorderSide(color: StudentDensityTokens.line)
                        : BorderSide.none,
                    bottom: vertical && index < values.length - 1
                        ? const BorderSide(color: StudentDensityTokens.line)
                        : BorderSide.none,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      values[index].$2,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        color: StudentDensityTokens.ink,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      values[index].$1,
                      style: const TextStyle(
                        fontSize: 10,
                        color: StudentDensityTokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(List<_HistoryRowData> rows) {
    return Container(
      constraints: const BoxConstraints(minHeight: 310),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      color: StudentDensityTokens.surface,
      child: Column(
        children: [
          for (final row in rows)
            _HistoryRow(
              data: row,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.schedule),
            ),
        ],
      ),
    );
  }
}

class _ToolbarTab extends StatelessWidget {
  const _ToolbarTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? StudentDensityTokens.ink : StudentDensityTokens.surface,
    child: InkWell(
      onTap: onTap,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : StudentDensityTokens.muted,
          ),
        ),
      ),
    ),
  );
}

class _ToolbarAction extends StatelessWidget {
  const _ToolbarAction({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: primary ? Colors.white : StudentDensityTokens.ink,
        backgroundColor: primary ? StudentDensityTokens.ink : Colors.white,
        side: BorderSide(
          color: primary
              ? StudentDensityTokens.ink
              : StudentDensityTokens.lineStrong,
        ),
        shape: const RoundedRectangleBorder(),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
      ),
    ),
  );
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.weekday,
    required this.day,
    required this.height,
    required this.selected,
    required this.onTap,
  });

  final String weekday;
  final int day;
  final double height;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? StudentDensityTokens.ink : StudentDensityTokens.surface,
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekday,
              style: TextStyle(
                fontSize: 9,
                color: selected ? Colors.white70 : StudentDensityTokens.muted,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '$day',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : StudentDensityTokens.ink,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HistoryRowData {
  const _HistoryRowData({
    required this.tag,
    required this.title,
    required this.action,
  });

  final String tag;
  final String title;
  final String action;
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.data, required this.onTap});

  final _HistoryRowData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 70),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: StudentDensityTokens.line)),
    ),
    child: Row(
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 54),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          color: StudentDensityTokens.surfaceMuted,
          child: Text(
            data.tag,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            data.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          height: 36,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: StudentDensityTokens.ink,
              side: const BorderSide(color: StudentDensityTokens.lineStrong),
              shape: const RoundedRectangleBorder(),
            ),
            child: Text(
              data.action,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ActivityHistoryContextAside extends StatelessWidget {
  const _ActivityHistoryContextAside({
    required this.snapshot,
    required this.now,
  });

  final ActivitySnapshot snapshot;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final days = ActivityStore.recentDays(snapshot, 56, now: now);
    final weekScore = days
        .skip(days.length - 7)
        .fold<int>(0, (sum, day) => sum + day.score);
    final streak = _currentStreak(days);
    return Container(
      width: 244,
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 22),
      decoration: const BoxDecoration(
        color: StudentDensityTokens.surface,
        border: Border(left: BorderSide(color: StudentDensityTokens.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                color: StudentDensityTokens.ink,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '활동 점수 ${_formatNumber(weekScore)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: StudentDensityTokens.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: StudentDensityTokens.line),
          const SizedBox(height: 14),
          const _AsideMetric(label: '오늘 집중', value: '—'),
          const SizedBox(height: 26),
          _AsideMetric(label: '연속 학습', value: '$streak일'),
          const Spacer(),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.tools),
              style: FilledButton.styleFrom(
                backgroundColor: StudentDensityTokens.ink,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(),
              ),
              icon: const Icon(Icons.auto_awesome, size: 15),
              label: const Text(
                '튜터에게 묻기',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AsideMetric extends StatelessWidget {
  const _AsideMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: StudentDensityTokens.muted,
          ),
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: 17,
          height: 1,
          fontWeight: FontWeight.w900,
          color: StudentDensityTokens.ink,
        ),
      ),
    ],
  );
}

int _currentStreak(List<ActivityDayRecord> days) {
  var count = 0;
  for (final day in days.reversed) {
    if (day.score <= 0) break;
    count++;
  }
  return count;
}

String _formatNumber(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (match) => ',',
);
