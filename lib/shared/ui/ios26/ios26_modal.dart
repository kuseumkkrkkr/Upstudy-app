import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

Future<T?> showIos26Modal<T>({
  required BuildContext context,
  required Widget child,
  double maxWidth = 980,
  double maxHeight = 640,
  bool barrierDismissible = true,
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
                final width = math.min(maxWidth, constraints.maxWidth * 0.94);
                final height = math.min(maxHeight, constraints.maxHeight * 0.9);
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
