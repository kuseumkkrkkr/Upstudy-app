# -*- coding: utf-8 -*-
"""
Patch runner (JSON -> Dart concept_textbooks.dart)

python gen_textbook/patch.py \
    --input  gen_textbook/generated_textbooks.json \
    --output lib/models/concept_textbooks.dart
"""

import argparse
import json
import os
from typing import Any


def load_generated(path: str) -> dict[str, dict[str, Any]]:
    with open(path, "r", encoding="utf-8") as file:
        data = json.load(file)

    filtered: dict[str, dict[str, Any]] = {}
    for name, info in data.items():
        paragraphs = info.get("paragraphs") or []
        if not paragraphs:
            continue
        first = str(paragraphs[0]).strip()
        if first.startswith("ERROR"):
            continue
        filtered[name] = info
    return filtered


def load_leaves(path: str = "data/leaves.txt") -> dict[str, list[str]]:
    mapping: dict[str, list[str]] = {}
    with open(path, "r", encoding="utf-8") as file:
        for line in file:
            line = line.strip()
            if not line:
                continue
            parts = line.split("\t")
            if len(parts) != 2:
                continue
            name, path_string = parts
            mapping[name] = path_string.split("|")
    return mapping


def escape_for_dart(text: str) -> str:
    return (
        text.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("$", "\\$")
        .replace("\r\n", " ")
        .replace("\n", " ")
        .replace("\r", " ")
    )


def normalize_paragraphs(raw_paragraphs: list[Any]) -> list[str]:
    paragraphs: list[str] = []

    for paragraph in raw_paragraphs:
        text = str(paragraph).strip()
        if not text:
            continue

        # Sometimes one element is a serialized JSON list string.
        if text.startswith("[") and text.endswith("]"):
            try:
                parsed = json.loads(text)
                if isinstance(parsed, list):
                    for item in parsed:
                        item_text = str(item).strip()
                        if item_text:
                            paragraphs.append(item_text)
                    continue
            except Exception:
                pass

        paragraphs.append(text)

    return paragraphs


def paragraphs_to_dart_array(paragraphs: list[str]) -> str:
    lines = []
    for paragraph in paragraphs:
        safe = escape_for_dart(paragraph)
        lines.append(f"              '{safe}',")
    return "\n".join(lines)


def build_bookdata(name: str, path_list: list[str], paragraphs: list[str]) -> str:
    subtitle = " > ".join(path_list) if path_list else name
    tags = ", ".join(f"'{escape_for_dart(item)}'" for item in path_list)
    tags_block = f"[{tags}]" if tags else "[]"
    paragraphs_block = paragraphs_to_dart_array(paragraphs)

    return f"""  '{escape_for_dart(name)}': BookData(
    id: 'concept_{escape_for_dart(name)}',
    title: '{escape_for_dart(name)}',
    subtitle: '{escape_for_dart(subtitle)}',
    category: 'common',
    tags: {tags_block},
    chapters: [
      BookChapter(
        title: '{escape_for_dart(name)}',
        intro: ['{escape_for_dart(subtitle)} 개념 학습'],
        sections: [
          BookSection(
            title: '{escape_for_dart(name)}',
            paragraphs: [
{paragraphs_block}
            ],
          ),
        ],
      ),
    ],
  ),"""


def generate_dart_source(
    generated: dict[str, dict[str, Any]],
    leaves_mapping: dict[str, list[str]],
) -> str:
    parts: list[str] = []
    parts.append("// 개념 교재 하드코딩 데이터 (자동생성 - 수정 가급적 금지)")
    parts.append("import 'textbook.dart';")
    parts.append("")
    parts.append("final Map<String, BookData> kConceptTextbooks = {")

    for name, info in generated.items():
        path_list = leaves_mapping.get(name, [name])
        paragraphs = normalize_paragraphs(info.get("paragraphs") or [])
        if not paragraphs:
            paragraphs = [f"{name} 개념 설명 데이터가 비어 있습니다."]
        parts.append(build_bookdata(name, path_list, paragraphs))

    parts.append("};")
    parts.append("")
    parts.append(
        """/// 태그 목록에 해당하는 개념 교재를 반환합니다.
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

/// 학습자의 태그들을 하나의 통합 교재(BookData)로 묶어 반환합니다.
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
  final subtitle = normalized.take(3).join(', ') +
      (normalized.length > 3 ? ' ...' : '');
  return BookData(
    id: 'concept_study_' + normalized.join('_'),
    title: '개념 학습',
    subtitle: subtitle,
    category: 'common',
    tags: tags.toList(),
    chapters: chapters.isNotEmpty
        ? chapters
        : kConceptTextbooks.values.first.chapters,
  );
}
"""
    )

    return "\n".join(parts)


def main() -> None:
    parser = argparse.ArgumentParser(description="JSON -> Dart 교재 구조체 변환")
    parser.add_argument(
        "--input",
        default="gen_textbook/generated_textbooks.json",
        help="gen.py output JSON",
    )
    parser.add_argument(
        "--output",
        default="lib/models/concept_textbooks.dart",
        help="Target Dart file",
    )
    parser.add_argument(
        "--leaves",
        default="data/leaves.txt",
        help="Leaves path file",
    )
    args = parser.parse_args()

    generated = load_generated(args.input)
    leaves_mapping = load_leaves(args.leaves)
    dart_source = generate_dart_source(generated, leaves_mapping)

    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as file:
        file.write(dart_source)

    print(f"Patched {len(generated)} concepts into {args.output}")


if __name__ == "__main__":
    main()
