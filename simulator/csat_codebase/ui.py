from __future__ import annotations

import json
import os
import random
import time
from typing import Any, Dict, List, Optional

from PyQt5.QtCore import Qt, QThread
from PyQt5.QtGui import QTextCursor
from PyQt5.QtWidgets import (
    QApplication,
    QCheckBox,
    QComboBox,
    QGridLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QListWidget,
    QListWidgetItem,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QPlainTextEdit,
    QSpinBox,
    QWidget,
)

from .config import DEFAULT_TIER_PARAMS, PROMPT_MODES, PromptMode, TagCategory, TierParams
from .data_sources import build_tag_catalog, estimate_difficulty, load_tier_params
from .db import load_codebases, save_codebase, update_codebase
from .env_client import build_client
from .prompts import build_prompt
from .streaming import StreamWorker, estimate_tokens
from .utils import build_repair_prompt, compile_code, extract_code_text, normalize_signs


class CodebaseLab(QMainWindow):
    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("Gemini 코드베이스 시뮬레이터")
        self.setMinimumSize(1200, 820)

        self._client = build_client()
        self._model = os.environ.get("GEMINI_MODEL", "gemini-3.1-flash-lite")
        self._tag_categories = build_tag_catalog()
        self._all_tags = sorted({tag for category in self._tag_categories for tag in category.tags})
        self._all_subject_index: Optional[int] = None
        self._tier_params = load_tier_params()

        self._codebases: List[Dict[str, Any]] = load_codebases()
        self._codebase_counter = max((entry.get("id", 0) for entry in self._codebases), default=0)
        self._tag_list_updating = False

        self._mode_combo = QComboBox()
        for mode in PROMPT_MODES:
            self._mode_combo.addItem(mode.title, userData=mode)

        self._auto_prompt_check = QCheckBox("프롬프트 자동 갱신")
        self._auto_prompt_check.setChecked(True)

        self._auto_fix_check = QCheckBox("자동 복구")
        self._auto_fix_check.setChecked(True)

        self._auto_fix_retry_spin = QSpinBox()
        self._auto_fix_retry_spin.setRange(0, 5)
        self._auto_fix_retry_spin.setValue(2)

        self._generate_code_button = QPushButton("코드베이스 생성")
        self._generate_code_button.clicked.connect(self._on_generate_codebase)

        self._build_prompt_button = QPushButton("프롬프트 생성")
        self._build_prompt_button.clicked.connect(self._refresh_prompt)

        self._status_label = QLabel("대기 중")

        self._subject_combo = QComboBox()
        if self._tag_categories:
            for category in self._tag_categories:
                label = (
                    "전체" if category.grade <= 0 or category.name == "전체" else f"{category.grade}학년 · {category.name}"
                )
                self._subject_combo.addItem(label, userData=category)
                if category.grade <= 0 or category.name == "전체":
                    self._all_subject_index = self._subject_combo.count() - 1
        else:
            self._subject_combo.addItem("태그 로드 실패", userData=None)
        self._subject_combo.currentIndexChanged.connect(self._on_subject_changed)

        self._tag_list = QListWidget()
        self._tag_list.itemChanged.connect(self._on_tag_item_changed)

        self._tag_random_count = QSpinBox()
        self._tag_random_count.setRange(1, 12)
        self._tag_random_count.setValue(4)

        self._tag_random_button = QPushButton("랜덤 선택")
        self._tag_random_button.clicked.connect(self._on_random_tags)

        self._tag_clear_button = QPushButton("전체 해제")
        self._tag_clear_button.clicked.connect(self._on_clear_tags)

        self._selected_tags_view = QPlainTextEdit()
        self._selected_tags_view.setReadOnly(True)
        self._selected_tags_view.setPlaceholderText("선택된 태그가 여기에 표시됩니다.")

        self._tier_combo = QComboBox()
        for tier in sorted(self._tier_params.keys()):
            self._tier_combo.addItem(f"{tier} 티어", userData=tier)
        self._tier_combo.currentIndexChanged.connect(self._on_tier_changed)

        self._tier_detail_label = QLabel("solves: - | strategy: - | branch: - | difficulty: -")

        self._prompt_editor = QPlainTextEdit()
        self._prompt_editor.setPlaceholderText("프롬프트를 자동 생성하거나 직접 수정하세요.")

        self._code_list = QListWidget()
        self._code_list.currentRowChanged.connect(self._on_pick_codebase)

        self._code_view = QPlainTextEdit()
        self._code_view.setReadOnly(True)
        self._code_view.setPlaceholderText("선택된 코드베이스가 표시됩니다.")

        self._stream_view = QPlainTextEdit()
        self._stream_view.setReadOnly(True)
        self._stream_view.setPlaceholderText("실시간 스트림 토큰이 표시됩니다.")

        self._stream_buffer = ""
        self._stream_start_time: Optional[float] = None
        self._stream_token_count = 0
        self._stream_char_count = 0
        self._stream_thread: Optional[QThread] = None
        self._stream_worker: Optional[StreamWorker] = None
        self._stream_context: Optional[Dict[str, Any]] = None
        self._token_rate_label = QLabel("속도: - tok/s (추정)")
        self._token_count_label = QLabel("토큰: 0 (추정)")

        self._seed_spin = QSpinBox()
        self._seed_spin.setRange(0, 1_000_000_000)
        self._seed_spin.setValue(42)

        self._random_seed_check = QCheckBox("랜덤 시드")
        self._random_seed_check.setChecked(True)

        self._run_button = QPushButton("문제 생성")
        self._run_button.clicked.connect(self._on_generate_problem)

        self._used_seed_label = QLabel("사용된 seed: -")
        self._answer_label = QLabel("정답: -")
        self._answer_label.setStyleSheet("font-weight: 600;")

        self._problem_view = QPlainTextEdit()
        self._problem_view.setReadOnly(True)
        self._problem_view.setPlaceholderText("문제가 여기에 표시됩니다.")

        self._solution_view = QPlainTextEdit()
        self._solution_view.setReadOnly(True)
        self._solution_view.setPlaceholderText("풀이가 여기에 표시됩니다.")

        self._meta_view = QPlainTextEdit()
        self._meta_view.setReadOnly(True)
        self._meta_view.setPlaceholderText("meta 정보가 여기에 표시됩니다.")

        self._build_layout()
        self._on_subject_changed(0)
        self._on_tier_changed(0)
        self._refresh_prompt()
        self._load_codebase_list()

    def _build_layout(self) -> None:
        root = QWidget()
        layout = QGridLayout(root)
        layout.setRowStretch(1, 3)
        layout.setRowStretch(2, 2)
        layout.setRowStretch(3, 3)
        layout.setColumnStretch(0, 1)
        layout.setColumnStretch(1, 2)

        control_box = QGroupBox("코드베이스 생성")
        control_layout = QHBoxLayout(control_box)
        control_layout.addWidget(QLabel("프롬프트 모드"))
        control_layout.addWidget(self._mode_combo)
        control_layout.addWidget(self._auto_prompt_check)
        control_layout.addWidget(self._auto_fix_check)
        control_layout.addWidget(QLabel("재시도"))
        control_layout.addWidget(self._auto_fix_retry_spin)
        control_layout.addWidget(self._build_prompt_button)
        control_layout.addWidget(self._generate_code_button)
        control_layout.addStretch(1)
        control_layout.addWidget(self._status_label)
        control_layout.addWidget(self._token_count_label)
        control_layout.addWidget(self._token_rate_label)

        tag_box = QGroupBox("해시태그 선택")
        tag_layout = QGridLayout(tag_box)
        tag_layout.addWidget(QLabel("과목"), 0, 0)
        tag_layout.addWidget(self._subject_combo, 0, 1, 1, 2)
        tag_layout.addWidget(self._tag_list, 1, 0, 1, 3)
        tag_layout.addWidget(QLabel("랜덤 개수"), 2, 0)
        tag_layout.addWidget(self._tag_random_count, 2, 1)
        tag_layout.addWidget(self._tag_random_button, 2, 2)
        tag_layout.addWidget(self._tag_clear_button, 3, 2)
        tag_layout.addWidget(QLabel("선택 태그"), 3, 0, 1, 2)
        tag_layout.addWidget(self._selected_tags_view, 4, 0, 1, 3)

        diff_box = QGroupBox("난이도 설정")
        diff_layout = QGridLayout(diff_box)
        diff_layout.addWidget(QLabel("티어"), 0, 0)
        diff_layout.addWidget(self._tier_combo, 0, 1)
        diff_layout.addWidget(self._tier_detail_label, 1, 0, 1, 2)

        settings_box = QGroupBox("설정 요약")
        settings_layout = QGridLayout(settings_box)
        settings_layout.addWidget(tag_box, 0, 0)
        settings_layout.addWidget(diff_box, 1, 0)

        prompt_box = QGroupBox("문제 코드 프롬프트")
        prompt_layout = QGridLayout(prompt_box)
        prompt_layout.addWidget(self._prompt_editor, 0, 0)

        list_box = QGroupBox("코드베이스 목록")
        list_layout = QGridLayout(list_box)
        list_layout.addWidget(self._code_list, 0, 0)

        code_box = QGroupBox("선택된 코드베이스")
        code_layout = QGridLayout(code_box)
        code_layout.addWidget(QLabel("실시간 스트림"), 0, 0)
        code_layout.addWidget(self._stream_view, 1, 0)
        code_layout.addWidget(QLabel("코드"), 2, 0)
        code_layout.addWidget(self._code_view, 3, 0)
        code_layout.setRowStretch(1, 1)
        code_layout.setRowStretch(3, 2)

        run_box = QGroupBox("문제 생성 (선택한 코드베이스)")
        run_layout = QGridLayout(run_box)
        run_layout.addWidget(QLabel("seed"), 0, 0)
        run_layout.addWidget(self._seed_spin, 0, 1)
        run_layout.addWidget(self._random_seed_check, 0, 2)
        run_layout.addWidget(self._run_button, 0, 3)
        run_layout.addWidget(self._used_seed_label, 0, 4)
        run_layout.addWidget(self._answer_label, 0, 5)
        run_layout.addWidget(QLabel("문제"), 1, 0, 1, 6)
        run_layout.addWidget(self._problem_view, 2, 0, 1, 6)
        run_layout.addWidget(QLabel("풀이"), 3, 0, 1, 6)
        run_layout.addWidget(self._solution_view, 4, 0, 1, 6)
        run_layout.addWidget(QLabel("meta"), 5, 0, 1, 6)
        run_layout.addWidget(self._meta_view, 6, 0, 1, 6)

        layout.addWidget(control_box, 0, 0, 1, 2)
        layout.addWidget(settings_box, 1, 0)
        layout.addWidget(prompt_box, 1, 1)
        layout.addWidget(list_box, 2, 0)
        layout.addWidget(code_box, 2, 1)
        layout.addWidget(run_box, 3, 0, 1, 2)

        self.setCentralWidget(root)

    def _load_codebase_list(self) -> None:
        self._code_list.clear()
        for entry in self._codebases:
            name = entry.get("name") or f"CB-{entry.get('id', 0):03d}"
            item = QListWidgetItem(name)
            item.setData(Qt.UserRole, entry.get("id"))
            self._code_list.addItem(item)
        if self._code_list.count() > 0:
            self._code_list.setCurrentRow(self._code_list.count() - 1)

    def _start_stream(self, prompt_text: str, context: Dict[str, Any], *, status_prefix: str) -> None:
        if self._stream_thread is not None:
            QMessageBox.warning(self, "오류", "이미 생성 중입니다.")
            return
        self._stream_context = context
        self._stream_buffer = ""
        self._stream_start_time = None
        self._stream_token_count = 0
        self._stream_char_count = 0
        self._code_view.clear()
        self._stream_view.clear()
        self._token_count_label.setText("토큰: 0 (추정)")
        self._token_rate_label.setText("속도: - tok/s (추정)")
        self._generate_code_button.setEnabled(False)
        self._run_button.setEnabled(False)
        self._status_label.setText(f"{status_prefix} (스트리밍)")
        QApplication.setOverrideCursor(Qt.WaitCursor)

        worker = StreamWorker(self._client, self._model, prompt_text)
        thread = QThread(self)
        worker.moveToThread(thread)
        thread.started.connect(worker.run)
        worker.chunk.connect(self._on_stream_chunk)
        worker.done.connect(self._on_stream_done)
        worker.error.connect(self._on_stream_error)
        worker.done.connect(thread.quit)
        worker.error.connect(thread.quit)
        worker.done.connect(worker.deleteLater)
        worker.error.connect(worker.deleteLater)
        thread.finished.connect(thread.deleteLater)

        self._stream_thread = thread
        self._stream_worker = worker
        thread.start()

    def _on_subject_changed(self, _: int) -> None:
        category = self._subject_combo.currentData()
        if not isinstance(category, TagCategory):
            self._tag_list.clear()
            return
        self._populate_tag_list(category)
        if self._auto_prompt_check.isChecked():
            self._refresh_prompt()

    def _populate_tag_list(self, category: TagCategory) -> None:
        self._tag_list_updating = True
        try:
            self._tag_list.clear()
            for tag in category.tags:
                item = QListWidgetItem(tag)
                item.setFlags(item.flags() | Qt.ItemIsUserCheckable)
                item.setCheckState(Qt.Unchecked)
                self._tag_list.addItem(item)
        finally:
            self._tag_list_updating = False
        self._update_selected_tags_view()

    def _on_tag_item_changed(self, _: QListWidgetItem) -> None:
        if self._tag_list_updating:
            return
        self._update_selected_tags_view()
        if self._auto_prompt_check.isChecked():
            self._refresh_prompt()

    def _on_random_tags(self) -> None:
        if not self._all_tags:
            return
        count = min(len(self._all_tags), int(self._tag_random_count.value()))
        picks = set(random.sample(self._all_tags, k=count))

        if self._all_subject_index is not None and self._subject_combo.currentIndex() != self._all_subject_index:
            self._subject_combo.setCurrentIndex(self._all_subject_index)

        self._tag_list_updating = True
        try:
            for idx in range(self._tag_list.count()):
                item = self._tag_list.item(idx)
                if item is None:
                    continue
                item.setCheckState(Qt.Checked if item.text() in picks else Qt.Unchecked)
        finally:
            self._tag_list_updating = False
        self._update_selected_tags_view()
        if self._auto_prompt_check.isChecked():
            self._refresh_prompt()

    def _on_clear_tags(self) -> None:
        self._tag_list_updating = True
        try:
            for idx in range(self._tag_list.count()):
                item = self._tag_list.item(idx)
                if item is not None:
                    item.setCheckState(Qt.Unchecked)
        finally:
            self._tag_list_updating = False
        self._update_selected_tags_view()
        if self._auto_prompt_check.isChecked():
            self._refresh_prompt()

    def _collect_selected_tags(self) -> List[str]:
        tags: List[str] = []
        for idx in range(self._tag_list.count()):
            item = self._tag_list.item(idx)
            if item is None:
                continue
            if item.checkState() == Qt.Checked:
                tags.append(item.text())
        return tags

    def _update_selected_tags_view(self) -> None:
        tags = self._collect_selected_tags()
        if not tags:
            self._selected_tags_view.setPlainText("")
        else:
            self._selected_tags_view.setPlainText(", ".join(tags))
        self._update_difficulty_label()

    def _on_tier_changed(self, _: int) -> None:
        self._update_difficulty_label()
        if self._auto_prompt_check.isChecked():
            self._refresh_prompt()

    def _refresh_prompt(self) -> None:
        tags = self._collect_selected_tags()
        tier = self._tier_combo.currentData()
        params = self._tier_params.get(tier, DEFAULT_TIER_PARAMS[3])
        difficulty = estimate_difficulty(len(tags), params)
        mode = self._mode_combo.currentData()
        if not isinstance(mode, PromptMode):
            mode = PROMPT_MODES[0]
        if not tags:
            tags = ["#선택된_태그_없음"]
        prompt = build_prompt(mode, tags, difficulty, params)
        self._prompt_editor.setPlainText(prompt)
        self._update_difficulty_label()

    def _update_difficulty_label(self) -> None:
        tier = self._tier_combo.currentData()
        params = self._tier_params.get(tier, DEFAULT_TIER_PARAMS[3])
        tags = self._collect_selected_tags()
        difficulty = estimate_difficulty(len(tags), params)
        self._tier_detail_label.setText(
            f"solves: {params.solves_count} | strategy: {params.strategy_level} | "
            f"branch: {params.branch_conditions} | difficulty: {difficulty}"
        )

    def _on_generate_codebase(self) -> None:
        prompt_text = self._prompt_editor.toPlainText().strip()
        if not prompt_text:
            QMessageBox.warning(self, "오류", "프롬프트가 비어 있습니다.")
            return
        mode = self._mode_combo.currentData()
        tags = self._collect_selected_tags()
        tier = self._tier_combo.currentData()
        params = self._tier_params.get(tier, DEFAULT_TIER_PARAMS[3])
        difficulty = estimate_difficulty(len(tags), params)
        context = {
            "kind": "create",
            "prompt": prompt_text,
            "mode": getattr(mode, "key", None) if mode else None,
            "tags": tags,
            "tier": tier,
            "params": params,
            "difficulty": difficulty,
            "attempt": 0,
        }
        self._start_stream(prompt_text, context, status_prefix="생성 중...")

    def _on_pick_codebase(self, row: int) -> None:
        entry = self._get_codebase_by_row(row)
        if not entry:
            self._code_view.clear()
            return
        self._code_view.setPlainText(entry["code"])

    def _on_stream_chunk(self, chunk: str) -> None:
        if not chunk:
            return
        if self._stream_start_time is None:
            self._stream_start_time = time.monotonic()
        self._stream_buffer += chunk
        self._stream_char_count += len(chunk)
        self._stream_token_count += estimate_tokens(chunk)

        self._stream_view.setPlainText(self._stream_buffer)
        self._stream_view.moveCursor(QTextCursor.End)

        self._code_view.setPlainText(self._stream_buffer)
        self._code_view.moveCursor(QTextCursor.End)

        elapsed = max(0.001, time.monotonic() - (self._stream_start_time or time.monotonic()))
        rate = self._stream_token_count / elapsed
        self._token_count_label.setText(f"토큰: {self._stream_token_count} (추정)")
        self._token_rate_label.setText(f"속도: {rate:.2f} tok/s (추정)")
        self._status_label.setText(f"생성 중... ({self._stream_char_count} chars)")

    def _on_stream_done(self, full_text: str) -> None:
        QApplication.restoreOverrideCursor()
        self._generate_code_button.setEnabled(True)
        self._run_button.setEnabled(True)
        self._stream_thread = None
        self._stream_worker = None
        if self._stream_start_time is not None:
            elapsed = max(0.001, time.monotonic() - self._stream_start_time)
            rate = self._stream_token_count / elapsed
            self._token_rate_label.setText(f"속도: {rate:.2f} tok/s (추정)")
        context = self._stream_context or {}
        prompt_text = context.get("prompt", "")
        try:
            code = extract_code_text(full_text)
            module = compile_code(code)
        except Exception as exc:
            self._handle_stream_failure(str(exc), full_text, context)
            return

        kind = context.get("kind", "create")
        if kind == "fix_existing":
            entry_id = context.get("entry_id")
            if entry_id is None:
                QMessageBox.critical(self, "생성 실패", "복구 대상 코드베이스를 찾을 수 없습니다.")
                self._status_label.setText("실패")
                return
            update_codebase(entry_id, code, prompt_text or None)
            for entry in self._codebases:
                if entry.get("id") == entry_id:
                    entry["code"] = code
                    entry["module"] = module
                    if prompt_text:
                        entry["prompt"] = prompt_text
                    break
            self._code_view.setPlainText(code)
            self._status_label.setText("복구 완료")
            return

        params = context.get("params") or DEFAULT_TIER_PARAMS[3]
        entry = {
            "id": None,
            "name": "",
            "code": code,
            "module": module,
            "prompt": prompt_text,
            "mode": context.get("mode"),
            "tags": context.get("tags") or [],
            "difficulty": context.get("difficulty"),
            "tier": context.get("tier"),
            "solves_count": getattr(params, "solves_count", None),
            "strategy_level": getattr(params, "strategy_level", None),
            "branch_conditions": getattr(params, "branch_conditions", None),
        }
        entry = save_codebase(entry)
        self._codebases.append(entry)

        item = QListWidgetItem(f"{entry['name']}")
        item.setData(Qt.UserRole, entry["id"])
        self._code_list.addItem(item)
        self._code_list.setCurrentItem(item)
        self._status_label.setText(f"완료: {entry['name']}")

    def _on_stream_error(self, message: str) -> None:
        QApplication.restoreOverrideCursor()
        self._generate_code_button.setEnabled(True)
        self._run_button.setEnabled(True)
        self._stream_thread = None
        self._stream_worker = None
        QMessageBox.critical(self, "생성 실패", message)
        self._status_label.setText("실패")

    def _handle_stream_failure(
        self,
        error_message: str,
        full_text: str,
        context: Dict[str, Any],
    ) -> None:
        max_retries = int(self._auto_fix_retry_spin.value())
        attempt = int(context.get("attempt", 0))
        if not self._auto_fix_check.isChecked() or attempt >= max_retries:
            QMessageBox.critical(self, "생성 실패", error_message)
            self._status_label.setText("실패")
            return

        base_prompt = context.get("prompt", "")
        repair_prompt = build_repair_prompt(base_prompt, full_text, error_message)
        next_context = dict(context)
        next_context["attempt"] = attempt + 1
        status_prefix = f"복구 시도 {attempt + 1}/{max_retries}"
        self._start_stream(repair_prompt, next_context, status_prefix=status_prefix)

    def _get_codebase_by_row(self, row: int) -> Optional[Dict[str, Any]]:
        if row < 0 or row >= len(self._codebases):
            return None
        item = self._code_list.item(row)
        if item is None:
            return None
        entry_id = item.data(Qt.UserRole)
        for entry in self._codebases:
            if entry["id"] == entry_id:
                return entry
        return None

    def _on_generate_problem(self) -> None:
        entry = self._get_codebase_by_row(self._code_list.currentRow())
        if not entry:
            QMessageBox.warning(self, "오류", "코드베이스를 먼저 선택하세요.")
            return

        if self._random_seed_check.isChecked():
            seed = int.from_bytes(os.urandom(4), "big")
        else:
            seed = int(self._seed_spin.value())

        module = entry.get("module")
        if module is None:
            try:
                module = compile_code(entry["code"])
                entry["module"] = module
            except Exception as exc:
                QMessageBox.critical(self, "실행 실패", str(exc))
                return

        generate_func = module.__dict__.get("generate_problem")
        try:
            result = generate_func(seed=seed)
        except Exception as exc:
            if self._auto_fix_check.isChecked():
                prompt_text = entry.get("prompt") or self._prompt_editor.toPlainText().strip()
                repair_prompt = build_repair_prompt(prompt_text, entry.get("code", ""), str(exc))
                context = {
                    "kind": "fix_existing",
                    "prompt": prompt_text,
                    "entry_id": entry.get("id"),
                    "attempt": 0,
                }
                self._start_stream(repair_prompt, context, status_prefix="복구 시도 1")
                return
            QMessageBox.critical(self, "실행 실패", str(exc))
            return

        problem = normalize_signs(str(result.get("problem", "")))
        answer = result.get("answer", "-")
        solution = result.get("solution") or result.get("meta", {}).get("solution") or ""
        solution = normalize_signs(str(solution))
        meta = result.get("meta", {})

        self._used_seed_label.setText(f"사용된 seed: {seed}")
        self._answer_label.setText(f"정답: {answer}")
        self._problem_view.setPlainText(str(problem))
        self._solution_view.setPlainText(str(solution))
        self._meta_view.setPlainText(json.dumps(meta, ensure_ascii=False, indent=2))


def main() -> None:
    app = QApplication([])
    try:
        window = CodebaseLab()
    except Exception as exc:
        QMessageBox.critical(None, "초기화 실패", str(exc))
        return
    window.show()
    app.exec_()
