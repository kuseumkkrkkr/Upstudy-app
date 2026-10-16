import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/shared/data/models/textbook.dart';

void main() {
  const path =
      'docs/advanced-generation-vault/07 Data/교재 원고/수학Ⅱ_2015개정_미분방정식부등식_보충_Batch7_BookData_V2_시범.json';

  test('2015 Math II derivative equation and inequality supplement round trips', () {
    final raw = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final book = BookData.fromJson(raw);
    final roundTrip = BookData.fromJson(
      jsonDecode(jsonEncode(book.toJson())) as Map<String, dynamic>,
    );

    expect(roundTrip.toJson(), book.toJson());
    expect(book.tags, contains('12수학Ⅱ02-10'));
    expect(book.chapters.single.pages, hasLength(5));
    final blocks = book.chapters.single.pages.expand((page) => page.blocks).toList();
    final graph = blocks.map((block) => block.graph).whereType<AiFlowGraphDocument>().single;
    expect(graph.items.single.expression, 'x^2-4*x+3');

    final solutionText = blocks
        .where((block) => block.type.name == 'solutionStep')
        .map((block) => block.text)
        .join(' ');
    expect(solutionText, contains('실근은 없다'));
    expect(solutionText, contains('1≤x≤3'));
    final quiz = blocks.map((block) => block.activity).whereType<Map<String, dynamic>>().single;
    expect(quiz['kind'], 'quiz');
    expect(quiz['options'][quiz['correct_index']], '1≤x≤3');
    expect(quiz['correct_feedback'], contains('두 영점 사이'));
  });
}
