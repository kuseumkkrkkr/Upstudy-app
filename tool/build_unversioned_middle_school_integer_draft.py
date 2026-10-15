"""Package the middle-school integer sample without guessing its edition."""

from __future__ import annotations

import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
SOURCE = MANUSCRIPTS / "중등수학_정수의덧셈과뺄셈_BookData_시범.json"
OUTPUT = MANUSCRIPTS / "중1수학_판본미확인_태그초안"


def signature(page: dict) -> str:
    return json.dumps({key: page.get(key) for key in ("title", "template", "blocks")}, ensure_ascii=False, sort_keys=True)


def main() -> None:
    book = json.loads(SOURCE.read_text(encoding="utf-8"))
    tags = book.get("tags", [])
    if tags[:3] != ["중1 수학", "수와 연산", "정수"]:
        raise RuntimeError(f"Unexpected source tag path: {tags}")
    chapters = book.get("chapters", [])
    if not chapters:
        raise RuntimeError("No source chapters")
    expected = Counter(signature(page) for chapter in chapters for page in chapter.get("pages", []))
    pages = []
    copied: Counter[str] = Counter()
    ids: set[str] = set()
    for chapter_index, chapter in enumerate(chapters, 1):
        opening = {"title": chapter["title"] + " · 원본 태그", "template": "opening", "blocks": [{"type": "paragraph", "text": " · ".join(tags)}, {"type": "paragraph", "text": "판본 태그가 없어 2015·2022 개정 어느 쪽에도 배정하지 않은 시범 원고입니다."}]}
        for page_index, page in enumerate([opening] + chapter.get("pages", []), 1):
            page["id"] = f"middle-unknown-integers-{chapter_index:02d}-{page_index:03d}"
            if page["id"] in ids:
                raise RuntimeError(f"Duplicate page ID {page['id']}")
            ids.add(page["id"])
            pages.append(page)
            if page_index > 1:
                copied[signature(page)] += 1
    if copied != expected:
        raise RuntimeError("Source page preservation failed")
    result = {"title": "중1 수학 · 정수의 덧셈과 뺄셈 · 판본 미확인 초안", "tags": ["중1 수학", "판본 미확인", "수와 연산", "정수"], "chapters": [{"title": "정수의 덧셈과 뺄셈", "pages": pages, "source_file": SOURCE.name, "source_tags": tags}], "metadata": {"status": "edition_unverified_draft", "source_files": [SOURCE.name]}}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "중1수학_정수의덧셈과뺄셈_판본미확인초안.json"
    (OUTPUT / filename).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    readme = ["# 중1 수학 정수 단원 · 판본 미확인 초안", "", f"태그 경로 `{' · '.join(tags)}`를 보존해 단원 초안으로 패키징했습니다. 원본 지면 {sum(expected.values())}개를 유지했습니다.", "", "## 산출물", "", f"- [{filename}]({filename})", "", "원본에는 개정 판본이 명시되지 않아 2015·2022 상품 어느 쪽에도 배정하지 않았습니다. 공식 범위 대조·교사 검수·앱 통합은 미완료입니다.", "", "재생성: `python tool/build_unversioned_middle_school_integer_draft.py`", ""]
    (OUTPUT / "README.md").write_text("\n".join(readme), encoding="utf-8")
    print(f"Built one edition-unverified unit; preserved {sum(expected.values())} pages; IDs unique.")


if __name__ == "__main__":
    main()
