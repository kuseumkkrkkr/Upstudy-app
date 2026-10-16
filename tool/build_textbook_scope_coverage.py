"""Build a conservative code-to-content coverage ledger for the textbook catalog."""
from __future__ import annotations

import json
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
SOURCES = ROOT / "work/official-curriculum"
OUT = MANUSCRIPTS / "REMAINING_TEXTBOOKS_CONTENT_COVERAGE.md"

# Catalog number -> official source, prefix, and the boundary that remains unapproved.
PRODUCTS = {
    **{n: ("2015_appendix8_math.txt", "9수", "학년군 코드; 학기 배정 미확인") for n in range(1, 7)},
    **{n: ("2022_appendix8_math.txt", "9수", "학년군 코드; 학기 배정 미확인") for n in range(7, 13)},
    13: ("2015_appendix8_math.txt", "10수학", "상권 분권 경계 미승인"),
    14: ("2015_appendix8_math.txt", "10수학", "하권 분권 경계 미승인"),
    15: ("2015_appendix8_math.txt", "12수학Ⅰ", "과목 연결; 상품 범위 대조 필요"),
    16: ("2015_appendix8_math.txt", "12수학Ⅱ", "과목 연결; 상품 범위 대조 필요"),
    17: ("2015_appendix8_math.txt", "12확통", "과목 연결; 상품 범위 대조 필요"),
    18: ("2015_appendix8_math.txt", "12미적", "과목 연결; 상품 범위 대조 필요"),
    19: ("2015_appendix8_math.txt", "12기하", "과목 연결; 상품 범위 대조 필요"),
    20: ("2022_appendix8_math.txt", "10공수1", "과목 연결; 상품 범위 대조 필요"),
    21: ("2022_appendix8_math.txt", "10공수2", "과목 연결; 상품 범위 대조 필요"),
    22: ("2022_appendix8_math.txt", "12대수", "과목 연결; 상품 범위 대조 필요"),
    23: ("2022_appendix8_math.txt", "12미적Ⅰ", "과목 연결; 상품 범위 대조 필요"),
    24: ("2022_appendix8_math.txt", "12확통", "과목 연결; 상품 범위 대조 필요"),
    25: ("2022_appendix8_math.txt", "12미적Ⅱ", "과목 연결; 상품 범위 대조 필요"),
    26: ("2022_appendix8_math.txt", "12기하", "과목 연결; 상품 범위 대조 필요"),
}


def read_catalog() -> dict[int, str]:
    path = MANUSCRIPTS / "개념서_체험콘텐츠_제작규격.md"
    result: dict[int, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"\|\s*(\d+)\s*\|\s*([^|]+)\|\s*([^|]+)", line)
        if match and int(match.group(1)) in PRODUCTS:
            # Catalog table columns are number, curriculum edition, product name, ...
            result[int(match.group(1))] = match.group(3).strip()
    if set(result) != set(PRODUCTS):
        raise RuntimeError(f"Catalog row mismatch: {sorted(result)}")
    return result


