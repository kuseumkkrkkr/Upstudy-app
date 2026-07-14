import 'dart:async';

import 'package:flutter/material.dart';

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/course_service.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

class StudentAcademyPage extends StatefulWidget {
  const StudentAcademyPage({
    super.key,
    required this.academyId,
    this.initialAcademy,
    this.initialTasks,
    this.initialSchedule,
    this.initialAttendancePresent,
  });

  final String academyId;
  final Map<String, dynamic>? initialAcademy;
  final List<Map<String, dynamic>>? initialTasks;
  final List<Map<String, dynamic>>? initialSchedule;
  final bool? initialAttendancePresent;

  @override
  State<StudentAcademyPage> createState() => _StudentAcademyPageState();
}

class _StudentAcademyPageState extends State<StudentAcademyPage> {
  _AcademyView? _academy;
  List<_AcademyTask> _tasks = const [];
  List<Map<String, dynamic>> _schedule = const [];
  bool _attendancePresent = false;
  bool _loading = true;
  String? _error;

  /// 필요한 변수는 선택적 학원·과제·시간표·출석 초기값이다.
  /// 작동 원리는 모든 초기값이 있으면 즉시 렌더하고 실제 진입은 서버 데이터를 병렬 조회하는 것이다.
  @override
  void initState() {
    super.initState();
    if (widget.initialAcademy != null) {
      _academy = _AcademyView.fromMap(widget.initialAcademy!);
      _tasks = (widget.initialTasks ?? const [])
          .map(_AcademyTask.fromMap)
          .toList(growable: false);
      _schedule = widget.initialSchedule ?? const [];
      _attendancePresent = widget.initialAttendancePresent ?? false;
      _loading = false;
    } else {
      unawaited(_load());
    }
  }

