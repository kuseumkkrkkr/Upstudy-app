"""Group current 2022 Calculus I sample BookData by candidate unit code."""

from __future__ import annotations

import json
import re
from collections import Counter, OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "미적분1_2022개정_통합초안"
CODE = re.compile(r"12미적Ⅰ-(\d{2})-(\d{2})")


def signature(page: dict) -> str:
    return json.dumps({k: page.get(k) for k in ("title", "template", "blocks")}, ensure_ascii=False, sort_keys=True)


def main() -> None:
    grouped: OrderedDict[str, list[dict]] = OrderedDict()
    expected: Counter[str] = Counter()
    for path in sorted(MANUSCRIPTS.glob("미적분Ⅰ*_BookData_시범.json")):
        book = json.loads(path.read_text(encoding="utf-8"))
        codes = sorted({match.group(2) for match in CODE.finditer(" ".join(book.get("tags", [])))})
        if not codes:
            continue
        chapters = book.get("chapters", [])
        pages = [p for c in chapters for p in c.get("pages", [])]
        if not pages:
            raise RuntimeError(f"No pages in {path.name}")
        for page in pages:
            expected[signature(page)] += 1
        # Every current source module belongs to the 02 domain. Keep all codes
        # on its chapter opening rather than pretending each source is a full unit.
        unit = "02"
        grouped.setdefault(unit, []).append({"file": path.name, "book": book, "pages": pages, "codes": codes})
    if not grouped:
        raise RuntimeError("No tagged 2022 Calculus I BookData samples found")

    OUTPUT.mkdir(parents=True, exist_ok=True)
    products = []
    actual: Counter[str] = Counter()
    seen_ids: set[str] = set()
    for unit, modules in sorted(grouped.items()):
        chapters = []
        for module_index, item in enumerate(modules, 1):
            source_chapters = item["book"]["chapters"]
            title = " / ".join(ch.get("title", "") for ch in source_chapters)
            tags = item["book"].get("tags", [])
            pages = [{
                "title": f"{title} · 원본 태그와 기준 후보",
                "template": "opening",
                "blocks": [
                    {"type": "paragraph", "text": "태그 경로: " + " · ".join(tags)},
                    {"type": "paragraph", "text": "성취기준 코드 후보: " + ", ".join(f"12미적Ⅰ-{unit}-{n}" for n in item["codes"]) + ". 후보 태그이며 공식 대조는 미완료입니다."},
                ],
            }] + item["pages"]
            for page_index, page in enumerate(pages, 1):
                page["id"] = f"calc1-{unit}-{module_index:02d}-{page_index:03d}"
                if page["id"] in seen_ids:
                    raise RuntimeError(f"Duplicate page ID: {page['id']}")
                seen_ids.add(page["id"])
                if page_index > 1:
                    actual[signature(page)] += 1
            chapters.append({"title": title, "pages": pages, "source_file": item["file"], "candidate_standard_codes": [f"12미적Ⅰ-{unit}-{n}" for n in item["codes"]]})
        result = {
            "title": f"미적분Ⅰ 2022 개정 · 단원 코드 {unit} 부분 통합 초안",
            "tags": ["미적분Ⅰ", "2022 개정", f"12미적Ⅰ-{unit}", "부분 통합 초안"],
            "chapters": chapters,
            "metadata": {"status": "partial_draft", "source_files": [x["file"] for x in modules]},
        }
        name = f"미적분Ⅰ_2022개정_{unit}_부분통합초안.json"
        (OUTPUT / name).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        products.append((name, modules))
    if actual != expected:
        raise RuntimeError("Original page preservation verification failed")

    lines = ["# 미적분Ⅰ 2022 개정 부분 통합 초안", "", f"성취기준 후보 태그가 붙은 기존 BookData {sum(len(m) for _, m in products)}개를 묶었습니다. 원본 지면 {sum(expected.values())}개를 보존했습니다.", "", "## 결과", ""]
    for name, modules in products:
        lines.append(f"- [{name}]({name})")
        for item in modules:
            lines.append(f"  - {' / '.join(c.get('title', '') for c in item['book']['chapters'])}: {', '.join(f'12미적Ⅰ-02-{c}' for c in item['codes'])} (`{item['file']}`)")
    lines += ["", "현재 태그가 있는 미분 영역 샘플만 포함합니다. 과목의 전체 단원 편성이나 교육과정 기준을 완성한 교재가 아니며, 공식 원문 대조·교사 검수·앱 통합은 미완료입니다.", "", "재생성: `python tool/build_calculus_1_2022_draft.py`", ""]
    (OUTPUT / "README.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"Built {sum(len(m) for _, m in products)} modules; preserved {sum(expected.values())} source pages; IDs unique.")


if __name__ == "__main__":
    main()
