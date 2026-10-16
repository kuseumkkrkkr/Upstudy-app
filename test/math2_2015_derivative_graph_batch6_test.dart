import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/shared/data/models/textbook.dart';

void main() {
  const path =
      'docs/advanced-generation-vault/07 Data/교재 원고/수학Ⅱ_2015개정_도함수그래프개형_보충_Batch6_BookData_V2_시범.json';

  test('2015 Math II derivative graph sketch preserves roots, extrema, graph and quiz', () {
    final raw = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final book = BookData.fromJson(raw);
    final roundTrip = BookData.fromJson(
      jsonDecode(jsonEncode(book.toJson())) as Map<String, dynamic>,
    );

    expect(roundTrip.toJson(), book.toJson());
    expect(book.tags, contains('12수학Ⅱ02-09'));
    expect(book.chapters.single.pages, hasLength(5));
    final blocks = book.chapters.single.pages.expand((page) => page.blocks).toList();
    final graph = blocks.map((block) => block.graph).whereType<AiFlowGraphDocument>().single;
    expect(graph.items.single.expression, 'x^3-3*x');

    final solutionText = blocks
        .where((block) => block.type.name == 'solutionStep')
        .map((block) => block.text)
        .join(' ');
    expect(solutionText, contains('−√3, 0, √3'));
    expect(solutionText, contains('극댓값'));
    expect(solutionText, contains('극솟값'));
    expect(solutionText, contains('x→∞'));
    final quiz = blocks.map((block) => block.activity).whereType<Map<String, dynamic>>().single;
    expect(quiz['kind'], 'quiz');
    expect(quiz['correct_index'], 0);
    expect(quiz['options'][quiz['correct_index']], contains("g′(x)"));
  });
}
