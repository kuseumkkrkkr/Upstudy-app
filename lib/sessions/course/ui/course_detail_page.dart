import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:s11/shared/data/models/course.dart';
import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/shared/services/api/course_service.dart';
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
import 'package:s11/sessions/course/session/course_learning_page.dart';
import 'package:s11/sessions/course/ui/course_catalog_page.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';
import 'shared.dart';

/// 코스 상세 + 유닛 목록 화면. 수강 신청/진행도를 처리한다.
class CourseDetailPage extends StatefulWidget {
  const CourseDetailPage({super.key, required this.course});
  final Course course;
  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  bool _enrolling = false;
  late Course _course;
  bool _loadingCourse = false;

  @override
  void initState() {
    super.initState();
    _course = widget.course;
    final number = _courseNumber(widget.course);
    unawaited(
      ActivityStore.recordCourseView(
        courseId: widget.course.id,
        courseNumber: number.toString(),
        screen: 'detail',
      ).catchError((_) {}),
    );
    unawaited(_loadCourseDetail(showLoading: _course.units.isEmpty));
  }

  Future<void> _loadCourseDetail({bool showLoading = true}) async {
    if (showLoading) setState(() => _loadingCourse = true);
    try {
      final full = await CourseService.fetchCourse(widget.course.id);
      if (!mounted) return;
      setState(() => _course = full);
    } finally {
      if (mounted && showLoading) setState(() => _loadingCourse = false);
    }
  }

