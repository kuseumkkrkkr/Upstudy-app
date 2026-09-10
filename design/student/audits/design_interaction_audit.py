"""학생 HTML 시안의 화면·대화상자·조작 대상을 검증하는 읽기 전용 도구.

기본 실행은 파일만 읽어 86개 화면 등록과 대화상자 템플릿을 확인한다.
`--runtime`을 사용하면 로컬 HTTP 서버에서 각 화면을 새로 연 뒤 보이는
버튼과 링크를 하나씩 눌러 열린 URL·대화상자 상태를 JSON으로 출력한다.
실제 Flutter API나 사용자 데이터에는 접근하지 않는다.
"""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import http.server
import json
import re
import socketserver
import sys
import threading
from dataclasses import asdict, dataclass
from pathlib import Path
from urllib.parse import quote, urlencode


SCREEN_RE = re.compile(r"defineScreen\(\{\s*id:\s*\"([^\"]+)\"")
DIALOG_RE = re.compile(r"(?:<dialog\b|role=\"dialog\")", re.IGNORECASE)
DATA_ATTRIBUTE_RE = re.compile(r"\b(data-[a-z0-9-]+)(?:\s*=|\s|>)", re.IGNORECASE)
CLICK_SELECTOR = (
    "button, a[href], [role='button'], [data-ui-action], [data-ui-choice], "
    "[data-screen-target]"
)
EDGE = Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")


@dataclass(frozen=True)
class DesignInventory:
    """디자인 파일에서 추출한 변경 불가 정적 검수 기준."""

    source: str
    sha256: str
    bytes: int
    lines: int
    screen_ids: tuple[str, ...]
    dialog_templates: int
    data_attributes: tuple[str, ...]

    @property
    def screen_count(self) -> int:
        """등록된 디자인 화면 수를 반환한다."""

        return len(self.screen_ids)


@dataclass(frozen=True)
class ClickObservation:
    """화면의 한 조작 대상을 누른 뒤 관찰한 읽기 전용 결과."""

    screen_id: str
    index: int
    tag: str
    label: str
    href: str
    url_after_click: str
    visible_dialogs: tuple[str, ...]
    error: str = ""


class _QuietHandler(http.server.SimpleHTTPRequestHandler):
    """로컬 검수 서버의 요청 로그를 숨긴다."""

    def log_message(self, _format: str, *args: object) -> None:
        return


