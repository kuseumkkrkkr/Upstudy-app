import 'package:flutter/material.dart';

import 'package:s11/app/router.dart';
import 'package:s11/shared/data/models/course_module_config.dart';
import 'package:s11/sessions/course/ui/widgets/wrong_answer_review_widget.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';

/// 오답 재풀이 실행 페이지.
///
/// 실제 문제 풀이 세션은 WrongAnswerReviewWidget → BuildpageWidget 연동을 통해
/// 제공될 예정이다. 이 페이지는 해당 흐름으로 진입하기 전의 플레이스홀더 화면이다.
class WrongAnswerSolvePage extends StatelessWidget {
  const WrongAnswerSolvePage({super.key, required this.sourceType});

  static const routeName = '/wrong_answer_solve';

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
    final normalizedSource = sourceType == 'habit' ? 'habit' : 'weakness';
    return StudentHtmlShell(
      title: '오답 재풀이',
      activeRoute: AppRoutes.wrongAnswers,
      onMenu: () => _goBack(context),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          mobile ? 14 : 28,
          mobile ? 20 : 30,
          mobile ? 14 : 28,
          mobile ? 28 : 42,
        ),
        child: StudentDensityPage(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const StudentDensityPageHeader(
                    eyebrow: 'REVIEW SESSION',
                    title: '오답 재풀이',
                    description: '최근 오답과 약점 태그를 기준으로 다시 풀어 보세요.',
                    showMobileDescription: true,
                  ),
                  SizedBox(height: mobile ? 18 : 28),
                  StudentDensitySurface(
                    padding: EdgeInsets.all(mobile ? 18 : 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.replay_circle_filled_rounded,
                              color: StudentDensityTokens.dark,
                              size: 30,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                normalizedSource == 'habit'
                                    ? '풀이 습관을 다시 점검해요.'
                                    : '최근 틀린 문제를 다시 풀어요.',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '실제 약점·풀이 기록에서 문제를 불러오며, 데이터가 없으면 빈 상태를 표시합니다.',
                          style: TextStyle(
                            color: StudentDensityTokens.muted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        WrongAnswerReviewWidget(
                          config: WrongAnswerReviewConfig(
                            sourceType: normalizedSource,
                            questionCount: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: mobile ? 18 : 28),
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
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
