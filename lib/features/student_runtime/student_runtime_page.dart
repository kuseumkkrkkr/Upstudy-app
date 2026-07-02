import 'package:flutter/material.dart';

import 'student_runtime_service.dart';
import 'models.dart';

const Color _primary = Color(0xFF1B402B);
const Color _accent = Color(0xFF45BF63);

/// Student runtime page showing enrolled courses, modules, and session controls.
class StudentRuntimePage extends StatefulWidget {
  const StudentRuntimePage({super.key});

  static const routeName = '/student/runtime';

  @override
  State<StudentRuntimePage> createState() => _StudentRuntimePageState();
}

class _StudentRuntimePageState extends State<StudentRuntimePage> {
  List<RuntimeCourseModel> _courses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    final courses = await StudentRuntimeService.instance.loadEnrolledCourses();
    if (mounted) {
      setState(() {
        _courses = courses;
        _loading = false;
      });
    }
  }

  RuntimeCourseModel? get _firstCourse => _courses.isNotEmpty ? _courses.first : null;

  RuntimeModuleModel? get _nextAvailableModule {
    final course = _firstCourse;
    if (course == null) return null;
    for (final m in course.modules) {
      if (m.status == 'available') return m;
    }
    return null;
  }

  IconData _iconForType(RuntimeModuleType type) {
    switch (type) {
      case RuntimeModuleType.textbookView:
        return Icons.menu_book;
      case RuntimeModuleType.problemSolve:
        return Icons.calculate;
      case RuntimeModuleType.examSolve:
        return Icons.assignment;
      case RuntimeModuleType.wrongAnswerReview:
        return Icons.error_outline;
      case RuntimeModuleType.challenge:
        return Icons.emoji_events;
      case RuntimeModuleType.levelTest:
        return Icons.trending_up;
    }
  }

  Color _chipColorForStatus(String status) {
    switch (status) {
      case 'completed':
        return _accent;
      case 'available':
        return Colors.blue;
      case 'locked':
      default:
        return Colors.grey;
    }
  }

  String _descriptionForType(RuntimeModuleType type) {
    switch (type) {
      case RuntimeModuleType.textbookView:
        return '교재를 읽고 핵심 개념을 학습합니다.';
      case RuntimeModuleType.problemSolve:
        return '개념을 적용해 문제를 풀어봅니다.';
      case RuntimeModuleType.examSolve:
        return '실전 시험 형태로 실력을 점검합니다.';
      case RuntimeModuleType.wrongAnswerReview:
        return '틀린 문제를 복습하고 취약점을 보완합니다.';
      case RuntimeModuleType.challenge:
        return '도전 과제를 통해 심화 학습을 진행합니다.';
      case RuntimeModuleType.levelTest:
        return '현재 실력을 측정하는 레벨 테스트입니다.';
    }
  }

  void _showModuleDetail(RuntimeModuleModel module) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_iconForType(module.moduleType), color: _primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      module.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _descriptionForType(module.moduleType),
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                '예상 소요 시간: 15분',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    final course = _firstCourse;
                    if (course != null) {
                      await StudentRuntimeService.instance.startSession(course.id);
                    }
                    if (!mounted) return;
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Starting ${module.moduleType.name}...'),
                        ),
                      );
                  },
                  child: const Text('Start', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _continueLearning() async {
    final next = _nextAvailableModule;
    if (next == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('진행 가능한 모듈이 없습니다.')),
      );
      return;
    }
    final course = _firstCourse;
    if (course != null) {
      await StudentRuntimeService.instance.startSession(course.id);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Starting ${next.moduleType.name}...')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = _firstCourse;
    final progress = course == null ? 0.0 : course.overallProgress / 100.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primary,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'My Learning',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              // TODO: navigate to settings
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : Column(
              children: [
                // Overall progress
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course?.title ?? '코스 없음',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade300,
                          color: _accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(progress * 100).round()}% 완료',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                // Module list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: course?.modules.length ?? 0,
                    itemBuilder: (context, index) {
                      final module = course!.modules[index];
                      final isLocked = module.status == 'locked';
                      final isAvailable = module.status == 'available';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 1,
                        child: ListTile(
                          leading: Icon(
                            _iconForType(module.moduleType),
                            color: isLocked ? Colors.grey : _primary,
                          ),
                          title: Text(
                            module.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isLocked ? Colors.grey : Colors.black87,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _chipColorForStatus(module.status),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              module.status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          onTap: isAvailable ? () => _showModuleDetail(module) : null,
                        ),
                      );
                    },
                  ),
                ),
                // Continue Learning button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _continueLearning,
                      child: const Text(
                        'Continue Learning',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
