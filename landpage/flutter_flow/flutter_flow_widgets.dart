import 'package:flutter/material.dart';

class FFButtonOptions {
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? iconPadding;
  final Color? color;
  final TextStyle? textStyle;
  final double? elevation;
  final BorderRadius? borderRadius;

  FFButtonOptions({
    this.width,
    this.height,
    this.padding,
    this.iconPadding,
    this.color,
    this.textStyle,
    this.elevation,
    this.borderRadius,
  });
}

class FFButtonWidget extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final FFButtonOptions? options;

  const FFButtonWidget(
      {Key? key, this.onPressed, required this.text, this.options})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final opts = options;
    final btn = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: opts?.color,
        padding: opts?.padding,
        elevation: opts?.elevation,
        shape: RoundedRectangleBorder(
            borderRadius: opts?.borderRadius ?? BorderRadius.circular(8)),
        fixedSize: opts?.width != null && opts?.height != null
            ? Size(opts!.width!, opts.height!)
            : null,
        textStyle: opts?.textStyle,
      ),
      onPressed: onPressed,
      child: Text(text, style: opts?.textStyle),
    );

    return btn;
  }
}
