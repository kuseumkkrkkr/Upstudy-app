"""학생 앱 AI 학습 튜터 화면을 모바일·데스크톱 PNG로 캡처한다."""

from __future__ import annotations

from pathlib import Path

from playwright.sync_api import Page, sync_playwright

BASE_URL = "http://127.0.0.1:8092/#/tools"
OUTPUT_DIR = Path("design/student/previews/flutter-implementation")


# 필요한 변수: Flutter Web 페이지와 출력 파일명.
# 작동 원리: 첫 프레임과 웹 폰트 렌더를 기다린 뒤 현재 viewport 전체를 PNG로 저장한다.
def capture(page: Page, filename: str) -> None:
    page.on("console", lambda message: print(f"CONSOLE[{message.type}] {message.text}"))
    page.on("pageerror", lambda error: print(f"PAGE_ERROR {error}"))
    page.goto(BASE_URL, wait_until="domcontentloaded", timeout=60_000)
    page.wait_for_selector(
        "flutter-view, flt-glass-pane", state="attached", timeout=60_000
    )
    page.wait_for_timeout(5_000)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_path = OUTPUT_DIR / filename
    page.screenshot(path=str(output_path), full_page=False)
    print(output_path.resolve())


# 필요한 변수: 로컬 8092 포트에서 실행 중인 Flutter Web 앱.
# 작동 원리: 하나의 headless Chromium에서 두 viewport를 독립 페이지로 열어 비교 가능한 캡처를 만든다.
def main() -> None:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        mobile = browser.new_page(viewport={"width": 390, "height": 844})
        desktop = browser.new_page(viewport={"width": 1280, "height": 900})
        capture(mobile, "ai-tutor-after-390.png")
        capture(desktop, "ai-tutor-after-1280.png")
        browser.close()


if __name__ == "__main__":
    main()
