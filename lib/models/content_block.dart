class ContentBlock {
  final String type;
  final String content;

  const ContentBlock({
    required this.type,
    required this.content,
  });

  bool get isLatex => type == 'latex';

  factory ContentBlock.fromMap(Map<String, dynamic> map) {
    return ContentBlock(
      type: map['type']?.toString() ?? 'text',
      content: map['content']?.toString() ?? '',
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
    if (value.containsKey('type') && value.containsKey('content')) {
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
    return [ContentBlock(type: 'text', content: value)];
  }

  return [ContentBlock(type: 'text', content: value.toString())];
}

List<ContentBlock> _parseBlockList(List<dynamic> blocksValue) {
  return blocksValue
      .map(
        (block) {
          if (block is Map<String, dynamic>) {
            return ContentBlock.fromMap(block);
          }
          if (block is String) {
            return ContentBlock(type: 'text', content: block);
          }
          return ContentBlock(type: 'text', content: block.toString());
        },
      )
      .where((block) => block.content.isNotEmpty)
      .toList();
}

List<ContentBlock> prependTextBlock(
  List<ContentBlock> blocks,
  String prefix,
) {
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
  return [
    ContentBlock(type: 'text', content: prefix),
    ...blocks,
  ];
}

String contentBlocksToPlainText(List<ContentBlock> blocks) {
  return blocks.map((block) => block.content).join(' ').trim();
}
