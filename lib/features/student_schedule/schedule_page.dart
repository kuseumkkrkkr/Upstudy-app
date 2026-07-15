import 'dart:async';

import 'package:flutter/material.dart';

import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
import 'package:s11/shared/services/api/course_service.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({
    super.key,
    this.courseId,
    this.initialSchedule,
    this.initialDate,
  });

  static const routeName = '/schedule';
  final String? courseId;
  final List<Map<String, dynamic>>? initialSchedule;
  final DateTime? initialDate;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _schedule = const [];
  bool _weekly = true;
  late DateTime _selectedDate;

  /// 필요한 변수는 선택 날짜와 선택적 초기 일정이다.
  /// 작동 원리는 미리보기 데이터가 있으면 즉시 렌더하고 실제 화면은 코스 런타임 일정을 한 번 조회하는 것이다.
  @override
  void initState() {
    super.initState();
    _selectedDate = DateUtils.dateOnly(widget.initialDate ?? DateTime.now());
    final initialSchedule = widget.initialSchedule;
    if (initialSchedule != null) {
      _schedule = initialSchedule;
      _loading = false;
    } else {
      unawaited(_loadRuntimeSchedule());
    }
  }

  /// 필요한 변수는 선택 코스 또는 첫 수강 코스다.
  /// 작동 원리는 코스 ID를 한 번 결정한 뒤 런타임의 curriculum.schedule만 화면 모델로 보관하는 것이다.
  Future<void> _loadRuntimeSchedule() async {
    String? courseId = widget.courseId;
    if (courseId == null || courseId.trim().isEmpty) {
      try {
        final myCourses = await CourseService.fetchMyCourses();
        if (myCourses.isNotEmpty) courseId = myCourses.first.id;
      } catch (_) {}
    }
    if (courseId == null || courseId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '코스 ID가 없어 일정을 불러올 수 없습니다.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = await CourseService.runtimeState(courseId);
      final curriculum = state['curriculum'] as Map? ?? const {};
      final schedule = curriculum['schedule'] as List? ?? const [];
      if (!mounted) return;
      setState(() {
        _schedule = schedule
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '일정을 불러오지 못했습니다.';
      });
    }
  }

  DateTime get _weekStart => _selectedDate.subtract(
    Duration(days: _selectedDate.weekday - DateTime.monday),
  );

  /// 필요한 변수는 현재 주 시작일과 이동 방향이다.
  /// 작동 원리는 7일 단위로 선택 날짜를 이동해 주간 카드 전체를 갱신하는 것이다.
  void _moveWeek(int delta) {
    setState(
      () => _selectedDate = _selectedDate.add(Duration(days: delta * 7)),
    );
  }

  /// 필요한 변수는 현재 화면 문맥이다.
  /// 작동 원리는 학습 일정에서도 학생 공용 상단 바와 모바일 드로어를 동일하게 제공하는 것이다.
  Widget _buildHeader(BuildContext context) => Ios26TopBar(
    brandColor: Colors.black,
    showLevelIndicator: false,
    onMenu: () => toggleAppDrawer(context),
    onTitleTap: () => Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainStudentPage()),
      (route) => false,
    ),
    items: studentTopNavItems(context, active: StudentTopDestination.learning),
  );

  /// 필요한 변수는 주간/월간 상태·선택 날짜·런타임 일정이다.
  /// 작동 원리는 HTML의 소개, 보기 전환, 주간 타임라인, 오늘 요약 순서로 한 개 스크롤을 구성하는 것이다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Builder(builder: _buildHeader),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadRuntimeSchedule,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 24, 14, 40),
                  children: [
                    Text(
                      _monthLabel(_selectedDate).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.7,
                        color: Colors.black54,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '학습 일정',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '주간의 하루 흐름과 월간 계획을 한 페이지에서 전환해 확인합니다.',
                      style: TextStyle(color: Colors.black45),
                    ),
                    const SizedBox(height: 18),
                    _ScheduleModeSwitch(
                      weekly: _weekly,
                      onChanged: (value) => setState(() => _weekly = value),
                    ),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      _EmptyScheduleCard(message: _error!)
                    else if (_weekly)
                      _WeeklyScheduleCard(
                        weekStart: _weekStart,
                        selectedDate: _selectedDate,
                        schedule: _schedule,
                        onSelectDate: (date) =>
                            setState(() => _selectedDate = date),
                        onMoveWeek: _moveWeek,
                      )
                    else
                      _MonthlyScheduleCard(
                        selectedDate: _selectedDate,
                        schedule: _schedule,
                        onSelectDate: (date) => setState(() {
                          _selectedDate = date;
                          _weekly = true;
                        }),
                      ),
                    const SizedBox(height: 12),
                    _TodaySummaryCard(schedule: _schedule),
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

class _ScheduleModeSwitch extends StatelessWidget {
  const _ScheduleModeSwitch({required this.weekly, required this.onChanged});
  final bool weekly;
  final ValueChanged<bool> onChanged;

  /// 필요한 변수는 주간 선택 여부다.
  /// 작동 원리는 두 동일 너비 버튼 중 활성 보기만 검은 캡슐로 표시하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: const Color(0xFFE9E9EC),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xFFDADADD)),
    ),
    child: Row(
      children: [
        _ModeButton(
          label: '주간(일별)',
          selected: weekly,
          onTap: () => onChanged(true),
        ),
        _ModeButton(
          label: '월간',
          selected: !weekly,
          onTap: () => onChanged(false),
        ),
      ],
    ),
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 필요한 변수는 레이블·선택 상태·전환 콜백이다.
  /// 작동 원리는 선택 상태에 따라 검정/투명 배경과 흰색/회색 글자를 전환하는 것이다.
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF202022) : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black45,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ),
  );
}

