import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:s11/sessions/course/ui/modals/course_mode.dart';
import 'package:s11/sessions/course/ui/modals/resume_mode.dart';
import 'package:s11/sessions/exam_paper/ui/modals/exam_mode.dart';
import 'package:s11/sessions/textbook/ui/modals/book_mode.dart';
import 'package:s11/sessions/tryout_solve/ui/modals/problem_solve_mode.dart';
import 'package:s11/sessions/tryout_solve/ui/modals/weakness_review_mode.dart';
import 'package:s11/shared/ui/ios26/ios26_modal.dart';

const _green = Color(0xFF1B402B);
const _shadow = BoxShadow(
  blurRadius: 4,
  color: Color(0x33000000),
  offset: Offset(0, 2),
);

Future<T?> showStudyModeModal<T>({required BuildContext context}) {
  return showIos26Modal<T>(
    context: context,
    maxWidth: 1200,
    maxHeight: 430,
    child: const StudypageCopyWidget(),
  );
}

class StudypageCopyWidget extends StatelessWidget {
  const StudypageCopyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 1020.0;
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 380.0;
        const baseWidth = 1250.0;
        const baseHeight = 380.0;
        final width = math.min(baseWidth, maxW * 0.95);
        final height = math.min(baseHeight, maxH * 0.95);
        final scale = (width / baseWidth).clamp(0.6, 1.0);

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              top: true,
              child: Center(
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Ios26ModalShell(
                    title: '학습하기',
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_kModes.length, (index) {
                            final mode = _kModes[index];
                            VoidCallback? onTap;
                            switch (mode.destination) {
                              case _ModeDestination.resume:
                                onTap = buildResumeAction(context);
                                break;
                              case _ModeDestination.course:
                                onTap = buildCourseAction(context);
                                break;
                              case _ModeDestination.tryout:
                                onTap = buildProblemSolveAction(context);
                                break;
                              case _ModeDestination.exam:
                                onTap = buildExamAction(context);
                                break;
                              case _ModeDestination.book:
                                onTap = buildBookAction(context);
                                break;
                              case _ModeDestination.weaknessReview:
                                final rootNavigator = Navigator.of(
                                  context,
                                  rootNavigator: true,
                                );
                                onTap = buildWeaknessReviewAction(
                                  context,
                                  reopenStudyModal: () {
                                    showStudyModeModal(
                                      context: rootNavigator.context,
                                    );
                                  },
                                );
                                break;
                              case _ModeDestination.none:
                                onTap = null;
                            }
                            return _ModeCard(
                              icon: mode.icon,
                              label: mode.label,
                              scale: scale,
                              onTap: onTap,
                            );
                          }).expand((w) => [w, SizedBox(width: 20 * scale)]).toList()
                            ..removeLast(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

const _kModes = [
  _StudyMode(
    icon: Icons.restart_alt_sharp,
    label: '이어하기',
    destination: _ModeDestination.resume,
  ),
  _StudyMode(
    icon: Icons.crop_din_outlined,
    label: '코스보기',
    destination: _ModeDestination.course,
  ),
  _StudyMode(
    icon: Icons.done_outline,
    label: '취약점복습',
    destination: _ModeDestination.weaknessReview,
  ),
  _StudyMode(
    icon: Icons.north_west_sharp,
    label: '문제풀기',
    destination: _ModeDestination.tryout,
  ),
  _StudyMode(
    icon: Icons.texture,
    label: '시험',
    destination: _ModeDestination.exam,
  ),
  _StudyMode(
    icon: Icons.menu_book_outlined,
    label: '교재보기',
    destination: _ModeDestination.book,
  ),
];

enum _ModeDestination {
  none,
  resume,
  course,
  weaknessReview,
  tryout,
  exam,
  book,
}

class _StudyMode {
  const _StudyMode({
    required this.icon,
    required this.label,
    this.destination = _ModeDestination.none,
  });

  final IconData icon;
  final String label;
  final _ModeDestination destination;
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.label,
    required this.scale,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20 * scale),
      child: Container(
        width: 180 * scale,
        height: 260 * scale,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20 * scale),
          border: Border.all(color: _green, width: 2),
          boxShadow: const [_shadow],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 90 * scale, color: _green),
            SizedBox(height: 8 * scale),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 24 * scale,
                fontWeight: FontWeight.w800,
                color: _green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
