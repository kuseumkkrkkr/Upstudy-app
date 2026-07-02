
/// 선택한 해시태그들을 하나의 통합 교재(BookData)로 묶어 반환합니다.
BookData buildConceptBook(List<String> tags) {
  final normalized = tags.map((t) => t.replaceFirst('#', '')).toList();
  final List<BookChapter> chapters = [];
  final seen = <String>{};
  for (final tag in normalized) {
    if (kConceptTextbooks.containsKey(tag)) {
      if (!seen.contains(tag)) {
        seen.add(tag);
        chapters.addAll(kConceptTextbooks[tag]!.chapters);
      }
      continue;
    }
    for (final entry in kConceptTextbooks.entries) {
      if (entry.value.tags.contains(tag) || entry.value.tags.contains('#' + tag)) {
        if (!seen.contains(entry.key)) {
          seen.add(entry.key);
          chapters.addAll(entry.value.chapters);
        }
      }
    }
  }
  final dt = normalized.take(3).join(', ') +
      (normalized.length > 3 ? ' 外 ' : '');
  return BookData(
    id: 'concept_study_' + normalized.join('_'),
    title: '개념 학습',
    subtitle: dt,
    category: 'common',
    tags: tags.toList(),
    chapters: chapters.isNotEmpty
        ? chapters
        : kConceptTextbooks.values.first.chapters,
  );
}