import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/teacher_operations_store.dart';
import '../shared/theme/app_colors.dart';
import '../shared/ui/ios26/ios26_chrome.dart';
import '../widgets/design_tokens.dart';

enum _OpsSection { finance, schedule }

enum _ScheduleScope { day, month }

class TeacherOperationsPage extends StatefulWidget {
  const TeacherOperationsPage({super.key});

  static const routeName = '/teacher-operations';

  @override
  State<TeacherOperationsPage> createState() => _TeacherOperationsPageState();
}

class _TeacherOperationsPageState extends State<TeacherOperationsPage> {
  final _store = TeacherOperationsStore.instance;
  final _financeTitleCtrl = TextEditingController();
  final _financeCategoryCtrl = TextEditingController(text: '수업료');
  final _financeAmountCtrl = TextEditingController();
  final _financeMemoCtrl = TextEditingController();
  final _scheduleTitleCtrl = TextEditingController();
  final _scheduleNoteCtrl = TextEditingController();

  _OpsSection _section = _OpsSection.finance;
  _ScheduleScope _scheduleScope = _ScheduleScope.day;
  FinanceEntryType _financeType = FinanceEntryType.income;
  DateTime _selectedDate = DateTime.now();
  DateTime _financeDate = DateTime.now();
  TimeOfDay _scheduleStart = TimeOfDay.now();
  TimeOfDay _scheduleEnd = TimeOfDay(
    hour: ((TimeOfDay.now().hour + 1).clamp(0, 23)).toInt(),
    minute: TimeOfDay.now().minute,
  );
  Future<_OperationsState>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _financeTitleCtrl.dispose();
    _financeCategoryCtrl.dispose();
    _financeAmountCtrl.dispose();
    _financeMemoCtrl.dispose();
    _scheduleTitleCtrl.dispose();
    _scheduleNoteCtrl.dispose();
    super.dispose();
  }

  Future<_OperationsState> _load() async {
    final financeStart = DateTime(_selectedDate.year, _selectedDate.month);
    final financeEnd = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
    ).subtract(const Duration(milliseconds: 1));
    final scheduleRange = _scheduleRange();
    final results = await Future.wait<Object>([
      _store.listFinanceEntries(start: financeStart, end: financeEnd),
      _store.financeSummary(start: financeStart, end: financeEnd),
      _store.listScheduleEntries(
        start: scheduleRange.start,
        end: scheduleRange.end,
      ),
    ]);
    return _OperationsState(
      financeEntries: results[0] as List<FinanceEntry>,
      financeSummary: results[1] as FinanceSummary,
      scheduleEntries: results[2] as List<ScheduleEntry>,
    );
  }

  _DateRange _scheduleRange() {
    if (_scheduleScope == _ScheduleScope.month) {
      final start = DateTime(_selectedDate.year, _selectedDate.month);
      return _DateRange(
        start,
        DateTime(
          _selectedDate.year,
          _selectedDate.month + 1,
        ).subtract(const Duration(milliseconds: 1)),
      );
    }
    final start = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    return _DateRange(
      start,
      start
          .add(const Duration(days: 1))
          .subtract(const Duration(milliseconds: 1)),
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Ios26TopBar(
              brandColor: kCourseGreen,
              title: '운영 관리',
              onBack: () => Navigator.of(context).pop(),
              items: const [Ios26NavItem(label: '로컬 저장', active: true)],
            ),
            Expanded(
              child: FutureBuilder<_OperationsState>(
                future: _future,
                builder: (context, snapshot) {
                  final data = snapshot.data ?? _OperationsState.empty();
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    children: [
                      _HeaderControls(
                        section: _section,
                        scheduleScope: _scheduleScope,
                        selectedDate: _selectedDate,
                        onSectionChanged: (section) {
                          setState(() {
                            _section = section;
                          });
                        },
                        onScheduleScopeChanged: (scope) {
                          setState(() {
                            _scheduleScope = scope;
                            _future = _load();
                          });
                        },
                        onPickDate: _pickSelectedDate,
                        onMoveDate: _moveSelectedDate,
                        onOpenCalendar: () =>
                            _openDeviceCalendar(_selectedDate),
                      ),
                      const SizedBox(height: 14),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const LinearProgressIndicator(minHeight: 2),
                      if (_section == _OpsSection.finance)
                        _FinancePanel(
                          selectedDate: _selectedDate,
                          entries: data.financeEntries,
                          summary: data.financeSummary,
                          titleCtrl: _financeTitleCtrl,
                          categoryCtrl: _financeCategoryCtrl,
                          amountCtrl: _financeAmountCtrl,
                          memoCtrl: _financeMemoCtrl,
                          type: _financeType,
                          occurredOn: _financeDate,
                          onTypeChanged: (value) {
                            setState(() {
                              _financeType = value;
                            });
                          },
                          onPickDate: _pickFinanceDate,
                          onSave: _saveFinance,
                          onDelete: _deleteFinance,
                        )
                      else
                        _SchedulePanel(
                          entries: data.scheduleEntries,
                          scope: _scheduleScope,
                          titleCtrl: _scheduleTitleCtrl,
                          noteCtrl: _scheduleNoteCtrl,
                          start: _scheduleStart,
                          end: _scheduleEnd,
                          onPickStart: () => _pickScheduleTime(start: true),
                          onPickEnd: () => _pickScheduleTime(start: false),
                          onSave: _saveSchedule,
                          onDelete: _deleteSchedule,
                          onOpenCalendar: _openDeviceCalendar,
                          onExportIcs: _exportScheduleIcs,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSelectedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      _financeDate = picked;
      _future = _load();
    });
  }

  void _moveSelectedDate(int direction) {
    final next = _scheduleScope == _ScheduleScope.month
        ? DateTime(_selectedDate.year, _selectedDate.month + direction)
        : _selectedDate.add(Duration(days: direction));
    setState(() {
      _selectedDate = next;
      _future = _load();
    });
  }

  Future<void> _pickFinanceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _financeDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _financeDate = picked;
      _selectedDate = picked;
      _future = _load();
    });
  }

  Future<void> _pickScheduleTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _scheduleStart : _scheduleEnd,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _scheduleStart = picked;
      } else {
        _scheduleEnd = picked;
      }
    });
  }

  Future<void> _saveFinance() async {
    final title = _financeTitleCtrl.text.trim();
    final amountText = _financeAmountCtrl.text.replaceAll(',', '').trim();
    final amount = double.tryParse(amountText);
    if (title.isEmpty || amount == null || amount <= 0) {
      _showMessage('항목명과 0보다 큰 금액을 입력하세요.');
      return;
    }
    final now = DateTime.now();
    await _store.upsertFinanceEntry(
      FinanceEntry(
        id: newLocalId('finance'),
        occurredOn: _financeDate,
        title: title,
        category: _financeCategoryCtrl.text.trim(),
        type: _financeType,
        amount: amount,
        memo: _financeMemoCtrl.text.trim(),
        createdAt: now,
        updatedAt: now,
      ),
    );
    _financeTitleCtrl.clear();
    _financeAmountCtrl.clear();
    _financeMemoCtrl.clear();
    _reload();
  }

  Future<void> _deleteFinance(FinanceEntry entry) async {
    await _store.deleteFinanceEntry(entry.id);
    _reload();
  }

  Future<void> _saveSchedule() async {
    final title = _scheduleTitleCtrl.text.trim();
    if (title.isEmpty) {
      _showMessage('일정명을 입력하세요.');
      return;
    }
    final start = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _scheduleStart.hour,
      _scheduleStart.minute,
    );
    var end = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _scheduleEnd.hour,
      _scheduleEnd.minute,
    );
    if (!end.isAfter(start)) {
      end = start.add(const Duration(hours: 1));
    }
    final now = DateTime.now();
    await _store.upsertScheduleEntry(
      ScheduleEntry(
        id: newLocalId('schedule'),
        startsAt: start,
        endsAt: end,
        title: title,
        note: _scheduleNoteCtrl.text.trim(),
        calendarSynced: false,
        createdAt: now,
        updatedAt: now,
      ),
    );
    _scheduleTitleCtrl.clear();
    _scheduleNoteCtrl.clear();
    _reload();
  }

  Future<void> _deleteSchedule(ScheduleEntry entry) async {
    await _store.deleteScheduleEntry(entry.id);
    _reload();
  }

  Future<void> _openDeviceCalendar(DateTime date) async {
    if (kIsWeb) {
      _showMessage('웹에서는 앱 내부 로컬 일정표를 사용합니다.');
      return;
    }
    Uri? uri;
    if (defaultTargetPlatform == TargetPlatform.android) {
      uri = Uri.parse(
        'content://com.android.calendar/time/${date.millisecondsSinceEpoch}',
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final appleEpoch = DateTime(2001).millisecondsSinceEpoch;
      final seconds = ((date.millisecondsSinceEpoch - appleEpoch) / 1000)
          .floor();
      uri = Uri.parse('calshow:$seconds');
    }
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showMessage('이 기기에서 캘린더 앱을 열 수 없습니다.');
    }
  }

  Future<void> _exportScheduleIcs(ScheduleEntry entry) async {
    final ics = _buildIcs(entry);
    final uri = Uri.dataFromString(
      ics,
      mimeType: 'text/calendar',
      encoding: utf8,
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showMessage('캘린더 파일을 열 수 없습니다.');
      return;
    }
    final now = DateTime.now();
    await _store.upsertScheduleEntry(
      ScheduleEntry(
        id: entry.id,
        startsAt: entry.startsAt,
        endsAt: entry.endsAt,
        title: entry.title,
        note: entry.note,
        calendarSynced: true,
        createdAt: entry.createdAt,
        updatedAt: now,
      ),
    );
    _reload();
  }

  String _buildIcs(ScheduleEntry entry) {
    final end = entry.endsAt ?? entry.startsAt.add(const Duration(hours: 1));
    return [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//S11 Teacher//Operations//KO',
      'BEGIN:VEVENT',
      'UID:${entry.id}@s11-teacher.local',
      'DTSTAMP:${_icsDate(DateTime.now())}',
      'DTSTART:${_icsDate(entry.startsAt)}',
      'DTEND:${_icsDate(end)}',
      'SUMMARY:${_escapeIcs(entry.title)}',
      'DESCRIPTION:${_escapeIcs(entry.note)}',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');
  }

  String _icsDate(DateTime value) {
    final utc = value.toUtc();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}T'
        '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  String _escapeIcs(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('\n', '\\n')
        .replaceAll(',', '\\,')
        .replaceAll(';', '\\;');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HeaderControls extends StatelessWidget {
  const _HeaderControls({
    required this.section,
    required this.scheduleScope,
    required this.selectedDate,
    required this.onSectionChanged,
    required this.onScheduleScopeChanged,
    required this.onPickDate,
    required this.onMoveDate,
    required this.onOpenCalendar,
  });

  final _OpsSection section;
  final _ScheduleScope scheduleScope;
  final DateTime selectedDate;
  final ValueChanged<_OpsSection> onSectionChanged;
  final ValueChanged<_ScheduleScope> onScheduleScopeChanged;
  final VoidCallback onPickDate;
  final ValueChanged<int> onMoveDate;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    return Ios26FrostedCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _OpsSegment<_OpsSection>(
            value: section,
            items: const [
              _SegmentItem(
                _OpsSection.finance,
                '재무',
                Icons.account_balance_wallet_rounded,
              ),
              _SegmentItem(
                _OpsSection.schedule,
                '일정',
                Icons.calendar_month_rounded,
              ),
            ],
            onChanged: onSectionChanged,
          ),
          if (section == _OpsSection.schedule)
            _OpsSegment<_ScheduleScope>(
              value: scheduleScope,
              items: const [
                _SegmentItem(_ScheduleScope.day, '일간', Icons.today_rounded),
                _SegmentItem(
                  _ScheduleScope.month,
                  '월간',
                  Icons.calendar_view_month_rounded,
                ),
              ],
              onChanged: onScheduleScopeChanged,
            ),
          _OpsIconAction(
            tooltip: '이전',
            icon: const Icon(Icons.chevron_left_rounded),
            onTap: () => onMoveDate(-1),
          ),
          _OpsAction(
            icon: Icons.event_rounded,
            label: _dateLabel(selectedDate, scheduleScope, section),
            onTap: onPickDate,
          ),
          _OpsIconAction(
            tooltip: '다음',
            icon: const Icon(Icons.chevron_right_rounded),
            onTap: () => onMoveDate(1),
          ),
          if (section == _OpsSection.schedule)
            _OpsIconAction(
              tooltip: '기기 캘린더 열기',
              icon: const Icon(Icons.open_in_new_rounded),
              onTap: onOpenCalendar,
            ),
        ],
      ),
    );
  }
}

