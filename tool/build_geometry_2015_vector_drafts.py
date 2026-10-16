"""Split 2015 Geometry vector samples by their existing unit tags."""

from __future__ import annotations

import json
import re
from collections import Counter, OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "기하_2015개정_벡터통합초안"
EXCLUDED = "고등수학_기하_2015개정_개념서_시범_BookData.json"
TAG_RE = re.compile(r"원문 대조 완료|교사 검수 전|부분 시범|개념서 시범|2015 개정")


def signature(page: dict) -> str:
    return json.dumps({key: page.get(key) for key in ("title", "template", "blocks")}, ensure_ascii=False, sort_keys=True)


def main() -> None:
    groups: OrderedDict[str, list[dict]] = OrderedDict()
    expected: Counter[str] = Counter()
    master_path = MANUSCRIPTS / EXCLUDED
    master = json.loads(master_path.read_text(encoding="utf-8"))
    master_tags = master.get("tags", [])
    if master_tags[:3] != ["기하", "2015 개정", "평면벡터"]:
        raise RuntimeError(f"Unexpected master-book tags: {master_tags}")
    for chapter in master.get("chapters", []):
        pages = chapter.get("pages", [])
        if not pages:
            raise RuntimeError(f"No pages in master chapter {chapter.get('title')}")
        for page in pages:
            expected[signature(page)] += 1
        groups.setdefault("평면벡터", []).append({"file": master_path.name, "book": master, "pages": pages, "tags": master_tags, "subunit": chapter["title"], "codes": master.get("standard_codes", [])})

    for path in sorted(MANUSCRIPTS.glob("고등수학_기하*_BookData*.json")):
        if path.name == EXCLUDED:
            continue
        book = json.loads(path.read_text(encoding="utf-8"))
        tags = book.get("tags", [])
        if len(tags) < 4 or tags[:2] != ["기하", "2015 개정"]:
            continue
        unit = tags[2]
        subunit = tags[3]
        if TAG_RE.fullmatch(unit) or TAG_RE.fullmatch(subunit):
            raise RuntimeError(f"Metadata tag used as curriculum node in {path.name}")
        pages = [page for chapter in book.get("chapters", []) for page in chapter.get("pages", [])]
        if not pages:
            raise RuntimeError(f"No pages in {path.name}")
        for page in pages:
            expected[signature(page)] += 1
        groups.setdefault(unit, []).append({"file": path.name, "book": book, "pages": pages, "tags": tags, "subunit": subunit, "codes": book.get("standard_codes", [])})
    batch_path = MANUSCRIPTS / "기하_2015개정_이차곡선공간도형_Batch1_BookData_V2_시범.json"
    if batch_path.exists():
        batch = json.loads(batch_path.read_text(encoding="utf-8"))
        for chapter in batch.get("chapters", []):
            unit = chapter.get("unit_name")
            if unit not in {"이차곡선", "평면벡터", "공간도형"}:
                raise RuntimeError(f"Unknown 2015 Geometry unit in {chapter.get('title')}: {unit}")
            pages = chapter.get("pages", [])
            if not pages:
                raise RuntimeError(f"No candidate pages in {chapter.get('title')}")
            for page in pages:
                expected[signature(page)] += 1
            groups.setdefault(unit, []).append({"file": batch_path.name, "book": batch, "pages": pages, "tags": batch.get("tags", []), "subunit": chapter["title"], "codes": ["12기하" + chapter["title_code"]]})
    if not groups:
        raise RuntimeError("No 2015 Geometry vector samples found")

    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    actual: Counter[str] = Counter()
    ids: set[str] = set()
    for unit, modules in groups.items():
        chapters = []
        for module_index, module in enumerate(modules, 1):
            title = module.get("subunit") or " / ".join(ch.get("title", "") for ch in module["book"]["chapters"])
            opening = {
                "title": title + " · 태그 경로",
                "template": "opening",
                "blocks": [{"type": "paragraph", "text": " · ".join(module["tags"])}, {"type": "paragraph", "text": "기존 시범 BookData의 원고 지면을 이어서 학습합니다."}],
            }
            pages = [opening] + module["pages"]
            for page_index, page in enumerate(pages, 1):
                page["id"] = f"geo15-{len(manifest)+1:02d}-{module_index:02d}-{page_index:03d}"
                if page["id"] in ids:
                    raise RuntimeError(f"Duplicate ID {page['id']}")
                ids.add(page["id"])
                if page_index > 1:
                    actual[signature(page)] += 1
            chapters.append({"title": module["subunit"], "pages": pages, "source_file": module["file"], "source_tags": module["tags"], "candidate_standard_codes": module.get("codes", [])})
        data = {"title": f"기하 2015 개정 · {unit} 태그별 통합 초안", "tags": ["기하", "2015 개정", unit, "태그 기반 초안"], "chapters": chapters, "metadata": {"status": "partial_draft", "source_files": [item["file"] for item in modules]}}
        filename = f"기하_2015개정_{unit}_통합초안.json"
        (OUTPUT / filename).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        manifest.append((filename, unit, modules))
    if actual != expected:
        raise RuntimeError("Original page content comparison failed")

    unique_source_count = len({module["file"] for _, _, modules in manifest for module in modules})
    lines = ["# 기하 2015 개정 벡터 태그별 통합 초안", "", f"기존 BookData 원본 {unique_source_count}개(통합 시범의 3개 핵심 장과 별도 시범 3개)를 원본 단원 태그별로 배치했습니다. 원본 지면 {sum(expected.values())}개를 보존했습니다.", "", "## 단원", ""]
    for filename, unit, modules in manifest:
        lines.append(f"- [{unit} 통합 초안]({filename})")
        for module in modules:
            title = module.get("subunit") or " / ".join(ch.get("title", "") for ch in module["book"]["chapters"])
            lines.append(f"  - {module['subunit']}: {title} (`{module['file']}`)")
    lines += ["", "기존 벡터 6모듈/18쪽과 신규 V2 12모듈/60쪽을 합쳐 18모듈/78개 원본 지면을 보존했습니다. 편집용으로 모듈마다 출처 표지 1쪽이 추가됩니다. 신규 quiz는 네이티브 BookData activity 후보입니다. 기존 HTML 5개는 별도 파일로 보존되며 앱에서 자동 실행되지 않고 화면 parity도 검증하지 않았습니다. 전체 교재 검수·권리 결정 전 출판 부적격입니다.", "", "재생성: `python tool/build_geometry_2015_vector_drafts.py`", ""]
    (OUTPUT / "README.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"Built {sum(len(row[2]) for row in manifest)} modules in {len(manifest)} tagged units; preserved {sum(expected.values())} pages; IDs unique.")


if __name__ == "__main__":
    main()
