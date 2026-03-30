import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../models/content_block.dart';

String _sanitizeLatex(String value) {
  var text = value.trim();
  if (text.isEmpty) {
    return text;
  }
  if (text.startsWith(r'\(') && text.endsWith(r'\)') && text.length > 4) {
    text = text.substring(2, text.length - 2).trim();
  } else if (text.startsWith(r'\[') &&
      text.endsWith(r'\]') &&
      text.length > 4) {
    text = text.substring(2, text.length - 2).trim();
  } else if (text.startsWith(r'$\$') &&
      text.endsWith(r'$\$') &&
      text.length > 4) {
    text = text.substring(2, text.length - 2).trim();
  } else if (text.startsWith(r'$') && text.endsWith(r'$') && text.length > 2) {
    text = text.substring(1, text.length - 1).trim();
  }
  if (!text.contains(r'$')) {
    return text;
  }
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == r'$') {
      final isEscaped = i > 0 && text[i - 1] == '\\';
      if (isEscaped) {
        buffer.write(char);
      }
      continue;
    }
    buffer.write(char);
  }
  return buffer.toString();
}

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
    final effectiveTextStyle = textStyle ?? DefaultTextStyle.of(context).style;
    final effectiveLatexStyle = latexStyle ?? effectiveTextStyle;
    if (inline) {
      final spans = <InlineSpan>[];
      for (final block in blocks) {
        if (block.content.isEmpty) {
          continue;
        }
        if (block.isLatex) {
          final latex = _sanitizeLatex(block.content);
          if (latex.isEmpty) {
            continue;
          }
          final mathWidget = Math.tex(
            latex,
            textStyle: effectiveLatexStyle,
            mathStyle: MathStyle.text,
          );
          final breakResult = mathWidget.texBreak();
          if (breakResult.parts.isEmpty) {
            spans.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: mathWidget,
              ),
            );
          } else {
            for (final part in breakResult.parts) {
              spans.add(
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: part,
                ),
              );
            }
          }
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
        overflow: TextOverflow.clip,
      );
    }

    final children = <Widget>[];
    for (final block in blocks) {
      if (block.content.isEmpty) {
        continue;
      }
      if (block.isLatex) {
        final latex = _sanitizeLatex(block.content);
        if (latex.isEmpty) {
          continue;
        }
        children.add(Math.tex(latex, textStyle: effectiveLatexStyle));
        continue;
      }
      children.add(
        Text(block.content, style: effectiveTextStyle, textAlign: textAlign),
      );
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
