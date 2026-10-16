"""Build a conservative evidence map for the 2015 high-school Math draft."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
SOURCES = ROOT / "work/official-curriculum"
OUT = MANUSCRIPTS / "2015_HIGH_SCHOOL_MATH_CONTENT_AUDIT.md"

# Candidate topic mapping based on the original BookData chapter title and its
# authored prose. Status describes the evidence strength, never completion.
MAPPING: dict[str, tuple[str | None, str]] = {
    "10수학01-01": ("다항식의 덧셈과 뺄셈", "title candidate"),
    "10수학01-02": ("항등식의 성질과 계수 비교", "new V2 candidate pending review"),
    "10수학01-03": ("나머지정리와 인수정리", "title candidate"),
    "10수학01-04": ("다항식의 인수분해", "title candidate"),
    "10수학01-05": ("복소수의 뜻과 연산", "title candidate"),
    "10수학01-06": ("복소수 범위의 이차방정식", "title candidate"),
    "10수학01-07": ("복소수 범위의 이차방정식", "title candidate"),
    "10수학01-08": ("이차방정식의 근과 계수의 관계", "title candidate"),
    "10수학01-09": ("이차함수 그래프와 이차방정식의 실근", "title candidate"),
    "10수학01-10": ("이차함수 그래프와 이차방정식의 실근", "partial topic candidate"),
    "10수학01-11": ("이차함수 그래프와 이차방정식의 실근", "partial topic candidate"),
    "10수학01-12": ("인수분해를 이용한 삼차방정식", "partial: quartic not evidenced"),
    "10수학01-13": ("대입법으로 푸는 연립이차방정식", "title candidate"),
    "10수학01-14": ("연립일차부등식과 공통 해", "title candidate"),
    "10수학01-15": ("절댓값을 포함한 일차부등식", "new V2 candidate pending review"),
    "10수학01-16": ("이차부등식의 해", "partial topic candidate"),
    "10수학02-01": ("두 점 사이의 거리와 선분의 중점", "title candidate"),
    "10수학02-02": ("두 점 사이의 거리와 선분의 중점", "partial: division points not evidenced"),
    "10수학02-03": ("기울기와 직선의 방정식", "title candidate"),
    "10수학02-04": ("평행한 직선과 수직인 직선의 방정식", "title candidate"),
    "10수학02-05": ("점과 직선 사이의 거리", "new V2 candidate pending review"),
    "10수학02-06": ("원의 표준형과 중심·반지름", "title candidate"),
    "10수학02-07": ("직선과 원의 교점 및 접선", "title candidate"),
    "10수학02-08": ("좌표평면에서 평행이동과 대칭이동", "title candidate"),
    "10수학02-09": ("좌표평면에서 평행이동과 대칭이동", "partial topic candidate"),
    "10수학03-01": ("집합의 합집합과 교집합", "partial topic candidate"),
    "10수학03-02": ("두 집합 사이의 포함 관계", "new V2 candidate pending review"),
    "10수학03-03": ("집합의 합집합과 교집합", "title candidate"),
    "10수학03-04": ("명제와 조건", "partial: quantifier statements not evidenced"),
    "10수학03-05": ("명제의 역과 대우", "new V2 candidate pending review"),
    "10수학03-06": ("충분조건과 필요조건", "new V2 candidate pending review"),
    "10수학03-07": ("대우를 이용한 증명과 귀류법", "new V2 candidate pending review"),
    "10수학03-08": ("절대부등식의 뜻과 증명", "new V2 candidate pending review"),
    "10수학04-01": ("함수의 뜻과 대응", "title candidate"),
    "10수학04-02": ("함수의 합성과 합성함수", "new V2 candidate pending review"),
    "10수학04-03": ("역함수의 의미와 구하기", "new V2 candidate pending review"),
    "10수학04-04": ("유리함수의 기본 꼴", "title candidate"),
    "10수학04-05": ("무리함수의 정의역과 그래프", "title candidate"),
    "10수학05-01": ("합의 법칙과 곱의 법칙", "title candidate"),
    "10수학05-02": ("순열", "title candidate"),
    "10수학05-03": ("조합", "title candidate"),
}

# Full-page text was checked for the partial candidates. Each quote is also
# verified against the mapped chapter below, so the report does not silently
# drift when source pages change.
PARTIAL_CONTENT_AUDIT: dict[str, tuple[str, str, str]] = {
    "10수학01-10": ("x축과 두 점에서 만납니다", "이차함수의 x절편·방정식 실근", "이차함수 그래프와 일반 직선의 위치 관계"),
    "10수학01-11": ("꼭짓점은 (2,−1)", "꼭짓점 계산", "최대·최소 및 활용 문제"),
    "10수학01-12": ("x=−2, 2, 3", "인수분해로 삼차방정식 풀이", "사차방정식 풀이"),
    "10수학01-16": ("−2≤x≤3", "이차부등식의 해 구간", "이차함수와의 관계 및 연립이차부등식"),
    "10수학02-02": ("중점의 y좌표는", "두 점 사이 거리·중점", "내분·외분 및 내분점·외분점 좌표"),
    "10수학02-09": ("x축 대칭은 (x,−y)", "원점·x축·y축 대칭", "직선 y=x에 대한 대칭"),
    "10수학03-01": ("A∪B", "집합을 원소나열법으로 나타내고 합집합·교집합 연산", "집합 자체의 명시적 정의와 표현 방법 설명"),
    "10수학03-04": ("진리집합은 {−1,1}", "명제·조건·진리집합", "‘모든’, ‘어떤’을 포함한 명제"),
}

SUPPLEMENTAL_V2: dict[str, tuple[str, str]] = {
    "10수학01-10": ("포물선과직선의위치관계", "이차함수 그래프와 직선의 위치 관계"),
    "10수학01-11": ("이차함수최대최소활용", "이차함수의 최댓값·최솟값과 활용"),
    "10수학01-12": ("사차방정식풀이", "치환과 인수분해로 사차방정식 풀기"),
    "10수학01-16": ("이차함수와연립이차부등식", "이차함수와 연립이차부등식"),
    "10수학02-02": ("내분점외분점", "선분의 내분점과 외분점 좌표"),
    "10수학02-09": ("직선yx대칭", "직선 y=x에 대한 대칭이동"),
    "10수학03-01": ("집합개념과표현", "집합의 개념과 표현"),
    "10수학03-04": ("전칭존재명제", "모든과 어떤을 포함한 명제"),
}


def flatten_text(value: object) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return " ".join(flatten_text(item) for item in value)
    if isinstance(value, dict):
        return " ".join(flatten_text(item) for key, item in value.items() if key not in {"id", "type", "template"})
    return ""


def main() -> None:
    source = (SOURCES / "2015_appendix8_math.txt").read_text(encoding="utf-8")
    standards = {
        match.group(1): " ".join(match.group(2).split())
        for match in __import__("re").finditer(r"\[(10수학\d{2}-\d{2})\]\s*([^\r\n]*)", source)
    }
    codes = sorted(code for code in standards if code.startswith("10수학"))
    if set(codes) != set(MAPPING) or len(codes) != 41:
        raise RuntimeError(f"Expected 41 mapped official criteria; found {len(codes)}")
    expected_partial = {code for code, (_, status) in MAPPING.items() if status.startswith("partial")}
    if set(PARTIAL_CONTENT_AUDIT) != expected_partial:
        raise RuntimeError("Page-level notes must cover every and only partial candidate")

    chapters: dict[str, tuple[str, str, dict]] = {}
    for folder in ("수학상_2015개정_초안", "수학하_2015개정_초안"):
        book_path = next((MANUSCRIPTS / folder).glob("*태그분권_통합BookData*.json"))
        book = json.loads(book_path.read_text(encoding="utf-8-sig"))
        for chapter in book.get("chapters", []):
            title = str(chapter.get("title", ""))
            if title in chapters:
                raise RuntimeError(f"Duplicate chapter title: {title}")
            chapters[title] = (folder, book_path.name, chapter)

    rows = []
    title_links = 0
    no_candidates = 0
    partial = 0
    new_v2 = 0
    for code in codes:
        title, status = MAPPING[code]
        if title is None:
            evidence = "—"
            no_candidates += 1
        else:
            if title not in chapters:
                raise RuntimeError(f"Mapped chapter missing from integrated BookData: {title}")
            folder, book_name, chapter = chapters[title]
            evidence = f"`{folder}/{book_name}` · {title} · {len(chapter.get('pages', []))}쪽"
            if status == "title candidate":
                title_links += 1
            elif status.startswith("partial"):
                partial += 1
            else:
                new_v2 += 1
        rows.append(f"| `{code}` | {standards[code]} | {evidence} | {status} |")

    content_rows = []
    for code, (quote, coverage, gap) in PARTIAL_CONTENT_AUDIT.items():
        title, _ = MAPPING[code]
        if title is None or title not in chapters:
            raise RuntimeError(f"Partial content audit has no mapped chapter: {code}")
        chapter = chapters[title][2]
        if len(chapter.get("pages", [])) != 4:
            raise RuntimeError(f"Expected four source pages for partial candidate {code}")
        quote_page = next((page for page in chapter.get("pages", []) if quote in flatten_text(page)), None)
        if quote_page is None:
            raise RuntimeError(f"Page evidence quote missing from {code}: {quote}")
        content_rows.append(
            f"| `{code}` | {quote_page.get('title', '')} · “{quote}” | {coverage} | {gap} |"
        )

    supplemental_rows = []
    for code, (slug, title) in SUPPLEMENTAL_V2.items():
        volume = "상" if code in standards and code.startswith(("10수학01", "10수학02")) else "하"
        filename = f"수학{volume}_2015개정_{slug}_보충V2_BookData_초안.json"
        candidate = MANUSCRIPTS / f"수학{volume}_2015개정_초안" / filename
        if candidate.exists():
            supplement = json.loads(candidate.read_text(encoding="utf-8-sig"))
            chapter = supplement.get("chapters", [{}])[0]
            pages = chapter.get("pages", [])
            if supplement.get("standard_codes") != [code] or chapter.get("standard_codes") != [code] or len(pages) != 4:
                raise RuntimeError(f"Invalid supplemental draft evidence for {code}: {candidate}")
            missing = PARTIAL_CONTENT_AUDIT[code][2]
            supplemental_rows.append(f"| `{code}` | `{filename}` · {title} · {len(pages)}쪽 | {missing} | candidate draft; human review pending |")
        else:
            supplemental_rows.append(f"| `{code}` | not generated | {PARTIAL_CONTENT_AUDIT[code][2]} | remaining |")

    lines = [
        "# 2015 고등 수학(상·하) 기준-원고 후보 대조",
        "",
        "공식 2015 별책 8의 `<수학>` 기준 41개를 현재 상·하 통합 BookData의 chapter 제목과 대조한 작업 원장이다. 이 문서는 공식 상·하 분권을 확정하지 않는다.",
        "",
        f"집계: 공식 기준 {len(codes)}개, 기존 제목 후보 {title_links}개, 복합·부분 후보 {partial}개, 신규 V2 후보 {new_v2}개, chapter 후보 없음 {no_candidates}개.",
        "모든 원고 파일의 `curriculum_version` 및 기준 코드 태그는 미기록이다. 제목 후보는 범위 신호일 뿐, 페이지 본문 충족·수학 정확성·교사 검토·권리 승인을 뜻하지 않는다. `partial` 표시는 공식 문구의 구성 요소 중 현재 제목만으로 대조할 수 없는 부분이 있거나, 그 기준 전체를 다루지 않는 것이 확인된 경우다.",
        "",
        "| 공식 코드 | 공식 기준 | 원고 chapter 후보 | 대조 상태 |",
        "|---|---|---|---|",
        *rows,
        "",
        "## 부분 후보 8개 본문 대조 (저자 수준)",
        "",
        "아래는 각 연결 chapter의 전체 4쪽 텍스트를 확인해 현재 드러난 범위와 공식 기준에서 추가로 필요한 범위를 분리한 기록이다. 인용 구절은 생성 시 원고에서 검증한다. 이는 독립 수학·교사 검토나 본문 충족 승인이 아니다.",
        "",
        "| 공식 코드 | 실제 페이지 근거 | 확인된 내용 | 기존 통합 chapter에서 미확인 기준 요소 |",
        "|---|---|---|---|",
        *content_rows,
        "",
        "## 미확인 요소 보충 V2 후보",
        "",
        "별도 파일의 보충 초안은 기존 통합본을 덮어쓰지 않는다. 생성 여부와 코드 연결은 확인하지만, 본문 전체의 기준 충족·정확성·교사 승인은 별도 검토가 필요하다.",
        "",
        "| 공식 코드 | 보충 후보 | 보충 대상 | 상태 |",
        "|---|---|---|---|",
        *supplemental_rows,
        "",
        "## 출판·재개 판단",
        "",
        "- 통합본은 상권 23개·하권 16개 chapter다. 신규 10개 코드는 chapter/root에 명시하고 있으나 상·하권은 `editorial_split_candidate`이며 공식 분권이 아니다.",
        "- 신규 V2 10개는 도입·개념·예제·연습과 native quiz를 갖춘 후보이며, 기준 문구 전체에 대한 내용 충족은 독립 검토 전이다. 공식 교육과정에는 상·하권 경계가 없으므로 코드 연결만으로 각 상품 완료를 계산하지 않는다.",
        "- 기존 통합본 29개 장은 정의·질문·풀이·오답 점검 block을 포함하는 정적 BookData이며 선언형 activity가 없다. 별도 보충 V2에는 native quiz가 있으나 기존 HTML 자산과의 동등성 또는 전체 앱 동작 parity를 주장하지 않는다.",
        "- 교사·독립 수학검토와 원고 권리 근거가 없으므로 이 대조로 게시 자격을 부여하지 않는다.",
        "",
        "재생성: `python tool/audit_2015_upper_lower_scope.py` (공식 추출물 및 상·하 통합 BookData 필요)",
        "",
    ]
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote 2015 upper/lower audit: {len(codes)} criteria, {title_links} title candidates, {partial} partial candidates, {sum('not generated' not in row for row in supplemental_rows)} supplemental V2 candidates, {no_candidates} no-chapter candidates.")


if __name__ == "__main__":
    main()
