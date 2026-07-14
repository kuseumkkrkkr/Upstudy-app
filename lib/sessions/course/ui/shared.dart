import 'package:flutter/material.dart';

/// 공용 색상/레이아웃 유틸: 코스 페이지 전반에서 함께 쓰는 상수 모음.
const Color kCourseGreen = Color(0xFF1B402B);
const Color kCourseLightGreen = Color(0xFF45BF63);
const Color kCourseBgGrey = Color(0xFFF7F7F7);
const Color kCourseSurface = Colors.white;
const Color kCourseBorder = Color(0x1A000000);
const BoxShadow kCourseShadow = BoxShadow(
  blurRadius: 14,
  color: Color(0x14000000),
  offset: Offset(0, 6),
);

/// 화면 폭에 따라 카드/타이포 크기를 조정하는 헬퍼.
double courseUiScale(
  BuildContext context, {
  double min = 0.6,
  double max = 1.0,
}) {
  final width = MediaQuery.of(context).size.width;
  final scale = width / 1100;
  if (scale < min) return min;
  if (scale > max) return max;
  return scale;
}

/// 코스 관련 자주 쓰는 상태 표시용 작은 알약 모양 위젯.
class MetaPill extends StatelessWidget {
  const MetaPill({
    super.key,
    required this.label,
    required this.icon,
    required this.scale,
  });

  final String label;
  final IconData icon;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 6 * scale,
      ),
      decoration: BoxDecoration(
        color: kCourseBgGrey,
        borderRadius: BorderRadius.circular(16 * scale),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14 * scale, color: Colors.black54),
          SizedBox(width: 6 * scale),
          Text(
            label,
            style: TextStyle(
              fontSize: 11 * scale,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
