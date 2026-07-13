import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

typedef TeacherPanelBodyBuilder = Widget Function(BuildContext panelContext);
typedef TeacherPanelActionsBuilder =
    List<Widget> Function(BuildContext panelContext);

/// 필요 변수: 패널 문맥, 안내 문구, 본문·하단 작업 빌더와 패널 최대 폭.
/// 작동 원리: PC에서는 우측 작업 패널, 모바일에서는 거의 전체 높이의 하단 작업면을
/// 열어 작은 확인창 안에서 복잡한 선택을 강요하지 않는다. 반환값은 기존 Navigator
/// 결과 흐름을 그대로 사용하므로 API 호출과 기능 콜백에는 관여하지 않는다.
Future<T?> showTeacherAdaptivePanel<T>({
  required BuildContext context,
  required String eyebrow,
  required String title,
  required String description,
  required TeacherPanelBodyBuilder bodyBuilder,
  TeacherPanelActionsBuilder? actionsBuilder,
  IconData icon = Icons.tune_rounded,
  double maxWidth = 620,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: '작업 패널 닫기',
    barrierColor: Colors.black.withValues(alpha: 0.34),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _TeacherAdaptivePanel<T>(
        eyebrow: eyebrow,
        title: title,
        description: description,
        bodyBuilder: bodyBuilder,
        actionsBuilder: actionsBuilder,
        icon: icon,
        maxWidth: maxWidth,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final mobile = MediaQuery.sizeOf(context).width < 700;
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: mobile ? const Offset(0, 0.08) : const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// 필요 변수: 삭제·해제 작업의 제목, 영향 설명, 확인 문구와 위험 항목.
/// 작동 원리: 단순 예/아니오 대신 실행 결과를 먼저 읽고 결정하도록 구성하며,
/// 최종 선택값만 기존 호출부에 bool로 돌려준다.
Future<bool?> showTeacherDecisionPanel({
  required BuildContext context,
  required String title,
  required String description,
  required String confirmLabel,
  String cancelLabel = '유지하기',
  String eyebrow = 'REVIEW ACTION',
  IconData icon = Icons.priority_high_rounded,
  List<String> consequences = const <String>[],
  bool destructive = false,
}) {
  return showTeacherAdaptivePanel<bool>(
    context: context,
    eyebrow: eyebrow,
    title: title,
    description: description,
    icon: icon,
    maxWidth: 520,
    bodyBuilder: (panelContext) => ListView(
      padding: EdgeInsets.zero,
      children: [
        _DecisionSummary(destructive: destructive, consequences: consequences),
      ],
    ),
    actionsBuilder: (panelContext) => [
      TeacherPanelAction(
        label: cancelLabel,
        icon: Icons.arrow_back_rounded,
        onTap: () => Navigator.of(panelContext).pop(false),
      ),
      TeacherPanelAction(
        label: confirmLabel,
        icon: destructive ? Icons.delete_outline_rounded : Icons.check_rounded,
        primary: true,
        onTap: () => Navigator.of(panelContext).pop(true),
      ),
    ],
  );
}

class _TeacherAdaptivePanel<T> extends StatelessWidget {
  const _TeacherAdaptivePanel({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.bodyBuilder,
    required this.actionsBuilder,
    required this.icon,
    required this.maxWidth,
  });

  final String eyebrow;
  final String title;
  final String description;
  final TeacherPanelBodyBuilder bodyBuilder;
  final TeacherPanelActionsBuilder? actionsBuilder;
  final IconData icon;
  final double maxWidth;

  /// 필요 변수: 현재 화면 제약과 패널에 전달된 작업 정보.
  /// 작동 원리: 화면 크기에 따라 패널 방향과 모서리·여백을 바꾸되 본문 상태와
  /// Navigator 반환 흐름은 동일하게 유지한다.
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mobile = constraints.maxWidth < 700;
            final width = mobile
                ? constraints.maxWidth
                : maxWidth.clamp(420, constraints.maxWidth * 0.92).toDouble();
            final height = mobile
                ? constraints.maxHeight * 0.94
                : constraints.maxHeight;
            final radius = mobile
                ? const BorderRadius.vertical(top: Radius.circular(32))
                : const BorderRadius.horizontal(left: Radius.circular(34));

            return Align(
              alignment: mobile
                  ? Alignment.bottomCenter
                  : Alignment.centerRight,
              child: ClipRRect(
                borderRadius: radius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F8).withValues(alpha: 0.97),
                      borderRadius: radius,
                      border: Border.all(color: Colors.white),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x30000000),
                          blurRadius: 42,
                          offset: Offset(-12, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PanelHeader(
                          eyebrow: eyebrow,
                          title: title,
                          description: description,
                          icon: icon,
                          compact: mobile,
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              mobile ? 18 : 24,
                              8,
                              mobile ? 18 : 24,
                              16,
                            ),
                            child: bodyBuilder(context),
                          ),
                        ),
                        if (actionsBuilder case final builder?)
                          _PanelFooter(actions: builder(context)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.compact,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 18 : 24, 22, 14, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 10,
                    letterSpacing: 1.25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: compact ? 24 : 28,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.black54,
                    height: 1.42,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '닫기',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _PanelFooter extends StatelessWidget {
  const _PanelFooter({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 10,
        runSpacing: 8,
        children: actions,
      ),
    );
  }
}

/// 필요 변수: 라벨, 아이콘, 원본 콜백과 강조 여부.
/// 작동 원리: 패널의 하단 의사결정을 한 줄짜리 텍스트 버튼 대신 충분한 터치 영역과
/// 동사 중심 라벨로 표시하고 탭하면 전달받은 기존 콜백만 실행한다.
class TeacherPanelAction extends StatelessWidget {
  const TeacherPanelAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? Colors.black : const Color(0xFFF0F0F2),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: primary ? Colors.white : Colors.black,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: primary ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DecisionSummary extends StatelessWidget {
  const _DecisionSummary({
    required this.destructive,
    required this.consequences,
  });

  final bool destructive;
  final List<String> consequences;

  @override
  Widget build(BuildContext context) {
    final items = consequences.isEmpty
        ? const <String>['이 작업은 확인 즉시 반영됩니다.', '완료 후 이전 화면으로 돌아갑니다.']
        : consequences;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE3E3E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                destructive ? Icons.warning_amber_rounded : Icons.info_outline,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                destructive ? '실행 전 확인할 내용' : '변경되는 내용',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        height: 1.42,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
