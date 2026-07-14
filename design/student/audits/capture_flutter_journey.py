"""Flutter Web 화면을 실제 스크롤·클릭하며 구간별 PNG로 기록한다."""

from __future__ import annotations

import argparse
import contextlib
import http.server
import socketserver
import threading
import time
from pathlib import Path

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[3]
FLUTTER_WEB_ROOT = ROOT / "build" / "web"
HTML_ROOT = ROOT / "design" / "student"
PREVIEW_ROOT = HTML_ROOT / "previews"
EDGE = Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")


class _QuietHandler(http.server.SimpleHTTPRequestHandler):
    """필요 변수는 Web 산출물 경로다.

    작동 원리는 HTTP 요청 로그를 숨기고 Flutter 빌드 파일만 UTF-8 경로로 제공하는 것이다.
    """

    def log_message(self, _format: str, *args: object) -> None:
        return


class _ReusableServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True


@contextlib.contextmanager
def _serve(port: int, web_root: Path):
    """필요 변수는 로컬 포트와 Flutter 또는 HTML 산출물 경로다.

    작동 원리는 지정한 UTF-8 웹 루트를 별도 스레드로 열고 감사 종료 시 소켓까지 닫는 것이다.
    """

    handler = lambda *args, **kwargs: _QuietHandler(  # noqa: E731
        *args, directory=str(web_root), **kwargs
    )
    server = _ReusableServer(("127.0.0.1", port), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)


def _parse_click(value: str) -> tuple[int, int]:
    """필요 변수는 `x,y` 클릭 문자열이다.

    작동 원리는 두 정수 좌표로 검증·변환해 실제 브라우저 포인터 입력에 사용하는 것이다.
    """

    x, y = value.split(",", 1)
    return int(x), int(y)


def capture(args: argparse.Namespace) -> None:
    """필요 변수는 화면 ID·viewport·스크롤 횟수·선택 클릭 좌표다.

    작동 원리는 실제 Edge에서 Flutter를 열고 각 휠 이동 및 클릭 뒤 안정화된 viewport를 PNG로 저장하는 것이다.
    """

    flutter_source = args.source == "flutter"
    web_root = FLUTTER_WEB_ROOT if flutter_source else HTML_ROOT
    entry = "index.html" if flutter_source else "full_face_preview.html"
    if not web_root.joinpath(entry).is_file():
        raise FileNotFoundError(f"감사 진입 파일이 없습니다: {web_root / entry}")
    if not EDGE.is_file():
        raise FileNotFoundError(f"Microsoft Edge를 찾을 수 없습니다: {EDGE}")
    journey = "flutter-journeys" if flutter_source else "html-journeys"
    output_dir = PREVIEW_ROOT / journey / args.screen / f"{args.width}x{args.height}"
    if args.action:
        output_dir = output_dir / args.action
    output_dir.mkdir(parents=True, exist_ok=True)
    query = f"screen={args.screen}"
    if flutter_source:
        query = f"width={args.width}&height={args.height}&{query}"
    if args.action:
        query = f"{query}&action={args.action}"
    url = f"http://127.0.0.1:{args.port}/{entry}?{query}"
    with _serve(args.port, web_root), sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            executable_path=str(EDGE),
            headless=True,
            args=["--disable-gpu", "--hide-scrollbars"],
        )
        page = browser.new_page(viewport={"width": args.width, "height": args.height})
        page.goto(url, wait_until="networkidle")
        page.wait_for_timeout(args.wait_ms)
        page.screenshot(path=output_dir / "scroll-00.png")
        for index in range(1, args.steps + 1):
            page.mouse.move(args.width // 2, args.height // 2)
            page.mouse.wheel(0, args.scroll_by)
            page.wait_for_timeout(450)
            page.screenshot(path=output_dir / f"scroll-{index:02d}.png")
        for click_index, click in enumerate(args.click, start=1):
            x, y = _parse_click(click)
            page.mouse.click(x, y)
            page.wait_for_timeout(600)
            page.screenshot(path=output_dir / f"click-{click_index:02d}-{x}-{y}.png")
        browser.close()


def main() -> None:
    """필요 변수는 명령행의 감사 대상과 상호작용 옵션이다.

    작동 원리는 UTF-8 경로를 유지한 채 기본 500px 화면을 여러 구간으로 기록하는 것이다.
    """

    parser = argparse.ArgumentParser()
    parser.add_argument("--screen", required=True)
    parser.add_argument("--source", choices=("flutter", "html"), default="flutter")
    parser.add_argument("--action", default="")
    parser.add_argument("--width", type=int, default=500)
    parser.add_argument("--height", type=int, default=1000)
    parser.add_argument("--steps", type=int, default=4)
    parser.add_argument("--scroll-by", type=int, default=720)
    parser.add_argument("--click", action="append", default=[])
    parser.add_argument("--wait-ms", type=int, default=2500)
    parser.add_argument("--port", type=int, default=8981)
    args = parser.parse_args()
    started = time.perf_counter()
    capture(args)
    elapsed = time.perf_counter() - started
    print(f"Captured {args.screen}: {args.steps + 1} scroll states, {len(args.click)} clicks, {elapsed:.1f}s")


if __name__ == "__main__":
    main()
