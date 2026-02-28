import 'package:flutter/material.dart';

class FlutterFlowTheme {
  static FlutterFlowTheme of(BuildContext context) => FlutterFlowTheme();

  final Color primaryBackground = const Color(0xFF000000);

  final FlutterFlowTextStyle displayLarge = FlutterFlowTextStyle(
    const TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
  );

  final FlutterFlowTextStyle displaySmall = FlutterFlowTextStyle(
    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
  );

  final FlutterFlowTextStyle titleSmall = FlutterFlowTextStyle(
    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
  );
}

class FlutterFlowTextStyle {
  final TextStyle textStyle;
  FlutterFlowTextStyle(this.textStyle);

  FontStyle? get fontStyle => textStyle.fontStyle;
  FontWeight? get fontWeight => textStyle.fontWeight;

  TextStyle override({
    TextStyle? font,
    Color? color,
    double? fontSize,
    double? letterSpacing,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
  }) {
    var base = textStyle;
    if (font != null) base = base.merge(font);
    return base.merge(TextStyle(
      color: color,
      fontSize: fontSize,
      letterSpacing: letterSpacing,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
    ));
  }
}
