import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../shared/theme/app_colors.dart';
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
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _courses = <Map<String, dynamic>>[];
  List<String> _availableTags = <String>[];
  final Set<String> _selectedIds = <String>{};

  bool _loading = true;
  bool _saving = false;
  String? _error;

  int _total = 0;
  int _page = 0;
  final int _pageSize = 12;
  String _visibility = 'all';
  String _sort = 'updated_at';
  bool _descending = true;
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final tags = await ApiClient.instance.getCourseHashTags();
      if (!mounted) return;
      setState(() {
        _availableTags = tags;
      });
    } catch (_) {
      // Tags are optional. Keep loading the course grid even if this fails.
    }
    await _load(resetPage: true);
  }

  Future<void> _load({bool resetPage = false}) async {
    final page = resetPage ? 0 : _page;
    setState(() {
      _loading = true;
      _error = null;
      _page = page;
    });
    try {
      final result = await ApiClient.instance.listCoursesV2Page(
        mineOnly: true,
        query: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        tag: _selectedTag,
        visibility: _visibility,
        limit: _pageSize,
        offset: page * _pageSize,
        sort: _sort,
        order: _descending ? 'desc' : 'asc',
        includeTotal: true,
      );
      if (!mounted) return;
      setState(() {
        _courses = result.items;
        _total = result.total;
        _selectedIds.removeWhere(
          (id) => !_courses.any((course) => course['id']?.toString() == id),
        );
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

  Future<void> _openBuilder({String? courseId}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CourseBuilderPage(initialCourseId: courseId),
      ),
    );
    if (mounted) {
      await _load(resetPage: false);
    }
  }

  Future<void> _deleteCourse(String courseId, {String? title}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('코스 삭제'),
        content: Text(
          title == null || title.isEmpty
              ? '이 코스를 삭제하시겠습니까?'
              : '"$title" 코스를 삭제하시겠습니까?',
        ),
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
      _selectedIds.remove(courseId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('코스가 삭제되었습니다.')));
      await _load(resetPage: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('선택 삭제'),
        content: Text('$count개 코스를 삭제하시겠습니까?'),
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

    setState(() => _saving = true);
    try {
      for (final id in _selectedIds.toList()) {
        await ApiClient.instance.deleteCourseV2(id);
      }
      if (!mounted) return;
      _selectedIds.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$count개 코스를 삭제했습니다.')));
      await _load(resetPage: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('선택 삭제 실패: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
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
      await _load(resetPage: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('노출 설정 변경 실패: $e')));
    }
  }

  String _courseTitle(Map<String, dynamic> course) {
    return course['title']?.toString().trim().isNotEmpty == true
        ? course['title'].toString()
        : '제목 없음';
  }

  String _courseDescription(Map<String, dynamic> course) {
    return course['description']?.toString() ?? '';
  }

  String _moduleCountLabel(Map<String, dynamic> course) {
    final count = (course['modules'] as List<dynamic>?)?.length ?? 0;
    return '$count개';
  }

  String _textbookLabel(Map<String, dynamic> course) {
    final title = course['textbook_id']?.toString().trim() ?? '';
    return title.isEmpty ? '-' : title;
  }

  String _updatedLabel(Map<String, dynamic> course) {
    final raw = course['updated_at'];
    final seconds = int.tryParse(raw?.toString() ?? '') ?? 0;
    if (seconds <= 0) return '-';
    final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$month-$day $hour:$minute';
  }

  List<String> _tagsFor(Map<String, dynamic> course) {
    return (course['tags'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scale = courseUiScale(context);
    final totalPages = _total == 0 ? 1 : (_total / _pageSize).ceil();
    final end = (_page * _pageSize) + _courses.length;
    return Scaffold(
      endDrawer: const TeacherAppDrawer(currentRoute: CourseListPage.routeName),
      backgroundColor: kCourseBgGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kCourseGreen,
        elevation: 0,
        surfaceTintColor: Colors.white,
        shadowColor: Colors.transparent,
        shape: const Border(bottom: BorderSide(color: AppColors.surfaceBorder)),
        automaticallyImplyLeading: Navigator.of(context).canPop(),
        title: const Text('코스 관리'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : () => _load(resetPage: false),
          ),
          Builder(
            builder: (context) => IconButton(
              tooltip: '메뉴',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _openBuilder(),
        backgroundColor: kCourseGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('새 코스'),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              16 * scale,
              16 * scale,
              16 * scale,
              12 * scale,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatPill(label: '전체', value: '$_total'),
                    _StatPill(label: '현재 페이지', value: '${_courses.length}'),
                    _StatPill(label: '선택', value: '${_selectedIds.length}'),
                    _StatPill(label: '페이지', value: '${_page + 1}/$totalPages'),
                  ],
                ),
                SizedBox(height: 12 * scale),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          labelText: '검색',
                          hintText: '제목, 설명',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            tooltip: '검색',
                            icon: const Icon(Icons.search_rounded),
                            onPressed: _loading
                                ? null
                                : () => _load(resetPage: true),
                          ),
                        ),
                        onSubmitted: (_) {
                          if (_loading) return;
                          _load(resetPage: true);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(_visibility),
                        initialValue: _visibility,
                        decoration: _fieldDecoration('노출'),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('전체')),
                          DropdownMenuItem(value: 'public', child: Text('공개')),
                          DropdownMenuItem(
                            value: 'private',
                            child: Text('비공개'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _visibility = value);
                          _load(resetPage: true);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(_sort),
                        initialValue: _sort,
                        decoration: _fieldDecoration('정렬'),
                        items: const [
                          DropdownMenuItem(
                            value: 'updated_at',
                            child: Text('최근 수정'),
                          ),
                          DropdownMenuItem(
                            value: 'created_at',
                            child: Text('최근 생성'),
                          ),
                          DropdownMenuItem(value: 'title', child: Text('제목')),
                          DropdownMenuItem(
                            value: 'target_ovr',
                            child: Text('목표 OVR'),
                          ),
                          DropdownMenuItem(
                            value: 'difficulty',
                            child: Text('난이도'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _sort = value);
                          _load(resetPage: true);
                        },
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: _descending ? '오름차순' : '내림차순',
                      onPressed: () {
                        setState(() => _descending = !_descending);
                        _load(resetPage: true);
                      },
                      icon: Icon(
                        _descending ? Icons.south_rounded : Icons.north_rounded,
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String?>(
                        key: ValueKey(_selectedTag),
                        initialValue: _selectedTag,
                        decoration: _fieldDecoration('태그'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('전체 태그'),
                          ),
                          ..._availableTags.map(
                            (tag) => DropdownMenuItem<String?>(
                              value: tag,
                              child: Text(tag),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedTag = value);
                          _load(resetPage: true);
                        },
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () {
                              _searchCtrl.clear();
                              setState(() {
                                _selectedTag = null;
                                _visibility = 'all';
                                _sort = 'updated_at';
                                _descending = true;
                              });
                              _load(resetPage: true);
                            },
                      icon: const Icon(Icons.filter_alt_off_rounded),
                      label: const Text('필터 초기화'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_selectedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Row(
                  children: [
                    Text(
                      '${_selectedIds.length}개 선택됨',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setState(_selectedIds.clear),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('선택 해제'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _saving ? null : _deleteSelected,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('선택 삭제'),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: _buildTable(scale)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Text(
                  _rangeLabel(),
                  style: TextStyle(color: Colors.black54, fontSize: 12 * scale),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loading || _page <= 0
                      ? null
                      : () {
                          setState(() => _page -= 1);
                          _load(resetPage: false);
                        },
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text('이전'),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_page + 1} / $totalPages',
                  style: TextStyle(fontSize: 12 * scale, color: Colors.black54),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _loading || end >= _total
                      ? null
                      : () {
                          setState(() => _page += 1);
                          _load(resetPage: false);
                        },
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: const Text('다음'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _rangeLabel() {
    if (_total == 0) return '0건';
    final start = (_page * _pageSize) + 1;
    final end = (_page * _pageSize) + _courses.length;
    return '$start - $end / $_total';
  }

  Widget _buildTable(double scale) {
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowHeight: 48,
                dataRowMinHeight: 64,
                dataRowMaxHeight: 84,
                showCheckboxColumn: true,
                columns: const [
                  DataColumn(label: Text('코스')),
                  DataColumn(label: Text('모듈')),
                  DataColumn(label: Text('노출')),
                  DataColumn(label: Text('교재')),
                  DataColumn(label: Text('태그')),
                  DataColumn(label: Text('수정일')),
                  DataColumn(label: Text('작업')),
                ],
                rows: _courses.map((course) {
                  final id = course['id']?.toString() ?? '';
                  final selected = _selectedIds.contains(id);
                  final public = course['is_public'] == true;
                  final tags = _tagsFor(course);
                  return DataRow(
                    selected: selected,
                    onSelectChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedIds.add(id);
                        } else {
                          _selectedIds.remove(id);
                        }
                      });
                    },
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 300,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _courseTitle(course),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _courseDescription(course),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(Text(_moduleCountLabel(course))),
                      DataCell(_Badge(label: public ? '공개' : '비공개', scale: 1)),
                      DataCell(Text(_textbookLabel(course))),
                      DataCell(
                        SizedBox(
                          width: 180,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: tags.isEmpty
                                ? [const Text('-')]
                                : tags
                                      .take(3)
                                      .map(
                                        (tag) => _Badge(label: tag, scale: 1),
                                      )
                                      .toList(),
                          ),
                        ),
                      ),
                      DataCell(Text(_updatedLabel(course))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '수정',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _openBuilder(courseId: id),
                            ),
                            IconButton(
                              tooltip: public ? '비공개로 전환' : '공개로 전환',
                              icon: Icon(
                                public
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                color: public ? kCourseGreen : Colors.black45,
                              ),
                              onPressed: () => _toggleVisibility(course),
                            ),
                            IconButton(
                              tooltip: '삭제',
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.red,
                              ),
                              onPressed: () => _deleteCourse(
                                id,
                                title: _courseTitle(course),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.surfaceBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.surfaceBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kCourseLightGreen, width: 2),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
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
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 3 * scale),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10 * scale,
          color: Colors.black54,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
