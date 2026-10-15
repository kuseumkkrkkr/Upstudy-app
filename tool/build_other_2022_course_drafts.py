"""Assemble remaining candidate-tagged 2022 high-school BookData samples."""

from __future__ import annotations

import json
import re
from collections import Counter, OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
COURSES = [
    {
        "name": "공통수학2",
        "glob": "공통수학2*_BookData_시범.json",
        "code": re.compile(r"10공수2-(\d{2})-(\d{2})"),
        "folder": "공통수학2_2022개정_통합초안",
        "code_prefix": "10공수2-",
    },
    {
        "name": "확률과 통계",
        "glob": "고등수학_확률과통계_*BookData_시범.json",
        "code": re.compile(r"12확통(\d{2})-(\d{2})"),
        "folder": "확률과통계_2022개정_통합초안",
        "code_prefix": "12확통",
    },
]


def signature(page: dict) -> str:
    return json.dumps({key: page.get(key) for key in ("title", "template", "blocks")}, ensure_ascii=False, sort_keys=True)


def build_course(config: dict) -> dict | None:
    grouped: OrderedDict[str, list[dict]] = OrderedDict()
    expected: Counter[str] = Counter()
    for path in sorted(MANUSCRIPTS.glob(config["glob"])):
        book = json.loads(path.read_text(encoding="utf-8"))
        matches = config["code"].finditer(" ".join(book.get("tags", [])))
        codes = sorted({(match.group(1), match.group(2)) for match in matches})
        if not codes:
            continue
        units = {unit for unit, _ in codes}
        if len(units) != 1:
            raise RuntimeError(f"Source spans multiple units: {path.name}: {codes}")
        pages = [page for chapter in book.get("chapters", []) for page in chapter.get("pages", [])]
        if not pages:
            raise RuntimeError(f"No pages in {path.name}")
        for page in pages:
            expected[signature(page)] += 1
        unit = next(iter(units))
        grouped.setdefault(unit, []).append({"file": path.name, "book": book, "pages": pages, "codes": codes})
    if not grouped:
        return None

    output = MANUSCRIPTS / config["folder"]
    output.mkdir(parents=True, exist_ok=True)
    actual: Counter[str] = Counter()
    ids: set[str] = set()
    rows = []
    for unit, modules in sorted(grouped.items()):
        chapters = []
        for module_index, module in enumerate(modules, 1):
            title = " / ".join(ch.get("title", "") for ch in module["book"]["chapters"])
            tags = module["book"].get("tags", [])
            page_list = [{
                "title": f"{title} · 원본 태그와 기준 후보",
                "template": "opening",
                "blocks": [{"type": "paragraph", "text": "태그 경로: " + " · ".join(tags)}, {"type": "paragraph", "text": "성취기준 코드 후보: " + ", ".join(f"{config['code_prefix']}{u}-{s}" for u, s in module["codes"]) + ". 공식 기준과 대조 전 후보입니다."}],
            }] + module["pages"]
            for page_index, page in enumerate(page_list, 1):
                page["id"] = f"other22-{config['code_prefix']}-{unit}-{module_index:02d}-{page_index:03d}"
                if page["id"] in ids:
                    raise RuntimeError(f"Duplicate page ID {page['id']}")
                ids.add(page["id"])
                if page_index > 1:
                    actual[signature(page)] += 1
            chapters.append({"title": title, "pages": page_list, "source_file": module["file"], "candidate_standard_codes": [f"{config['code_prefix']}{u}-{s}" for u, s in module["codes"]]})
        filename = f"{config['name']}_2022개정_{unit}_부분통합초안.json"
        data = {"title": f"{config['name']} 2022 개정 · 단원 코드 {unit} 부분 통합 초안", "tags": [config["name"], "2022 개정", f"{config['code_prefix']}{unit}", "부분 통합 초안"], "chapters": chapters, "metadata": {"status": "partial_draft", "source_files": [m["file"] for m in modules]}}
        (output / filename).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        rows.append((filename, unit, modules))
    if actual != expected:
        raise RuntimeError(f"Page preservation failed for {config['name']}")
    lines = [f"# {config['name']} 2022 개정 부분 통합 초안", "", f"후보 코드 태그가 있는 BookData {sum(len(row[2]) for row in rows)}개를 단원 코드별로 묶었습니다. 원본 지면 {sum(expected.values())}개를 보존했습니다.", "", "## 산출물", ""]
    for filename, unit, modules in rows:
        lines.append(f"- [{unit} 단원 통합 초안]({filename})")
        for module in modules:
            title = " / ".join(ch.get("title", "") for ch in module["book"]["chapters"])
            code_text = ", ".join(f"{config['code_prefix']}{u}-{s}" for u, s in module["codes"])
            lines.append(f"  - {title}: {code_text} (`{module['file']}`)")
    lines += ["", "현재 후보 태그가 있는 시범만 포함합니다. 과목 전체 범위, 공식 원문 대조, 교사 검수와 앱 통합은 완료되지 않았습니다.", "", "재생성: `python tool/build_other_2022_course_drafts.py`", ""]
    (output / "README.md").write_text("\n".join(lines), encoding="utf-8")
    return {"name": config["name"], "modules": sum(len(row[2]) for row in rows), "pages": sum(expected.values()), "units": len(rows), "output": str(output)}


def main() -> None:
    results = [result for config in COURSES if (result := build_course(config))]
    for result in results:
        print(f"{result['name']}: {result['modules']} modules, {result['units']} unit groups, {result['pages']} source pages preserved")


if __name__ == "__main__":
    main()
