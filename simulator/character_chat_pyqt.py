import json
import math
import os
import sqlite3
import sys
import html
from dataclasses import dataclass
from typing import List, Optional, Tuple

from google import genai
from PyQt5 import QtCore, QtGui, QtWidgets


DB_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'omj', 'quests.db'))
COMETAPI_KEY = os.environ.get('COMETAPI_KEY')
BASE_URL = 'https://api.cometapi.com'
MODEL_NAME = os.environ.get('OMJ_CHAT_MODEL', 'gemini-3.1-flash-lite')

DEFAULT_CHARACTER_PROMPT = (
    '?? ???? ??? ???? ??? ????. '
    '??? ?? ??????? ??? ?? ??? ??? ????? ???.'
)
DEFAULT_SOLUTION_PROMPT = (
    '????(?? ?? ?? ??)? ??? ?? ????? ????, '
    '???? ???? ????.'
)
FINAL_ANSWER_PREFIX = '??? ???? ??? ??????.'


@dataclass
class QuestData:
    quest_id: str
    title_text: str
    answer_text: str
    tags: List[str]


def _parse_content(value: object) -> object:
    if value is None:
        return None
    if isinstance(value, (dict, list)):
        return value
    if isinstance(value, str):
        if not value:
            return {'blocks': []}
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return {'blocks': [{'type': 'text', 'content': value}]}
    return {'blocks': [{'type': 'text', 'content': str(value)}]}


def content_to_text(value: object) -> str:
    content = _parse_content(value)
    if content is None:
        return ''
    if isinstance(content, dict):
        blocks = content.get('blocks')
        if isinstance(blocks, list):
            parts = []
            for block in blocks:
                if isinstance(block, dict) and block.get('content'):
                    parts.append(str(block.get('content')).strip())
            return ' '.join(p for p in parts if p).strip()
        if 'content' in content:
            return str(content.get('content') or '').strip()
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict) and block.get('content'):
                parts.append(str(block.get('content')).strip())
            else:
                text = str(block).strip()
                if text:
                    parts.append(text)
        return ' '.join(p for p in parts if p).strip()
    return str(content).strip()


def load_random_quest(db_path: str) -> QuestData:
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute(
        """
        SELECT d.quest_id, d.quest_title, d.quest_answer, i.hash_tag
        FROM quest_data d
        LEFT JOIN quest_info i ON d.quest_id = i.quest_id
        WHERE d.quest_answer IS NOT NULL AND d.quest_answer != ''
        ORDER BY RANDOM() LIMIT 1
        """
    )
    row = cur.fetchone()
    conn.close()
    if not row:
        raise RuntimeError('No quest with answer found in DB')
    quest_id, quest_title, quest_answer, hash_tag = row
    title_text = content_to_text(quest_title)
    answer_text = content_to_text(quest_answer)
    tags: List[str] = []
    if hash_tag:
        try:
            tags = [str(tag).strip() for tag in json.loads(hash_tag) if str(tag).strip()]
        except json.JSONDecodeError:
            tags = [str(hash_tag).strip()]
    return QuestData(
        quest_id=str(quest_id),
        title_text=title_text,
        answer_text=answer_text,
        tags=tags,
    )


def estimate_tokens(text: str) -> int:
    if not text:
        return 0
    return max(1, int(math.ceil(len(text) / 4)))


