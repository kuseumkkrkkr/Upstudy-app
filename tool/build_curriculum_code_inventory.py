"""Create a source-grounded code-family map for the 26 textbook catalog entries."""
from __future__ import annotations

import hashlib
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "work/official-curriculum"
OUT = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고/REMAINING_TEXTBOOKS_CURRICULUM_MAP.md"
CATALOG = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고/개념서_체험콘텐츠_제작규격.md"

COURSE_PREFIX = {
    1: ("2015_appendix8_math.txt", ["9수"]),
    2: ("2015_appendix8_math.txt", ["9수"]),
    3: ("2015_appendix8_math.txt", ["9수"]),
    4: ("2015_appendix8_math.txt", ["9수"]),
    5: ("2015_appendix8_math.txt", ["9수"]),
    6: ("2015_appendix8_math.txt", ["9수"]),
    7: ("2022_appendix8_math.txt", ["9수"]),
    8: ("2022_appendix8_math.txt", ["9수"]),
    9: ("2022_appendix8_math.txt", ["9수"]),
    10: ("2022_appendix8_math.txt", ["9수"]),
    11: ("2022_appendix8_math.txt", ["9수"]),
    12: ("2022_appendix8_math.txt", ["9수"]),
    13: ("2015_appendix8_math.txt", ["10수학"]),
    14: ("2015_appendix8_math.txt", ["10수학"]),
    15: ("2015_appendix8_math.txt", ["12수학Ⅰ"]),
    16: ("2015_appendix8_math.txt", ["12수학Ⅱ"]),
    17: ("2015_appendix8_math.txt", ["12확통"]),
    18: ("2015_appendix8_math.txt", ["12미적"]),
    19: ("2015_appendix8_math.txt", ["12기하"]),
    20: ("2022_appendix8_math.txt", ["10공수1"]),
    21: ("2022_appendix8_math.txt", ["10공수2"]),
    22: ("2022_appendix8_math.txt", ["12대수"]),
    23: ("2022_appendix8_math.txt", ["12미적Ⅰ"]),
    24: ("2022_appendix8_math.txt", ["12확통"]),
    25: ("2022_appendix8_math.txt", ["12미적Ⅱ"]),
    26: ("2022_appendix8_math.txt", ["12기하"]),
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main() -> None:
    catalog_lines = CATALOG.read_text(encoding="utf-8").splitlines()
    products = {}
    for line in catalog_lines:
        match = re.match(r"\|\s*(\d+)\s*\|\s*([^|]+)\|\s*([^|]+)\|\s*([^|]+)\|\s*([^|]+)\|", line)
        if match and 1 <= int(match.group(1)) <= 26:
            products[int(match.group(1))] = [part.strip() for part in match.groups()[1:]]
    if set(products) != set(range(1, 27)):
        raise RuntimeError(f"Catalog rows not fully parsed: {sorted(products)}")

    texts = {name: (SOURCES / name).read_text(encoding="utf-8")
             for name in {item[0] for item in COURSE_PREFIX.values()}}
    code_lines = {
        filename: {match.group(1): re.sub(r"\s+", " ", match.group(2)).strip()
                   for match in re.finditer(r"\[([^\]\s]+-\d{2})\]\s*([^\r\n]*)", text)}
        for filename, text in texts.items()
    }
    standards_2022 = json.loads((SOURCES / "2022_math_standards.json").read_text(encoding="utf-8"))["standards"]
    official_2022 = {row["code"]: row["criterion"] for row in standards_2022}
    hashes = {
        "2015 official PDF": sha(SOURCES / "2015_appendix8_math.pdf"),
        "2015 official archive": sha(SOURCES / "2015_moe_curriculum_bundle.zip"),
        "2022 official HWP": sha(SOURCES / "2022_appendix8_math.hwp"),
        "2022 official archive": sha(SOURCES / "2022_math_standards_bundle.zip"),
    }

    out = [
        "# 남은 교재 교육과정 원문 추출 인덱스",
        "",
        "생성물: 2015 PDF 기준 코드 인덱스와 2022 HWP 본표 기준 코드를 구분해 기록한다. 이는 학기별 배정, 원고 내용 충족, 수학 검수, 권리 승인, 출판 승인을 뜻하지 않는다.",
        "",
        "## 원문과 무결성",
        "",
        "| 원문 | 다운로드·추출 파일 | SHA-256 |",
        "|---|---|---|",
        f"| 2015 개정 수학과 별책8 PDF | `work/official-curriculum/2015_appendix8_math.pdf` | `{hashes['2015 official PDF']}` |",
        f"| 2015 교육부 묶음 ZIP | `work/official-curriculum/2015_moe_curriculum_bundle.zip` | `{hashes['2015 official archive']}` |",
        f"| 2022 개정 수학과 별책8 HWP | `work/official-curriculum/2022_appendix8_math.hwp` | `{hashes['2022 official HWP']}` |",
        f"| 2022 교육부 묶음 ZIP | `work/official-curriculum/2022_math_standards_bundle.zip` | `{hashes['2022 official archive']}` |",
        "",
        f"중요한 범위 구분: 2015 항목은 교육부 고시 제2015-74호 별책8 PDF의 성취기준 코드 목록에서 추출했다. 2022 항목은 공식 HWP를 XHTML로 변환한 뒤 성취기준 표에서 {len(official_2022)}개 고유 코드를 추출했다. 해설 텍스트 ID는 본표와 별개이며 공식 기준 목록으로 세지 않는다.",
        "두 원문은 중학교 학년군 기준을 제공하지만 각 학년·학기의 배열은 제공하지 않는다. 중학교 학기 배정은 별도 공식/지역 편성 근거를 확보하기 전까지 편집 후보로 둔다.",
        "",
        "## 26개 상품별 원문 범위 상태",
        "",
        "2015 값은 PDF 기준 코드 수, 2022 값은 HWP 본표 기준 코드 수다. 원고의 실제 내용 연결은 별도 검토가 필요하다.",
        "",
        "| # | 카탈로그 상품 | 과목/학년군 prefix | 원문 추출 | 학기·범위 상태 |",
        "|---:|---|---|---:|---|",
    ]

    for index in range(1, 27):
        filename, prefixes = COURSE_PREFIX[index]
        source = texts[filename]
        if filename.startswith("2022"):
            codes = sorted(code for code in official_2022 if any(code.startswith(prefix) for prefix in prefixes))
        else:
            codes = sorted({code for code in re.findall(r"\[([^\]\s]+-\d{2})\]", source)
                            if any(code.startswith(prefix) for prefix in prefixes)})
        if not codes:
            raise RuntimeError(f"No official codes found for catalog row {index}: {prefixes}")
        prefix_text = ", ".join(f"`{prefix}`" for prefix in prefixes)
        semester = "학년군 기준; 공식 학기 미배정" if index <= 12 else "과목 기준; 상품 범위 대조 필요"
        if index in (13, 14):
            semester = "공식 과목은 `<수학>`; 상·하권 분권은 자체 편집안이며 코드 범위 전수 배분 필요"
        title = products[index][1]
        if filename == "2022_appendix8_math.txt":
            extract_status = f"{len(codes)}개 HWP 본표 기준 코드"
            scope_status = semester
        else:
            extract_status = f"{len(codes)}개 PDF 기준 코드 항목"
            scope_status = semester
        out.append(f"| {index} | {title} | {prefix_text} | {extract_status} | {scope_status} |")

    out += [
        "",
        "## 추출 ID 목록과 해석 종류",
        "",
        "2015 목록은 PDF 기준 코드 추출이다. 2022 목록은 XHTML 복구 HWP 성취기준 본표의 공식 코드다.",
        "",
        "| 원문 | prefix | 추출 종류 | 관측 ID 수 | ID 목록 |",
        "|---|---|---:|---|",
    ]
    unique_families = sorted({(filename, prefix) for filename, prefixes in COURSE_PREFIX.values() for prefix in prefixes})
    for filename, prefix in unique_families:
        codes = (sorted(code for code in official_2022 if code.startswith(prefix)) if filename.startswith("2022")
                 else sorted({code for code in re.findall(r"\[([^\]\s]+-\d{2})\]", texts[filename]) if code.startswith(prefix)}))
        extract_kind = "기준 코드 (PDF)" if filename.startswith("2015") else "기준 코드 (HWP XHTML 표)"
        out.append(f"| {filename.replace('_appendix8_math.txt', '')} | `{prefix}` | {extract_kind} | {len(codes)} | " + ", ".join(f"`{code}`" for code in codes) + " |")

    out += [
        "",
        "## 확인된 원고 연결",
        "",
        "- 2022 HWP 해설 참고 ID는 성취기준 표의 코드 범위로 승격하지 않는다. 기존 BookData의 2022 code tags 및 이 원장 수치는 교재 coverage 산정에 사용하지 않는다.",
        "- #1–#6의 2015 중학교 코드는 모두 중학교 학년군 범위다. 학년군의 코드 순서를 학년·학기 순서로 간주하지 않는다.",
        "- #13–#14는 2015 개정 공식 과목 `<수학>`을 자체 분권한 상품이다. 두 분권 간 공식 코드의 누락·중복 없는 배분표가 아직 없다.",
        "- 2015 고등학교 코드는 과목 수준의 공식 목록이다. #13·#14 분권 경계 및 원고별 본문 coverage는 아직 확정하지 않았다.",
        "- 다음 단계는 공식 기준과 기존 BookData/태그 원고의 본문을 대조하는 것이다. 별도로 수학 교사 검수와 권리 근거가 필요하다.",
        "",
        "재생성: `python tool/build_curriculum_code_inventory.py` (공식 원문 텍스트는 `work/official-curriculum/`에 필요)",
        "",
    ]
    OUT.write_text("\n".join(out), encoding="utf-8")
    print(f"Mapped {len(products)} catalog products from official extracts; wrote {OUT}.")


if __name__ == "__main__":
    main()
