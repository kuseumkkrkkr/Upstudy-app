import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/shared/data/models/textbook.dart';

void main() {
  const path =
      'docs/advanced-generation-vault/07 Data/교재 원고/기하_2015개정_이차곡선접선_보충_Batch2_BookData_V2_시범.json';

  test('2015 conic tangent supplement preserves worked and interactive content', () {
    final raw = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final book = BookData.fromJson(raw);
    final copy = BookData.fromJson(
      jsonDecode(jsonEncode(book.toJson())) as Map<String, dynamic>,
    );
    expect(copy.toJson(), book.toJson());
    expect(book.tags, contains('12기하01-04'));
    expect(book.chapters.single.pages, hasLength(5));
    final blocks = book.chapters.single.pages.expand((page) => page.blocks).toList();
    final graph = blocks.map((block) => block.graph).whereType<AiFlowGraphDocument>().single;
    expect(graph.items.map((item) => item.expression), ['2*sqrt(x)', '-2*sqrt(x)', 'x+1']);
    final solutions = blocks.where((block) => block.type.name == 'solutionStep').map((block) => block.text).join(' ');
    expect(solutions, contains('(x−1)²=0'));
    expect(solutions, contains('(0,0), (4,4)'));
    expect(solutions, contains('4x²+1=0'));
    final quiz = blocks.map((block) => block.activity).whereType<Map<String, dynamic>>().single;
    expect(quiz['options'][quiz['correct_index']], '판별식 0, 접한다');
    expect(quiz['hints'], hasLength(2));
  });
}
