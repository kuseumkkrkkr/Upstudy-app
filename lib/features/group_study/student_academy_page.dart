import 'package:flutter/material.dart';

import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/course_service.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';

class StudentAcademyPage extends StatefulWidget {
  const StudentAcademyPage({super.key, required this.academyId});

  final String academyId;

  @override
  State<StudentAcademyPage> createState() => _StudentAcademyPageState();
}

class _StudentAcademyPageState extends State<StudentAcademyPage> {
  Academy? _academy;
  List<StudentAssignmentTask> _assignments = const [];
  List<AttendanceLog> _attendance = const [];
  List<Map<String, dynamic>> _schedule = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 필요한 변수는 학원 ID·현재 사용자·첫 수강 코스다.
  /// 작동 원리: 오늘 과제와 출석을 병렬 조회하고 코스 런타임 일정은 별도로 합쳐 학생용 작업 화면을 만든다.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ApiClient.instance.getMyProfile();
      final now = DateTime.now();
      final today = _dateKey(now);
      final responses = await Future.wait<dynamic>([
        ApiClient.instance.getAcademy(widget.academyId),
        ApiClient.instance.listMyAssignments(),
        ApiClient.instance.listAttendance(userId: profile.userId, date: today),
        CourseService.fetchMyCourses(),
      ]);
      final academy = responses[0] as ApiResponse<Academy>;
      final assignments =
          responses[1] as ApiResponse<List<StudentAssignmentTask>>;
      final attendance = responses[2] as ApiResponse<List<AttendanceLog>>;
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
        _academy = academy.data;
        _assignments = assignments.data ?? const [];
        _attendance = attendance.data ?? const [];
        _schedule = schedule;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  /// 필요한 변수는 날짜다. 서버 조회 계약과 같은 `YYYY-MM-DD` 문자열로 변환한다.
  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// 필요한 변수는 과제 마감일과 제출 상태다. 오늘 또는 미제출 과제를 우선 노출한다.
  List<StudentAssignmentTask> get _todayAssignments {
    final today = _dateKey(DateTime.now());
    final pending = _assignments
        .where((task) {
          final due = task.assignment.dueDate?.trim() ?? '';
          return due == today || task.submission.status != 'submitted';
        })
        .toList(growable: false);
    return pending.take(5).toList(growable: false);
  }

  /// 필요한 변수는 로딩·오류·과제·출석·시간표 상태다.
  /// 작동 원리: 모바일 한 열과 PC 3열에서 오늘 해야 할 행동을 통계보다 먼저 보여준다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_academy?.name ?? '학원')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('다시 불러오기'),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  StudentDensityPage(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const StudentDensityPageHeader(
                          eyebrow: 'TODAY AT ACADEMY',
                          title: '오늘 학원에서 할 일',
                          description: '과제, 출석, 수업 일정을 한 번에 확인하세요.',
                        ),
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cards = [
                              _AssignmentCard(tasks: _todayAssignments),
                              _AttendanceCard(logs: _attendance),
                              _ScheduleCard(schedule: _schedule),
                            ];
                            if (constraints.maxWidth < 780) {
                              return Column(
                                children: cards
                                    .map(
                                      (card) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: card,
                                      ),
                                    )
                                    .toList(growable: false),
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children:
                                  cards
                                      .map((card) => Expanded(child: card))
                                      .expand(
                                        (card) => [
                                          card,
                                          const SizedBox(width: 12),
                                        ],
                                      )
                                      .toList(growable: false)
                                    ..removeLast(),
                            );
                          },
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

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.tasks});

  final List<StudentAssignmentTask> tasks;

  @override
  Widget build(BuildContext context) => StudentDensitySurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(icon: Icons.assignment_outlined, title: '오늘 과제'),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          const Text('남은 과제가 없습니다.')
        else
          ...tasks.map(
            (task) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(task.assignment.title ?? task.assignment.kind),
              subtitle: Text(task.assignment.dueDate ?? '기한 없음'),
              trailing: Text(
                task.submission.status == 'submitted' ? '제출' : '진행 전',
              ),
            ),
          ),
      ],
    ),
  );
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.logs});

  final List<AttendanceLog> logs;

  @override
  Widget build(BuildContext context) {
    final present = logs.any((log) => log.status == 'present');
    return StudentDensitySurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(icon: Icons.how_to_reg_outlined, title: '오늘 출석'),
          const SizedBox(height: 20),
          Text(
            present ? '출석 완료' : '출석 확인 전',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(present ? '오늘 출석이 정상 반영됐습니다.' : '학원 도착 후 출석 상태를 확인하세요.'),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.schedule});

  final List<Map<String, dynamic>> schedule;

  @override
  Widget build(BuildContext context) => StudentDensitySurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          icon: Icons.calendar_today_outlined,
          title: '학습 시간표',
        ),
        const SizedBox(height: 12),
        if (schedule.isEmpty)
          const Text('등록된 일정이 없습니다.')
        else
          ...schedule
              .take(4)
              .map(
                (item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    (item['title'] ?? item['module_id'] ?? '학습').toString(),
                  ),
                  subtitle: Text((item['due_date'] ?? '기한 없음').toString()),
                ),
              ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ],
  );
}