class _FinancePanel extends StatelessWidget {
  const _FinancePanel({
    required this.selectedDate,
    required this.entries,
    required this.summary,
    required this.titleCtrl,
    required this.categoryCtrl,
    required this.amountCtrl,
    required this.memoCtrl,
    required this.type,
    required this.occurredOn,
    required this.onTypeChanged,
    required this.onPickDate,
    required this.onSave,
    required this.onDelete,
  });

  final DateTime selectedDate;
  final List<FinanceEntry> entries;
  final FinanceSummary summary;
  final TextEditingController titleCtrl;
  final TextEditingController categoryCtrl;
  final TextEditingController amountCtrl;
  final TextEditingController memoCtrl;
  final FinanceEntryType type;
  final DateTime occurredOn;
  final ValueChanged<FinanceEntryType> onTypeChanged;
  final VoidCallback onPickDate;
  final VoidCallback onSave;
  final ValueChanged<FinanceEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FinanceSummaryRow(summary: summary),
        const SizedBox(height: 14),
        Ios26FrostedCard(
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelTitle(
                icon: Icons.receipt_long_rounded,
                title: '${selectedDate.year}년 ${selectedDate.month}월 회계 작성',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<FinanceEntryType>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: '구분'),
                      items: FinanceEntryType.values
                          .map(
                            (entryType) => DropdownMenuItem(
                              value: entryType,
                              child: Text(entryType.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) onTypeChanged(value);
                      },
                    ),
                  ),
                  _FieldBox(
                    width: 190,
                    child: TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: '항목명'),
                    ),
                  ),
                  _FieldBox(
                    width: 160,
                    child: TextField(
                      controller: categoryCtrl,
                      decoration: const InputDecoration(labelText: '분류'),
                    ),
                  ),
                  _FieldBox(
                    width: 170,
                    child: TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: '금액'),
                    ),
                  ),
                  _OpsAction(
                    icon: Icons.today_rounded,
                    label: _shortDate(occurredOn),
                    onTap: onPickDate,
                  ),
                  _FieldBox(
                    width: 240,
                    child: TextField(
                      controller: memoCtrl,
                      decoration: const InputDecoration(labelText: '메모'),
                    ),
                  ),
                  _OpsAction(
                    icon: Icons.arrow_downward_rounded,
                    label: '항목 저장',
                    dark: true,
                    onTap: onSave,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _EntryList(
          emptyText: '이번 달 회계 항목이 없습니다.',
          children: [
            for (final entry in entries)
              _FinanceEntryTile(entry: entry, onDelete: () => onDelete(entry)),
          ],
        ),
      ],
    );
  }
}

