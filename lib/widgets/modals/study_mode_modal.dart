import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:s11/tryout.dart';

Future<T?> showStudyModeModal<T>({required BuildContext context}) {
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
            const Center(child: StudypageCopyWidget()),
          ],
        ),
      );
    },
  );
}

class StudypageCopyWidget extends StatelessWidget {
  const StudypageCopyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 1020.0;
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 380.0;
        final width = math.min(1020.0, maxW * 0.95);
        final height = math.min(380.0, maxH * 0.95);
        final scale = (width / 1020.0).clamp(0.6, 1.0);

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              top: true,
              child: Center(
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16 * scale),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Padding(
                            padding: EdgeInsets.all(24 * scale),
                            child: IconButton(
                              icon: Icon(
                                Icons.close,
                                color: Colors.black,
                                size: 36 * scale,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(bottom: 4 * scale),
                            child: Text(
                              '학습하기',
                              style: GoogleFonts.inter(fontSize: 30 * scale),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children:
                                List.generate(_kModes.length, (index) {
                                      final mode = _kModes[index];
                                      final isTryout = index == 3;
                                      return _ModeCard(
                                        icon: mode.icon,
                                        label: mode.label,
                                        scale: scale,
                                        onTap: isTryout
                                            ? () {
                                                final navigator = Navigator.of(
                                                  context,
                                                  rootNavigator: true,
                                                );
                                                navigator.pop();
                                                Future.microtask(
                                                  () => navigator.push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          const BuildpageWidget(),
                                                    ),
                                                  ),
                                                );
                                              }
                                            : null,
                                      );
                                    })
                                    .expand(
                                      (w) => [w, SizedBox(width: 20 * scale)],
                                    )
                                    .toList()
                                  ..removeLast(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

const _kModes = [
  _StudyMode(icon: Icons.restart_alt_sharp, label: '이어하기'),
  _StudyMode(icon: Icons.crop_din_outlined, label: '코스보기'),
  _StudyMode(icon: Icons.done_outline, label: '약점과복습'),
  _StudyMode(icon: Icons.north_west_sharp, label: '문제풀기'),
  _StudyMode(icon: Icons.texture, label: '시험'),
];

class _StudyMode {
  const _StudyMode({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.label,
    required this.scale,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16 * scale),
      child: Container(
        width: 180 * scale,
        height: 260 * scale,
        decoration: BoxDecoration(
          color: const Color(0xFFEBEBEB),
          borderRadius: BorderRadius.circular(16 * scale),
          boxShadow: const [
            BoxShadow(
              blurRadius: 4,
              color: Color(0x33000000),
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 90 * scale),
            SizedBox(height: 8 * scale),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 24 * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
