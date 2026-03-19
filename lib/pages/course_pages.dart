import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:s11/models/course.dart';
import 'package:s11/services/activity_store.dart';
import '../study_center.dart' show StudyCenterNavBar;
import 'course_learning_page.dart';

const _green = Color(0xFF1B402B);
const _lightGreen = Color(0xFF45BF63);
const _bgGrey = Color(0xFFF7F7F7);
const _shadow = BoxShadow(
  blurRadius: 6,
  color: Color(0x1A000000),
  offset: Offset(0, 3),
);

double _uiScale(BuildContext context, {double min = 0.6, double max = 1.0}) {
  final width = MediaQuery.of(context).size.width;
  final scale = width / 1100;
  if (scale < min) return min;
  if (scale > max) return max;
  return scale;
}

int _courseNumber(Course course) {
  final index = kSampleCourses.indexWhere((entry) => entry.id == course.id);
  return index >= 0 ? index + 1 : 0;
}

class CourseCatalogPage extends StatelessWidget {
  const CourseCatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    final courses = kSampleCourses;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StudyCenterNavBar(),
              _CatalogHero(scale: scale),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  30 * scale,
                  30 * scale,
                  30 * scale,
                  40 * scale,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '코스 목록',
                      style: GoogleFonts.inter(
                        fontSize: 36 * scale,
                        fontWeight: FontWeight.w700,
                        color: _green,
                      ),
                    ),
                    SizedBox(height: 8 * scale),
                    Text(
                      '코스를 선택하면 구성, 혜택, 유형을 확인할 수 있습니다.',
                      style: GoogleFonts.inter(
                        fontSize: 16 * scale,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(height: 20 * scale),
                    for (final course in courses)
                      _CourseCard(
                        course: course,
                        scale: scale,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CourseDetailPage(course: course),
                            ),
                          );
                        },
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
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(16 * scale),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '제공 내용',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12 * scale),
              _HeroBullet(text: '매일 혼합 루틴', scale: scale),
              _HeroBullet(text: '적응형 점검', scale: scale),
              _HeroBullet(text: '명확한 진행 경로', scale: scale),
            ],
          ),
        );
        final textBlock = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '통합 코스 경험',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 42 * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 12 * scale),
            Text(
              '복습·문제풀이·교재 학습·약점 점검·빈출 드릴을 하나의 흐름으로 진행합니다.',
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
              Image.network(
                'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHw1fHxjdXJyaWN1bHVtfGVufDB8fHx8MTc3MjM1MzQ1MHww&ixlib=rb-4.1.0&q=80&w=1080',
                fit: BoxFit.cover,
              ),
              Container(color: const Color(0xB3000000)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 30 * scale),
                child: isNarrow
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          textBlock,
                          SizedBox(height: 20 * scale),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: 420 * scale,
                            ),
                            child: infoCard,
                          ),
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
  const _HeroBullet({required this.text, required this.scale});

  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8 * scale),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: _lightGreen, size: 18 * scale),
          SizedBox(width: 8 * scale),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 13 * scale,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
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
      borderRadius: BorderRadius.circular(18 * scale),
      child: Container(
        margin: EdgeInsets.only(bottom: 20 * scale),
        padding: EdgeInsets.all(20 * scale),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18 * scale),
          boxShadow: const [_shadow],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 6 * scale,
              height: 140 * scale,
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(6 * scale),
              ),
            ),
            SizedBox(width: 16 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    style: GoogleFonts.inter(
                      fontSize: 26 * scale,
                      fontWeight: FontWeight.w600,
                      color: _green,
                    ),
                  ),
                  SizedBox(height: 8 * scale),
                  Text(
                    course.description,
                    style: GoogleFonts.inter(
                      fontSize: 14 * scale,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 12 * scale),
                  Wrap(
                    spacing: 8 * scale,
                    runSpacing: 6 * scale,
                    children: course.focusTags
                        .map(
                          (tag) => _TagChip(label: tag, scale: scale),
                        )
                        .toList(),
                  ),
                  SizedBox(height: 16 * scale),
                  Row(
                    children: [
                      _MetaPill(
                        label: course.level,
                        icon: Icons.signal_cellular_alt,
                        scale: scale,
                      ),
                      SizedBox(width: 8 * scale),
                      _MetaPill(
                        label: course.duration,
                        icon: Icons.schedule,
                        scale: scale,
                      ),
                      SizedBox(width: 8 * scale),
                      _MetaPill(
                        label: '${course.lessons}강',
                        icon: Icons.menu_book,
                        scale: scale,
                      ),
                    ],
                  ),
                  SizedBox(height: 14 * scale),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6 * scale),
                          child: LinearProgressIndicator(
                            value: course.progress,
                            minHeight: 8 * scale,
                            backgroundColor: const Color(0xFFE2E2E2),
                            color: _lightGreen,
                          ),
                        ),
                      ),
                      SizedBox(width: 12 * scale),
                      Text(
                        '진행률 $progressPercent%',
                        style: GoogleFonts.inter(
                          fontSize: 12 * scale,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 12 * scale),
            Column(
              children: [
                ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    minimumSize: Size(130 * scale, 48 * scale),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14 * scale),
                    ),
                  ),
                  child: Text(
                    '코스 보기',
                    style: GoogleFonts.inter(
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: 10 * scale),
                Text(
                  '자세히 보기',
                  style: GoogleFonts.inter(
                    fontSize: 12 * scale,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.scale});

  final String label;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 4 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6F2),
        borderRadius: BorderRadius.circular(20 * scale),
        border: Border.all(color: const Color(0xFFD3E4D6)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11 * scale,
          color: _green,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    required this.icon,
    required this.scale,
  });

  final String label;
  final IconData icon;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 6 * scale),
      decoration: BoxDecoration(
        color: _bgGrey,
        borderRadius: BorderRadius.circular(16 * scale),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14 * scale, color: Colors.black54),
          SizedBox(width: 6 * scale),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11 * scale,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class CourseDetailPage extends StatefulWidget {
  const CourseDetailPage({super.key, required this.course});

  final Course course;

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  @override
  void initState() {
    super.initState();
    final number = _courseNumber(widget.course);
    unawaited(
      ActivityStore.recordCourseView(
        courseId: widget.course.id,
        courseNumber: number > 0 ? number.toString() : widget.course.id,
        screen: 'detail',
      ).catchError((_) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    final course = widget.course;
    final progressPercent = (course.progress * 100).round();
    final primaryActionLabel =
        course.progress > 0 ? '코스 계속하기' : '코스 시작하기';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StudyCenterNavBar(),
              _DetailHero(
                course: course,
                scale: scale,
                progressPercent: progressPercent,
                primaryActionLabel: primaryActionLabel,
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  30 * scale,
                  24 * scale,
                  30 * scale,
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
                          title: '기간',
                          value: course.duration,
                          scale: scale,
                        ),
                        _MetricCard(
                          title: '강의 수',
                          value: '${course.lessons}',
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
                    _InfoSection(
                      title: '코스 구성',
                      items: course.outline,
                      scale: scale,
                    ),
                    SizedBox(height: 20 * scale),
                    _InfoSection(
                      title: '코스 혜택',
                      items: course.benefits,
                      scale: scale,
                    ),
                    SizedBox(height: 20 * scale),
                    _InfoSection(
                      title: '코스 유형',
                      items: course.types,
                      scale: scale,
                    ),
                    SizedBox(height: 24 * scale),
                    Text(
                      '코스 진행 경로',
                      style: GoogleFonts.inter(
                        fontSize: 28 * scale,
                        fontWeight: FontWeight.w700,
                        color: _green,
                      ),
                    ),
                    SizedBox(height: 12 * scale),
                    for (final unit in course.units)
                      _CourseUnitTile(unit: unit, scale: scale),
                    SizedBox(height: 20 * scale),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CourseLearningPage(course: course),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          minimumSize: Size(180 * scale, 50 * scale),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14 * scale),
                          ),
                        ),
                        child: Text(
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
    required this.scale,
    required this.progressPercent,
    required this.primaryActionLabel,
  });

  final Course course;
  final double scale;
  final int progressPercent;
  final String primaryActionLabel;

  @override
  Widget build(BuildContext context) {
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
              course.description,
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
                        color: Colors.white.withOpacity(0.18),
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
            boxShadow: const [_shadow],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '코스 진행률',
                style: GoogleFonts.inter(
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w600,
                  color: _green,
                ),
              ),
              SizedBox(height: 12 * scale),
              ClipRRect(
                borderRadius: BorderRadius.circular(8 * scale),
                child: LinearProgressIndicator(
                  value: course.progress,
                  minHeight: 10 * scale,
                  backgroundColor: const Color(0xFFE4E4E4),
                  color: _lightGreen,
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
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CourseLearningPage(course: course),
                      ),
                    );
                  },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 46 * scale),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12 * scale),
                  ),
                ),
                child: Text(
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
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: 420 * scale,
                            ),
                            child: progressCard,
                          ),
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
      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 14 * scale),
      decoration: BoxDecoration(
        color: _bgGrey,
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
              color: _green,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.title,
    required this.items,
    required this.scale,
  });

  final String title;
  final List<String> items;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 22 * scale,
            fontWeight: FontWeight.w700,
            color: _green,
          ),
        ),
        SizedBox(height: 10 * scale),
        for (final item in items)
          Padding(
            padding: EdgeInsets.only(bottom: 8 * scale),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check, color: _lightGreen, size: 18 * scale),
                SizedBox(width: 8 * scale),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.inter(
                      fontSize: 14 * scale,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CourseUnitTile extends StatelessWidget {
  const _CourseUnitTile({required this.unit, required this.scale});

  final CourseUnit unit;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final status = _statusFor(unit.status);

    return Container(
      margin: EdgeInsets.only(bottom: 12 * scale),
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * scale),
        boxShadow: const [_shadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38 * scale,
            height: 38 * scale,
            decoration: BoxDecoration(
              color: status.badgeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12 * scale),
            ),
            child: Icon(status.icon, color: status.badgeColor, size: 20 * scale),
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
                          color: _green,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10 * scale,
                        vertical: 4 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: status.badgeColor.withOpacity(0.1),
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
                  unit.detail,
                  style: GoogleFonts.inter(
                    fontSize: 13 * scale,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8 * scale),
                Row(
                  children: [
                    _MetaPill(
                      label: unit.type,
                      icon: Icons.category_outlined,
                      scale: scale,
                    ),
                    SizedBox(width: 8 * scale),
                    if (unit.estimatedMinutes > 0)
                      _MetaPill(
                        label: '${unit.estimatedMinutes}분',
                        icon: Icons.timer_outlined,
                        scale: scale,
                      ),
                  ],
                ),
                if (unit.progress != null) ...[
                  SizedBox(height: 10 * scale),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6 * scale),
                    child: LinearProgressIndicator(
                      value: unit.progress,
                      minHeight: 6 * scale,
                      backgroundColor: const Color(0xFFE2E2E2),
                      color: _lightGreen,
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
        label: '잠김',
        badgeColor: Color(0xFF9A9A9A),
        icon: Icons.lock,
      );
  }
}
