import 'dart:ui';

import 'package:flutter/material.dart';

Future<T?> showSocialModal<T>({required BuildContext context}) {
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
            const Center(child: SocialModal()),
          ],
        ),
      );
    },
  );
}

class SocialModal extends StatelessWidget {
  const SocialModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 860,
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
                  icon: const Icon(Icons.close, size: 24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const Text('소셜', style: TextStyle(fontSize: 22)),
            ],
          ),
          const Padding(
            padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 12),
            child: Text(
              '최근 알림과 친구 소식을 확인하세요.',
              style: TextStyle(fontSize: 15),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: const [
                _SocialItem(text: '친구 A가 새 글을 올렸습니다.'),
                _SocialItem(text: '친구 B가 문제 풀이를 완료했습니다.'),
                _SocialItem(text: '새로운 팔로워가 있습니다.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialItem extends StatelessWidget {
  const _SocialItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}
