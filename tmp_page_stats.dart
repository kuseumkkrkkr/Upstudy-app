import 'package:s11/shared/data/models/concept_textbooks.dart';
import 'package:s11/shared/data/models/textbook.dart';

void main() {
  final buckets = <int,int>{};
  var min = 999;
  var max = 0;
  var below8 = <String>[];
  var above12 = <String>[];

  for (final entry in kConceptTextbooks.entries) {
    final pages = entry.value.chapters.single.pages.length;
    buckets[pages] = (buckets[pages] ?? 0) + 1;
    if (pages < min) min = pages;
    if (pages > max) max = pages;
    if (pages < 8) below8.add(entry.key);
    if (pages > 12) above12.add(entry.key);
  }

  print('count=${kConceptTextbooks.length}, min=$min, max=$max');
  final keys = buckets.keys.toList()..sort();
  for (final k in keys) {
    print('$k: ${buckets[k]}');
  }
  print('below8=${below8.length}: ${below8.take(20).join(',')}');
  print('above12=${above12.length}: ${above12.join(',')}');
}
