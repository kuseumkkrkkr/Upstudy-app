from __future__ import annotations

import argparse
import json
import os
import shlex
import sys
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple
from urllib import error, request
from urllib.parse import urlencode

DEFAULT_BASE_URL = os.environ.get("API_BASE_URL", "http://localhost:8000")


@dataclass
class ChatState:
    affection: int = 120
    attendance_days: int = 7
    quest_id: Optional[str] = None
    quest_title: Optional[str] = None
    quest_tags: List[str] = field(default_factory=list)
    problem_number: Optional[str] = None
    solution_notes: Optional[str] = None
    learning_ratings: Dict[str, int] = field(default_factory=dict)
    history: List[Tuple[str, str]] = field(default_factory=list)
    last_search_results: List[dict] = field(default_factory=list)
    last_prompt: str = ""
    last_pair_summary: Optional[str] = None
    last_input_tokens: int = 0
    last_output_tokens: int = 0
    total_input_tokens: int = 0
    total_output_tokens: int = 0


class HttpChatClient:
    def __init__(self, base_url: str) -> None:
        self.base_url = base_url.rstrip("/")
        self._token: Optional[str] = None

    def _request_json(
        self,
        path: str,
        *,
        method: str = "GET",
        payload: Optional[dict] = None,
        headers: Optional[dict] = None,
        timeout: int = 30,
    ) -> dict:
        url = f"{self.base_url}{path}"
        data = None
        req_headers = {"Accept": "application/json"}
        if payload is not None:
            data = json.dumps(payload).encode("utf-8")
            req_headers["Content-Type"] = "application/json"
        if headers:
            req_headers.update(headers)
        req = request.Request(url, data=data, headers=req_headers, method=method)
        try:
            with request.urlopen(req, timeout=timeout) as resp:
                body = resp.read().decode("utf-8")
        except error.HTTPError as exc:
            error_body = exc.read().decode("utf-8")
            detail = error_body.strip() or exc.reason
            raise RuntimeError(f"HTTP {exc.code} {exc.reason}: {detail}") from exc
        except error.URLError as exc:
            raise RuntimeError(f"Request failed: {exc.reason}") from exc
        if not body:
            return {}
        try:
            return json.loads(body)
        except json.JSONDecodeError as exc:
            raise RuntimeError("Invalid JSON response") from exc

    def _ensure_token(self) -> str:
        if self._token:
            return self._token
        payload = self._request_json("/auth/anonymous", method="POST")
        token = payload.get("token")
        if not token:
            raise RuntimeError("Token missing in /auth/anonymous response")
        self._token = str(token)
        return self._token

    def send_message(self, state: ChatState, user_message: str) -> dict:
        token = self._ensure_token()
        payload = build_payload(state, user_message)
        headers = {"Authorization": f"Bearer {token}"}
        return self._request_json(
            "/test-chat/message", method="POST", payload=payload, headers=headers
        )

    def search_quests(
        self,
        *,
        hash_tag: Optional[str] = None,
        quest_id: Optional[str] = None,
        text: Optional[str] = None,
        page_size: int = 20,
    ) -> List[dict]:
        params: Dict[str, str] = {}
        if hash_tag:
            params["hash_tag"] = hash_tag
        if quest_id:
            params["quest_id"] = quest_id
        if text:
            params["text"] = text
        if page_size > 0:
            params["page_size"] = str(page_size)
        if not params:
            raise ValueError("Provide hash_tag, quest_id, or text to search")
        query = urlencode(params)
        token = self._ensure_token()
        payload = self._request_json(
            f"/quests?{query}",
            method="GET",
            headers={"Authorization": f"Bearer {token}"},
        )
        return list(payload.get("quests") or [])


def clamp_int(value: int, low: int, high: int) -> int:
    return max(low, min(high, int(value)))


def build_payload(state: ChatState, user_message: str) -> dict:
    payload: dict = {
        "user_message": user_message,
        "affection": clamp_int(state.affection, 1, 255),
        "attendance_days": max(1, int(state.attendance_days)),
    }
    if state.quest_id:
        payload["quest_id"] = state.quest_id
    if state.problem_number:
        payload["problem_number"] = state.problem_number
    if state.solution_notes:
        payload["solution_notes"] = state.solution_notes
    if state.learning_ratings:
        payload["learning_ratings"] = dict(state.learning_ratings)
    if state.history:
        user, assistant = state.history[-1]
        payload["recent_pairs"] = [{"user": user, "assistant": assistant}]
    return payload


