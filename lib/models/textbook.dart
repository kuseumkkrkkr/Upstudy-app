import 'dart:convert';

import 'package:flutter/material.dart';

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
      if (coverColor != null) 'cover_color': coverColor!.value,
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
      'cover_color': coverColor?.value,
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
      'cover_color': coverColor?.value,
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
  });

  final String title;
  final List<String> intro;
  final List<BookSection> sections;

  factory BookChapter.fromJson(Map<String, dynamic> json) {
    return BookChapter(
      title: json['title']?.toString() ?? '',
      intro: _readStringList(json['intro']),
      sections: _readSections(json['sections']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'intro': intro,
      'sections': sections.map((section) => section.toJson()).toList(),
    };
  }
}

class BookSection {
  const BookSection({
    required this.title,
    required this.paragraphs,
    this.images = const [],
  });

  final String title;
  final List<String> paragraphs;
  final List<String> images;

  factory BookSection.fromJson(Map<String, dynamic> json) {
    return BookSection(
      title: json['title']?.toString() ?? '',
      paragraphs: _readStringList(json['paragraphs']),
      images: _readStringList(json['images']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'paragraphs': paragraphs,
      'images': images,
    };
  }
}

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
