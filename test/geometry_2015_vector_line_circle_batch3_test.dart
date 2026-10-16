import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/shared/data/models/textbook.dart';

void main() {
  const path =
      'docs/advanced-generation-vault/07 Data/교재 원고/기하_2015개정_벡터직선원_보충_Batch3_BookData_V2_시범.json';

  test('2015 vector line and circle supplement round trips with practice graph and quiz', () {
    final book = BookData.fromJson(
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
    );
    final copy = BookData.fromJson(
      jsonDecode(jsonEncode(book.toJson())) as Map<String, dynamic>,
    );
    expect(copy.toJson(), book.toJson());
    expect(book.tags, contains('12기하02-05'));
    expect(book.chapters.single.pages, hasLength(5));
    final blocks = book.chapters.single.pages.expand((page) => page.blocks).toList();
    final solutions = blocks.where((block) => block.type.name == 'solutionStep').map((block) => block.text).join(' ');
    expect(solutions, contains('x=−1+3t, y=2−t'));
    expect(solutions, contains('R=√(3²+4²)=5'));
    expect(solutions, contains('(x+2)²+(y−1)²=25'));
    final graph = blocks.map((block) => block.graph).whereType<AiFlowGraphDocument>().single;
    expect(graph.items.map((item) => item.expression), [
      '1+sqrt(25-(x+2)^2)',
      '1-sqrt(25-(x+2)^2)',
    ]);
    final quiz = blocks.map((block) => block.activity).whereType<Map<String, dynamic>>().single;
    expect(quiz['options'][quiz['correct_index']], '5');
    expect(quiz['hints'], hasLength(2));
  });
}
