import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/textbook.dart';

void main() {
  const path =
      'docs/advanced-generation-vault/07 Data/교재 원고/기하_2015개정_공간관계삼수선정사영_보충_Batch4_BookData_V2_시범.json';
  const codes = ['12기하03-01', '12기하03-02', '12기하03-03'];

  test('2015 space relations supplement round trips proofs and three quizzes', () {
    final book = BookData.fromJson(
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
    );
    final copy = BookData.fromJson(
      jsonDecode(jsonEncode(book.toJson())) as Map<String, dynamic>,
    );
    expect(copy.toJson(), book.toJson());
    expect(book.tags, containsAll(codes));
    expect(book.chapters, hasLength(3));
    expect(book.chapters.expand((chapter) => chapter.pages), hasLength(15));
    final blocks = book.chapters.expand((chapter) => chapter.pages).expand((page) => page.blocks).toList();
    final solutions = blocks.where((block) => block.type.name == 'solutionStep').map((block) => block.text).join(' ');
    expect(solutions, contains('d·n=0'));
    expect(solutions, contains('AP=(0,−4,3)'));
    expect(solutions, contains('13√3/2'));
    expect(solutions, contains('L=12'));
    final quizzes = blocks.map((block) => block.activity).whereType<Map<String, dynamic>>().toList();
    expect(quizzes, hasLength(3));
    expect(quizzes.map((quiz) => quiz['kind']).toSet(), {'quiz'});
    expect(quizzes.map((quiz) => quiz['correct_feedback']).every((feedback) => feedback != null), isTrue);
  });
}
