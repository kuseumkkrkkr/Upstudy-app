import 'package:s11/shared/data/models/concept_textbooks.dart';
import 'package:s11/shared/data/models/textbook.dart';

void main() {
  final book = kConceptTextbooks['계차수열'];
  if (book == null) {
    print('not found');
    return;
  }
  final chapter = book.chapters.single;
  print('pages=${chapter.pages.length}, sections=${chapter.sections.length}');
  for (var i = 0; i < chapter.pages.length; i++) {
    final page = chapter.pages[i];
    print('page $i: template=${page.template}, title=${page.title}, blocks=${page.blocks.length}, visuals=${page.visuals.length}, graph=${page.graph != null}, paragraphs=${page.paragraphs.length}, images=${page.images.length}');
    for (var j = 0; j < page.blocks.length; j++) {
      final b = page.blocks[j];
      final summary = '${b.type} titleLen=${b.title.length} textLen=${b.text.length} items=${b.items.length}';
      final hasVisual = b.visual != null;
      final hasGraph = b.graph != null;
      final hasFormula = b.formula.isNotEmpty;
      print('  block $j: $summary visual=$hasVisual graph=$hasGraph formula=$hasFormula');
      if (b.formula.isNotEmpty) {
        print('    formula=${b.formula.substring(0, b.formula.length > 120 ? 120 : b.formula.length)}...');
      }
    }
  }
}
