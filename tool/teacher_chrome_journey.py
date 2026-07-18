"""교사용 Flutter Web을 Chromium에서 실제 조작하는 핵심 기능 여정."""

from __future__ import annotations

import base64
import json
import sqlite3
import sys
from pathlib import Path
from time import time

import requests
from playwright.sync_api import Page, sync_playwright

sys.stdout.reconfigure(errors="backslashreplace")


BASE_URL = "http://127.0.0.1:8090"
OUTPUT_DIR = Path("design/teacher-runtime-journey")
QUEST_ID = "codex/chrome-audit/linear-001"
APP_ROOT = Path(__file__).resolve().parents[1]


# 필요 변수: 현재 Flutter Web 페이지.
# 작동 원리: 화면 밖에 있는 Flutter 접근성 활성화 요소를 DOM 이벤트로 눌러 텍스트 기반 조작을 가능하게 한다.
def enable_semantics(page: Page) -> None:
    page.wait_for_selector("flt-semantics-placeholder", timeout=30_000)
    page.locator("flt-semantics-placeholder").evaluate("element => element.click()")
    page.wait_for_timeout(500)


# 필요 변수: 페이지, 단계 이름.
# 작동 원리: 각 실제 조작 직후 화면과 접근성 텍스트를 UTF-8 로그로 남긴다.
def capture(page: Page, step: str) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    page.screenshot(path=str(OUTPUT_DIR / f"{step}.png"), full_page=True)
    print(f"STEP={step}", flush=True)
    print(f"URL={page.url}", flush=True)
    print(page.locator("body").inner_text(), flush=True)
    for index, field in enumerate(page.locator('[role="textbox"]').all()):
        print(f"TEXTBOX[{index}]={field.get_attribute('aria-label')}", flush=True)


# 필요 변수: 페이지와 화면에 표시된 정확한 문구.
# 작동 원리: 동일 문구가 여러 번 있을 때 마지막 실제 액션 항목을 클릭한다.
def click_text(page: Page, label: str) -> None:
    target = page.get_by_text(label, exact=True)
    print(f"CLICK={label} count={target.count()}", flush=True)
    target.last.click()


