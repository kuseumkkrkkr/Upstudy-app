import 'dart:ui';

import 'package:flutter/material.dart';

Future<T?> showLearningToolsModal<T>({required BuildContext context}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    builder: (context) {
      return Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
            const Center(child: LearningToolsModal()),
          ],
        ),
      );
    },
  );
}

class LearningToolsModal extends StatelessWidget {
  const LearningToolsModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 940,
      height: 520,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: IconButton(
                  icon: const Icon(Icons.close, size: 26),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const Text('학습도구', style: TextStyle(fontSize: 22)),
            ],
          ),
          const Padding(
            padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 12),
            child: Text('자주 쓰는 도구를 빠르게 실행하세요.', style: TextStyle(fontSize: 15)),
          ),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 3.2,
              children: const [
                _ToolTile(label: '오답노트'),
                _ToolTile(label: '모의고사'),
                _ToolTile(label: '타이머'),
                _ToolTile(label: '학습 통계'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 15)),
    );
  }
}
