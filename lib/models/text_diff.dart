import 'package:flutter/material.dart';

enum DiffType { deletion, addition, unchanged }

class TextDiff {
  final String text;
  final DiffType type;
  final String? reason;
  bool isAccepted;

  TextDiff({
    required this.text,
    required this.type,
    this.reason,
    this.isAccepted = false,
  });
}

class DiffSection {
  final List<TextDiff> diffs;
  final int startIndex;
  final int endIndex;

  DiffSection({
    required this.diffs,
    required this.startIndex,
    required this.endIndex,
  });
}
