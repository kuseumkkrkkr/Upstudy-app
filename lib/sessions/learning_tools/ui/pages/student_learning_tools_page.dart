import 'package:flutter/material.dart';

import 'package:s11/sessions/learning_tools/ui/pages/focus_mode_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/notepad_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/timer_page.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';

/// 필요한 변수는 현재 Navigator 문맥과 노트·타이머·집중 화면이다.
/// 작동 원리: 모바일은 HTML 액션 패널처럼 전체 화면, PC는 최대 940px 모달로 도구를 연다.
Future<void> showStudentToolModal(BuildContext context, Widget page) {
  final size = MediaQuery.sizeOf(context);
  final mobile = size.width <= StudentDensityTokens.mobileBreakpoint;
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .42),
    builder: (_) => Dialog(
      insetPadding: mobile
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(mobile ? 0 : 28),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: mobile ? size.width : 940,
          maxHeight: mobile ? size.height : 900,
        ),
        child: page,
      ),
    ),
  );
}

class StudentLearningToolsPage extends StatelessWidget {
  const StudentLearningToolsPage({super.key});

  /// 필요한 변수는 현재 Navigator와 도구 화면이다.
  /// 작동 원리는 원래 페이지 기능을 유지하면서 모바일은 거의 전체 높이, PC는 940px 폭 모달로 연다.
  Future<void> _openTool(BuildContext context, Widget page) {
    return showStudentToolModal(context, page);
  }

  /// 필요한 변수는 화면 폭과 세 도구의 모달 콜백이다.
  /// 작동 원리는 HTML의 제목·홈 버튼·세 개 전폭 도구 카드·기능 태그를 같은 순서로 렌더한다.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudentDensityTokens.background,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (context) => Ios26TopBar(
                brandColor: Colors.black,
                showLevelIndicator: false,
                onMenu: () => toggleAppDrawer(context),
                items: const [],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 24, 14, 44),
                children: [
                  const Text(
                    'LEARNING TOOLS',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.7,
                      color: Colors.black54,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '학습 도구',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '그래프 그리기를 제외한 도구는 학습 맥락을 유지하는 모달로 실행됩니다.',
                    style: TextStyle(color: Colors.black45, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/study-center'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF202022),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('홈으로 돌아가기'),
                  ),
                  const SizedBox(height: 14),
                  _ToolLaunchCard(
                    icon: Icons.edit_outlined,
                    title: '빠른 노트',
                    subtitle: '자동 저장 · UTF-8',
                    onTap: () => _openTool(context, const NotepadPage()),
                  ),
                  const SizedBox(height: 14),
                  _ToolLaunchCard(
                    icon: Icons.schedule_outlined,
                    title: '집중 타이머',
                    subtitle: '25분 · 학습 시간 기록',
                    onTap: () => _openTool(context, const TimerPage()),
                  ),
                  const SizedBox(height: 14),
                  _ToolLaunchCard(
                    icon: Icons.radio_button_checked,
                    title: '집중 모드',
                    subtitle: '알림 보류 · 주변 UI 절제',
                    onTap: () => _openTool(context, const FocusModePage()),
                  ),
                  const SizedBox(height: 14),
                  const Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _ToolFeatureChip('모달 진입'),
                      _ToolFeatureChip('노트패드 필압 필기'),
                      _ToolFeatureChip('무한 확장 캔버스'),
                      _ToolFeatureChip('펜·형광펜·3색·4굵기'),
                      _ToolFeatureChip('지우개·라인·실행 취소'),
                      _ToolFeatureChip('500ms 로컬 저장'),
                      _ToolFeatureChip('스톱워치·타이머 전환'),
                      _ToolFeatureChip('랩 기록'),
                      _ToolFeatureChip('시·분·초 직접 입력'),
                      _ToolFeatureChip('시간 프리셋'),
                      _ToolFeatureChip('집중 모드 30분~12시간'),
                      _ToolFeatureChip('3초 잠금 해제'),
                      _ToolFeatureChip('서버 AI 채팅'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolLaunchCard extends StatelessWidget {
  const _ToolLaunchCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// 필요한 변수는 도구 아이콘·문구·모달 콜백이다.
  /// 작동 원리는 HTML의 흰 전폭 카드와 우측 MODAL 표시를 동일한 터치 영역으로 만든다.
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: const BorderSide(color: Color(0xFFE3E3E5)),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F8),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFE0E0E2)),
              ),
              child: Icon(icon, color: Colors.black87),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ],
              ),
            ),
            const Text(
              '모달 ›',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ToolFeatureChip extends StatelessWidget {
  const _ToolFeatureChip(this.label);

  final String label;

  /// 필요한 변수는 기능 레이블이다.
  /// 작동 원리는 시안의 조밀한 기능 태그를 작은 둥근 테두리로 표시한다.
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE1E1E3)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Colors.black54,
      ),
    ),
  );
}
