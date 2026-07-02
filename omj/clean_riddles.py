from __future__ import annotations

from typing import Any, Dict, List, Optional


def _content_blocks_to_text(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, dict):
        if "blocks" in value and isinstance(value.get("blocks"), list):
            parts = [
                str(block.get("content", "")).strip()
                for block in value.get("blocks", [])
                if isinstance(block, dict)
            ]
            return " ".join(part for part in parts if part).strip()
        if "content" in value:
            return str(value.get("content") or "").strip()
    if isinstance(value, list):
        parts: List[str] = []
        for item in value:
            if isinstance(item, dict):
                parts.append(str(item.get("content", "")).strip())
            else:
                parts.append(str(item).strip())
        return " ".join(part for part in parts if part).strip()
    return str(value).strip()


def _normalize_hash_tags(raw: Any) -> List[str]:
    if raw is None:
        return []
    if isinstance(raw, list):
        return [str(tag).strip() for tag in raw if str(tag).strip()]
    return [str(raw).strip()] if str(raw).strip() else []


def extract_flows(quest_json: Dict[str, Any]) -> List[Dict[str, Any]]:
    flows: List[Dict[str, Any]] = []
    solves = quest_json.get("solves") or []
    if not isinstance(solves, list):
        return flows

    def visit(step: Dict[str, Any]) -> None:
        answer_text = _content_blocks_to_text(step.get("answer_riddle"))
        flows.append(
            {
                "flow_number": len(flows),
                "hash_tag": _normalize_hash_tags(step.get("hash_tag")),
                "answer_riddle": answer_text,
            }
        )
        branches = step.get("branches") or []
        if isinstance(branches, list):
            for branch in branches:
                if isinstance(branch, dict):
                    visit(branch)

    for entry in solves:
        if isinstance(entry, dict):
            visit(entry)
    return flows


def build_clean_payload(quest_json: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    if not isinstance(quest_json, dict):
        return {
            "quest_title": "",
            "quest_answer": "",
            "quest_image": None,
            "flows": [],
        }
    data = quest_json.get("data") or {}
    if not isinstance(data, dict):
        data = {}
    return {
        "quest_title": _content_blocks_to_text(data.get("quest_title")),
        "quest_answer": _content_blocks_to_text(data.get("quest_answer")),
        "quest_image": data.get("quest_image"),
        "flows": extract_flows(quest_json),
    }

