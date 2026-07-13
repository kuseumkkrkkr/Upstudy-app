import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../shared/theme/app_colors.dart';
import '../shared/ui/ios26/teacher_studio_shell.dart';
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
    return TeacherStudioShell(
      currentRoute: CourseListPage.routeName,
      eyebrow: 'COURSE LIBRARY',
      title: '코스 관리',
      description: '학습 흐름을 찾고, 공개 상태와 구성을 한 화면에서 관리합니다.',
      endDrawer: const TeacherAppDrawer(currentRoute: CourseListPage.routeName),
      onBack: Navigator.of(context).canPop()
          ? () => Navigator.of(context).pop()
          : null,
      actions: [
        TeacherStudioAction(
          label: '새 코스',
          icon: Icons.add_rounded,
          onTap: _saving ? null : () => _openBuilder(),
          primary: true,
        ),
        TeacherStudioAction(
          label: '새로고침',
          icon: Icons.refresh_rounded,
          onTap: _loading ? null : () => _load(resetPage: false),
        ),
      ],
      child: Column(
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
                      width: MediaQuery.sizeOf(context).width < 720
                          ? MediaQuery.sizeOf(context).width - 32
                          : 320,
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
                    _CapsuleButton(
                      label: '필터 초기화',
                      icon: Icons.filter_alt_off_rounded,
                      onTap: _loading
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
            _CapsuleButton(
              label: '다시 시도',
              icon: Icons.refresh_rounded,
              onTap: _load,
              primary: true,
            ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080
            ? 3
            : constraints.maxWidth >= 700
            ? 2
            : 1;
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 250,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _courses.length,
          itemBuilder: (context, index) {
            final course = _courses[index];
            final id = course['id']?.toString() ?? '';
            final selected = _selectedIds.contains(id);
            final public = course['is_public'] == true;
            final tags = _tagsFor(course);
            return _CourseCard(
              title: _courseTitle(course),
              description: _courseDescription(course),
              moduleCount: _moduleCountLabel(course),
              textbook: _textbookLabel(course),
              updatedAt: _updatedLabel(course),
              tags: tags,
              isPublic: public,
              selected: selected,
              onSelected: () {
                setState(() {
                  selected ? _selectedIds.remove(id) : _selectedIds.add(id);
                });
              },
              onEdit: () => _openBuilder(courseId: id),
              onVisibility: () => _toggleVisibility(course),
              onDelete: () => _deleteCourse(id, title: _courseTitle(course)),
            );
          },
        );
      },
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

/// 필요 변수: 문구, 아이콘, 실행 콜백, 강조 여부.
/// 작동 원리: 구형 Material 버튼 대신 동일한 높이의 캡슐 표면에서 기존 콜백을 실행한다.
class _CapsuleButton extends StatelessWidget {
  const _CapsuleButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? Colors.black : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 17),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD7D7DB)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: primary ? Colors.white : Colors.black,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: primary ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 필요 변수: 코스 표시 정보와 선택·수정·공개·삭제 콜백.
/// 작동 원리: 표의 좁은 작업 열을 넓은 카드로 바꾸되 모든 기존 관리 기능을 그대로 연결한다.
class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.title,
    required this.description,
    required this.moduleCount,
    required this.textbook,
    required this.updatedAt,
    required this.tags,
    required this.isPublic,
    required this.selected,
    required this.onSelected,
    required this.onEdit,
    required this.onVisibility,
    required this.onDelete,
  });

  final String title;
  final String description;
  final String moduleCount;
  final String textbook;
  final String updatedAt;
  final List<String> tags;
  final bool isPublic;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback onEdit;
  final VoidCallback onVisibility;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF0F0F2) : Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? Colors.black : const Color(0xFFDADADD),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Badge(label: isPublic ? '공개' : '비공개', scale: 1),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: '선택',
                    onPressed: onSelected,
                    icon: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: selected ? Colors.black : Colors.black38,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description.isEmpty ? '설명이 아직 없습니다.' : description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: Colors.black54,
                ),
              ),
              const Spacer(),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Badge(label: '모듈 $moduleCount', scale: 1),
                  ...tags.take(2).map((tag) => _Badge(label: tag, scale: 1)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      textbook == '-' ? updatedAt : textbook,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black45,
                      ),
                    ),
                  ),
                  _CardAction(
                    icon: Icons.edit_outlined,
                    tooltip: '수정',
                    onTap: onEdit,
                  ),
                  _CardAction(
                    icon: isPublic
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    tooltip: isPublic ? '비공개로 전환' : '공개로 전환',
                    onTap: onVisibility,
                  ),
                  _CardAction(
                    icon: Icons.delete_outline_rounded,
                    tooltip: '삭제',
                    onTap: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 필요 변수: 아이콘, 도움말, 실행 콜백.
/// 작동 원리: 카드 내부의 자주 쓰는 작업을 작은 원형 표면으로 구분해 오작동을 줄인다.
class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(backgroundColor: const Color(0xFFF1F1F3)),
      icon: Icon(icon, size: 17),
    );
  }
}
