"""Group existing 2022 Calculus II sine/cosine derivative BookData."""

from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "미적분2_2022개정_통합초안"
CODE = re.compile(r"12미적Ⅱ-(\d{2})-(\d{2})")


def signature(page: dict) -> str:
    return json.dumps({key: page.get(key) for key in ("title", "template", "blocks")}, ensure_ascii=False, sort_keys=True)


def main() -> None:
    groups: dict[str, list[dict]] = {}
    original: Counter[str] = Counter()
    for path in sorted(MANUSCRIPTS.glob("미적분Ⅱ*_BookData_시범.json")):
        book = json.loads(path.read_text(encoding="utf-8"))
        matches = list(CODE.finditer(" ".join(book.get("tags", []))))
        codes = sorted({(match.group(1), match.group(2)) for match in matches})
        if not codes:
            continue
        units = {unit for unit, _ in codes}
        if len(units) != 1:
            raise RuntimeError(f"Module spans multiple unit codes: {path.name}: {codes}")
        pages = [page for chapter in book.get("chapters", []) for page in chapter.get("pages", [])]
        if not pages:
            raise RuntimeError(f"No pages in {path.name}")
        for page in pages:
            original[signature(page)] += 1
        unit = next(iter(units))
        groups.setdefault(unit, []).append({"file": path.name, "book": book, "pages": pages, "codes": codes})
    if not groups:
        raise RuntimeError("No tagged 2022 Calculus II samples found")

    OUTPUT.mkdir(parents=True, exist_ok=True)
    outputs = []
    rendered: Counter[str] = Counter()
    all_ids: set[str] = set()
    for unit, modules in sorted(groups.items()):
        chapters = []
        for module_index, module in enumerate(modules, 1):
            title = " / ".join(chapter.get("title", "") for chapter in module["book"]["chapters"])
            tags = module["book"].get("tags", [])
            pages = [{
                "title": f"{title} · 원본 태그와 기준 후보",
                "template": "opening",
                "blocks": [{"type": "paragraph", "text": "태그 경로: " + " · ".join(tags)}, {"type": "paragraph", "text": "성취기준 코드 후보: " + ", ".join(f"12미적Ⅱ-{u}-{n}" for u, n in module["codes"]) + ". 공식 교육과정 대조 전 후보입니다."}],
            }] + module["pages"]
            for page_index, page in enumerate(pages, 1):
                page["id"] = f"calc2-{unit}-{module_index:02d}-{page_index:03d}"
                if page["id"] in all_ids:
                    raise RuntimeError(f"Duplicate ID {page['id']}")
                all_ids.add(page["id"])
                if page_index > 1:
                    rendered[signature(page)] += 1
            chapters.append({"title": title, "pages": pages, "source_file": module["file"], "candidate_standard_codes": [f"12미적Ⅱ-{u}-{n}" for u, n in module["codes"]]})
        filename = f"미적분Ⅱ_2022개정_{unit}_부분통합초안.json"
        data = {"title": f"미적분Ⅱ 2022 개정 · 단원 코드 {unit} 부분 통합 초안", "tags": ["미적분Ⅱ", "2022 개정", f"12미적Ⅱ-{unit}", "부분 통합 초안"], "chapters": chapters, "metadata": {"status": "partial_draft", "source_files": [module["file"] for module in modules]}}
        (OUTPUT / filename).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        outputs.append((filename, unit, modules))
    if rendered != original:
        raise RuntimeError("Source page title/template/block preservation failed")
    lines = ["# 미적분Ⅱ 2022 개정 부분 통합 초안", "", f"후보 코드 태그가 있는 BookData {sum(len(x[2]) for x in outputs)}개를 단원별로 묶었습니다. 기존 지면 {sum(original.values())}개를 보존했습니다.", "", "## 산출물", ""]
    for filename, unit, modules in outputs:
        lines.append(f"- [{unit} 단원 통합 초안]({filename})")
        for module in modules:
            title = " / ".join(ch.get("title", "") for ch in module["book"]["chapters"])
            codes = ", ".join(f"12미적Ⅱ-{u}-{n}" for u, n in module["codes"])
            lines.append(f"  - {title}: {codes} (`{module['file']}`)")
    lines += ["", "현재 사인·코사인 함수 미분 시범만 포함합니다. 과목 전체 범위, 공식 원문 대조, 교사 검수, 앱 통합은 완료되지 않았습니다.", "", "재생성: `python tool/build_calculus_2_2022_draft.py`", ""]
    (OUTPUT / "README.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"Built {sum(len(x[2]) for x in outputs)} modules; preserved {sum(original.values())} pages; unique IDs verified.")


if __name__ == "__main__":
    main()