def build_prompt(
    *,
    user_message: str,
    affection: int,
    attendance_days: int,
    character_prompt: str,
    solution_prompt: str,
    quest: QuestData,
    pair_summary: Optional[str],
    include_answer: bool,
) -> str:
    sections: List[str] = [
        character_prompt.strip(),
        f'???: {affection}/256',
        f'?? ??: {attendance_days}?',
        f'?? ID: {quest.quest_id}',
        f'??: {quest.title_text}',
    ]

    if quest.tags:
        sections.append('????: ' + ', '.join(quest.tags))

    if solution_prompt.strip():
        sections.append('???? ??:\n' + solution_prompt.strip())

    if pair_summary:
        sections.append(f'?? ?? ??: {pair_summary}')

    if include_answer:
        sections.append(f'??: {quest.answer_text}')
        sections.append('? ??? ???? ??? ????.')
    else:
        sections.append('??? ?? ??? ??, ??? ?? ????.')

    sections.append(f'?? ??: {user_message}')
    if include_answer:
        sections.append('??? ???? ????. ?? ? ????.')
    else:
        sections.append('??? ???? ????. ??? ??? ???? ?????.')

    return '\n\n'.join(section for section in sections if section)


def summarize_last_pair(history: List[Tuple[str, str]]) -> Optional[str]:
    if not history:
        return None
    user, assistant = history[-1]
    summary = f'??: {user} / AI: {assistant}'
    if len(summary) < 40:
        return None
    return summary[:120] + '...' if len(summary) > 120 else summary


class ChatWorker(QtCore.QThread):
    response_ready = QtCore.pyqtSignal(str, int, int)
    error = QtCore.pyqtSignal(str)

    def __init__(self, client: genai.Client, prompt: str) -> None:
        super().__init__()
        self._client = client
        self._prompt = prompt

    def run(self) -> None:
        try:
            response = self._client.models.generate_content(
                model=MODEL_NAME,
                contents=self._prompt,
            )
            text = (response.text or '').strip()
            cleaned = self._strip_code_fences(text)
            if not cleaned:
                raise RuntimeError('Empty response from model')
            input_tokens = estimate_tokens(self._prompt)
            output_tokens = estimate_tokens(cleaned)
            self.response_ready.emit(cleaned, input_tokens, output_tokens)
        except Exception as exc:
            self.error.emit(str(exc))

    @staticmethod
    def _strip_code_fences(text: str) -> str:
        if text.startswith('```'):
            text = text.lstrip('`').split('\n', 1)[-1]
        if text.endswith('```'):
            text = text.rsplit('\n', 1)[0]
        return text.strip()


