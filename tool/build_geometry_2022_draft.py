"""Group 2022 Geometry BookData samples by explicit candidate unit codes."""

from __future__ import annotations

import json
import re
from collections import Counter, OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "기하_2022개정_통합초안"
CODE = re.compile(r"12기하(\d{2})-(\d{2})")
UNIT_NAMES = {"01": "이차곡선", "02": "공간도형과 공간좌표", "03": "벡터"}


def signature(page: dict) -> str:
    return json.dumps({key: page.get(key) for key in ("title", "template", "blocks")}, ensure_ascii=False, sort_keys=True)


def main() -> None:
    groups: OrderedDict[str, list[dict]] = OrderedDict()
    original: Counter[str] = Counter()
    for path in sorted(MANUSCRIPTS.glob("*기하*_BookData_시범.json")):
        book = json.loads(path.read_text(encoding="utf-8"))
        tags = book.get("tags", [])
        # 2015 and 2022 Geometry reuse the code prefix and numbers with different meanings.
        if book.get("curriculum_version") != "2022" and not any(tag in {"2022 개정", "2022 개정 후보"} for tag in tags):
            continue
        raw_codes = book.get("standard_codes", [])
        raw_codes = raw_codes if isinstance(raw_codes, list) else [raw_codes]
        if book.get("standard_code"):
            raw_codes.append(book["standard_code"])
        matches = list(CODE.finditer(" ".join([*tags, *(str(code) for code in raw_codes)])))
        codes = sorted({match.group(0) for match in matches})
        if not codes:
            continue
        units = {match.group(1) for match in matches}
        if len(units) != 1:
            raise RuntimeError(f"Multiple geometry domains in {path.name}: {codes}")
        chapters = book.get("chapters", [])
        pages = [page for chapter in chapters for page in chapter.get("pages", [])]
        if not pages:
            raise RuntimeError(f"Missing source pages in {path.name}")
        for page in pages:
            original[signature(page)] += 1
        unit = next(iter(units))
        groups.setdefault(unit, []).append({"file": path.name, "book": book, "chapters": chapters, "pages": pages, "codes": codes})
    if not groups:
        raise RuntimeError("No 2022 Geometry candidate-code samples found")

    OUTPUT.mkdir(parents=True, exist_ok=True)
    outputs = []
    copied: Counter[str] = Counter()
    unique_ids: set[str] = set()
    for unit, modules in sorted(groups.items()):
        chapters = []
        chapter_index = 0
        for module in modules:
            tags = module["book"].get("tags", [])
            for source_chapter in module["chapters"]:
                chapter_index += 1
                title = source_chapter.get("title", module["book"].get("title", ""))
                source_pages = source_chapter.get("pages", [])
                chapter_text = json.dumps(source_chapter, ensure_ascii=False)
                chapter_codes = sorted({
                    match.group(0)
                    for match in CODE.finditer(chapter_text)
                    if match.group(0) in module["codes"]
                }) or module["codes"]
                pages = [{
                    "title": f"{title} · 기준 연결 후보",
                    "template": "opening",
                    "blocks": [{"type": "paragraph", "text": "원고 태그: " + " · ".join(tags)}, {"type": "paragraph", "text": f"공식 기준 코드 연결 후보: {', '.join(chapter_codes)}. 코드 문구는 원문과 대조했으나, 이 원고가 기준 전체를 충족하는지는 검수 전입니다."}],
                }] + source_pages
                for page_index, page in enumerate(pages, 1):
                    page["id"] = f"geometry-{unit}-{chapter_index:02d}-{page_index:03d}"
                    if page["id"] in unique_ids:
                        raise RuntimeError(f"Duplicate ID {page['id']}")
                    unique_ids.add(page["id"])
                    if page_index > 1:
                        copied[signature(page)] += 1
                chapters.append({"title": title, "pages": pages, "source_file": module["file"], "candidate_standard_codes": chapter_codes})
        unit_name = UNIT_NAMES.get(unit, f"단원 코드 {unit}")
        filename = f"기하_2022개정_{unit}_{unit_name}_부분통합초안.json"
        result = {"title": f"기하 2022 개정 · {unit_name} 부분 통합 초안", "curriculum_version": "2022", "standard_codes": sorted({code for module in modules for code in module["codes"]}), "tags": ["기하", "2022 개정", unit_name, f"12기하{unit}", "부분 통합 초안"], "chapters": chapters, "metadata": {"status": "partial_draft", "source_files": sorted({module["file"] for module in modules}), "curriculum_status": "official_codes_verified_content_coverage_pending", "teacher_review_status": "pending", "rights_status": "pending", "app_integration_status": "not_verified"}}
        (OUTPUT / filename).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        outputs.append((filename, unit, unit_name, modules))
    if copied != original:
        raise RuntimeError("Source page preservation check failed")

    book_count = sum(len(row[3]) for row in outputs)
    chapter_count = sum(1 for row in outputs for module in row[3] for _ in module["chapters"])
    lines = ["# 기하 2022 개정 태그별 부분 통합 초안", "", f"공식 기준 코드 후보가 있는 BookData {book_count}개({chapter_count}개 모듈)를 {len(outputs)}개 영역으로 나눴습니다. 원본 지면 {sum(original.values())}개를 보존했습니다. 신규 V2 모듈은 `standard_codes` 필드도 읽습니다.", "", "## 단원", ""]
    for filename, unit, unit_name, modules in outputs:
        lines.append(f"- [{unit_name} 통합 초안]({filename}) — 단원 코드 후보 12기하{unit}")
        for module in modules:
            title = " / ".join(ch.get("title", "") for ch in module["book"]["chapters"])
            lines.append(f"  - {title}: {', '.join(module['codes'])} (`{module['file']}`)")
    lines += ["", "기준 코드는 공식 HWP 본표와 연결한 후보입니다. 연결은 원고가 해당 기준 전체를 충족한다는 뜻이 아닙니다. 과목 전체 범위 검토·교사 검수·권리 확인·앱 통합은 미완료입니다.", "", "재생성: `python tool/build_geometry_2022_draft.py`", ""]
    (OUTPUT / "README.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"Built {chapter_count} modules from {book_count} BookData files in {len(outputs)} units; preserved {sum(original.values())} source pages; IDs unique.")


if __name__ == "__main__":
    main()
