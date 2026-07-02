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
  } else if (text.startsWith(r'$$') &&
      text.endsWith(r'$$') &&
      text.length > 4) {
    text = text.substring(2, text.length - 2).trim();
  } else if (text.startsWith('\$') && text.endsWith('\$') && text.length > 2) {
    text = text.substring(1, text.length - 1).trim();
  }
  if (!text.contains('\$')) {
    return text;
  }
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == '\$') {
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

/// Inline math widget rendered directly inside text flow.
class _InlineMath extends StatelessWidget {
  final String latex;
  final TextStyle style;

  const _InlineMath({
    required this.latex,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = style.fontSize ?? 14.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Math.tex(
        latex,
        textStyle: style.copyWith(
          fontSize: fontSize * 0.92,
        ),
        mathStyle: MathStyle.text,
      ),
    );
  }
}

class ContentBlocksView extends StatefulWidget {
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
  State<ContentBlocksView> createState() => _ContentBlocksViewState();
}

class _ContentBlocksViewState extends State<ContentBlocksView> {
  @override
  Widget build(BuildContext context) {
    final blocks = widget.blocks;
    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    final effectiveTextStyle =
        widget.textStyle ?? DefaultTextStyle.of(context).style;
    final effectiveLatexStyle = widget.latexStyle ?? effectiveTextStyle;

    if (widget.inline) {
      final spans = <InlineSpan>[];
      var needsLeadingSpace = false;

      for (final block in blocks) {
        if (block.content.isEmpty) continue;

        if (block.isLatex) {
          final latex = _sanitizeLatex(block.content);
          if (latex.isEmpty) continue;

          if (spans.isNotEmpty && needsLeadingSpace) {
            spans.add(TextSpan(
              text: '\u200A',
              style: effectiveTextStyle.copyWith(letterSpacing: -0.5),
            ));
          }

          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _InlineMath(
              latex: latex,
              style: effectiveLatexStyle,
            ),
          ));
          needsLeadingSpace = true;
        } else {
          var text = block.content;
          if (needsLeadingSpace && text.startsWith(' ')) {
            text = text.substring(1);
          }
          spans.add(TextSpan(
            text: text,
            style: effectiveTextStyle,
          ));
          needsLeadingSpace = !text.endsWith(' ');
        }
      }

      if (spans.isEmpty) {
        return const SizedBox.shrink();
      }

      return Text.rich(
        TextSpan(children: spans),
        textAlign: widget.textAlign,
        softWrap: true,
        overflow: TextOverflow.clip,
      );
    }

    // Non-inline mode: block equations in Column
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
        children.add(
          Math.tex(
            latex,
            textStyle: effectiveLatexStyle,
            mathStyle: MathStyle.display,
          ),
        );
        continue;
      }
      children.add(
        Text(
          block.content,
          style: effectiveTextStyle,
          textAlign: widget.textAlign,
        ),
      );
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: widget.crossAxisAlignment,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) SizedBox(height: widget.spacing),
        ],
      ],
    );
  }
}
