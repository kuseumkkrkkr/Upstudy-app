"""학생 HTML 시안의 화면별 스크롤 길이와 상호작용 원장을 출력한다."""

from __future__ import annotations

import json
import sys
from urllib.parse import urlencode

from playwright.sync_api import sync_playwright

from capture_flutter_journey import EDGE, HTML_ROOT, _serve


SCREENS = (
    "dashboard",
    "courses",
    "course-detail",
    "course-learning",
    "solve",
    "exam-paper",
    "wrong-answers",
    "level-test",
    "arena",
    "textbooks",
    "textbook-reader",
    "schedule",
    "groups",
    "group-detail",
    "academy",
    "friends",
    "chat",
    "marketplace",
    "tools",
    "graph",
    "flow",
    "profile",
    "settings",
    "auth",
    "signup",
)

INTERACTION_SELECTOR = ",".join(
    (
        "[data-action]",
        "[data-signup-stage]",
        "[data-signup-next]",
        "[data-group-tab]",
        "[data-review-filter]",
        "[data-setting-toggle]",
        "[data-solve-tool]",
        "[data-solve-choice]",
        "[data-exam-page]",
        "[data-exam-prev]",
        "[data-exam-next]",
        "[data-reader-view]",
        "[data-reader-tool]",
        "[data-schedule-view]",
    )
)


def _element_contract(element) -> dict[str, str]:
    """필요 변수는 HTML 상호작용 요소다.

    작동 원리는 액션 종류·값·사용자 레이블을 UTF-8 JSON 원장 한 항목으로 변환하는 것이다.
    """

    return element.evaluate(
        """node => {
          const names = [
            'data-action', 'data-signup-stage', 'data-signup-next',
            'data-group-tab', 'data-review-filter', 'data-setting-toggle',
            'data-solve-tool', 'data-solve-choice', 'data-exam-page',
            'data-exam-prev', 'data-exam-next', 'data-reader-view',
            'data-reader-tool', 'data-schedule-view'
          ];
          const name = names.find(value => node.hasAttribute(value)) || '';
          return {
            kind: name.replace('data-', ''),
            value: name ? (node.getAttribute(name) || 'toggle') : '',
            label: (node.getAttribute('aria-label') || node.innerText || '')
              .replace(/\s+/g, ' ').trim()
          };
        }"""
    )


def inventory(width: int = 500, height: int = 1000, port: int = 8986) -> dict:
    """필요 변수는 모바일 viewport와 로컬 HTML 서버 포트다.

    작동 원리는 25개 화면을 실제 Edge에서 렌더하고 문서 높이와 중복 제거된 상호작용을 수집하는 것이다.
    """

    result: dict[str, dict] = {}
    with _serve(port, HTML_ROOT), sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            executable_path=str(EDGE),
            headless=True,
            args=["--enable-unsafe-swiftshader", "--hide-scrollbars"],
        )
        page = browser.new_page(viewport={"width": width, "height": height})
        for screen in SCREENS:
            query = urlencode({"screen": screen})
            page.goto(
                f"http://127.0.0.1:{port}/full_face_preview.html?{query}",
                wait_until="networkidle",
            )
            page.wait_for_timeout(180)
            contracts = [
                _element_contract(element)
                for element in page.locator(INTERACTION_SELECTOR).all()
            ]
            unique = []
            seen = set()
            for contract in contracts:
                key = (contract["kind"], contract["value"], contract["label"])
                if key in seen:
                    continue
                seen.add(key)
                unique.append(contract)
            result[screen] = {
                "scrollHeight": page.evaluate("document.documentElement.scrollHeight"),
                "viewportHeight": height,
                "interactions": unique,
            }
        browser.close()
    return result


def main() -> None:
    """필요 변수는 고정된 25개 학생 화면이다.

    작동 원리는 감사 결과를 다른 검증 명령에서 재사용 가능한 UTF-8 JSON으로 표준 출력한다.
    """

    sys.stdout.reconfigure(encoding="utf-8")
    print(json.dumps(inventory(), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
