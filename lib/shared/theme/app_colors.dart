import 'package:flutter/material.dart';

/// AIFlow 앱 전역 색상 상수.
///
/// 기존에 50+ 파일에 하드코딩되어 있던 색상들을 중앙 집중화합니다.
/// 변경 시 이 파일만 수정하면 전체 앱에 반영됩니다.
class AppColors {
  AppColors._();

  /// 메인 브랜드 색상 — 짙은 녹색 (기존 Color(0xFF1B402B))
  static const Color primary = Color(0xFF1B402B);

  /// 메인 브랜드 보조 색상 — 밝은 녹색 (기존 Color(0xFF45BF63))
  static const Color primaryLight = Color(0xFF45BF63);

  /// 경계선/구분선 색상 (기존 Color(0xFFE0E3E7))
  static const Color border = Color(0xFFE0E3E7);

  /// 배경 색상 — 거의 흰색 회색 (기존 Color(0xFFF8F8F8))
  static const Color background = Color(0xFFF8F8F8);

  /// 헤더용 짙은 녹색 (기존 Color(0xFF22593A))
  static const Color headerGreen = Color(0xFF22593A);

  /// 카드/컨테이너 배경 — 흰색
  static const Color cardBg = Colors.white;

  /// 모달 오버레이 반투명 검정 (기존 Colors.black.withValues(alpha: 0.35))
  static Color get modalOverlay => Colors.black.withValues(alpha: 0.35);

  /// 에러/경고 색상
  static const Color error = Colors.red;

  /// 성공/확인 색상
  static const Color success = Colors.green;
}
