import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/shared/data/models/textbook.dart';

void main() {
  const path =
      'docs/advanced-generation-vault/07 Data/교재 원고/수학Ⅱ_2015개정_정적분넓이_보충_Batch3_BookData_V2_시범.json';

  test('2015 Math II curved-area supplement preserves exact solution, graph and quiz', () {
    final raw = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final book = BookData.fromJson(raw);
    final roundTrip = BookData.fromJson(
      jsonDecode(jsonEncode(book.toJson())) as Map<String, dynamic>,
    );

    expect(roundTrip.toJson(), book.toJson());
    expect(book.tags, contains('12수학Ⅱ03-05'));
    expect(book.chapters, hasLength(1));
    expect(book.chapters.single.pages, hasLength(5));

    final blocks = book.chapters.single.pages.expand((page) => page.blocks).toList();
    final graph = blocks.map((block) => block.graph).whereType<AiFlowGraphDocument>().single;
    expect(graph.items.single.expression, 'x^2');
    final example = blocks.where((block) => block.type.name == 'solutionStep').toList();
    expect(example, hasLength(3));
    expect(example.map((block) => block.text).join(' '), contains('8/3'));

    final quiz = blocks.map((block) => block.activity).whereType<Map<String, dynamic>>().single;
    expect(quiz['kind'], 'quiz');
    expect(quiz['options'], ['2/3', '1/3', '2']);
    expect(quiz['correct_index'], 0);
    expect(quiz['correct_feedback'], contains('2/3'));
  });
}
