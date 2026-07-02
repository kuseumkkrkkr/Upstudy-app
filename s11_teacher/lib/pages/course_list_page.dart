import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../widgets/design_tokens.dart';
import '../widgets/teacher_app_drawer.dart';
import 'course_builder_page.dart';

class CourseListPage extends StatefulWidget {
  const CourseListPage({super.key});

  static const String routeName = '/course-list';

  @override
  State<CourseListPage> createState() => _CourseListPageState();
}

class _CourseListPageState extends State<CourseListPage> {
  List<Map<String, dynamic>> _courses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ApiClient.instance.listCoursesV2(mineOnly: true);
      if (!mounted) return;
      setState(() {
        _courses = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _deleteCourse(String courseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('코스 삭제'),
        content: Text('"$courseId" 코스를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiClient.instance.deleteCourseV2(courseId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('코스가 삭제되었습니다.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  Future<void> _toggleVisibility(Map<String, dynamic> course) async {
    final id = course['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final current = course['is_public'] == true;
    try {
      final latest = await ApiClient.instance.getCourseV2(id);
      latest['is_public'] = !current;
      await ApiClient.instance.updateCourseV2(id, latest);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(!current ? '코스를 공개했습니다.' : '코스를 비공개했습니다.')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('노출 설정 변경 실패: $e')));
    }
  }

  void _openBuilder({String? courseId}) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CourseBuilderPage(initialCourseId: courseId),
          ),
        )
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final scale = courseUiScale(context);
    return Scaffold(
      endDrawer: const TeacherAppDrawer(currentRoute: CourseListPage.routeName),
      backgroundColor: kCourseBgGrey,
      appBar: AppBar(
        backgroundColor: kCourseGreen,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        title: const Text('코스 관리'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              tooltip: '메뉴',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: _buildBody(scale),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openBuilder(),
        backgroundColor: kCourseLightGreen,
        icon: const Icon(Icons.add),
        label: const Text('새 코스'),
      ),
    );
  }

  Widget _buildBody(double scale) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '오류: $_error',
              style: TextStyle(color: Colors.red, fontSize: 14 * scale),
            ),
            SizedBox(height: 16 * scale),
            ElevatedButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    if (_courses.isEmpty) {
      return Center(
        child: Text(
          '등록된 코스가 없습니다.',
          style: TextStyle(fontSize: 16 * scale, color: Colors.black54),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16 * scale),
      itemCount: _courses.length,
      itemBuilder: (context, index) {
        final c = _courses[index];
        final id = c['id']?.toString() ?? 'unknown';
        final title = c['title']?.toString() ?? '제목 없음';
        final description = c['description']?.toString() ?? '';
        final moduleCount = (c['modules'] as List<dynamic>?)?.length ?? 0;
        final difficulty = c['difficulty']?.toString() ?? '';
        final isPublic = c['is_public'] == true;

        return Dismissible(
          key: ValueKey(id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 20 * scale),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            await _deleteCourse(id);
            return false;
          },
          child: Card(
            margin: EdgeInsets.only(bottom: 12 * scale),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16 * scale),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20 * scale,
                vertical: 12 * scale,
              ),
              leading: Container(
                width: 48 * scale,
                height: 48 * scale,
                decoration: BoxDecoration(
                  color: kCourseLightGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12 * scale),
                ),
                child: Icon(
                  Icons.menu_book,
                  color: kCourseGreen,
                  size: 24 * scale,
                ),
              ),
              title: Text(
                title,
                style: TextStyle(
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.bold,
                  color: kCourseGreen,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (description.isNotEmpty)
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12 * scale,
                        color: Colors.black54,
                      ),
                    ),
                  SizedBox(height: 4 * scale),
                  Row(
                    children: [
                      _Badge(label: '모듈 $moduleCount개', scale: scale),
                      SizedBox(width: 6 * scale),
                      _Badge(label: isPublic ? '공개' : '비공개', scale: scale),
                      if (difficulty.isNotEmpty) ...[
                        SizedBox(width: 6 * scale),
                        _Badge(label: difficulty, scale: scale),
                      ],
                    ],
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: isPublic ? '비공개로 전환' : '공개로 전환',
                    icon: Icon(
                      isPublic ? Icons.visibility : Icons.visibility_off,
                      color: isPublic ? kCourseGreen : Colors.black45,
                    ),
                    onPressed: () => _toggleVisibility(c),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.black38,
                    size: 20 * scale,
                  ),
                ],
              ),
              onTap: () => _openBuilder(courseId: id),
            ),
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.scale});

  final String label;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 2 * scale),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8 * scale),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10 * scale,
          color: Colors.black54,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
