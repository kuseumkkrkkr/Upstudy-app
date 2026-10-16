"""Package remaining BookData samples without inventing edition assignments."""

from __future__ import annotations

import json
import re
from collections import Counter, OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
CODE_RE = re.compile(r"(?:9수\d{2}-\d{2}|10공수2-\d{2}-\d{2}|12대수\d{2}-\d{2}|12확통\d{2}-\d{2})")
SOURCES = [
    {"file": "중등수학_일차함수_BookData_시범.json", "folder": "중등수학_2022개정_태그초안", "course": "중등 수학", "edition": "2022 개정 후보", "unit": "일차함수", "subunit": "기울기와 그래프 변화", "expected": ["중등수학", "일차함수", "2022 개정"]},
    {"file": "중등수학_좌표와순서쌍_BookData_시범.json", "folder": "중학교수학_판본미확인_태그초안", "course": "중학교 수학", "edition": "판본 미확인", "unit": "중1 수학 · 좌표평면", "subunit": "순서쌍", "expected": ["중1 수학", "좌표평면", "순서쌍"]},
    {"file": "중등수학_연립일차방정식_BookData_시범.json", "folder": "중학교수학_판본미확인_태그초안", "course": "중학교 수학", "edition": "판본 미확인", "unit": "중2 수학 · 연립일차방정식", "subunit": "연립방정식과 일차함수", "expected": ["중2 수학", "연립일차방정식"]},
    {"file": "중등수학_제곱근과제곱_개념서_BookData_시범.json", "folder": "중학교수학_판본미확인_태그초안", "course": "중학교 수학", "edition": "판본 미확인", "unit": "중3 수학 · 제곱근", "subunit": "제곱근과 제곱", "expected": ["중3 수학", "제곱근", "제곱"]},
    {"file": "공통수학2_유리함수_BookData_시범.json", "folder": "공통수학2_판본미확인_태그초안", "course": "공통수학2", "edition": "판본 미확인", "unit": "유리함수", "subunit": "점근선", "expected": ["공통수학2", "유리함수"]},
    {"file": "공통수학2_집합과명제_BookData_시범.json", "folder": "공통수학2_판본미확인_태그초안", "course": "공통수학2", "edition": "판본 미확인", "unit": "집합", "subunit": "포함관계와 벤다이어그램", "expected": ["공통수학2", "집합"]},
    {"file": "공통수학2_명제와조건_BookData_시범.json", "folder": "공통수학2_판본미확인_태그초안", "course": "공통수학2", "edition": "판본 미확인", "unit": "명제", "subunit": "조건·역·대우·전칭·존재", "expected": ["공통수학2", "명제", "조건"]},
    {"file": "대수_등차수열_BookData_시범.json", "folder": "대수_2022개정_태그초안", "course": "대수", "edition": "2022 개정 후보", "unit": "수열", "subunit": "등차수열", "expected": ["대수", "2022 개정", "수열"]},
    {"file": "대수_등비수열_BookData_시범.json", "folder": "대수_판본미확인_태그초안", "course": "대수", "edition": "판본 미확인", "unit": "수열", "subunit": "등비수열", "expected": ["대수", "수열", "등비수열"]},
    {"file": "고등수학_확률과통계_이항분포_BookData_시범.json", "folder": "확률과통계_판본미확인_태그초안", "course": "확률과 통계", "edition": "판본 미확인 · 2022 범위 참고 태그만", "unit": "이항분포", "subunit": "성공 횟수의 분포", "expected": ["확률과 통계", "이항분포"]},
]


def signature(page: dict) -> str:
    return json.dumps({key: page.get(key) for key in ("title", "template", "blocks")}, ensure_ascii=False, sort_keys=True)


