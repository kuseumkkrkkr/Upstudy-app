import json
import os
import sqlite3
import sys
from typing import Any, Dict, List, Optional

from PyQt5 import QtCore, QtWidgets


DB_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "omj", "quests.db"))


def _parse_content(value: object) -> object:
    if value is None:
        return None
    if isinstance(value, (dict, list)):
        return value
    if isinstance(value, str):
        if not value:
            return {"blocks": []}
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return {"blocks": [{"type": "text", "content": value}]}
    return {"blocks": [{"type": "text", "content": str(value)}]}


def _parse_options(value: object) -> Optional[List[object]]:
    if value is None:
        return None
    if isinstance(value, str):
        if not value:
            return []
        try:
            parsed = json.loads(value)
        except json.JSONDecodeError:
            return [_parse_content(value)]
        if isinstance(parsed, list):
            return [_parse_content(item) for item in parsed]
        return [_parse_content(parsed)]
    if isinstance(value, list):
        return [_parse_content(item) for item in value]
    return [_parse_content(value)]


def _parse_json_list(value: object) -> List[Any]:
    if value is None:
        return []
    if isinstance(value, list):
        return value
    if isinstance(value, str):
        if not value:
            return []
        try:
            parsed = json.loads(value)
        except json.JSONDecodeError:
            return []
        if isinstance(parsed, list):
            return parsed
        return [parsed]
    return [value]


def _normalize_nested_steps(value: object) -> List[Dict[str, Any]]:
    if value is None:
        return []
    if isinstance(value, str):
        try:
            value = json.loads(value)
        except json.JSONDecodeError:
            return []
    if not isinstance(value, list):
        return []
    normalized: List[Dict[str, Any]] = []
    for step in value:
        if not isinstance(step, dict):
            continue
        normalized.append(_normalize_nested_step(step))
    return normalized


def _normalize_nested_step(step: Dict[str, Any]) -> Dict[str, Any]:
    normalized = dict(step)
    normalized["flow"] = _parse_content(step.get("flow"))
    normalized["hint_riddle"] = _parse_content(step.get("hint_riddle"))
    normalized["answer_riddle"] = _parse_content(step.get("answer_riddle"))
    normalized["branches"] = _normalize_nested_steps(step.get("branches"))
    return normalized


def content_to_text(value: object) -> str:
    content = _parse_content(value)
    if content is None:
        return ""
    if isinstance(content, dict):
        blocks = content.get("blocks")
        if isinstance(blocks, list):
            parts = []
            for block in blocks:
                if isinstance(block, dict) and block.get("content"):
                    parts.append(str(block.get("content")).strip())
            return " ".join(p for p in parts if p).strip()
        if "content" in content:
            return str(content.get("content") or "").strip()
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict) and block.get("content"):
                parts.append(str(block.get("content")).strip())
            else:
                text = str(block).strip()
                if text:
                    parts.append(text)
        return " ".join(p for p in parts if p).strip()
    return str(content).strip()


def _connect() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def _fetch_random_quest_id() -> Optional[str]:
    with _connect() as conn:
        row = conn.execute(
            """
            SELECT quest_id
            FROM quest_header
            ORDER BY RANDOM()
            LIMIT 1
            """
        ).fetchone()
    return str(row["quest_id"]) if row else None


def _fetch_quest_ids(order: str = "asc") -> List[Dict[str, Any]]:
    order_sql = "ASC" if order.lower() == "asc" else "DESC"
    with _connect() as conn:
        rows = conn.execute(
            f"""
            SELECT rowid as created_order, quest_id
            FROM quest_header
            ORDER BY rowid {order_sql}
            """
        ).fetchall()
    return [{"created_order": row["created_order"], "quest_id": row["quest_id"]} for row in rows]


