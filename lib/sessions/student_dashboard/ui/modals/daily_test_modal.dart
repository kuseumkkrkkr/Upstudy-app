import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:s11/shared/business/repositories/attendance_store.dart';

Future<T?> showDailyTestModal<T>({required BuildContext context}) {
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
            const Center(child: DailyTestModal()),
          ],
        ),
      );
    },
  );
}

class DailyTestModal extends StatelessWidget {
  const DailyTestModal({super.key});

  @override
  Widget build(BuildContext context) {
    final statusWidth = _measureTextWidth(
      context,
      '진행 중',
      const TextStyle(fontSize: 14),
    );
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        width: 1200,
        height: 560,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ValueListenableBuilder<AttendanceSnapshot>(
          valueListenable: AttendanceStore.notifier,
          builder: (context, snapshot, _) {
            final todayDone = AttendanceStore.isTodayChecked(snapshot);
            const total = 1;
            final completed = todayDone ? 1 : 0;
            final progress = todayDone ? 1.0 : 0.0;
            final percentLabel = '${(progress * 100).round()}%';
            final statusLabel = todayDone ? '완료' : '진행 중';
            final statusIcon = todayDone
                ? Icons.check_rounded
                : Icons.arrow_forward_rounded;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(
                          Icons.close,
                          color: Colors.black,
                          size: 28,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsetsDirectional.only(bottom: 4),
                      child: Text('일일 퀘스트', style: TextStyle(fontSize: 24)),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Padding(
                          padding: EdgeInsetsDirectional.only(end: 5),
                          child: Text('완료율', style: TextStyle(fontSize: 14)),
                        ),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 50),
                          child: Text(
                            percentLabel,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ],
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 1100,
                        height: 6,
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: const Color(0xCCE6E6E6),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF45BF63),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildTaskRow(
                          title: '1일 출석하기',
                          points: '10P',
                          status: statusLabel,
                          icon: statusIcon,
                          statusWidth: statusWidth,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTaskRow({
    required String title,
    required String points,
    required String status,
    required IconData icon,
    required double statusWidth,
    double pointsPadding = 20,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(0, 8, 0, 0),
      child: Center(
        child: Container(
          width: 1100,
          decoration: BoxDecoration(
            color: const Color(0xFFEDEDED),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 0, 8),
                child: Text(title, style: const TextStyle(fontSize: 20)),
              ),
              Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.monetization_on_rounded,
                          color: Color(0xFF5DA676),
                          size: 20,
                        ),
                        Text(
                          points,
                          style: const TextStyle(
                            color: Color(0xFF5DA676),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: pointsPadding),
                  SizedBox(
                    width: statusWidth,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        status,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  IconButton(
                    iconSize: 20,
                    icon: Icon(icon, color: Colors.black),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _measureTextWidth(
    BuildContext context,
    String text,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
    )..layout();
    return painter.width;
  }
}
