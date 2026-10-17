import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:s11/shared/ui/student_density/student_html_shell.dart';

// Legacy learning-action callers remain separate from restriction settings.
export '../modals/study_mode_modal.dart'
    show showStudyModeModal, StudypageCopyWidget;

/// The reference's web restriction page is an honest capability notice.
/// It does not pretend that a browser can lock other applications.
class RestrictionModePage extends StatelessWidget {
  const RestrictionModePage({super.key, this.webOverride});

  /// Rendering tests may select the web notice; this grants no capability.
  final bool? webOverride;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width <= 719;
    final web = webOverride ?? kIsWeb;
    final fontSize = compact ? 28.0 : (width * .04).clamp(28.0, 42.0);
    final scaler = MediaQuery.textScalerOf(context);
    return StudentHtmlShell(
      key: const ValueKey('restriction-mode-page'),
      title: '제한 모드',
      headerTrailing: const SizedBox.shrink(),
      railWidth: 76,
      showBottomNavigation: !compact,
      mobileBackButton: true,
      onMenu: () {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        } else {
          navigator.pushReplacementNamed('/student/dashboard');
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 760,
                minHeight: constraints.maxHeight,
              ),
              child: Padding(
                padding: compact
                    ? const EdgeInsets.fromLTRB(15, 22, 15, 36)
                    : const EdgeInsets.fromLTRB(28, 32, 28, 48),
                child: Center(
                  child: Container(
                    key: const ValueKey('restriction-capability-notice'),
                    constraints: const BoxConstraints(maxWidth: 520),
                    padding: compact
                        ? const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 28,
                          )
                        : const EdgeInsets.all(42),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDFDFE),
                      border: Border.all(color: const Color(0x1A09090B)),
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: scaler.scale(18),
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: Text(
                                web ? '현재 환경 · 웹' : '현재 환경 · 앱',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  height: 1.4,
                                  color: Color(0xFF71717A),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            web
                                ? '웹에서는 제한 모드를\n사용할 수 없어요.'
                                : '이 빌드에서는 제한 모드를\n사용할 수 없어요.',
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -fontSize * .05,
                              height: compact ? 40 / 28 : 61 / 42,
                              color: const Color(0xFF09090B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            web
                                ? '앱 잠금과 허용 앱 설정은 Android 앱과 PC 앱에서만 지원합니다.'
                                : '운영체제 앱 잠금 기능이 연결되지 않아 제한 모드를 시작할 수 없습니다.',
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.6,
                              color: Color(0xFF71717A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