class _SchedulePanel extends StatelessWidget {
  const _SchedulePanel({
    required this.entries,
    required this.scope,
    required this.titleCtrl,
    required this.noteCtrl,
    required this.start,
    required this.end,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onSave,
    required this.onDelete,
    required this.onOpenCalendar,
    required this.onExportIcs,
  });

  final List<ScheduleEntry> entries;
  final _ScheduleScope scope;
  final TextEditingController titleCtrl;
  final TextEditingController noteCtrl;
  final TimeOfDay start;
  final TimeOfDay end;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onSave;
  final ValueChanged<ScheduleEntry> onDelete;
  final ValueChanged<DateTime> onOpenCalendar;
  final ValueChanged<ScheduleEntry> onExportIcs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Ios26FrostedCard(
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelTitle(
                icon: Icons.edit_calendar_rounded,
                title: scope == _ScheduleScope.day ? '일간 스케줄 작성' : '월간 스케줄 작성',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _FieldBox(
                    width: 260,
                    child: TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: '일정명'),
                    ),
                  ),
                  _OpsAction(
                    icon: Icons.schedule_rounded,
                    label: start.format(context),
                    onTap: onPickStart,
                  ),
                  _OpsAction(
                    icon: Icons.schedule_send_rounded,
                    label: end.format(context),
                    onTap: onPickEnd,
                  ),
                  _FieldBox(
                    width: 300,
                    child: TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(labelText: '메모'),
                    ),
                  ),
                  _OpsAction(
                    icon: Icons.arrow_downward_rounded,
                    label: '일정 저장',
                    dark: true,
                    onTap: onSave,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _EntryList(
          emptyText: '선택한 기간의 일정이 없습니다.',
          children: [
            for (final entry in entries)
              _ScheduleEntryTile(
                entry: entry,
                onDelete: () => onDelete(entry),
                onOpenCalendar: () => onOpenCalendar(entry.startsAt),
                onExportIcs: () => onExportIcs(entry),
              ),
          ],
        ),
      ],
    );
  }
}

