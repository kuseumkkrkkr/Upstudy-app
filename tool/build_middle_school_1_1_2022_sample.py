"""Assemble the existing 2022 middle-school 1-1 samples into one draft book.

The four unit groupings and candidate standards come from the local scope-map
example. They are not asserted to be the nationwide semester sequence.
"""

from __future__ import annotations

import json
import re
from collections import Counter, OrderedDict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "중학수학1-1_2022개정_통합시범"
INPUT_PATTERN = "중학수학1-1_2022개정*_BookData_시범.json"
CODE_RE = re.compile(r"9수\d{2}-\d{2}")

UNIT_GROUPS = OrderedDict(
    [
        (
            "수와 연산 · 소인수분해",
            {"9수01-01", "9수01-02"},
        ),
        (
            "수와 연산 · 정수와 유리수",
            {"9수01-03", "9수01-04", "9수01-05"},
        ),
        (
            "변화와 관계 · 문자와 식",
            {"9수02-01", "9수02-02", "9수02-03", "9수02-04"},
        ),
        (
            "변화와 관계 · 좌표평면과 그래프",
            {"9수02-05", "9수02-06", "9수02-07"},
        ),
    ]
)
MODULE_ORDER = {
    "중학수학1-1_2022개정_문자와식_일차식의덧셈과뺄셈_BookData_시범.json": 1,
    "중학수학1-1_2022개정_문자와식_일차식과수의곱셈나눗셈_BookData_시범.json": 2,
}


def signature(page: dict) -> str:
    return json.dumps(
        {key: page.get(key) for key in ("title", "template", "blocks")},
        ensure_ascii=False,
        sort_keys=True,
    )


def slug(value: str) -> str:
    return re.sub(r"\s+", "_", re.sub(r'[<>:"/\\|?*]', "_", value))


