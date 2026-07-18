import 'dart:convert';
import 'package:s11/shared/data/models/concept_textbooks.dart';
import 'package:s11/shared/data/models/textbook.dart';

String _estimateBookPageLength(BookPage page) {
  var len=0;
  for (final b in page.blocks) {
    len += b.title.length + b.text.length + b.formula.length + b.formula.length+4;
    for(final it in b.items) len += it.length+10;
    if (b.graph!=null) len += 500;
    if (b.visual!=null) len += 260;
  }
  return len.toString();
}

void main(){
  final book = kConceptTextbooks['계차수열']!;
  final page = book.chapters.single.pages[1];
  print('concept=계차수열 page=${page.id} template=${page.template} blocks=${page.blocks.length} len=${_estimateBookPageLength(page)}');
  for(final block in page.blocks){
    final len = block.title.length + block.text.length + block.formula.length + block.rows.fold(0,(a,b)=>a+b.fold(0,(x,y)=>x+y.length+6)) + block.items.fold(0,(a,b)=>a+b.length+12);
    print('${block.type.name} title="${block.title}" textLen=${block.text.length} items=${block.items.length} rows=${block.rows.length} score=$len');
    if(block.text.isNotEmpty) {
      print('  text=${block.text}');
    }
    if(block.items.isNotEmpty){
      for(final i in block.items){print('  - $i');}
    }
  }
}
