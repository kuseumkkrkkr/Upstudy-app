"""Group existing 2015 middle-school BookData samples by standard-code domain."""

from __future__ import annotations

import json
import re
from collections import Counter, OrderedDict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "중학교수학_2015개정_영역별통합초안"
CODE_RE = re.compile(r"9수\d{2}-\d{2}")
DOMAINS = OrderedDict(
    [
        ("01", "수와 연산"),
        ("02", "문자와 식"),
        ("03", "함수"),
    ]
)


def page_signature(page: dict) -> str:
    return json.dumps(
        {key: page.get(key) for key in ("title", "template", "blocks")},
        ensure_ascii=False,
        sort_keys=True,
    )


def page_id(prefix: str, pages: list[dict]) -> None:
    for index, page in enumerate(pages, 1):
        page["id"] = f"{prefix}-{index:03d}"


def main() -> None:
    source_files = sorted(MANUSCRIPTS.glob("중학교수학_2015개정*_BookData_시범.json"))
    grouped: dict[str, list[dict]] = {key: [] for key in DOMAINS}
    expected: Counter[str] = Counter()
    for path in source_files:
        book = json.loads(path.read_text(encoding="utf-8"))
        codes = sorted(set(CODE_RE.findall(" ".join(book.get("tags", [])))))
        if len(codes) != 1:
            continue
        domain = codes[0][2:4]
        if domain not in grouped:
            continue
        chapters = book.get("chapters", [])
        if not chapters:
            continue
        pages = [p for ch in chapters for p in ch.get("pages", [])]
        if not pages:
            continue
        for page in pages:
            expected[page_signature(page)] += 1
        grouped[domain].append({"file": path.name, "book": book, "pages": pages, "codes": CODE_RE.findall(" ".join(book.get("tags", [])))})

    OUTPUT.mkdir(parents=True, exist_ok=True)
    products = []
    total_pages = 0
    for domain, domain_name in DOMAINS.items():
        modules = grouped[domain]
        if not modules:
            continue
        chapters = []
        used_codes = set()
        for item in modules:
            source = item["book"]
            codes = sorted(set(CODE_RE.findall(" ".join(source.get("tags", [])))))
            used_codes.update(codes)
            original_title = " / ".join(ch.get("title", "") for ch in source["chapters"])
            intro = {
                "title": f"{original_title} · 성취기준 후보와 원본 태그",
                "template": "concept",
                "blocks": [
                    {"type": "paragraph", "text": f"원본 태그: {' · '.join(source.get('tags', []))}"},
                    {"type": "paragraph", "text": f"성취기준 코드 후보: {', '.join(codes)}. 이 코드는 원본 태그에서 추출했으며 공식 판본 대조가 완료된 표기가 아닙니다."},
                ],
            }
            pages = [intro] + item["pages"]
            page_id(f"ms15-{domain}-{len(chapters)+1:03d}", pages)
            chapters.append({"title": original_title, "pages": pages, "source_file": item["file"]})
        book = {
            "title": f"중학교 수학 2015 개정 · {domain_name} 통합 초안",
            "tags": ["중학교 수학", "2015 개정", domain_name, "자동 통합 초안"],
            "chapters": chapters,
            "metadata": {"source_files": [item["file"] for item in modules], "candidate_standard_codes": sorted(used_codes), "status": "draft_grouped_from_existing_bookdata"},
        }
        target = OUTPUT / f"중학교수학_2015개정_{domain}_{domain_name}_통합초안.json"
        target.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        products.append({"file": target.name, "domain": domain_name, "modules": len(modules), "original_pages": sum(len(i["pages"]) for i in modules), "codes": sorted(used_codes), "sources": [i["file"] for i in modules]})
        total_pages += sum(len(i["pages"]) for i in modules)

    actual: Counter[str] = Counter()
    ids: list[str] = []
    for product in products:
        book = json.loads((OUTPUT / product["file"]).read_text(encoding="utf-8"))
        for chapter in book["chapters"]:
            for page in chapter["pages"]:
                ids.append(page["id"])
                if " · 성취기준 후보와 원본 태그" not in page["title"]:
                    actual[page_signature(page)] += 1
    if actual != expected or len(ids) != len(set(ids)):
        raise RuntimeError("Generated page preservation or unique-ID check failed")

    lines = ["# 중학교 수학 2015 개정 영역별 통합 초안", "", f"기존 시범 BookData {sum(p['modules'] for p in products)}개에서 성취기준 코드 태그가 정확히 하나인 모듈을 대영역별로 묶었습니다. 원본 페이지 {total_pages}개는 제목·템플릿·블록을 보존했습니다.", "", "## 생성 결과", ""]
    for product in products:
        lines.append(f"- [{product['domain']} 통합 초안]({product['file']}): 소단원 시범 {product['modules']}개, 기존 지면 {product['original_pages']}개, 코드 후보 {', '.join(product['codes'])}")
    lines += ["", "자동 추출 대상이 아닌 통계·기하 시범은 이번 영역 초안에서 제외했습니다. 성취기준 코드는 후보 태그이며, 2015 개정 원문·학년별 배열·교사 검수와 앱 통합을 완료한 결과가 아닙니다.", "", "재생성: `python tool/build_middle_school_2015_domain_drafts.py`", ""]
    (OUTPUT / "README.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"Built {len(products)} domain drafts from {sum(p['modules'] for p in products)} modules; preserved {total_pages} pages; unique IDs verified.")


if __name__ == "__main__":
    main()
