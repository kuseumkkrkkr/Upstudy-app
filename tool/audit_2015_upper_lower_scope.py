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
    "10수학01-02": (None, "no chapter candidate"),
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
    "10수학01-15": (None, "no chapter candidate"),
    "10수학01-16": ("이차부등식의 해", "partial topic candidate"),
    "10수학02-01": ("두 점 사이의 거리와 선분의 중점", "title candidate"),
    "10수학02-02": ("두 점 사이의 거리와 선분의 중점", "partial: division points not evidenced"),
    "10수학02-03": ("기울기와 직선의 방정식", "title candidate"),
    "10수학02-04": ("평행한 직선과 수직인 직선의 방정식", "title candidate"),
    "10수학02-05": (None, "no chapter candidate"),
    "10수학02-06": ("원의 표준형과 중심·반지름", "title candidate"),
    "10수학02-07": ("직선과 원의 교점 및 접선", "title candidate"),
    "10수학02-08": ("좌표평면에서 평행이동과 대칭이동", "title candidate"),
    "10수학02-09": ("좌표평면에서 평행이동과 대칭이동", "partial topic candidate"),
    "10수학03-01": ("집합의 합집합과 교집합", "partial topic candidate"),
    "10수학03-02": (None, "no chapter candidate"),
    "10수학03-03": ("집합의 합집합과 교집합", "title candidate"),
    "10수학03-04": ("명제와 조건", "title candidate"),
    "10수학03-05": (None, "no chapter candidate"),
    "10수학03-06": (None, "no chapter candidate"),
    "10수학03-07": (None, "no chapter candidate"),
    "10수학03-08": (None, "no chapter candidate"),
    "10수학04-01": ("함수의 뜻과 대응", "title candidate"),
    "10수학04-02": (None, "no chapter candidate"),
    "10수학04-03": (None, "no chapter candidate"),
    "10수학04-04": ("유리함수의 기본 꼴", "title candidate"),
    "10수학04-05": ("무리함수의 정의역과 그래프", "title candidate"),
    "10수학05-01": ("합의 법칙과 곱의 법칙", "title candidate"),
    "10수학05-02": ("순열", "title candidate"),
    "10수학05-03": ("조합", "title candidate"),
}


def main() -> None:
    source = (SOURCES / "2015_appendix8_math.txt").read_text(encoding="utf-8")
    standards = {
        match.group(1): " ".join(match.group(2).split())
        for match in __import__("re").finditer(r"\[(10수학\d{2}-\d{2})\]\s*([^\r\n]*)", source)
    }
    codes = sorted(code for code in standards if code.startswith("10수학"))
    if set(codes) != set(MAPPING) or len(codes) != 41:
        raise RuntimeError(f"Expected 41 mapped official criteria; found {len(codes)}")

    chapters: dict[str, tuple[str, str, int]] = {}
    for folder in ("수학상_2015개정_초안", "수학하_2015개정_초안"):
        book_path = next((MANUSCRIPTS / folder).glob("*태그분권_통합BookData*.json"))
        book = json.loads(book_path.read_text(encoding="utf-8-sig"))
        for chapter in book.get("chapters", []):
            title = str(chapter.get("title", ""))
            if title in chapters:
                raise RuntimeError(f"Duplicate chapter title: {title}")
            page_count = len(chapter.get("pages", []))
            chapters[title] = (folder, book_path.name, page_count)

    rows = []
    title_links = 0
    no_candidates = 0
    partial = 0
    for code in codes:
        title, status = MAPPING[code]
        if title is None:
            evidence = "—"
            no_candidates += 1
        else:
            if title not in chapters:
                raise RuntimeError(f"Mapped chapter missing from integrated BookData: {title}")
            folder, book_name, pages = chapters[title]
            evidence = f"`{folder}/{book_name}` · {title} · {pages}쪽"
            if status == "title candidate":
                title_links += 1
            else:
                partial += 1
        rows.append(f"| `{code}` | {standards[code]} | {evidence} | {status} |")

    lines = [
        "# 2015 고등 수학(상·하) 기준-원고 후보 대조",
        "",
        "공식 2015 별책 8의 `<수학>` 기준 41개를 현재 상·하 통합 BookData의 chapter 제목과 대조한 작업 원장이다. 이 문서는 공식 상·하 분권을 확정하지 않는다.",
        "",
        f"집계: 공식 기준 {len(codes)}개, 제목 후보 {title_links}개, 복합·부분 후보 {partial}개, chapter 후보 없음 {no_candidates}개.",
        "모든 원고 파일의 `curriculum_version` 및 기준 코드 태그는 미기록이다. 제목 후보는 범위 신호일 뿐, 페이지 본문 충족·수학 정확성·교사 검토·권리 승인을 뜻하지 않는다. `partial` 표시는 공식 문구의 구성 요소 중 현재 제목만으로 대조할 수 없는 부분이 있거나, 그 기준 전체를 다루지 않는 것이 확인된 경우다.",
        "",
        "| 공식 코드 | 공식 기준 | 원고 chapter 후보 | 대조 상태 |",
        "|---|---|---|---|",
        *rows,
        "",
        "## 출판·재개 판단",
        "",
        "- 두 통합본은 20개 상권 chapter와 9개 하권 chapter로 구성되어 있으나, 공식 기준 코드를 담지 않고 `standard_code_status=not_crosschecked`로 표시한다.",
        "- `no chapter candidate` 및 `partial` 기준을 우선 원고 범위표에 올리고, 페이지 본문 작성 후 코드별 tag를 추가해야 한다. 공식 교육과정에는 상·하권 경계가 없으므로 코드 연결만으로 각 상품 완료를 계산하지 않는다.",
        "- 기존 소단원 원고는 정의·질문·풀이·오답 점검 block을 포함하는 정적 BookData다. 해당 29개 장에는 선언형 activity가 확인되지 않아 interactive HTML 자산의 동등성이나 앱 동작을 주장하지 않는다.",
        "- 교사·독립 수학검토와 원고 권리 근거가 없으므로 이 대조로 게시 자격을 부여하지 않는다.",
        "",
        "재생성: `python tool/audit_2015_upper_lower_scope.py` (공식 추출물 및 상·하 통합 BookData 필요)",
        "",
    ]
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote 2015 upper/lower audit: {len(codes)} criteria, {title_links} title candidates, {partial} partial candidates, {no_candidates} no-chapter candidates.")


if __name__ == "__main__":
    main()