class _WeeklyScheduleCard extends StatelessWidget {
  const _WeeklyScheduleCard({
    required this.weekStart,
    required this.selectedDate,
    required this.schedule,
    required this.onSelectDate,
    required this.onMoveWeek,
  });
  final DateTime weekStart;
  final DateTime selectedDate;
  final List<Map<String, dynamic>> schedule;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<int> onMoveWeek;

  /// 필요한 변수는 주 시작일·선택일·일정 목록이다.
  /// 작동 원리는 7일 선택 행과 시간순 일정 행을 HTML의 한 흰색 카드에 결합하는 것이다.
  @override
  Widget build(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'THIS WEEK',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.6,
                        color: Colors.black54,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${weekStart.month}월 ${weekStart.day}일 – ${weekEnd.day}일',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _CircleAction(
                icon: Icons.chevron_left,
                onTap: () => onMoveWeek(-1),
              ),
              const SizedBox(width: 8),
              _CircleAction(
                icon: Icons.chevron_right,
                onTap: () => onMoveWeek(1),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (var index = 0; index < 7; index++) ...[
                Expanded(
                  child: _DayButton(
                    date: weekStart.add(Duration(days: index)),
                    selected: DateUtils.isSameDay(
                      weekStart.add(Duration(days: index)),
                      selectedDate,
                    ),
                    hasTask: index == 0 || index == 3 || index == 5,
                    onTap: onSelectDate,
                  ),
                ),
                if (index != 6) const SizedBox(width: 4),
              ],
            ],
          ),
          const Divider(height: 44, color: Color(0xFFE3E3E5)),
          if (schedule.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('선택한 날짜의 일정이 없습니다.')),
            )
          else
            for (final item in schedule.take(3)) _TimelineItem(data: item),
        ],
      ),
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.date,
    required this.selected,
    required this.hasTask,
    required this.onTap,
  });
  final DateTime date;
  final bool selected;
  final bool hasTask;
  final ValueChanged<DateTime> onTap;

  static const _days = ['월', '화', '수', '목', '금', '토', '일'];

  /// 필요한 변수는 날짜·선택 상태·과제 존재 여부다.
  /// 작동 원리는 선택일을 검은 카드로, 과제가 있는 날은 하단 점으로 표시하는 것이다.
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: () => onTap(date),
    child: Container(
      height: 82,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF202022) : const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDEDEE1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _days[date.weekday - 1],
            style: TextStyle(color: selected ? Colors.white70 : Colors.black45),
          ),
          const SizedBox(height: 6),
          Text(
            '${date.day}',
            style: TextStyle(
              color: selected ? Colors.white : Colors.black,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          if (hasTask)
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.black,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    ),
  );
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.data});
  final Map<String, dynamic> data;

  /// 필요한 변수는 일정의 시간·종류·제목·상태다.
  /// 작동 원리는 시간축과 흰색 일정 행을 분리해 시안의 16:00/19:30/22:00 흐름으로 표시하는 것이다.
  @override
  Widget build(BuildContext context) {
    final time = data['time']?.toString() ?? _timeFromDueDate(data['due_date']);
    final title = data['title']?.toString() ?? '학습 일정';
    final type = data['type']?.toString() ?? '과제';
    final detail = data['detail']?.toString() ?? '오늘 학습';
    final status = data['status']?.toString() ?? '예정';
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 66,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                time,
                style: const TextStyle(fontSize: 10, color: Colors.black45),
              ),
            ),
          ),
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0E0E2)),
              ),
              child: Stack(
                children: [
                  const Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: SizedBox(
                      width: 4,
                      child: ColoredBox(color: Colors.black),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            type,
                            style: const TextStyle(
                              fontSize: 10,
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
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                detail,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          status,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({required this.schedule});
  final List<Map<String, dynamic>> schedule;

  /// 필요한 변수는 오늘 일정 목록이다.
  /// 작동 원리는 완료 개수와 전체 개수로 진행률을 계산해 HTML 오늘 요약 카드에 표시하는 것이다.
  @override
  Widget build(BuildContext context) {
    final completed = schedule
        .where((item) => item['completed'] == true)
        .length;
    final total = schedule.isEmpty ? 3 : schedule.length;
    final progress = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘 요약',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$completed개 완료',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        color: Colors.black,
                        backgroundColor: const Color(0xFFE1E1E4),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ],
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

class _MonthlyScheduleCard extends StatelessWidget {
  const _MonthlyScheduleCard({
    required this.selectedDate,
    required this.schedule,
    required this.onSelectDate,
  });
  final DateTime selectedDate;
  final List<Map<String, dynamic>> schedule;
  final ValueChanged<DateTime> onSelectDate;

  /// 필요한 변수는 선택 월과 날짜 선택 콜백이다.
  /// 작동 원리는 월의 첫 요일과 일수를 계산해 7열 달력으로 표시하고 날짜를 누르면 주간 보기로 복귀하는 것이다.
  @override
  Widget build(BuildContext context) {
    final first = DateTime(selectedDate.year, selectedDate.month);
    final days = DateUtils.getDaysInMonth(
      selectedDate.year,
      selectedDate.month,
    );
    final leading = first.weekday - 1;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _monthLabel(selectedDate),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: leading + days,
            itemBuilder: (context, index) {
              if (index < leading) return const SizedBox.shrink();
              final day = index - leading + 1;
              final date = DateTime(selectedDate.year, selectedDate.month, day);
              final selected = DateUtils.isSameDay(date, selectedDate);
              return InkWell(
                onTap: () => onSelectDate(date),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? Colors.black : const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  /// 필요한 변수는 아이콘과 이동 콜백이다.
  /// 작동 원리는 40px 원형 테두리 버튼으로 주간 이전·다음 동작을 제공하는 것이다.
  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    icon: Icon(icon),
    style: IconButton.styleFrom(
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE0E0E2)),
    ),
  );
}

class _EmptyScheduleCard extends StatelessWidget {
  const _EmptyScheduleCard({required this.message});
  final String message;

  /// 필요한 변수는 빈 상태 안내 문구다.
  /// 작동 원리는 일정 카드와 같은 표면 안에 오류·빈 상태를 중앙 정렬하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(40),
    decoration: _cardDecoration(),
    child: Center(child: Text(message)),
  );
}

/// 필요한 변수는 날짜다.
/// 작동 원리는 영문 월과 연도를 시안 상단 레이블 형식으로 변환하는 것이다.
String _monthLabel(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

/// 필요한 변수는 서버 due_date 값이다.
/// 작동 원리는 ISO 날짜에서 시·분을 추출하고 실패하면 기본 시간을 반환하는 것이다.
String _timeFromDueDate(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return '20:00';
  return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
}

/// 필요한 변수는 없다.
/// 작동 원리는 모든 일정 섹션에 동일한 흰색 표면·둥근 모서리·얕은 테두리를 제공하는 것이다.
BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(24),
  border: Border.all(color: const Color(0xFFE1E1E3)),
);
