import 'dart:async';

import 'package:flutter/material.dart';

import 'package:s11/sessions/course/session/course_learning_page.dart';
import 'package:s11/sessions/course/ui/course_detail_page.dart';
import 'package:s11/sessions/course/ui/course_html_dialogs.dart';
import 'package:s11/shared/business/repositories/rating_store.dart';
import 'package:s11/shared/data/models/course.dart';
import 'package:s11/shared/services/api/course_service.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

enum CourseEntryTarget { learning, detail }

/// 필요한 변수는 선택 코스의 등록·완료 상태다.
/// 작동 원리: 진행 중 등록 코스만 학습으로 직행하고 완료·미등록 코스는 읽기 가능한 상세로 보낸다.
CourseEntryTarget courseEntryTarget(Course course) =>
    course.isEnrolled && !course.isCompleted
    ? CourseEntryTarget.learning
    : CourseEntryTarget.detail;

typedef CourseFeedLoader =
    Future<List<Course>> Function({required String keyword, double? recommend});

const double _ratingOvrFloor = 1200;
const double _ratingOvrDivider = 128;

/// 필요한 변수는 서버 레이팅 또는 이미 환산된 OVR 값이다.
/// 작동 원리: 원시 레이팅은 OVR로 환산하고 작은 값은 화면 표시값으로 그대로 사용한다.
String _formatVisibleOvr(num value) {
  final raw = value.toDouble();
  if (raw.isNaN || raw <= 0) return '18.6';
  if (raw < _ratingOvrFloor) return raw.toStringAsFixed(1);
  return ((raw - _ratingOvrFloor) / _ratingOvrDivider).toStringAsFixed(1);
}

class CourseCatalogPage extends StatefulWidget {
  const CourseCatalogPage({super.key, this.courseFeedLoader});

  final CourseFeedLoader? courseFeedLoader;

  @override
  State<CourseCatalogPage> createState() => _CourseCatalogPageState();
}

class _CourseCatalogPageState extends State<CourseCatalogPage> {
  final TextEditingController _searchController = TextEditingController();
  Future<List<Course>>? _future;
  double? _lastRecommend;
  String _filter = '전체';

  @override
  void initState() {
    super.initState();
    RatingStore.notifier.addListener(_handleRatingChange);
    _load();
  }

  @override
  void dispose() {
    RatingStore.notifier.removeListener(_handleRatingChange);
    _searchController.dispose();
    super.dispose();
  }

  /// 필요한 변수는 최신 레이팅 OVR이다.
  /// 작동 원리: 추천 기준이 실제로 달라졌을 때만 코스 피드를 다시 요청한다.
  void _handleRatingChange() {
    final next = _currentRecommendOvr();
    if ((_lastRecommend ?? -1) != next) _load();
  }

  /// 필요한 변수는 현재 레이팅 저장소 값이다.
  /// 작동 원리: 서버 원시 레이팅을 추천 API가 받는 OVR 단위로 변환한다.
  double? _currentRecommendOvr() {
    final rating = RatingStore.notifier.value.ovr;
    if (rating <= 0) return null;
    return rating / _ratingOvrDivider;
  }

  /// 필요한 변수는 검색어와 추천 OVR이다.
  /// 작동 원리: 주입 로더 또는 실제 공개·내 코스 병합 로더를 한 번 실행해 FutureBuilder를 갱신한다.
  void _load() {
    final keyword = _searchController.text.trim();
    final recommend = _currentRecommendOvr();
    _lastRecommend = recommend;
    setState(() {
      _future = (widget.courseFeedLoader ?? _loadCourseFeed)(
        keyword: keyword,
        recommend: recommend,
      );
    });
  }

  /// 필요한 변수는 검색어·추천 OVR·공개 코스·내 코스다.
  /// 작동 원리: 두 응답을 ID 기준으로 합치고 검색어가 있으면 제목·설명·태그를 다시 검증한다.
  Future<List<Course>> _loadCourseFeed({
    required String keyword,
    required double? recommend,
  }) async {
    final publicCourses = await CourseService.fetchCourses(
      keyword: keyword.isEmpty ? null : keyword,
      recommendOvr: recommend,
    );
    final mine = await CourseService.fetchMyCourses().catchError(
      (_) => const <Course>[],
    );
    final byId = <String, Course>{};
    for (final course in [...publicCourses, ...mine]) {
      if (course.id.trim().isEmpty) continue;
      if (keyword.isNotEmpty && !_matchesKeyword(course, keyword)) continue;
      byId[course.id] = course;
    }
    return byId.values.toList(growable: false);
  }

