"""Build a source-linked review queue for textbook BookData files."""

from __future__ import annotations

import hashlib
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT = MANUSCRIPTS / "REMAINING_TEXTBOOKS_REVIEW_QUEUE.md"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def status(book: dict, manifest: dict | None, key: str) -> str:
    value = (manifest or {}).get(key)
    if value is None:
        value = book.get("metadata", {}).get(key)
    return str(value) if value not in (None, "") else "unspecified"


def cell(value: object) -> str:
    return str(value).replace("|", "\\|").replace("\r", " ").replace("\n", " ")


def main() -> None:
    books: dict[str, list[Path]] = {}
    for path in MANUSCRIPTS.rglob("*BookData*.json"):
        books.setdefault(path.name, []).append(path)

    manifests: dict[str, list[tuple[Path, dict]]] = {}
    unassigned_manifests: list[tuple[Path, dict]] = []
    for path in MANUSCRIPTS.rglob("REVIEW_MANIFEST.json"):
        data = json.loads(path.read_text(encoding="utf-8"))
        bookdata_file = data.get("bookdata_file")
        if not bookdata_file:
            unassigned_manifests.append((path, data))
            continue
        manifests.setdefault(str(bookdata_file), []).append((path, data))

    lines = [
        "# 남은 교재 검수 대기 목록",
        "",
        "> 이 표는 기존 BookData와 REVIEW_MANIFEST의 상태를 모은 작업 목록이다. 원고 해시 일치, 생성기 검사, 저자 계산 점검은 교사·독립 수학·교육과정·권리 승인을 뜻하지 않는다. 상태가 기록되지 않은 값은 `unspecified`로 표시한다.",
        "",
    ]
    counts: Counter[str] = Counter()
    hash_counts: Counter[str] = Counter()
    fully_approved = 0
    rows: list[list[str]] = []

    for filename, paths in sorted(books.items(), key=lambda item: item[0].casefold()):
        for path in sorted(paths, key=lambda item: item.as_posix().casefold()):
            book = json.loads(path.read_text(encoding="utf-8"))
            candidates = manifests.get(filename, [])
            manifest_path: Path | None = None
            manifest: dict | None = None
            hash_state = "no manifest"
            if len(paths) > 1:
                hash_state = "duplicate filename; unresolved"
            elif len(candidates) > 1:
                hash_state = "multiple manifests; unresolved"
            elif candidates:
                manifest_path, manifest = candidates[0]
                expected = str(manifest.get("bookdata_sha256", "")).upper()
                content = path.read_bytes()
                if expected and expected == sha256(content):
                    hash_state = "raw SHA match"
                elif expected and expected == sha256(content.replace(b"\r\n", b"\n")):
                    hash_state = "normalized SHA match"
                else:
                    hash_state = "SHA mismatch"
            counts["books"] += 1
            counts["with manifest"] += bool(manifest)
            counts["without manifest"] += not bool(manifest)
            hash_counts[hash_state] += 1
            gates = {
                key: status(book, manifest, key).strip().lower()
                for key in (
                    "curriculum_review_status",
                    "math_review_status",
                    "teacher_review_status",
                    "rights_status",
                    "publication_eligibility",
                )
            }
            fully_approved += (
                gates["curriculum_review_status"] in {"approved", "cleared"}
                and gates["math_review_status"] in {"approved", "cleared"}
                and gates["teacher_review_status"] in {"approved", "cleared"}
                and gates["rights_status"] in {"approved", "cleared", "licensed"}
                and gates["publication_eligibility"]
                in {"eligible", "approved", "publishable"}
            )
            chapters = book.get("chapters", [])
            page_count = sum(
                len(chapter.get("pages", []))
                for chapter in chapters
                if isinstance(chapter, dict)
            )
            relative = path.relative_to(ROOT).as_posix()
            manifest_cell = (
                f"`{manifest_path.relative_to(ROOT).as_posix()}`"
                if manifest_path
                else "—"
            )
            rows.append(
                [
                    f"`{relative}`",
                    cell(book.get("title", "untitled")),
                    str(len(book.get("tags", []))),
                    f"{len(chapters)}/{page_count}",
                    manifest_cell,
                    hash_state,
                    status(book, manifest, "curriculum_review_status"),
                    status(book, manifest, "math_review_status"),
                    status(book, manifest, "teacher_review_status"),
                    status(book, manifest, "rights_status"),
                    status(book, manifest, "publication_eligibility"),
                ]
            )

    manifest_count = sum(1 for _ in MANUSCRIPTS.rglob("REVIEW_MANIFEST.json"))
    lines.extend(
        [
            "## 현재 집계",
            "",
            f"- BookData: {counts['books']}개",
            f"- 직접 연결된 검수 manifest: {counts['with manifest']}개; 미연결 BookData: {counts['without manifest']}개",
            f"- REVIEW_MANIFEST 파일: {manifest_count}개; `bookdata_file` 미기재: {len(unassigned_manifests)}개",
            "- SHA 상태: "
            + ", ".join(f"{name} {count}개" for name, count in sorted(hash_counts.items())),
            f"- 다섯 승인 게이트가 모두 명시적으로 승인된 BookData: {fully_approved}개",
            "- `publication_eligibility`는 기록된 값을 그대로 표시한다. 승인 표시가 있어도 권리·교사·수학·교육과정 검토가 모두 확인되기 전에는 배포 승인으로 간주하지 않는다.",
            "",
            "## 파일별 검수 상태",
            "",
            "| BookData | 책 제목 | 태그 | 장/쪽 | 검수 manifest | 해시 | 교육과정 검토 | 수학 검토 | 교사 검토 | 권리 | 출판 자격 |",
            "|---|---|---:|---:|---|---|---|---|---|---|---|",
        ]
    )
    lines.extend("| " + " | ".join(row) + " |" for row in rows)
    if unassigned_manifests:
        lines.extend(
            [
                "",
                "## BookData 연결이 빠진 manifest",
                "",
                "| manifest 경로 | 상태 | 출판 자격 | 권리 | 교사 검토 | 수학 검토 |",
                "|---|---|---|---|---|---|",
            ]
        )
        for path, manifest in unassigned_manifests:
            relative = f"`{path.relative_to(ROOT).as_posix()}`"
            lines.append(
                "| "
                + " | ".join(
                    [
                        relative,
                        cell(manifest.get("status", "unspecified")),
                        cell(manifest.get("publication_eligibility", "unspecified")),
                        cell(manifest.get("rights_status", "unspecified")),
                        cell(manifest.get("teacher_review_status", "unspecified")),
                        cell(manifest.get("math_review_status", "unspecified")),
                    ]
                )
                + " |"
            )
    OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(
        f"Wrote review queue: {counts['books']} BookData, "
        f"{counts['with manifest']} manifest-linked, "
        f"{counts['without manifest']} unlinked."
    )


if __name__ == "__main__":
    main()
