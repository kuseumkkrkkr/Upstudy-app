import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';

class BookData {
  const BookData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.chapters,
    this.progress = 0,
    this.progressLabel = '',
    this.coverColor,
    this.tags = const [],
    this.category = 'custom',
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<BookChapter> chapters;
  final double progress;
  final String progressLabel;
  final Color? coverColor;
  final List<String> tags;
  final String category;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  factory BookData.fromJson(Map<String, dynamic> json) {
    final id = json['textbook_id']?.toString() ?? json['id']?.toString() ?? '';
    final title = json['title']?.toString() ?? '';
    final subtitle = json['subtitle']?.toString() ?? '';
    final progress = (json['progress'] as num?)?.toDouble() ?? 0.0;
    final progressLabel = json['progress_label']?.toString() ?? '';
    final coverColorValue = (json['cover_color'] as num?)?.toInt();
    final tags = _readStringList(json['tags']);
    final category = json['category']?.toString() ?? 'custom';
    final createdAt = _readDate(json['created_at']);
    final updatedAt = _readDate(json['updated_at']);
    final createdBy = json['created_by']?.toString();
    final chapters = _readChapters(json['chapters']);
    return BookData(
      id: id,
      title: title,
      subtitle: subtitle,
      chapters: chapters,
      progress: progress,
      progressLabel: progressLabel,
      coverColor: coverColorValue == null ? null : Color(coverColorValue),
      tags: tags,
      category: category,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'category': category,
      'tags': tags,
      'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
      if (coverColor != null) 'cover_color': coverColor!.toARGB32(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'textbook_id': id,
      'title': title,
      'subtitle': subtitle,
      'category': category,
      'tags': tags,
      'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
      'cover_color': coverColor?.toARGB32(),
      'created_at': createdAt?.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'created_by': createdBy,
      'progress': progress,
      'progress_label': progressLabel,
    };
  }

  Map<String, dynamic> toLibraryJson() {
    return {
      'textbook_id': id,
      'title': title,
      'subtitle': subtitle,
      'category': category,
      'tags': tags,
      'cover_color': coverColor?.toARGB32(),
      'created_at': createdAt?.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'created_by': createdBy,
      'progress': progress,
      'progress_label': progressLabel,
    };
  }
}

class BookChapter {
  const BookChapter({
    required this.title,
    required this.intro,
    required this.sections,
    this.visuals = const [],
    this.pages = const [],
  });

  final String title;
  final List<String> intro;
  final List<BookSection> sections;
  final List<BookVisual> visuals;
  final List<BookPage> pages;

  factory BookChapter.fromJson(Map<String, dynamic> json) {
    return BookChapter(
      title: json['title']?.toString() ?? '',
      intro: _readStringList(json['intro']),
      sections: _readSections(json['sections']),
      visuals: _readVisuals(json['visuals']),
      pages: _readPages(json['pages']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'intro': intro,
      'sections': sections.map((section) => section.toJson()).toList(),
      if (visuals.isNotEmpty)
        'visuals': visuals.map((visual) => visual.toJson()).toList(),
      if (pages.isNotEmpty)
        'pages': pages.map((page) => page.toJson()).toList(),
    };
  }
}

enum BookPageTemplate {
  opening,
  concept,
  principle,
  experiment,
  example,
  solution,
  practice,
  summary,
}

enum BookContentBlockType {
  lead,
  paragraph,
  definition,
  theorem,
  formula,
  symbols,
  derivation,
  visual,
  graph,
  question,
  thinking,
  solutionStep,
  verification,
  hint,
  answer,
  misconception,
  summary,
  checklist,
}

/// 실제 교재의 한 지면을 나타낸다.
/// [template]은 지면의 편집 역할, [blocks]는 위에서 아래로 읽는 의미 단위다.
class BookPage {
  const BookPage({
    required this.id,
    required this.template,
    required this.title,
    required this.blocks,
    this.kicker = '',
  });

  final String id;
  final BookPageTemplate template;
  final String title;
  final String kicker;
  final List<BookContentBlock> blocks;

  Map<String, dynamic> toJson() => {
    'id': id,
    'template': template.name,
    'title': title,
    'kicker': kicker,
    'blocks': blocks.map((block) => block.toJson()).toList(),
  };