class DesignInteractionAuditor:
    """HTML 기준을 추출하고 선택적으로 로컬 클릭 검수를 실행한다."""

    def __init__(self, source: Path) -> None:
        """필요 변수는 UTF-8 HTML 파일 경로다."""

        self.source = source.resolve()
        self._html = ""
        self._raw = b""

    def _read(self) -> str:
        """HTML을 한 번 읽고 이후 추출에서 재사용한다."""

        if not self._html:
            self._raw = self.source.read_bytes()
            self._html = self._raw.decode("utf-8")
        return self._html

    def inventory(self) -> DesignInventory:
        """화면·대화상자·data 속성을 중복 없이 추출한다."""

        html = self._read()
        screen_ids = tuple(dict.fromkeys(SCREEN_RE.findall(html)))
        data_attributes = tuple(sorted(set(DATA_ATTRIBUTE_RE.findall(html))))
        return DesignInventory(
            source=str(self.source),
            sha256=hashlib.sha256(self._raw).hexdigest().upper(),
            bytes=len(self._raw),
            lines=html.count("\n") + 1,
            screen_ids=screen_ids,
            dialog_templates=len(DIALOG_RE.findall(html)),
            data_attributes=data_attributes,
        )

    def assert_expected(self, expected_screens: int) -> DesignInventory:
        """화면 수가 기준과 다르면 예외를 발생시킨다."""

        report = self.inventory()
        if report.screen_count != expected_screens:
            raise ValueError(
                f"화면 수 불일치: expected={expected_screens}, "
                f"actual={report.screen_count}"
            )
        return report

    def click_visible_controls(
        self,
        *,
        width: int = 390,
        height: int = 844,
        port: int = 8997,
        wait_ms: int = 250,
        screen_ids: tuple[str, ...] | None = None,
    ) -> tuple[ClickObservation, ...]:
        """각 화면을 초기화한 뒤 보이는 조작 대상을 하나씩 눌러 결과를 기록한다.

        매 클릭마다 새 페이지를 사용해 앞선 클릭이 다음 결과에 영향을 주지 않게 한다.
        검수 대상은 로컬 HTML뿐이며, 실패한 클릭도 결과에 남기고 전체 순회를 계속한다.
        """

        try:
            from playwright.sync_api import sync_playwright
        except ImportError as exc:  # pragma: no cover - 환경 의존 경로
            raise RuntimeError("--runtime에는 playwright가 필요합니다.") from exc

        inventory = self.inventory()
        selected = screen_ids or inventory.screen_ids
        if not selected:
            return ()

        handler = lambda *args, **kwargs: _QuietHandler(  # noqa: E731
            *args, directory=str(self.source.parent), **kwargs
        )
        server = socketserver.ThreadingTCPServer(("127.0.0.1", port), handler)
        server.allow_reuse_address = True
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        observations: list[ClickObservation] = []
        try:
            with sync_playwright() as playwright:
                browser_options = {
                    "headless": True,
                    "args": ["--enable-unsafe-swiftshader", "--hide-scrollbars"],
                }
                if EDGE.is_file():
                    browser_options["executable_path"] = str(EDGE)
                browser = playwright.chromium.launch(**browser_options)
                page_url = f"http://127.0.0.1:{port}/{quote(self.source.name)}"
                for screen_id in selected:
                    baseline_url = f"{page_url}?{urlencode({'screen': screen_id})}"
                    baseline = browser.new_page(viewport={"width": width, "height": height})
                    baseline.goto(baseline_url, wait_until="domcontentloaded", timeout=5000)
                    baseline.wait_for_timeout(wait_ms)
                    count = baseline.locator(CLICK_SELECTOR).count()
                    baseline.close()
                    for index in range(count):
                        page = browser.new_page(viewport={"width": width, "height": height})
                        tag = label = href = ""
                        try:
                            page.goto(baseline_url, wait_until="domcontentloaded", timeout=5000)
                            page.wait_for_timeout(wait_ms)
                            target = page.locator(CLICK_SELECTOR).nth(index)
                            if not target.is_visible():
                                continue
                            tag, label, href = target.evaluate(
                                """node => ({
                                  tag: node.tagName.toLowerCase(),
                                  label: (node.getAttribute('aria-label') || node.innerText || '').replace(/\\s+/g, ' ').trim(),
                                  href: node.getAttribute('href') || ''
                                })"""
                            ).values()
                            target.click(timeout=1000)
                            page.wait_for_timeout(wait_ms)
                            dialog_nodes = page.locator(
                                "[role='dialog'], dialog, [aria-modal='true']"
                            ).all()
                            dialogs = tuple(
                                node.inner_text()
                                for node in dialog_nodes
                                if node.is_visible()
                            )
                            observations.append(
                                ClickObservation(
                                    screen_id=screen_id,
                                    index=index,
                                    tag=tag,
                                    label=label,
                                    href=href,
                                    url_after_click=page.url,
                                    visible_dialogs=tuple(
                                        " ".join(text.split()) for text in dialogs if text.strip()
                                    ),
                                )
                            )
                        except Exception as exc:  # pragma: no cover - 브라우저별 오류
                            observations.append(
                                ClickObservation(
                                    screen_id=screen_id,
                                    index=index,
                                    tag=tag,
                                    label=label,
                                    href=href,
                                    url_after_click=page.url,
                                    visible_dialogs=(),
                                    error=str(exc),
                                )
                            )
                        finally:
                            page.close()
                browser.close()
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)
        return tuple(observations)


def _source_path(value: str) -> Path:
    """입력 경로를 확인하고 절대 경로로 반환한다."""

    source = Path(value).expanduser().resolve()
    if not source.is_file():
        raise FileNotFoundError(f"HTML 파일이 없습니다: {source}")
    return source


def main() -> int:
    """CLI 입력을 처리하고 JSON으로 결과를 출력한다."""

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=_source_path)
    parser.add_argument("--expect-screens", type=int, default=86)
    parser.add_argument("--runtime", action="store_true")
    parser.add_argument("--screen", action="append", dest="screens", default=[])
    parser.add_argument("--width", type=int, default=390)
    parser.add_argument("--height", type=int, default=844)
    parser.add_argument("--port", type=int, default=8997)
    parser.add_argument("--wait-ms", type=int, default=250)
    args = parser.parse_args()

    auditor = DesignInteractionAuditor(args.source)
    report = auditor.assert_expected(args.expect_screens)
    inventory_json = asdict(report)
    inventory_json["screen_count"] = report.screen_count
    result: dict[str, object] = {"inventory": inventory_json}
    if args.runtime:
        clicks = auditor.click_visible_controls(
            width=args.width,
            height=args.height,
            port=args.port,
            wait_ms=args.wait_ms,
            screen_ids=tuple(args.screens) or None,
        )
        result["clicks"] = [asdict(click) for click in clicks]
    sys.stdout.reconfigure(encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

