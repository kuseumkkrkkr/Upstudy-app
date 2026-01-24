import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../models/content_block.dart';

class ContentBlocksView extends StatelessWidget {
  final List<ContentBlock> blocks;
  final TextStyle? textStyle;
  final TextStyle? latexStyle;
  final double spacing;
  final TextAlign textAlign;
  final CrossAxisAlignment crossAxisAlignment;
  final bool inline;

  const ContentBlocksView({
    super.key,
    required this.blocks,
    this.textStyle,
    this.latexStyle,
    this.spacing = 4,
    this.textAlign = TextAlign.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.inline = true,
  });

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }
    final effectiveTextStyle =
        textStyle ?? DefaultTextStyle.of(context).style;
    final effectiveLatexStyle = latexStyle ?? effectiveTextStyle;
    if (inline) {
      final spans = <InlineSpan>[];
      for (final block in blocks) {
        if (block.content.isEmpty) {
          continue;
        }
        if (block.isLatex) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Math.tex(
                block.content,
                textStyle: effectiveLatexStyle,
              ),
            ),
          );
        } else {
          spans.add(TextSpan(text: block.content));
        }
      }
      if (spans.isEmpty) {
        return const SizedBox.shrink();
      }
      return Text.rich(
        TextSpan(style: effectiveTextStyle, children: spans),
        textAlign: textAlign,
        softWrap: true,
      );
    }

    final children = <Widget>[];
    for (final block in blocks) {
      if (block.content.isEmpty) {
        continue;
      }
      final widget = block.isLatex
          ? Math.tex(
              block.content,
              textStyle: effectiveLatexStyle,
            )
          : Text(
              block.content,
              style: effectiveTextStyle,
              textAlign: textAlign,
            );
      children.add(widget);
    }
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) SizedBox(height: spacing),
        ],
      ],
    );
  }
}