  factory BookPage.fromJson(Map<String, dynamic> json) => BookPage(
    id: json['id']?.toString() ?? '',
    template: _readPageTemplate(json['template']),
    title: json['title']?.toString() ?? '',
    kicker: json['kicker']?.toString() ?? '',
    blocks: _readContentBlocks(json['blocks']),
  );
}

/// 실제 교재 지면의 의미 블록이다.
/// 텍스트·수식·표·그래프를 한 타입으로 직렬화하여 편집 위계를 보존한다.
class BookContentBlock {
  const BookContentBlock({
    required this.type,
    this.title = '',
    this.text = '',
    this.formula = '',
    this.items = const [],
    this.rows = const [],
    this.visual,
    this.graph,
  });

  final BookContentBlockType type;
  final String title;
  final String text;
  final String formula;
  final List<String> items;
  final List<List<String>> rows;
  final BookVisual? visual;
  final AiFlowGraphDocument? graph;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'title': title,
    'text': text,
    'formula': formula,
    'items': items,
    'rows': rows,
    if (visual != null) 'visual': visual!.toJson(),
    if (graph != null) 'graph': graph!.toJson(),
  };

  factory BookContentBlock.fromJson(Map<String, dynamic> json) =>
      BookContentBlock(
        type: _readContentBlockType(json['type']),
        title: json['title']?.toString() ?? '',
        text: json['text']?.toString() ?? '',
        formula: json['formula']?.toString() ?? '',
        items: _readStringList(json['items']),
        rows: _readRows(json['rows']),
        visual: json['visual'] is Map
            ? BookVisual.fromJson(
                Map<String, dynamic>.from(json['visual'] as Map),
              )
            : null,
        graph: _readGraph(json['graph']),
      );
}

class BookSection {
  const BookSection({
    required this.title,
    required this.paragraphs,
    this.images = const [],
    this.graph,
    this.visuals = const [],
  });

  final String title;
  final List<String> paragraphs;
  final List<String> images;

  /// 필요한 변수는 절의 본문과 선택적 그래프 문서다.
  /// 작동 원리는 교재가 직접 JSXGraph 삽화를 선언하도록 하되, 기존 API 문서와의 호환성을 위해 선택값으로 둔다.
  final AiFlowGraphDocument? graph;
  final List<BookVisual> visuals;

  factory BookSection.fromJson(Map<String, dynamic> json) {
    return BookSection(
      title: json['title']?.toString() ?? '',
      paragraphs: _readStringList(json['paragraphs']),
      images: _readStringList(json['images']),
      graph: _readGraph(json['graph']),
      visuals: _readVisuals(json['visuals']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'paragraphs': paragraphs,
      'images': images,
      if (graph != null) 'graph': graph!.toJson(),
      if (visuals.isNotEmpty)
        'visuals': visuals.map((visual) => visual.toJson()).toList(),
    };
  }
}

/// 교재 지면 안에 배치하는 시각 블록이다.
/// [kind]는 formula, steps, table, numberLine, signChart, flow, image 등으로 확장할 수 있다.
class BookVisual {
  const BookVisual({
    required this.kind,
    required this.title,
    this.caption = '',
    this.formula = '',
    this.items = const [],
    this.rows = const [],
    this.imageSource = '',
  });

  final String kind;
  final String title;
  final String caption;
  final String formula;
  final List<String> items;
  final List<List<String>> rows;
  final String imageSource;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'title': title,
    'caption': caption,
    'formula': formula,
    'items': items,
    'rows': rows,
    'image_source': imageSource,
  };

