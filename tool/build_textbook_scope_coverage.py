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


def edition_from_bookdata(data: dict) -> str:
    """Use explicit version metadata or an explicit edition tag; never infer from filename."""
    value = str(data.get("curriculum_version") or "").strip()
    tags = data.get("tags", [])
    tags = [str(tag).strip() for tag in tags] if isinstance(tags, list) else []
    tagged_editions = {
        year for year in ("2015", "2022")
        if any(re.fullmatch(rf"{year} 개정(?: 후보)?", tag) for tag in tags)
    }
    if value in {"2015", "2022"}:
        return value if not tagged_editions or tagged_editions == {value} else "edition-conflict"
    if len(tagged_editions) == 1:
        return next(iter(tagged_editions))
    return "edition-unverified" if not tagged_editions else "edition-conflict"


def exact_codes_from_tags(tags: object, valid_codes: set[str]) -> list[str]:
    if not isinstance(tags, list):
        return []
    found: set[str] = set()
    for tag in tags:
        text = str(tag)
        for code in valid_codes:
            if re.search(rf"(?<![\w]){re.escape(code)}(?![\w-])", text):
                found.add(code)
    return sorted(found)


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
    recovered_eqedit_scripts = {
        row["code"]: row["equation_scripts"]
        for row in json.loads((SOURCES / "2022_math_standards.json").read_text(encoding="utf-8"))["standards"]
        if row.get("equation_scripts")
    }

    tagged: dict[str, list[tuple[str, str]]] = defaultdict(list)
    chapter_signals: dict[tuple[str, str], dict[str, object]] = {}
    explicit_chapter_anchors: set[tuple[str, str]] = set()
    single_code_chapter_anchors: set[tuple[str, str]] = set()
    module_alignment: dict[str, str] = {}
    untagged_by_prefix: dict[str, list[str]] = defaultdict(list)
    source_bookdata_files = sorted(MANUSCRIPTS.glob("*BookData*.json"))
    candidate_bookdata_files = sorted(MANUSCRIPTS.rglob("*BookData*.json"))
    for manifest_path in MANUSCRIPTS.rglob("REVIEW_MANIFEST.json"):
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        module_alignment.update(manifest.get("preliminary_module_alignment", {}))
    valid_codes = {code for source in standards.values() for code in source}
    code_tagged_files: set[str] = set()
    for path in candidate_bookdata_files:
        data = json.loads(path.read_text(encoding="utf-8"))
        relative_path = path.relative_to(MANUSCRIPTS).as_posix()
        raw = data.get("standard_codes", [])
        codes = raw if isinstance(raw, list) else [raw]
        if data.get("standard_code"):
            codes.append(data["standard_code"])
        codes += exact_codes_from_tags(data.get("tags", []), valid_codes)
        codes = sorted({str(code).strip() for code in codes if str(code).strip()})
        if codes:
            code_tagged_files.add(relative_path)
        if not codes:
            untagged_by_prefix[str(data.get("curriculum_version") or "판본 미기록")].append(relative_path)
        edition = edition_from_bookdata(data)
        chapters = data.get("chapters", [])
        for code in codes:
            tagged[code].append((relative_path, edition))
            key = (edition, code)
            signal = chapter_signals.setdefault(key, {"files": set(), "chapters": 0, "pages": 0, "blocks": set()})
            matched_chapters = []
            for chapter in chapters if isinstance(chapters, list) else []:
                chapter_text = json.dumps(chapter, ensure_ascii=False)
                if not re.search(rf"(?<![\w-]){re.escape(code)}(?![\w-])", chapter_text):
                    continue
                matched_chapters.append(chapter)
            # A one-code, one-chapter BookData has an unambiguous module link even
            # when the legacy chapter prose omitted the code token itself.
            if not matched_chapters and len(codes) == 1 and isinstance(chapters, list) and len(chapters) == 1:
                matched_chapters = chapters
                single_code_chapter_anchors.add(key)
            elif matched_chapters:
                explicit_chapter_anchors.add(key)
            for chapter in matched_chapters:
                signal["files"].add(relative_path)
                signal["chapters"] += 1
                pages = chapter.get("pages", [])
                signal["pages"] += len(pages) if isinstance(pages, list) else 0
                if isinstance(pages, list):
                    for page in pages:
                        for block in page.get("blocks", []) if isinstance(page, dict) else []:
                            if isinstance(block, dict):
                                signal["blocks"].add(str(block.get("type", "unknown")))
                                activity = block.get("activity")
                                if isinstance(activity, dict):
                                    signal["blocks"].add(f"activity:{activity.get('kind', 'unknown')}")

    lines = [
        "# 26종 교재 성취기준·콘텐츠 적용 범위 원장",
        "",
        "목적: 2015 PDF 및 2022 HWP 성취기준 본표에서 추출한 공식 코드와 BookData 태그를 대조한다. 태그는 내용 충족의 증거가 아니다.",
        "",
        "## 해석 규칙",
        "",
        "- 재귀 원고 인벤토리의 exact BookData code tag는 매핑 후보 수로만 센다. 태그만으로 설명·예제·연습·해설의 충족을 판정하지 않는다.",
        "- 공식 코드 토큰은 `standard_codes`/`standard_code` 필드와 tags에서 exact match로 찾는다. 판본은 `curriculum_version` 또는 명시적인 판본 태그로만 확인한다.",
        "- 2022 HWP XHTML 본표에서 추출한 코드를 공식 기준 baseline으로 삼는다. 해설 참고 ID는 이 집합과 분리한다.",
        "- `edition-unverified` 태그는 같은 코드 문자열이 보여도 특정 교육과정 판본에 연결하지 않는다.",
        "- 중학교 학년군 기준은 학기별로 배분하지 않는다. 2015 수학(상)/(하) 분권도 공식 경계가 아니므로 각 기준을 양쪽 상품에 동시에 완료 처리하지 않는다.",
        "- 권리·수학·교사 검토와 게시 적격성은 별도 상태다.",
        "",
        "## 상품별 집계",
        "",
        "아래 태그 수는 재귀 원고 인벤토리에서 해당 판본·prefix 코드가 발견된 수다. 중학교 #1–#12는 학년군 후보 전체의 인벤토리 수이며 학기/상품 귀속 수가 아니다. #13–#14는 같은 공식 <수학> 코드 목록을 기준선으로 함께 표시하므로 분권 배정 전까지 두 상품의 완료 수로 해석하지 않는다. 나머지도 상품별 본문 충족은 검수하지 않았다.",
        "",
        "| # | 상품 | 증거 종류 | 공식 기준 항목 | 판본/prefix 태그 인벤토리 코드 수 | 상태 |",
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
        displayed = "분권 미확정" if number in {13, 14} else str(matched)
        lines.append(f"| {number} | {catalog[number]} | {edition} 공식 성취기준 | {len(codes)} | {displayed} | 미완 · {boundary}; 내용 검수 필요 |")

    lines += ["", "## 코드별 연결 근거", ""]
    for number, (filename, prefix, boundary) in PRODUCTS.items():
        edition = "2015" if filename.startswith("2015") else "2022"
        lines += [f"### {number}. {catalog[number]}", "", f"원문: `{filename}`, prefix `{prefix}`. {boundary}.", "",
                  f"| {edition} 기준 코드 | 공식 기준 문구 | same-edition BookData tag | chapter 구조 신호 | 상태 |", "|---|---|---|---|---|"]
        for code, description in per_product[number]:
            sources = [name for name, tag_edition in tagged.get(code, []) if tag_edition == edition]
            evidence = ", ".join(f"`{name}`" for name in sources) if sources else "—"
            signal = chapter_signals.get((edition, code), {})
            chapter_count = int(signal.get("chapters", 0))
            page_count = int(signal.get("pages", 0))
            block_types = sorted(signal.get("blocks", set()))
            chapter_evidence = (
                f"{len(signal.get('files', set()))} files · {chapter_count} chapters · {page_count} pages · "
                + (", ".join(f"`{kind}`" for kind in block_types) or "no typed blocks")
                if chapter_count
                else "no exact-code chapter anchor"
            )
            alignment = module_alignment.get(code)
            if alignment == "pending_first_class_statistics_tool":
                status = "태그 있음 · 전용 공학 도구 상호작용 미구현; 연동 후보"
            elif alignment == "candidate_statistics_estimator_added_runtime_qa_pending":
                status = "태그·statisticsEstimator 후보 있음 · importer/reader QA 대기"
            elif alignment == "candidate_statistics_estimator_qa_passed_pending_teacher_review":
                status = "태그·statisticsEstimator candidate importer/reader QA 통과 · 교사/권리 검토 대기"
            elif alignment == "candidate_partial_general_function_graph_incomplete":
                status = "부분 후보 태그 있음 · 일반 함수 그래프 이해 미완료; 내용 검수 필요"
            elif alignment == "candidate_mapping_review_pending":
                status = "후보 연결 기록 있음 · 교사·내용 검수 필요"
            else:
                status = "tag 있음 · 내용 검수 필요" if sources else "same-edition tag 없음 · 원고 대조 필요"
            equation_scripts = recovered_eqedit_scripts.get(code, [])
            if equation_scripts:
                description += " [복구 EqEdit: " + "; ".join(equation_scripts) + "]"
            excerpt = description.replace("|", "\\|")[:260]
            lines.append(f"| `{code}` | {excerpt} | {evidence} | {chapter_evidence} | {status} |")
        lines.append("")

    official_pairs = {
        ("2015" if filename.startswith("2015") else "2022", code)
        for filename, prefix, _ in PRODUCTS.values()
        for code in standards[filename]
        if code.startswith(prefix)
    }
    tagged_pairs = {
        (edition, code)
        for code, entries in tagged.items()
        for edition in {tag_edition for _, tag_edition in entries}
        if (edition, code) in official_pairs
    }
    linked_pairs = (explicit_chapter_anchors | single_code_chapter_anchors) & official_pairs
    lines += [
        "## 기준-챕터 매핑 신호 감사",
        "",
        f"고유 공식 판본-코드 쌍 `{len(official_pairs)}`개 중 같은 판본 태그가 있는 쌍은 `{len(tagged_pairs)}`개, exact code가 chapter 안에 있는 쌍은 `{len(explicit_chapter_anchors & official_pairs)}`개, 단일 코드·단일 chapter BookData로 연결된 쌍은 `{len(single_code_chapter_anchors & official_pairs)}`개, 어느 구조 신호도 없는 쌍은 `{len(official_pairs - linked_pairs)}`개다.",
        "아래 표는 상품별 미연결 기준 수다. 2015 수학(상)/(하) 행은 같은 코드 집합을 각각 보여 주며 공식 분권 경계가 아니다. chapter 신호는 내용의 정확성·완전성·교사 검수를 뜻하지 않는다.",
        "",
        "| # | 상품 | 기준 수 | chapter 연결 신호 없음 |",
        "|---:|---|---:|---:|",
    ]
    for number, (filename, prefix, _) in PRODUCTS.items():
        edition = "2015" if filename.startswith("2015") else "2022"
        product_codes = [code for code in standards[filename] if code.startswith(prefix)]
        unlinked = sum((edition, code) not in linked_pairs for code in product_codes)
        lines.append(f"| {number} | {catalog[number]} | {len(product_codes)} | {unlinked} |")
    lines.append("")

    lines += [
        "## 2022 원문 수식 추출 한계",
        "",
        "공식 HWP의 `EqEdit` raw record script를 원본 HWP에서 직접 복구해 16개 기준에 별도 인용했다. XHTML은 해당 개체를 typeset 수식으로 렌더링하지 않지만, 원문 script는 코드 행과 `work/official-curriculum/2022_math_standards.json`에 기록되어 있다. script 해석과 교과서 표기는 독립 교과 검토가 필요하다.",
        "",
    ]

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
    publication_gates: dict[str, int] = defaultdict(int)
    rights_gates: dict[str, int] = defaultdict(int)
    teacher_gates: dict[str, int] = defaultdict(int)
    math_gates: dict[str, int] = defaultdict(int)
    for path in sorted(MANUSCRIPTS.rglob("*BookData*.json")):
        try:
            book = json.loads(path.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError):
            publication_gates["invalid_json"] += 1
            continue
        metadata = book.get("metadata", {})
        metadata = metadata if isinstance(metadata, dict) else {}
        publication_gates[str(metadata.get("publication_eligibility", book.get("publication_eligibility", "unspecified")))] += 1
        rights_gates[str(metadata.get("rights_status", metadata.get("rights_review", "unspecified")))] += 1
        teacher_gates[str(metadata.get("teacher_review_status", metadata.get("teacher_review", "unspecified")))] += 1
        math_gates[str(metadata.get("math_review_status", metadata.get("independent_math_review", "unspecified")))] += 1
    def gate_summary(values: dict[str, int]) -> str:
        return ", ".join(f"`{key}` {count}" for key, count in sorted(values.items())) or "없음"

    lines += [
        "## 앱 인터랙션 호환성 인벤토리",
        "",
        f"현재 재귀 인벤토리: BookData `{len(recursive_bookdata)}`개(그중 V2 `{len(v2_files)}`개), 선언형 activity `{sum(activity_kinds.values())}`개({kind_summary}), 독립 HTML `{len(html_files)}`개.",
        "",
        "## 게시·권리·사람 검토 게이트 인벤토리",
        "",
        f"재귀 BookData `{sum(publication_gates.values())}`개 metadata 집계: 게시 적격성 {gate_summary(publication_gates)}; 권리 상태 {gate_summary(rights_gates)}; 교사 검토 {gate_summary(teacher_gates)}; 수학 검토 {gate_summary(math_gates)}.",
        "`unspecified`는 승인이나 미승인을 뜻하지 않고 증거가 없는 상태다. `not_eligible` 및 검수 대기 문서만으로는 출판 승인할 수 없다. 이 집계는 원고 metadata 인벤토리이며 권리 문서·교사 서명·독립 수학검토 산출물을 대체하지 않는다.",
        "",
        "실제 hotfix 앱 계약은 guarded `Upstudy-hotfix`에서 확인했다. 등록 kind는 `quiz`, `steps`, `parabolaDistance`, `discreteExperiment`, `statisticsEstimator`, `vectorOperation`, `vectorInnerProduct`이다. main은 hotfix의 한정된 모델·renderer를 재사용해 `vectorOperation`과 `vectorInnerProduct` kind를 reader에 연결했다. `vectorOperation`은 2015 기하 V2 후보에 벡터 조작 활동과 HTML의 두 Socratic 확인 및 연습 퀴즈를 연결했다. importer 왕복과 BookWidget 조작은 검증했으나 원본 HTML의 모든 시각·시간 동작과 parity는 확인하지 않아 `migration_status=ported_pending_review`다. `vectorInnerProduct`는 별도 V2 후보에서 importer 및 BookWidget 조작을 확인했고 동일하게 교사 수학검수·권리·전체 HTML parity는 pending이다. 두 vector 상품은 출판 eligible이 아니다. opaque payload 왕복은 지원 기능 실행과 구분한다. 이 main 저장소에서는 hotfix 모델·렌더러를 중복 구현하지 않고, `discreteExperiment`는 이산 결과를 네이티브로 반복 추첨해 결과 횟수·누적 상대도수를 보여 주며 학생결과 사전 입력이나 API 저장은 허용하지 않는다.",
        "`statisticsEstimator`는 표본 값 입력으로 평균을 계산하거나 성공 수÷표본 크기로 비율을 계산하고, 결과 해석·수정·초기화·힌트를 제공한다. 상태는 reader-session에 한정된다. `12확통03-07` 후보에는 mean/proportion 두 모드를 넣었다. 전체 BookData importer, Python activity/import 32개, Flutter estimator/V2 reader 9개가 guarded hotfix HEAD에서 통과했으나, 교사 수학검토·권리승인은 남아 있다.",
        "독립 HTML/JavaScript 자산은 V2 activity로 임베드되거나 자동 실행되지 않는다. 이산실험은 native discreteExperiment로 일부 기능을 대응할 수 있으나 원본 HTML과 화면·기능 패리티는 별도 검수 대상이다. 범용 드래그 도형, 범용 애니메이션, 자유서술 의미 채점은 등록 계약 밖이다.",
        "V2는 저장·검증 가능한 데이터 계약이지 배포 승인이 아니다. 실제 서버 저장, 페이지별 UI 패리티, 교사 검수, 권리 승인 단계는 별도로 남아 있다.",
        "",
        "## 확인된 매핑 한계",
        "",
        "2015 고등 수학(상·하) 41개 코드를 원고 chapter 후보별로 대조한 별도 표: [2015_HIGH_SCHOOL_MATH_CONTENT_AUDIT.md](2015_HIGH_SCHOOL_MATH_CONTENT_AUDIT.md). 후보·tag는 내용 검수 완료를 뜻하지 않는다.",
        "",
        "2022 HWP 본표에서 대수 코드를 추출했다. 초안의 코드 연결은 표 기준과 직접 대조해야 하며, code tag만으로 원고 충족을 인정하지 않는다.",
        "",
        f"현재 검색 대상은 원본 BookData `{len(source_bookdata_files)}`개, 재귀 후보·패키지 BookData `{len(candidate_bookdata_files)}`개다. 공식 코드 필드 또는 tags에 정확한 코드 토큰이 있는 재귀 파일은 `{len(code_tagged_files)}`개다.",
        "태그에서 코드를 읽을 때는 공식 코드 전체와 exact token을 대조한다. 판본은 curriculum_version 또는 명시적인 `2015 개정`/`2022 개정` 태그만 인정하며, filename은 판본 근거로 쓰지 않는다. 2022 code tags는 본표 공식 코드와 동일 판본일 때만 집계한다. 기준 태그가 있어도 full content coverage는 별도 검수 대상이다.",
        "",
        "자동 생성 표시는 증거 인벤토리이며 완성도·정답 정확성·저작권 승인 판정은 아니다.",
        "`chapter 구조 신호`는 chapter 텍스트의 exact code를 우선 찾고, 코드 하나만 가진 단일 chapter BookData에는 그 하나의 chapter를 연결해 페이지 수와 block type을 집계한다. 다중 코드 자료에 임의 분배하지 않는다. 이 구조 신호는 원고 충족이나 계산 정확성을 승인하지 않는다.",
        "",
        "재생성: `python tool/build_textbook_scope_coverage.py` (공식 추출물과 원본 BookData 필요)",
        "",
    ]
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote scope ledger for {len(PRODUCTS)} products, {sum(map(len, per_product.values()))} product-standard rows, and {len(source_bookdata_files)} source BookData files.")


if __name__ == "__main__":
    main()