def main() -> None:
    inputs = sorted(MANUSCRIPTS.glob(INPUT_PATTERN))
    if len(inputs) != 11:
        raise RuntimeError(f"Expected 11 2022 middle 1-1 samples, found {len(inputs)}")

    grouped: OrderedDict[str, list[dict]] = OrderedDict(
        (unit, []) for unit in UNIT_GROUPS
    )
    expected_pages: Counter[str] = Counter()
    for path in inputs:
        book = json.loads(path.read_text(encoding="utf-8"))
        tags = book.get("tags", [])
        codes = sorted(set(CODE_RE.findall(" ".join(tags))))
        if not codes:
            raise RuntimeError(f"No candidate standard code in {path.name}")
        matching_units = [
            unit for unit, unit_codes in UNIT_GROUPS.items() if set(codes) & unit_codes
        ]
        if len(matching_units) != 1:
            raise RuntimeError(
                f"Candidate codes do not map to exactly one scope unit: {path.name}: {codes}"
            )
        chapter_list = book.get("chapters", [])
        if not chapter_list:
            raise RuntimeError(f"No chapters in {path.name}")
        module_title = " / ".join(chapter["title"] for chapter in chapter_list)
        for chapter in chapter_list:
            if not chapter.get("pages"):
                raise RuntimeError(f"No editorial pages in {path.name}/{chapter['title']}")
            for page in chapter["pages"]:
                expected_pages[signature(page)] += 1
        grouped[matching_units[0]].append(
            {
                "book": book,
                "codes": codes,
                "file": path.name,
                "module_title": module_title,
            }
        )

    # Keep the local scope-map order for the two modules sharing 9수02-02.
    for unit, modules in grouped.items():
        modules.sort(
            key=lambda item: (
                min(item["codes"]),
                MODULE_ORDER.get(item["file"], 99),
                item["module_title"],
            )
        )
        if not modules:
            raise RuntimeError(f"No samples mapped to scope unit {unit}")

    chapters = []
    total_source_pages = 0
    for unit, modules in grouped.items():
        pages = [
            {
                "id": f"unit-opening-{slug(unit)}",
                "template": "opening",
                "title": unit,
                "kicker": "2022 개정 중학교편 학기 예시",
                "blocks": [
                    {
                        "type": "lead",
                        "title": "이 단원 예시의 범위",
                        "text": " · ".join(item["module_title"] for item in modules),
                        "formula": "",
                        "items": [],
                        "rows": [],
                    },
                    {
                        "type": "thinking",
                        "title": "기준 코드 상태",
                        "text": "아래 코드는 원고에 기록된 성취기준 후보입니다. 교육부 별책 8 원문과 교사 검수 전까지 확정 매핑으로 보지 않습니다.",
                        "formula": "",
                        "items": [],
                        "rows": [],
                    },
                ],
            }
        ]
        sections = []
        visuals = []
        for module in modules:
            source = module["book"]
            module_title = module["module_title"]
            codes = ", ".join(module["codes"])
            pages.append(
                {
                    "id": f"subunit-opening-{slug(module['file'])}",
                    "template": "concept",
                    "title": module_title,
                    "kicker": f"소단원 · 기준 후보 {codes}",
                    "blocks": [
                        {
                            "type": "lead",
                            "title": "학습 지면 안내",
                            "text": f"이 소단원은 {module_title}을 다룹니다. 기준 코드는 {codes} 후보입니다.",
                            "formula": "",
                            "items": [],
                            "rows": [],
                        },
                        {
                            "type": "paragraph",
                            "title": "원본 태그 경로와 검수 상태",
                            "text": " > ".join(source.get("tags", [])),
                            "formula": "",
                            "items": [],
                            "rows": [],
                        },
                    ],
                }
            )
            for chapter in source.get("chapters", []):
                for section in chapter.get("sections", []):
                    sections.append(
                        {
                            **section,
                            "title": f"{module_title} · {section['title']}",
                        }
                    )
                visuals.extend(chapter.get("visuals", []))
                for page in chapter["pages"]:
                    page_copy = dict(page)
                    page_copy["id"] = f"{slug(module['file'])}-{page['id']}"
                    page_copy["kicker"] = (
                        f"{module_title} · {page.get('kicker', '')} · {codes}"
                    ).strip(" ·")
                    pages.append(page_copy)
                    total_source_pages += 1
        chapters.append(
            {
                "title": unit,
                "intro": [
                    "학기 편성 참고: 경기도교육청 2025 중학교편의 중1 1학기 예시",
                    "단원 구성: " + ", ".join(item["module_title"] for item in modules),
                    "학교별 진도와 배열은 달라질 수 있으며 이 묶음은 고정 진도가 아니다.",
                ],
                "sections": sections,
                "visuals": visuals,
                "pages": pages,
            }
        )

    book = {
        "title": "중학수학 1-1 개념서 · 2022 개정",
        "subtitle": "경기도교육청 중학교편 중1 1학기 예시 범위 기반 통합 시범 · 판본 원문 대조·교사 검수 전",
        "category": "concept_textbook_prototype",
        "tags": [
            "중학수학 1-1",
            "2022 개정 후보",
            "학기 예시 편성",
            "통합 시범",
            "교육부 별책 8 원문 대조 전",
            "교사 검수 전",
        ],
        "chapters": chapters,
    }

    OUTPUT.mkdir(parents=True, exist_ok=True)
    output_file = OUTPUT / "중학수학1-1_2022개정_통합시범.json"
    output_file.write_text(
        json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    # Re-read the artifact and compare every original content page by title/template/blocks.
    rendered = json.loads(output_file.read_text(encoding="utf-8"))
    actual_pages: Counter[str] = Counter()
    page_ids: set[str] = set()
    for chapter in rendered["chapters"]:
        if not chapter["pages"] or not chapter["pages"][0]["id"].startswith("unit-opening-"):
            raise RuntimeError(f"Missing unit opening page: {chapter['title']}")
        for page in chapter["pages"]:
            if page["id"] in page_ids:
                raise RuntimeError(f"Duplicate page ID: {page['id']}")
            page_ids.add(page["id"])
            if page["id"].startswith(("unit-opening-", "subunit-opening-")):
                continue
            actual_pages[signature(page)] += 1
    if actual_pages != expected_pages:
        raise RuntimeError("Integrated book did not preserve every source page")
    if total_source_pages != sum(expected_pages.values()):
        raise RuntimeError("Source page count changed during assembly")

    html_files = sorted(
        path.name
        for path in MANUSCRIPTS.glob("중학수학1-1_2022개정*_체험형_시범.html")
    )
    summary = [
        "# 중학수학 1-1 개념서 · 2022 개정 통합 시범",
        "",
        "- 범위 근거: `중학수학1-1_2022개정_성취기준_목차대조.md`의 경기도교육청 중학교편 중1 1학기 사례",
        "- 구성: 네 단원 예시 → 태그/성취기준 후보가 붙은 소단원 → 기존 BookData 페이지",
        "- 전국 공통 학기 진도나 교육부 별책 8 원문 대조 완료를 뜻하지 않음",
        "- 성취기준 코드는 입력 원고의 후보 태그를 보존했으며 확정 매핑으로 승격하지 않음",
        "- 원고 내용 페이지는 제목·템플릿·블록 일치로 보존 확인; 통합 앱·화면낭독기·교사 검수는 별도",
        "",
        f"- 입력 BookData: {len(inputs)}개",
        f"- 단원 예시: {len(chapters)}개",
        f"- 기존 내용 지면: {total_source_pages}개",
        f"- 추가 단원/소단원 도입 지면: {len(chapters)} + {len(inputs)}개",
        "",
    ]
    summary.extend(["## 단원·소단원과 기준 후보", ""])
    for unit, modules in grouped.items():
        summary.extend([f"### {unit}", ""])
        for module in modules:
            summary.append(
                f"- {module['module_title']} — 기준 후보 {', '.join(module['codes'])}"
            )
            summary.append("  - 원본 태그: " + " > ".join(module["book"].get("tags", [])))
        summary.append("")
    summary.extend(
        [
            "## 연결된 독립 체험 HTML",
            "",
            "아래 파일은 같은 교재 폴더의 독립 시범물이며 이 BookData에 임베드되거나 학생 응답을 저장하지 않는다.",
            "",
        ]
    )
    summary.extend(f"- `../{name}`" for name in html_files)
    (OUTPUT / "README.md").write_text("\n".join(summary) + "\n", encoding="utf-8")
    print(
        f"Built {output_file}: {len(inputs)} modules, {len(chapters)} units, "
        f"{total_source_pages} existing pages preserved, {len(html_files)} separate HTML demos"
    )


if __name__ == "__main__":
    main()
