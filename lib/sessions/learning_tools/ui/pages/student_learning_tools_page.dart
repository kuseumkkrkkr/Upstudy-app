import 'package:flutter/material.dart';

import 'package:s11/sessions/learning_tools/ui/pages/focus_mode_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/notepad_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/server_chat_page.dart';
import 'package:s11/sessions/learning_tools/ui/pages/timer_page.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

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

  /// 필요한 변수는 현재 Navigator와 학생 홈 명명 라우트다.
  /// 작동 원리: 도구 화면까지 쌓인 경로를 제거하고 인증된 학생 홈을 새 루트로 열어 뒤로가기와 인증 분기를 안정화한다.
  void _goHome(BuildContext context) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/student/dashboard', (route) => false);
  }

  /// 필요한 변수는 현재 Navigator와 도구 화면이다.
  /// 작동 원리는 원래 페이지 기능을 유지하면서 모바일은 거의 전체 높이, PC는 940px 폭 모달로 연다.
  Future<void> _openTool(BuildContext context, Widget page) {
    return showStudentToolModal(context, page);
  }

  /// 필요한 변수는 화면 폭과 세 도구의 모달 콜백이다.
  /// 작동 원리는 390px에서는 한 열, PC에서는 세 열로 같은 도구 진입점과 계약 정보를 배치한다.
  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return Scaffold(
      backgroundColor: StudentDensityTokens.background,
      drawer: const AppDrawer(),
      bottomNavigationBar: mobile
          ? const MobileStudentBottomAppBar(activeRoute: '/tools')
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (context) => Ios26TopBar(
                brandColor: Colors.black,
                showLevelIndicator: false,
                onMenu: () => toggleAppDrawer(context),
                onTitleTap: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  '/student/dashboard',
                  (route) => false,
                ),
                items: studentTopNavItems(
                  context,
                  active: StudentTopDestination.learning,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: StudentDensityPage(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StudentDensityPageHeader(
                        eyebrow: 'LEARNING TOOLS',
                        title: '학습 도구',
                        description: '그래프 그리기를 제외한 도구는 학습 맥락을 유지하는 모달로 실행됩니다.',
                        showMobileDescription: true,
                        action: StudentDensityButton(
                          label: '홈으로 돌아가기',
                          primary: true,
                          onPressed: () => _goHome(context),
                        ),
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = mobile
                              ? 1
                              : constraints.maxWidth < 980
                              ? 2
                              : 3;
                          return GridView.count(
                            crossAxisCount: columns,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: mobile ? 3.05 : 3.85,
                            children: [
                              _ToolLaunchCard(
                                key: const ValueKey('learning-tools-notepad'),
                                icon: Icons.edit_outlined,
                                title: '빠른 노트',
                                subtitle: '자동 저장 · UTF-8',
                                onTap: () =>
                                    _openTool(context, const NotepadPage()),
                              ),
                              _ToolLaunchCard(
                                key: const ValueKey('learning-tools-timer'),
                                icon: Icons.schedule_outlined,
                                title: '집중 타이머',
                                subtitle: '25분 · 학습 시간 기록',
                                onTap: () =>
                                    _openTool(context, const TimerPage()),
                              ),
                              _ToolLaunchCard(
                                key: const ValueKey('learning-tools-focus'),
                                icon: Icons.radio_button_checked,
                                title: '집중 모드',
                                subtitle: '알림 보류 · 주변 UI 절제',
                                onTap: () =>
                                    _openTool(context, const FocusModePage()),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _TutorShortcut(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const ServerChatPage(standalone: true),
                          ),
                        ),
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
                      const SizedBox(height: 18),
                      const _ToolContractNote(),
                    ],
                  ),
                ),
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
    super.key,
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
  /// 작동 원리는 HTML의 흰 카드와 우측 MODAL 표시를 같은 터치 영역으로 만든다.
  @override
  Widget build(BuildContext context) => StudentDensitySurface(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    onTap: onTap,
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: StudentDensityTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: StudentDensityTokens.line),
          ),
          child: Icon(icon, color: StudentDensityTokens.ink),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                style: const TextStyle(
                  fontSize: 12,
                  color: StudentDensityTokens.muted,
                ),
              ),
            ],
          ),
        ),
        const Text(
          '모달 ›',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: StudentDensityTokens.muted,
          ),
        ),
      ],
    ),
  );
}

class _TutorShortcut extends StatelessWidget {
  const _TutorShortcut({required this.onTap});

  final VoidCallback onTap;

  /// 필요한 변수는 기존 AI 튜터 전용 페이지의 진입 콜백이다.
  /// 작동 원리는 도구 허브를 복구해도 기존 /tools 대화 기능을 별도 카드로 보존하는 것이다.
  @override
  Widget build(BuildContext context) => StudentDensitySurface(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    color: StudentDensityTokens.surfaceMuted,
    onTap: onTap,
    child: Row(
      children: [
        const Icon(Icons.auto_awesome_outlined, size: 22),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI 학습 튜터', style: TextStyle(fontWeight: FontWeight.w900)),
              SizedBox(height: 3),
              Text(
                '기존 질문·개념 설명 대화를 이어갑니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: StudentDensityTokens.muted,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          key: const ValueKey('learning-tools-tutor'),
          onPressed: onTap,
          child: const Text('열기'),
        ),
      ],
    ),
  );
}

class _ToolContractNote extends StatelessWidget {
  const _ToolContractNote();

  /// 필요한 변수는 노트·타이머·집중·AI 채팅의 실제 저장과 호출 계약이다.
  /// 작동 원리는 시안의 작은 계약 블록을 유지하되 사용자 데이터나 비밀값은 노출하지 않는다.
  @override
  Widget build(BuildContext context) => StudentDensitySurface(
    color: StudentDensityTokens.surfaceMuted,
    radius: StudentDensityTokens.radiusMedium,
    padding: const EdgeInsets.all(16),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('도구 계약', style: TextStyle(fontWeight: FontWeight.w900)),
        SizedBox(height: 7),
        Text(
          '노트는 로컬 저장하고, 타이머·집중 모드는 현재 기기에서 동작합니다. AI 튜터는 /serverchat/config와 /serverchat/message를 사용합니다.',
          style: TextStyle(
            fontSize: 11,
            height: 1.5,
            color: StudentDensityTokens.muted,
          ),
        ),
      ],
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
