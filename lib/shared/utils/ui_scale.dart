import 'package:flutter/material.dart';

/// 화면 크기에 따른 UI 스케일 팩터를 계산합니다.
///
/// 기존에 5개 파일에 중복되어 있던 `_uiScale()` 함수를 통합한 전역 유틸입니다.
/// [min] — 최소 스케일 값 (기본 0.6)
/// [max] — 최대 스케일 값 (기본 1.0)
///
/// 사용 예:
/// ```dart
/// final scale = uiScale(context);
/// final width = 300 * scale;
/// ```
double uiScale(
  BuildContext context, {
  double min = 0.6,
  double max = 1.0,
}) {
  final size = MediaQuery.of(context).size;
  final shortest = minValue(size.width, size.height);
  // 600px 기준으로 선형 스케일링
  final raw = shortest / 600.0;
  return raw.clamp(min, max);
}

/// 두 값 중 작은 값을 반환합니다.
double minValue(double a, double b) => a < b ? a : b;
