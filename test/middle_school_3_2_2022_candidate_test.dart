import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const root = 'docs/advanced-generation-vault/07 Data/교재 원고/중학수학3-2_2022개정_통합시범';
  test('2022 중학수학 3-2 부분 후보가 공식 기준 태그와 V2 퀴즈를 보존한다', () {
    final book = jsonDecode(File('$root/중학수학3-2_2022개정_통계탐구와분포_BookData_V2_시범.json').readAsStringSync()) as Map<String, dynamic>;
    expect(book['schema_version'], 2);
    expect(book['tags'], contains('학기 배정 후보'));
    expect(book['standard_codes'], containsAll(['9수04-01', '9수04-04', '9수04-08', '9수04-09']));
    final chapters = (book['chapters'] as List).cast<Map>();
    expect(chapters, hasLength(4));
    expect(chapters.expand((c) => c['pages'] as List), hasLength(24));
    final activities = chapters.expand((c) => c['pages'] as List).cast<Map>()
        .expand((p) => p['blocks'] as List).cast<Map>()
        .where((b) => b['type'] == 'activity').toList();
    expect(activities, hasLength(4));
    for (final block in activities) {
      final activity = block['activity'] as Map;
      expect(activity['kind'], 'quiz');
      expect(activity['options'], hasLength(3));
      expect(activity['correct_feedback'], isNotEmpty);
    }
  });

  test('standalone interaction pages use local accessible controls', () {
    final files = Directory(root).listSync().whereType<File>()
        .where((f) => f.path.endsWith('_체험형_시범.html')).toList();
    expect(files, hasLength(4));
    for (final file in files) {
      final html = file.readAsStringSync();
      expect(html, contains('aria-live'));
      expect(html, contains('addEventListener'));
      expect(html, isNot(contains('<script src=')));
    }
  });
}
