import 'dart:ui';

import 'package:flutter/material.dart';

Future<T?> showCurriculumModal<T>({required BuildContext context}) {
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
            const Center(child: CurriculumModal()),
          ],
        ),
      );
    },
  );
}

class CurriculumModal extends StatelessWidget {
  const CurriculumModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 920,
      height: 560,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
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
              const Text('커리큘럼', style: TextStyle(fontSize: 22)),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                _CurriculumItem(
                  title: '챕터 1: 기초 다지기',
                  subtitle: '진행률 30%',
                ),
                _CurriculumItem(
                  title: '챕터 2: 응용 문제',
                  subtitle: '진행률 10%',
                ),
                _CurriculumItem(
                  title: '챕터 3: 모의고사',
                  subtitle: '진행률 0%',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurriculumItem extends StatelessWidget {
  const _CurriculumItem({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
