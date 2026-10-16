"""Extract official 2022 mathematics achievement standards from recovered HWP XHTML tables."""
from __future__ import annotations

import json
import re
from pathlib import Path

from lxml import etree

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "work/official-curriculum/2022_appendix8_math.xhtml"
OUTPUT = ROOT / "work/official-curriculum/2022_math_standards.json"
CODE = re.compile(r"\[\s*([^\]]+?)\s*\]")
MATH_PREFIX = re.compile(r"^(?:9수|10공수1|10공수2|12대수|12미적Ⅰ|12확률과통계|12확통|12미적Ⅱ|12기하)(?:\d{2})?(?:-\d{2}){1,2}$")


def main() -> None:
    doc = etree.fromstring(SOURCE.read_bytes())
    tables = doc.xpath("//*[local-name()='table']")
    rows: list[dict[str, str | int]] = []
    for table_index, table in enumerate(tables):
        excluded: set[etree._Element] = set()
        for element in table.iter():
            if element.text and any(ord(char) >= 0xF0000 for char in element.text):
                excluded.add(element)
                heading = element.getnext()
                if heading is not None and etree.QName(heading).localname == "span":
                    excluded.add(heading)
        text = " ".join(" ".join(
            part for element in table.iter() if element not in excluded
            for part in ([element.text] if element.text else []) + ([element.tail] if element.tail else [])
        ).split())
        matches = list(CODE.finditer(text))
        for index, match in enumerate(matches):
            code = re.sub(r"\s+", "", match.group(1))
            if not MATH_PREFIX.fullmatch(code):
                continue
            end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
            criterion = text[match.end():end].strip(" \t.,")
            if not criterion:
                raise RuntimeError(f"Empty criterion at table {table_index}: {code}")
            rows.append({"code": code, "criterion": criterion, "table_index": table_index})
    codes = [str(row["code"]) for row in rows]
    if len(codes) != len(set(codes)):
        duplicates = sorted(code for code in set(codes) if codes.count(code) > 1)
        raise RuntimeError(f"Duplicate official standard codes: {duplicates}")
    if len(rows) < 50:
        raise RuntimeError(f"Unexpectedly few standards extracted: {len(rows)}")
    if len(rows) != 190:
        raise RuntimeError(f"Unexpected 2022 mathematics standard count: {len(rows)}; expected 190")
    known = {row["code"]: row["criterion"] for row in rows}
    expected = {
        "10공수1-02-07": "간단한 삼차방정식과 사차방정식을 풀 수 있다",
        "10공수1-02-08": "미지수가 2개인 연립이차방정식을 풀 수 있다",
        "10공수1-04-02": "행렬의 연산을 수행하고, 관련된 문제를 해결할 수 있다",
    }
    for code, criterion in expected.items():
        if known.get(code) != criterion:
            raise RuntimeError(f"Official criterion extraction mismatch: {code}: {known.get(code)!r}")
    OUTPUT.write_text(json.dumps({"source": SOURCE.name, "standards": rows}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Extracted {len(rows)} unique standards from {len(tables)} XHTML tables to {OUTPUT}")


if __name__ == "__main__":
    main()
