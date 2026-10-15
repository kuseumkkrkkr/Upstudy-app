"""Export the existing concept manuscripts into unit-sized, tag-grouped books.

Hierarchy: subject (source package) > unit tag (one JSON file) > subunit tag
(chapter) > existing concept pages. The tag order is not claimed to be the
official curriculum order.
"""

from __future__ import annotations

import json
import re
from collections import Counter
from collections import OrderedDict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "태그별_교재패키지_초안"
SOURCE = ROOT / "lib/shared/data/models/concept_textbooks.dart"
PACKAGE_PATTERN = "*_원고패키지_판본대조전.json"
TAG_ENTRY = re.compile(
    r"(?ms)^\s*'([^']+)': BookData\(.*?^\s+tags: \[([^\]]*)\],"
)
TAG_VALUE = re.compile(r"'([^']*)'")


def slug(value: str) -> str:
    return re.sub(r"\s+", "_", re.sub(r'[<>:"/\\|?*]', "_", value))


def page_signature(page: dict) -> str:
    return json.dumps(
        {key: page.get(key) for key in ("title", "template", "blocks")},
        ensure_ascii=False,
        sort_keys=True,
    )


def load_tags() -> dict[str, list[str]]:
    source = SOURCE.read_text(encoding="utf-8")
    entries = {
        match.group(1): TAG_VALUE.findall(match.group(2))
        for match in TAG_ENTRY.finditer(source)
    }
    if len(entries) != 199:
        raise RuntimeError(f"Expected 199 tagged source concepts, found {len(entries)}")
    if any(len(tags) < 3 or any(not tag.strip() for tag in tags[:3]) for tags in entries.values()):
        raise RuntimeError("Every source concept must have subject, unit, and subunit tags")
    return entries


