import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../models/course.dart';

Future<Course?> showCurriculumModal({required BuildContext context}) {
  return showDialog<Course>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (context) {
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
            const Center(child: CourseSelectModal()),
          ],
        ),
      );
    },
  );
}

class CourseSelectModal extends StatelessWidget {
  const CourseSelectModal({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 980.0;
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 600.0;
        final width = math.min(980.0, maxW * 0.95);
        final height = math.min(560.0, maxH * 0.9);
        final scale = (width / 980.0).clamp(0.7, 1.0);

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18 * scale),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(18 * scale),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.close, size: 26 * scale),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    SizedBox(width: 8 * scale),
                    Text(
                      '코스를 선택하세요',
                      style: TextStyle(
                        fontSize: 22 * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.all(20 * scale),
                  itemCount: kSampleCourses.length,
                  separatorBuilder: (_, __) => SizedBox(height: 14 * scale),
                  itemBuilder: (context, index) {
                    final course = kSampleCourses[index];
                    return _CourseSelectCard(
                      course: course,
                      scale: scale,
                      onTap: () => Navigator.of(context).pop(course),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 18 * scale),
                child: Text(
                  '학습 경로를 이어갈 코스를 선택하세요.',
                  style: TextStyle(fontSize: 12 * scale, color: Colors.black54),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CourseSelectCard extends StatelessWidget {
  const _CourseSelectCard({
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
      borderRadius: BorderRadius.circular(16 * scale),
      child: Container(
        padding: EdgeInsets.all(16 * scale),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F6F6),
          borderRadius: BorderRadius.circular(16 * scale),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    style: TextStyle(
                      fontSize: 18 * scale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6 * scale),
                  Text(
                    course.description,
                    style: TextStyle(
                      fontSize: 12 * scale,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 12 * scale),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6 * scale),
                    child: LinearProgressIndicator(
                      value: course.progress,
                      minHeight: 6 * scale,
                      backgroundColor: const Color(0xFFE2E2E2),
                      color: const Color(0xFF45BF63),
                    ),
                  ),
                  SizedBox(height: 6 * scale),
                  Text(
                    '진행률 $progressPercent%',
                    style: TextStyle(fontSize: 11 * scale, color: Colors.black54),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12 * scale),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B402B),
                foregroundColor: Colors.white,
                minimumSize: Size(120 * scale, 40 * scale),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12 * scale),
                ),
              ),
              child: Text(
                '코스 열기',
                style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
