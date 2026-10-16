import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const root =
      'docs/advanced-generation-vault/07 Data/교재 원고/중학수학3-1_2022개정_통합시범';
  const bookPath = '$root/중학수학3-1_2022개정_수와다항식함수_BookData_V2_시범.json';

  test('2022 중학수학 3-1 후보가 확인된 기준 태그와 V2 퀴즈를 보존한다', () {
    final book = jsonDecode(File(bookPath).readAsStringSync()) as Map<String, dynamic>;
    expect(book['schema_version'], 2);
    expect(book['tags'], contains('학기 배정 후보'));
    expect(book['tags'], contains('공식 학기 배열 아님'));
    expect(book['standard_codes'], containsAll(['9수01-08', '9수02-19', '9수02-22']));
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

  test('standalone HTML exercises expose native controls and no remote scripts', () {
    final files = Directory(root)
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('_체험형_시범.html'))
        .toList();
    expect(files, hasLength(4));
    for (final file in files) {
      final html = file.readAsStringSync();
      expect(html, contains('<script>'));
      expect(html, contains('aria-live'));
      expect(html, contains('addEventListener'));
      expect(html, isNot(contains('<script src=')));
    }
  });
}
