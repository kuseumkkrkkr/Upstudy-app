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
UNIT_NAMES = {"01": "이차곡선", "02": "공간도형과 공간좌표"}


def signature(page: dict) -> str:
    return json.dumps({key: page.get(key) for key in ("title", "template", "blocks")}, ensure_ascii=False, sort_keys=True)


def main() -> None:
    groups: OrderedDict[str, list[dict]] = OrderedDict()
    original: Counter[str] = Counter()
    for path in sorted(MANUSCRIPTS.glob("*기하*_BookData_시범.json")):
        book = json.loads(path.read_text(encoding="utf-8"))
        matches = list(CODE.finditer(" ".join(book.get("tags", []))))
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
        groups.setdefault(unit, []).append({"file": path.name, "book": book, "pages": pages, "codes": codes})
    if not groups:
        raise RuntimeError("No 2022 Geometry candidate-code samples found")

    OUTPUT.mkdir(parents=True, exist_ok=True)
    outputs = []
    copied: Counter[str] = Counter()
    unique_ids: set[str] = set()
    for unit, modules in sorted(groups.items()):
        chapters = []
        for module_index, module in enumerate(modules, 1):
            title = " / ".join(chapter.get("title", "") for chapter in module["book"]["chapters"])
            tags = module["book"].get("tags", [])
            pages = [{
                "title": f"{title} · 원본 태그와 기준 후보",
                "template": "opening",
                "blocks": [{"type": "paragraph", "text": "태그 경로: " + " · ".join(tags)}, {"type": "paragraph", "text": f"성취기준 코드 후보: {', '.join(module['codes'])}. 공식 원문 대조 전 후보입니다."}],
            }] + module["pages"]
            for page_index, page in enumerate(pages, 1):
                page["id"] = f"geometry-{unit}-{module_index:02d}-{page_index:03d}"
                if page["id"] in unique_ids:
                    raise RuntimeError(f"Duplicate ID {page['id']}")
                unique_ids.add(page["id"])
                if page_index > 1:
                    copied[signature(page)] += 1
            chapters.append({"title": title, "pages": pages, "source_file": module["file"], "candidate_standard_codes": module["codes"]})
        unit_name = UNIT_NAMES.get(unit, f"단원 코드 {unit}")
        filename = f"기하_2022개정_{unit}_{unit_name}_부분통합초안.json"
        result = {"title": f"기하 2022 개정 · {unit_name} 부분 통합 초안", "tags": ["기하", "2022 개정", unit_name, f"12기하{unit}", "부분 통합 초안"], "chapters": chapters, "metadata": {"status": "partial_draft", "source_files": [module["file"] for module in modules]}}
        (OUTPUT / filename).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        outputs.append((filename, unit, unit_name, modules))
    if copied != original:
        raise RuntimeError("Source page preservation check failed")

    lines = ["# 기하 2022 개정 태그별 부분 통합 초안", "", f"후보 코드 태그가 붙은 BookData {sum(len(row[3]) for row in outputs)}개를 2개 영역으로 나눴습니다. 원본 지면 {sum(original.values())}개를 보존했습니다.", "", "## 단원", ""]
    for filename, unit, unit_name, modules in outputs:
        lines.append(f"- [{unit_name} 통합 초안]({filename}) — 단원 코드 후보 12기하{unit}")
        for module in modules:
            title = " / ".join(ch.get("title", "") for ch in module["book"]["chapters"])
            lines.append(f"  - {title}: {', '.join(module['codes'])} (`{module['file']}`)")
    lines += ["", "단원명과 코드는 태그에서 가져온 후보입니다. 교육과정 원문 대조·과목 전체 범위 검토·교사 검수·앱 통합은 미완료입니다.", "", "재생성: `python tool/build_geometry_2022_draft.py`", ""]
    (OUTPUT / "README.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"Built {sum(len(row[3]) for row in outputs)} modules in {len(outputs)} units; preserved {sum(original.values())} pages; IDs unique.")


if __name__ == "__main__":
    main()