def content_to_text(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, dict):
        blocks = value.get("blocks")
        if isinstance(blocks, list):
            parts = [
                str(block.get("content", "")).strip()
                for block in blocks
                if isinstance(block, dict) and block.get("content")
            ]
            return " ".join(part for part in parts if part).strip()
        if "content" in value:
            return str(value.get("content") or "").strip()
    if isinstance(value, list):
        parts = []
        for block in value:
            if isinstance(block, dict) and block.get("content"):
                parts.append(str(block.get("content", "")).strip())
            else:
                text = str(block).strip()
                if text:
                    parts.append(text)
        return " ".join(part for part in parts if part).strip()
    return str(value).strip()


def summarize_quest(quest: dict) -> Tuple[str, str, List[str]]:
    header = quest.get("header") or {}
    info = quest.get("info") or {}
    data = quest.get("data") or {}
    quest_id = str(header.get("quest_id") or "").strip()
    title = content_to_text(data.get("quest_title"))
    raw_tags = info.get("hash_tag") or []
    tags = [str(tag).strip() for tag in raw_tags if str(tag).strip()]
    return quest_id, title, tags


def update_state_from_response(state: ChatState, response: dict) -> None:
    prompt = response.get("prompt") or ""
    state.last_prompt = str(prompt)
    state.last_pair_summary = response.get("pair_summary")

    total = int(response.get("token_estimate") or 0)
    input_tokens = response.get("input_token_estimate")
    output_tokens = response.get("output_token_estimate")

    if input_tokens is None:
        input_tokens = total
    if output_tokens is None:
        output_tokens = total - int(input_tokens) if total > 0 else 0

    state.last_input_tokens = int(input_tokens)
    state.last_output_tokens = int(output_tokens)
    state.total_input_tokens += state.last_input_tokens
    state.total_output_tokens += state.last_output_tokens


def format_config(state: ChatState) -> str:
    lines = [
        "Config:",
        f"- affection: {state.affection}",
        f"- attendance_days: {state.attendance_days}",
        f"- quest_id: {state.quest_id or '(none)'}",
        f"- quest_title: {state.quest_title or '(none)'}",
        f"- quest_tags: {', '.join(state.quest_tags) if state.quest_tags else '(none)'}",
        f"- problem_number: {state.problem_number or '(none)'}",
        f"- solution_notes: {state.solution_notes or '(none)'}",
    ]
    if state.learning_ratings:
        lines.append("- learning_ratings:")
        for tag, score in sorted(state.learning_ratings.items()):
            lines.append(f"  {tag}={score}")
    else:
        lines.append("- learning_ratings: (none)")
    return "\n".join(lines)


def format_tokens(state: ChatState) -> str:
    return (
        "Tokens:\n"
        f"- last input: {state.last_input_tokens}\n"
        f"- last output: {state.last_output_tokens}\n"
        f"- total input: {state.total_input_tokens}\n"
        f"- total output: {state.total_output_tokens}"
    )


def print_help() -> None:
    print(
        "Commands:\n"
        "- /help\n"
        "- /config\n"
        "- /affection <1-255>\n"
        "- /attendance <days>\n"
        "- /quest <quest_id>\n"
        "- /quest clear\n"
        "- /quest-search tag=<tag> id=<id> text=<text>\n"
        "- /quest-pick <index>\n"
        "- /problem <text>\n"
        "- /notes <text>\n"
        "- /rate <tag> <0-256>\n"
        "- /rates\n"
        "- /rates clear\n"
        "- /prompt\n"
        "- /tokens\n"
        "- /reset\n"
        "- /exit\n"
    )


