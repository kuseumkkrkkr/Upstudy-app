import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:s11/models/course.dart';
import 'package:s11/services/activity_store.dart';
import '../study_center.dart' show StudyCenterNavBar;

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

class CourseLearningPage extends StatefulWidget {
  const CourseLearningPage({super.key, required this.course});

  final Course course;

  @override
  State<CourseLearningPage> createState() => _CourseLearningPageState();
}

class _CourseLearningPageState extends State<CourseLearningPage> {
  final Set<int> _expandedUnits = {};

  @override
  void initState() {
    super.initState();
    final number = _courseNumber(widget.course);
    unawaited(
      ActivityStore.recordCourseView(
        courseId: widget.course.id,
        courseNumber: number > 0 ? number.toString() : widget.course.id,
        screen: 'learning',
      ).catchError((_) {}),
    );
  }

  void _toggleUnit(int index) {
    setState(() {
      if (_expandedUnits.contains(index)) {
        _expandedUnits.remove(index);
      } else {
        _expandedUnits.add(index);
      }
    });
  }

  void _startLearning() {
    final index = widget.course.units.indexWhere(
      (unit) => unit.status != CourseUnitStatus.locked,
    );
    if (index == -1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No available unit yet.')));
      return;
    }
    setState(() => _expandedUnits.add(index));
  }

  void _handleMissionTap(CourseUnit unit, CourseUnitMission mission) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mission started: ${unit.title} - ${mission.title}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = _uiScale(context);
    final course = widget.course;
    final progressPercent = (course.progress * 100).round();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StudyCenterNavBar(),
              _LearningHero(
                course: course,
                scale: scale,
                progressPercent: progressPercent,
                onPrimaryAction: _startLearning,
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
                    Text(
                      '코스 진행 경로',
                      style: GoogleFonts.inter(
                        fontSize: 28 * scale,
                        fontWeight: FontWeight.w700,
                        color: _green,
                      ),
                    ),
                    SizedBox(height: 10 * scale),
                    Text(
                      '화살표를 눌러 상세 미션을 확인하고 실행하세요.',
                      style: GoogleFonts.inter(
                        fontSize: 14 * scale,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(height: 18 * scale),
                    for (var i = 0; i < course.units.length; i++)
                      _LearningUnitCard(
                        unit: course.units[i],
                        scale: scale,
                        isExpanded: _expandedUnits.contains(i),
                        onToggle: () => _toggleUnit(i),
                        onMissionTap: (mission) =>
                            _handleMissionTap(course.units[i], mission),
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

class _LearningHero extends StatelessWidget {
  const _LearningHero({
    required this.course,
    required this.scale,
    required this.progressPercent,
    required this.onPrimaryAction,
  });

  final Course course;
  final double scale;
  final int progressPercent;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        final heroHeight = isNarrow ? 420 * scale : 320 * scale;
        final detailBlock = Column(
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
                '현재 진행률',
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
                onPressed: onPrimaryAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 46 * scale),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12 * scale),
                  ),
                ),
                child: Text(
                  '학습 계속하기',
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
                          detailBlock,
                          SizedBox(height: 20 * scale),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 420 * scale),
                            child: progressCard,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: detailBlock),
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

class _LearningUnitCard extends StatelessWidget {
  const _LearningUnitCard({
    required this.unit,
    required this.scale,
    required this.isExpanded,
    required this.onToggle,
    required this.onMissionTap,
  });

  final CourseUnit unit;
  final double scale;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ValueChanged<CourseUnitMission> onMissionTap;

  @override
  Widget build(BuildContext context) {
    final status = _statusFor(unit.status);
    final canExpand = unit.missions.isNotEmpty;
    final arrowIcon = isExpanded
        ? Icons.keyboard_arrow_up_rounded
        : Icons.keyboard_arrow_down_rounded;

    return Container(
      margin: EdgeInsets.only(bottom: 12 * scale),
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * scale),
        boxShadow: const [_shadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38 * scale,
                height: 38 * scale,
                decoration: BoxDecoration(
                  color: status.badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12 * scale),
                ),
                child: Icon(
                  status.icon,
                  color: status.badgeColor,
                  size: 20 * scale,
                ),
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
                            label: '${unit.estimatedMinutes} min',
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
              SizedBox(width: 8 * scale),
              IconButton(
                icon: Icon(arrowIcon, color: canExpand ? _green : Colors.grey),
                onPressed: canExpand ? onToggle : null,
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: EdgeInsets.only(top: 16 * scale),
              child: _MissionList(
                unit: unit,
                scale: scale,
                onMissionTap: onMissionTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionList extends StatelessWidget {
  const _MissionList({
    required this.unit,
    required this.scale,
    required this.onMissionTap,
  });

  final CourseUnit unit;
  final double scale;
  final ValueChanged<CourseUnitMission> onMissionTap;

  @override
  Widget build(BuildContext context) {
    if (unit.missions.isEmpty) {
      return Text(
        'No missions available yet.',
        style: GoogleFonts.inter(fontSize: 13 * scale, color: Colors.black54),
      );
    }

    final isLocked = unit.status == CourseUnitStatus.locked;
    return Column(
      children: [
        for (final mission in unit.missions)
          Container(
            margin: EdgeInsets.only(bottom: 10 * scale),
            padding: EdgeInsets.all(14 * scale),
            decoration: BoxDecoration(
              color: _bgGrey,
              borderRadius: BorderRadius.circular(14 * scale),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission.title,
                        style: GoogleFonts.inter(
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.w600,
                          color: _green,
                        ),
                      ),
                      SizedBox(height: 4 * scale),
                      Text(
                        mission.detail,
                        style: GoogleFonts.inter(
                          fontSize: 12 * scale,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12 * scale),
                ElevatedButton(
                  onPressed: isLocked ? null : () => onMissionTap(mission),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    minimumSize: Size(110 * scale, 38 * scale),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12 * scale),
                    ),
                  ),
                  child: Text(
                    mission.actionLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w600,
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
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 6 * scale,
      ),
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
        label: 'Completed',
        badgeColor: Color(0xFF2EAD62),
        icon: Icons.check_circle,
      );
    case CourseUnitStatus.active:
      return const _StatusData(
        label: 'In progress',
        badgeColor: Color(0xFFF3A43A),
        icon: Icons.play_circle_fill,
      );
    case CourseUnitStatus.locked:
      return const _StatusData(
        label: 'Locked',
        badgeColor: Color(0xFF9A9A9A),
        icon: Icons.lock,
      );
  }
}