class _FinanceSummaryRow extends StatelessWidget {
  const _FinanceSummaryRow({required this.summary});

  final FinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final cards = [
          _MetricCard(
            icon: Icons.trending_up_rounded,
            label: '수입',
            value: _money(summary.income),
            color: const Color(0xFF237A4B),
          ),
          _MetricCard(
            icon: Icons.trending_down_rounded,
            label: '지출',
            value: _money(summary.expense),
            color: const Color(0xFF9B3A2E),
          ),
          _MetricCard(
            icon: Icons.account_balance_rounded,
            label: '잔액',
            value: _money(summary.balance),
            color: summary.balance >= 0
                ? const Color(0xFF27272A)
                : const Color(0xFF9B3A2E),
          ),
        ];
        if (compact) {
          return Column(
            children: [
              for (final card in cards) ...[
                card,
                if (card != cards.last) const SizedBox(height: 10),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (final card in cards) ...[
              Expanded(child: card),
              if (card != cards.last) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Ios26FrostedCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.emptyText, required this.children});

  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Ios26FrostedCard(
      radius: 24,
      padding: const EdgeInsets.all(8),
      child: children.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                emptyText,
                style: TextStyle(color: Colors.black.withValues(alpha: 0.58)),
              ),
            )
          : Column(children: children),
    );
  }
}

