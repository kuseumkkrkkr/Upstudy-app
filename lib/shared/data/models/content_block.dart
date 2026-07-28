class ContentBlock {
  final String type;
  final String content;

  const ContentBlock({required this.type, required this.content});

  bool get isLatex {
    final normalized = type.toLowerCase();
    return normalized == 'latex' ||
        normalized == 'formula' ||
        normalized == 'math';
  }

  factory ContentBlock.fromMap(Map<String, dynamic> map) {
    return ContentBlock(
      type: map['type']?.toString() ?? 'text',
      content: (map['content'] ?? map['text'])?.toString() ?? '',
    );
  }
}

List<ContentBlock> parseContentBlocks(dynamic value) {
  if (value == null) {
    return [];
  }

  if (value is Map<String, dynamic>) {
    final blocksValue = value['blocks'];
    if (blocksValue is List) {
      return _parseBlockList(blocksValue);
    }
    if (value.containsKey('type') &&
        (value.containsKey('content') || value.containsKey('text'))) {
      return [ContentBlock.fromMap(value)];
    }
  }

  if (value is List) {
    return _parseBlockList(value);
  }

  if (value is String) {
    if (value.isEmpty) {
      return [];
    }
    return parseTextWithLatex(value);
  }

  return [ContentBlock(type: 'text', content: value.toString())];
}

List<ContentBlock> _parseBlockList(List<dynamic> blocksValue) {
  final blocks = <ContentBlock>[];
  for (final block in blocksValue) {
    if (block is Map<String, dynamic>) {
      final type = block['type']?.toString() ?? 'text';
      final content = (block['content'] ?? block['text'])?.toString() ?? '';
      if (content.isEmpty) {
        continue;
      }
      if (type.toLowerCase() == 'text') {
        blocks.addAll(parseTextWithLatex(content));
      } else {
        blocks.add(ContentBlock(type: type, content: content));
      }
      continue;
    }
    if (block is String) {
      if (block.isEmpty) {
        continue;
      }
      blocks.addAll(parseTextWithLatex(block));
      continue;
    }
    final fallback = block.toString();
    if (fallback.isEmpty) {
      continue;
    }
    blocks.addAll(parseTextWithLatex(fallback));
  }
  return blocks.where((block) => block.content.isNotEmpty).toList();
}

List<ContentBlock> normalizeFlowBlocks(List<ContentBlock> blocks) {
  if (blocks.isEmpty) {
    return blocks;
  }
  final markerOnly = RegExp(r'^\d+[\.\)]$');
  final leadingMarker = RegExp(r'^\s*\d+[\.\)]\s+');
  final normalized = <ContentBlock>[];
  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    if (block.type.toLowerCase() != 'text') {
      normalized.add(block);
      continue;
    }
    var text = block.content.trim();
    if (text.isEmpty) {
      continue;
    }
    if (markerOnly.hasMatch(text)) {
      continue;
    }
    if (i == 0) {
      text = text.replaceFirst(leadingMarker, '');
      if (text.isEmpty) {
        continue;
      }
    }
    normalized.add(ContentBlock(type: block.type, content: text));
  }
  return normalized.isEmpty ? blocks : normalized;
}

List<ContentBlock> prependTextBlock(List<ContentBlock> blocks, String prefix) {
  if (prefix.isEmpty) {
    return blocks;
  }
  if (blocks.isEmpty) {
    return [ContentBlock(type: 'text', content: prefix)];
  }
  final first = blocks.first;
  if (first.type == 'text') {
    return [
      ContentBlock(type: 'text', content: '$prefix${first.content}'),
      ...blocks.skip(1),
    ];
  }
  return [ContentBlock(type: 'text', content: prefix), ...blocks];
}

String contentBlocksToPlainText(List<ContentBlock> blocks) {
  return blocks.map((block) => block.content).join(' ').trim();
}