  /// 필요한 변수는 코스 제목·설명·태그와 검색어다.
  /// 작동 원리: 대소문자를 제거한 뒤 세 필드 중 하나라도 포함하면 검색 결과에 유지한다.
  bool _matchesKeyword(Course course, String keyword) {
    final query = keyword.trim().toLowerCase();
    if (query.isEmpty) return true;
    return course.title.toLowerCase().contains(query) ||
        course.description.toLowerCase().contains(query) ||
        course.focusTags.any((tag) => tag.toLowerCase().contains(query));
  }

  /// 필요한 변수는 현재 필터와 코스 상태다.
  /// 작동 원리: HTML 필터 문구를 등록·추천·완료 상태에 대응시켜 화면 목록만 즉시 좁힌다.
  bool _matchesFilter(Course course) {
    return switch (_filter) {
      '수강 중' => course.isEnrolled && !course.isCompleted,
      '추천' => !course.isCompleted,
      '배정됨' => course.status == 'assigned',
      '완료 코스' => course.isCompleted,
      _ => true,
    };
  }

  /// 필요한 변수는 선택 코스의 등록·완료 상태다.
  /// 작동 원리: 수강 중 코스는 학습으로, 완료·미등록 코스는 상세로 이동한다.
  void _openCourse(Course course) {
    final page = courseEntryTarget(course) == CourseEntryTarget.learning
        ? CourseLearningPage(course: course)
        : CourseDetailPage(course: course);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  /// 필요한 변수는 비동기 코스 목록·현재 필터·화면 폭이다.
  /// 작동 원리: HTML DOM 순서와 반응형 규칙을 그대로 따라 코스 탐색 화면을 구성한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final rating = _formatVisibleOvr(RatingStore.notifier.value.ovr);
    return Scaffold(
      backgroundColor: StudentDensityTokens.background,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Ios26TopBar(
              brandColor: StudentDensityTokens.dark,
              onMenu: () => toggleAppDrawer(context),
              showLevelIndicator: false,
              items: studentTopNavItems(
                context,
                active: StudentTopDestination.courses,
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Course>>(
                future: _future,
                builder: (context, snapshot) {
                  final allCourses = snapshot.data ?? const <Course>[];
                  final courses = allCourses
                      .where(_matchesFilter)
                      .toList(growable: false);
                  final active = allCourses
                      .where(
                        (course) => course.isEnrolled && !course.isCompleted,
                      )
                      .take(2)
                      .toList(growable: false);
                  final recommended = allCourses
                      .where((course) => !course.isCompleted)
                      .take(4)
                      .toList(growable: false);
                  return SingleChildScrollView(
                    child: StudentDensityPage(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CoursePageHead(rating: rating),
                          const SizedBox(height: 16),
                          _CourseSearchDock(
                            controller: _searchController,
                            filter: _filter,
                            onFilter: (value) =>
                                setState(() => _filter = value),
                            onSearch: _load,
                          ),
                          const SizedBox(height: 12),
                          _ResumeCourses(
                            courses: active,
                            loading:
                                snapshot.connectionState ==
                                ConnectionState.waiting,
                            onOpen: _openCourse,
                            onReorder: () => showCourseReorderDialog(
                              context,
                              courses: active,
                              onSaved: _load,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (recommended.isNotEmpty)
                            _RecommendationSection(
                              courses: recommended,
                              onOpen: _openCourse,
                              onCompare: () => showCourseCompareDialog(
                                context,
                                courses: recommended,
                              ),
                            ),
                          const SizedBox(height: 14),
                          _CourseLibrary(
                            courses: courses,
                            loading:
                                snapshot.connectionState ==
                                ConnectionState.waiting,
                            mobile: mobile,
                            onOpen: _openCourse,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoursePageHead extends StatelessWidget {
  const _CoursePageHead({required this.rating});

  final String rating;

  /// 필요한 변수는 현재 OVR과 화면 폭이다.
  /// 작동 원리: PC는 제목 우측, 모바일은 제목 아래 전체 폭에 OVR 카드를 배치한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final copy = const StudentDensityPageHeader(
      eyebrow: 'LEARNING PATH',
      title: '코스',
      description: '현재 학습을 이어가거나 내 실력에 맞는 다음 코스를 선택하세요.',
    );
    final chip = Container(
      constraints: BoxConstraints(minHeight: mobile ? 52 : 72),
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 13 : 18,
        vertical: mobile ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(mobile ? 20 : 24),
        border: Border.all(color: StudentDensityTokens.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: mobile
          ? Row(
              children: [
                const StudentDensityEyebrow('MY OVR'),
                const SizedBox(width: 8),
                Text(
                  rating,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.3,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'B Tier',
                  style: TextStyle(
                    color: StudentDensityTokens.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StudentDensityEyebrow('MY OVR'),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      rating,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'B Tier',
                      style: TextStyle(
                        color: StudentDensityTokens.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [copy, const SizedBox(height: 16), chip],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: copy),
        const SizedBox(width: 26),
        chip,
      ],
    );
  }
}

class _CourseSearchDock extends StatelessWidget {
  const _CourseSearchDock({
    required this.controller,
    required this.filter,
    required this.onFilter,
    required this.onSearch,
  });

  static const filters = ['전체', '수강 중', '추천', '배정됨', '완료 코스', '#중2', '#함수'];

  final TextEditingController controller;
  final String filter;
  final ValueChanged<String> onFilter;
  final VoidCallback onSearch;

  /// 필요한 변수는 검색어·선택 필터·검색 콜백이다.
  /// 작동 원리: HTML처럼 검색 필드와 가로 스크롤 필터를 하나의 흰 도크 안에 배치한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return StudentDensitySurface(
      radius: 20,
      padding: EdgeInsets.all(mobile ? 8 : 10),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 5, 5, 5),
            decoration: BoxDecoration(
              color: StudentDensityTokens.surfaceMuted,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: StudentDensityTokens.line),
            ),
            child: mobile
                ? Column(
                    children: [
                      _SearchInput(controller: controller, onSearch: onSearch),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: onSearch,
                          child: const Text('검색'),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _SearchInput(
                          controller: controller,
                          onSearch: onSearch,
                        ),
                      ),
                      FilledButton(
                        onPressed: onSearch,
                        child: const Text('검색'),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: mobile ? 5 : filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 5),
              itemBuilder: (context, index) {
                final label = filters[index];
                final selected = label == filter;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => onFilter(label),
                  showCheckmark: false,
                  side: BorderSide.none,
                  backgroundColor: Colors.transparent,
                  selectedColor: StudentDensityTokens.dark,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : StudentDensityTokens.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({required this.controller, required this.onSearch});

  final TextEditingController controller;
  final VoidCallback onSearch;

  /// 필요한 변수는 검색 컨트롤러와 제출 콜백이다.
  /// 작동 원리: 테두리 없는 한 줄 입력과 검색 아이콘을 기존 도크 배경 위에 표시한다.
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onSubmitted: (_) => onSearch(),
      decoration: const InputDecoration(
        hintText: '코스명, 설명, 태그로 검색',
        prefixIcon: Icon(Icons.search_rounded, size: 18),
        border: InputBorder.none,
        isDense: true,
      ),
      style: const TextStyle(fontSize: 13),
    );
  }
}

class _ResumeCourses extends StatelessWidget {
  const _ResumeCourses({
    required this.courses,
    required this.loading,
    required this.onOpen,
    required this.onReorder,
  });

  final List<Course> courses;
  final bool loading;
  final ValueChanged<Course> onOpen;
  final VoidCallback onReorder;

  /// 필요한 변수는 수강 중 코스·로딩 상태·진입 콜백이다.
  /// 작동 원리: PC는 두 코스를 한 행에, 모바일은 편집 버튼 아래 세로 목록으로 표시한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final visible = courses.isNotEmpty ? courses : const <Course>[];
    return StudentDensitySurface(
      padding: EdgeInsets.all(mobile ? 18 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StudentDensityEyebrow('CONTINUE LEARNING'),
                    SizedBox(height: 7),
                    Text(
                      '이어서 학습',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (!mobile)
                OutlinedButton(
                  onPressed: onReorder,
                  child: const Text('순서 편집'),
                ),
            ],
          ),
          if (mobile) ...[
            const SizedBox(height: 36),
            OutlinedButton(onPressed: onReorder, child: const Text('순서 편집')),
          ],
          SizedBox(height: mobile ? 16 : 36),
          const Divider(height: 1),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text(
                '진행 중인 코스가 없습니다.',
                style: TextStyle(color: StudentDensityTokens.muted),
              ),
            )
          else if (mobile)
            for (var index = 0; index < visible.length; index++)
              _ResumeCourseRow(
                course: visible[index],
                index: index,
                onTap: () => onOpen(visible[index]),
              )
          else
            IntrinsicHeight(
              child: Row(
                children: [
                  for (var index = 0; index < visible.length; index++) ...[
                    if (index > 0) const VerticalDivider(width: 1),
                    Expanded(
                      child: _ResumeCourseRow(
                        course: visible[index],
                        index: index,
                        onTap: () => onOpen(visible[index]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ResumeCourseRow extends StatelessWidget {
  const _ResumeCourseRow({
    required this.course,
    required this.index,
    required this.onTap,
  });

  final Course course;
  final int index;
  final VoidCallback onTap;

  /// 필요한 변수는 코스 정보·순서·진입 콜백이다.
  /// 작동 원리: 번호, 현재 모듈, 진행 막대, 행동을 HTML의 이어하기 한 행에 배치한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final progress = course.progress.clamp(0.0, 1.0);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: mobile ? 16 : 27,
          horizontal: 16,
        ),
        child: mobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CourseIndex(index: index),
                      const SizedBox(width: 14),
                      Expanded(child: _CourseRowCopy(course: course)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.only(left: 54),
                    child: _CourseProgress(progress: progress),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    index == 0 ? '이어하기 ›' : '열기 ›',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  _CourseIndex(index: index),
                  const SizedBox(width: 14),
                  Expanded(child: _CourseRowCopy(course: course)),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 160,
                    child: _CourseProgress(progress: progress),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    index == 0 ? '이어하기 ›' : '열기 ›',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CourseIndex extends StatelessWidget {
  const _CourseIndex({required this.index});

  final int index;

  /// 필요한 변수는 0부터 시작하는 코스 순서다.
  /// 작동 원리: 첫 코스만 검은 40px 번호 배지로 강조한다.
  @override
  Widget build(BuildContext context) {
    final active = index == 0;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? StudentDensityTokens.dark
            : StudentDensityTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        '${index + 1}'.padLeft(2, '0'),
        style: TextStyle(
          color: active ? Colors.white : StudentDensityTokens.ink,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CourseRowCopy extends StatelessWidget {
  const _CourseRowCopy({required this.course});

  final Course course;

  /// 필요한 변수는 코스 제목과 최근 학습 정보다.
  /// 작동 원리: 최근 행동이 없으면 코스 난이도·강의 수로 보조 문구를 만든다.
  @override
  Widget build(BuildContext context) {
    final meta = course.lastAction?.trim().isNotEmpty == true
        ? course.lastAction!.trim()
        : '${course.level} · ${course.lessons > 0 ? '${course.lessons}번째 모듈' : course.duration}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          course.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          meta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: StudentDensityTokens.muted,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

class _CourseProgress extends StatelessWidget {
  const _CourseProgress({required this.progress});

  final double progress;

  /// 필요한 변수는 0~1 진행률이다.
  /// 작동 원리: 5px 검은 진행 막대와 백분율을 한 행에 표시한다.
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              color: StudentDensityTokens.dark,
              backgroundColor: const Color(0xFFE4E4E7),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(progress * 100).round()}%',
          style: const TextStyle(
            color: StudentDensityTokens.muted,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

class _RecommendationSection extends StatelessWidget {
  const _RecommendationSection({
    required this.courses,
    required this.onOpen,
    required this.onCompare,
  });

  final List<Course> courses;
  final ValueChanged<Course> onOpen;
  final VoidCallback onCompare;

  /// 필요한 변수는 추천 코스 목록과 이동 콜백이다.
  /// 작동 원리: 첫 추천은 큰 91점 카드, 나머지는 우측 대안 목록으로 배치하고 모바일에서는 세로로 쌓는다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final primary = courses.first;
    final main = StudentDensitySurface(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => onOpen(primary),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: mobile ? 330 : 260),
          child: Padding(
            padding: EdgeInsets.all(mobile ? 28 : 32),
            child: mobile
                ? _RecommendationCopy(course: primary)
                : Row(
                    children: [
                      Expanded(child: _RecommendationCopy(course: primary)),
                      const SizedBox(width: 24),
                      const _RecommendationScore(),
                    ],
                  ),
          ),
        ),
      ),
    );
    final alternatives = StudentDensitySurface(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StudentDensityEyebrow('ALTERNATIVES'),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '다른 추천',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                ),
              ),
              OutlinedButton(
                onPressed: onCompare,
                child: const Text('두 코스 비교'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var index = 1; index < courses.length; index++)
            _AlternativeRow(
              course: courses[index],
              score: 91 - index * 7,
              onTap: () => onOpen(courses[index]),
            ),
        ],
      ),
    );
    if (mobile) {
      return Column(children: [main, const SizedBox(height: 14), alternatives]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: main),
        const SizedBox(width: 14),
        Expanded(child: alternatives),
      ],
    );
  }
}

class _RecommendationCopy extends StatelessWidget {
  const _RecommendationCopy({required this.course});

  final Course course;

  /// 필요한 변수는 첫 추천 코스다.
  /// 작동 원리: 시안의 큰 추천 제목과 설명·메타데이터·행동을 구성한다.
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StudentDensityEyebrow('BEST MATCH · 91%'),
        const SizedBox(height: 30),
        Text(
          '다음 코스로\n${course.title}은 어때요?',
          style: const TextStyle(
            fontSize: 42,
            height: 1.06,
            fontWeight: FontWeight.w900,
            letterSpacing: -2.2,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          course.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: StudentDensityTokens.muted,
            fontSize: 12,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _RecommendationScore extends StatelessWidget {
  const _RecommendationScore();

  /// 필요한 변수는 고정 추천 점수 91이다.
  /// 작동 원리: 검은 직사각 표면 안에 동심원과 큰 점수를 겹쳐 추천 시각을 만든다.
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 230,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: StudentDensityTokens.dark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        width: 140,
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: const Text(
          '91',
          style: TextStyle(
            color: Colors.white,
            fontSize: 66,
            fontWeight: FontWeight.w900,
            letterSpacing: -4,
          ),
        ),
      ),
    );
  }
}

class _AlternativeRow extends StatelessWidget {
  const _AlternativeRow({
    required this.course,
    required this.score,
    required this.onTap,
  });

  final Course course;
  final int score;
  final VoidCallback onTap;

  /// 필요한 변수는 대안 코스·점수·진입 콜백이다.
  /// 작동 원리: 점수 배지와 한 줄 코스 메타를 얇은 구분선 목록으로 표시한다.
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: StudentDensityTokens.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: StudentDensityTokens.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '$score',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _CourseRowCopy(course: course)),
            const Text('›'),
          ],
        ),
      ),
    );
  }
}

class _CourseLibrary extends StatelessWidget {
  const _CourseLibrary({
    required this.courses,
    required this.loading,
    required this.mobile,
    required this.onOpen,
  });

  final List<Course> courses;
  final bool loading;
  final bool mobile;
  final ValueChanged<Course> onOpen;

  /// 필요한 변수는 필터된 전체 코스·로딩 상태·화면 폭이다.
  /// 작동 원리: PC 3열, 모바일 1열 카드 그리드로 공개·배정·완료 코스를 표시한다.
  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StudentDensityEyebrow('ALL COURSES'),
                  SizedBox(height: 7),
                  Text(
                    '전체 코스',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            _CountPill(count: courses.length),
          ],
        ),
        const SizedBox(height: 14),
        if (courses.isEmpty)
          const StudentDensitySurface(
            child: Text(
              '조건에 맞는 코스가 없습니다.',
              style: TextStyle(color: StudentDensityTokens.muted),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = mobile ? 1 : (constraints.maxWidth < 980 ? 2 : 3);
              final width =
                  (constraints.maxWidth - 14 * (columns - 1)) / columns;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final course in courses)
                    SizedBox(
                      width: width,
                      child: CourseCard(
                        course: course,
                        onTap: () => onOpen(course),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  /// 필요한 변수는 검색 결과 개수다.
  /// 작동 원리: 전체 코스 제목 우측에 작은 회색 캡슐로 개수를 표시한다.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: StudentDensityTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: StudentDensityTokens.line),
      ),
      child: Text(
        '$count개',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  /// 필요한 변수는 코스 상태 문구다.
  /// 작동 원리: 카드 우측 상단에 HTML과 같은 작은 회색 상태 캡슐을 표시한다.
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: StudentDensityTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: StudentDensityTokens.line),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: StudentDensityTokens.muted,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course, required this.onTap});

  final Course course;
  final VoidCallback onTap;

  /// 필요한 변수는 코스 정보와 진입 콜백이다.
  /// 작동 원리: 추천 점수·상태·설명·메타·행동을 HTML 전체 코스 카드 순서로 배치한다.
  @override
  Widget build(BuildContext context) {
    final status = course.isCompleted
        ? '완료 · 미리보기'
        : course.isEnrolled
        ? '수강 중'
        : '공개';
    final score = course.targetOvr > 0 ? '${course.targetOvr}' : '—';
    return StudentDensitySurface(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
        height: 230,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    score,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  _StatusPill(label: status),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                course.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                course.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: StudentDensityTokens.muted,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                '${course.lessons > 0 ? '${course.lessons}강' : course.level} · ${course.duration}',
                style: const TextStyle(
                  color: StudentDensityTokens.muted,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$status ›',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
