"""학생 Flutter Web에서 교사 생성 코스의 실제 학습 여정을 점검한다."""

from __future__ import annotations

import sys
import re
from pathlib import Path
from time import time

import requests
from playwright.sync_api import Page, sync_playwright

sys.stdout.reconfigure(errors="backslashreplace")

BASE_URL = "http://127.0.0.1:8091"
OUTPUT_DIR = Path("design/student-runtime-journey")


# 필요 변수: 학생 Flutter Web 페이지.
# 작동 원리: 접근성 레이어를 활성화해 화면 문구 기준으로 실제 UI를 클릭한다.
def enable_semantics(page: Page) -> None:
    page.wait_for_selector("flt-semantics-placeholder", timeout=30_000)
    page.locator("flt-semantics-placeholder").evaluate("element => element.click()")
    page.wait_for_timeout(500)


# 필요 변수: 페이지와 단계 이름.
# 작동 원리: 사용자 조작 결과를 UTF-8 텍스트와 전체 화면 이미지로 남긴다.
def capture(page: Page, step: str) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    page.screenshot(path=str(OUTPUT_DIR / f"{step}.png"), full_page=True)
    print(f"STEP={step}", flush=True)
    print(f"URL={page.url}", flush=True)
    print(page.locator("body").inner_text(), flush=True)


# 필요 변수: 학생 앱 시작 페이지.
# 작동 원리: 코스 탐색 메뉴를 실제 클릭하고 공개 코스 노출 여부를 기록한다.
def run_course_journey(page: Page) -> None:
    username = f"cdx{int(time())}"
    password = "Codex2026"
    register = requests.post(
        "http://127.0.0.1:8000/auth/register",
        json={
            "username": username,
            "password": password,
            "name": "Codex 학생",
            "grade": "10",
        },
        timeout=10,
    )
    register.raise_for_status()
    print(f"STUDENT_REGISTERED username={username}", flush=True)

    page.goto(BASE_URL, wait_until="domcontentloaded", timeout=60_000)
    page.wait_for_timeout(5_000)
    enable_semantics(page)
    capture(page, "01-home")
    login = page.get_by_text("로그인", exact=True)
    if login.count() > 0:
        login.last.click()
        page.wait_for_timeout(1_000)
        capture(page, "01b-login")
        page.mouse.click(720, 490)
        page.wait_for_timeout(400)
        page.keyboard.type(username, delay=60)
        page.mouse.click(720, 554)
        page.wait_for_timeout(400)
        page.keyboard.type(password, delay=100)
        capture(page, "01b-login-filled")
        page.mouse.click(720, 624)
        page.wait_for_timeout(5_000)
        capture(page, "01c-student-home")
    course_tab = page.get_by_text("코스", exact=True)
    print(f"CLICK=코스 count={course_tab.count()}", flush=True)
    if course_tab.count() == 0:
        raise RuntimeError("학생 로그인 후 코스 탭을 찾을 수 없습니다.")
    course_tab.first.click()
    page.wait_for_timeout(5_000)
    capture(page, "02-courses")
    audit_course = page.get_by_text(re.compile(r"Codex Chrome Course"))
    print(f"CLICK=Codex course count={audit_course.count()}", flush=True)
    audit_course.first.click()
    page.wait_for_timeout(3_000)
    capture(page, "03-course-detail")
    enroll = page.get_by_text("코스 등록", exact=True)
    print(f"CLICK=코스 등록 count={enroll.count()}", flush=True)
    enroll.click()
    page.wait_for_timeout(5_000)
    capture(page, "04-after-enroll")
    solve = page.get_by_text("문제 풀기", exact=True)
    print(f"CLICK=문제 풀기 count={solve.count()}", flush=True)
    solve.last.click()
    page.wait_for_timeout(5_000)
    capture(page, "05-problem-solve")
    correct_choice = page.get_by_text("① x=5", exact=True)
    print(f"CLICK=정답 x=5 count={correct_choice.count()}", flush=True)
    if correct_choice.count() == 0:
        raise RuntimeError("학생 문제 화면에서 정답 선택지를 찾을 수 없습니다.")
    correct_choice.first.click()
    page.wait_for_timeout(1_000)
    capture(page, "06-answer-selected")
    submit = page.get_by_text("제출", exact=True)
    print(f"CLICK=제출 count={submit.count()}", flush=True)
    if submit.count() > 0:
        submit.last.click()
    else:
        # Flutter 캔버스 도구막대의 제출 아이콘은 접근성 텍스트가 생략될 수 있다.
        page.mouse.click(995, 947)
    page.wait_for_timeout(5_000)
    capture(page, "07-answer-submitted")
    confirm = page.get_by_text("확인", exact=True)
    print(f"CLICK=확인 count={confirm.count()}", flush=True)
    if confirm.count() == 0:
        raise RuntimeError("정답 채점 후 확인 버튼을 찾을 수 없습니다.")
    confirm.last.click()
    page.wait_for_timeout(5_000)
    capture(page, "08-course-progress")
    passed_confirm = page.get_by_text("확인", exact=True)
    print(f"CLICK=통과 확인 count={passed_confirm.count()}", flush=True)
    if passed_confirm.count() == 0:
        raise RuntimeError("통과 결과의 확인 버튼을 찾을 수 없습니다.")
    passed_confirm.last.click()
    page.wait_for_timeout(5_000)
    capture(page, "09-module-completed")


# 필요 변수: 없음.
# 작동 원리: Chromium 콘솔·API 응답을 함께 수집하며 학생 코스 여정을 수행한다.
def main() -> None:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1440, "height": 1000})
        page.on("console", lambda message: print(f"CONSOLE[{message.type}]={message.text}", flush=True))
        page.on("pageerror", lambda error: print(f"PAGE_ERROR={error}", flush=True))
        page.on(
            "response",
            lambda response: print(f"HTTP={response.status} {response.url}", flush=True)
            if "127.0.0.1:8000" in response.url
            else None,
        )
        run_course_journey(page)
        browser.close()


if __name__ == "__main__":
    main()