def export() -> None:
    tags_by_title = load_tags()
    packages = sorted(MANUSCRIPTS.glob(PACKAGE_PATTERN))
    if len(packages) != 4:
        raise RuntimeError(f"Expected four subject source packages, found {len(packages)}")

    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest_rows: list[tuple[str, str, str, int, int, int]] = []
    hierarchy_rows: list[tuple[str, str, str, str, list[str]]] = []
    total_concepts = total_pages = total_subunits = 0
    all_exported_titles: set[str] = set()
    expected_page_content: Counter[str] = Counter()

    for source_path in packages:
        source_book = json.loads(source_path.read_text(encoding="utf-8"))
        subject = source_book["tags"][0]
        grouped: OrderedDict[str, OrderedDict[str, list[dict]]] = OrderedDict()
        for chapter in source_book["chapters"]:
            title = chapter["title"]
            tags = tags_by_title.get(title)
            if not tags or tags[0] != subject:
                raise RuntimeError(f"No matching {subject} tag path for chapter {title!r}")
            if title in all_exported_titles:
                raise RuntimeError(f"Duplicate concept in source packages: {title!r}")
            all_exported_titles.add(title)
            unit, subunit = tags[1], tags[2]
            grouped.setdefault(unit, OrderedDict()).setdefault(subunit, []).append(
                {"chapter": chapter, "tags": tags, "title": title}
            )

        for unit, subunits in grouped.items():
            chapters = []
            unit_concepts = unit_pages = 0
            for subunit, concepts in subunits.items():
                pages = [
                    {
                        "id": f"tag-index-{slug(subject)}-{slug(unit)}-{slug(subunit)}",
                        "template": "opening",
                        "title": subunit,
                        "kicker": f"{unit} · {len(concepts)}개 개념",
                        "blocks": [
                            {
                                "type": "lead",
                                "title": "이 소단원에서 다룰 개념",
                                "text": " · ".join(item["title"] for item in concepts),
                                "formula": "",
                                "items": [],
                                "rows": [],
                            },
                            {
                                "type": "thinking",
                                "title": "학습 방법",
                                "text": "각 개념의 정의와 조건을 확인하고, 원리·예제·풀이·연습 지면을 차례로 살펴보세요.",
                                "formula": "",
                                "items": [],
                                "rows": [],
                            },
                        ],
                    }
                ]
                sections = []
                visuals = []
                for item in concepts:
                    chapter = item["chapter"]
                    if not chapter.get("pages"):
                        raise RuntimeError(f"Concept has no editorial pages: {item['title']!r}")
                    for section in chapter.get("sections", []):
                        sections.append(
                            {**section, "title": f"{item['title']} · {section['title']}"}
                        )
                    visuals.extend(chapter.get("visuals", []))
                    for page in chapter["pages"]:
                        expected_page_content[page_signature(page)] += 1
                        page_copy = dict(page)
                        page_copy["id"] = f"{slug(item['title'])}-{page['id']}"
                        page_copy["kicker"] = (
                            f"{' · '.join(item['tags'][2:])} · {page.get('kicker', '')}"
                        ).strip(" ·")
                        pages.append(page_copy)
                        unit_pages += 1

                chapters.append(
                    {
                        "title": subunit,
                        "intro": [
                            f"태그 경로: {subject} > {unit} > {subunit}",
                            "포함 개념: " + ", ".join(item["title"] for item in concepts),
                            "태그 편성 초안이며 공식 교육과정의 단원 순서 대조 전입니다.",
                        ],
                        "sections": sections,
                        "visuals": visuals,
                        "pages": pages,
                    }
                )
                unit_concepts += len(concepts)
                total_subunits += 1

            book = {
                **source_book,
                "title": f"{subject} · {unit} 개념서",
                "subtitle": "태그 기반 단원 분권 초안 · 교육과정 판본·성취기준 대조 전",
                "tags": [subject, unit, "태그 기반 편성 초안", "교육과정 대조 전"],
                "chapters": chapters,
            }
            file_name = f"{slug(subject)}_{slug(unit)}_개념서_초안.json"
            (OUTPUT / file_name).write_text(
                json.dumps(book, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
            manifest_rows.append(
                (file_name, subject, unit, len(subunits), unit_concepts, unit_pages)
            )
            hierarchy_rows.extend(
                (
                    file_name,
                    subject,
                    unit,
                    subunit,
                    [item["title"] for item in concepts],
                )
                for subunit, concepts in subunits.items()
            )
            total_concepts += unit_concepts
            total_pages += unit_pages

    missing_titles = set(tags_by_title) - all_exported_titles
    if missing_titles:
        preview = ", ".join(sorted(missing_titles)[:8])
        raise RuntimeError(f"Source package is missing tagged concepts: {preview}")
    if total_concepts != len(tags_by_title):
        raise RuntimeError(
            f"Exported {total_concepts} concepts, expected {len(tags_by_title)}"
        )

    actual_page_content: Counter[str] = Counter()
    generated_books = sorted(OUTPUT.glob("*.json"))
    if len(generated_books) != len(manifest_rows):
        raise RuntimeError(
            f"Found {len(generated_books)} generated books, expected {len(manifest_rows)}; "
            "reconcile old output files before regenerating"
        )
    for path in generated_books:
        book = json.loads(path.read_text(encoding="utf-8"))
        page_ids: set[str] = set()
        for chapter in book.get("chapters", []):
            pages = chapter.get("pages", [])
            if not pages or not pages[0].get("id", "").startswith("tag-index-"):
                raise RuntimeError(
                    f"Missing subunit opening page: {path.name}/{chapter.get('title')}"
                )
            for page in pages:
                page_id = page.get("id", "")
                if not page_id or page_id in page_ids:
                    raise RuntimeError(f"Empty or duplicate page id in {path.name}: {page_id!r}")
                page_ids.add(page_id)
                if not page_id.startswith("tag-index-"):
                    actual_page_content[page_signature(page)] += 1
    if actual_page_content != expected_page_content:
        raise RuntimeError("Generated output did not preserve all source page content")

    rows = [
        "# 태그별 개념서 분권 초안",
        "",
        "- 생성 원본: `lib/shared/data/models/concept_textbooks.dart`의 태그와 `*_원고패키지_판본대조전.json`의 원고",
        "- 구성: 과목별 원본 → 단원 태그별 JSON → 소단원 태그별 장 → 기존 개념 지면",
        "- 태그 배열 순서는 공식 교육과정 단원 순서로 간주하지 않음",
        "- 성취기준 판본 대조·교사 검수 전의 초안",
        "- 기존 페이지·절·시각자료를 보존하고 소단원 도입 지면만 추가",
        "",
        "| 파일 | 과목 | 단원 태그 | 소단원 | 개념 | 기존 지면 |",
        "|---|---|---|---:|---:|---:|",
    ]
    rows.extend(
        f"| `{file}` | {subject} | {unit} | {subunits} | {concepts} | {pages} |"
        for file, subject, unit, subunits, concepts, pages in manifest_rows
    )
    rows.extend(["", "## 단원·소단원·개념 목차", ""])
    for file, subject, unit, subunit, concepts in hierarchy_rows:
        rows.append(f"### [{subject} · {unit}](./{file}) / {subunit}")
        rows.append("")
        rows.append(" · ".join(concepts))
        rows.append("")
    rows.extend(
        [
            "",
            f"- 총 단원 패키지: {len(manifest_rows)}",
            f"- 소단원: {total_subunits}",
            f"- 원본 개념: {total_concepts}",
            f"- 보존한 기존 지면: {total_pages}",
        ]
    )
    (OUTPUT / "README.md").write_text("\n".join(rows) + "\n", encoding="utf-8")
    print(
        f"Generated {len(manifest_rows)} unit books, {total_subunits} subunits, "
        f"{total_concepts} concepts, {total_pages} existing pages at {OUTPUT}"
    )


if __name__ == "__main__":
    export()
