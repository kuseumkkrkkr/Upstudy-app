import 'package:s11/shared/data/models/concept_textbooks.dart';

void main() {
  final page = kConceptTextbooks['concept_계차수열']!.chapters.single.pages[1];
  print('template=${page.template} title=${page.title} blocks=${page.blocks.length}');
  for (var i = 0; i < page.blocks.length; i++) {
    final b = page.blocks[i];
    final score = b.title.length + b.text.length + b.formula.length +
      b.items.fold<int>(0, (s,e)=> s + e.length) +
      b.rows.fold<int>(0, (s,row) => s + row.fold<int>(0, (r,c) => r + c.length));
    print('[$i] type=${b.type} title=${b.title} textLen=${b.text.length} formulaLen=${b.formula.length} items=${b.items.length} rows=${b.rows.length} score=$score');
  }
}
