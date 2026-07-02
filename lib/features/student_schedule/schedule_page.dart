import 'package:flutter/material.dart';
import 'package:s11/shared/services/api/course_service.dart';
import 'package:s11/shared/theme/app_colors.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, this.courseId});

  static const routeName = '/schedule';
  final String? courseId;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  bool _loading = true;
  String? _error;
  bool _curriculumEnabled = false;
  String _status = 'in_progress';
  String _pauseReason = '';
  List<Map<String, dynamic>> _schedule = const [];

  @override
  void initState() {
    super.initState();
    _loadRuntimeSchedule();
  }

  Future<void> _loadRuntimeSchedule() async {
    String? courseId = widget.courseId;
    if (courseId == null || courseId.trim().isEmpty) {
      try {
        final my = await CourseService.fetchMyCourses();
        if (my.isNotEmpty) {
          courseId = my.first.id;
        }
      } catch (_) {}
    }
    if (courseId == null || courseId.trim().isEmpty) {
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
      final curriculum = (state['curriculum'] as Map?) ?? const {};
      final schedule = (curriculum['schedule'] as List?) ?? const [];
      setState(() {
        _curriculumEnabled = curriculum['enabled'] == true;
        _status = (state['status'] ?? 'in_progress').toString();
        _pauseReason = (state['pause_reason'] ?? '').toString();
        _schedule = schedule
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '일정을 불러오지 못했습니다: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '학습 일정',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _loadRuntimeSchedule,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!_curriculumEnabled)
                    _buildInfoCard(
                      title: '커리큘럼 미설정',
                      subtitle: '현재 코스는 기한/일정 제한 없이 무제한으로 진행됩니다.',
                    )
                  else ...[
                    _buildInfoCard(
                      title: _status == 'paused' ? '자동 일시정지됨' : '커리큘럼 적용 중',
                      subtitle: _status == 'paused' && _pauseReason.isNotEmpty
                          ? _pauseReason
                          : '모듈별 기한과 진행 제한이 적용됩니다.',
                    ),
                    const SizedBox(height: 12),
                    if (_schedule.isEmpty)
                      _buildInfoCard(
                        title: '생성된 일정 없음',
                        subtitle: '커리큘럼은 켜져 있지만 배정된 일정 데이터가 없습니다.',
                      )
                    else
                      ..._schedule.map(_buildScheduleTile),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard({required String title, required String subtitle}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleTile(Map<String, dynamic> item) {
    final moduleId = (item['module_id'] ?? '').toString();
    final title = (item['title'] ?? moduleId).toString();
    final dueDate = (item['due_date'] ?? '-').toString();
    final completed = item['completed'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(title),
        subtitle: Text('기한: $dueDate'),
        trailing: Chip(
          label: Text(completed ? '완료' : '진행 전'),
          backgroundColor: completed
              ? Colors.green.shade100
              : Colors.orange.shade100,
        ),
      ),
    );
  }
}
