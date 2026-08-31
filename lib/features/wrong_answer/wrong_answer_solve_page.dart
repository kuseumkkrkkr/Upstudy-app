import 'package:flutter/material.dart';

import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_top_navigation.dart';

/// 오답 재풀이 실행 페이지.
///
/// 실제 문제 풀이 세션은 WrongAnswerReviewWidget → BuildpageWidget 연동을 통해
/// 제공될 예정이다. 이 페이지는 해당 흐름으로 진입하기 전의 플레이스홀더 화면이다.
class WrongAnswerSolvePage extends StatelessWidget {
  const WrongAnswerSolvePage({super.key, required this.sourceType});

  final String sourceType;

  /// 필요한 변수는 현재 네비게이터 스택이다.
  /// 작동 원리는 목록에서 진입했으면 이전 화면으로 돌아가고, 단독 경로면 실제 오답 노트로 복귀하는 것이다.
  void _goBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushNamedAndRemoveUntil('/wrong_answers', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isStudentDensityMobile(context);
    return Scaffold(
      backgroundColor: StudentDensityTokens.background,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (headerContext) => Ios26TopBar(
                brandColor: StudentDensityTokens.dark,
                onBack: () => _goBack(context),
                onMenu: () => toggleAppDrawer(headerContext),
                onTitleTap: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  '/student/dashboard',
                  (route) => false,
                ),
                showMenuWithBack: true,
                showLevelIndicator: false,
                showUtilityActions: true,
                items: studentTopNavItems(
                  context,
                  active: StudentTopDestination.learning,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: StudentDensityPage(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const StudentDensityPageHeader(
                            eyebrow: 'REVIEW SESSION',
                            title: '오답 재풀이',
                            description: '오답 노트에서 선택한 문제를 다시 풀어 보세요.',
                            showMobileDescription: true,
                          ),
                          SizedBox(height: mobile ? 22 : 32),
                          StudentDensitySurface(
                            padding: EdgeInsets.all(mobile ? 22 : 30),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Icon(
                                  Icons.replay_circle_filled_rounded,
                                  color: StudentDensityTokens.dark,
                                  size: 44,
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  '재풀이 세션을 준비하고 있어요.',
                                  style: TextStyle(
                                    color: StudentDensityTokens.ink,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '재풀이 세션이 여기에서 실행됩니다. (WrongAnswerReviewWidget 연동 예정)',
                                  style: TextStyle(
                                    color: StudentDensityTokens.muted,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                OutlinedButton.icon(
                                  onPressed: () => _goBack(context),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  label: const Text('오답 노트로 돌아가기'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: Size(0, mobile ? 52 : 46),
                                    foregroundColor: StudentDensityTokens.ink,
                                    side: const BorderSide(
                                      color: StudentDensityTokens.lineStrong,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
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