def main() -> None:
    catalog = read_catalog()
    standards: dict[str, dict[str, str]] = {}
    for filename in {source for source, _, _ in PRODUCTS.values()}:
        text = (SOURCES / filename).read_text(encoding="utf-8")
        standards[filename] = {
            match.group(1): re.sub(r"\s+", " ", match.group(2)).strip()
            for match in re.finditer(r"\[([^\]\s]+-\d{2})\]\s*([^\r\n]*)", text)
        }

    tagged: dict[str, list[str]] = defaultdict(list)
    untagged_by_prefix: dict[str, list[str]] = defaultdict(list)
    bookdata_files = sorted(MANUSCRIPTS.glob("*BookData*.json"))
    for path in bookdata_files:
        data = json.loads(path.read_text(encoding="utf-8"))
        raw = data.get("standard_codes", [])
        codes = raw if isinstance(raw, list) else [raw]
        if data.get("standard_code"):
            codes.append(data["standard_code"])
        codes = [str(code).strip() for code in codes if str(code).strip()]
        if not codes:
            untagged_by_prefix[str(data.get("curriculum_version") or "판본 미기록")].append(path.name)
        for code in codes:
            tagged[code].append(path.name)

    lines = [
        "# 26종 교재 성취기준·콘텐츠 적용 범위 원장",
        "",
        "목적: 현재 공식 텍스트 추출물의 기준 코드와 BookData에 명시된 `standard_code(s)`를 대조해 적용 근거와 공백을 드러낸다. 이 표는 수학적 충족 판정이나 교사 승인이 아니다.",
        "",
        "## 해석 규칙",
        "",
        "- `직접 태그 있음`은 BookData 필드에 같은 코드가 적혀 있다는 뜻뿐이다. 본문 설명·예제·연습·정답이 기준을 충족하는지 검토하지 않았다.",
        "- `명시 매핑 없음`은 해당 코드가 태그된 BookData를 현재 찾지 못했다는 뜻이다. 원고 내용이 없다는 확정 판정은 아니다.",
        "- 2022 HWP 텍스트 변환에서 표 전체 복구 여부가 검증되지 않았다. 2022 기준은 관측 코드 목록으로 표시하며, 누락 코드를 완전한 미작성 범위로 간주하지 않는다.",
        "- 중학교 학년군 기준은 학기별로 배분하지 않는다. 2015 수학(상)/(하) 분권도 공식 경계가 아니므로 각 기준을 양쪽 상품에 동시에 완료 처리하지 않는다.",
        "- 원고에 실제로 붙일 기준 코드와 학기 근거가 확인되기 전에는 `미확인`으로 둔다.",
        "",
        "## 상품별 집계",
        "",
        "| # | 상품 | 코드 원문 | 관측 코드 | BookData 직접 태그가 있는 코드 | 직접 태그 없는 코드 | 범위 상태 |",
        "|---:|---|---|---:|---:|---:|---|",
    ]
    per_product: dict[int, list[tuple[str, str]]] = {}
    for number, (filename, prefix, boundary) in PRODUCTS.items():
        codes = sorted(code for code in standards[filename] if code.startswith(prefix))
        if not codes:
            raise RuntimeError(f"No observed codes for #{number} prefix {prefix}")
        matched = sum(bool(tagged.get(code)) for code in codes)
        missing = len(codes) - matched
        per_product[number] = [(code, standards[filename][code]) for code in codes]
        lines.append(
            f"| {number} | {catalog[number]} | `{filename}` / `{prefix}` | {len(codes)} | {matched} | {missing} | 미완 · {boundary} |"
        )

    lines += ["", "## 코드별 연결 근거", ""]
    for number, (filename, prefix, boundary) in PRODUCTS.items():
        lines += [f"### {number}. {catalog[number]}", "", f"원문: `{filename}`, prefix `{prefix}`. {boundary}.", "",
                  "| 기준 코드 | 원문 발췌 | BookData 근거 | 상태 |", "|---|---|---|---|"]
        for code, description in per_product[number]:
            sources = tagged.get(code, [])
            evidence = ", ".join(f"`{name}`" for name in sources) if sources else "—"
            status = "직접 태그 있음 · 내용 검수 필요" if sources else "명시 매핑 없음 · 원고 검색/작성 필요"
            excerpt = description.replace("|", "\\|")[:180]
            lines.append(f"| `{code}` | {excerpt} | {evidence} | {status} |")
        lines.append("")

    recursive_bookdata = sorted(MANUSCRIPTS.rglob("*BookData*.json"))
    v2_files: list[str] = []
    activity_kinds: dict[str, int] = defaultdict(int)
    for path in recursive_bookdata:
        data = json.loads(path.read_text(encoding="utf-8"))
        if data.get("schema_version") == 2:
            v2_files.append(str(path.relative_to(MANUSCRIPTS)))

        def count_activities(value: object) -> None:
            if isinstance(value, dict):
                activity = value.get("activity")
                if value.get("type") == "activity" and isinstance(activity, dict):
                    activity_kinds[str(activity.get("kind", "unknown"))] += 1
                for child in value.values():
                    count_activities(child)
            elif isinstance(value, list):
                for child in value:
                    count_activities(child)

        count_activities(data)
    html_files = sorted(MANUSCRIPTS.rglob("*.html"))
    kind_summary = ", ".join(f"`{kind}` {count}" for kind, count in sorted(activity_kinds.items())) or "없음"

    lines += [
        "## 앱 인터랙션 호환성 인벤토리",
        "",
        f"현재 재귀 인벤토리: BookData `{len(recursive_bookdata)}`개(그중 V2 `{len(v2_files)}`개), 선언형 activity `{sum(activity_kinds.values())}`개({kind_summary}), 독립 HTML `{len(html_files)}`개.",
        "",
        "실제 앱 계약은 guarded `Upstudy-hotfix`의 `deploy/vercel/BOOK_ACTIVITY_V2.md`에서 확인했다(HEAD `7b36e0ed0b42793caff251f422601022cf2b6769`). V2 activity block은 등록된 `quiz`, `steps`, `parabolaDistance`만 지원한다. 현재 원고 인벤토리의 V2 activity는 모두 `quiz`다.",
        "독립 HTML/JavaScript 자산은 V2 activity로 임베드되거나 자동 실행되지 않는다. HTML 자산과 BookData 연결별 화면·기능 패리티는 미검수다. 일반 드래그 도형, 확률 시뮬레이션, 범용 애니메이션, 자유서술 의미 채점은 현재 등록 activity 계약 밖이며, 지원되는 것처럼 평탄화하지 않는다.",
        "V2는 저장·검증 가능한 데이터 계약이지 배포 승인이 아니다. 실제 서버 저장, 페이지별 UI 패리티, 교사 검수, 권리 승인 단계는 별도로 남아 있다.",
        "",
        "## 확인된 매핑 한계",
        "",
        "기존 대수 초안의 `[12대수03-02]` 후보는 현재 HWP 텍스트 추출에서 발견되지 않았다. 표 누락 가능성 때문에 공식 코드가 아니라고 단정하지 않으며, 원문 표 확인 전까지 미검증 태그로 남긴다.",
        "",
        f"현재 검색 대상은 `{len(bookdata_files)}`개 원본 BookData JSON이다. 그중 기준 코드 태그가 하나 이상 있는 파일은 `{sum(1 for p in bookdata_files if (json.loads(p.read_text(encoding='utf-8')).get('standard_codes') or json.loads(p.read_text(encoding='utf-8')).get('standard_code')))}`개다.",
        "태그되지 않은 원고도 파일명과 태그로 판본·학기·상품에 자동 귀속하지 않았다. 해당 내용은 별도 편집자 매핑 후 이 원장을 갱신해야 한다.",
        "",
        "자동 생성 표시는 증거 인벤토리이며 완성도·정답 정확성·저작권 승인 판정은 아니다.",
        "",
        "재생성: `python tool/build_textbook_scope_coverage.py` (공식 추출물과 원본 BookData 필요)",
        "",
    ]
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote scope ledger for {len(PRODUCTS)} products, {sum(map(len, per_product.values()))} observed code rows, and {len(bookdata_files)} BookData sources.")


if __name__ == "__main__":
    main()
