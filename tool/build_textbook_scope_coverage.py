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
    standards["2022_appendix8_math.txt"] = {
        row["code"]: row["criterion"]
        for row in json.loads((SOURCES / "2022_math_standards.json").read_text(encoding="utf-8"))["standards"]
    }

    tagged: dict[str, list[tuple[str, str]]] = defaultdict(list)
    module_alignment: dict[str, str] = {}
    untagged_by_prefix: dict[str, list[str]] = defaultdict(list)
    source_bookdata_files = sorted(MANUSCRIPTS.glob("*BookData*.json"))
    candidate_bookdata_files = sorted(MANUSCRIPTS.rglob("*BookData*.json"))
    for manifest_path in MANUSCRIPTS.rglob("REVIEW_MANIFEST.json"):
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        module_alignment.update(manifest.get("preliminary_module_alignment", {}))
    for path in candidate_bookdata_files:
        data = json.loads(path.read_text(encoding="utf-8"))
        raw = data.get("standard_codes", [])
        codes = raw if isinstance(raw, list) else [raw]
        if data.get("standard_code"):
            codes.append(data["standard_code"])
        codes = [str(code).strip() for code in codes if str(code).strip()]
        if not codes:
            untagged_by_prefix[str(data.get("curriculum_version") or "판본 미기록")].append(path.name)
        edition = str(data.get("curriculum_version") or "edition-unverified")
        for code in codes:
            tagged[code].append((path.name, edition))

    lines = [
        "# 26종 교재 성취기준·콘텐츠 적용 범위 원장",
        "",
        "목적: 2015 PDF 및 2022 HWP 성취기준 본표에서 추출한 공식 코드와 BookData 태그를 대조한다. 태그는 내용 충족의 증거가 아니다.",
        "",
        "## 해석 규칙",
        "",
        "- 재귀 원고 인벤토리의 exact BookData code tag는 매핑 후보 수로만 센다. 태그만으로 설명·예제·연습·해설의 충족을 판정하지 않는다.",
        "- 2022 HWP XHTML 본표에서 추출한 코드를 공식 기준 baseline으로 삼는다. 해설 참고 ID는 이 집합과 분리한다.",
        "- `edition-unverified` 태그는 같은 코드 문자열이 보여도 특정 교육과정 판본에 연결하지 않는다.",
        "- 중학교 학년군 기준은 학기별로 배분하지 않는다. 2015 수학(상)/(하) 분권도 공식 경계가 아니므로 각 기준을 양쪽 상품에 동시에 완료 처리하지 않는다.",
        "- 권리·수학·교사 검토와 게시 적격성은 별도 상태다.",
        "",
        "## 상품별 집계",
        "",
        "동일 판본 prefix tag 수는 재귀 BookData에서 확인한 고유 기준 코드 수다. 중학교 9수는 학년군 기준이므로 개별 학기·상품에 배분한 수치가 아니다.",
        "",
        "| # | 상품 | 증거 종류 | 공식 기준 항목 | 동일 판본 prefix tag 코드 수 | 상태 |",
        "|---:|---|---|---:|---:|---:|---|",
    ]
    per_product: dict[int, list[tuple[str, str]]] = {}
    for number, (filename, prefix, boundary) in PRODUCTS.items():
        codes = sorted(code for code in standards[filename] if code.startswith(prefix))
        if not codes:
            raise RuntimeError(f"No observed codes for #{number} prefix {prefix}")
        if filename.startswith("2015"):
            per_product[number] = [(code, standards[filename][code]) for code in codes]
            edition = "2015"
        else:
            per_product[number] = [(code, standards[filename][code]) for code in codes]
            edition = "2022"
        matched = sum(any(tag_edition == edition for _, tag_edition in tagged.get(code, [])) for code in codes)
        lines.append(f"| {number} | {catalog[number]} | {edition} 공식 성취기준 | {len(codes)} | {matched} | 미완 · {boundary}; 내용 검수 필요 |")

    lines += ["", "## 코드별 연결 근거", ""]
    for number, (filename, prefix, boundary) in PRODUCTS.items():
        edition = "2015" if filename.startswith("2015") else "2022"
        lines += [f"### {number}. {catalog[number]}", "", f"원문: `{filename}`, prefix `{prefix}`. {boundary}.", "",
                  f"| {edition} 기준 코드 | 공식 기준 문구 | same-edition BookData tag | 상태 |", "|---|---|---|---|"]
        for code, description in per_product[number]:
            sources = [name for name, tag_edition in tagged.get(code, []) if tag_edition == edition]
            evidence = ", ".join(f"`{name}`" for name in sources) if sources else "—"
            if module_alignment.get(code) == "pending_first_class_statistics_tool":
                status = "태그 있음 · 전용 공학 도구 상호작용 미구현; 연동 후보"
            else:
                status = "tag 있음 · 내용 검수 필요" if sources else "same-edition tag 없음 · 원고 대조 필요"
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
        "실제 앱 계약은 guarded `Upstudy-hotfix`의 `api/book_activity.py`와 `deploy/vercel/BOOK_ACTIVITY_V2.md`에서 확인했다. 등록 kind는 `quiz`, `steps`, `parabolaDistance`, `discreteExperiment`다. `discreteExperiment`는 이산 결과를 네이티브로 반복 추첨해 결과 횟수·누적 상대도수를 보여 주며, 학생결과 사전 입력이나 API 저장은 허용하지 않는다.",
        "`12확통03-07`은 공학 도구를 이용한 모평균·모비율 추정 기준이다. 현재 V2 계약에는 표본 값 입력, 평균/성공수÷n 비율 계산, 결과 해석, 편집·초기화·힌트를 제공하는 `statisticsEstimator` first-class kind가 없다. 해당 모듈은 연동 후보로 보류하며, 앱 스키마와 화면 계약이 추가되기 전에는 완료로 세지 않는다.",
        "독립 HTML/JavaScript 자산은 V2 activity로 임베드되거나 자동 실행되지 않는다. 이산실험은 native discreteExperiment로 일부 기능을 대응할 수 있으나 원본 HTML과 화면·기능 패리티는 별도 검수 대상이다. 범용 드래그 도형, 범용 애니메이션, 자유서술 의미 채점은 등록 계약 밖이다.",
        "V2는 저장·검증 가능한 데이터 계약이지 배포 승인이 아니다. 실제 서버 저장, 페이지별 UI 패리티, 교사 검수, 권리 승인 단계는 별도로 남아 있다.",
        "",
        "## 확인된 매핑 한계",
        "",
        "2022 HWP 본표에서 대수 코드를 추출했다. 초안의 코드 연결은 표 기준과 직접 대조해야 하며, code tag만으로 원고 충족을 인정하지 않는다.",
        "",
        f"현재 검색 대상은 원본 BookData `{len(source_bookdata_files)}`개, 재귀 후보·패키지 BookData `{len(candidate_bookdata_files)}`개다. 기준 code tag가 있는 재귀 파일은 `{sum(1 for p in candidate_bookdata_files if (json.loads(p.read_text(encoding='utf-8')).get('standard_codes') or json.loads(p.read_text(encoding='utf-8')).get('standard_code')))}`개다.",
        "태그되지 않은 원고도 파일명으로 판본·학기·상품에 자동 귀속하지 않았다. 2022 code tags는 본표 공식 코드와 동일 판본일 때만 집계했다. 기준 태그가 있어도 full content coverage는 별도 검수 대상이다.",
        "",
        "자동 생성 표시는 증거 인벤토리이며 완성도·정답 정확성·저작권 승인 판정은 아니다.",
        "",
        "재생성: `python tool/build_textbook_scope_coverage.py` (공식 추출물과 원본 BookData 필요)",
        "",
    ]
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote scope ledger for {len(PRODUCTS)} products, {sum(map(len, per_product.values()))} product-standard rows, and {len(source_bookdata_files)} source BookData files.")


if __name__ == "__main__":
    main()