List<ContentBlock> parseTextWithLatex(String text) {
  if (text.trim().isEmpty) {
    return [];
  }
  final blocks = <ContentBlock>[];
  var cursor = 0;
  while (cursor < text.length) {
    final match = _findNextLatexDelimiter(text, cursor);
    if (match == null) {
      final tail = text.substring(cursor);
      if (tail.isNotEmpty) {
        blocks.add(ContentBlock(type: 'text', content: _unescapeText(tail)));
      }
      break;
    }
    if (match.start > cursor) {
      final chunk = text.substring(cursor, match.start);
      if (chunk.isNotEmpty) {
        blocks.add(ContentBlock(type: 'text', content: _unescapeText(chunk)));
      }
    }
    final end = _findDelimiterEnd(text, match, match.start + match.open.length);
    if (end < 0) {
      final tail = text.substring(match.start);
      if (tail.isNotEmpty) {
        blocks.add(ContentBlock(type: 'text', content: _unescapeText(tail)));
      }
      break;
    }
    final latex = text.substring(match.start + match.open.length, end).trim();
    if (latex.isNotEmpty) {
      blocks.add(ContentBlock(type: 'latex', content: latex));
    }
    cursor = end + match.close.length;
  }
  return blocks;
}

class _LatexDelimiterMatch {
  final int start;
  final String open;
  final String close;

  const _LatexDelimiterMatch({
    required this.start,
    required this.open,
    required this.close,
  });
}

_LatexDelimiterMatch? _findNextLatexDelimiter(String text, int start) {
  final candidates = <_LatexDelimiterMatch>[];
  final doubleDollar = _indexOfUnescapedDoubleDollar(text, start);
  if (doubleDollar >= 0) {
    candidates.add(
      _LatexDelimiterMatch(start: doubleDollar, open: '\$\$', close: '\$\$'),
    );
  }
  final singleDollar = _indexOfUnescapedSingleDollar(text, start);
  if (singleDollar >= 0) {
    candidates.add(
      _LatexDelimiterMatch(start: singleDollar, open: '\$', close: '\$'),
    );
  }
  final paren = text.indexOf(r'\(', start);
  if (paren >= 0) {
    candidates.add(
      _LatexDelimiterMatch(start: paren, open: r'\(', close: r'\)'),
    );
  }
  final bracket = text.indexOf(r'\[', start);
  if (bracket >= 0) {
    candidates.add(
      _LatexDelimiterMatch(start: bracket, open: r'\[', close: r'\]'),
    );
  }
  if (candidates.isEmpty) {
    return null;
  }
  candidates.sort((a, b) {
    if (a.start != b.start) {
      return a.start.compareTo(b.start);
    }
    return b.open.length.compareTo(a.open.length);
  });
  return candidates.first;
}

int _findDelimiterEnd(String text, _LatexDelimiterMatch match, int start) {
  if (match.open == r'\(') {
    return text.indexOf(r'\)', start);
  }
  if (match.open == r'\[') {
    return text.indexOf(r'\]', start);
  }
  if (match.open == '\$\$') {
    return _indexOfUnescapedDoubleDollar(text, start);
  }
  return _indexOfUnescapedSingleDollar(text, start);
}

int _indexOfUnescapedDoubleDollar(String text, int start) {
  for (var i = start; i < text.length - 1; i++) {
    if (text[i] != '\$') {
      continue;
    }
    if (i > 0 && text[i - 1] == '\\') {
      continue;
    }
    if (text[i + 1] == '\$') {
      return i;
    }
  }
  return -1;
}

int _indexOfUnescapedSingleDollar(String text, int start) {
  for (var i = start; i < text.length; i++) {
    if (text[i] != '\$') {
      continue;
    }
    if (i > 0 && text[i - 1] == '\\') {
      continue;
    }
    if (i + 1 < text.length && text[i + 1] == '\$') {
      continue;
    }
    if (i > 0 && text[i - 1] == '\$') {
      continue;
    }
    return i;
  }
  return -1;
}

String _unescapeText(String text) {
  // 필요한 변수는 서버가 문자열로 전달한 이스케이프 문자다.
  // 작동 원리는 LaTeX 구분자 밖의 줄바꿈 표기를 실제 개행으로 복원해 `\n`이 화면에 노출되지 않게 하는 것이다.
  return text
      .replaceAll(r'\r\n', '\n')
      .replaceAll(r'\n', '\n')
      .replaceAll('\\\$', '\$');
}
