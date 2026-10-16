import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/textbook.dart';

void main() {
  const path =
      'docs/advanced-generation-vault/07 Data/교재 원고/수학Ⅱ_2015개정_극한연속_보충_Batch2_BookData_V2_시범.json';

  test('2015 Math II limit and continuity supplement round trips', () {
    final raw = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final book = BookData.fromJson(raw);
    final copy = BookData.fromJson(
      jsonDecode(jsonEncode(book.toJson())) as Map<String, dynamic>,
    );

    expect(copy.toJson(), book.toJson());
    expect(book.chapters, hasLength(3));
    expect(book.chapters.map((chapter) => chapter.pages.length), [5, 5, 5]);
    expect(book.tags, containsAll(['12수학Ⅱ01-01', '12수학Ⅱ01-02', '12수학Ⅱ01-03']));

    final pages = book.chapters.expand((chapter) => chapter.pages).toList();
    final blocks = pages.expand((page) => page.blocks).toList();
    final activities = blocks
        .where((block) => block.activity != null)
        .map((block) => block.activity!)
        .toList();
    expect(activities, hasLength(3));
    expect(activities.every((activity) => activity['kind'] == 'quiz'), isTrue);
    expect(activities.map((activity) => activity['correct_index']), [0, 0, 0]);
    expect(blocks.where((block) => block.type.name == 'solutionStep'), hasLength(6));
    expect(blocks.where((block) => block.type.name == 'definition'), hasLength(3));
  });
}
