"""Assemble available 2015 Mathematics II BookData by their unit tags."""

from __future__ import annotations

import json
from collections import Counter, OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "수학2_2015개정_통합초안"


def signature(page: dict) -> str:
    return json.dumps({key: page.get(key) for key in ("title", "template", "blocks")}, ensure_ascii=False, sort_keys=True)


def main() -> None:
    grouped: OrderedDict[str, list[dict]] = OrderedDict()
    original: Counter[str] = Counter()
    for path in sorted(MANUSCRIPTS.glob("수학Ⅱ*_BookData_시범.json")):
        book = json.loads(path.read_text(encoding="utf-8"))
        tags = book.get("tags", [])
        if not tags or tags[0] != "수학Ⅱ" or not any(tag.startswith("2015 개정") for tag in tags[1:3]):
            continue
        unit = next((tag for tag in tags[2:] if tag in {"함수의 극한", "함수의 연속", "미분", "정적분"}), None)
        if unit is None:
            raise RuntimeError(f"No recognized unit tag in {path.name}: {tags}")
        pages = [page for chapter in book.get("chapters", []) for page in chapter.get("pages", [])]
        if not pages:
            raise RuntimeError(f"No content pages in {path.name}")
        for page in pages:
            original[signature(page)] += 1
        grouped.setdefault(unit, []).append({"file": path.name, "book": book, "pages": pages, "tags": tags})
    if not grouped:
        raise RuntimeError("No matching Mathematics II source modules")

    OUTPUT.mkdir(parents=True, exist_ok=True)
    outputs = []
    copied: Counter[str] = Counter()
    ids: set[str] = set()
    for unit, modules in grouped.items():
        chapters = []
        for module_index, module in enumerate(modules, 1):
            title = " / ".join(ch.get("title", "") for ch in module["book"]["chapters"])
            opening = {"title": title + " · 태그 경로", "template": "opening", "blocks": [{"type": "paragraph", "text": " · ".join(module["tags"])}, {"type": "paragraph", "text": "기존 수학Ⅱ 시범 원고 지면을 이어서 학습합니다."}]}
            pages = [opening] + module["pages"]
            for page_index, page in enumerate(pages, 1):
                page["id"] = f"math2-2015-{len(outputs)+1:02d}-{module_index:02d}-{page_index:03d}"
                if page["id"] in ids:
                    raise RuntimeError(f"Duplicate page ID {page['id']}")
                ids.add(page["id"])
                if page_index > 1:
                    copied[signature(page)] += 1
            chapters.append({"title": title, "pages": pages, "source_file": module["file"], "source_tags": module["tags"]})
        filename = f"수학Ⅱ_2015개정_{unit}_통합초안.json"
        data = {"title": f"수학Ⅱ 2015 개정 · {unit} 단원 초안", "tags": ["수학Ⅱ", "2015 개정 후보", unit, "태그 기반 초안"], "chapters": chapters, "metadata": {"status": "partial_draft", "source_files": [m["file"] for m in modules]}}
        (OUTPUT / filename).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        outputs.append((filename, unit, modules))
    if copied != original:
        raise RuntimeError("Source page comparison failed")

    lines = ["# 수학Ⅱ 2015 개정 부분 통합 초안", "", f"기존 BookData {sum(len(row[2]) for row in outputs)}개를 원본 단원 태그 {len(outputs)}개에 배치했습니다. 원본 지면 {sum(original.values())}개를 보존했습니다.", "", "## 단원", ""]
    for filename, unit, modules in outputs:
        lines.append(f"- [{unit} 단원 초안]({filename})")
        for module in modules:
            title = " / ".join(ch.get("title", "") for ch in module["book"]["chapters"])
            lines.append(f"  - {title} (`{module['file']}`)")
    lines += ["", "도함수 부호·증감은 원본 태그가 2015 개정 후보로만 되어 있어 별도 미분 단원으로 두고, 기준 코드가 미대조임을 유지했습니다. 과목 전체 범위·공식 코드 대조·교사 검수·앱 통합은 미완료입니다.", "", "재생성: `python tool/build_math_2_2015_draft.py`", ""]
    (OUTPUT / "README.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"Built {sum(len(row[2]) for row in outputs)} modules in {len(outputs)} units; preserved {sum(original.values())} pages; IDs unique.")


if __name__ == "__main__":
    main()