def _fetch_quest(quest_id: str) -> Optional[Dict[str, Any]]:
    with _connect() as conn:
        header_row = conn.execute(
            "SELECT quest_id, quest_model FROM quest_header WHERE quest_id = ?",
            (quest_id,),
        ).fetchone()
        if not header_row:
            return None
        info_row = conn.execute(
            """
            SELECT quest_id, main, sub, hash_tag, flow_rate, difficulty, main_huddle
            FROM quest_info
            WHERE quest_id = ?
            """,
            (quest_id,),
        ).fetchone()
        data_row = conn.execute(
            """
            SELECT quest_id, quest_title, quest_image, quest_answer,
                   question_type, quest_options, codebase_id
            FROM quest_data
            WHERE quest_id = ?
            """,
            (quest_id,),
        ).fetchone()
        solves_rows = conn.execute(
            """
            SELECT id, quest_id, flow, hash_tag, hint_riddle, answer_riddle,
                   enter_huddle, branches
            FROM solve_step
            WHERE quest_id = ?
            ORDER BY id ASC
            """,
            (quest_id,),
        ).fetchall()

    header = {
        "quest_id": str(header_row["quest_id"]),
        "quest_model": {"models": _parse_json_list(header_row["quest_model"])},
    }
    info = None
    if info_row:
        info = {
            "main": info_row["main"],
            "sub": _parse_json_list(info_row["sub"]),
            "hash_tag": _parse_json_list(info_row["hash_tag"]),
            "flow_rate": info_row["flow_rate"],
            "difficulty": info_row["difficulty"],
            "main_huddle": info_row["main_huddle"],
        }
    data = None
    if data_row:
        data = {
            "quest_title": _parse_content(data_row["quest_title"]),
            "quest_image": data_row["quest_image"],
            "quest_answer": _parse_content(data_row["quest_answer"]),
            "question_type": data_row["question_type"],
            "quest_options": _parse_options(data_row["quest_options"]),
            "codebase_id": data_row["codebase_id"],
        }
    solves: List[Dict[str, Any]] = []
    for row in solves_rows:
        solves.append(
            {
                "flow": _parse_content(row["flow"]),
                "hash_tag": _parse_json_list(row["hash_tag"]),
                "hint_riddle": _parse_content(row["hint_riddle"]),
                "answer_riddle": _parse_content(row["answer_riddle"]),
                "enter_huddle": row["enter_huddle"],
                "branches": _normalize_nested_steps(row["branches"]),
            }
        )

    return {
        "header": header,
        "info": info,
        "data": data,
        "solves": solves,
    }


def _pretty_json(value: object) -> str:
    if value is None:
        return ""
    try:
        return json.dumps(value, ensure_ascii=False, indent=2)
    except TypeError:
        return json.dumps(str(value), ensure_ascii=False, indent=2)


