"""Canonical grade-based math tag registry bundled with the S11 generator."""

from __future__ import annotations

from pathlib import Path
import re


TAG_SOURCE = Path(__file__).resolve().parents[1] / "data" / "math_curriculum_hashtags.md"
_GRADE_CODES = {"중1": 7, "중2": 8, "중3": 9, "고1": 10, "고2": 11, "고3": 12}


def load_subject_tag_rules() -> list[dict]:
    """Parse the checked-in curriculum hashtag specification by grade."""
    text = TAG_SOURCE.read_text(encoding="utf-8")
    groups: list[dict] = []
    seen_tags: set[str] = set()

    for code, (label, grade) in enumerate(_GRADE_CODES.items(), start=1):
        heading = re.search(rf"(?m)^# {re.escape(label)}\s*$", text)
        if not heading:
            raise ValueError(f"태그 기준 문서에 학년 섹션이 없습니다: {label}")
        next_heading = re.search(r"(?m)^# (?:중[123]|고[123])\s*$", text[heading.end():])
        end = heading.end() + next_heading.start() if next_heading else len(text)
        section = text[heading.end():end]
        tags = [match.group(1).strip() for match in re.finditer(r"(?m)^\s*-\s+#([^\s]+)\s*$", section)]
        if not tags:
            raise ValueError(f"태그 기준 문서에 태그가 없습니다: {label}")
        duplicates = seen_tags.intersection(tags)
        if duplicates:
            raise ValueError(f"학년 간 중복 태그가 있습니다: {sorted(duplicates)}")
        seen_tags.update(tags)
        groups.append({
            "code": code,
            "grade": grade,
            "name": label,
            "label": label,
            "tags": set(tags),
        })

    return groups
