"""Combine tagged 2015 Math (Upper/Lower) subunits into book-level drafts."""

from __future__ import annotations

import json
from pathlib import Path

from audit_2015_upper_lower_scope import MAPPING

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"

VOLUMES = {
    "수학상_2015개정_초안": [
        ("다항식", [
            "수학상_2015개정_다항식의덧셈과뺄셈_BookData_초안.json",
            "수학상_2015개정_나머지정리와인수정리_BookData_초안.json",
            "수학상_2015개정_인수분해_BookData_초안.json",
            "수학상_2015개정_항등식_V2_BookData_초안.json",
        ]),
        ("방정식과 부등식", [
            "수학상_2015개정_복소수_BookData_초안.json",
            "수학상_2015개정_복소수범위의이차방정식_BookData_초안.json",
            "수학상_2015개정_이차방정식과이차함수_BookData_초안.json",
            "수학상_2015개정_근과계수의관계_BookData_초안.json",
            "수학상_2015개정_삼차방정식_BookData_초안.json",
            "수학상_2015개정_분수방정식_BookData_초안.json",
            "수학상_2015개정_무리방정식_BookData_초안.json",
            "수학상_2015개정_연립이차방정식_BookData_초안.json",
            "수학상_2015개정_연립일차부등식_BookData_초안.json",
            "수학상_2015개정_이차부등식_BookData_초안.json",
            "수학상_2015개정_절댓값일차부등식_V2_BookData_초안.json",
        ]),
        ("도형의 방정식", [
            "수학상_2015개정_거리와중점_BookData_초안.json",
            "수학상_2015개정_점과직선사이거리_V2_BookData_초안.json",
            "수학상_2015개정_직선의방정식_BookData_초안.json",
            "수학상_2015개정_평행수직직선_BookData_초안.json",
            "수학상_2015개정_원의방정식_BookData_초안.json",
            "수학상_2015개정_직선과원의위치관계_BookData_초안.json",
            "수학상_2015개정_원의접선_BookData_초안.json",
            "수학상_2015개정_도형의이동_BookData_초안.json",
        ]),
    ],
    "수학하_2015개정_초안": [
        ("수와 연산", [
            "수학하_2015개정_집합의합집합과교집합_BookData_초안.json",
            "수학하_2015개정_여집합과차집합_BookData_초안.json",
            "수학하_2015개정_명제와조건_BookData_초안.json",
            "수학하_2015개정_집합포함관계_V2_BookData_초안.json",
            "수학하_2015개정_명제의역과대우_V2_BookData_초안.json",
            "수학하_2015개정_충분조건필요조건_V2_BookData_초안.json",
            "수학하_2015개정_대우증명과귀류법_V2_BookData_초안.json",
            "수학하_2015개정_절대부등식_V2_BookData_초안.json",
        ]),
        ("함수", [
            "수학하_2015개정_함수의뜻_BookData_초안.json",
            "수학하_2015개정_함수의합성_V2_BookData_초안.json",
            "수학하_2015개정_역함수_V2_BookData_초안.json",
            "수학하_2015개정_유리함수_BookData_초안.json",
            "수학하_2015개정_무리함수_BookData_초안.json",
        ]),
        ("확률과 통계", [
            "수학하_2015개정_경우의수기본원리_BookData_초안.json",
            "수학하_2015개정_순열_BookData_초안.json",
            "수학하_2015개정_조합_BookData_초안.json",
        ]),
    ],
}


def build_volume(folder_name: str, units: list[tuple[str, list[str]]]) -> None:
    output_dir = MANUSCRIPTS / folder_name
    chapters = []
    unit_records = []
    tags = set()
    standard_codes = set()
    candidate_standard_codes = set()
    page_ids = []
    page_count = 0
    for unit_title, filenames in units:
        chapter_titles = []
        for filename in filenames:
            source_path = output_dir / filename
            if not source_path.is_file():
                raise FileNotFoundError(f"Missing subunit BookData: {source_path}")
            source = json.loads(source_path.read_text(encoding="utf-8"))
            tags.update(source.get("tags", []))
            codes = source.get("standard_codes", [])
            if isinstance(codes, list):
                standard_codes.update(str(code) for code in codes)
            for chapter in source.get("chapters", []):
                chapter_copy = dict(chapter)
                chapter_copy["unitTitle"] = unit_title
                chapter_codes = [code for code, (title, _) in MAPPING.items() if title == chapter_copy.get("title")]
                if chapter_codes:
                    chapter_copy["candidate_standard_codes"] = chapter_codes
                    candidate_standard_codes.update(chapter_codes)
                chapters.append(chapter_copy)
                chapter_titles.append(chapter_copy["title"])
                pages = chapter_copy.get("pages", [])
                page_count += len(pages)
                page_ids.extend(page.get("id") for page in pages)
        unit_records.append({"title": unit_title, "chapterTitles": chapter_titles})

    if len(page_ids) != len(set(page_ids)):
        raise RuntimeError(f"Duplicate page IDs in combined volume: {folder_name}")
    if len(chapters) != sum(len(files) for _, files in units):
        raise RuntimeError(f"Unexpected chapter count in combined volume: {folder_name}")
    expected_volume_codes = {
        code for code, (title, _) in MAPPING.items()
        if any(title == chapter.get("title") for chapter in chapters)
    }
    if candidate_standard_codes != expected_volume_codes:
        raise RuntimeError(f"Candidate standard mapping mismatch in combined volume: {folder_name}")
    volume_label = "수학(상)" if folder_name.startswith("수학상") else "수학(하)"
    book = {
        "title": f"{volume_label} 2015 개정 · 태그별 분권 통합 초안",
        "subtitle": "단원별 챕터와 소단원 페이지를 묶은 부분 원고",
        "category": "concept_textbook",
        "tags": sorted(tags),
        "curriculum_version": "2015",
        "standard_codes": sorted(standard_codes),
        "candidate_standard_codes": sorted(candidate_standard_codes),
        "units": unit_records,
        "chapters": chapters,
        "metadata": {
            "status": "authored_partial_draft",
            "edition_status": "editorial_split_candidate",
            "standard_code_status": "partial_candidate_links_pending_teacher_review",
            "publication_eligibility": "not_eligible",
            "rights_status": "pending",
            "teacher_review_status": "pending",
            "math_review_status": "author_checks_recorded_independent_review_pending",
            "chapter_count": len(chapters),
            "page_count": page_count,
        },
    }
    filename = f"{volume_label}_2015개정_태그분권_통합BookData_초안.json"
    target = output_dir / filename
    target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    verified = json.loads(target.read_text(encoding="utf-8"))
    if len(verified["chapters"]) != len(chapters) or sum(len(c["pages"]) for c in verified["chapters"]) != page_count:
        raise RuntimeError(f"Combined volume round-trip check failed: {folder_name}")

    readme_path = output_dir / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    link_line = f"- [{filename}]({filename}): {len(unit_records)}개 단원, {len(chapters)}개 소단원, {page_count}쪽 통합본"
    if filename not in readme:
        readme += "\n## 단원별 통합 BookData\n\n" + link_line + "\n- 각 chapter에 단원명(unitTitle)을 기록했고 원본 소단원 JSON은 별도 보존했습니다.\n- 공식 기준 대조·교사 검수는 미완료입니다.\n"
    readme_path.write_text(readme.rstrip() + "\n", encoding="utf-8")
    print(f"Combined {volume_label}: {len(unit_records)} units, {len(chapters)} subunits, {page_count} pages.")


def main() -> None:
    for folder_name, units in VOLUMES.items():
        build_volume(folder_name, units)


if __name__ == "__main__":
    main()
