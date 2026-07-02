"""Command parser — parses natural language commands into course operations.

Supported command tags (from docs/COURSE_BUILDER_V2_PLAN.md §4.1):
- /latex{수식}          → LaTeX formula insertion
- /load_text{경로}      → External text load
- /load_ai{프롬프트}    → AI-generated content
- /load_file{경로}      → File load
- /load_graph{...}      → JSXGraph insertion
- /prob{...}           → Problem insertion

Each command is parsed into a structured dict for downstream processing.
"""
from __future__ import annotations

import re
from dataclasses import dataclass
from enum import Enum
from typing import Any, Optional


# ---------------------------------------------------------------------------
# Enums and data classes
# ---------------------------------------------------------------------------


class CommandType(str, Enum):
    latex = "latex"
    load_text = "load_text"
    load_ai = "load_ai"
    load_file = "load_file"
    load_graph = "load_graph"
    prob = "prob"


@dataclass
class ParsedCommand:
    """A single parsed command with its type and arguments."""

    type: CommandType
    raw: str
    args: dict[str, Any]
    line_number: Optional[int] = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "type": self.type.value,
            "raw": self.raw,
            "args": self.args,
            "line_number": self.line_number,
        }


# ---------------------------------------------------------------------------
# Regex patterns
# ---------------------------------------------------------------------------

# Generic /command{body} pattern — uses balanced brace matching to support nested braces
_COMMAND_RE = re.compile(r"/([a-zA-Z_]+)\{")

def _extract_balanced(text: str, start: int) -> tuple[Optional[str], int]:
    """Extract content of balanced braces starting at `start`.

    Returns (content, end_index) where end_index is the position after the closing brace.
    Returns (None, start) if braces are unbalanced.
    """
    if start >= len(text) or text[start] != "{":
        return None, start
    depth = 0
    i = start
    while i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[start + 1 : i], i + 1
        i += 1
    return None, start

def _parse_command_line(line: str) -> list[tuple[str, str, str]]:
    """Parse all commands in a single line using balanced brace matching.

    Returns list of (cmd_name, body, raw) tuples.
    """
    results: list[tuple[str, str, str]] = []
    for match in _COMMAND_RE.finditer(line):
        cmd_name = match.group(1)
        start = match.end() - 1  # position of '{'
        body, end = _extract_balanced(line, start)
        if body is None:
            continue
        raw = line[match.start() : end]
        results.append((cmd_name, body, raw))
    return results

# /load_graph specific: {lock} {lock_field} {add_button} {slider} {변화단위} {최대} {최소} {변수} {공식}
# Format: /load_graph{lock a slider 1 -10 10 a y = a*x^2}
_LOAD_GRAPH_RE = re.compile(
    r"^(?:(lock)\s+)?"  # optional lock
    r"(\w+)\s+"  # lock_field
    r"(?:(add_button)\s+)?"  # optional add_button
    r"(?:(slider)\s+)?"  # optional slider
    r"([\d.]+)\s+"  # 변화단위 (step)
    r"([-\d.]+)\s+"  # 최소 (min)
    r"([-\d.]+)\s+"  # 최대 (max)
    r"(\w+)\s+"  # 변수 (var)
    r"(.+)$"  # 공식 (formula)
)

# /prob sub-tags: {객관식} {주관식} {힌트금지} {풀이제한}
_PROB_SUBTAGS_RE = re.compile(r"\{(객관식|주관식|힌트금지|풀이제한)\}")

# ASCII fallback sub-tags for testing
_PROB_SUBTAGS_RE_ASCII = re.compile(r"\{(multiple_choice|essay|hints_forbidden|solve_restricted)\}")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def parse_commands(text: str) -> list[ParsedCommand]:
    """Parse all commands from a text block.

    Returns a list of ParsedCommand objects, one per matched command.
    Unmatched or malformed commands are skipped.
    """
    results: list[ParsedCommand] = []
    lines = text.splitlines()

    for line_idx, line in enumerate(lines, start=1):
        for cmd_name, body, raw in _parse_command_line(line):
            cmd_type = _resolve_type(cmd_name)
            if cmd_type is None:
                continue  # Unknown command — skip

            args = _parse_args(cmd_type, body)
            results.append(
                ParsedCommand(
                    type=cmd_type,
                    raw=raw,
                    args=args,
                    line_number=line_idx,
                )
            )

    return results


def parse_single_command(text: str) -> Optional[ParsedCommand]:
    """Parse a single command from text. Returns None if no valid command found."""
    results = parse_commands(text)
    return results[0] if results else None


