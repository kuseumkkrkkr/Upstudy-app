import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:s11/shared/data/models/course.dart';
import 'package:s11/shared/services/api/course_service.dart';
import 'package:s11/sessions/course/ui/course_catalog_page.dart';

Future<Course?> showCurriculumModal({required BuildContext context}) {
  return showDialog<Course>(
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
            const Center(child: CourseSelectModal()),
          ],
        ),
      );
    },
  );
}

class CourseSelectModal extends StatefulWidget {
  const CourseSelectModal({super.key});

  @override
  State<CourseSelectModal> createState() => _CourseSelectModalState();
}

class _CourseSelectModalState extends State<CourseSelectModal> {
  bool _loading = true;
  bool _editMode = false;
  List<Course> _courses = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final courses = await CourseService.fetchMyCourses();
      setState(() {
        // 완료 코스는 검색 필터의 미리보기에서만 확인하며 학습 선택 목록에서는 제외한다.
        _courses = courses
            .where((course) => !course.isCompleted)
            .toList(growable: false);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('코스를 불러오지 못했습니다.')));
    }
  }

  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final items = List<Course>.from(_courses);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    setState(() => _courses = items);
    try {
      await CourseService.reorderEnrollments(items.map((c) => c.id).toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('순서 저장 실패: $e')));
    }
  }

  Future<void> _handleDelete(Course course) async {
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('코스 삭제'),
            content: Text('${course.title} 한번 삭제하면 복구할 수 없습니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('삭제'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirm) return;
    try {
      await CourseService.unenroll(course.id);
      final updated = List<Course>.from(_courses)
        ..removeWhere((c) => c.id == course.id);
      setState(() => _courses = updated);
      if (updated.isNotEmpty) {
        await CourseService.reorderEnrollments(
          updated.map((c) => c.id).toList(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('코스가 삭제되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 980.0;
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 600.0;
        final width = math.min(980.0, maxW * 0.95);
        final height = math.min(560.0, maxH * 0.9);
        final scale = (width / 980.0).clamp(0.7, 1.0);

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18 * scale),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(18 * scale),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.close, size: 26 * scale),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    SizedBox(width: 8 * scale),
                    Text(
                      '코스를 선택하세요',
                      style: TextStyle(
                        fontSize: 22 * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (_courses.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => setState(() => _editMode = !_editMode),
                        icon: Icon(
                          _editMode ? Icons.check : Icons.edit,
                          size: 18 * scale,
                        ),
                        label: Text(_editMode ? '완료' : '편집'),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _courses.isEmpty
                    ? _EmptyCourses(scale: scale)
                    : _editMode
                    ? Padding(
                        padding: EdgeInsets.all(12 * scale),
                        child: ReorderableListView.builder(
                          itemCount: _courses.length,
                          onReorder: _handleReorder,
                          buildDefaultDragHandles: false,
                          itemBuilder: (context, index) {
                            final course = _courses[index];
                            return _EditableCourseTile(
                              key: ValueKey(course.id),
                              course: course,
                              scale: scale,
                              onDelete: () => _handleDelete(course),
                              index: index,
                            );
                          },
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.all(20 * scale),
                        itemCount: _courses.length,
                        separatorBuilder: (_, __) =>
                            SizedBox(height: 14 * scale),
                        itemBuilder: (context, index) {
                          final course = _courses[index];
                          return _CourseSelectCard(
                            course: course,
                            scale: scale,
                            onTap: () => Navigator.of(context).pop(course),
                          );
                        },
                      ),
              ),
              if (!_loading)
                Padding(
                  padding: EdgeInsets.only(bottom: 18 * scale),
                  child: Text(
                    '최대 4개의 코스를 수강할 수 있습니다.',
                    style: TextStyle(
                      fontSize: 12 * scale,
                      color: Colors.black54,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyCourses extends StatelessWidget {
  const _EmptyCourses({required this.scale});
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '현재 수강 중인 코스가 없습니다.',
            style: TextStyle(fontSize: 14 * scale, color: Colors.black87),
          ),
          SizedBox(height: 12 * scale),
          ElevatedButton(
            onPressed: () {
              final navigator = Navigator.of(context, rootNavigator: true);
              navigator.pop();
              Future.microtask(
                () => navigator.push(
                  MaterialPageRoute(builder: (_) => const CourseCatalogPage()),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B402B),
              foregroundColor: Colors.white,
              minimumSize: Size(180 * scale, 42 * scale),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12 * scale),
              ),
            ),
            child: const Text('+ 코스 수강하러 가기'),
          ),
        ],
      ),
    );
  }
}

class _CourseSelectCard extends StatelessWidget {
  const _CourseSelectCard({
    required this.course,
    required this.scale,
    required this.onTap,
  });

  final Course course;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progressPercent = (course.progress * 100).round();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16 * scale),
      child: Container(
        padding: EdgeInsets.all(16 * scale),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F6F6),
          borderRadius: BorderRadius.circular(16 * scale),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    style: TextStyle(
                      fontSize: 18 * scale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6 * scale),
                  Text(
                    course.description,
                    style: TextStyle(
                      fontSize: 12 * scale,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 12 * scale),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6 * scale),
                    child: LinearProgressIndicator(
                      value: course.progress,
                      minHeight: 6 * scale,
                      backgroundColor: const Color(0xFFE2E2E2),
                      color: const Color(0xFF45BF63),
                    ),
                  ),
                  SizedBox(height: 6 * scale),
                  Text(
                    '진행률 $progressPercent%',
                    style: TextStyle(
                      fontSize: 11 * scale,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12 * scale),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B402B),
                foregroundColor: Colors.white,
                minimumSize: Size(120 * scale, 40 * scale),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12 * scale),
                ),
              ),
              child: Text(
                course.isDemo ? '맛보기' : '선택',
                style: TextStyle(
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableCourseTile extends StatelessWidget {
  const _EditableCourseTile({
    super.key,
    required this.course,
    required this.scale,
    required this.onDelete,
    required this.index,
  });

  final Course course;
  final double scale;
  final VoidCallback onDelete;
  final int index;

  @override
  Widget build(BuildContext context) {
    final progressPercent = (course.progress * 100).round();
    return Card(
      key: key,
      margin: EdgeInsets.symmetric(vertical: 6 * scale),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12 * scale,
          vertical: 6 * scale,
        ),
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle),
        ),
        title: Text(
          course.title,
          style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '진행률 $progressPercent%',
          style: TextStyle(fontSize: 12 * scale, color: Colors.black54),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
