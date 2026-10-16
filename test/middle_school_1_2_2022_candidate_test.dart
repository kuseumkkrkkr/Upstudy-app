import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const root =
      'docs/advanced-generation-vault/07 Data/교재 원고/중학수학1-2_2022개정_통합시범';
  const bookPath = '$root/중학수학1-2_2022개정_수학의언어와자료_BookData_시범.json';

  test('2022 중학수학 1-2 후보가 V2 선언형 퀴즈 계약을 보존한다', () {
    final raw = jsonDecode(File(bookPath).readAsStringSync());
    final book = Map<String, dynamic>.from(raw as Map);

    expect(book['schema_version'], 2);
    expect(book['tags'], contains('학기 배정 후보'));
    expect(book['tags'], contains('공식 학기 배열 아님'));
    final chapters = (book['chapters'] as List).cast<Map>();
    expect(chapters, hasLength(4));
    expect(chapters.expand((chapter) => chapter['pages'] as List), hasLength(24));
    final activities = chapters
        .expand((chapter) => chapter['pages'] as List)
        .cast<Map>()
        .expand((page) => page['blocks'] as List)
        .cast<Map>()
        .where((block) => block['type'] == 'activity')
        .map((block) => Map<String, dynamic>.from(block['activity'] as Map));
    expect(activities, hasLength(4));
    for (final activity in activities) {
      expect(activity['kind'], 'quiz');
      expect((activity['options'] as List).length, inInclusiveRange(2, 6));
      expect(activity['correct_feedback'], isNotEmpty);
      expect(activity['incorrect_feedback'], isNotEmpty);
    }
  });

  test('각 단원에 연결된 체험 HTML은 자체 입력과 채점 경로를 보존한다', () {
    final directory = Directory(root);
    final htmlFiles = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('_체험형_시범.html'))
        .toList();

    expect(htmlFiles, hasLength(4));
    for (final file in htmlFiles) {
      final html = file.readAsStringSync();
      expect(html, contains('<input'));
      expect(html, contains("addEventListener('click'"));
      expect(html, contains('aria-live'));
      expect(html, isNot(contains('<script src=')));
    }
  });
}
