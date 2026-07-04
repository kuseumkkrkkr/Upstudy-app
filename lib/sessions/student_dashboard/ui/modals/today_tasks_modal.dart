import 'dart:ui';

import 'package:flutter/material.dart';

const _accentGreen = Color(0xFF1B402B);
const _lightGreen = Color(0xFF45BF63);
const _dividerColor = Color(0xFFE4E4E4);
const _chipGrey = Color(0xFFF2F2F2);

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
              child: Container(color: Colors.black.withOpacity(0.35)),
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
    final targetMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    final currentMonth = DateTime(_today.year, _today.month);
    if (targetMonth.isBefore(currentMonth)) return;

    final daysInMonth = DateUtils.getDaysInMonth(
      targetMonth.year,
      targetMonth.month,
    );
    final selectedDay = _selectedDate.day > daysInMonth
        ? daysInMonth
        : _selectedDate.day;
    final candidate = DateTime(targetMonth.year, targetMonth.month, selectedDay);

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

  @override
  Widget build(BuildContext context) {
    final tasks = _tasksByDate[_selectedDate] ?? const <String>[];
    final lockedTasks = _lockedTasksByDate[_selectedDate] ?? const <String>[];
    final isToday = _isSameDay(_selectedDate, _today);
    final selectedLabel = isToday ? '오늘' : _formatDate(_selectedDate);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        width: 1040,
        height: 580,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 26),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 4),
                  child: Text('오늘 할일', style: TextStyle(fontSize: 22)),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsetsDirectional.fromSTEB(24, 2, 24, 0),
              child: Text(
                '선택한 날짜의 일정을 추가하거나 삭제할 수 있습니다.',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _TaskPanel(
                        dateLabel: selectedLabel,
                        tasks: tasks,
                        lockedTasks: lockedTasks,
                        onAdd: _addTask,
                        onDelete: _deleteTask,
                        controller: _taskController,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Container(width: 1, color: _dividerColor),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _CalendarPanel(
                        today: _today,
                        selectedDate: _selectedDate,
                        visibleMonth: _visibleMonth,
                        tasksByDate: _tasksByDate,
                        lockedTasksByDate: _lockedTasksByDate,
                        onSelectDate: _selectDate,
                        onChangeMonth: _changeMonth,
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
                child: const Text(
                  '추가',
                  style: TextStyle(color: Colors.white),
                ),
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
    final canGoPrev = !DateTime(visibleMonth.year, visibleMonth.month - 1)
        .isBefore(DateTime(today.year, today.month));

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
              final hasTasks = (tasksByDate[dateOnly]?.isNotEmpty ?? false) ||
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
            Text(
              '$day',
              style: TextStyle(fontSize: 14, color: textColor),
            ),
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

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

Map<DateTime, List<String>> _cloneTasks(
  Map<DateTime, List<String>> source,
) {
  return {
    for (final entry in source.entries)
      _dateOnly(entry.key): List<String>.from(entry.value),
  };
}
