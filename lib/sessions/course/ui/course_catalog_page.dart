import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:s11/shared/business/repositories/rating_store.dart';
import 'package:s11/shared/data/models/course.dart';
import 'package:s11/shared/services/api/course_service.dart';
import 'package:s11/sessions/course/ui/course_detail_page.dart';
import 'package:s11/sessions/course/session/course_learning_page.dart';
import 'package:s11/sessions/friend/friend.dart';
import 'package:s11/sessions/legacy_cleanup/session/study_center.dart'
    as study_center;
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
import 'package:s11/sessions/textbook/ui/pages/docx_box.dart' as docx;
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'shared.dart';

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
const Color _ink = Color(0xFF17211B);
const Color _accentBlue = Color(0xFF2D6CDF);
const Color _accentOrange = Color(0xFFE8862F);

String _formatVisibleOvr(num value) {
  final raw = value.toDouble();
  if (raw.isNaN || raw <= 0) return '--';
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
  final TextEditingController _searchCtrl = TextEditingController();
  Future<List<Course>>? _future;
  double? _lastRecommend;
  bool _showCompletedCourses = false;

  @override
  void initState() {
    super.initState();
    RatingStore.notifier.addListener(_handleRatingChange);
    _load();
  }

  @override
  void dispose() {
    RatingStore.notifier.removeListener(_handleRatingChange);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _handleRatingChange() {
    final next = _currentRecommendOvr();
    if ((_lastRecommend ?? -1) != next) _load();
  }

  double? _currentRecommendOvr() {
    final rating = RatingStore.notifier.value.ovr;
    if (rating <= 0) return null;
    return rating / _ratingOvrDivider;
  }

  void _load() {
    final keyword = _searchCtrl.text.trim();
    final recommend = _currentRecommendOvr();
    _lastRecommend = recommend;
    setState(() {
      _future = (widget.courseFeedLoader ?? _loadCourseFeed)(
        keyword: keyword,
        recommend: recommend,
      );
    });
  }

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

  bool _matchesKeyword(Course course, String keyword) {
    final q = keyword.trim().toLowerCase();
    if (q.isEmpty) return true;
    return course.title.toLowerCase().contains(q) ||
        course.description.toLowerCase().contains(q) ||
        course.focusTags.any((tag) => tag.toLowerCase().contains(q));
  }

  /// 필요 변수: 선택한 [course]의 수강 여부를 사용한다.
  /// 작동 원리: 수강 중이면 현재 진도 화면으로 직행하고, 미수강이면 상세/신청 화면을 연다.
  void _openCourse(Course course) {
    final page = courseEntryTarget(course) == CourseEntryTarget.learning
        ? CourseLearningPage(course: course)
        : CourseDetailPage(course: course);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  /// 필요 변수: 현재 Navigator의 이전 경로 존재 여부를 사용한다.
  /// 작동 원리: 이전 화면이 있으면 복귀하고, 단독 진입이면 학생 홈으로 안전하게 이동한다.
  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const MainStudentPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = courseUiScale(context);
    final rating = RatingStore.notifier.value.ovr;

    return Scaffold(
      backgroundColor: StudentDensityTokens.background,
      body: SafeArea(
        child: FutureBuilder<List<Course>>(
          future: _future,
          builder: (context, snapshot) {
            final loadedCourses = snapshot.data ?? const <Course>[];
            final courses = loadedCourses
                .where((course) => _showCompletedCourses || !course.isCompleted)
                .toList(growable: false);
            final featured = courses.take(2).toList(growable: false);
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Ios26TopBar(
                    brandColor: kCourseGreen,
                    onBack: _goBack,
                    onTitleTap: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const MainStudentPage(),
                      ),
                      (route) => false,
                    ),
                    items: [
                      Ios26NavItem(
                        label: '학습터',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const study_center.SoWidget(),
                          ),
                        ),
                      ),
                      Ios26NavItem(
                        label: '책가방',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const docx.BookWidget(),
                          ),
                        ),
                      ),
                      Ios26NavItem(
                        label: '친구/소셜',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SoWidget()),
                        ),
                      ),
                      const Ios26NavItem(label: '코스', active: true),
                    ],
                  ),
                  _CatalogHero(
                    scale: scale,
                    featured: featured,
                    onOpenCourse: _openCourse,
                  ),
                  StudentDensityPage(
                    padding: EdgeInsets.fromLTRB(
                      28 * scale,
                      22 * scale,
                      28 * scale,
                      42 * scale,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SearchBar(
                          scale: scale,
                          controller: _searchCtrl,
                          ratingLabel: _formatVisibleOvr(rating),
                          onSearch: _load,
                          showCompletedCourses: _showCompletedCourses,
                          onShowCompletedChanged: (value) {
                            setState(() => _showCompletedCourses = value);
                          },
                        ),
                        SizedBox(height: 22 * scale),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 42 * scale),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (courses.isEmpty)
                          _EmptyCourses(scale: scale)
                        else ...[
                          _CompareCourses(
                            scale: scale,
                            courses: featured,
                            onOpenCourse: _openCourse,
                          ),
                          SizedBox(height: 24 * scale),
                          _CourseGrid(
                            scale: scale,
                            courses: courses,
                            onOpenCourse: _openCourse,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CatalogHero extends StatelessWidget {
  const _CatalogHero({
    required this.scale,
    required this.featured,
    required this.onOpenCourse,
  });

  final double scale;
  final List<Course> featured;
  final ValueChanged<Course> onOpenCourse;

  @override
  Widget build(BuildContext context) {
    final first = featured.isNotEmpty ? featured.first : null;
    final mobile = isStudentDensityMobile(context);
    return StudentDensityPage(
      padding: EdgeInsets.fromLTRB(
        28 * scale,
        34 * scale,
        28 * scale,
        10 * scale,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StudentDensityPageHeader(
            eyebrow: 'COURSE CATALOG',
            title: '코스 탐색',
            description: '내 OVR과 학습 목표에 맞는 코스를 찾고 현재 위치에서 바로 이어가세요.',
          ),
          if (first != null) ...[
            SizedBox(height: 24 * scale),
            StudentDensitySurface(
              onTap: () => onOpenCourse(first),
              color: StudentDensityTokens.dark,
              padding: EdgeInsets.all((mobile ? 20 : 26) * scale),
              child: Row(
                children: [
                  Container(
                    width: 52 * scale,
                    height: 52 * scale,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16 * scale),
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: StudentDensityTokens.dark,
                      size: 30 * scale,
                    ),
                  ),
                  SizedBox(width: 16 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const StudentDensityEyebrow(
                          'RECOMMENDED NOW',
                          color: Color(0xFF9B9BA3),
                        ),
                        SizedBox(height: 5 * scale),
                        Text(
                          first.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: (mobile ? 17 : 21) * scale,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          first.isEnrolled
                              ? '현재 진도 ${(first.progress * 100).round()}%'
                              : '추천 코스 상세 보기',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFAFAFB6),
                            fontSize: 12 * scale,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.scale,
    required this.controller,
    required this.ratingLabel,
    required this.onSearch,
    required this.showCompletedCourses,
    required this.onShowCompletedChanged,
  });

  final double scale;
  final TextEditingController controller;
  final String ratingLabel;
  final VoidCallback onSearch;
  final bool showCompletedCourses;
  final ValueChanged<bool> onShowCompletedChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: const Color(0xFFE1E6DF)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 720;
          final searchField = TextField(
            controller: controller,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: '코스명, 설명, 태그로 검색',
              filled: true,
              fillColor: const Color(0xFFF6F7F5),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14 * scale,
                vertical: 14 * scale,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8 * scale),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => onSearch(),
          );
          final actions = Wrap(
            spacing: 8 * scale,
            runSpacing: 8 * scale,
            children: [
              FilledButton.icon(
                onPressed: onSearch,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('검색'),
              ),
              OutlinedButton.icon(
                onPressed: onSearch,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text('내 OVR $ratingLabel'),
              ),
              FilterChip(
                selected: showCompletedCourses,
                onSelected: onShowCompletedChanged,
                avatar: Icon(
                  showCompletedCourses
                      ? Icons.check_circle_rounded
                      : Icons.history_rounded,
                  size: 18 * scale,
                ),
                label: const Text('완료한 코스 보기'),
                tooltip: '완료한 코스는 미리보기만 가능합니다',
              ),
            ],
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                SizedBox(height: 10 * scale),
                actions,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: searchField),
              SizedBox(width: 12 * scale),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _CompareCourses extends StatelessWidget {
  const _CompareCourses({
    required this.scale,
    required this.courses,
    required this.onOpenCourse,
  });

  final double scale;
  final List<Course> courses;
  final ValueChanged<Course> onOpenCourse;

  @override
  Widget build(BuildContext context) {
    if (courses.length < 2) return const SizedBox.shrink();
    final a = courses[0];
    final b = courses[1];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: '추천 코스 비교',
          subtitle: '가장 먼저 볼 만한 두 강좌를 한눈에 비교합니다.',
          scale: scale,
        ),
        SizedBox(height: 12 * scale),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 780;
            final firstCard = _CompareCard(
              course: a,
              accent: _accentBlue,
              scale: scale,
              onOpen: () => onOpenCourse(a),
            );
            final secondCard = _CompareCard(
              course: b,
              accent: _accentOrange,
              scale: scale,
              onOpen: () => onOpenCourse(b),
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  firstCard,
                  SizedBox(height: 12 * scale),
                  secondCard,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: firstCard),
                SizedBox(width: 12 * scale),
                Expanded(child: secondCard),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({
    required this.course,
    required this.accent,
    required this.scale,
    required this.onOpen,
  });

  final Course course;
  final Color accent;
  final double scale;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final progress = (course.progress * 100).round();
    final lessons = course.lessons > 0 ? course.lessons : course.units.length;
    return Container(
      padding: EdgeInsets.all(18 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: const Color(0xFFE1E6DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(
            icon: Icons.local_fire_department_rounded,
            text: course.targetOvr > 0
                ? '목표 OVR ${_formatVisibleOvr(course.targetOvr)}'
                : '추천 강좌',
            color: accent,
            scale: scale,
          ),
          SizedBox(height: 12 * scale),
          Text(
            course.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 21 * scale,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          SizedBox(height: 8 * scale),
          Text(
            course.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13 * scale,
              height: 1.45,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 16 * scale),
          Row(
            children: [
              _Metric(label: '강의', value: '$lessons개', scale: scale),
              SizedBox(width: 12 * scale),
              _Metric(label: '난이도', value: course.level, scale: scale),
              SizedBox(width: 12 * scale),
              _Metric(label: '진행', value: '$progress%', scale: scale),
            ],
          ),
          SizedBox(height: 16 * scale),
          FilledButton.icon(
            onPressed: onOpen,
            icon: Icon(
              course.isCompleted
                  ? Icons.visibility_outlined
                  : Icons.play_arrow_rounded,
            ),
            label: Text(
              course.isCompleted
                  ? '완료 코스 미리보기'
                  : (course.progress > 0 ? '현재 학습 보기' : '강좌 보기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseGrid extends StatelessWidget {
  const _CourseGrid({
    required this.scale,
    required this.courses,
    required this.onOpenCourse,
  });

  final double scale;
  final List<Course> courses;
  final ValueChanged<Course> onOpenCourse;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: '전체 강좌',
          subtitle: '공개 코스와 배정된 코스를 골라 수강할 수 있습니다.',
          scale: scale,
        ),
        SizedBox(height: 12 * scale),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1080
                ? 3
                : (constraints.maxWidth >= 720 ? 2 : 1);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: courses.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 12 * scale,
                crossAxisSpacing: 12 * scale,
                mainAxisExtent: columns == 1 ? 248 : 310,
              ),
              itemBuilder: (context, index) {
                final course = courses[index];
                return CourseCard(
                  course: course,
                  scale: scale,
                  onTap: () => onOpenCourse(course),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
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
    final lessons = course.lessons > 0 ? course.lessons : course.units.length;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8 * scale),
      child: Container(
        padding: EdgeInsets.all(16 * scale),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8 * scale),
          border: Border.all(color: const Color(0xFFE1E6DF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34 * scale,
                  height: 34 * scale,
                  decoration: BoxDecoration(
                    color: kCourseGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8 * scale),
                  ),
                  child: Icon(
                    Icons.ondemand_video_rounded,
                    color: kCourseGreen,
                    size: 19 * scale,
                  ),
                ),
                SizedBox(width: 10 * scale),
                Expanded(
                  child: Text(
                    course.isCompleted
                        ? '학습 완료 · 미리보기 전용'
                        : (course.level.isEmpty ? '강좌' : course.level),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12 * scale,
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  course.isCompleted
                      ? Icons.visibility_outlined
                      : Icons.arrow_forward_rounded,
                  size: 18 * scale,
                ),
              ],
            ),
            SizedBox(height: 12 * scale),
            Text(
              course.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 18 * scale,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            SizedBox(height: 8 * scale),
            Expanded(
              child: Text(
                course.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12 * scale,
                  height: 1.4,
                  color: Colors.black54,
                ),
              ),
            ),
            SizedBox(height: 12 * scale),
            Wrap(
              spacing: 6 * scale,
              runSpacing: 6 * scale,
              children: [
                MetaPill(
                  label: '$lessons강',
                  icon: Icons.video_library_rounded,
                  scale: scale,
                ),
                MetaPill(
                  label: course.duration.isEmpty ? '자율 수강' : course.duration,
                  icon: Icons.schedule_rounded,
                  scale: scale,
                ),
              ],
            ),
            SizedBox(height: 12 * scale),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: course.progress,
                minHeight: 7 * scale,
                backgroundColor: const Color(0xFFE6EAE4),
                color: _accentBlue,
              ),
            ),
            SizedBox(height: 6 * scale),
            Text(
              course.isCompleted
                  ? '완료됨 · 다시 수강할 수 없습니다'
                  : (course.status == null ? '수강 전' : '$progressPercent% 완료'),
              style: GoogleFonts.inter(
                fontSize: 11 * scale,
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCourses extends StatelessWidget {
  const _EmptyCourses({required this.scale});
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(28 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(color: const Color(0xFFE1E6DF)),
      ),
      child: Column(
        children: [
          Icon(Icons.video_library_outlined, size: 46 * scale, color: _ink),
          SizedBox(height: 12 * scale),
          Text(
            '표시할 코스가 없습니다.',
            style: GoogleFonts.inter(
              fontSize: 20 * scale,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          SizedBox(height: 8 * scale),
          Text(
            '교사가 코스를 공개하거나 그룹스터디에 배정하면 이곳에서 수강할 수 있습니다.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13 * scale,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.scale,
  });

  final String title;
  final String subtitle;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 24 * scale,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              SizedBox(height: 4 * scale),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 13 * scale,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({
    required this.icon,
    required this.text,
    required this.color,
    required this.scale,
  });

  final IconData icon;
  final String text;
  final Color color;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 6 * scale,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15 * scale, color: color),
          SizedBox(width: 6 * scale),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12 * scale,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.scale,
  });

  final String label;
  final String value;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11 * scale,
              color: Colors.black45,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 3 * scale),
          Text(
            value.isEmpty ? '-' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 15 * scale,
              color: _ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
