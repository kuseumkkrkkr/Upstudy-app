"""Split existing 2015 Probability and Statistics BookData by unit tags."""

from __future__ import annotations

import json
import re
from collections import Counter, OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "확률과통계_2015개정_통합초안"
HTML_DEMOS = [
    "확률과통계_2015개정_조건부확률_체험형_시범.html",
    "고등수학_확률과통계_이항분포_체험형_시범.html",
]


def signature(page: dict) -> str:
    return json.dumps({key: page.get(key) for key in ("title", "template", "blocks")}, ensure_ascii=False, sort_keys=True)


def main() -> None:
    grouped: OrderedDict[str, list[dict]] = OrderedDict()
    original: Counter[str] = Counter()
    unit_by_standard = {"01": "순열과 조합", "02": "확률", "03": "통계"}
    code_pattern = re.compile(r"12확통(\d{2})-\d{2}")
    generic_unit_tags = {"보완 원고 후보", "추가 원고 후보"}
    for path in sorted(MANUSCRIPTS.glob("확률과통계_2015개정*_BookData*_시범.json")):
        book = json.loads(path.read_text(encoding="utf-8"))
        tags = book.get("tags", [])
        if len(tags) < 3 or tags[:2] != ["확률과 통계", "2015 개정"]:
            raise RuntimeError(f"Unexpected edition tags in {path.name}")
        standard_codes = book.get("standard_codes", [])
        chapters = book.get("chapters", [])
        if not isinstance(standard_codes, list) or not isinstance(chapters, list):
            raise RuntimeError(f"Invalid candidate structure in {path.name}")
        if tags[2] not in generic_unit_tags:
            chapter_units = [tags[2]] * len(chapters)
        else:
            if len(standard_codes) != len(chapters):
                raise RuntimeError(f"Cannot map candidate chapters to standards in {path.name}")
            chapter_units = []
            for code in standard_codes:
                match = code_pattern.fullmatch(str(code))
                unit = unit_by_standard.get(match.group(1)) if match else None
                if unit is None:
                    raise RuntimeError(f"Unmapped 2015 probability standard {code!r} in {path.name}")
                chapter_units.append(unit)
        for chapter, unit in zip(chapters, chapter_units, strict=True):
            pages = chapter.get("pages", [])
            if not pages:
                raise RuntimeError(f"No content pages in {path.name}/{chapter.get('title', '')}")
            for page in pages:
                original[signature(page)] += 1
            chapter_book = {**book, "chapters": [chapter]}
            grouped.setdefault(unit, []).append({"file": path.name, "book": chapter_book, "pages": pages, "tags": tags})
    if not grouped:
        raise RuntimeError("No 2015 Probability and Statistics source modules")

    OUTPUT.mkdir(parents=True, exist_ok=True)
    outputs = []
    copied: Counter[str] = Counter()
    ids: set[str] = set()
    for unit, modules in grouped.items():
        chapters = []
        for module_index, module in enumerate(modules, 1):
            title = " / ".join(ch.get("title", "") for ch in module["book"]["chapters"])
            opening = {"title": title + " · 태그 경로", "template": "opening", "blocks": [{"type": "paragraph", "text": " · ".join(module["tags"])}, {"type": "paragraph", "text": "기존 2015 개정 시범 원고 지면을 학습합니다."}]}
            pages = [opening] + module["pages"]
            for page_index, page in enumerate(pages, 1):
                page["id"] = f"probstat15-{len(outputs)+1:02d}-{module_index:02d}-{page_index:03d}"
                if page["id"] in ids:
                    raise RuntimeError(f"Duplicate page ID {page['id']}")
                ids.add(page["id"])
                if page_index > 1:
                    copied[signature(page)] += 1
            chapters.append({"title": title, "pages": pages, "source_file": module["file"], "source_tags": module["tags"]})
        filename = f"확률과통계_2015개정_{unit}_통합초안.json"
        result = {"title": f"확률과 통계 2015 개정 · {unit} 단원 초안", "tags": ["확률과 통계", "2015 개정", unit, "태그 기반 초안"], "chapters": chapters, "metadata": {"status": "partial_draft", "source_files": [m["file"] for m in modules]}}
        (OUTPUT / filename).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        outputs.append((filename, unit, modules))
    if copied != original:
        raise RuntimeError("Page preservation check failed")

    lines = ["# 확률과 통계 2015 개정 태그별 부분 통합 초안", "", f"기존 BookData {sum(len(row[2]) for row in outputs)}개를 원본 단원 태그 {len(outputs)}개로 분리했습니다. 원본 지면 {sum(original.values())}개를 보존했습니다.", "", "## 단원", ""]
    for filename, unit, modules in outputs:
        lines.append(f"- [{unit} 단원 초안]({filename})")
        for module in modules:
            title = " / ".join(ch.get("title", "") for ch in module["book"]["chapters"])
            lines.append(f"  - {title} (`{module['file']}`)")
    lines += ["", "## 관련 체험형 HTML", ""]
    for demo in HTML_DEMOS:
        if (MANUSCRIPTS / demo).exists():
            note = "2015 개정 조건부확률 시범" if "조건부확률" in demo else "판본 중립 도구 시범; 2015 개정 원고와의 교육과정 대응 검증은 별도"
            lines.append(f"- [{demo}]({demo}) — {note}. BookData 임베드·앱 응답 저장은 확인되지 않았습니다.")
    lines += ["", "조건부확률·이항분포 부분만 다룹니다. 과목 전체 범위·공식 성취기준 대조·교사 검수·앱 통합은 미완료입니다.", "", "재생성: `python tool/build_probability_statistics_2015_draft.py`", ""]
    (OUTPUT / "README.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"Built {sum(len(row[2]) for row in outputs)} modules in {len(outputs)} units; preserved {sum(original.values())} pages; IDs unique.")


if __name__ == "__main__":
    main()
