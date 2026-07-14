import 'package:flutter/material.dart';
import 'package:s11/sessions/course/ui/modals/course_mode.dart';
import 'package:s11/sessions/course/ui/modals/resume_mode.dart';
import 'package:s11/sessions/exam_paper/ui/modals/exam_mode.dart';
import 'package:s11/sessions/textbook/ui/modals/book_mode.dart';
import 'package:s11/sessions/tryout_solve/ui/modals/problem_solve_mode.dart';
import 'package:s11/sessions/review_course/review_course.dart';
import 'package:s11/shared/ui/ios26/ios26_modal.dart';

/// 필요한 변수는 학생 홈 context다.
/// 작동 원리는 HTML 액션 패널과 같은 세로형 학습 메뉴를 화면 중앙에 열어 기존 목적지 콜백을 유지하는 것이다.
Future<T?> showStudyModeModal<T>({required BuildContext context}) {
  return showIos26Modal<T>(
    context: context,
    maxWidth: 720,
    maxHeight: 900,
    child: const StudypageCopyWidget(),
  );
}

class StudypageCopyWidget extends StatelessWidget {
  const StudypageCopyWidget({super.key});

  /// 필요한 변수는 여섯 학습 모드와 현재 Navigator다.
  /// 작동 원리는 HTML과 동일한 제목·설명·세로 목록을 만들고 각 행을 기존 학습 기능으로 연결하는 것이다.
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Material(
        color: const Color(0xFFF9F9FA),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 18, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STUDY MODE',
                          style: TextStyle(
                            color: Colors.black45,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '학습하기',
                          style: TextStyle(
                            fontSize: 30,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 38, 24, 20),
              child: Text(
                '시작할 학습 유형을 선택하세요.',
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                itemCount: _kModes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final mode = _kModes[index];
                  return _ModeCard(
                    icon: mode.icon,
                    label: mode.label,
                    description: mode.description,
                    onTap: _actionFor(context, mode.destination),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 필요한 변수는 화면 context와 학습 목적지다.
  /// 작동 원리는 시각 행과 기존 코스·복습·문제·시험·교재 기능 사이의 콜백을 한곳에서 결정하는 것이다.
  VoidCallback? _actionFor(BuildContext context, _ModeDestination destination) {
    return switch (destination) {
      _ModeDestination.resume => buildResumeAction(context),
      _ModeDestination.course => buildCourseAction(context),
      _ModeDestination.tryout => buildProblemSolveAction(context),
      _ModeDestination.exam => buildExamAction(context),
      _ModeDestination.book => buildBookAction(context),
      _ModeDestination.weaknessReview => () => showReviewCoursePage(
        context: context,
      ),
      _ModeDestination.none => null,
    };
  }
}

const _kModes = [
  _StudyMode(
    icon: Icons.restart_alt_sharp,
    label: '이어하기',
    description: '마지막 학습 위치',
    destination: _ModeDestination.resume,
  ),
  _StudyMode(
    icon: Icons.crop_din_outlined,
    label: '코스보기',
    description: '코스 탐색과 상세',
    destination: _ModeDestination.course,
  ),
  _StudyMode(
    icon: Icons.done_outline,
    label: '복습',
    description: '오답과 약점 태그',
    destination: _ModeDestination.weaknessReview,
  ),
  _StudyMode(
    icon: Icons.north_west_sharp,
    label: '문제풀기',
    description: '문제 유형 선택 후 풀이',
    destination: _ModeDestination.tryout,
  ),
  _StudyMode(
    icon: Icons.texture,
    label: '시험',
    description: '시험지 선택 후 시작',
    destination: _ModeDestination.exam,
  ),
  _StudyMode(
    icon: Icons.menu_book_outlined,
    label: '교재보기',
    description: '책가방에서 교재 선택',
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
    required this.description,
    this.destination = _ModeDestination.none,
  });

  final IconData icon;
  final String label;
  final String description;
  final _ModeDestination destination;
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.label,
    required this.description,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE0E0E3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 24, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