def main() -> None:
    grouped: OrderedDict[tuple[str, str, str], list[dict]] = OrderedDict()
    for item in SOURCES:
        source = MANUSCRIPTS / item["file"]
        book = json.loads(source.read_text(encoding="utf-8"))
        tags = book.get("tags", [])
        if tags[:len(item["expected"])] != item["expected"]:
            raise RuntimeError(f"Tags changed for {source.name}: {tags}")
        has_edition_evidence = bool(book.get("curriculum_version")) or any(
            tag in {"2015 개정", "2015 개정 후보", "2022 개정", "2022 개정 후보"}
            for tag in tags
        )
        if "미확인" in item["edition"] and has_edition_evidence:
            # The source now has explicit edition provenance and is packaged by
            # its edition-aware generator; do not duplicate it under unknown edition.
            continue
        item["book"] = book
        item["tags"] = tags
        item["source"] = source
        item["codes"] = sorted(set(CODE_RE.findall(" ".join(tags))))
        key = (item["folder"], item["course"], item["edition"])
        grouped.setdefault(key, []).append(item)

    for (folder, course, edition), modules in grouped.items():
        output = MANUSCRIPTS / folder
        output.mkdir(parents=True, exist_ok=True)
        chapters = []
        expected_pages: Counter[str] = Counter()
        copied_pages: Counter[str] = Counter()
        ids: set[str] = set()
        for module_index, module in enumerate(modules, 1):
            for source_chapter in module["book"].get("chapters", []):
                source_pages = source_chapter.get("pages", [])
                if not source_pages:
                    raise RuntimeError(f"No source pages in {module['file']}")
                expected_pages.update(signature(page) for page in source_pages)
                intro = {"title": module["subunit"] + " · 원본 태그 경로", "template": "opening", "blocks": [{"type": "paragraph", "text": " · ".join(module["tags"])}, {"type": "paragraph", "text": f"분권 상태: {edition}. 원본 판본과 기준 대조 상태를 초안 메타데이터에 유지합니다."}]}
                pages = [intro] + source_pages
                for page_index, page in enumerate(pages, 1):
                    page["id"] = f"remaining-{folder}-{module_index:02d}-{len(chapters)+1:02d}-{page_index:03d}"
                    if page["id"] in ids:
                        raise RuntimeError(f"Duplicate page ID {page['id']}")
                    ids.add(page["id"])
                    if page_index > 1:
                        copied_pages[signature(page)] += 1
                codes = module["codes"]
                chapters.append({"title": f"{module['unit']} · {module['subunit']}", "pages": pages, "source_file": module["file"], "source_tags": module["tags"], "candidate_standard_codes": codes})
        if copied_pages != expected_pages:
            raise RuntimeError(f"Original page preservation failed for {course}/{edition}")

        safe_edition = "판본미확인" if "미확인" in edition else "2022개정후보"
        filename = f"{course}_{safe_edition}_태그통합초안.json"
        result = {"title": f"{course} · {edition} 태그 통합 초안", "tags": [course, edition, "태그 기반 부분 초안"], "chapters": chapters, "metadata": {"status": "partial_draft", "edition_status": edition, "source_files": [m["file"] for m in modules]}}
        (output / filename).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

        lines = [f"# {course} · {edition} 태그 통합 초안", "", f"BookData {len(modules)}개를 태그 단위로 묶었습니다. 원본 지면 {sum(expected_pages.values())}개를 보존했습니다.", "", "## 단원·소단원", ""]
        for module in modules:
            title = " / ".join(ch.get("title", "") for ch in module["book"]["chapters"])
            codes = f"; 코드 후보: {', '.join(module['codes'])}" if module["codes"] else ""
            lines.append(f"- {module['unit']} / {module['subunit']}: {title} (`{module['file']}`){codes}")
        lines += ["", f"판본 상태: {edition}. 이 초안은 공식 교육과정 전체 범위, 교사 검수, 앱 통합을 완료하지 않았습니다.", "", "재생성: `python tool/build_remaining_tagged_samples.py`", ""]
        (output / "README.md").write_text("\n".join(lines), encoding="utf-8")
        print(f"{course} ({edition}): {len(modules)} modules, {sum(expected_pages.values())} source pages preserved")


if __name__ == "__main__":
    main()
