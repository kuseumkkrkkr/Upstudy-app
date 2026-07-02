import 'package:flutter/material.dart';

class WebFixedDialog extends StatelessWidget {
  final String title;

  const WebFixedDialog({super.key, this.title = '설정 창'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 480,
        height: 320,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              blurRadius: 30,
              offset: Offset(0, 10),
              color: Colors.black26,
            ),
          ],
        ),
        child: Column(
          children: [
            /// ───── 상단 바 (윈도우 느낌) ─────
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),

            /// ───── 내용 영역 ─────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• 드래그 불가\n'
                      '• 리사이즈 불가\n'
                      '• Flutter Web 최적\n'
                      '• 중앙 고정',
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('닫기'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
