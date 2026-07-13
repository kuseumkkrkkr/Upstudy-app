import 'package:flutter/material.dart';

/// AIFlow 교사용 흑백 iOS26 색상 토큰.
///
/// 필요 변수: 없음. 모든 값은 앱 전역에서 공유하는 불변 색상이다.
/// 작동 원리: 기능별 기존 색상 참조는 유지하되 실제 출력값을 중성 흑백 계층으로
/// 통일해 화면별 로직이나 상태 판정에 영향을 주지 않고 시각 체계만 교체한다.
class AppColors {
  AppColors._();

  /// 핵심 액션과 선택 상태에 사용하는 순수 흑색.
  static const Color primary = Color(0xFF0A0A0A);

  /// 보조 액션과 아이콘에 사용하는 짙은 중성 회색.
  static const Color primaryLight = Color(0xFF27272A);

  /// 입력창과 카드의 기본 경계.
  static const Color border = Color(0xFFE1E1E5);

  /// 글래스 표면이 구분되는 앱 캔버스.
  static const Color background = Color(0xFFF4F4F5);

  /// 검색, 세그먼트, 비활성 영역의 중성 표면.
  static const Color surfaceMuted = Color(0xFFF0F0F2);

  /// 반투명 카드와 패널의 얇은 경계.
  static const Color surfaceBorder = Color(0xFFE3E3E7);

  /// 기존 이름을 사용하는 화면과의 호환용 헤더 색상.
  static const Color headerGreen = primary;

  /// 카드/컨테이너 기본 표면.
  static const Color cardBg = Colors.white;

  /// 유리 표면 위에 사용하는 반투명 흰색.
  static Color get glassSurface => Colors.white.withValues(alpha: 0.78);

  /// 모달 뒤 콘텐츠를 낮추는 흑백 스크림.
  static Color get modalOverlay => Colors.black.withValues(alpha: 0.32);

  /// 흑백 UI에서는 오류를 아이콘과 문구로 구분하고 색상은 짙은 회색을 쓴다.
  static const Color error = Color(0xFF27272A);

  /// 성공 상태 역시 라벨과 아이콘을 함께 사용한다.
  static const Color success = Color(0xFF111111);
}
