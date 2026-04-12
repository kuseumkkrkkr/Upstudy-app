"""
PyQt 디버그 창: 통합 문제 생성 파이프라인(프롬프트 → 코드 생성 → diff 리페어 → 실행/검증) 수동 조작용.

실행: python omj/generater/debug_prob.py
필수: PyQt5, COMETAPI_KEY, generater 모듈.
"""

from __future__ import annotations

import json
import sys
import traceback
from pathlib import Path
from typing import Any, Callable, Dict, Optional

from PyQt5 import QtCore, QtWidgets

# 경로 추가(프로젝트 루트)
PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from generater.codebase_gen import (
    _build_generation_prompt,
    _extract_code_text,
    _request_code,
    generate_codebase,
)
from generater.codebase_repair import repair_codebase
from generater.codebase_runner import run_codebase, validate_result


class WorkerSignals(QtCore.QObject):
    finished = QtCore.pyqtSignal(object)
    failed = QtCore.pyqtSignal(str)


class Worker(QtCore.QRunnable):
    def __init__(self, fn: Callable, *args: Any, **kwargs: Any) -> None:
        super().__init__()
        self.fn = fn
        self.args = args
        self.kwargs = kwargs
        self.signals = WorkerSignals()

    def run(self) -> None:  # type: ignore[override]
        try:
            result = self.fn(*self.args, **self.kwargs)
            self.signals.finished.emit(result)
        except Exception:
            self.signals.failed.emit(traceback.format_exc())


def _blocks_to_text(blocks: Any) -> str:
    try:
        if isinstance(blocks, dict) and "blocks" in blocks:
            parts = [str(b.get("content", "")).strip() for b in blocks.get("blocks", [])]
            return "\n".join(p for p in parts if p)
        if isinstance(blocks, list):
            parts = []
            for b in blocks:
                if isinstance(b, dict):
                    parts.append(str(b.get("content", "")).strip())
                else:
                    parts.append(str(b))
            return "\n".join(p for p in parts if p)
    except Exception:
        pass
    return str(blocks or "").strip()


def render_problem(
    code_text: str,
    seed: Optional[int],
    *,
    tags: list[str],
    solves: int,
    branches: int,
    main_huddle: int,
) -> Dict[str, Any]:
    entry = {"code": code_text}
    result = run_codebase(entry, seed)
    validated = validate_result(
        result,
        fallback_hash_tags=tags,
        expected_solves=solves,
        expected_branches=branches,
        main_huddle=main_huddle,
    )
    problem = validated.get("problem")
    solution = validated.get("solution")
    return {
        "problem": _blocks_to_text(problem),
        "answer": validated.get("answer"),
        "solution": _blocks_to_text(solution),
        "meta": validated.get("meta"),
    }


