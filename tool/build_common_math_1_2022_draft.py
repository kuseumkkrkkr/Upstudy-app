"""Assemble tagged 2022 Common Mathematics 1 BookData samples by unit code."""

from __future__ import annotations

import json
import re
from collections import Counter, OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "공통수학1_2022개정_통합초안"
CODE = re.compile(r"10공수1-(\d{2})-(\d{2})")
UNIT = re.compile(r"10공수1-(\d{2})")


def signature(page: dict) -> str:
    return json.dumps({k: page.get(k) for k in ("title", "template", "blocks")}, ensure_ascii=False, sort_keys=True)


def main() -> None:
    source_files = sorted(MANUSCRIPTS.glob("공통수학1*_BookData*_시범.json"))
    grouped: OrderedDict[str, list[dict]] = OrderedDict()
    expected: Counter[str] = Counter()
    for path in source_files:
        book = json.loads(path.read_text(encoding="utf-8"))
        full_codes = sorted(set(match.group(0) for match in CODE.finditer(" ".join(book.get("tags", [])))))
        unit_codes = sorted(set(match.group(1) for match in UNIT.finditer(" ".join(book.get("tags", [])))))
        standard_codes = book.get("standard_codes", [])
        chapters = book.get("chapters", [])
        if not full_codes and not unit_codes and not standard_codes:
            continue
        if len(standard_codes) == len(chapters) and chapters:
            chapter_codes = standard_codes
        elif len(full_codes) == len(chapters) and chapters:
            chapter_codes = full_codes
        elif len(unit_codes) == 1:
            chapter_codes = [None] * len(chapters)
        else:
            raise RuntimeError(f"Cannot map source chapters to unit codes in {path.name}: {unit_codes}")
        if not chapters:
            raise RuntimeError(f"Missing pages in {path.name}")
        for chapter, code in zip(chapters, chapter_codes):
            pages = chapter.get("pages", [])
            if not pages:
                raise RuntimeError(f"Missing pages in {path.name}: {chapter.get('title', '')}")
            unit_match = re.fullmatch(r"10공수1-(\d{2})-\d{2}", code or "")
            unit = unit_match.group(1) if unit_match else (unit_codes[0] if len(unit_codes) == 1 else None)
            if unit is None:
                raise RuntimeError(f"Missing exact unit for source chapter in {path.name}: {code}")
            for page in pages:
                expected[signature(page)] += 1
            grouped.setdefault(unit, []).append({"file": path.name, "book": book, "chapter": chapter, "pages": pages, "code": code})
    if not grouped:
        raise RuntimeError("No tagged Common Mathematics 1 source samples found")

    OUTPUT.mkdir(parents=True, exist_ok=True)
    unit_list = []
    all_ids: list[str] = []
    actual: Counter[str] = Counter()
    for unit_code, modules in sorted(grouped.items()):
        chapters = []
        for module_index, module in enumerate(modules, 1):
            src = module["book"]
            subunit_title = module["chapter"].get("title", "")
            tags = src.get("tags", [])
            path_text = f"기준 후보 {module['code']}" if module["code"] else " · ".join(tags)
            opening = {
                "id": f"cm1-{unit_code}-{module_index:02d}-opening",
                "title": f"{subunit_title} · 원본 태그와 기준 후보",
                "template": "opening",
                "kicker": "기존 BookData 모듈",
                "blocks": [{"type": "lead", "title": "태그 경로", "text": path_text, "formula": "", "items": [], "rows": []}],
            }
            pages = [opening] + module["pages"]
            for page_index, page in enumerate(pages, 1):
                page["id"] = f"cm1-{unit_code}-{module_index:02d}-{page_index:03d}"
                all_ids.append(page["id"])
                if page is not opening:
                    actual[signature(page)] += 1
            chapters.append({"title": subunit_title, "pages": pages, "source_file": module["file"], "candidate_standard_codes": [module["code"]] if module["code"] else []})
        unit_title = f"공통수학1 단원 코드 {unit_code} · 후보 묶음"
        unit_book = {
            "title": unit_title,
            "tags": ["공통수학1", "2022 개정", f"10공수1-{unit_code}", "자동 통합 초안"],
            "chapters": chapters,
            "metadata": {"standard_code_status": "candidate_from_source_tags", "source_files": [m["file"] for m in modules]},
        }
        filename = f"공통수학1_2022개정_{unit_code}_통합초안.json"
        (OUTPUT / filename).write_text(json.dumps(unit_book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        unit_list.append((unit_code, filename, modules))
    if actual != expected or len(all_ids) != len(set(all_ids)):
        raise RuntimeError("Source page preservation or unique-ID verification failed")
    lines = ["# 공통수학1 2022 개정 태그별 통합 초안", "", f"기존 BookData {sum(len(modules) for _, _, modules in unit_list)}개를 단원 코드 그룹 {len(unit_list)}개로 묶었습니다. 원본 콘텐츠 지면 {sum(expected.values())}개를 보존하고, 소단원 도입 지면을 추가했습니다.", "", "## 단원", ""]
    for code, filename, modules in unit_list:
        lines.append(f"- [{code} 통합 초안]({filename}): 소단원 {len(modules)}개 / {sum(len(m['pages']) for m in modules)}개 원본 지면")
        for module in modules:
            lines.append(f"  - {' / '.join(ch.get('title', '') for ch in module['book']['chapters'])} (`{module['file']}`)")
    lines += ["", "단원명은 코드 번호를 임시로 사용했습니다. 공식 교육과정 원문 대조·교사 검수·과목 전체 범위 확인·앱 통합을 완료한 교재가 아닙니다.", "", "재생성: `python tool/build_common_math_1_2022_draft.py`", ""]
    (OUTPUT / "README.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"Built {len(unit_list)} unit drafts from {sum(len(m) for _, _, m in unit_list)} modules; preserved {sum(expected.values())} source pages; IDs verified.")


if __name__ == "__main__":
    main()