def handle_command(client: HttpChatClient, state: ChatState, line: str) -> bool:
    try:
        parts = shlex.split(line)
    except ValueError:
        print("Invalid command format")
        return True

    if not parts:
        return True

    cmd = parts[0].lower()
    args = parts[1:]

    if cmd in ("/exit", "/quit"):
        return False
    if cmd == "/help":
        print_help()
        return True
    if cmd == "/config":
        print(format_config(state))
        return True
    if cmd == "/affection":
        if not args:
            print("Usage: /affection <1-255>")
            return True
        try:
            state.affection = clamp_int(int(args[0]), 1, 255)
        except ValueError:
            print("Invalid affection value")
        return True
    if cmd == "/attendance":
        if not args:
            print("Usage: /attendance <days>")
            return True
        try:
            state.attendance_days = max(1, int(args[0]))
        except ValueError:
            print("Invalid attendance value")
        return True
    if cmd == "/quest":
        if not args:
            print(f"quest_id: {state.quest_id or '(none)'}")
            return True
        if args[0].lower() == "clear":
            state.quest_id = None
            state.quest_title = None
            state.quest_tags = []
            state.learning_ratings.clear()
        else:
            state.quest_id = " ".join(args).strip() or None
            state.quest_title = None
            state.quest_tags = []
        return True
    if cmd == "/quest-search":
        if not args:
            print("Usage: /quest-search tag=<tag> id=<id> text=<text>")
            return True
        params: Dict[str, str] = {}
        text_parts: List[str] = []
        for token in args:
            if "=" in token:
                key, value = token.split("=", 1)
                key = key.strip().lower()
                value = value.strip()
                if not value:
                    continue
                if key in ("tag", "hash_tag"):
                    params["hash_tag"] = value
                elif key in ("id", "quest_id"):
                    params["quest_id"] = value
                elif key in ("text", "query"):
                    params["text"] = value
            else:
                text_parts.append(token)
        if text_parts and "text" not in params:
            params["text"] = " ".join(text_parts)
        try:
            results = client.search_quests(
                hash_tag=params.get("hash_tag"),
                quest_id=params.get("quest_id"),
                text=params.get("text"),
                page_size=20,
            )
        except (RuntimeError, ValueError) as exc:
            print(f"Search failed: {exc}")
            return True
        state.last_search_results = results
        if not results:
            print("No results")
            return True
        for idx, quest in enumerate(results, 1):
            quest_id, title, tags = summarize_quest(quest)
            title_display = title or "(untitled)"
            tags_display = ", ".join(tags) if tags else "-"
            print(f"{idx}. {quest_id} | {title_display} | {tags_display}")
        return True
    if cmd == "/quest-pick":
        if not args:
            print("Usage: /quest-pick <index>")
            return True
        if not state.last_search_results:
            print("No search results to pick from")
            return True
        try:
            index = int(args[0])
        except ValueError:
            print("Invalid index")
            return True
        if index < 1 or index > len(state.last_search_results):
            print("Index out of range")
            return True
        quest = state.last_search_results[index - 1]
        quest_id, title, tags = summarize_quest(quest)
        state.quest_id = quest_id or None
        state.quest_title = title or None
        state.quest_tags = tags
        if tags:
            for tag in tags:
                state.learning_ratings.setdefault(tag, 128)
        print(f"Selected quest: {quest_id or '(unknown)'}")
        return True
    if cmd == "/problem":
        state.problem_number = " ".join(args).strip() or None
        return True
    if cmd == "/notes":
        state.solution_notes = " ".join(args).strip() or None
        return True
    if cmd == "/rate":
        if len(args) < 2:
            print("Usage: /rate <tag> <0-256>")
            return True
        tag = args[0].strip()
        if not tag:
            print("Tag cannot be empty")
            return True
        try:
            score = clamp_int(int(args[1]), 0, 256)
        except ValueError:
            print("Invalid score value")
            return True
        state.learning_ratings[tag] = score
        return True
    if cmd == "/rates":
        if args and args[0].lower() == "clear":
            state.learning_ratings.clear()
            return True
        if not state.learning_ratings:
            print("No learning ratings set")
            return True
        for tag, score in sorted(state.learning_ratings.items()):
            print(f"- {tag}: {score}")
        return True
    if cmd == "/prompt":
        if not state.last_prompt:
            print("No prompt yet")
            return True
        print(state.last_prompt)
        return True
    if cmd == "/tokens":
        print(format_tokens(state))
        return True
    if cmd == "/reset":
        state.history.clear()
        state.last_prompt = ""
        state.last_pair_summary = None
        state.last_input_tokens = 0
        state.last_output_tokens = 0
        state.total_input_tokens = 0
        state.total_output_tokens = 0
        print("Conversation reset")
        return True

    print("Unknown command. Type /help for list.")
    return True


def run_repl(client: HttpChatClient, state: ChatState) -> None:
    print("Character chat simulator (HTTP mode)")
    print("Type /help for commands. Enter message to send.")
    while True:
        try:
            line = input("> ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nExiting")
            return

        if not line:
            continue
        if line.startswith("/"):
            if not handle_command(client, state, line):
                return
            continue

        user_message = line
        try:
            response = client.send_message(state, user_message)
        except RuntimeError as exc:
            print(f"Error: {exc}")
            continue

        assistant = response.get("assistant_message") or ""
        state.history.append((user_message, assistant))
        update_state_from_response(state, response)

        print("Assistant:")
        print(assistant)
        if state.last_pair_summary:
            print(f"Pair summary: {state.last_pair_summary}")
        print(format_tokens(state))


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Character chat simulator")
    parser.add_argument(
        "--base-url",
        default=DEFAULT_BASE_URL,
        help="Backend API base URL (default: %(default)s)",
    )
    return parser.parse_args(argv)


def main(argv: List[str]) -> int:
    args = parse_args(argv)
    client = HttpChatClient(args.base_url)
    state = ChatState()
    run_repl(client, state)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
