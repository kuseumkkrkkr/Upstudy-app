import 'dart:ui';

import 'package:flutter/material.dart';

const _accentGreen = Colors.black;
const _lightGreen = Color(0xFF8B8B90);
const _dividerColor = Color(0xFFE4E4E4);
const _chipGrey = Color(0xFFF2F2F2);

// 필요 변수: 날짜별 과제·잠금 과제·변경 콜백. 작동 원리: 편집 가능한 오늘 과제 모달을 블러 배경 위에 연다.
Future<T?> showTodayTasksModal<T>({
  required BuildContext context,
  required Map<DateTime, List<String>> tasksByDate,
  required ValueChanged<Map<DateTime, List<String>>> onTasksChanged,
  Map<DateTime, List<String>> lockedTasksByDate = const {},
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (context) {
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),
            Center(
              child: TodayTasksModal(
                initialTasksByDate: tasksByDate,
                lockedTasksByDate: lockedTasksByDate,
                onTasksChanged: onTasksChanged,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class TodayTasksModal extends StatefulWidget {
  const TodayTasksModal({
    super.key,
    required this.initialTasksByDate,
    required this.onTasksChanged,
    this.lockedTasksByDate = const {},
  });

  final Map<DateTime, List<String>> initialTasksByDate;
  final Map<DateTime, List<String>> lockedTasksByDate;
  final ValueChanged<Map<DateTime, List<String>>> onTasksChanged;

  @override
  State<TodayTasksModal> createState() => _TodayTasksModalState();
}

class _TodayTasksModalState extends State<TodayTasksModal> {
  final TextEditingController _taskController = TextEditingController();
  late final DateTime _today;
  late DateTime _selectedDate;
  late DateTime _visibleMonth;
  late Map<DateTime, List<String>> _tasksByDate;
  late Map<DateTime, List<String>> _lockedTasksByDate;
  bool _showCalendar = false;

  @override
  void initState() {
    super.initState();
    _today = _dateOnly(DateTime.now());
    _selectedDate = _today;
    _visibleMonth = DateTime(_today.year, _today.month);
    _tasksByDate = _cloneTasks(widget.initialTasksByDate);
    _lockedTasksByDate = _cloneTasks(widget.lockedTasksByDate);
    _tasksByDate.putIfAbsent(_selectedDate, () => []);
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onTasksChanged(_cloneTasks(_tasksByDate));
  }

  void _selectDate(DateTime date) {
    if (date.isBefore(_today)) return;
    setState(() => _selectedDate = _dateOnly(date));
    _tasksByDate.putIfAbsent(_selectedDate, () => []);
  }

  void _changeMonth(int delta) {
    final targetMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + delta,
    );
    final currentMonth = DateTime(_today.year, _today.month);
    if (targetMonth.isBefore(currentMonth)) return;

    final daysInMonth = DateUtils.getDaysInMonth(
      targetMonth.year,
      targetMonth.month,
    );
    final selectedDay = _selectedDate.day > daysInMonth
        ? daysInMonth
        : _selectedDate.day;
    final candidate = DateTime(
      targetMonth.year,
      targetMonth.month,
      selectedDay,
    );

    setState(() {
      _visibleMonth = targetMonth;
      _selectedDate = candidate.isBefore(_today) ? _today : candidate;
      _tasksByDate.putIfAbsent(_selectedDate, () => []);
    });
  }

  void _addTask() {
    final text = _taskController.text.trim();
    if (text.isEmpty) return;

    final tasks = List<String>.from(_tasksByDate[_selectedDate] ?? []);
    tasks.add(text);

    setState(() {
      _tasksByDate[_selectedDate] = tasks;
      _taskController.clear();
    });
    _notifyChange();
  }

  void _deleteTask(int index) {
    final tasks = List<String>.from(_tasksByDate[_selectedDate] ?? []);
    if (index < 0 || index >= tasks.length) return;
    tasks.removeAt(index);
    setState(() => _tasksByDate[_selectedDate] = tasks);
    _notifyChange();
  }

  /// 필요한 변수는 선택 날짜의 교사 과제·개인 일정·달력 표시 상태다.
  /// 작동 원리는 HTML의 오늘 할 일 요약을 먼저 보여주고 요청할 때만 편집 가능한 달력 작업공간으로 전환하는 것이다.
  @override
  Widget build(BuildContext context) {
    final tasks = _tasksByDate[_selectedDate] ?? const <String>[];
    final lockedTasks = _lockedTasksByDate[_selectedDate] ?? const <String>[];
    final isToday = _isSameDay(_selectedDate, _today);
    final selectedLabel = isToday ? '오늘' : _formatDate(_selectedDate);

    final size = MediaQuery.sizeOf(context);
    final mobile = size.width <= 780;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        width: mobile
            ? size.width
            : (size.width > 760 ? 720 : size.width * .94),
        height: mobile ? size.height : size.height * .9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(mobile ? 0 : 28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 18, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TODAY TASKS',
                          style: TextStyle(
                            color: Colors.black45,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '오늘 할 일',
                          style: TextStyle(
                            fontSize: 30,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE4E4E6)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
                child: _showCalendar
                    ? _buildCalendarWorkspace(
                        compact: size.width < 700,
                        selectedLabel: selectedLabel,
                        tasks: tasks,
                        lockedTasks: lockedTasks,
                      )
                    : _TodayTaskSummary(
                        tasks: tasks,
                        lockedTasks: lockedTasks,
                        onOpenCalendar: () =>
                            setState(() => _showCalendar = true),
                      ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE4E4E6)),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('닫기'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 필요한 변수는 모바일 여부·선택 날짜·과제 목록이다.
  /// 작동 원리는 기존 일정 추가·삭제와 달력 탐색 기능을 보존하되 작은 화면에서는 위아래로 배치하는 것이다.
  Widget _buildCalendarWorkspace({
    required bool compact,
    required String selectedLabel,
    required List<String> tasks,
    required List<String> lockedTasks,
  }) {
    final taskPanel = _TaskPanel(
      dateLabel: selectedLabel,
      tasks: tasks,
      lockedTasks: lockedTasks,
      onAdd: _addTask,
      onDelete: _deleteTask,
      controller: _taskController,
    );
    final calendar = _CalendarPanel(
      today: _today,
      selectedDate: _selectedDate,
      visibleMonth: _visibleMonth,
      tasksByDate: _tasksByDate,
      lockedTasksByDate: _lockedTasksByDate,
      onSelectDate: _selectDate,
      onChangeMonth: _changeMonth,
    );
    if (compact) {
      return Column(
        children: [
          Expanded(child: calendar),
          const SizedBox(height: 16),
          SizedBox(height: 220, child: taskPanel),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: taskPanel),
        const SizedBox(width: 18),
        Container(width: 1, color: _dividerColor),
        const SizedBox(width: 18),
        Expanded(child: calendar),
      ],
    );
  }
}

class _TodayTaskSummary extends StatelessWidget {
  const _TodayTaskSummary({
    required this.tasks,
    required this.lockedTasks,
    required this.onOpenCalendar,
  });

  final List<String> tasks;
  final List<String> lockedTasks;
  final VoidCallback onOpenCalendar;

  /// 필요한 변수는 교사 과제·개인 일정·달력 전환 콜백이다.
  /// 작동 원리는 HTML 시안처럼 오늘의 항목을 세로 행으로 요약하고 아래 버튼에서 상세 달력을 연다.
  @override
  Widget build(BuildContext context) {
    final entries =
        <({String title, String subtitle, IconData icon, bool active})>[
          for (var index = 0; index < lockedTasks.length; index++)
            (
              title: lockedTasks[index],
              subtitle: index == 0
                  ? '교사 과제 · 오늘 22:00 · 진행 상태 확인'
                  : '교사 과제 · 최소 학습 시간 확인',
              icon: index == 0 ? Icons.check_rounded : Icons.menu_book_outlined,
              active: index == 0,
            ),
          for (final task in tasks)
            (
              title: task,
              subtitle: '학생 일정 · 완료 체크와 편집 가능',
              icon: Icons.add_rounded,
              active: false,
            ),
        ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '별도 페이지를 열지 않고 홈에서 교사 과제와 개인 일정을 확인합니다.',
          style: TextStyle(color: Colors.black54, fontSize: 14),
        ),
        const SizedBox(height: 22),
        for (var index = 0; index < entries.length; index++) ...[
          _TodayTaskRow(entry: entries[index]),
          if (index < entries.length - 1) const SizedBox(height: 10),
        ],
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onOpenCalendar,
          child: const Text('일정 달력에서 보기'),
        ),
      ],
    );
  }
}

class _TodayTaskRow extends StatelessWidget {
  const _TodayTaskRow({required this.entry});

  final ({String title, String subtitle, IconData icon, bool active}) entry;

  /// 필요한 변수는 오늘 일정의 제목·설명·아이콘·강조 상태다.
  /// 작동 원리는 첫 진행 과제를 검정으로, 나머지를 흰색 테두리 행으로 표시하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: entry.active ? Colors.black : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: entry.active ? Colors.black : const Color(0xFFDCDCE0),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: entry.active ? Colors.white : const Color(0xFFF4F4F6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDCDCE0)),
          ),
          child: Icon(entry.icon, color: Colors.black),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style: TextStyle(
                  color: entry.active ? Colors.white : Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.subtitle,
                style: TextStyle(
                  color: entry.active ? Colors.white70 : Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TaskPanel extends StatelessWidget {
  const _TaskPanel({
    required this.dateLabel,
    required this.tasks,
    required this.lockedTasks,
    required this.onAdd,
    required this.onDelete,
    required this.controller,
  });

  final String dateLabel;
  final List<String> tasks;
  final List<String> lockedTasks;
  final VoidCallback onAdd;
  final ValueChanged<int> onDelete;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$dateLabel 일정',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '총 ${tasks.length + lockedTasks.length}건',
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: tasks.isEmpty && lockedTasks.isEmpty
              ? const Center(
                  child: Text(
                    '등록된 일정이 없습니다.',
                    style: TextStyle(fontSize: 14, color: Colors.black45),
                  ),
                )
              : ListView.separated(
                  itemCount: lockedTasks.length + tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index < lockedTasks.length) {
                      return _TaskRow(
                        label: lockedTasks[index],
                        locked: true,
                        onDelete: () {},
                      );
                    }
                    final taskIndex = index - lockedTasks.length;
                    return _TaskRow(
                      label: tasks[taskIndex],
                      onDelete: () => onDelete(taskIndex),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onAdd(),
                decoration: InputDecoration(
                  hintText: '일정을 입력하세요',
                  filled: true,
                  fillColor: _chipGrey,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('추가', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.label,
    required this.onDelete,
    this.locked = false,
  });

  final String label;
  final VoidCallback onDelete;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _chipGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (locked) ...[
            const Icon(Icons.school_outlined, size: 18, color: _accentGreen),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          if (locked)
            const Tooltip(
              message: '교사가 내준 숙제',
              child: Icon(Icons.lock_outline, size: 18, color: Colors.black45),
            )
          else
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDelete,
              tooltip: '삭제',
            ),
        ],
      ),
    );
  }
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.today,
    required this.selectedDate,
    required this.visibleMonth,
    required this.tasksByDate,
    required this.lockedTasksByDate,
    required this.onSelectDate,
    required this.onChangeMonth,
  });

  final DateTime today;
  final DateTime selectedDate;
  final DateTime visibleMonth;
  final Map<DateTime, List<String>> tasksByDate;
  final Map<DateTime, List<String>> lockedTasksByDate;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<int> onChangeMonth;

  @override
  Widget build(BuildContext context) {
    final monthLabel = '${visibleMonth.year}년 ${visibleMonth.month}월';
    final monthStart = DateTime(visibleMonth.year, visibleMonth.month);
    final daysInMonth = DateUtils.getDaysInMonth(
      visibleMonth.year,
      visibleMonth.month,
    );
    final leadingEmpty = monthStart.weekday % 7;
    final canGoPrev = !DateTime(
      visibleMonth.year,
      visibleMonth.month - 1,
    ).isBefore(DateTime(today.year, today.month));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: canGoPrev ? () => onChangeMonth(-1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              monthLabel,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            IconButton(
              onPressed: () => onChangeMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: const [
            _WeekdayLabel('일'),
            _WeekdayLabel('월'),
            _WeekdayLabel('화'),
            _WeekdayLabel('수'),
            _WeekdayLabel('목'),
            _WeekdayLabel('금'),
            _WeekdayLabel('토'),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1.1,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final dayNumber = index - leadingEmpty + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final date = DateTime(
                visibleMonth.year,
                visibleMonth.month,
                dayNumber,
              );
              final dateOnly = _dateOnly(date);
              final isDisabled = dateOnly.isBefore(today);
              final isSelected = _isSameDay(dateOnly, selectedDate);
              final isToday = _isSameDay(dateOnly, today);
              final hasTasks =
                  (tasksByDate[dateOnly]?.isNotEmpty ?? false) ||
                  (lockedTasksByDate[dateOnly]?.isNotEmpty ?? false);

              return _CalendarDayCell(
                day: dayNumber,
                isDisabled: isDisabled,
                isSelected: isSelected,
                isToday: isToday,
                hasTasks: hasTasks,
                onTap: isDisabled ? null : () => onSelectDate(dateOnly),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '과거 일자는 선택할 수 없습니다.',
          style: TextStyle(fontSize: 12, color: Colors.black45),
        ),
      ],
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.isDisabled,
    required this.isSelected,
    required this.isToday,
    required this.hasTasks,
    this.onTap,
  });

  final int day;
  final bool isDisabled;
  final bool isSelected;
  final bool isToday;
  final bool hasTasks;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = isSelected ? _accentGreen : Colors.transparent;
    final border = isToday
        ? Border.all(color: _lightGreen, width: 1.4)
        : Border.all(color: _dividerColor);
    final textColor = isSelected
        ? Colors.white
        : (isDisabled ? Colors.black26 : Colors.black87);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: border,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$day', style: TextStyle(fontSize: 14, color: textColor)),
            const SizedBox(height: 4),
            if (hasTasks)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : _lightGreen,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

Map<DateTime, List<String>> _cloneTasks(Map<DateTime, List<String>> source) {
  return {
    for (final entry in source.entries)
      _dateOnly(entry.key): List<String>.from(entry.value),
  };
}