  /// 필요 변수: 현재 코스의 수강 여부와 코스 ID를 사용한다.
  /// 작동 원리: 이미 수강 중이면 추가 API 요청 없이 학습 화면으로 이동하고, 미수강일 때만 한 번 등록한다.
  Future<void> _enrollAndGo() async {
    if (widget.course.isDemo || _course.isCompleted) return;
    if (_course.isEnrolled) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CourseLearningPage(course: _course)),
      );
      return;
    }
    setState(() => _enrolling = true);
    try {
      final enrolled = await CourseService.enroll(widget.course.id);
      if (!mounted) return;
      setState(() => _course = enrolled);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CourseLearningPage(course: enrolled)),
      );
    } catch (_) {
      setState(() => _enrolling = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('수강 신청에 실패했습니다.')));
    }
  }

  /// 필요 변수: 현재 Navigator의 이전 경로 존재 여부를 사용한다.
  /// 작동 원리: 목록으로 복귀할 수 있으면 pop하고, 단독 진입이면 코스 목록을 새 기준 화면으로 연다.
  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const CourseCatalogPage()),
    );
  }

  /// 필요한 변수는 최신 코스 상세·진행률·완료 여부다.
  /// 완료 코스의 행동을 비활성화하고 공용 코스 메뉴 아래에 읽기 전용 기록과 구성을 표시한다.
  @override
  Widget build(BuildContext context) {
    final scale = courseUiScale(context);
    final course = _course;
    final descriptionText = course.description.trim().isEmpty
        ? '설명이 없습니다.'
        : course.description;
    final progressPercent = (course.progress * 100).round();
    final isEnrolled = course.isEnrolled;
    final primaryActionLabel = course.isCompleted
        ? '완료한 코스 · 미리보기'
        : course.isDemo
        ? '데모 코스입니다'
        : (isEnrolled ? '코스 계속하기' : '수강 신청');
    final canStartCourse = !course.isDemo && !course.isCompleted;

    return Scaffold(
      backgroundColor: StudentDensityTokens.background,
      body: SafeArea(
        child: _loadingCourse
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Ios26TopBar(
                      brandColor: kCourseGreen,
                      onBack: _goBack,
                      onTitleTap: () =>
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const MainStudentPage(),
                            ),
                            (route) => false,
                          ),
                      items: studentTopNavItems(
                        context,
                        active: StudentTopDestination.courses,
                      ),
                    ),
                    StudentDensityPage(
                      padding: EdgeInsets.fromLTRB(
                        20 * scale,
                        22 * scale,
                        20 * scale,
                        0,
                      ),
                      child: _DetailHero(
                        course: course,
                        descriptionText: descriptionText,
                        scale: scale,
                        progressPercent: progressPercent,
                        primaryActionLabel: primaryActionLabel,
                        onPrimary: canStartCourse ? _enrollAndGo : null,
                        enrolling: _enrolling,
                      ),
                    ),
                    StudentDensityPage(
                      padding: EdgeInsets.fromLTRB(
                        20 * scale,
                        16 * scale,
                        20 * scale,
                        40 * scale,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 12 * scale,
                            runSpacing: 12 * scale,
                            children: [
                              _MetricCard(
                                title: '난이도',
                                value: course.level,
                                scale: scale,
                              ),
                              _MetricCard(
                                title: '예상 시간',
                                value: course.duration,
                                scale: scale,
                              ),
                              _MetricCard(
                                title: '강의 수',
                                value: course.lessons > 0
                                    ? '${course.lessons}강'
                                    : '${course.units.length}유닛',
                                scale: scale,
                              ),
                              _MetricCard(
                                title: '진행률',
                                value: '$progressPercent%',
                                scale: scale,
                              ),
                            ],
                          ),
                          SizedBox(height: 26 * scale),
                          Text(
                            '코스 설명',
                            style: GoogleFonts.inter(
                              fontSize: 22 * scale,
                              fontWeight: FontWeight.w700,
                              color: kCourseGreen,
                            ),
                          ),
                          SizedBox(height: 10 * scale),
                          Text(
                            descriptionText,
                            style: GoogleFonts.inter(
                              fontSize: 14 * scale,
                              height: 1.4,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 26 * scale),
                          Text(
                            '코스 경로',
                            style: GoogleFonts.inter(
                              fontSize: 22 * scale,
                              fontWeight: FontWeight.w700,
                              color: kCourseGreen,
                            ),
                          ),
                          SizedBox(height: 12 * scale),
                          for (final unit in course.units)
                            _CourseUnitTile(
                              unit: unit,
                              scale: scale,
                              isEnrolled: isEnrolled,
                            ),
                          SizedBox(height: 20 * scale),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: canStartCourse ? _enrollAndGo : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kCourseGreen,
                                foregroundColor: Colors.white,
                                minimumSize: Size(180 * scale, 50 * scale),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    14 * scale,
                                  ),
                                ),
                              ),
                              child: _enrolling
                                  ? SizedBox(
                                      height: 18 * scale,
                                      width: 18 * scale,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      primaryActionLabel,
                                      style: GoogleFonts.inter(
                                        fontSize: 14 * scale,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
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

class _DetailHero extends StatelessWidget {
  const _DetailHero({
    required this.course,
    required this.descriptionText,
    required this.scale,
    required this.progressPercent,
    required this.primaryActionLabel,
    required this.onPrimary,
    required this.enrolling,
  });

  final Course course;
  final String descriptionText;
  final double scale;
  final int progressPercent;
  final String primaryActionLabel;
  final VoidCallback? onPrimary;
  final bool enrolling;

  @override
  Widget build(BuildContext context) {
    final isActionEnabled = onPrimary != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        final heroHeight = isNarrow ? 420 * scale : 320 * scale;
        final textBlock = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              course.title,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 38 * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 10 * scale),
            Text(
              descriptionText,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 16 * scale,
                height: 1.4,
              ),
            ),
            SizedBox(height: 18 * scale),
            Wrap(
              spacing: 8 * scale,
              runSpacing: 6 * scale,
              children: course.focusTags
                  .map(
                    (tag) => Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10 * scale,
                        vertical: 4 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16 * scale),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11 * scale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
        final progressCard = Container(
          width: isNarrow ? double.infinity : 240 * scale,
          padding: EdgeInsets.all(18 * scale),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18 * scale),
            boxShadow: const [kCourseShadow],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '진행률',
                style: GoogleFonts.inter(
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w600,
                  color: kCourseGreen,
                ),
              ),
              SizedBox(height: 12 * scale),
              ClipRRect(
                borderRadius: BorderRadius.circular(8 * scale),
                child: LinearProgressIndicator(
                  value: course.progress,
                  minHeight: 10 * scale,
                  backgroundColor: const Color(0xFFE4E4E4),
                  color: kCourseLightGreen,
                ),
              ),
              SizedBox(height: 8 * scale),
              Text(
                '$progressPercent% 완료',
                style: GoogleFonts.inter(
                  fontSize: 12 * scale,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: 16 * scale),
              ElevatedButton(
                onPressed: isActionEnabled ? onPrimary : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kCourseGreen,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 46 * scale),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12 * scale),
                  ),
                ),
                child: enrolling
                    ? SizedBox(
                        height: 18 * scale,
                        width: 18 * scale,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        primaryActionLabel,
                        style: GoogleFonts.inter(
                          fontSize: 13 * scale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
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
                          progressCard,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: textBlock),
                          SizedBox(width: 20 * scale),
                          progressCard,
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.scale,
  });
  final String title;
  final String value;
  final double scale;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16 * scale,
        vertical: 14 * scale,
      ),
      decoration: BoxDecoration(
        color: kCourseBgGrey,
        borderRadius: BorderRadius.circular(14 * scale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12 * scale,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 6 * scale),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16 * scale,
              fontWeight: FontWeight.w600,
              color: kCourseGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseUnitTile extends StatelessWidget {
  const _CourseUnitTile({
    required this.unit,
    required this.scale,
    required this.isEnrolled,
  });
  final CourseUnit unit;
  final double scale;
  final bool isEnrolled;

  String _unitSubtitle() {
    final detail = unit.detail;
    if (detail is Map) {
      if (detail['type'] == 'textbook_view') {
        return _textbookRangeLabel(detail);
      }
      if (detail['type'] == 'problem_solve') {
        final tags = (detail['hash_tags'] as List?)?.join(', ') ?? '';
        return '문제 풀이 · 태그: $tags';
      }
      if (detail['type'] == 'exam_solve') {
        final duration = (detail['exam_duration'] as num?)?.toInt();
        return duration == null || duration <= 0
            ? '시험지 풀이'
            : '시험지 풀이 · $duration분';
      }
      return _moduleTypeLabel(detail['type']?.toString() ?? unit.type);
    }
    return detail?.toString() ?? _moduleTypeLabel(unit.type);
  }

  String _textbookRangeLabel(Map detail) {
    final from = _positivePage(detail['page_from']);
    final to = _positivePage(detail['page_to']);
    if (from != null && to != null) {
      if (from == to) return '교재 열람 ${from.toString()}P';
      return '교재 열람 ${from.toString()}~${to.toString()}P';
    }
    if (from != null) return '교재 열람 ${from.toString()}P부터';
    if (to != null) return '교재 열람 ${to.toString()}P까지';
    return '교재 열람';
  }

  int? _positivePage(dynamic value) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  IconData _typeIcon() {
    final detail = unit.detail;
    final type = detail is Map && detail['type'] != null
        ? detail['type'].toString()
        : unit.type;
    switch (type) {
      case 'problem_solve':
        return Icons.quiz_outlined;
      case 'textbook_view':
        return Icons.menu_book_outlined;
      case 'exam_solve':
        return Icons.assignment_outlined;
      case 'level_test':
        return Icons.trending_up;
      case 'wrong_answer_review':
        return Icons.replay;
      default:
        return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = isEnrolled ? _statusFor(unit.status) : null;
    final icon = _typeIcon();
    final iconColor = isEnrolled ? status!.badgeColor : kCourseGreen;
    final showProgress = isEnrolled && unit.progress != null;
    return Container(
      margin: EdgeInsets.only(bottom: 12 * scale),
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * scale),
        boxShadow: const [kCourseShadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38 * scale,
            height: 38 * scale,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12 * scale),
            ),
            child: Icon(icon, color: iconColor, size: 20 * scale),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        unit.title,
                        style: GoogleFonts.inter(
                          fontSize: 16 * scale,
                          fontWeight: FontWeight.w600,
                          color: kCourseGreen,
                        ),
                      ),
                    ),
                    if (status != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10 * scale,
                          vertical: 4 * scale,
                        ),
                        decoration: BoxDecoration(
                          color: status.badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14 * scale),
                        ),
                        child: Text(
                          status.label,
                          style: GoogleFonts.inter(
                            fontSize: 11 * scale,
                            color: status.badgeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 6 * scale),
                Text(
                  _unitSubtitle(),
                  style: GoogleFonts.inter(
                    fontSize: 13 * scale,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8 * scale),
                Row(
                  children: [
                    MetaPill(
                      label: _moduleTypeLabel(unit.type),
                      icon: icon,
                      scale: scale,
                    ),
                    SizedBox(width: 8 * scale),
                    if (unit.estimatedMinutes > 0)
                      MetaPill(
                        label: '${unit.estimatedMinutes}분',
                        icon: Icons.timer_outlined,
                        scale: scale,
                      ),
                  ],
                ),
                if (showProgress) ...[
                  SizedBox(height: 10 * scale),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6 * scale),
                    child: LinearProgressIndicator(
                      value: unit.progress,
                      minHeight: 6 * scale,
                      backgroundColor: const Color(0xFFE2E2E2),
                      color: kCourseLightGreen,
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

String _moduleTypeLabel(String type) {
  switch (type) {
    case 'textbook_view':
      return '교재 열람';
    case 'problem_solve':
      return '문제 풀이';
    case 'exam_solve':
      return '시험지 풀이';
    case 'level_test':
      return '레벨 테스트';
    case 'wrong_answer_review':
      return '오답 복습';
    case 'challenge_group':
      return '도전 학습';
    case 'curriculum_group':
      return '커리큘럼';
    default:
      return type.trim().isEmpty ? '학습 모듈' : type;
  }
}

class _StatusData {
  const _StatusData({
    required this.label,
    required this.badgeColor,
    required this.icon,
  });
  final String label;
  final Color badgeColor;
  final IconData icon;
}

_StatusData _statusFor(CourseUnitStatus status) {
  switch (status) {
    case CourseUnitStatus.completed:
      return const _StatusData(
        label: '완료',
        badgeColor: Color(0xFF2EAD62),
        icon: Icons.check_circle,
      );
    case CourseUnitStatus.active:
      return const _StatusData(
        label: '진행 중',
        badgeColor: Color(0xFFF3A43A),
        icon: Icons.play_circle_fill,
      );
    case CourseUnitStatus.locked:
      return const _StatusData(
        label: '잠금',
        badgeColor: Color(0xFF9A9A9A),
        icon: Icons.lock,
      );
  }
}

int _courseNumber(Course course) => course.hashCode & 0xFFFF;
