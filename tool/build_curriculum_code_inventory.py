"""Create a source-grounded code-family map for the 26 textbook catalog entries."""
from __future__ import annotations

import hashlib
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
    hashes = {
        "2015 official PDF": sha(SOURCES / "2015_appendix8_math.pdf"),
        "2015 official archive": sha(SOURCES / "2015_moe_curriculum_bundle.zip"),
        "2022 official HWP": sha(SOURCES / "2022_appendix8_math.hwp"),
        "2022 official archive": sha(SOURCES / "2022_math_standards_bundle.zip"),
    }

    out = [
        "# 남은 교재 공식 성취기준 코드 인덱스",
        "",
        "생성물: 공식 원문에서 추출된 코드 묶음과 26개 카탈로그 과목 연결 후보. 이 인덱스는 학기별 배정, 본문 커버리지, 수학 검수, 권리 승인, 출판 승인을 뜻하지 않는다.",
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
        "2015 원문은 교육부 고시 제2015-74호 별책8 PDF에서 추출했다. 2022 원문은 교육부 고시 제2022-33호 별책8 HWP를 텍스트로 추출했지만, 현재 추출물에서 성취기준 표 전체가 복구되지 않았다. 따라서 2022 코드 수와 아래 목록은 추출물에서 발견한 코드만 나타내며 공식 코드 집합 전체가 아니다. 로컬 대수 초안의 후보 `12대수03-02`도 이 추출물에서는 확인되지 않았다. 표 누락으로 인한 미확인 상태이므로 공식 코드로 승인하거나 잘못됐다고 단정할 수 없다. 원문 표를 복구한 뒤 재생성해야 한다.",
        "두 원문은 중학교 학년군 기준을 제공하지만 각 학년·학기의 배열은 제공하지 않는다. 중학교 학기 배정은 별도 공식/지역 편성 근거를 확보하기 전까지 편집 후보로 둔다.",
        "",
        "## 26개 상품별 공식 코드 묶음",
        "",
        "`추출물에서 발견`은 텍스트 변환 결과 안의 코드 수다. 특히 2022 자료는 성취기준 표 전체를 복구하지 못했으므로 이 수를 과목의 총 기준 수로 해석하지 않는다. 실제 원고의 내용 커버리지도 별도 대조가 필요하다.",
        "",
        "| # | 카탈로그 상품 | 공식 과목/학년군 코드 prefix | 추출물에서 발견 | 학기 귀속 근거 |",
        "|---:|---|---|---:|---|",
    ]

    for index in range(1, 27):
        filename, prefixes = COURSE_PREFIX[index]
        source = texts[filename]
        codes = sorted({code for code in re.findall(r"\[([^\]\s]+-\d{2})\]", source)
                        if any(code.startswith(prefix) for prefix in prefixes)})
        if not codes:
            raise RuntimeError(f"No official codes found for catalog row {index}: {prefixes}")
        prefix_text = ", ".join(f"`{prefix}`" for prefix in prefixes)
        semester = "공식 학기 미배정(학년군 기준); 편집 후보로 관리" if index <= 12 else "과목 기준 직접 연결; 자체 상·하 분권 경계 또는 학기 배열은 별도 검토"
        if index in (13, 14):
            semester = "공식 과목은 `<수학>`; 상·하권 분권은 자체 편집안이며 코드 범위 전수 배분 필요"
        title = products[index][1]
        out.append(f"| {index} | {title} | {prefix_text} | {len(codes)}개 (공식 총수 아님) | {semester} |")

    target_prefixes = {prefix for _, prefixes in COURSE_PREFIX.values() for prefix in prefixes}
    common_codes = sorted(code for code in set(code_lines["2015_appendix8_math.txt"]) & set(code_lines["2022_appendix8_math.txt"])
                          if any(code.startswith(prefix) for prefix in target_prefixes))
    changed_codes = [code for code in common_codes
                     if code_lines["2015_appendix8_math.txt"][code] != code_lines["2022_appendix8_math.txt"][code]]
    out += [
        "",
        "## 판본 간 코드 재사용 주의",
        "",
        f"두 원문에서 동일한 코드는 {len(common_codes)}개 발견됐고, PDF/HWP에서 추출한 해당 코드의 설명 줄이 모두 다르다({len(changed_codes)}/{len(common_codes)}). 같은 코드 문자열만으로 판본을 판정하지 말고, 교재 판본·공식 원문·설명 문맥을 함께 확인해야 한다.",
        "",
        "중복 코드: " + ", ".join(f"`{code}`" for code in common_codes),
        "",
        "예시 비교:",
        "",
    ]
    examples = [code for code in ("9수03-01", "12확통02-01", "12기하02-04", "12수학Ⅰ01-01") if code in changed_codes]
    for code in examples:
        old = code_lines["2015_appendix8_math.txt"][code][:110]
        new = code_lines["2022_appendix8_math.txt"][code][:110]
        out.append(f"- `{code}` — 2015: {old} / 2022: {new}")

    out += [
        "",
        "## 중복 제거된 코드 인벤토리",
        "",
        "다음은 prefix별 추출물에서 발견한 고유 코드다. 2015년 `10수학` 항목은 #13·#14가 함께 나누어야 할 공식 과목 집합이다. 2022 열거는 불완전 추출 결과이며 전체 기준 목록이 아니다.",
        "",
        "| 원문 | 코드 prefix | 추출 코드 수 | 추출물에서 발견된 코드 목록 |",
        "|---|---|---:|---|",
    ]
    unique_families = sorted({(filename, prefix) for filename, prefixes in COURSE_PREFIX.values() for prefix in prefixes})
    for filename, prefix in unique_families:
        codes = sorted({code for code in re.findall(r"\[([^\]\s]+-\d{2})\]", texts[filename]) if code.startswith(prefix)})
        out.append(f"| {filename.replace('_appendix8_math.txt', '')} | `{prefix}` | {len(codes)} | " + ", ".join(f"`{code}`" for code in codes) + " |")

    out += [
        "",
        "## 확인된 원고 연결",
        "",
        "- #8–#12의 2022 중학교 후보는 각 BookData에 코드 후보를 명시하고 있으나, 4모듈/24쪽은 과목 전체 범위가 아니다. 후보 코드가 있다고 전체 기준 충족으로 계산하지 않는다.",
        "- #1–#6의 2015 중학교 코드는 모두 중학교 학년군 범위다. 학년군의 코드 순서를 학년·학기 순서로 간주하지 않는다.",
        "- #13–#14는 2015 개정 공식 과목 `<수학>`을 자체 분권한 상품이다. 두 분권 간 공식 코드의 누락·중복 없는 배분표가 아직 없다.",
        "- 고등학교 과목은 코드 prefix로 공식 과목 범위를 식별했지만, 해당 상품의 모든 기준에 기존 원고가 대응되는지(원고·예제·연습·해설·조작 기능 포함)는 아직 입증하지 않았다.",
        "- 다음 단계는 이 기준 인덱스와 BookData/태그 원고를 코드별로 연결해 `covered / partial / missing / semester-unassigned` 상태와 원고 근거 경로를 기록하는 것이다. 출판 전 수학 교사 검수와 각 자산의 권리 근거 확인이 별도 필수다.",
        "",
        "재생성: `python tool/build_curriculum_code_inventory.py` (공식 원문 텍스트는 `work/official-curriculum/`에 필요)",
        "",
    ]
    OUT.write_text("\n".join(out), encoding="utf-8")
    print(f"Mapped {len(products)} catalog products from official extracts; wrote {OUT}.")


if __name__ == "__main__":
    main()