  factory BookVisual.fromJson(Map<String, dynamic> json) => BookVisual(
    kind: json['kind']?.toString() ?? 'callout',
    title: json['title']?.toString() ?? '',
    caption: json['caption']?.toString() ?? '',
    formula: json['formula']?.toString() ?? '',
    items: _readStringList(json['items']),
    rows:
        (json['rows'] as List?)
            ?.whereType<List>()
            .map((row) => row.map((cell) => cell.toString()).toList())
            .toList() ??
        const [],
    imageSource: json['image_source']?.toString() ?? '',
  );
}

/// 필요한 변수는 JSON으로 저장된 그래프 문서다.
/// 작동 원리는 서버에서 내려온 문서가 없거나 형식이 다르면 그래프 없이 본문만 표시해 하위 호환을 유지하는 것이다.
AiFlowGraphDocument? _readGraph(dynamic value) {
  if (value is! Map) return null;
  final json = Map<String, dynamic>.from(value);
  final items = json['items'];
  final settings = json['settings'];
  if (items is! List || settings is! Map) return null;
  try {
    final parsedItems = items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map((item) {
          final type = AiFlowGraphItemType.values.firstWhere(
            (value) => value.name == item['type'],
            orElse: () => AiFlowGraphItemType.function,
          );
          return AiFlowGraphItem(
            id: item['id']?.toString() ?? '',
            type: type,
            label: item['label']?.toString() ?? '',
            colorHex: item['colorHex']?.toString() ?? '#1B402B',
            enabled: item['enabled'] != false,
            expression: item['expression']?.toString(),
            xValues: _readDoubleList(item['xValues']),
            yValues: _readDoubleList(item['yValues']),
          );
        })
        .toList(growable: false);
    final rawViewport = settings['viewport'];
    final viewport = rawViewport is Map
        ? AiFlowGraphViewport(
            left: _readDouble(rawViewport['left'], -8),
            right: _readDouble(rawViewport['right'], 8),
            top: _readDouble(rawViewport['top'], 8),
            bottom: _readDouble(rawViewport['bottom'], -8),
          )
        : null;
    final parameters = (settings['parameters'] as List?)
        ?.whereType<Map>()
        .map(
          (item) => AiFlowGraphParameter(
            id: item['id']?.toString() ?? '',
            label: item['label']?.toString() ?? '',
            value: _readDouble(item['value'], 0),
            min: _readDouble(item['min'], -10),
            max: _readDouble(item['max'], 10),
            step: _readDouble(item['step'], 0.1),
          ),
        )
        .toList(growable: false);
    return AiFlowGraphDocument(
      items: parsedItems,
      settings: AiFlowGraphSettings(
        showAxes: settings['showAxes'] != false,
        showGrid: settings['showGrid'] != false,
        lockViewport: settings['lockViewport'] == true,
        degreeMode: settings['degreeMode'] == true,
        viewport: viewport,
        parameters: parameters,
      ),
    );
  } catch (_) {
    return null;
  }
}

double _readDouble(dynamic value, double fallback) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;

List<double>? _readDoubleList(dynamic value) {
  if (value is! List) return null;
  return value.map((item) => _readDouble(item, 0)).toList(growable: false);
}

List<BookVisual> _readVisuals(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => BookVisual.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

List<BookPage> _readPages(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => BookPage.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

List<BookContentBlock> _readContentBlocks(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => BookContentBlock.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

List<List<String>> _readRows(dynamic value) =>
    (value as List?)
        ?.whereType<List>()
        .map((row) => row.map((cell) => cell.toString()).toList())
        .toList(growable: false) ??
    const [];

BookPageTemplate _readPageTemplate(dynamic value) =>
    BookPageTemplate.values.firstWhere(
      (item) => item.name == value?.toString(),
      orElse: () => BookPageTemplate.concept,
    );

BookContentBlockType _readContentBlockType(dynamic value) =>
    BookContentBlockType.values.firstWhere(
      (item) => item.name == value?.toString(),
      orElse: () => BookContentBlockType.paragraph,
    );

List<BookChapter> _readChapters(dynamic value) {
  if (value == null) return const [];
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final decoded = jsonDecode(trimmed);
      return _readChapters(decoded);
    } catch (_) {
      return const [];
    }
  }
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((entry) => BookChapter.fromJson(Map<String, dynamic>.from(entry)))
      .toList();
}

List<BookSection> _readSections(dynamic value) {
  if (value == null) return const [];
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final decoded = jsonDecode(trimmed);
      return _readSections(decoded);
    } catch (_) {
      return const [];
    }
  }
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((entry) => BookSection.fromJson(Map<String, dynamic>.from(entry)))
      .toList();
}

List<String> _readStringList(dynamic value) {
  if (value == null) return const [];
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final decoded = jsonDecode(trimmed);
      return _readStringList(decoded);
    } catch (_) {
      return [trimmed];
    }
  }
  if (value is List) {
    return value
        .map((entry) => entry?.toString() ?? '')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }
  return [value.toString()];
}

DateTime? _readDate(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}
