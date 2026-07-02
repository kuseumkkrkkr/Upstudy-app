import os

in_file = 'lib/models/concept_textbooks.dart'
out_file = in_file + '.new'

with open(in_file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

last_map = -1
for i in range(len(lines)-1, -1, -1):
    if lines[i].strip() == '};':
        last_map = i
        break

if last_map < 0:
    print('map end not found')
    exit(1)

with open(out_file, 'w', encoding='utf-8') as f:
    for line in lines[:last_map+1]:
        f.write(line)
    f.write('\n')
    f.write("""/// 태그 목록에 해당하는 개념 교재를 반환합니다.
List<BookData> findConceptTextbooks(List<String> tags) {
  if (tags.isEmpty) {
    return kConceptTextbooks.values.toList();
  }
  final result = <BookData>[];
  final seen = <String>{};
  for (final tag in tags) {
    final key = tag.replaceFirst('#', '');
    if (kConceptTextbooks.containsKey(key) && !seen.contains(key)) {
      seen.add(key);
      result.add(kConceptTextbooks[key]!);
      continue;
    }
    for (final entry in kConceptTextbooks.entries) {
      if (entry.value.tags.contains(key) || entry.value.tags.contains(tag)) {
        if (!seen.contains(entry.key)) {
          seen.add(entry.key);
          result.add(entry.value);
        }
      }
    }
  }
  return result.isNotEmpty ? result : kConceptTextbooks.values.toList();
}

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
      (normalized.length > 3 ? ' 外 개' : '');
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
""")

os.replace(out_file, in_file)
print('Fixed tail')