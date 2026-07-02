import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:s11/shared/data/models/course.dart';
import 'package:s11/shared/services/api/course_service.dart';
import 'package:s11/shared/business/repositories/rating_store.dart';
import 'package:s11/sessions/textbook/ui/pages/docx_box.dart' as docx;
import 'package:s11/sessions/friend/friend.dart';
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
import 'package:s11/sessions/legacy_cleanup/session/study_center.dart'
    as study_center;
import 'package:s11/sessions/course/ui/course_detail_page.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'shared.dart';

/// 코스 목록/추천 화면. 검색과 추천 OVR을 한 곳에서 처리.
class CourseCatalogPage extends StatefulWidget {
  const CourseCatalogPage({super.key});

  @override
  State<CourseCatalogPage> createState() => _CourseCatalogPageState();
}

class _CourseCatalogPageState extends State<CourseCatalogPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  Future<List<Course>>? _future;
  double? _lastRecommend;
  static const double _ratingOvrDivider = 128;

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
      _future = CourseService.fetchCourses(
        keyword: keyword.isEmpty ? null : keyword,
        recommendOvr: recommend,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = courseUiScale(context);
    final recommend = _lastRecommend;

    return Scaffold(
      backgroundColor: kCourseBgGrey,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Ios26TopBar(
                brandColor: kCourseGreen,
                onTitleTap: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MainStudentPage()),
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
                    label: '문서함',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const docx.BookWidget()),
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
              _CatalogHero(scale: scale),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  30 * scale,
                  30 * scale,
                  30 * scale,
                  40 * scale,
                ),
                child: Container(
                  padding: EdgeInsets.all(20 * scale),
                  decoration: BoxDecoration(
                    color: kCourseSurface,
                    borderRadius: BorderRadius.circular(20 * scale),
                    border: Border.all(color: kCourseBorder),
                    boxShadow: const [kCourseShadow],
                  ),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '코스 목록',
                      style: GoogleFonts.inter(
                        fontSize: 36 * scale,
                        fontWeight: FontWeight.w700,
                        color: kCourseGreen,
                      ),
                    ),
                    SizedBox(height: 8 * scale),
                    Text(
                      '수강 신청 후 진행도와 현황이 계정별로 반영됩니다. 데모 코스는 관람만 가능합니다.',
                      style: GoogleFonts.inter(
                        fontSize: 16 * scale,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(height: 16 * scale),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: '코스 검색 (제목/설명/태그)',
                              filled: true,
                              fillColor: kCourseBgGrey,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14 * scale,
                                vertical: 12 * scale,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14 * scale),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _load(),
                          ),
                        ),
                        SizedBox(width: 10 * scale),
                        ElevatedButton(
                          onPressed: _load,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kCourseGreen,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 14 * scale,
                              vertical: 12 * scale,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12 * scale),
                            ),
                          ),
                          child: Text(
                            '검색',
                            style: GoogleFonts.inter(
                              fontSize: 13 * scale,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(width: 8 * scale),
                        OutlinedButton(
                          onPressed: _load,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kCourseGreen,
                            side: const BorderSide(color: kCourseGreen),
                            padding: EdgeInsets.symmetric(
                              horizontal: 12 * scale,
                              vertical: 12 * scale,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12 * scale),
                            ),
                          ),
                          child: Text(
                            recommend == null
                                ? '추천 새로고침'
                                : '추천 OVR ${recommend.toStringAsFixed(1)}',
                            style: GoogleFonts.inter(
                              fontSize: 12 * scale,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20 * scale),
                    FutureBuilder<List<Course>>(
                      future: _future,
                      builder: (context, snapshot) {
                        final courses = snapshot.data ?? const <Course>[];
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 20 * scale),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        if (courses.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 12 * scale),
                            child: Text(
                              '등록된 코스가 없습니다.',
                              style: GoogleFonts.inter(
                                fontSize: 14 * scale,
                                color: Colors.black54,
                              ),
                            ),
                          );
                        }
                        final recommendCount = recommend != null
                            ? (courses.length >= 3 ? 3 : courses.length)
                            : 0;
                        final recommended = recommendCount > 0
                            ? courses.take(recommendCount).toList()
                            : const <Course>[];
                        final rest = recommendCount > 0
                            ? courses.skip(recommendCount).toList()
                            : courses;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (recommended.isNotEmpty) ...[
                              Text(
                                '추천 코스',
                                style: GoogleFonts.inter(
                                  fontSize: 22 * scale,
                                  fontWeight: FontWeight.w700,
                                  color: kCourseGreen,
                                ),
                              ),
                              SizedBox(height: 12 * scale),
                              for (final course in recommended)
                                CourseCard(
                                  course: course,
                                  scale: scale,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CourseDetailPage(course: course),
                                      ),
                                    );
                                  },
                                ),
                              SizedBox(height: 16 * scale),
                              if (rest.isNotEmpty)
                                Text(
                                  '전체 코스',
                                  style: GoogleFonts.inter(
                                    fontSize: 18 * scale,
                                    fontWeight: FontWeight.w700,
                                    color: kCourseGreen,
                                  ),
                                ),
                              SizedBox(height: 8 * scale),
                            ],
                            for (final course in rest)
                              CourseCard(
                                course: course,
                                scale: scale,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CourseDetailPage(course: course),
                                    ),
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogHero extends StatelessWidget {
  const _CatalogHero({required this.scale});
  final double scale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        final heroHeight = isNarrow ? 420 * scale : 340 * scale;
        final infoCard = Container(
          width: isNarrow ? double.infinity : 220 * scale,
          padding: EdgeInsets.all(16 * scale),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16 * scale),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _HeroBullet(text: '매일 학습 루틴'),
              _HeroBullet(text: '문제·시험·교재 한곳에'),
              _HeroBullet(text: '진행도/추천 자동 반영'),
            ],
          ),
        );
        final textBlock = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '맞춤형 코스 탐색',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 42 * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 12 * scale),
            Text(
              '문제풀기·시험지·교재를 일정에 따라 이어서 학습하고, OVR에 맞춰 자동 추천을 받으세요.',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 18 * scale,
              ),
            ),
          ],
        );

        return SizedBox(
          height: heroHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF183D2B), Color(0xFF2A6B4B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 30 * scale),
                child: isNarrow
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          textBlock,
                          SizedBox(height: 20 * scale),
                          infoCard,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: textBlock),
                          SizedBox(width: 20 * scale),
                          infoCard,
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroBullet extends StatelessWidget {
  const _HeroBullet({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: kCourseLightGreen, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
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
    final lessonsLabel =
        course.lessons > 0 ? '${course.lessons}강' : '${course.units.length}유닛';
    final isDemo = course.isDemo;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 220),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, (1 - t) * 8),
        child: Opacity(opacity: t, child: child),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18 * scale),
        child: Container(
        margin: EdgeInsets.only(bottom: 20 * scale),
        padding: EdgeInsets.all(20 * scale),
        decoration: BoxDecoration(
          color: kCourseSurface,
          borderRadius: BorderRadius.circular(18 * scale),
          border: Border.all(color: kCourseBorder),
          boxShadow: const [kCourseShadow],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 6 * scale,
              height: 140 * scale,
              decoration: BoxDecoration(
                color: kCourseGreen,
                borderRadius: BorderRadius.circular(6 * scale),
              ),
            ),
            SizedBox(width: 16 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.title,
                              style: GoogleFonts.inter(
                                fontSize: 26 * scale,
                                fontWeight: FontWeight.w600,
                                color: kCourseGreen,
                              ),
                            ),
                            SizedBox(height: 4 * scale),
                            Text(
                              lessonsLabel,
                              style: GoogleFonts.inter(
                                fontSize: 12 * scale,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          ElevatedButton(
                            onPressed: onTap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isDemo ? Colors.grey.shade500 : kCourseGreen,
                              foregroundColor: Colors.white,
                              minimumSize: Size(130 * scale, 48 * scale),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14 * scale),
                              ),
                            ),
                            child: Text(
                              isDemo
                                  ? '코스 보기'
                                  : (course.progress > 0 ? '이어하기' : '코스 보기'),
                              style: GoogleFonts.inter(
                                fontSize: 14 * scale,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(height: 10 * scale),
                          Text(
                            course.targetOvr > 0
                                ? '목표 OVR ${course.targetOvr}'
                                : '추천 코스',
                            style: GoogleFonts.inter(
                              fontSize: 12 * scale,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8 * scale),
                  if (isDemo)
                    Text(
                      '데모 코스입니다. 진행도는 기록되지 않습니다.',
                      style: GoogleFonts.inter(
                        fontSize: 12 * scale,
                        color: Colors.black54,
                      ),
                    )
                  else if (course.status != null)
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6 * scale),
                            child: LinearProgressIndicator(
                              value: course.progress,
                              minHeight: 8 * scale,
                              backgroundColor: const Color(0xFFE2E2E2),
                              color: kCourseLightGreen,
                            ),
                          ),
                        ),
                        SizedBox(width: 12 * scale),
                        Text(
                          '$progressPercent%',
                          style: GoogleFonts.inter(
                            fontSize: 12 * scale,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      '수강 신청 후 진행률이 표시됩니다.',
                      style: GoogleFonts.inter(
                        fontSize: 12 * scale,
                        color: Colors.black54,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
