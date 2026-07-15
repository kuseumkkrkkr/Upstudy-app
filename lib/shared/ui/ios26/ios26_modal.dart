import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// 필요한 변수는 화면 문맥·모달 본문·최대 크기·모바일 전체 화면 여부다.
/// 작동 원리: 데스크톱은 중앙 제한 크기, 모바일 액션 패널은 HTML처럼 viewport 전체 크기로 표시한다.
Future<T?> showIos26Modal<T>({
  required BuildContext context,
  required Widget child,
  double maxWidth = 980,
  double maxHeight = 640,
  bool barrierDismissible = true,
  bool mobileFullScreen = false,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.transparent,
    builder: (_) => Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(color: Colors.black.withValues(alpha: 0.28)),
          ),
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fullScreen =
                    mobileFullScreen && constraints.maxWidth <= 780;
                final width = fullScreen
                    ? constraints.maxWidth
                    : math.min(maxWidth, constraints.maxWidth * 0.94);
                final height = fullScreen
                    ? constraints.maxHeight
                    : math.min(maxHeight, constraints.maxHeight * 0.9);
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: width,
                    maxHeight: height,
                  ),
                  child: child,
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class Ios26ModalShell extends StatelessWidget {
  const Ios26ModalShell({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.onClose,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: onClose ?? () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.black.withValues(alpha: 0.08)),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
