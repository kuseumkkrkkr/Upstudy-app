import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/textbook.dart';

void main() {
  test(
    'all current BookData files preserve pages and activities through round trip',
    () {
      final directory = Directory(
        'docs/advanced-generation-vault/07 Data/교재 원고',
      );
      final files = directory
          .listSync()
          .whereType<File>()
          .where(
            (file) =>
                file.path.endsWith('.json') &&
                RegExp(r'BookData.*\.json$').hasMatch(file.path),
          )
          .toList();
      expect(files, hasLength(107));

      var activities = 0;
      for (final file in files) {
        final source = BookData.fromJson(
          Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map),
        );
        final copy = BookData.fromJson(
          Map<String, dynamic>.from(
            jsonDecode(jsonEncode(source.toJson())) as Map,
          ),
        );
        expect(copy.toJson(), source.toJson(), reason: file.path);
        expect(copy.chapters.length, source.chapters.length, reason: file.path);
        final sourcePages = source.chapters
            .expand((chapter) => chapter.pages)
            .toList();
        final copyPages = copy.chapters
            .expand((chapter) => chapter.pages)
            .toList();
        expect(
          copyPages.map((page) => page.id),
          sourcePages.map((page) => page.id),
          reason: file.path,
        );
        final sourceActivities = sourcePages
            .expand((page) => page.blocks)
            .where((block) => block.activity != null)
            .map((block) => block.activity)
            .toList();
        final copyActivities = copyPages
            .expand((page) => page.blocks)
            .where((block) => block.activity != null)
            .map((block) => block.activity)
            .toList();
        activities += sourceActivities.length;
        expect(copyActivities, sourceActivities, reason: file.path);
      }
      // Keep a visible aggregate in the test result for the checkpoint.
      expect(activities, greaterThan(0));
    },
  );
}