class DebugWindow(QtWidgets.QWidget):
    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("Unified Problem Generator Debug")
        self.thread_pool = QtCore.QThreadPool.globalInstance()
        self.base_prompt: Optional[str] = None
        self.code_latest: Optional[str] = None
        self.last_error: Optional[str] = None
        self._build_ui()

    def _build_ui(self) -> None:
        layout = QtWidgets.QVBoxLayout(self)

        form = QtWidgets.QFormLayout()
        self.tags_edit = QtWidgets.QLineEdit("math, algebra")
        self.difficulty_spin = QtWidgets.QSpinBox(); self.difficulty_spin.setRange(0, 50); self.difficulty_spin.setValue(10)
        self.solves_spin = QtWidgets.QSpinBox(); self.solves_spin.setRange(1, 5); self.solves_spin.setValue(2)
        self.strategy_spin = QtWidgets.QSpinBox(); self.strategy_spin.setRange(1, 3); self.strategy_spin.setValue(2)
        self.branch_spin = QtWidgets.QSpinBox(); self.branch_spin.setRange(0, 5); self.branch_spin.setValue(1)
        self.max_attempts_spin = QtWidgets.QSpinBox(); self.max_attempts_spin.setRange(1, 5); self.max_attempts_spin.setValue(3)
        self.seed_spin = QtWidgets.QSpinBox(); self.seed_spin.setRange(0, 1_000_000_000); self.seed_spin.setValue(0)

        form.addRow("Tags (comma)", self.tags_edit)
        form.addRow("difficulty", self.difficulty_spin)
        form.addRow("solves_count", self.solves_spin)
        form.addRow("strategy_level", self.strategy_spin)
        form.addRow("branch_conditions", self.branch_spin)
        form.addRow("max_attempts", self.max_attempts_spin)
        form.addRow("seed (0=random)", self.seed_spin)
        layout.addLayout(form)

        btn_layout = QtWidgets.QHBoxLayout()
        self.btn_prompt = QtWidgets.QPushButton("1. Build Prompt")
        self.btn_llm = QtWidgets.QPushButton("2. LLM Generate")
        self.btn_repair = QtWidgets.QPushButton("3. Diff Repair")
        self.btn_validate = QtWidgets.QPushButton("4. Validate & Render")
        self.btn_auto = QtWidgets.QPushButton("5. Auto Generate (unified)")
        for b in (self.btn_prompt, self.btn_llm, self.btn_repair, self.btn_validate, self.btn_auto):
            btn_layout.addWidget(b)
        layout.addLayout(btn_layout)

        self.prompt_edit = QtWidgets.QPlainTextEdit(); self.prompt_edit.setPlaceholderText("생성/편집 프롬프트")
        self.code_edit = QtWidgets.QPlainTextEdit(); self.code_edit.setReadOnly(True); self.code_edit.setPlaceholderText("생성된 코드")
        self.error_edit = QtWidgets.QPlainTextEdit(); self.error_edit.setReadOnly(True); self.error_edit.setPlaceholderText("오류 메시지 / diff")
        self.result_edit = QtWidgets.QPlainTextEdit(); self.result_edit.setReadOnly(True); self.result_edit.setPlaceholderText("렌더된 문제/정답/해설")

        layout.addWidget(QtWidgets.QLabel("Prompt"))
        layout.addWidget(self.prompt_edit)
        layout.addWidget(QtWidgets.QLabel("Code"))
        layout.addWidget(self.code_edit)
        layout.addWidget(QtWidgets.QLabel("Errors / Diff"))
        layout.addWidget(self.error_edit)
        layout.addWidget(QtWidgets.QLabel("Rendered Problem"))
        layout.addWidget(self.result_edit)

        self.btn_prompt.clicked.connect(self.handle_build_prompt)
        self.btn_llm.clicked.connect(self.handle_llm_generate)
        self.btn_repair.clicked.connect(self.handle_repair_prompt)
        self.btn_validate.clicked.connect(self.handle_validate_render)
        self.btn_auto.clicked.connect(self.handle_auto_generate)

    def log_error(self, msg: str) -> None:
        self.last_error = msg
        self.error_edit.setPlainText(msg)

    def run_async(self, fn: Callable, on_success: Callable[[Any], None]) -> None:
        worker = Worker(fn)
        worker.signals.finished.connect(on_success)
        worker.signals.failed.connect(self.log_error)
        self.thread_pool.start(worker)

    def _current_tags(self) -> list[str]:
        return [t.strip() for t in self.tags_edit.text().split(",") if t.strip()]

    def handle_build_prompt(self) -> None:
        tags = self._current_tags()
        prompt = _build_generation_prompt(
            hash_tags=tags,
            solves_count=self.solves_spin.value(),
            branch_conditions=self.branch_spin.value(),
            main_huddle=self.strategy_spin.value(),
        )
        self.base_prompt = prompt
        self.prompt_edit.setPlainText(prompt)
        self.log_error("")

    def handle_llm_generate(self) -> None:
        prompt = self.prompt_edit.toPlainText().strip()
        if not prompt:
            self.log_error("프롬프트가 비었습니다.")
            return
        tags = self._current_tags()

        def task() -> Dict[str, Any]:
            raw = _request_code(prompt)
            code_text = _extract_code_text(raw)
            error = None
            try:
                validate_result(
                    run_codebase({"code": code_text}, seed=None),
                    fallback_hash_tags=tags,
                    expected_solves=self.solves_spin.value(),
                    expected_branches=self.branch_spin.value(),
                    main_huddle=self.strategy_spin.value(),
                )
            except Exception as exc:  # pragma: no cover
                error = str(exc)
            return {"code": code_text, "error": error}

        def done(payload: Dict[str, Any]) -> None:
            self.code_latest = payload.get("code") or ""
            self.code_edit.setPlainText(self.code_latest)
            self.log_error(payload.get("error") or "")

        self.run_async(task, done)

    def handle_repair_prompt(self) -> None:
        if not self.code_latest:
            self.log_error("수정할 코드가 없습니다.")
            return
        if not self.last_error:
            self.log_error("최근 오류가 없어 diff 리페어를 수행할 수 없습니다.")
            return
        try:
            repaired = repair_codebase(
                prompt=self.prompt_edit.toPlainText() or (self.base_prompt or ""),
                code_text=self.code_latest,
                error_message=self.last_error,
            )
            self.code_latest = repaired.get("code")
            self.code_edit.setPlainText(self.code_latest or "")
            self.log_error(repaired.get("diff", ""))
        except Exception as exc:
            self.log_error(str(exc))

    def handle_validate_render(self) -> None:
        if not self.code_latest:
            self.log_error("생성된 코드가 없습니다.")
            return
        seed_val = self.seed_spin.value() or None
        tags = self._current_tags()

        def task() -> Dict[str, Any]:
            return render_problem(
                self.code_latest,
                seed_val,
                tags=tags,
                solves=self.solves_spin.value(),
                branches=self.branch_spin.value(),
                main_huddle=self.strategy_spin.value(),
            )

        def done(result: Dict[str, Any]) -> None:
            pretty = json.dumps(result, ensure_ascii=False, indent=2)
            self.result_edit.setPlainText(pretty)
            self.log_error("")

        self.run_async(task, done)

    def handle_auto_generate(self) -> None:
        tags = self._current_tags()
        if not tags:
            self.log_error("tags가 비었습니다.")
            return
        seed_val = self.seed_spin.value() or None
        max_attempts = self.max_attempts_spin.value()

        def task() -> Dict[str, Any]:
            entry = generate_codebase(
                tags=tags,
                difficulty=self.difficulty_spin.value(),
                solves_count=self.solves_spin.value(),
                strategy_level=self.strategy_spin.value(),
                branch_conditions=self.branch_spin.value(),
                max_attempts=max_attempts,
            )
            code_text = entry.get("code", "")
            rendered = render_problem(
                code_text,
                seed_val,
                tags=tags,
                solves=self.solves_spin.value(),
                branches=self.branch_spin.value(),
                main_huddle=self.strategy_spin.value(),
            )
            return {"entry": entry, "rendered": rendered, "code": code_text}

        def done(payload: Dict[str, Any]) -> None:
            entry = payload.get("entry", {})
            self.base_prompt = entry.get("prompt")
            self.code_latest = payload.get("code")
            self.prompt_edit.setPlainText(entry.get("prompt", ""))
            self.code_edit.setPlainText(self.code_latest or "")
            pretty = json.dumps(payload.get("rendered", {}), ensure_ascii=False, indent=2)
            self.result_edit.setPlainText(pretty)
            self.log_error("")

        self.run_async(task, done)


def main() -> None:
    app = QtWidgets.QApplication(sys.argv)
    win = DebugWindow()
    win.resize(1000, 800)
    win.show()
    sys.exit(app.exec_())


if __name__ == "__main__":
    main()
