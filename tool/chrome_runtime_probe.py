"""Flutter Web 화면을 실제 Chromium으로 조작하는 런타임 점검 도구."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

sys.stdout.reconfigure(errors="backslashreplace")


# 필요 변수: 점검 URL, 스크린샷 경로, 대기 시간.
# 작동 원리: Chromium을 실행해 Flutter 렌더링 완료를 기다리고 접근성 트리를 활성화한 뒤 화면 정보를 출력한다.
def probe(url: str, screenshot_path: Path, wait_ms: int) -> None:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1440, "height": 1000})
        page.on("console", lambda message: print(f"CONSOLE[{message.type}]={message.text}", flush=True))
        page.on("pageerror", lambda error: print(f"PAGE_ERROR={error}", flush=True))
        page.goto(url, wait_until="commit", timeout=60_000)
        page.wait_for_timeout(wait_ms)

        placeholder = page.locator("flt-semantics-placeholder")
        if placeholder.count() > 0:
            placeholder.evaluate("element => element.click()")
            page.wait_for_timeout(1_000)

        screenshot_path.parent.mkdir(parents=True, exist_ok=True)
        page.screenshot(path=str(screenshot_path), full_page=True)
        print(f"URL={page.url}", flush=True)
        print(f"TITLE={page.title()}", flush=True)
        print("BODY_TEXT_BEGIN", flush=True)
        print(page.locator("body").inner_text(), flush=True)
        print("BODY_TEXT_END", flush=True)
        print("SEMANTICS_COUNT=" + str(page.locator("flt-semantics").count()), flush=True)
        browser.close()


# 필요 변수: 명령행 URL과 출력 파일.
# 작동 원리: 인자를 UTF-8 문자열로 받아 공통 probe 함수에 전달한다.
def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("url")
    parser.add_argument("screenshot", type=Path)
    parser.add_argument("--wait-ms", type=int, default=8_000)
    args = parser.parse_args()
    probe(args.url, args.screenshot, args.wait_ms)


if __name__ == "__main__":
    main()
