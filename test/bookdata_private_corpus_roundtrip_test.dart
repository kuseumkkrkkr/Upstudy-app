import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/textbook.dart';

// Generated only by the guarded read-only audit. Never commit this private input.
final privateCorpus = File(
  'build/temp/bookdata-explorers-private-runtime.json',
);

void preserved(dynamic source, dynamic restored, String path) {
  if (source is Map) {
    if (restored is! Map) fail('Object lost at $path');
    for (final key in source.keys) {
      if (!restored.containsKey(key)) {
        final value = source[key];
        if (value == '' ||
            value is List && value.isEmpty ||
            key == 'schema_version' && value == 1) {
          continue;
        }
        fail('Authored field lost at $path.$key');
      }
      preserved(source[key], restored[key], '$path.$key');
    }
  } else if (source is List) {
    if (restored is! List || source.length != restored.length) {
      fail('List changed at $path');
    }
    for (var i = 0; i < source.length; i++) {
      preserved(source[i], restored[i], '$path[$i]');
    }
  } else if (source != restored) {
    // Do not dump private manuscript values into logs on mismatch.
    fail('Authored value changed at $path');
  }
}

void main() {
  test(
    'every audited private runtime retains its authored content through Dart',
    () {
      final entries = jsonDecode(privateCorpus.readAsStringSync()) as List;
      expect(entries, isNotEmpty);
      for (var i = 0; i < entries.length; i++) {
        final source = Map<String, dynamic>.from(entries[i]['book']);
        final book = BookData.fromJson(source);
        final restored = BookData.fromJson(book.toCreateJson());
        preserved(source, restored.toCreateJson(), 'book[$i]');
        expect(restored.toCreateJson(), book.toCreateJson());
      }
      // Count only: never expose private body text in successful test output.
      debugPrint('Private runtime books checked: ${entries.length}');
    },
    skip: !privateCorpus.existsSync(),
  );
}
