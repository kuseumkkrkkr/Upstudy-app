import 'package:flutter/material.dart';

/// 필요 변수: 교사용 앱의 전체 화면 트리 [child].
/// 작동 원리: 기존 기능 화면에 남아 있는 직접 지정 색상까지 휘도 기반 흑백으로
/// 변환한다. 위젯 상태·이벤트·API 호출에는 관여하지 않고 최종 합성 색상만 바꾼다.
class TeacherMonochromeScope extends StatelessWidget {
  const TeacherMonochromeScope({super.key, required this.child});

  final Widget child;

  static const ColorFilter _grayscaleFilter = ColorFilter.matrix(<double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(colorFilter: _grayscaleFilter, child: child);
  }
}