# 필요 변수: Chrome에서 가입한 교사 이메일·비밀번호와 quests.db 경로.
# 작동 원리: JWT의 사용자 ID에 직접 작성한 검수 문제를 연결해 장시간 생성 작업 없이 실제 학생 런타임을 점검한다.
def seed_audit_problem(email: str, password: str) -> str:
    response = requests.post(
        "http://127.0.0.1:8000/auth/teacher/login",
        json={"email": email, "password": password},
        timeout=10,
    )
    response.raise_for_status()
    token = response.json()["token"]
    payload_part = token.split(".")[1]
    payload_part += "=" * (-len(payload_part) % 4)
    user_id = json.loads(base64.urlsafe_b64decode(payload_part))["sub"]

    title = {
        "blocks": [
            {"type": "text", "content": "일차방정식 "},
            {"type": "latex", "content": "3x+5=20"},
            {"type": "text", "content": "의 해를 구하시오."},
        ]
    }
    answer = {"blocks": [{"type": "latex", "content": "x=5"}]}
    tags = ["#일차방정식", "#Chrome검수"]
    db_path = APP_ROOT / "omj" / "quests.db"
    connection = sqlite3.connect(db_path)
    cursor = connection.cursor()
    cursor.execute(
        "INSERT OR REPLACE INTO quest_header (quest_id, quest_model) VALUES (?, ?)",
        (QUEST_ID, json.dumps(["codex-chrome-audit-v1"], ensure_ascii=False)),
    )
    cursor.execute(
        """
        INSERT OR REPLACE INTO quest_info (
            quest_id, main, sub, hash_tag, flow_rate, difficulty, main_huddle,
            difficulty_tier, difficulty_score, tier_source, quality_status,
            quality_reasons, quality_checked_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            QUEST_ID,
            1,
            json.dumps(tags, ensure_ascii=False),
            json.dumps(tags, ensure_ascii=False),
            2,
            25,
            1,
            2,
            25,
            "explicit",
            "approved",
            "[]",
            int(time()),
        ),
    )
    cursor.execute(
        """
        INSERT OR REPLACE INTO quest_data (
            quest_id, quest_title, quest_image, quest_answer, question_type,
            quest_options, codebase_id, seed, hash_tag, choice_answer_index, meta_json
        ) VALUES (?, ?, NULL, ?, 'short', '[]', ?, ?, ?, NULL, ?)
        """,
        (
            QUEST_ID,
            json.dumps(title, ensure_ascii=False),
            json.dumps(answer, ensure_ascii=False),
            -20260716001,
            20260716001,
            json.dumps(tags, ensure_ascii=False),
            json.dumps({"origin": "codex_chrome_runtime_audit"}, ensure_ascii=False),
        ),
    )
    cursor.execute("DELETE FROM solve_step WHERE quest_id = ?", (QUEST_ID,))
    cursor.execute(
        """
        INSERT INTO solve_step (
            quest_id, flow, hash_tag, hint_riddle, answer_riddle, enter_huddle, branches
        ) VALUES (?, ?, ?, ?, ?, 0, '[]')
        """,
        (
            QUEST_ID,
            json.dumps({"blocks": [{"type": "text", "content": "양변에서 5를 뺀 뒤 3으로 나눈다."}]}, ensure_ascii=False),
            json.dumps(tags, ensure_ascii=False),
            json.dumps({"blocks": [{"type": "text", "content": "먼저 상수항을 이항하세요."}]}, ensure_ascii=False),
            json.dumps(answer, ensure_ascii=False),
        ),
    )
    cursor.execute(
        """
        INSERT INTO user_problem_set (
            user_id, codebase_id, seed, quest_id, question_type, hash_tags, created_at
        ) VALUES (?, ?, ?, ?, 'short', ?, datetime('now'))
        ON CONFLICT(user_id, quest_id) DO UPDATE SET
            codebase_id = excluded.codebase_id,
            seed = excluded.seed,
            question_type = excluded.question_type,
            hash_tags = excluded.hash_tags
        """,
        (
            user_id,
            -20260716001,
            20260716001,
            QUEST_ID,
            json.dumps(tags, ensure_ascii=False),
        ),
    )
    connection.commit()
    connection.close()

    # 학생 코스 런타임은 PostgreSQL 문제 저장소를 읽으므로 같은 문제 계약을 즉시 동기화한다.
    sys.path.insert(0, str(APP_ROOT / "omj"))
    from storage.postgres_problem_store import postgres_problem_store
    from storage.storage import get_quest

    quest = get_quest(QUEST_ID)
    if not quest:
        raise RuntimeError(f"SQLite 검수 문제를 다시 읽지 못했습니다: {QUEST_ID}")
    postgres_problem_store.upsert_problem(quest, strict=True)
    print(f"DB_SEEDED quest_id={QUEST_ID} user_id={user_id}", flush=True)
    return QUEST_ID


# 필요 변수: 교사용 앱의 시작 URL.
# 작동 원리: 교사 회원가입 후 저장된 토큰으로 대시보드가 즉시 열리는지 확인하고 코스 생성까지 진행한다.
def run_teacher_journey(page: Page) -> None:
    page.goto(BASE_URL, wait_until="domcontentloaded", timeout=60_000)
    page.wait_for_timeout(4_000)
    enable_semantics(page)
    capture(page, "01-login")
    if page.get_by_text("게스트로 계속하기", exact=True).count() > 0:
        raise RuntimeError("교사 권한이 없는 게스트 진입 버튼이 다시 노출되었습니다.")
    page.get_by_text("회원가입", exact=True).click()
    page.wait_for_timeout(1_500)
    capture(page, "03-register")

    email = f"codex.chrome.{int(time())}@aiflow.local"
    password = "CodexTest!2026"
    for x, y, value in (
        (720, 282, "Codex Chrome Teacher"),
        (720, 346, email),
        (720, 410, password),
        (720, 474, password),
    ):
        page.mouse.click(x, y)
        page.keyboard.press("Control+A")
        page.keyboard.type(value, delay=20)
        page.wait_for_timeout(250)
    capture(page, "03b-register-filled")
    page.mouse.click(720, 549)
    page.wait_for_timeout(3_000)
    capture(page, "04-after-register")
    if "register" in page.url:
        raise RuntimeError("회원가입 직후 교사 대시보드로 이동하지 못했습니다.")

    if "register" not in page.url:
        seed_audit_problem(email, password)
        page.goto(BASE_URL, wait_until="domcontentloaded", timeout=60_000)
        page.wait_for_timeout(4_000)
        if page.locator("flt-semantics-placeholder").count() > 0:
            enable_semantics(page)
        capture(page, "05-dashboard")
        click_text(page, "코스 생성")
        page.wait_for_timeout(4_000)
        capture(page, "06-course-builder")
        page.mouse.click(700, 366)
        page.keyboard.type(f"Codex Chrome Course {int(time())}", delay=20)
        page.mouse.click(1360, 435)
        click_text(page, "학습 모듈")
        page.wait_for_timeout(1_000)
        capture(page, "07-course-modules")
        page.mouse.click(1000, 528)
        page.wait_for_timeout(500)
        capture(page, "07b-module-types")
        page.mouse.click(900, 576)
        page.wait_for_timeout(1_000)
        capture(page, "08-problem-module")
        click_text(page, "문서함에서 선택")
        page.wait_for_timeout(3_000)
        capture(page, "09-problem-library")
        page.mouse.click(216, 305)
        click_text(page, "추가")
        page.wait_for_timeout(1_000)
        page.mouse.click(1000, 472)
        page.keyboard.type("Chrome 검수 일차방정식", delay=20)
        capture(page, "10-problem-linked")
        click_text(page, "저장")
        page.wait_for_timeout(5_000)
        capture(page, "11-course-saved")


# 필요 변수: 없음.
# 작동 원리: Chromium 네트워크와 콘솔 로그를 켠 뒤 교사용 사용자 여정을 실행한다.
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
        run_teacher_journey(page)
        browser.close()


if __name__ == "__main__":
    main()