  /// 필요한 변수는 학원 ID·현재 사용자·첫 수강 코스다.
  /// 작동 원리는 학원·과제·출석·코스를 병렬 조회하고 첫 코스 일정만 후속 1회 조회해 학생 작업 화면을 만든다.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ApiClient.instance.getMyProfile();
      final today = _dateKey(DateTime.now());
      final responses = await Future.wait<dynamic>([
        ApiClient.instance.getAcademy(widget.academyId),
        ApiClient.instance.listMyAssignments(),
        ApiClient.instance.listAttendance(userId: profile.userId, date: today),
        CourseService.fetchMyCourses(),
      ]);
      final academyResponse = responses[0] as ApiResponse<Academy>;
      final assignmentResponse =
          responses[1] as ApiResponse<List<StudentAssignmentTask>>;
      final attendanceResponse =
          responses[2] as ApiResponse<List<AttendanceLog>>;
      final courses = responses[3] as List;
      var schedule = const <Map<String, dynamic>>[];
      if (courses.isNotEmpty) {
        final state = await CourseService.runtimeState(
          courses.first.id.toString(),
        );
        final curriculum = state['curriculum'] as Map? ?? const {};
        schedule = (curriculum['schedule'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
      if (!mounted) return;
      setState(() {
        final academy = academyResponse.data;
        _academy = academy == null
            ? null
            : _AcademyView(
                name: academy.name,
                subtitle: academy.address ?? '중2 심화반',
                teacher: academy.adminUserId ?? '담당 선생님',
              );
        _tasks = (assignmentResponse.data ?? const [])
            .map(_AcademyTask.fromServer)
            .toList(growable: false);
        _attendancePresent = (attendanceResponse.data ?? const []).any(
          (log) => log.status == 'present',
        );
        _schedule = schedule;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '학원 정보를 불러오지 못했습니다.';
        _loading = false;
      });
    }
  }

  /// 필요한 변수는 날짜다.
  /// 작동 원리는 서버 조회 계약과 같은 YYYY-MM-DD 문자열로 변환하는 것이다.
  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// 필요한 변수는 현재 학원·과제·출석·시간표 상태다.
  /// 작동 원리는 HTML의 학원 정보, 오늘 할 일, 이번 주 수업 순서로 한 개 학생 작업 스크롤을 구성하는 것이다.
  @override
  Widget build(BuildContext context) {
    final academy = _academy;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (context) => Ios26TopBar(
                brandColor: Colors.black,
                showLevelIndicator: false,
                onMenu: () => toggleAppDrawer(context),
                items: studentTopNavItems(
                  context,
                  active: StudentTopDestination.social,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: FilledButton(
                        onPressed: _load,
                        child: const Text('다시 불러오기'),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 24, 14, 40),
                        children: [
                          const Text(
                            'ACADEMY',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.7,
                              color: Colors.black54,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '학원',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '오늘 수업과 과제를 한곳에서 확인합니다.',
                            style: TextStyle(color: Colors.black45),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () {},
                            child: const Text('학원 정보'),
                          ),
                          const SizedBox(height: 12),
                          _AcademyInfoCard(
                            academy: academy,
                            attendancePresent: _attendancePresent,
                            remainingTasks: _tasks
                                .where((task) => !task.completed)
                                .length,
                            nextClass: _schedule.isEmpty
                                ? '목 19:30'
                                : _schedule.first['time']?.toString() ??
                                      '목 19:30',
                          ),
                          const SizedBox(height: 12),
                          _TodayAcademyCard(
                            tasks: _tasks,
                            attendancePresent: _attendancePresent,
                          ),
                          const SizedBox(height: 12),
                          _AcademyTimetableCard(schedule: _schedule),
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

class _AcademyInfoCard extends StatelessWidget {
  const _AcademyInfoCard({
    required this.academy,
    required this.attendancePresent,
    required this.remainingTasks,
    required this.nextClass,
  });
  final _AcademyView? academy;
  final bool attendancePresent;
  final int remainingTasks;
  final String nextClass;

  /// 필요한 변수는 학원 메타·출석·다음 수업·남은 과제다.
  /// 작동 원리는 학원 로고와 세 핵심 상태를 HTML 상단 카드의 3열 통계로 표시하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: _academyCardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AIFLOW MATH ACADEMY',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.6,
            color: Colors.black54,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF202022),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'A',
                style: TextStyle(
                  color: Colors.white,
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
                    academy?.name ?? 'AIFlow 수학학원',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${academy?.subtitle ?? '중2 심화반'} · ${academy?.teacher ?? '담당 김선생'}',
                    style: const TextStyle(fontSize: 10, color: Colors.black45),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 32, color: Color(0xFFE0E0E2)),
        Row(
          children: [
            _AcademyMetric(
              label: '오늘 출석',
              value: attendancePresent ? '출석 완료' : '확인 전',
            ),
            _AcademyMetric(label: '다음 수업', value: nextClass),
            _AcademyMetric(label: '남은 과제', value: '$remainingTasks개'),
          ],
        ),
      ],
    ),
  );
}

class _AcademyMetric extends StatelessWidget {
  const _AcademyMetric({required this.label, required this.value});
  final String label;
  final String value;

  /// 필요한 변수는 상태 레이블과 값이다.
  /// 작동 원리는 세 통계를 동일 너비로 정렬해 빠르게 비교하게 하는 것이다.
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.black45)),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class _TodayAcademyCard extends StatelessWidget {
  const _TodayAcademyCard({
    required this.tasks,
    required this.attendancePresent,
  });
  final List<_AcademyTask> tasks;
  final bool attendancePresent;

  /// 필요한 변수는 오늘 과제와 출석 상태다.
  /// 작동 원리는 미완료 과제와 출석 확인을 시간순 구분선 행으로 최대 세 개 표시하는 것이다.
  @override
  Widget build(BuildContext context) {
    final visible = tasks.take(2).toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _academyCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.6,
                        color: Colors.black54,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '오늘 할 일',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _SmallBadge(
                label: '${tasks.where((task) => !task.completed).length}개 남음',
              ),
            ],
          ),
          const SizedBox(height: 24),
          for (final task in visible) _AcademyTaskRow(task: task),
          _AcademyTaskRow(
            task: _AcademyTask(
              title: '출석 확인',
              detail: attendancePresent
                  ? '학원 입실이 기록되었습니다.'
                  : '학원 도착 후 출석을 확인하세요.',
              time: attendancePresent ? '18:54' : '수업 전',
              action: attendancePresent ? '완료' : '확인',
              completed: attendancePresent,
            ),
          ),
        ],
      ),
    );
  }
}

