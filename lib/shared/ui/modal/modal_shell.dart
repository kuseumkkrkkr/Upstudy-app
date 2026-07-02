import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:s11/shared/theme/app_colors.dart';

/// 공통 모달 셸 위젯.
///
/// 기존 7개 이상의 모달 파일들이 중복되어 있던
/// `BackdropFilter` + `ImageFilter.blur(sigmaX:4, sigmaY:4)` +
/// `Colors.black.withValues(alpha: 0.35)` 패턴을 유틸리티화한 클래스입니다.
///
/// 사용 예:
/// ```dart
/// ModalShell.show(context, child: MyModalContent());
/// ```
class ModalShell {
  ModalShell._();

  /// 모달의 화면 중앙에 표시됩니다.
  ///
  /// [context] - BuildContext
  /// [child] - 모달 내용 콘텐츠
  /// [barrierDismissible] - 배경 클릭으로 닫기 가능 여부 (기본 true)
  /// [blurSigma] - 블러 강도 (기본 4.0)
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool barrierDismissible = true,
    double blurSigma = 4.0,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.transparent,
      builder: (context) => _ModalShellWidget(
        blurSigma: blurSigma,
        child: child,
      ),
    );
  }
}

class _ModalShellWidget extends StatelessWidget {
  const _ModalShellWidget({
    required this.blurSigma,
    required this.child,
  });

  final double blurSigma;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // 블러 + 오버레이 레이어
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: Container(
                color: AppColors.modalOverlay,
              ),
            ),
          ),
          // 모달 콘텐츠(중앙 배치)
          Center(child: child),
        ],
      ),
    );
  }
}
