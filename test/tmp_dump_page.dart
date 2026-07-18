import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/concept_textbooks.dart';
import 'package:s11/shared/data/models/textbook.dart';

int _count(BookPage page) =>
    page.blocks.fold<int>(0, (sum, b) =>
        sum +
        b.title.length +
        b.text.length +
        b.formula.length +
        b.rows.fold<int>(
            0,
            (rSum, row) =>
                rSum + row.fold<int>(0, (cSum, cell) => cSum + cell.length + 6)) +
        b.items.fold<int>(0, (iSum, item) => iSum + item.length + 12));

void main() {
  test('debug concept_계차수열 pages', () {
    final entry = kConceptTextbooks.entries
        .firstWhere((entry) => entry.key == '계차수열');
    final book = entry.value;
    print('conceptKey=${entry.key} bookId=${book.id}');
    for (var i=0;i<book.chapters.single.pages.length;i++) {
      final page=book.chapters.single.pages[i];
      print('PAGE $i id=${page.id} template=${page.template} blocks=${page.blocks.length} count=${_count(page)}');
      for (var b=0;b<page.blocks.length;b++){
        final block=page.blocks[b];
        print('  block#$b type=${block.type} title=${block.title} text=${block.text.length} items=${block.items.length} formula=${block.formula.length}');
      }
    }
  });
}
