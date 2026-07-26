from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass
from typing import Any, Optional, cast

from k_wolfram_alpha_loop import run_continuous_generation_grading
from wolfram_rule_based_generator import build_blueprint
from rule_based_nlp import build_solution_trace, classify, solve_rule


def _qt_import_error_text() -> str:
    """필요 변수: 없음
    설명: PyQt5 미설치 시 사용자에게 설치 안내 메시지와 함께 앱 실행을 중단한다."""
    return (
        "PyQt5가 설치되어 있지 않습니다.\n"
        "설치 후 다시 실행해 주세요.\n\n"
        "python -m pip install PyQt5"
    )


def _to_int(value: str, default: int) -> int:
    """필요 변수: value, default
    설명: 입력 문자열을 안전하게 int로 변환한다."""
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _safe_json(payload: Any) -> str:
    """필요 변수: payload
    설명: UI 텍스트 표시용으로 JSON을 UTF-8 친화 포맷으로 만든다."""
    return json.dumps(payload, ensure_ascii=False, indent=2)


def _extract_tags_from_question(question: str) -> list[str]:
    """필요 변수: question
    설명: 직접문제의 키워드만 사용해서 규칙 기반 fallback을 위한 태그 후보를 만든다."""
    text = question.replace(" ", "")
    tags: list[str] = []
    if "aₙ" in text or "a_n" in text or "등차수열" in text:
        tags.append("#등차수열")
    if "x²" in text or "x^2" in text or "이차" in text:
        tags.append("#이차방정식")
    if "집합" in text or "합집합" in text or "|A|" in text:
        tags.append("#집합")
    if "경우의 수" in text or "조합" in text:
        tags.append("#경우의수")
    if not tags:
        tags.append("#수학")
    return tags


