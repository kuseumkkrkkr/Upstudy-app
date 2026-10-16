import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const root =
      'docs/advanced-generation-vault/07 Data/교재 원고/중학수학2-2_2022개정_통합시범';
  const bookPath = '$root/중학수학2-2_2022개정_측정과가능성_BookData_V2_시범.json';

  test('2022 중학수학 2-2 후보가 안전한 V2 퀴즈와 학년군 기준을 기록한다', () {
    final book = jsonDecode(File(bookPath).readAsStringSync()) as Map<String, dynamic>;
    expect(book['schema_version'], 2);
    expect(book['tags'], contains('학기 배정 후보'));
    expect(book['tags'], contains('공식 학기 배열 아님'));
    expect(book['standard_codes'], containsAll(['9수03-15', '9수03-17', '9수04-05', '9수04-06']));
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

  test('체험 HTML은 단독 조작 자산으로 남고 외부 스크립트를 불러오지 않는다', () {
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
