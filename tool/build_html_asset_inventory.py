"""Create a static, non-executing inventory of standalone textbook HTML assets."""
from __future__ import annotations

import hashlib
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUT = MANUSCRIPTS / "REMAINING_TEXTBOOKS_HTML_ASSET_INDEX.md"
SCRIPT_RE = re.compile(r"<script\b([^>]*)>(.*?)</script\s*>", re.I | re.S)
TAG_RE = re.compile(r"<(input|button|select|textarea|canvas|svg)\b([^>]*)>", re.I | re.S)
ID_RE = re.compile(r"\bid\s*=\s*['\"]([^'\"]+)['\"]", re.I)
TYPE_RE = re.compile(r"\btype\s*=\s*['\"]([^'\"]+)['\"]", re.I)
EVENT_RE = re.compile(r"\bon([a-z]+)\s*=", re.I)
LISTENER_RE = re.compile(r"\.addEventListener\(\s*['\"]([a-z]+)['\"]", re.I)
EXTERNAL_SCRIPT_RE = re.compile(r"<script\b[^>]*\bsrc\s*=\s*['\"]([^'\"]+)['\"]", re.I)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def main() -> None:
    html_files = sorted(MANUSCRIPTS.rglob("*.html"))
    bookdata = sorted(MANUSCRIPTS.rglob("*BookData*.json"))
    book_text: dict[Path, str] = {}
    for path in bookdata:
        try:
            book_text[path] = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            book_text[path] = ""

    total_bytes = 0
    signal_counts = Counter()
    explicit_ref_assets = 0
    rows = []
    for path in html_files:
        raw = path.read_bytes()
        source = raw.decode("utf-8", errors="replace")
        rel = path.relative_to(MANUSCRIPTS).as_posix()
        digest = sha(raw)
        asset_id = "html-" + hashlib.sha256(rel.encode("utf-8")).hexdigest()[:16]
        scripts = SCRIPT_RE.findall(source)
        inline_hashes = [sha(body.encode("utf-8")) for attrs, body in scripts if not re.search(r"\bsrc\s*=", attrs, re.I)]
        tags: Counter[str] = Counter()
        control_ids: list[str] = []
        for tag, attrs in TAG_RE.findall(source):
            tag = tag.lower()
            if tag == "input":
                typ = TYPE_RE.search(attrs)
                tags[f"input:{typ.group(1).lower() if typ else 'text'}"] += 1
            else:
                tags[tag] += 1
            ident = ID_RE.search(attrs)
            if ident:
                control_ids.append(f"{tag}#{ident.group(1)}")
        events = sorted(set(EVENT_RE.findall(source) + LISTENER_RE.findall(source)))
        external = EXTERNAL_SCRIPT_RE.findall(source)
        signal = {
            "random": bool(re.search(r"Math\.random|\brandom\b|dice|주사위", source, re.I)),
            "pointer": bool(re.search(r"pointer(?:down|move|up)|touchstart|draggable|dragstart", source, re.I)),
            "timer": bool(re.search(r"setInterval|setTimeout|requestAnimationFrame", source, re.I)),
            "css_animation": bool(re.search(r"@keyframes|\banimation\s*:", source, re.I)),
            "reduced_motion": bool(re.search(r"prefers-reduced-motion|reducedMotion", source, re.I)),
            "network": bool(re.search(r"\bfetch\s*\(|XMLHttpRequest|WebSocket", source)),
        }
        signal_counts.update({key: int(value) for key, value in signal.items()})
        refs = [p.relative_to(MANUSCRIPTS).as_posix() for p, text in book_text.items() if path.name in text]
        if refs:
            explicit_ref_assets += 1
        total_bytes += len(raw)
        controls = ", ".join(f"{key}×{count}" for key, count in sorted(tags.items())) or "none detected"
        ids = ", ".join(control_ids) or "none detected"
        script_hashes = ", ".join(inline_hashes) or "none"
        event_text = ", ".join(events) or "none detected"
        ref_text = "; ".join(f"`{name}`" for name in refs) or "unresolved"
        external_text = ", ".join(external) or "none detected"
        signal_text = ", ".join(f"{key}={int(value)}" for key, value in signal.items())
        status = "partial_native_mapping_review_required" if "확률실험" in Path(rel).name else "source_review_required"
        rows.append(
            f"| `{asset_id}` | `{rel}` | {len(raw)} | `{digest}` | `{script_hashes}` | {controls} | `{ids}` | {event_text} | {signal_text} | {ref_text} | {external_text} | {status} |"
        )

    lines = [
        "# 독립 HTML 체험 자산 정적 인덱스",
        "",
        f"검색 결과: HTML `{len(html_files)}`개, 총 `{total_bytes}` bytes; BookData 참조 파일 `{len(bookdata)}`개를 대상으로 전체 파일명 문자열을 확인했다.",
        "",
        "이 자료는 정적 인벤토리다. 스크립트는 실행하지 않았으므로 컨트롤/이벤트/신호는 source text에서 검출한 후보이지 실제 동작 검증이 아니다. `asset_id`는 상대 경로 SHA-256 앞 16자리이며, 콘텐츠 SHA와 inline script SHA도 함께 기록한다.",
        "BookData 열은 HTML 파일명이 JSON 본문에 명시된 정확 일치 참조만 보여 준다. 이것은 학생용 상품 ID 귀속 또는 앱 runtime 연결 증거가 아니다. 앱 V2 importer는 HTML/JavaScript 실행을 지원하지 않으며, 독립 파일은 activity로 자동 임베드되지 않는다.",
        "네트워크 신호는 inline source에서의 `fetch`/XHR/WebSocket 정적 검색이다. 외부 `<script src>` 값은 별도 열에 기록한다. 보안/저작권/수학 검토를 대체하지 않는다.",
        "",
        f"정적 신호 검출 파일 수(중복 가능): random `{signal_counts['random']}`, pointer/drag `{signal_counts['pointer']}`, JavaScript timer API `{signal_counts['timer']}`, CSS animation `{signal_counts['css_animation']}`, reduced-motion `{signal_counts['reduced_motion']}`, network-call `{signal_counts['network']}`. HTML 파일명이 BookData 본문에 정확히 언급된 자산은 `{explicit_ref_assets}`개다. 이 숫자는 상품 소유·실행 연결 수가 아니다.",
        "",
        "| Asset ID | 상대 경로 | bytes | 본문 SHA-256 | inline script SHA-256 | 검출 컨트롤 수 | control IDs | event names | 정적 신호 | BookData exact reference | external scripts | 상태 |",
        "|---|---|---:|---|---|---|---|---|---|---|---|---|",
        *rows,
        "",
        "## Content review notes",
        "",
        "| Asset ID | 발견 내용 | 수정 상태 | 확인 경계 |",
        "|---|---|---|---|",
        "| `html-002d8074c7ebb2fb` | `α=2`에서 `α=−2`로 바꿀 때 기존 응답은 반대 방향·두 배 길이라고 안내했다. 계수 절댓값은 같으므로 길이 변화 설명이 틀렸다. | 선택지를 반대 방향·같은 길이로 수정하고 안내문을 교체했다. | 로컬 브라우저에서 두 Socratic 질문 진행과 정답 선택 후 완료 피드백을 확인하고 화면을 캡처했다. 상품/BookData 연결과 교사 검수는 미확인이다. |",
        "| `html-002d8074c7ebb2fb`, `html-5f1d5700e9fa1fc1` | hotfix 문서의 `vectorOperation` 원본 자산이다. | `migration_status=not_ported`로 추적한다. | 현재 eligible BookData 후보 연결과 실제 reader 검증은 확인되지 않았다. main 앱 reader는 `quiz`만 실행하고 이 kind는 unsupported fallback으로 표시한다. 원본 HTML은 보존한다. |",
        "| `html-2a9ff578cf62178d` | hotfix 문서의 `vectorInnerProduct` 원본 자산이다. | `migration_status=not_ported`로 추적한다. | 현재 eligible BookData 후보 연결과 실제 reader 검증은 확인되지 않았다. main 앱 reader는 `quiz`만 실행하고 이 kind는 unsupported fallback으로 표시한다. 원본 HTML은 보존한다. |",
        "| `html-4f713a1ae26d9f06` | 주사위 시행·짝수 사건·상대도수 누적 기능이 독립 HTML에 있다. | BookData V2에 `discreteExperiment`(6면 균등, 짝수 성공 조건)으로 네이티브 부분 대응을 추가했다. | importer는 통과했으나 HTML과 native UI의 실제 화면·상호작용 parity는 별도 브라우저 검수 전이며 원본 HTML은 보존한다. |",
        "",
        "재생성: `python tool/build_html_asset_inventory.py`",
        "",
    ]
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Indexed {len(html_files)} HTML assets and {len(bookdata)} BookData files; wrote {OUT}.")


if __name__ == "__main__":
    main()
