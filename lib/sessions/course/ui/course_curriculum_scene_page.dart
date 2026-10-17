import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:s11/shared/data/models/course.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';

/// 실제 코스의 단계를 고르는 장면. 실행은 선택 결과를 받은 부모가 담당한다.
/// 반환값은 `(CourseUnit, CourseUnitMission)`이며 취소는 null이다.
class CourseCurriculumScenePage extends StatefulWidget {
  const CourseCurriculumScenePage({super.key, required this.course});

  final Course course;

  @override
  State<CourseCurriculumScenePage> createState() => _CourseCurriculumScenePageState();
}

class _CourseCurriculumScenePageState extends State<CourseCurriculumScenePage> {
  int _tab = 0;
  (CourseUnit, CourseUnitMission)? _selected;

  /// 서버 모듈 종류만 분류한다. 알 수 없는 종류는 전체 단원에서만 보인다.
  List<(CourseUnit, CourseUnitMission)> get _missions => [
    for (final unit in widget.course.units)
      for (final mission in unit.missions)
        if (_tab == 0 || _matchesTab(mission)) (unit, mission),
  ];

  bool _matchesTab(CourseUnitMission mission) {
    final detail = mission.detail;
    final type = detail is Map ? detail['type']?.toString() : null;
    return switch (_tab) {
      1 => type == 'challenge_group' || type == 'problem_solve',
      2 => type == 'exam_solve' || type == 'level_test',
      3 => type == 'wrong_answer_review' || type == 'review',
      _ => true,
    };
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width <= 720;
    final missions = _missions;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: Focus(autofocus: true, child: StudentHtmlShell(
      title: '커리큘럼 단위',
      activeRoute: '/courses',
      railWidth: MediaQuery.sizeOf(context).width > 1040 ? 84 : 72,
      reserveContextTrack: !mobile,
      showBottomNavigation: false,
      onMenu: _close,
      child: LayoutBuilder(builder: (context, constraints) {
        return Stack(children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(mobile ? 24 : 48),
              child: IgnorePointer(child: SingleChildScrollView(child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: (constraints.maxHeight - (mobile ? 48 : 96)).clamp(0, double.infinity).toDouble()),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                for (final shape in [(0.48, 96.0), (0.75, 190.0), (0.62, 120.0)])
                  FractionallySizedBox(widthFactor: shape.$1, child: Container(height: shape.$2, color: StudentDensityTokens.line)),
              ])))),
            ),
          ),
          Align(
            alignment: mobile ? Alignment.bottomCenter : Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: mobile ? constraints.maxWidth : 660,
                maxHeight: mobile ? constraints.maxHeight * .78 : (constraints.maxHeight - 40).clamp(0, 720).toDouble(),
              ),
              child: Container(
                key: const ValueKey('course-curriculum-sheet'),
                decoration: BoxDecoration(
                  color: StudentDensityTokens.surface,
                  border: Border.all(color: StudentDensityTokens.line),
                ),
                padding: EdgeInsets.all(mobile ? 14 : 18),
                child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      constraints: const BoxConstraints(minHeight: 50),
                      padding: const EdgeInsets.only(bottom: 10),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: StudentDensityTokens.line))),
                      child: Row(children: [
                        const Expanded(child: Text('커리큘럼 단위', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                        SizedBox(width: 40, height: 40, child: IconButton(tooltip: '닫기', onPressed: _close, icon: const Icon(Icons.close, size: 19))),
                      ]),
                    ),
                    SizedBox(height: mobile ? 10 : 12),
                    Row(children: [
                      for (final entry in ['단원', '도전', '시험', '복습'].indexed)
                        Expanded(child: Semantics(
                          selected: _tab == entry.$1,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: Size(0, mobile ? 38 : 40),
                              foregroundColor: _tab == entry.$1 ? Colors.white : StudentDensityTokens.muted,
                              backgroundColor: _tab == entry.$1 ? StudentDensityTokens.dark : StudentDensityTokens.surface,
                              shape: const RoundedRectangleBorder(side: BorderSide(color: StudentDensityTokens.line)),
                              textStyle: const TextStyle(fontFamily: 'Noto Sans KR', fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                            onPressed: () => setState(() { _tab = entry.$1; _selected = null; }),
                            child: Text(entry.$2),
                          ),
                        )),
                    ]),
                    const SizedBox(height: 20),
                    if (missions.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('등록된 학습 단계가 없습니다.')),
                    for (final entry in missions.indexed)
                      Semantics(
                        selected: _selected == entry.$2,
                        enabled: entry.$2.$1.status != CourseUnitStatus.locked,
                        label: entry.$2.$1.status == CourseUnitStatus.locked ? '${entry.$2.$2.title}, 잠긴 학습 단계' : entry.$2.$2.title,
                        child: InkWell(
                          onTap: entry.$2.$1.status == CourseUnitStatus.locked ? null : () => setState(() => _selected = entry.$2),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 54),
                            decoration: BoxDecoration(
                              color: _selected == entry.$2 ? StudentDensityTokens.surfaceMuted : null,
                              border: Border(
                                bottom: const BorderSide(color: StudentDensityTokens.line),
                                left: BorderSide(color: _selected == entry.$2 ? StudentDensityTokens.dark : Colors.transparent, width: 4),
                              ),
                            ),
                            child: Row(children: [
                              SizedBox(width: 42, child: Text('${entry.$1 + 1}'.padLeft(2, '0'), style: const TextStyle(fontSize: 10, color: StudentDensityTokens.muted, fontWeight: FontWeight.w900))),
                              Expanded(child: Text(entry.$2.$2.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                              if (entry.$2.$1.status == CourseUnitStatus.locked) const Icon(Icons.lock_outline, size: 18),
                            ]),
                          ),
                        ),
                      ),
                    SizedBox(height: mobile ? 14 : 16),
                    Row(children: [
                      Expanded(flex: 3, child: FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 44), shape: const RoundedRectangleBorder(), backgroundColor: StudentDensityTokens.dark, textStyle: const TextStyle(fontFamily: 'Noto Sans KR', fontSize: 10, fontWeight: FontWeight.w900)),
                        onPressed: _selected == null ? null : () => Navigator.of(context).pop(_selected),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('선택 단계 시작'), SizedBox(width: 8), Icon(Icons.arrow_forward, size: 18)]),
                      )),
                      SizedBox(width: mobile ? 6 : 8),
                      Expanded(flex: 2, child: OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), shape: const RoundedRectangleBorder(), textStyle: const TextStyle(fontFamily: 'Noto Sans KR', fontSize: 10, fontWeight: FontWeight.w900)),
                        onPressed: _close,
                        child: const Text('닫기'),
                      )),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ]);
      }),
    )));
  }
}
