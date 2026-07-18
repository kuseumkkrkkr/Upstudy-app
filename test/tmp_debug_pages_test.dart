import 'package:s11/shared/data/models/concept_textbooks.dart';

void main() {
  const keyToFind = '\uacc4\ucc28\uc218\uc5f4';
  final book = kConceptTextbooks[keyToFind];
  if (book == null) {
    print('not found');
    return;
  }

  final chapter = book.chapters.single;
  print('pages=${chapter.pages.length}, sections=${chapter.sections.length}');
  for (var i = 0; i < chapter.pages.length; i++) {
    final page = chapter.pages[i];
    print(
      'page $i: template=${page.template}, title=${page.title}, blocks=${page.blocks.length}, '
      'graph=${page.blocks.any((block) => block.graph != null)}',
    );
    for (var j = 0; j < page.blocks.length; j++) {
      final b = page.blocks[j];
      print(
        '  block $j: ${b.type} titleLen=${b.title.length} textLen=${b.text.length} '
        'items=${b.items.length} visual=${b.visual != null} graph=${b.graph != null} formulaLen=${b.formula.length}',
      );
      if (b.text.length > 120) {
        print('    text=${b.text.substring(0, 120)}...');
      }
      if (b.formula.isNotEmpty) {
        print('    formula=${b.formula.substring(0, b.formula.length > 100 ? 100 : b.formula.length)}...');
      }
    }
  }
}