class _AcademyTaskRow extends StatelessWidget {
  const _AcademyTaskRow({required this.task});
  final _AcademyTask task;

  /// 필요한 변수는 과제 시간·제목·설명·행동이다.
  /// 작동 원리는 HTML 오늘 할 일 카드의 시간 열과 본문 열을 구분선 행으로 구성하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFE2E2E4))),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            task.time,
            style: const TextStyle(fontSize: 10, color: Colors.black45),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: task.completed ? Colors.black38 : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                task.detail,
                style: const TextStyle(fontSize: 10, color: Colors.black45),
              ),
              const SizedBox(height: 10),
              Text(
                '${task.action} ›',
                style: const TextStyle(
                  fontSize: 10,
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

class _AcademyTimetableCard extends StatelessWidget {
  const _AcademyTimetableCard({required this.schedule});
  final List<Map<String, dynamic>> schedule;

  /// 필요한 변수는 코스 런타임 시간표다.
  /// 작동 원리는 이번 주 수업 제목과 첫 세 일정을 시안의 회색 수업 행으로 표시하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: _academyCardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TIMETABLE',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.6,
            color: Colors.black54,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '이번 주 수업',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 20),
        for (final item in schedule.take(3))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text('학'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item['title']?.toString() ?? '함수 심화',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  item['time']?.toString() ?? '목 19:30',
                  style: const TextStyle(fontSize: 10, color: Colors.black45),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label});
  final String label;

  /// 필요한 변수는 짧은 상태 문구다.
  /// 작동 원리는 회색 캡슐로 남은 과제 수를 제목 옆에 표시하는 것이다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F6),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: const Color(0xFFE0E0E2)),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
    ),
  );
}

class _AcademyView {
  const _AcademyView({
    required this.name,
    required this.subtitle,
    required this.teacher,
  });
  final String name;
  final String subtitle;
  final String teacher;

  /// 필요한 변수는 미리보기 학원 맵이다.
  /// 작동 원리는 이름·반·담당자 값을 안전하게 화면 모델로 변환하는 것이다.
  factory _AcademyView.fromMap(Map<String, dynamic> map) => _AcademyView(
    name: map['name']?.toString() ?? 'AIFlow 수학학원',
    subtitle: map['subtitle']?.toString() ?? '중2 심화반',
    teacher: map['teacher']?.toString() ?? '담당 김선생',
  );
}

class _AcademyTask {
  const _AcademyTask({
    required this.title,
    required this.detail,
    required this.time,
    required this.action,
    required this.completed,
  });
  final String title;
  final String detail;
  final String time;
  final String action;
  final bool completed;

  /// 필요한 변수는 미리보기 과제 맵이다.
  /// 작동 원리는 화면에 필요한 다섯 필드를 기본값과 함께 읽는 것이다.
  factory _AcademyTask.fromMap(Map<String, dynamic> map) => _AcademyTask(
    title: map['title']?.toString() ?? '학원 과제',
    detail: map['detail']?.toString() ?? '',
    time: map['time']?.toString() ?? '오늘',
    action: map['action']?.toString() ?? '시작',
    completed: map['completed'] == true,
  );

  /// 필요한 변수는 서버 과제·제출 상태다.
  /// 작동 원리는 과제 제목·메시지·마감일과 제출 여부를 학생 작업 행으로 변환하는 것이다.
  factory _AcademyTask.fromServer(StudentAssignmentTask task) => _AcademyTask(
    title: task.assignment.title ?? '학원 과제',
    detail: task.assignment.message ?? task.assignment.kind,
    time: task.assignment.dueDate ?? '오늘 마감',
    action: task.submission.status == 'submitted' ? '완료' : '이어하기',
    completed: task.submission.status == 'submitted',
  );
}

/// 필요한 변수는 없다.
/// 작동 원리는 학원 섹션에 동일한 흰 표면·모서리·테두리를 적용하는 것이다.
BoxDecoration _academyCardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: const Color(0xFFE0E0E2)),
);