def validate_commands(text: str) -> dict[str, Any]:
    """Validate all commands in text and return a report.

    Returns:
        {
            "valid": bool,
            "commands": list[dict],
            "errors": list[str],
            "warnings": list[str],
        }
    """
    commands = parse_commands(text)
    errors: list[str] = []
    warnings: list[str] = []

    for cmd in commands:
        if cmd.type == CommandType.load_graph:
            graph_args = cmd.args
            if not graph_args.get("formula"):
                errors.append(f"Line {cmd.line_number}: /load_graph missing formula")
            if graph_args.get("step") is None:
                warnings.append(f"Line {cmd.line_number}: /load_graph missing step, defaulting to 1")
            if graph_args.get("min") is None or graph_args.get("max") is None:
                warnings.append(f"Line {cmd.line_number}: /load_graph unbounded range")

        elif cmd.type == CommandType.prob:
            prob_args = cmd.args
            if not prob_args.get("body"):
                errors.append(f"Line {cmd.line_number}: /prob missing body")
            subtags = prob_args.get("subtags", [])
            if ("객관식" in subtags or "multiple_choice" in subtags) and ("주관식" in subtags or "essay" in subtags):
                errors.append(f"Line {cmd.line_number}: /prob cannot have both 객관식/multiple_choice and 주관식/essay")

    return {
        "valid": len(errors) == 0,
        "commands": [c.to_dict() for c in commands],
        "errors": errors,
        "warnings": warnings,
    }


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _resolve_type(name: str) -> Optional[CommandType]:
    """Map command name string to CommandType enum."""
    mapping = {
        "latex": CommandType.latex,
        "load_text": CommandType.load_text,
        "load_ai": CommandType.load_ai,
        "load_file": CommandType.load_file,
        "load_graph": CommandType.load_graph,
        "prob": CommandType.prob,
    }
    return mapping.get(name)


def _parse_args(cmd_type: CommandType, body: str) -> dict[str, Any]:
    """Parse command body into structured args based on command type."""
    if cmd_type == CommandType.latex:
        return {"formula": body}

    if cmd_type in {CommandType.load_text, CommandType.load_file}:
        return {"path": body}

    if cmd_type == CommandType.load_ai:
        return {"prompt": body}

    if cmd_type == CommandType.load_graph:
        return _parse_load_graph(body)

    if cmd_type == CommandType.prob:
        return _parse_prob(body)

    return {"body": body}


def _parse_load_graph(body: str) -> dict[str, Any]:
    """Parse /load_graph body into structured args.

    Format: [lock] <lock_field> [add_button] [slider] <step> <min> <max> <var> <formula>
    """
    parts = body.split()
    args: dict[str, Any] = {
        "lock": False,
        "add_button": False,
        "slider": True,  # default
        "step": 1.0,
        "min": None,
        "max": None,
        "var": "x",
        "formula": "",
    }

    idx = 0
    if idx < len(parts) and parts[idx] == "lock":
        args["lock"] = True
        idx += 1

    if idx < len(parts):
        args["lock_field"] = parts[idx]
        idx += 1

    if idx < len(parts) and parts[idx] == "add_button":
        args["add_button"] = True
        idx += 1

    if idx < len(parts) and parts[idx] == "slider":
        args["slider"] = True
        idx += 1

    # Try to parse step, min, max as numbers
    numeric_vals: list[float] = []
    while idx < len(parts) and len(numeric_vals) < 3:
        try:
            numeric_vals.append(float(parts[idx]))
            idx += 1
        except ValueError:
            break

    if len(numeric_vals) >= 1:
        args["step"] = numeric_vals[0]
    if len(numeric_vals) >= 2:
        args["min"] = numeric_vals[1]
    if len(numeric_vals) >= 3:
        args["max"] = numeric_vals[2]

    # Remaining: var and formula
    if idx < len(parts):
        args["var"] = parts[idx]
        idx += 1

    if idx < len(parts):
        args["formula"] = " ".join(parts[idx:])

    return args


def _parse_prob(body: str) -> dict[str, Any]:
    """Parse /prob body into structured args with subtags.

    Subtags are inline markers like {객관식}, {주관식}, {힌트금지}, {풀이제한}.
    The remaining text is the problem body.
    """
    subtags: list[str] = []
    remaining = body

    for match in _PROB_SUBTAGS_RE.finditer(body):
        tag = match.group(1)
        subtags.append(tag)
        # Replace only the first occurrence to avoid double-removal
        remaining = remaining.replace("{" + tag + "}", "", 1)

    # ASCII fallback for testing
    if not subtags:
        for match in _PROB_SUBTAGS_RE_ASCII.finditer(body):
            tag = match.group(1)
            subtags.append(tag)
            remaining = remaining.replace("{" + tag + "}", "", 1)

    return {
        "body": remaining.strip(),
        "subtags": subtags,
        "is_multiple_choice": "객관식" in subtags or "multiple_choice" in subtags,
        "hints_forbidden": "힌트금지" in subtags or "hints_forbidden" in subtags,
        "solve_restricted": "풀이제한" in subtags or "solve_restricted" in subtags,
    }