class _FinanceEntryTile extends StatelessWidget {
  const _FinanceEntryTile({required this.entry, required this.onDelete});

  final FinanceEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = entry.type == FinanceEntryType.income
        ? const Color(0xFF237A4B)
        : const Color(0xFF9B3A2E);
    return ListTile(
      leading: Icon(
        entry.type == FinanceEntryType.income
            ? Icons.add_circle_rounded
            : Icons.remove_circle_rounded,
        color: color,
      ),
      title: Text(
        entry.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${_shortDate(entry.occurredOn)} · ${entry.category}'
        '${entry.memo.isEmpty ? '' : ' · ${entry.memo}'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            _money(entry.amount),
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          IconButton(
            tooltip: '삭제',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _ScheduleEntryTile extends StatelessWidget {
  const _ScheduleEntryTile({
    required this.entry,
    required this.onDelete,
    required this.onOpenCalendar,
    required this.onExportIcs,
  });

  final ScheduleEntry entry;
  final VoidCallback onDelete;
  final VoidCallback onOpenCalendar;
  final VoidCallback onExportIcs;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        entry.calendarSynced
            ? Icons.event_available_rounded
            : Icons.event_note_rounded,
        color: kCourseGreen,
      ),
      title: Text(
        entry.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${_shortDate(entry.startsAt)} ${_clock(entry.startsAt)}'
        '${entry.endsAt == null ? '' : ' - ${_clock(entry.endsAt!)}'}'
        '${entry.note.isEmpty ? '' : ' · ${entry.note}'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: '기기 캘린더 열기',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: onOpenCalendar,
          ),
          IconButton(
            tooltip: 'ICS 내보내기',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: onExportIcs,
          ),
          IconButton(
            tooltip: '삭제',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: kCourseGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: kCourseGreen,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width - 72;
    return SizedBox(width: width > maxWidth ? maxWidth : width, child: child);
  }
}

class _OperationsState {
  const _OperationsState({
    required this.financeEntries,
    required this.financeSummary,
    required this.scheduleEntries,
  });

  final List<FinanceEntry> financeEntries;
  final FinanceSummary financeSummary;
  final List<ScheduleEntry> scheduleEntries;

  factory _OperationsState.empty() {
    return const _OperationsState(
      financeEntries: <FinanceEntry>[],
      financeSummary: FinanceSummary(income: 0, expense: 0),
      scheduleEntries: <ScheduleEntry>[],
    );
  }
}

class _DateRange {
  const _DateRange(this.start, this.end);

  final DateTime start;
  final DateTime end;
}

/// 운영 화면의 선택 항목에 필요한 값, 표시명, 아이콘을 묶는다.
class _SegmentItem<T> {
  const _SegmentItem(this.value, this.label, this.icon);

  final T value;
  final String label;
  final IconData icon;
}

/// Material 기본 세그먼트를 대신하는 흑백 캡슐 선택기다.
/// 현재 [value]와 각 항목을 비교해 선택 상태를 표시하고 [onChanged]로 원래 상태 변경을 전달한다.
class _OpsSegment<T> extends StatelessWidget {
  const _OpsSegment({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<_SegmentItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Material(
                color: item.value == value ? Colors.black : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => onChanged(item.value),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: 17,
                          color: item.value == value
                              ? Colors.white
                              : Colors.black54,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: item.value == value
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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

/// 날짜 선택과 저장 동작을 캡슐 버튼으로 통일한다.
class _OpsAction extends StatelessWidget {
  const _OpsAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.dark = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dark ? Colors.black : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: dark ? null : Border.all(color: AppColors.surfaceBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: dark ? Colors.white : Colors.black),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: dark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 이전·다음처럼 아이콘만 필요한 동작을 동일한 터치 영역으로 제공한다.
class _OpsIconAction extends StatelessWidget {
  const _OpsIconAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(width: 48, height: 48, child: Center(child: icon)),
        ),
      ),
    );
  }
}

String _dateLabel(
  DateTime date,
  _ScheduleScope scheduleScope,
  _OpsSection section,
) {
  if (section == _OpsSection.finance || scheduleScope == _ScheduleScope.month) {
    return '${date.year}년 ${date.month}월';
  }
  return '${date.year}년 ${date.month}월 ${date.day}일';
}

String _shortDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _clock(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _money(double value) {
  final sign = value < 0 ? '-' : '';
  final digits = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final reverseIndex = digits.length - index;
    buffer.write(digits[index]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(',');
    }
  }
  return '$sign${buffer.toString()}원';
}