class QuestViewer(QtWidgets.QMainWindow):
    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("Quest Data Viewer (PyQt)")
        self.resize(1000, 700)
        self._build_ui()
        self._reload_list()
        self._load_random()

    def _build_ui(self) -> None:
        root = QtWidgets.QWidget()
        layout = QtWidgets.QVBoxLayout(root)
        layout.setContentsMargins(12, 12, 12, 12)
        layout.setSpacing(8)

        control_row = QtWidgets.QHBoxLayout()
        self.quest_id_input = QtWidgets.QLineEdit()
        self.quest_id_input.setPlaceholderText("quest_id 입력")
        self.load_btn = QtWidgets.QPushButton("Load")
        self.load_btn.clicked.connect(self._load_by_id)
        self.random_btn = QtWidgets.QPushButton("Random")
        self.random_btn.clicked.connect(self._load_random)
        control_row.addWidget(QtWidgets.QLabel("Quest ID"))
        control_row.addWidget(self.quest_id_input, 1)
        control_row.addWidget(self.load_btn)
        control_row.addWidget(self.random_btn)

        list_group = QtWidgets.QGroupBox("Quest List")
        list_layout = QtWidgets.QVBoxLayout(list_group)
        list_controls = QtWidgets.QHBoxLayout()
        self.order_combo = QtWidgets.QComboBox()
        self.order_combo.addItems(["Oldest -> Newest", "Newest -> Oldest"])
        self.order_combo.currentIndexChanged.connect(self._reload_list)
        self.refresh_btn = QtWidgets.QPushButton("Refresh")
        self.refresh_btn.clicked.connect(self._reload_list)
        self.count_label = QtWidgets.QLabel("0 quests")
        list_controls.addWidget(self.order_combo)
        list_controls.addWidget(self.refresh_btn)
        list_controls.addStretch(1)
        list_controls.addWidget(self.count_label)
        self.quest_list = QtWidgets.QListWidget()
        self.quest_list.itemSelectionChanged.connect(self._load_selected)
        list_layout.addLayout(list_controls)
        list_layout.addWidget(self.quest_list, 1)

        meta_group = QtWidgets.QGroupBox("Meta")
        meta_layout = QtWidgets.QFormLayout(meta_group)
        meta_layout.setLabelAlignment(QtCore.Qt.AlignLeft)
        self.quest_id_label = QtWidgets.QLabel("-")
        self.question_type_label = QtWidgets.QLabel("-")
        self.codebase_id_label = QtWidgets.QLabel("-")
        self.quest_image_label = QtWidgets.QLabel("-")
        self.quest_image_label.setTextInteractionFlags(QtCore.Qt.TextSelectableByMouse)
        meta_layout.addRow("quest_id", self.quest_id_label)
        meta_layout.addRow("question_type", self.question_type_label)
        meta_layout.addRow("codebase_id", self.codebase_id_label)
        meta_layout.addRow("quest_image", self.quest_image_label)

        self.tabs = QtWidgets.QTabWidget()
        self.text_tab = QtWidgets.QWidget()
        self.full_tab = QtWidgets.QWidget()
        self.tabs.addTab(self.text_tab, "Text")
        self.tabs.addTab(self.full_tab, "Full JSON")

        text_layout = QtWidgets.QVBoxLayout(self.text_tab)
        self.title_text = QtWidgets.QTextEdit()
        self.title_text.setReadOnly(True)
        self.answer_text = QtWidgets.QTextEdit()
        self.answer_text.setReadOnly(True)
        text_layout.addWidget(QtWidgets.QLabel("quest_title (text)"))
        text_layout.addWidget(self.title_text, 1)
        text_layout.addWidget(QtWidgets.QLabel("quest_answer (text)"))
        text_layout.addWidget(self.answer_text, 1)

        full_layout = QtWidgets.QVBoxLayout(self.full_tab)
        self.full_json = QtWidgets.QPlainTextEdit()
        self.full_json.setReadOnly(True)
        full_layout.addWidget(QtWidgets.QLabel("quest (full structure)"))
        full_layout.addWidget(self.full_json, 1)

        layout.addLayout(control_row)
        layout.addWidget(list_group, 1)
        layout.addWidget(meta_group)
        layout.addWidget(self.tabs, 1)
        self.setCentralWidget(root)

    def _set_empty(self, message: str) -> None:
        self.quest_id_label.setText("-")
        self.question_type_label.setText("-")
        self.codebase_id_label.setText("-")
        self.quest_image_label.setText("-")
        self.title_text.setPlainText("")
        self.answer_text.setPlainText("")
        self.full_json.setPlainText("")
        if message:
            QtWidgets.QMessageBox.information(self, "Quest Data", message)

    def _render(self, quest: Dict[str, Any]) -> None:
        header = quest.get("header") or {}
        data = quest.get("data") or {}
        quest_id = str(header.get("quest_id") or "-")
        self.quest_id_label.setText(quest_id)
        self.question_type_label.setText(str(data.get("question_type") or "-"))
        self.codebase_id_label.setText(str(data.get("codebase_id") or "-"))
        self.quest_image_label.setText(str(data.get("quest_image") or "-"))
        self.title_text.setPlainText(content_to_text(data.get("quest_title")))
        self.answer_text.setPlainText(content_to_text(data.get("quest_answer")))
        self.full_json.setPlainText(_pretty_json(quest))
        if quest_id and quest_id != "-":
            self._select_in_list(quest_id)

    def _select_in_list(self, quest_id: str) -> None:
        self.quest_list.blockSignals(True)
        try:
            for i in range(self.quest_list.count()):
                item = self.quest_list.item(i)
                if item.data(QtCore.Qt.UserRole) == quest_id:
                    self.quest_list.setCurrentItem(item)
                    break
        finally:
            self.quest_list.blockSignals(False)

    def _load_by_id(self) -> None:
        quest_id = self.quest_id_input.text().strip()
        if not quest_id:
            self._set_empty("quest_id를 입력하세요.")
            return
        quest = _fetch_quest(quest_id)
        if not quest:
            self._set_empty(f"quest_id={quest_id} 데이터가 없습니다.")
            return
        self._render(quest)

    def _load_selected(self) -> None:
        items = self.quest_list.selectedItems()
        if not items:
            return
        quest_id = items[0].data(QtCore.Qt.UserRole)
        if not quest_id:
            return
        self.quest_id_input.setText(str(quest_id))
        quest = _fetch_quest(str(quest_id))
        if not quest:
            self._set_empty(f"quest_id={quest_id} 데이터가 없습니다.")
            return
        self._render(quest)

    def _reload_list(self) -> None:
        order = "asc" if self.order_combo.currentIndex() == 0 else "desc"
        rows = _fetch_quest_ids(order=order)
        self.quest_list.clear()
        for row in rows:
            quest_id = str(row["quest_id"])
            created_order = row["created_order"]
            item = QtWidgets.QListWidgetItem(f"{created_order:04d} | {quest_id}")
            item.setData(QtCore.Qt.UserRole, quest_id)
            self.quest_list.addItem(item)
        self.count_label.setText(f"{len(rows)} quests")

    def _load_random(self) -> None:
        quest_id = _fetch_random_quest_id()
        if not quest_id:
            self._set_empty("quest_header 테이블에 데이터가 없습니다.")
            return
        quest = _fetch_quest(quest_id)
        if not quest:
            self._set_empty(f"quest_id={quest_id} 데이터가 없습니다.")
            return
        self.quest_id_input.setText(quest_id)
        self._render(quest)


def main() -> int:
    app = QtWidgets.QApplication(sys.argv)
    window = QuestViewer()
    window.show()
    return app.exec_()


if __name__ == "__main__":
    raise SystemExit(main())