def _solve_direct_question(question: str) -> dict[str, Any]:
    """??? ?? 1?? ?? ???(??? ????)."""
    q = (question or "").strip()
    try:
        import unicodedata

        def _norm_digits(text: str) -> str:
            out = []
            for ch in text:
                if ch == "-":
                    out.append(ch)
                    continue
                try:
                    d = unicodedata.digit(ch)
                    out.append(str(d))
                except Exception:
                    out.append(ch)
            return "".join(out)

        q_norm = _norm_digits(q)
    except Exception:
        q_norm = q
    if not q:
        return {
            "status": "FAIL",
            "expected": "",
            "reason": "??? ?? ????.",
            "question": q,
            "steps": [],
        }

    # 1) ????: a? = a? + d(n-1)
    seq_match = re.search(r"a[0-9]\s*=\s*([+\-\d]+)\s*\+\s*\(?([+\-\d]+)\)?\s*\(\s*n\s*[-+]\s*1\)\s*.*a[0-9]", q_norm.replace(",", ""))
    if seq_match:
        a1 = int(seq_match.group(1))
        d = int(seq_match.group(2))
        expected = a1 + 2 * d
        return {
            "status": "PASS",
            "expected": str(expected),
            "reason": "???? ????? a3 = a1 + 2d ??",
            "question": q,
            "steps": [f"a3 = {a1} + 2?{d}", f"?? {expected}"],
        }

    # 2) ?????: ax^2 + bx + c = 0
    quad_match = re.search(
        r"([+-]?\d+)\s*\*?\s*x\^2\s*([+-]\s*[+-]?\d+)\s*x\s*([+-]\s*[+-]?\d+)\s*=\s*0",
        q_norm.replace(" ", ""),
    )
    if quad_match:
        a = int(quad_match.group(1))
        b = int(quad_match.group(2))
        c = int(quad_match.group(3))
        if a == 0:
            return {
                "status": "FAIL",
                "expected": "",
                "reason": "?????? ?? ?????.",
                "question": q,
                "steps": [],
            }
        disc = b * b - 4 * a * c
        if disc < 0:
            return {
                "status": "FAIL",
                "expected": "",
                "reason": "???? ???? ??? ???? ?? ??.",
                "question": q,
                "steps": [],
            }
        root = int(disc ** 0.5)
        if root * root != disc:
            return {
                "status": "FAIL",
                "expected": "",
                "reason": "???? ????? ??? ??? ???? ?? ??.",
                "question": q,
                "steps": [],
            }
        den = 2 * a
        for num in (-(b) + root, -(b) - root):
            if num % den == 0:
                return {
                    "status": "PASS",
                    "expected": str(num // den),
                    "reason": "????? ??? ??",
                    "question": q,
                    "steps": [f"D = {disc}", f"x = (-b ? ?D) / (2a) = {num // den}"],
                }
        return {
            "status": "FAIL",
            "expected": "",
            "reason": "???? ?? PASS ?? ??",
            "question": q,
            "steps": [],
        }

    # 3) ??: |A|, |B|, |A?B|? ??? ??
    set_match = re.search(r"\|A\|\s*=\s*([+-]?\d+).*?\|B\|\s*=\s*([+-]?\d+).*?\|A\?\?B\|\s*=\s*([+-]?\d+)", q.replace(" ", ""))
    if set_match:
        a = int(set_match.group(1))
        b = int(set_match.group(2))
        c = int(set_match.group(3))
        expected = a + b - c
        return {
            "status": "PASS",
            "expected": str(expected),
            "reason": "??? ?? |A?B| = |A| + |B| - |A?B|",
            "question": q,
            "steps": [f"{a} + {b} - {c} = {expected}"],
        }

    # 4) 지식 규칙 계산기: 직접 입력을 NLP 슬롯으로 변환한 뒤 공통 검산기를 사용한다.
    try:
        nlp = classify(q)
        rule_result = solve_rule(nlp.get("domain", ""), nlp.get("slots", {}))
        if rule_result.get("status") == "PASS" and float(nlp.get("confidence", 0.0)) >= 0.5:
            return {
                "status": "PASS" if rule_result.get("verified", True) else "FAIL",
                "expected": str(rule_result.get("answer", "")),
                "reason": f"규칙 {nlp.get('domain')} 적용 및 재검산 완료",
                "question": q,
                "steps": build_solution_trace(nlp, rule_result),
            }
        if nlp.get("rules") and float(nlp.get("confidence", 0.0)) >= 0.5 and rule_result.get("status") == "FAIL":
            return {
                "status": "FAIL",
                "expected": "",
                "reason": str(rule_result.get("reason", "규칙 계산 조건을 만족하지 않습니다.")),
                "question": q,
                "steps": [f"도메인: {nlp.get('domain')}", f"추출 변수: {nlp.get('slots')}"],
            }
    except Exception:
        pass

    # 5) fallback: 기존 템플릿 생성기로 처리하고 실패 시 구조화된 FAIL을 반환한다.
    try:
        nlp = classify(q)
        tags = nlp.get("tags") or _extract_tags_from_question(q)
        if nlp.get("domain") == "cm_algebra_basic" and not nlp.get("rules"):
            return {
                "status": "FAIL",
                "expected": "",
                "reason": "지원되는 수학 유형을 해석하지 못했습니다.",
                "question": q,
                "steps": [],
            }
        required = [item for rule in nlp.get("rules", []) for item in rule.get("conditions", {}).get("requires", [])]
        slots = nlp.get("slots", {})
        missing = [item for item in required if item not in slots]
        if missing and nlp.get("domain") != "cm_algebra_basic":
            return {
                "status": "FAIL",
                "expected": "",
                "reason": f"필수 조건을 해석하지 못했습니다: {', '.join(missing)}",
                "question": q,
                "steps": [],
            }
        blueprint = build_blueprint(tags=tags, prompt=q, raw_flowchart=None, seed=2026)
    except Exception as exc:  # noqa: BLE001
        return {
            "status": "FAIL",
            "expected": "",
            "reason": f"fallback ?? ?? ??: {exc}",
            "question": q,
            "steps": [],
        }
    return {
        "status": "PASS",
        "expected": str(blueprint.answer),
        "reason": "?? ?? fallback ?? ??",
        "question": blueprint.prompt,
        "steps": blueprint.flow_steps,
    }




@dataclass
class UiBundle:
    """필요 변수: 앱 위젯 전체
    설명: 핸들러에서 공통으로 접근할 UI 객체 묶음."""
    window: Any
    case_input: Any
    repeat_input: Any
    min_grade_input: Any
    max_grade_input: Any
    retry_input: Any
    seed_input: Any
    loop_start_btn: Any
    loop_status_label: Any
    loop_status_text: Any
    loop_table: Any
    direct_question_input: Any
    direct_result_text: Any
    direct_solve_btn: Any


def _build_table_rows(cases: list[dict[str, Any]]) -> list[list[str]]:
    """필요 변수: cases
    설명: 루프 결과 목록을 테이블 row 문자열 배열로 변환한다."""
    rows: list[list[str]] = []
    for item in cases:
        rows.append(
            [
                str(item.get("problem_id", "")),
                str(item.get("question_type", "")),
                str(item.get("school_grade_code", "")),
                str(item.get("grade_status", "")),
                str(item.get("grade_score", "")),
                str(item.get("retry_count", "")),
                str(item.get("reason", "")),
            ]
        )
    return rows


def _apply_rows_to_table(table: Any, rows: list[list[str]]) -> None:
    """필요 변수: table, rows
    설명: QTableWidget에 행 데이터 반영."""
    from PyQt5.QtWidgets import QTableWidgetItem

    table.setRowCount(len(rows))
    for r, row in enumerate(rows):
        for c, value in enumerate(row):
            table.setItem(r, c, QTableWidgetItem(value))


class _LoopWorker:
    """필요 변수: params
    설명: 단일 실행 단위의 루프 파라미터를 가지고 동기 run_continuous_generation_grading 호출."""

    def __init__(
        self,
        *,
        case_count: int,
        repeat_per_case: int,
        min_grade: int,
        max_grade: int,
        max_scope_retry: int,
        seed: int,
    ) -> None:
        self.case_count = case_count
        self.repeat_per_case = repeat_per_case
        self.min_grade = min_grade
        self.max_grade = max_grade
        self.max_scope_retry = max_scope_retry
        self.seed = seed
        self.result: Optional[dict[str, Any]] = None
        self.error: Optional[str] = None

    def run(self) -> None:
        """필요 변수: 없음
        설명: 루프 실행 결과를 result/error에 저장한다."""
        try:
            self.result = run_continuous_generation_grading(
                case_count=self.case_count,
                repeat_per_case=self.repeat_per_case,
                min_grade=self.min_grade,
                max_grade=self.max_grade,
                max_scope_retry=self.max_scope_retry,
                seed=self.seed,
            )
        except Exception as exc:  # noqa: BLE001
            self.error = str(exc)


def run_beta_app() -> int:
    """필요 변수: 없음
    설명: PyQt5 베타 앱 실행. 루프 모드와 직접문제 모드를 함께 제공."""
    try:
        from PyQt5.QtCore import Qt, QThread, pyqtSignal
        from PyQt5.QtWidgets import (
            QApplication,
            QFormLayout,
            QLabel,
            QLineEdit,
            QMainWindow,
            QPushButton,
            QSplitter,
            QTableWidget,
            QTextEdit,
            QVBoxLayout,
            QWidget,
            QHBoxLayout,
            QMessageBox,
        )
    except Exception:
        print(_qt_import_error_text())
        return 1

    class LoopThread(QThread):
        finished_ok = pyqtSignal(dict)
        failed = pyqtSignal(str)

        def __init__(self, worker: _LoopWorker) -> None:
            super().__init__()
            self.worker = worker

        def run(self) -> None:  # noqa: D401
            self.worker.run()
            if self.worker.error:
                self.failed.emit(self.worker.error)
            else:
                report = cast(dict[str, Any], self.worker.result or {})
                self.finished_ok.emit(report)

    class DirectThread(QThread):
        solved = pyqtSignal(dict)

        def __init__(self, question: str) -> None:
            super().__init__()
            self.question = question

        def run(self) -> None:
            self.solved.emit(_solve_direct_question(self.question))

    app = QApplication.instance() or QApplication(sys.argv)
    win = QMainWindow()
    win.setWindowTitle("K-울프럼알파 베타 앱 (루프 + 직접문제)")
    win.resize(1320, 760)

    case_input = QLineEdit("20")
    repeat_input = QLineEdit("5")
    min_grade_input = QLineEdit("1")
    max_grade_input = QLineEdit("9")
    retry_input = QLineEdit("1")
    seed_input = QLineEdit("777")

    direct_question_input = QTextEdit()
    direct_question_input.setPlaceholderText("문제를 그대로 입력해 주세요.\n예: aₙ = 5 + (3)(n-1)일 때, a3의 값은?")
    direct_question_input.setMinimumHeight(120)
    direct_result_text = QTextEdit()
    direct_result_text.setReadOnly(True)

    loop_start_btn = QPushButton("루프 실행")
    direct_solve_btn = QPushButton("문제 풀기")

    loop_status_label = QLabel("준비됨")
    loop_status_text = QTextEdit()
    loop_status_text.setReadOnly(True)
    loop_status_text.setMinimumHeight(110)

    loop_table = QTableWidget(0, 7)
    loop_table.setHorizontalHeaderLabels(["문항ID", "유형", "난이도", "채점결과", "점수", "재시도", "사유"])
    loop_table.setAlternatingRowColors(True)
    loop_table.setSortingEnabled(True)

    form = QFormLayout()
    form.addRow("사례 수", case_input)
    form.addRow("반복 수", repeat_input)
    form.addRow("최소 난이도", min_grade_input)
    form.addRow("최대 난이도", max_grade_input)
    form.addRow("범위 이탈 재시도", retry_input)
    form.addRow("seed", seed_input)
    form.addRow(loop_start_btn)

    left = QWidget()
    l = QVBoxLayout(left)
    l.addLayout(form)
    l.addWidget(loop_status_label)
    l.addWidget(loop_table)
    l.addWidget(loop_status_text)

    right = QWidget()
    r = QVBoxLayout(right)
    r.addWidget(QLabel("직접문제 입력"))
    r.addWidget(direct_question_input)
    r.addWidget(direct_solve_btn)
    r.addWidget(QLabel("풀이 결과"))
    r.addWidget(direct_result_text)

    splitter = QSplitter()
    splitter.addWidget(left)
    splitter.addWidget(right)
    splitter.setSizes([720, 560])

    root = QWidget()
    root_layout = QHBoxLayout(root)
    root_layout.addWidget(splitter)
    win.setCentralWidget(root)

    ui = UiBundle(
        window=win,
        case_input=case_input,
        repeat_input=repeat_input,
        min_grade_input=min_grade_input,
        max_grade_input=max_grade_input,
        retry_input=retry_input,
        seed_input=seed_input,
        loop_start_btn=loop_start_btn,
        loop_status_label=loop_status_label,
        loop_status_text=loop_status_text,
        loop_table=loop_table,
        direct_question_input=direct_question_input,
        direct_result_text=direct_result_text,
        direct_solve_btn=direct_solve_btn,
    )

    active_loop_thread: list[Optional[QThread]] = [None]
    active_direct_thread: list[Optional[QThread]] = [None]

    def set_running(running: bool) -> None:
        """필요 변수: running
        설명: 실행 중 버튼 상태를 통일적으로 제어."""
        ui.loop_start_btn.setEnabled(not running)
        ui.direct_solve_btn.setEnabled(not running)

    def on_loop_done(report: dict[str, Any]) -> None:
        metadata = report.get("metadata", {})
        ui.loop_status_label.setText("완료")
        ui.loop_status_text.setPlainText(_safe_json({"metadata": metadata}))
        _apply_rows_to_table(ui.loop_table, _build_table_rows(report.get("cases", [])))
        set_running(False)
        active_loop_thread[0] = None

    def on_loop_failed(msg: str) -> None:
        ui.loop_status_label.setText("실패")
        ui.loop_status_text.setPlainText(msg)
        set_running(False)
        active_loop_thread[0] = None
        QMessageBox.warning(ui.window, "루프 실행 실패", msg)

    def on_direct_done(result: dict[str, Any]) -> None:
        ui.direct_result_text.setPlainText(
            _safe_json(
                {
                    "question": result.get("question", ""),
                    "status": result.get("status", ""),
                    "expected_answer": result.get("expected", ""),
                    "reason": result.get("reason", ""),
                    "steps": result.get("steps", []),
                }
            )
        )
        set_running(False)
        active_direct_thread[0] = None

    def on_loop_start() -> None:
        case_count = _to_int(ui.case_input.text(), 20)
        repeat_per_case = _to_int(ui.repeat_input.text(), 5)
        min_grade = _to_int(ui.min_grade_input.text(), 1)
        max_grade = _to_int(ui.max_grade_input.text(), 9)
        retry = _to_int(ui.retry_input.text(), 1)
        seed = _to_int(ui.seed_input.text(), 777)

        if min_grade > max_grade:
            QMessageBox.warning(ui.window, "입력 오류", "최소 난이도는 최대 난이도보다 클 수 없습니다.")
            return
        if case_count <= 0 or repeat_per_case <= 0:
            QMessageBox.warning(ui.window, "입력 오류", "사례 수/반복 수는 1 이상이어야 합니다.")
            return

        worker = _LoopWorker(
            case_count=case_count,
            repeat_per_case=repeat_per_case,
            min_grade=min_grade,
            max_grade=max_grade,
            max_scope_retry=retry,
            seed=seed,
        )
        thread = LoopThread(worker)
        active_loop_thread[0] = thread
        thread.finished_ok.connect(on_loop_done)
        thread.failed.connect(on_loop_failed)
        thread.finished.connect(lambda: None)
        set_running(True)
        ui.loop_status_label.setText("실행 중...")
        ui.loop_status_text.setPlainText("루프 실행 중입니다.")
        thread.start()

    def on_direct_start() -> None:
        question = ui.direct_question_input.toPlainText()
        if not question.strip():
            QMessageBox.warning(ui.window, "입력 오류", "문제를 입력해 주세요.")
            return
        thread = DirectThread(question)
        active_direct_thread[0] = thread
        thread.solved.connect(on_direct_done)
        thread.finished.connect(lambda: None)
        set_running(True)
        ui.direct_result_text.setPlainText("문제 풀이 중...")
        thread.start()

    loop_start_btn.clicked.connect(on_loop_start)
    direct_solve_btn.clicked.connect(on_direct_start)

    win.show()
    ui.loop_status_text.setPlainText(
        "안내: 왼쪽은 루프 강화 실행, 오른쪽은 직접문제 입력 풀이 모드입니다."
    )
    return app.exec_()


def main() -> int:
    """필요 변수: 없음
    설명: 앱 실행 진입점."""
    return run_beta_app()


if __name__ == "__main__":
    raise SystemExit(main())
