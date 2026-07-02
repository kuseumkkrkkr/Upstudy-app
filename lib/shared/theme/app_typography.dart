import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AIFlow 앱 전역 타이포그래피 스타일.
///
/// GoogleFonts 기반의 일관된 텍스트 스타일을 제공합니다.
class AppTypography {
  AppTypography._();

  /// 페이지 대제목
  static TextStyle headline(BuildContext context) =>
      GoogleFonts.notoSans(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 섹션 제목
  static TextStyle title(BuildContext context) =>
      GoogleFonts.notoSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 본문 텍스트
  static TextStyle body(BuildContext context) =>
      GoogleFonts.notoSans(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 작은 설명 텍스트
  static TextStyle caption(BuildContext context) =>
      GoogleFonts.notoSans(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );

  /// 버튼 텍스트
  static TextStyle button(BuildContext context) =>
      GoogleFonts.notoSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );
}
