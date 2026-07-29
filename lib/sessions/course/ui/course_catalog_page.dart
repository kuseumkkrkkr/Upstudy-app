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
const int _coursePageSize = 6;

/// 필요한 변수는 서버 레이팅 또는 이미 환산된 OVR 값이다.
/// 작동 원리: 원시 레이팅은 OVR로 환산하고 작은 값은 화면 표시값으로 그대로 사용한다.
String _formatVisibleOvr(num value) {
  final raw = value.toDouble();
  if (raw.isNaN || raw <= 0) return '18.6';
  if (raw < _ratingOvrFloor) return raw.toStringAsFixed(1);
  return ((raw - _ratingOvrFloor) / _ratingOvrDivider).toStringAsFixed(1);
}

class _RecommendedCourse {
  const _RecommendedCourse({required this.course, this.matchScore});

  final Course course;
  final int? matchScore;
}

/// 필요한 변수는 추천 기준 OVR과 노출할 코스 목록이다.
/// 작동 원리: 코스 목표 OVR과 학생 기준값의 차이를 후보군 안에서 0~100 적합도로 환산하고, 가까운 코스를 먼저 배치한다.
List<_RecommendedCourse> _buildRecommendedCourses(
  List<Course> courses,
  double? recommendOvr,
) {
  final candidates = courses
      .where((course) => !course.isCompleted)
      .toList(growable: false);
  if (recommendOvr == null || recommendOvr <= 0) {
    return candidates
        .take(4)
        .map((course) => _RecommendedCourse(course: course))
        .toList(growable: false);
  }

  final distances = <String, double>{
    for (final course in candidates)
      if (course.targetOvr > 0)
        course.id: (course.targetOvr - recommendOvr).abs(),
  };
  if (distances.isEmpty) {
    return candidates
        .take(4)
        .map((course) => _RecommendedCourse(course: course))
        .toList(growable: false);
  }

  final values = distances.values;
  final nearest = values.reduce((left, right) => left < right ? left : right);
  final farthest = values.reduce((left, right) => left > right ? left : right);
  final range = farthest - nearest;
  final recommended = candidates.map((course) {
    final distance = distances[course.id];
    final score = distance == null
        ? null
        : range == 0
        ? 100
        : ((farthest - distance) / range * 100).round();
    return _RecommendedCourse(course: course, matchScore: score);
  }).toList();
  recommended.sort((left, right) {
    final leftScore = left.matchScore;
    final rightScore = right.matchScore;
    if (leftScore == null && rightScore == null) return 0;
    if (leftScore == null) return 1;
    if (rightScore == null) return -1;
    return rightScore.compareTo(leftScore);
  });
  return recommended.take(4).toList(growable: false);
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
  Future<List<GenerationTagGroup>>? _tagGroupsFuture;
  double? _lastRecommend;
  String _filter = '전체';
  String? _subjectName;
  String? _tag;
  List<Course> _loadedCourses = const <Course>[];
  int _publicCourseOffset = 0;
  bool _hasMoreCourses = false;
  bool _loadingMoreCourses = false;

  @override
  void initState() {
    super.initState();
    RatingStore.notifier.addListener(_handleRatingChange);
    _tagGroupsFuture = widget.courseFeedLoader == null
        ? CourseService.fetchGenerationTagGroups().catchError(
            (_) => const <GenerationTagGroup>[],
          )
        : Future.value(const <GenerationTagGroup>[]);
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
    _publicCourseOffset = 0;
    _hasMoreCourses = false;
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
      limit: _coursePageSize,
      offset: _publicCourseOffset,
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
    final courses = byId.values.toList(growable: false);
    _loadedCourses = courses;
    _publicCourseOffset = publicCourses.length;
    _hasMoreCourses = publicCourses.length == _coursePageSize;
    return courses;
  }

  /// 필요한 변수는 현재 검색 조건·공개 코스 페이지 오프셋·이미 받은 목록이다.
  /// 작동 원리: 서버에 다음 6개만 요청하고 ID 중복을 제거해 기존 카드 뒤에 추가한다.
  Future<void> _loadMoreCourses() async {
    if (_loadingMoreCourses ||
        !_hasMoreCourses ||
        widget.courseFeedLoader != null) {
      return;
    }
    setState(() => _loadingMoreCourses = true);
    try {
      final nextCourses = await CourseService.fetchCourses(
        keyword: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        recommendOvr: _currentRecommendOvr(),
        limit: _coursePageSize,
        offset: _publicCourseOffset,
      );
      final byId = <String, Course>{
        for (final course in _loadedCourses) course.id: course,
        for (final course in nextCourses)
          if (course.id.trim().isNotEmpty) course.id: course,
      };
      _publicCourseOffset += nextCourses.length;
      _hasMoreCourses = nextCourses.length == _coursePageSize;
      _loadedCourses = byId.values.toList(growable: false);
      if (!mounted) return;
      setState(() => _future = Future.value(_loadedCourses));
    } finally {
      if (mounted) setState(() => _loadingMoreCourses = false);
    }
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
  bool _matchesFilter(Course course, GenerationTagGroup? subject) {
    final courseTags = course.focusTags
        .map(_normalizedTag)
        .where((tag) => tag.isNotEmpty)
        .toSet();
    if (_tag != null && !courseTags.contains(_normalizedTag(_tag!))) {
      return false;
    }
    if (_tag == null &&
        subject != null &&
        !subject.tags.map(_normalizedTag).any(courseTags.contains)) {
      return false;
    }
    return switch (_filter) {
      '수강 중' => course.isEnrolled && !course.isCompleted,
      '추천' => !course.isCompleted,
      '배정됨' => course.status == 'assigned',
      '완료 코스' => course.isCompleted,
      _ => true,
    };
  }

  /// 필요한 변수는 태그 원문이다.
  /// 작동 원리: # 유무와 공백 차이를 제거해 코스 태그와 fix_gen.py 태그를 같은 기준으로 비교한다.
  String _normalizedTag(String tag) =>
      tag.trim().replaceFirst(RegExp(r'^#'), '').toLowerCase();

  /// 필요한 변수는 선택 과목·태그다.
  /// 작동 원리: 과목을 바꾸면 하위 태그 선택을 초기화하고, 서버 요청 없이 이미 받은 코스 목록을 즉시 필터링한다.
  void _selectTagFilter(String? subjectName, String? tag) {
    setState(() {
      _subjectName = subjectName;
      _tag = tag;
    });
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
      drawer: mobile ? null : const AppDrawer(),
      bottomNavigationBar: mobile ? const MobileStudentBottomAppBar() : null,
      body: SafeArea(
        child: Column(
          children: [
            Ios26TopBar(
              brandColor: StudentDensityTokens.dark,
              onMenu: mobile ? null : () => toggleAppDrawer(context),
              showLevelIndicator: false,
              showUtilityActions: !mobile,
              items: studentTopNavItems(
                context,
                active: StudentTopDestination.courses,
              ),
            ),
            Expanded(
              child: FutureBuilder<List<GenerationTagGroup>>(
                future: _tagGroupsFuture,
                builder: (context, tagSnapshot) {
                  final tagGroups =
                      tagSnapshot.data ?? const <GenerationTagGroup>[];
                  final matchingSubjects = tagGroups
                      .where((item) => item.name == _subjectName)
                      .toList(growable: false);
                  final subject = matchingSubjects.isEmpty
                      ? null
                      : matchingSubjects.first;
                  return FutureBuilder<List<Course>>(
                    future: _future,
                    builder: (context, snapshot) {
                      final allCourses = snapshot.data ?? const <Course>[];
                      final courses = allCourses
                          .where((course) => _matchesFilter(course, subject))
                          .toList(growable: false);
                      // 공개 목록은 페이지당 6개만 추가 노출해 한 화면에 전체 재고를 렌더링하지 않는다.
                      final libraryCourses = _publicCourseOffset == 0
                          ? courses
                          : courses
                                .take(_publicCourseOffset)
                                .toList(growable: false);
                      final active = allCourses
                          .where(
                            (course) =>
                                course.isEnrolled && !course.isCompleted,
                          )
                          .take(2)
                          .toList(growable: false);
                      final recommended = _buildRecommendedCourses(
                        allCourses,
                        _lastRecommend,
                      );
                      return SingleChildScrollView(
                        key: ValueKey(
                          mobile
                              ? 'course-catalog-mobile'
                              : 'course-catalog-desktop',
                        ),
                        child: StudentDensityPage(
                          child: mobile
                              ? _MobileCourseCatalog(
                                  rating: rating,
                                  controller: _searchController,
                                  filter: _filter,
                                  tagGroups: tagGroups,
                                  subjectName: _subjectName,
                                  tag: _tag,
                                  active: active,
                                  recommended: recommended,
                                  courses: libraryCourses,
                                  loading:
                                      snapshot.connectionState ==
                                      ConnectionState.waiting,
                                  hasMore: _hasMoreCourses,
                                  loadingMore: _loadingMoreCourses,
                                  onFilter: (value) =>
                                      setState(() => _filter = value),
                                  onTagFilter: _selectTagFilter,
                                  onSearch: _load,
                                  onOpen: _openCourse,
                                  onLoadMore: _loadMoreCourses,
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _CoursePageHead(rating: rating),
                                    const SizedBox(height: 16),
                                    _CourseSearchDock(
                                      controller: _searchController,
                                      filter: _filter,
                                      tagGroups: tagGroups,
                                      subjectName: _subjectName,
                                      tag: _tag,
                                      onFilter: (value) =>
                                          setState(() => _filter = value),
                                      onTagFilter: _selectTagFilter,
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
                                        onCompare: () =>
                                            showCourseCompareDialog(
                                              context,
                                              courses: recommended
                                                  .map((item) => item.course)
                                                  .toList(growable: false),
                                            ),
                                      ),
                                    const SizedBox(height: 14),
                                    _CourseLibrary(
                                      courses: libraryCourses,
                                      loading:
                                          snapshot.connectionState ==
                                          ConnectionState.waiting,
                                      mobile: false,
                                      onOpen: _openCourse,
                                      hasMore: _hasMoreCourses,
                                      loadingMore: _loadingMoreCourses,
                                      onLoadMore: _loadMoreCourses,
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
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

/// 필요한 변수: 검색·필터 상태, 수강·추천·공개 코스와 진입 콜백이다.
/// 작동 원리: 세로 화면은 PC용 추천 비교와 큰 정보 카드를 반복하지 않고,
/// 검색 후 현재 코스 한 개를 바로 이어서 열고 압축 목록으로 다음 코스를 고르게 한다.
class _MobileCourseCatalog extends StatelessWidget {
  const _MobileCourseCatalog({
    required this.rating,
    required this.controller,
    required this.filter,
    required this.tagGroups,
    required this.subjectName,
    required this.tag,
    required this.active,
    required this.recommended,
    required this.courses,
    required this.loading,
    required this.hasMore,
    required this.loadingMore,
    required this.onFilter,
    required this.onTagFilter,
    required this.onSearch,
    required this.onOpen,
    required this.onLoadMore,
  });

  final String rating;
  final TextEditingController controller;
  final String filter;
  final List<GenerationTagGroup> tagGroups;
  final String? subjectName;
  final String? tag;
  final List<Course> active;
  final List<_RecommendedCourse> recommended;
  final List<Course> courses;
  final bool loading;
  final bool hasMore;
  final bool loadingMore;
  final ValueChanged<String> onFilter;
  final void Function(String? subjectName, String? tag) onTagFilter;
  final VoidCallback onSearch;
  final ValueChanged<Course> onOpen;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    final featured = active.isNotEmpty
        ? active.first
        : (recommended.isEmpty ? null : recommended.first.course);
    final featureLabel = active.isNotEmpty ? '이어서 학습' : '추천 코스';
    final listCourses = courses
        .where((course) => course.id != featured?.id)
        .toList(growable: false);
    return Column(
      key: const ValueKey('course-catalog-mobile-redesign'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MobileCourseHeader(rating: rating),
        const SizedBox(height: 20),
        _CourseSearchDock(
          controller: controller,
          filter: filter,
          tagGroups: tagGroups,
          subjectName: subjectName,
          tag: tag,
          onFilter: onFilter,
          onTagFilter: onTagFilter,
          onSearch: onSearch,
        ),
        const SizedBox(height: 24),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 42),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (featured != null) ...[
          _MobileCourseSectionTitle(label: featureLabel),
          const SizedBox(height: 10),
          _MobileFeaturedCourse(
            course: featured,
            continuing: active.isNotEmpty,
            onTap: () => onOpen(featured),
          ),
          const SizedBox(height: 28),
        ],
        if (!loading) ...[
          _MobileCourseSectionTitle(label: '코스 둘러보기'),
          const SizedBox(height: 10),
          if (listCourses.isEmpty)
            const _MobileCourseEmptyState()
          else
            _MobileCourseList(courses: listCourses, onOpen: onOpen),
          if (hasMore) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: loadingMore ? null : onLoadMore,
                child: Text(loadingMore ? '불러오는 중…' : '코스 더보기'),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// 필요한 변수: 표시용 OVR이다.
/// 작동 원리: 모바일 상단을 제목과 한 줄 수준 정보로 제한해 목록 진입 행동을 첫 화면에 남긴다.
class _MobileCourseHeader extends StatelessWidget {
  const _MobileCourseHeader({required this.rating});
  final String rating;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StudentDensityEyebrow('LEARNING PATH'),
            SizedBox(height: 8),
            Text(
              '코스',
              style: TextStyle(
                fontSize: 34,
                letterSpacing: -1.8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
      Text(
        'OVR $rating',
        style: const TextStyle(
          color: StudentDensityTokens.muted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

/// 필요한 변수: 섹션 문구다.
/// 작동 원리: 큰 부제와 장식 문구를 줄여 다음 행동의 구분만 제공한다.
class _MobileCourseSectionTitle extends StatelessWidget {
  const _MobileCourseSectionTitle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.5,
    ),
  );
}

/// 필요한 변수: 우선 노출할 코스와 현재 수강 여부다.
/// 작동 원리: 진행률·현재 행동·한 개의 전체 폭 버튼만 남겨 세로 화면에서 즉시 학습을 시작한다.
class _MobileFeaturedCourse extends StatelessWidget {
  const _MobileFeaturedCourse({
    required this.course,
    required this.continuing,
    required this.onTap,
  });

  final Course course;
  final bool continuing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = course.progress.clamp(0.0, 1.0);
    final meta = course.lastAction?.trim().isNotEmpty == true
        ? course.lastAction!.trim()
        : '${course.lessons > 0 ? '${course.lessons}강' : course.level} · ${course.duration}';
    return Container(
      key: const ValueKey('course-mobile-featured'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: StudentDensityTokens.dark,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            course.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              height: 1.15,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          if (continuing) ...[
            const SizedBox(height: 18),
            _MobileCourseProgress(progress: progress),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: StudentDensityTokens.dark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                continuing ? '학습 이어하기' : '코스 자세히 보기',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 필요한 변수: 목록 코스와 선택 콜백이다.
/// 작동 원리: 긴 카드·중복 태그 대신 제목과 최소 메타만 가진 터치 행으로 공개 코스를 빠르게 훑는다.
class _MobileCourseList extends StatelessWidget {
  const _MobileCourseList({required this.courses, required this.onOpen});
  final List<Course> courses;
  final ValueChanged<Course> onOpen;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: StudentDensityTokens.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: StudentDensityTokens.line),
    ),
    child: Column(
      children: [
        for (var index = 0; index < courses.length; index++) ...[
          InkWell(
            onTap: () => onOpen(courses[index]),
            borderRadius: index == 0
                ? const BorderRadius.vertical(top: Radius.circular(20))
                : index == courses.length - 1
                ? const BorderRadius.vertical(bottom: Radius.circular(20))
                : BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  _MobileCourseStatusIcon(course: courses[index]),
                  const SizedBox(width: 13),
                  Expanded(child: _CourseRowCopy(course: courses[index])),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
            ),
          ),
          if (index != courses.length - 1)
            const Divider(height: 1, color: StudentDensityTokens.line),
        ],
      ],
    ),
  );
}

/// 필요한 변수: 코스 완료·수강 상태다.
/// 작동 원리: 상태를 작은 단색 아이콘으로 치환해 반복 상태 알약과 긴 텍스트를 제거한다.
class _MobileCourseStatusIcon extends StatelessWidget {
  const _MobileCourseStatusIcon({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    final completed = course.isCompleted;
    final active = course.isEnrolled && !completed;
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? StudentDensityTokens.dark
            : StudentDensityTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        completed
            ? Icons.check_rounded
            : active
            ? Icons.play_arrow_rounded
            : Icons.menu_book_outlined,
        size: 19,
        color: active ? Colors.white : StudentDensityTokens.ink,
      ),
    );
  }
}

/// 필요한 변수: 0~1 진행률이다.
/// 작동 원리: 어두운 추천 카드 안에서 남은 학습량을 짧은 막대와 수치로 한 번만 표시한다.
class _MobileCourseProgress extends StatelessWidget {
  const _MobileCourseProgress({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            color: Colors.white,
            backgroundColor: Colors.white24,
          ),
        ),
      ),
      const SizedBox(width: 9),
      Text(
        '${(progress * 100).round()}%',
        style: const TextStyle(color: Colors.white70, fontSize: 10),
      ),
    ],
  );
}

/// 필요한 변수 없음.
/// 작동 원리: 필터 결과가 비어도 목록 영역의 의미를 보존하고 다음 검색을 안내한다.
class _MobileCourseEmptyState extends StatelessWidget {
  const _MobileCourseEmptyState();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('course-mobile-empty-state'),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    decoration: BoxDecoration(
      color: StudentDensityTokens.surface,
      borderRadius: BorderRadius.circular(22),
    ),
    child: const Row(
      children: [
        _MobileCourseEmptyIcon(),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '조건에 맞는 코스가 없어요',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 4),
              Text(
                '검색어나 필터를 바꿔보세요.',
                style: TextStyle(
                  color: StudentDensityTokens.muted,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 필요한 변수 없음.
/// 작동 원리: 빈 결과의 의미를 짧은 아이콘으로 먼저 전달해 긴 안내 문장을 읽지 않아도 되게 한다.
class _MobileCourseEmptyIcon extends StatelessWidget {
  const _MobileCourseEmptyIcon();

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: StudentDensityTokens.surfaceMuted,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Icon(Icons.search_off_rounded, size: 22),
  );
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
    required this.tagGroups,
    required this.subjectName,
    required this.tag,
    required this.onFilter,
    required this.onTagFilter,
    required this.onSearch,
  });

  static const filters = ['전체', '수강 중', '추천', '배정됨', '완료 코스'];

  final TextEditingController controller;
  final String filter;
  final List<GenerationTagGroup> tagGroups;
  final String? subjectName;
  final String? tag;
  final ValueChanged<String> onFilter;
  final void Function(String? subjectName, String? tag) onTagFilter;
  final VoidCallback onSearch;

  /// 필요한 변수는 검색어·상태 필터·fix_gen.py 과목별 태그 목록이다.
  /// 작동 원리: 모바일은 무테 표면과 큰 입력·필터를 사용하고 PC는 기존 검색 도크를 유지한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    if (mobile) {
      return Container(
        key: const ValueKey('course-mobile-search-dock'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: StudentDensityTokens.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _SearchInput(
                    controller: controller,
                    onSearch: onSearch,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 50,
                  height: 50,
                  child: FilledButton(
                    key: const ValueKey('course-mobile-search-button'),
                    onPressed: onSearch,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: StudentDensityTokens.dark,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Icon(Icons.search_rounded, size: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final label in filters)
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: _FilterChip(
                        label: label,
                        selected: label == filter,
                        onSelected: () => onFilter(label),
                      ),
                    ),
                  if (tagGroups.isNotEmpty) ...[
                    _FilterChip(
                      label: '전체 과목',
                      selected: subjectName == null,
                      onSelected: () => onTagFilter(null, null),
                    ),
                    for (final group in tagGroups)
                      Padding(
                        padding: const EdgeInsets.only(left: 7),
                        child: _FilterChip(
                          label: group.label,
                          selected: group.name == subjectName,
                          onSelected: () => onTagFilter(group.name, null),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (tagGroups.isNotEmpty && subjectName != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final group in tagGroups.where(
                    (item) => item.name == subjectName,
                  ))
                    for (final item in group.tags)
                      _FilterChip(
                        label: '#$item',
                        selected: item == tag,
                        onSelected: () =>
                            onTagFilter(group.name, item == tag ? null : item),
                      ),
                ],
              ),
            ],
          ],
        ),
      );
    }
    return StudentDensitySurface(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          mobile
              ? Row(
                  children: [
                    Expanded(
                      child: _SearchInput(
                        controller: controller,
                        onSearch: onSearch,
                      ),
                    ),
                    IconButton(
                      tooltip: '코스 검색',
                      onPressed: onSearch,
                      icon: const Icon(Icons.search_rounded),
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
                    const SizedBox(width: 8),
                    FilledButton(onPressed: onSearch, child: const Text('검색')),
                  ],
                ),
          const SizedBox(height: 8),
          mobile
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final label in filters)
                        Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: _FilterChip(
                            label: label,
                            selected: label == filter,
                            onSelected: () => onFilter(label),
                          ),
                        ),
                      if (tagGroups.isNotEmpty) ...[
                        _FilterChip(
                          label: '전체 과목',
                          selected: subjectName == null,
                          onSelected: () => onTagFilter(null, null),
                        ),
                        for (final group in tagGroups)
                          Padding(
                            padding: const EdgeInsets.only(left: 5),
                            child: _FilterChip(
                              label: group.label,
                              selected: group.name == subjectName,
                              onSelected: () => onTagFilter(group.name, null),
                            ),
                          ),
                      ],
                    ],
                  ),
                )
              : Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final label in filters)
                      _FilterChip(
                        label: label,
                        selected: label == filter,
                        onSelected: () => onFilter(label),
                      ),
                    if (tagGroups.isNotEmpty) ...[
                      _FilterChip(
                        label: '전체 과목',
                        selected: subjectName == null,
                        onSelected: () => onTagFilter(null, null),
                      ),
                      for (final group in tagGroups)
                        _FilterChip(
                          label: group.label,
                          selected: group.name == subjectName,
                          onSelected: () => onTagFilter(group.name, null),
                        ),
                    ],
                  ],
                ),
          if (tagGroups.isNotEmpty) ...[
            if (subjectName != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final group in tagGroups.where(
                    (item) => item.name == subjectName,
                  ))
                    for (final item in group.tags)
                      _FilterChip(
                        label: '#$item',
                        selected: item == tag,
                        onSelected: () =>
                            onTagFilter(group.name, item == tag ? null : item),
                      ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  /// 필요한 변수는 라벨·선택 여부·선택 콜백이다.
  /// 작동 원리: 모바일은 큰 무테 칩으로 가독성과 터치 영역을 확보하고 PC 밀도는 유지한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      side: BorderSide.none,
      backgroundColor: StudentDensityTokens.surfaceMuted,
      selectedColor: StudentDensityTokens.dark,
      labelStyle: TextStyle(
        color: selected ? Colors.white : StudentDensityTokens.muted,
        fontSize: mobile ? 13 : 10,
        fontWeight: FontWeight.w800,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 11 : 7,
        vertical: mobile ? 8 : 0,
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({required this.controller, required this.onSearch});

  final TextEditingController controller;
  final VoidCallback onSearch;

  /// 필요한 변수는 검색 컨트롤러와 제출 콜백이다.
  /// 작동 원리: 모바일은 큰 회색 입력면을 사용하고 PC는 기존 한 줄 입력 밀도를 유지한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return SizedBox(
      height: mobile ? 50 : null,
      child: TextField(
        controller: controller,
        onSubmitted: (_) => onSearch(),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: mobile ? '코스 검색' : '코스명, 설명, 태그로 검색',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          filled: mobile,
          fillColor: StudentDensityTokens.surfaceMuted,
          border: InputBorder.none,
          enabledBorder: mobile
              ? OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(16),
                )
              : InputBorder.none,
          focusedBorder: mobile
              ? OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(16),
                )
              : InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          isDense: true,
        ),
        style: TextStyle(fontSize: mobile ? 15 : 13),
      ),
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
          style: const TextStyle(
            fontSize: 15,
            height: 1.1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          meta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: StudentDensityTokens.muted,
            fontSize: 9,
            height: 1.1,
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

  final List<_RecommendedCourse> courses;
  final ValueChanged<Course> onOpen;
  final VoidCallback onCompare;

  /// 필요한 변수는 실제 추천 코스 목록과 이동 콜백이다.
  /// 작동 원리: 첫 추천은 큰 적합도 카드, 나머지는 우측 대안 목록으로 배치하고 모바일에서는 세로로 쌓는다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    final primary = courses.first;
    final main = StudentDensitySurface(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => onOpen(primary.course),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: mobile ? 330 : 260),
          child: Padding(
            padding: EdgeInsets.all(mobile ? 28 : 32),
            child: mobile
                ? _RecommendationCopy(
                    course: primary.course,
                    matchScore: primary.matchScore,
                    onOpen: () => onOpen(primary.course),
                    onCompare: onCompare,
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _RecommendationCopy(
                          course: primary.course,
                          matchScore: primary.matchScore,
                          onOpen: () => onOpen(primary.course),
                          onCompare: onCompare,
                        ),
                      ),
                      const SizedBox(width: 24),
                      _RecommendationScore(score: primary.matchScore),
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
              course: courses[index].course,
              score: courses[index].matchScore,
              onTap: () => onOpen(courses[index].course),
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
  const _RecommendationCopy({
    required this.course,
    required this.matchScore,
    required this.onOpen,
    required this.onCompare,
  });

  final Course course;
  final int? matchScore;
  final VoidCallback onOpen;
  final VoidCallback onCompare;

  /// 필요한 변수는 첫 추천 코스와 OVR 기반 적합도다.
  /// 작동 원리: 실제 코스 정보와 계산된 적합도를 큰 추천 제목·설명·메타데이터·행동으로 구성한다.
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudentDensityEyebrow(
          matchScore == null ? 'BEST MATCH' : 'BEST MATCH · $matchScore%',
        ),
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
        const SizedBox(height: 18),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _CourseMetaPill(
              label: course.targetOvr > 0
                  ? '목표 OVR ${course.targetOvr}'
                  : '맞춤 추천',
            ),
            _CourseMetaPill(
              label: course.lessons > 0 ? '${course.lessons}강' : course.level,
            ),
            _CourseMetaPill(label: course.duration),
            for (final tag in course.focusTags.take(2))
              _CourseMetaPill(label: '#$tag'),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: onOpen,
              style: FilledButton.styleFrom(
                backgroundColor: StudentDensityTokens.dark,
                foregroundColor: Colors.white,
              ),
              child: const Text('코스 상세'),
            ),
            OutlinedButton(onPressed: onCompare, child: const Text('추천 비교')),
          ],
        ),
      ],
    );
  }
}

class _RecommendationScore extends StatelessWidget {
  const _RecommendationScore({required this.score});

  final int? score;

  /// 필요한 변수는 목표 OVR 차이로 계산한 추천 적합도다.
  /// 작동 원리: 적합도가 있을 때만 검은 직사각 표면 안에 동심원과 큰 점수를 겹쳐 표시한다.
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
        child: Text(
          score?.toString() ?? '—',
          style: const TextStyle(
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
  final int? score;
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
                score?.toString() ?? '—',
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
    required this.hasMore,
    required this.loadingMore,
    required this.onLoadMore,
  });

  final List<Course> courses;
  final bool loading;
  final bool mobile;
  final ValueChanged<Course> onOpen;
  final bool hasMore;
  final bool loadingMore;
  final Future<void> Function() onLoadMore;

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
        else if (mobile)
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: StudentDensityTokens.surface,
                border: Border.all(color: StudentDensityTokens.line),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  for (var index = 0; index < courses.length; index++) ...[
                    CourseCard(
                      course: courses[index],
                      onTap: () => onOpen(courses[index]),
                      joinedMobileList: true,
                    ),
                    if (index != courses.length - 1)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: StudentDensityTokens.line,
                      ),
                  ],
                ],
              ),
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
        if (hasMore) ...[
          const SizedBox(height: 20),
          Center(
            child: OutlinedButton(
              onPressed: loadingMore ? null : onLoadMore,
              child: Text(loadingMore ? '불러오는 중...' : '코스 더보기'),
            ),
          ),
        ],
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
  const CourseCard({
    super.key,
    required this.course,
    required this.onTap,
    this.joinedMobileList = false,
  });

  final Course course;
  final VoidCallback onTap;
  final bool joinedMobileList;

  /// 필요한 변수는 코스 정보와 진입 콜백이다.
  /// 작동 원리: 추천 점수·상태·설명·메타·행동을 HTML 전체 코스 카드 순서로 배치한다.
  @override
  Widget build(BuildContext context) {
    final status = course.isCompleted
        ? '완료 · 미리보기'
        : course.isEnrolled
        ? '수강 중'
        : '공개';
    final score = course.targetOvr > 0 ? '${course.targetOvr}' : 'OVR 미설정';
    if (joinedMobileList) {
      return Material(
        color: StudentDensityTokens.surface,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 256,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          score,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _StatusPill(label: status),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 21,
                      height: 1.16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    course.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StudentDensityTokens.muted,
                      fontSize: 11,
                      height: 1.55,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      _CourseMetaPill(label: course.isCompleted ? '완료' : '공개'),
                      const SizedBox(width: 6),
                      _CourseMetaPill(
                        label: course.lessons > 0
                            ? '${course.lessons}강'
                            : course.level,
                      ),
                      const SizedBox(width: 6),
                      _CourseMetaPill(
                        label: course.isCompleted
                            ? '${(course.progress * 100).round()}%'
                            : course.duration,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    course.isCompleted ? '미리보기 ›' : '코스 상세 ›',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
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

class _CourseMetaPill extends StatelessWidget {
  const _CourseMetaPill({required this.label});

  final String label;

  /// 필요한 변수는 코스 공개·분량·기간 메타 문구다.
  /// 작동 원리: HTML 모바일 카드의 9px 회색 캡슐을 같은 높이와 대비로 표시한다.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: StudentDensityTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: StudentDensityTokens.muted,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
