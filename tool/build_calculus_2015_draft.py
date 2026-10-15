"""Package the existing 2015 Calculus sequence-limit sample by its tags."""

from __future__ import annotations

import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "미적분_2015개정_통합초안"


def signature(page: dict) -> str:
    return json.dumps({key: page.get(key) for key in ("title", "template", "blocks")}, ensure_ascii=False, sort_keys=True)


def main() -> None:
    path = MANUSCRIPTS / "미적분_2015개정_수열의극한_BookData_시범.json"
    source = json.loads(path.read_text(encoding="utf-8"))
    tags = source.get("tags", [])
    if tags[:3] != ["미적분", "2015 개정", "수열의 극한"]:
        raise RuntimeError(f"Unexpected source tags: {tags}")
    original_pages = [page for chapter in source.get("chapters", []) for page in chapter.get("pages", [])]
    if not original_pages:
        raise RuntimeError("No source pages")
    opening = {"title": "수열의 극한 · 원본 태그", "template": "opening", "blocks": [{"type": "paragraph", "text": " · ".join(tags)}, {"type": "paragraph", "text": "기존 미적분 2015 개정 시범 원고 지면을 이어서 학습합니다."}]}
    pages = [opening] + original_pages
    for index, page in enumerate(pages, 1):
        page["id"] = f"calculus15-sequence-limit-{index:03d}"
    product = {"title": "미적분 2015 개정 · 수열의 극한 부분 초안", "tags": ["미적분", "2015 개정", "수열의 극한", "부분 초안"], "chapters": [{"title": "수열의 극한", "pages": pages, "source_file": path.name, "source_tags": tags}], "metadata": {"status": "partial_draft", "source_files": [path.name]}}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    filename = "미적분_2015개정_수열의극한_부분통합초안.json"
    (OUTPUT / filename).write_text(json.dumps(product, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    expected = Counter(signature(page) for page in original_pages)
    actual = Counter(signature(page) for page in pages[1:])
    if expected != actual or len({page["id"] for page in pages}) != len(pages):
        raise RuntimeError("Source page or ID check failed")
    readme = ["# 미적분 2015 개정 부분 통합 초안", "", f"기존 BookData 1개를 태그 경로 `{' · '.join(tags)}`에 따라 한 단원 초안으로 만들었습니다. 원본 지면 {len(original_pages)}개를 보존했습니다.", "", "## 결과", "", f"- [{filename}]({filename})", "", "현재 수열의 극한 시범만 포함합니다. 미분·적분을 포함한 과목 전체 범위, 공식 성취기준 대조, 교사 검수, 앱 통합은 미완료입니다.", "", "재생성: `python tool/build_calculus_2015_draft.py`", ""]
    (OUTPUT / "README.md").write_text("\n".join(readme), encoding="utf-8")
    print(f"Built one tagged unit; preserved {len(original_pages)} pages; IDs unique.")


if __name__ == "__main__":
    main()
