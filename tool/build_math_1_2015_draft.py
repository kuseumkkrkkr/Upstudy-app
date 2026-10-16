"""Split existing 2015 Mathematics I BookData by their subject/unit tags."""

from __future__ import annotations

import json
import re
from collections import Counter, OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "수학1_2015개정_통합초안"
CODE_RE = re.compile(r"12수학Ⅰ(\d{2})-(\d{2})")


def signature(page: dict) -> str:
    return json.dumps({key: page.get(key) for key in ("title", "template", "blocks")}, ensure_ascii=False, sort_keys=True)


def unit_from_tags(tags: list[str]) -> str | None:
    if "2015 개정" not in tags:
        return None
    if "삼각함수" in tags:
        return "삼각함수"
    if "수열" in tags:
        return "수열"
    if "지수함수" in tags and "로그함수" in tags:
        return "지수함수와 로그함수"
    return None


def main() -> None:
    grouped: OrderedDict[str, list[dict]] = OrderedDict()
    expected: Counter[str] = Counter()
    for path in sorted(MANUSCRIPTS.glob("*BookData*.json")):
        book = json.loads(path.read_text(encoding="utf-8"))
        tags = book.get("tags", [])
        if not tags or tags[0] != "수학Ⅰ" or not (book.get("curriculum_version") == "2015" or "2015 개정" in tags):
            continue
        tag_unit = unit_from_tags(tags)
        book_codes = sorted(set(CODE_RE.findall(" ".join(tags))))
        for source_chapter in book.get("chapters", []):
            chapter_codes = sorted(set(CODE_RE.findall(" ".join([source_chapter.get("title", ""), *source_chapter.get("intro", [])])))) or book_codes
            code_units = {unit for unit, _ in chapter_codes}
            if len(code_units) > 1:
                raise RuntimeError(f"A source chapter spans multiple Math I units: {path.name}/{source_chapter.get('title')}: {chapter_codes}")
            unit = {"01": "지수함수와 로그함수", "02": "삼각함수", "03": "수열"}.get(next(iter(code_units))) if code_units else tag_unit
            if unit is None:
                continue
            pages = source_chapter.get("pages", [])
            if not pages:
                raise RuntimeError(f"No content pages in {path.name}/{source_chapter.get('title')}")
            for page in pages:
                expected[signature(page)] += 1
            grouped.setdefault(unit, []).append({"file": path.name, "title": source_chapter.get("title", ""), "pages": pages, "tags": tags, "codes": [f"12수학Ⅰ{u}-{s}" for u, s in chapter_codes]})
    if not grouped:
        raise RuntimeError("No eligible Mathematics I source modules found")

    OUTPUT.mkdir(parents=True, exist_ok=True)
    actual: Counter[str] = Counter()
    ids: set[str] = set()
    rows = []
    for unit, modules in grouped.items():
        chapters = []
        for module_index, module in enumerate(modules, 1):
            title = module["title"]
            opening = {"title": title + " · 태그 경로", "template": "opening", "blocks": [{"type": "paragraph", "text": " · ".join(module["tags"])}, {"type": "paragraph", "text": "2015 개정 수학Ⅰ의 기존 시범 원고 지면을 학습합니다."}]}
            pages = [opening] + module["pages"]
            for page_index, page in enumerate(pages, 1):
                page["id"] = f"math1-2015-{len(rows)+1:02d}-{module_index:02d}-{page_index:03d}"
                if page["id"] in ids:
                    raise RuntimeError(f"Duplicate page ID {page['id']}")
                ids.add(page["id"])
                if page_index > 1:
                    actual[signature(page)] += 1
            subunit_tags = [tag for tag in module["tags"] if tag not in ("수학Ⅰ", "2015 개정", unit) and not any(x in tag for x in ("시범", "미검수", "코드 대조 전"))]
            chapters.append({"title": title, "tags": subunit_tags, "pages": pages, "source_file": module["file"], "source_tags": module["tags"], "candidate_standard_codes": module["codes"]})
        data = {"title": f"수학Ⅰ 2015 개정 · {unit} 단원 초안", "tags": ["수학Ⅰ", "2015 개정", unit, "태그 기반 초안"], "chapters": chapters, "metadata": {"status": "partial_draft", "source_files": [m["file"] for m in modules]}}
        filename = f"수학Ⅰ_2015개정_{unit}_통합초안.json"
        (OUTPUT / filename).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        rows.append((filename, unit, modules))
    if actual != expected:
        raise RuntimeError("Page content preservation check failed")

    lines = ["# 수학Ⅰ 2015 개정 태그별 부분 통합 초안", "", f"단원 태그 {len(rows)}개에 기존 BookData {sum(len(r[2]) for r in rows)}개를 배치했습니다. 기존 지면 {sum(expected.values())}개를 보존했습니다.", "", "## 단원", ""]
    for filename, unit, modules in rows:
        lines.append(f"- [{unit} 단원 초안]({filename})")
        for module in modules:
            codes = f"; 코드 후보: {', '.join(module['codes'])}" if module["codes"] else ""
            lines.append(f"  - {module['title']} (`{module['file']}`){codes}")
    lines += ["", "원본 태그 경로를 유지한 부분 초안입니다. 전체 과목 범위·공식 성취기준 대조·교사 검수·앱 통합은 완료되지 않았습니다.", "", "재생성: `python tool/build_math_1_2015_draft.py`", ""]
    (OUTPUT / "README.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"Built {sum(len(r[2]) for r in rows)} modules across {len(rows)} units; preserved {sum(expected.values())} source pages; IDs unique.")


if __name__ == "__main__":
    main()
