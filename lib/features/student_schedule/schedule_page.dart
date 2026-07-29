import 'dart:async';

import 'package:flutter/material.dart';

import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/course_service.dart';
import 'package:s11/shared/services/api/student_facing_api_error.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
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
  List<StudentScheduleTask> _personalTasks = const [];
  bool _savingPersonalTask = false;
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
      unawaited(_loadPersonalSchedule());
    }
  }

  /// 필요한 변수는 로그인 학생의 개인 일정 API다.
  /// 작동 원리: 코스 일정과 병렬로 한 번 조회하고 실패는 코스 일정 화면을 막지 않도록 빈 목록으로 격리한다.
  Future<void> _loadPersonalSchedule() async {
    try {
      final response = await ApiClient.instance.listMyStudentSchedule();
      if (!mounted) return;
      setState(() => _personalTasks = response.data ?? const []);
    } catch (_) {
      if (!mounted) return;
      setState(() => _personalTasks = const []);
    }
  }

  /// 필요한 변수는 현재 개인 일정 전체와 새 제목·날짜다.
  /// 작동 원리: 서버의 전체 동기화 계약에 맞춰 기존 날짜별 제목을 보존한 뒤 새 일정 하나를 추가하고 화면 상태를 즉시 갱신한다.
  Future<void> _savePersonalSchedule(_PersonalScheduleDraft draft) async {
    if (_savingPersonalTask) return;
    final tasksByDate = <DateTime, List<String>>{};
    for (final task in _personalTasks) {
      final date = DateTime.tryParse(task.date);
      final title = task.title.trim();
      if (date == null || title.isEmpty) continue;
      tasksByDate
          .putIfAbsent(DateUtils.dateOnly(date), () => <String>[])
          .add(title);
    }
    final selectedDate = DateUtils.dateOnly(draft.date);
    final titles = tasksByDate.putIfAbsent(selectedDate, () => <String>[]);
    if (titles.contains(draft.title)) {
      _showScheduleMessage('같은 날짜에 이미 등록된 일정이에요.');
      return;
    }
    titles.add(draft.title);

    setState(() => _savingPersonalTask = true);
    try {
      await ApiClient.instance.syncMyStudentSchedule(tasksByDate);
      final dateKey = _scheduleDateKey(selectedDate);
      if (!mounted) return;
      setState(() {
        _personalTasks = [
          ..._personalTasks,
          StudentScheduleTask(
            taskId: 'local-${DateTime.now().microsecondsSinceEpoch}',
            date: dateKey,
            title: draft.title,
          ),
        ];
        _selectedDate = selectedDate;
      });
      _showScheduleMessage('개인 일정을 저장했어요.');
    } catch (error) {
      if (!mounted) return;
      _showScheduleMessage(
        studentFacingApiError(
          error,
          fallback: '개인 일정을 저장하지 못했어요.',
          unavailable: '일정 저장 연결이 잠시 불안정해요. 잠시 후 다시 시도해 주세요.',
        ),
      );
    } finally {
      if (mounted) setState(() => _savingPersonalTask = false);
    }
  }

  /// 필요한 변수는 선택 날짜와 모바일 화면 문맥이다.
  /// 작동 원리: 레퍼런스형 둥근 바텀시트에서 제목·날짜를 검증하고 사용자가 저장을 확정한 경우에만 서버 동기화를 시작한다.
  Future<void> _openAddPersonalSchedule() async {
    final titleController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var draftDate = _selectedDate;
    final draft = await showModalBottomSheet<_PersonalScheduleDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .52),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SafeArea(
              top: false,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4B4B54),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '개인 일정 추가',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      '내 학습 계획에 표시할 일정과 날짜를 입력하세요.',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      key: const ValueKey('personal-schedule-title'),
                      controller: titleController,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      maxLength: 60,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? '일정 제목을 입력해 주세요.'
                          : null,
                      decoration: const InputDecoration(
                        labelText: '일정 제목',
                        hintText: '예: 이차함수 오답 복습',
                        prefixIcon: Icon(Icons.edit_calendar_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const ValueKey('personal-schedule-date'),
                      onPressed: () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: draftDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 730),
                          ),
                        );
                        if (selected == null) return;
                        setSheetState(
                          () => draftDate = DateUtils.dateOnly(selected),
                        );
                      },
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: Text(_scheduleDateLabel(draftDate)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const ValueKey('personal-schedule-save'),
                      onPressed: () {
                        if (formKey.currentState?.validate() != true) return;
                        Navigator.of(sheetContext).pop(
                          _PersonalScheduleDraft(
                            title: titleController.text.trim(),
                            date: draftDate,
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF202022),
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: const Text(
                        '일정 저장',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // 바텀시트 역방향 애니메이션 동안 입력 위젯이 컨트롤러를 잠시 더 참조하므로
    // 전환이 끝난 뒤 해제해 dispose 이후 접근을 막는다.
    await Future<void>.delayed(const Duration(milliseconds: 320));
    titleController.dispose();
    if (draft == null || !mounted) return;
    await _savePersonalSchedule(draft);
  }

  /// 필요한 변수는 일정 저장 결과 문구다.
  /// 작동 원리: 이전 안내를 지우고 현재 저장 결과 하나만 화면 하단에 표시한다.
  void _showScheduleMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
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
  /// 작동 원리는 PC에서는 공용 드로어를 유지하고 모바일에서는 하단 앱바에 탐색을 맡기는 것이다.
  Widget _buildHeader(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return Ios26TopBar(
      brandColor: Colors.black,
      showLevelIndicator: false,
      showUtilityActions: !mobile,
      onMenu: mobile ? null : () => toggleAppDrawer(context),
      onTitleTap: () => Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainStudentPage()),
        (route) => false,
      ),
      items: studentTopNavItems(
        context,
        active: StudentTopDestination.learning,
      ),
    );
  }

  /// 필요한 변수는 화면 너비·주간/월간 상태·선택 날짜·런타임 일정이다.
  /// 작동 원리는 780px 이하에서는 일정과 요약을 세로로, PC에서는 시안 비율의 2열로 배치하는 것이다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final personalSchedule = mobile
        ? _personalTasks
              .where(
                (task) => DateUtils.isSameDay(
                  DateTime.tryParse(task.date),
                  _selectedDate,
                ),
              )
              .map(
                (task) => <String, dynamic>{
                  'task_id': task.taskId,
                  'date': task.date,
                  'title': task.title,
                  'type': '개인',
                  'detail': '내 학습 일정',
                  'status': '예정',
                  'time': '자율',
                },
              )
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final visibleSchedule = <Map<String, dynamic>>[
      ..._schedule,
      ...personalSchedule,
    ];
    final scheduleCard = _loading
        ? const _ScheduleLoadingCard()
        : _error != null
        ? _EmptyScheduleCard(message: _error!)
        : _weekly
        ? _WeeklyScheduleCard(
            weekStart: _weekStart,
            selectedDate: _selectedDate,
            schedule: visibleSchedule,
            onSelectDate: (date) => setState(() => _selectedDate = date),
            onMoveWeek: _moveWeek,
          )
        : _MonthlyScheduleCard(
            selectedDate: _selectedDate,
            schedule: visibleSchedule,
            onSelectDate: (date) => setState(() => _selectedDate = date),
          );
    final summaryCard = _TodaySummaryCard(
      selectedDate: _selectedDate,
      schedule: visibleSchedule,
      savingPersonalTask: _savingPersonalTask,
      onAddPersonalSchedule: mobile ? _openAddPersonalSchedule : null,
    );

    return Scaffold(
      backgroundColor: StudentDensityTokens.background,
      drawer: mobile ? null : const AppDrawer(),
      bottomNavigationBar: mobile
          ? const MobileStudentBottomAppBar(activeRoute: '/schedule')
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Builder(builder: _buildHeader),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadRuntimeSchedule,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    StudentDensityPage(
                      padding: EdgeInsets.fromLTRB(
                        studentDensityHorizontalPadding(context),
                        studentDensityVerticalPadding(context),
                        studentDensityHorizontalPadding(context),
                        40,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          StudentDensityPageHeader(
                            eyebrow: _monthLabel(_selectedDate),
                            title: '학습 일정',
                            description: '주간의 하루 흐름과 월간 계획을 한 페이지에서 전환해 확인합니다.',
                            action: _ScheduleModeSwitch(
                              weekly: _weekly,
                              onChanged: (value) =>
                                  setState(() => _weekly = value),
                            ),
                          ),
                          SizedBox(height: mobile ? 14 : 20),
                          if (mobile)
                            Column(
                              key: const ValueKey('schedule-mobile-layout'),
                              children: [
                                scheduleCard,
                                const SizedBox(height: 14),
                                summaryCard,
                              ],
                            )
                          else
                            Row(
                              key: const ValueKey('schedule-desktop-layout'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 155, child: scheduleCard),
                                const SizedBox(width: 14),
                                Expanded(flex: 65, child: summaryCard),
                              ],
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
  Widget build(BuildContext context) => SizedBox(
    width: isStudentDensityMobile(context) ? double.infinity : 252,
    child: Container(
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
    final mobile = isStudentDensityMobile(context);
    final weekEnd = weekStart.add(const Duration(days: 6));
    return Container(
      padding: EdgeInsets.fromLTRB(
        mobile ? 14 : 20,
        mobile ? 18 : 24,
        mobile ? 14 : 20,
        18,
      ),
      decoration: mobile
          ? BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            )
          : _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!mobile) ...[
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
                    ],
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
  /// 작동 원리는 모바일의 미선택 날짜는 배경·외곽선을 없애고 선택일만 검은 면으로 강조하는 것이다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onTap(date),
      child: Container(
        height: mobile ? 76 : 82,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF202022)
              : mobile
              ? Colors.transparent
              : const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(14),
          border: mobile ? null : Border.all(color: const Color(0xFFDEDEE1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _days[date.weekday - 1],
              style: TextStyle(
                color: selected ? Colors.white70 : Colors.black45,
              ),
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
  const _TodaySummaryCard({
    required this.selectedDate,
    required this.schedule,
    required this.savingPersonalTask,
    this.onAddPersonalSchedule,
  });
  final DateTime selectedDate;
  final List<Map<String, dynamic>> schedule;
  final bool savingPersonalTask;
  final VoidCallback? onAddPersonalSchedule;

  static const _weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];

  /// 필요한 변수는 선택 날짜와 해당 일정 목록이다.
  /// 작동 원리는 완료율·간단 일정 목록·개인 일정 버튼을 PC 우측 또는 모바일 하단 요약 카드에 표시하는 것이다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final completed = schedule
        .where((item) => item['completed'] == true)
        .length;
    final total = schedule.length;
    final progress = total == 0 ? 0.0 : completed / total;
    final summaryItems = <Map<String, dynamic>>[
      ...schedule.where(
        (item) => (item['status']?.toString() ?? '').contains('진행'),
      ),
      ...schedule.where(
        (item) => !(item['status']?.toString() ?? '').contains('진행'),
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: mobile
          ? BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            )
          : _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '오늘 요약',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F8),
                  border: Border.all(color: const Color(0xFFE1E1E3)),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  _weekdays[selectedDate.weekday - 1],
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
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
          const SizedBox(height: 14),
          if (schedule.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  '선택한 날짜의 일정이 없습니다.',
                  style: TextStyle(color: Colors.black45, fontSize: 12),
                ),
              ),
            )
          else
            for (final item in summaryItems.take(3)) ...[
              _SummaryTaskItem(data: item),
              const SizedBox(height: 8),
            ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: savingPersonalTask
                  ? null
                  : onAddPersonalSchedule ??
                        () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('개인 일정 추가 기능을 준비 중입니다.'),
                          ),
                        ),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: Text(savingPersonalTask ? '저장 중…' : '개인 일정 추가'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: const Color(0xFF202022),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalScheduleDraft {
  const _PersonalScheduleDraft({required this.title, required this.date});

  final String title;
  final DateTime date;
}

class _SummaryTaskItem extends StatelessWidget {
  const _SummaryTaskItem({required this.data});
  final Map<String, dynamic> data;

  /// 필요한 변수는 일정 종류·제목·상세·상태다.
  /// 작동 원리는 진행 중 일정은 검은 배경으로 강조하고 나머지는 얇은 테두리 행으로 요약한다.
  @override
  Widget build(BuildContext context) {
    final title = data['title']?.toString() ?? '학습 일정';
    final type = data['type']?.toString() ?? '과제';
    final detail = data['detail']?.toString() ?? '오늘 학습';
    final status = data['status']?.toString() ?? '예정';
    final active = status.contains('진행');
    final foreground = active ? Colors.white : Colors.black;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF202022) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? const Color(0xFF202022) : const Color(0xFFE0E0E2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? Colors.white : const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E2E4)),
            ),
            child: Text(
              type,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? Colors.white60 : Colors.black45,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: foreground, size: 18),
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

class _ScheduleLoadingCard extends StatelessWidget {
  const _ScheduleLoadingCard();

  /// 필요한 변수는 없다.
  /// 작동 원리는 데이터 조회 중에도 완성된 카드 영역을 유지해 PC 2열과 모바일 세로 배치의 흔들림을 줄이는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 260),
    decoration: _cardDecoration(),
    alignment: Alignment.center,
    child: const CircularProgressIndicator(color: Colors.black),
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

/// 필요한 변수는 개인 일정 날짜다.
/// 작동 원리: API 동기화에 사용하는 로컬 시간대의 YYYY-MM-DD 키를 만든다.
String _scheduleDateKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// 필요한 변수는 개인 일정 날짜다.
/// 작동 원리: 모바일 날짜 선택 버튼에 연·월·일과 요일을 함께 표시한다.
String _scheduleDateLabel(DateTime date) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  return '${date.year}년 ${date.month}월 ${date.day}일 (${weekdays[date.weekday - 1]})';
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