class CharacterChatWindow(QtWidgets.QMainWindow):
    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle('Character Chat Simulator (PyQt)')
        self.resize(1200, 800)

        self.quest = load_random_quest(DB_PATH)
        self.history: List[Tuple[str, str]] = []
        self.last_user_message: str = ""
        self.user_turns = 0
        self.pending_final_prefix = False
        self.last_user_message = ""
        self.total_input_tokens = 0
        self.total_output_tokens = 0

        if not COMETAPI_KEY:
            QtWidgets.QMessageBox.warning(
                self,
                'COMETAPI_KEY missing',
                'COMETAPI_KEY is not set. Set it before sending messages.',
            )
        self.client = genai.Client(
            http_options={'api_version': 'v1beta', 'base_url': BASE_URL},
            api_key=COMETAPI_KEY,
        )

        self._build_ui()
        self._refresh_quest_ui()

    def _build_ui(self) -> None:
        splitter = QtWidgets.QSplitter(QtCore.Qt.Horizontal)
        splitter.setStretchFactor(0, 2)
        splitter.setStretchFactor(1, 3)

        left = QtWidgets.QWidget()
        left_layout = QtWidgets.QVBoxLayout(left)
        left_layout.setContentsMargins(12, 12, 12, 12)
        left_layout.setSpacing(10)

        quest_group = QtWidgets.QGroupBox('Quest')
        quest_layout = QtWidgets.QVBoxLayout(quest_group)
        self.quest_id_label = QtWidgets.QLabel()
        self.quest_title_label = QtWidgets.QLabel()
        self.quest_title_label.setWordWrap(True)
        self.quest_tags_label = QtWidgets.QLabel()
        self.quest_tags_label.setWordWrap(True)
        self.answer_label = QtWidgets.QLabel('??: (??)')
        self.answer_label.setWordWrap(True)
        self.answer_label.setVisible(False)

        quest_layout.addWidget(self.quest_id_label)
        quest_layout.addWidget(self.quest_title_label)
        quest_layout.addWidget(self.quest_tags_label)
        quest_layout.addWidget(self.answer_label)

        quest_btns = QtWidgets.QHBoxLayout()
        self.reload_btn = QtWidgets.QPushButton('Load Random Quest')
        self.reload_btn.clicked.connect(self._load_new_quest)
        self.toggle_answer_btn = QtWidgets.QPushButton('Show Answer')
        self.toggle_answer_btn.clicked.connect(self._toggle_answer)
        quest_btns.addWidget(self.reload_btn)
        quest_btns.addWidget(self.toggle_answer_btn)
        quest_layout.addLayout(quest_btns)

        controls_group = QtWidgets.QGroupBox('Controls')
        controls_layout = QtWidgets.QHBoxLayout(controls_group)
        self.affection_spin = QtWidgets.QSpinBox()
        self.affection_spin.setRange(1, 255)
        self.affection_spin.setValue(120)
        self.attendance_spin = QtWidgets.QSpinBox()
        self.attendance_spin.setRange(1, 60)
        self.attendance_spin.setValue(7)
        controls_layout.addWidget(QtWidgets.QLabel('Affection'))
        controls_layout.addWidget(self.affection_spin)
        controls_layout.addWidget(QtWidgets.QLabel('Attendance Days'))
        controls_layout.addWidget(self.attendance_spin)

        prompt_group = QtWidgets.QGroupBox('Solution Process Prompt')
        prompt_layout = QtWidgets.QVBoxLayout(prompt_group)
        self.solution_prompt_edit = QtWidgets.QTextEdit()
        self.solution_prompt_edit.setPlainText(DEFAULT_SOLUTION_PROMPT)
        prompt_layout.addWidget(self.solution_prompt_edit)

        character_group = QtWidgets.QGroupBox('Character Prompt')
        character_layout = QtWidgets.QVBoxLayout(character_group)
        self.character_prompt_edit = QtWidgets.QTextEdit()
        self.character_prompt_edit.setPlainText(DEFAULT_CHARACTER_PROMPT)
        character_layout.addWidget(self.character_prompt_edit)

        left_layout.addWidget(quest_group)
        left_layout.addWidget(controls_group)
        left_layout.addWidget(prompt_group)
        left_layout.addWidget(character_group)
        left_layout.addStretch(1)

        right = QtWidgets.QWidget()
        right_layout = QtWidgets.QVBoxLayout(right)
        right_layout.setContentsMargins(12, 12, 12, 12)
        right_layout.setSpacing(10)

        self.chat_view = QtWidgets.QTextBrowser()
        self.chat_view.setOpenExternalLinks(False)
        self.chat_view.setStyleSheet('font-size: 13px;')

        input_row = QtWidgets.QHBoxLayout()
        self.chat_input = QtWidgets.QTextEdit()
        self.chat_input.setFixedHeight(80)
        self.chat_input.setPlaceholderText('???? ?????...')
        self.send_btn = QtWidgets.QPushButton('Send')
        self.send_btn.clicked.connect(self._send_message)
        self.reset_btn = QtWidgets.QPushButton('Reset Chat')
        self.reset_btn.clicked.connect(self._reset_chat)
        input_row.addWidget(self.chat_input, 1)
        input_row.addWidget(self.send_btn)
        input_row.addWidget(self.reset_btn)

        self.status_label = QtWidgets.QLabel('Ready')

        right_layout.addWidget(self.chat_view, 1)
        right_layout.addLayout(input_row)
        right_layout.addWidget(self.status_label)

        splitter.addWidget(left)
        splitter.addWidget(right)
        self.setCentralWidget(splitter)

    def _refresh_quest_ui(self) -> None:
        self.quest_id_label.setText(f'Quest ID: {self.quest.quest_id}')
        self.quest_title_label.setText(f'??: {self.quest.title_text}')
        tags_text = ', '.join(self.quest.tags) if self.quest.tags else '-'
        self.quest_tags_label.setText(f'??: {tags_text}')
        self.answer_label.setText(f'??: {self.quest.answer_text}')

    def _load_new_quest(self) -> None:
        try:
            self.quest = load_random_quest(DB_PATH)
        except Exception as exc:
            QtWidgets.QMessageBox.critical(self, 'Quest load failed', str(exc))
            return
        self.answer_label.setVisible(False)
        self.toggle_answer_btn.setText('Show Answer')
        self._refresh_quest_ui()
        self._reset_chat(clear_input=False)

    def _toggle_answer(self) -> None:
        visible = not self.answer_label.isVisible()
        self.answer_label.setVisible(visible)
        self.toggle_answer_btn.setText('Hide Answer' if visible else 'Show Answer')

    def _reset_chat(self, clear_input: bool = True) -> None:
        self.history.clear()
        self.user_turns = 0
        self.pending_final_prefix = False
        self.last_user_message = ""
        self.total_input_tokens = 0
        self.total_output_tokens = 0
        self.chat_view.clear()
        if clear_input:
            self.chat_input.clear()
        self.status_label.setText('Chat reset')

    def _append_chat(self, speaker: str, message: str) -> None:
        escaped = html.escape(message).replace('\n', '<br>')
        self.chat_view.append(f'<b>{speaker}:</b> {escaped}')
        self.chat_view.verticalScrollBar().setValue(self.chat_view.verticalScrollBar().maximum())

    def _send_message(self) -> None:
        if not COMETAPI_KEY:
            QtWidgets.QMessageBox.warning(
                self,
                'COMETAPI_KEY missing',
                'Set COMETAPI_KEY before sending messages.',
            )
            return
        text = self.chat_input.toPlainText().strip()
        if not text:
            return
        self.chat_input.clear()
        self._append_chat('User', text)
        self.user_turns += 1
        self.last_user_message = text

        pair_summary = summarize_last_pair(self.history)
        include_answer = self.user_turns >= 10
        self.pending_final_prefix = self.user_turns == 10

        prompt = build_prompt(
            user_message=text,
            affection=self.affection_spin.value(),
            attendance_days=self.attendance_spin.value(),
            character_prompt=self.character_prompt_edit.toPlainText(),
            solution_prompt=self.solution_prompt_edit.toPlainText(),
            quest=self.quest,
            pair_summary=pair_summary,
            include_answer=include_answer,
        )

        self.status_label.setText('Thinking...')
        self.send_btn.setEnabled(False)
        self.worker = ChatWorker(self.client, prompt)
        self.worker.response_ready.connect(self._handle_response)
        self.worker.error.connect(self._handle_error)
        self.worker.finished.connect(self._worker_finished)
        self.worker.start()

    def _handle_response(self, response: str, input_tokens: int, output_tokens: int) -> None:
        if self.pending_final_prefix:
            response = f'{FINAL_ANSWER_PREFIX}\n{response}'
        self.history.append((self.last_user_message, response))
        self.total_input_tokens += input_tokens
        self.total_output_tokens += output_tokens
        self._append_chat('Assistant', response)
        self.status_label.setText(
            f'Input tokens: {input_tokens} | Output tokens: {output_tokens} | '
            f'Total in/out: {self.total_input_tokens}/{self.total_output_tokens}'
        )

    def _handle_error(self, message: str) -> None:
        self.status_label.setText(f'Error: {message}')
        QtWidgets.QMessageBox.critical(self, 'Error', message)

    def _worker_finished(self) -> None:
        self.send_btn.setEnabled(True)

def main() -> int:
    app = QtWidgets.QApplication(sys.argv)
    window = CharacterChatWindow()
    window.show()
    return app.exec_()


if __name__ == '__main__':
    raise SystemExit(main())
