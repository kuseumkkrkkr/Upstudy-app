import base64
import json
import os
from typing import Any, Dict, List, Optional, Tuple

from storage.storage import get_quest
from clean_riddles import build_clean_payload
from env_loader import load_env
from services.ai.sam_client import (
    DEFAULT_ANALYSIS_MODEL,
    SAM_API_KEY_ENV,
    generate_json,
    is_sam_configured,
)
from services.ai.prompts import solve_grading_prompt, solve_ocr_prompt
from services.ocr.texteller_grid import extract_math_with_texteller_grid

load_env()


ANALYSIS_MODEL = DEFAULT_ANALYSIS_MODEL
# 로컬 TexTeller 실패 때만 사용하는 Qwen 비전 OCR 모델이다.
QWEN_OCR_MODEL = os.getenv("OMJ_OCR_QWEN_MODEL", "fw-qwen3.7-plus")

_DEFAULT_OCR_PROMPT = solve_ocr_prompt()
_DEFAULT_GRADING_PROMPT = solve_grading_prompt()


def analyze_submission(
    payload: Dict[str, Any],
    *,
    student_work_image_bytes: Optional[bytes] = None,
    problem_image_bytes: Optional[bytes] = None,
    heatmap_image_bytes: Optional[bytes] = None,
) -> Dict[str, Any]:
    debug_mode = _parse_debug_flag(payload.get("debug"))
    quest_id = _normalize_optional_text(payload.get("quest_id"))
    quest_json = payload.get("quest_json")
    if isinstance(quest_json, str):
        try:
            quest_json = json.loads(quest_json)
        except Exception:
            quest_json = None
    quest = quest_json if isinstance(quest_json, dict) else (get_quest(quest_id) if quest_id else None)
    quest_models = _extract_models(quest)
    if not quest_models:
        quest_models = _extract_models_from_payload(payload)

    warnings: List[str] = []
    ocr_debug_details: Dict[str, Any] = {"source": "request_payload", "warnings": []}

    analysis_prompt = _normalize_optional_text(payload.get("analysis_prompt")) or _DEFAULT_GRADING_PROMPT
    analysis_model = _normalize_optional_text(payload.get("analysis_model")) or ANALYSIS_MODEL
    gen_config = _normalize_gen_config(payload.get("gen_config"))

    if student_work_image_bytes is None and payload.get("student_work_image"):
        student_work_image_bytes = _decode_base64(payload.get("student_work_image"))
    if problem_image_bytes is None and payload.get("problem_image"):
        problem_image_bytes = _decode_base64(payload.get("problem_image"))
    if heatmap_image_bytes is None and payload.get("heatmap_image"):
        heatmap_image_bytes = _decode_base64(payload.get("heatmap_image"))

    ocr_all_formulas = _normalize_ocr_list(payload.get("ocr_all_formulas"))
    ocr_purple_formulas = _normalize_ocr_list(payload.get("ocr_purple_formulas"))
    if not ocr_all_formulas:
        ocr_all_formulas = _normalize_ocr_list(payload.get("all_formulas"))
    if not ocr_purple_formulas:
        ocr_purple_formulas = _normalize_ocr_list(payload.get("purple_formulas"))
    if not ocr_all_formulas and not ocr_purple_formulas:
        ocr_payload = dict(payload)
        # A grading prompt override must not replace the OCR extraction prompt.
        ocr_payload["analysis_prompt"] = payload.get("ocr_analysis_prompt")
        ocr_result = analyze_pregrade(
            ocr_payload,
            student_work_image_bytes=student_work_image_bytes,
            heatmap_image_bytes=heatmap_image_bytes,
        )
        ocr_all_formulas = _normalize_ocr_list(ocr_result.get("all_formulas"))
        ocr_purple_formulas = _normalize_ocr_list(ocr_result.get("purple_formulas"))
        warnings.extend(_normalize_warning_list(ocr_result.get("warnings")))
        ocr_debug_details = {
            "source": ocr_result.get("ocr_source", "qwen_vision"),
            "warnings": _normalize_warning_list(ocr_result.get("warnings")),
        }

    clean_payload = _build_grading_context(
        quest if isinstance(quest, dict) else None,
        payload,
    )
    flow_items = clean_payload.get("flows") or []
    prompt = _augment_grading_prompt(
        analysis_prompt=analysis_prompt,
        quest_title=clean_payload.get("quest_title") or "",
        quest_answer=clean_payload.get("quest_answer") or "",
        quest_image=clean_payload.get("quest_image"),
        flow_steps=flow_items,
        ocr_all_formulas=ocr_all_formulas,
        ocr_purple_formulas=ocr_purple_formulas,
    )
    images: List[bytes] = []

    result_json, warning = _generate_json_with_images(
        prompt=prompt,
        model=analysis_model,
        images=images,
        gen_config=gen_config,
    )
    if warning:
        warnings.append(warning)

    status = _normalize_status_list(result_json.get("status"), len(flow_items))
    in_panic = _normalize_in_panic(result_json.get("in_panic"), len(flow_items))
    ai_opinion = _normalize_optional_text(result_json.get("ai_opinion")) or ""
    step_correctness = _status_to_step_correctness(status)
    is_correct = bool(status) and all(
        str(item.get("status", "")).upper() == "O" for item in status
    )
    o_reasons = result_json.get("o_reasons")
    if isinstance(o_reasons, list):
        o_flow_numbers = set()
        for item in status:
            if item.get("status") != "O":
                continue
            try:
                o_flow_numbers.add(int(item.get("flow_number")))
            except (TypeError, ValueError):
                continue
        for entry in o_reasons:
            if not isinstance(entry, dict):
                continue
            try:
                flow_number = int(entry.get("flow_number"))
            except (TypeError, ValueError):
                continue
            reason = _normalize_optional_text(entry.get("reason")) or ""
            if flow_number in o_flow_numbers and reason:
                print(f"[grading reason] flow={flow_number} reason={reason}")

    debug_info = (
        _build_debug_info(
            prompt=prompt,
            model=analysis_model,
            gen_config=gen_config,
            payload=payload,
            result_json=result_json,
            student_work_image_bytes=student_work_image_bytes,
            problem_image_bytes=problem_image_bytes,
            heatmap_image_bytes=heatmap_image_bytes,
            ocr_all_formulas=ocr_all_formulas,
            ocr_purple_formulas=ocr_purple_formulas,
            ocr_details=ocr_debug_details,
        )
        if debug_mode
        else None
    )
    return {
        "status": status,
        "step_correctness": step_correctness,
        "is_correct": is_correct,
        "in_panic": in_panic,
        "ai_opinion": ai_opinion,
        "quest_id": quest_id,
        "quest_model": quest_models,
        "warnings": warnings,
        "debug": debug_info,
    }


def analyze_pregrade(
    payload: Dict[str, Any],
    *,
    student_work_image_bytes: Optional[bytes] = None,
    heatmap_image_bytes: Optional[bytes] = None,
) -> Dict[str, Any]:
    debug_mode = _parse_debug_flag(payload.get("debug"))
    warnings: List[str] = []
    analysis_prompt = _normalize_optional_text(payload.get("analysis_prompt")) or _DEFAULT_OCR_PROMPT
    # Qwen은 TexTeller가 실패한 요청에만 사용하고 채점 모델은 OCR 문자열만 받는다.
    analysis_model = _normalize_optional_text(payload.get("ocr_analysis_model")) or QWEN_OCR_MODEL
    gen_config = _normalize_gen_config(payload.get("gen_config"))

    if student_work_image_bytes is None and payload.get("student_work_image"):
        student_work_image_bytes = _decode_base64(payload.get("student_work_image"))
    if heatmap_image_bytes is None and payload.get("heatmap_image"):
        heatmap_image_bytes = _decode_base64(payload.get("heatmap_image"))

    # OCR은 창작이 아니라 전사 작업이므로 Qwen 응답 편차를 최소화한다.
    ocr_gen_config = dict(gen_config or {})
    ocr_gen_config.setdefault("temperature", 0.0)
    ocr_gen_config.setdefault("top_p", 0.1)
    prompt = _augment_ocr_prompt(
        analysis_prompt=analysis_prompt,
    )
    images: List[bytes] = []
    if student_work_image_bytes:
        images.append(student_work_image_bytes)
    if heatmap_image_bytes:
        images.append(heatmap_image_bytes)
    texteller_result = extract_math_with_texteller_grid(
        student_work_image_bytes or b"",
        payload.get("writing_events"),
    )
    if texteller_result.get("accepted"):
        result_json: Dict[str, Any] = {}
        warning: Optional[str] = None
        ocr_result = texteller_result
    else:
        # TexTeller가 실패·포화·비정상 출력일 때만 Qwen이 원본 이미지 OCR을 담당한다.
        warnings.extend(_normalize_warning_list(texteller_result.get("warnings")))
        result_json, warning = _generate_json_with_images(
            prompt=prompt,
            model=analysis_model,
            images=images,
            gen_config=ocr_gen_config,
        )
        qwen_formulas = _normalize_ocr_list(result_json.get("all_formulas"))
        qwen_purple = _normalize_ocr_list(result_json.get("purple_formulas"))
        if warning:
            warnings.append(f"Qwen OCR failed: {warning}")
        elif not qwen_formulas:
            warnings.append("Qwen OCR returned no formulas")
        ocr_result = {
            **result_json,
            "all_formulas": qwen_formulas,
            "purple_formulas": qwen_purple,
            "ocr_source": "qwen_vision" if qwen_formulas else "qwen_vision_empty",
            "accepted": bool(qwen_formulas),
        }
    warnings.extend(_normalize_warning_list(ocr_result.get("warnings")))
    all_formulas = _normalize_ocr_list(ocr_result.get("all_formulas"))
    purple_formulas = _normalize_ocr_list(ocr_result.get("purple_formulas"))
    all_ocr = ocr_result.get("all_ocr")
    hit_mapped = ocr_result.get("hit_mapped")
    user_answer = ocr_result.get("user_answer")
    print(
        "[ocr payload] source=%s all_formulas=%s purple_formulas=%s"
        % (ocr_result.get("ocr_source"), len(all_formulas), len(purple_formulas))
    )
    debug_info = (
        _build_debug_info(
            prompt=prompt,
            model=analysis_model,
            gen_config=ocr_gen_config,
            payload=payload,
            result_json=result_json,
            student_work_image_bytes=student_work_image_bytes,
            heatmap_image_bytes=heatmap_image_bytes,
            ocr_all_formulas=all_formulas,
            ocr_purple_formulas=purple_formulas,
            ocr_details={
                "source": ocr_result.get("ocr_source", "qwen_vision"),
                "texteller": texteller_result,
                "warnings": warnings,
            },
        )
        if debug_mode
        else None
    )
    return {
        "all_formulas": all_formulas,
        "purple_formulas": purple_formulas,
        "all_ocr": all_ocr,
        "hit_mapped": hit_mapped,
        "user_answer": user_answer,
        "warnings": warnings,
        "ocr_source": str(ocr_result.get("ocr_source") or "qwen_vision_empty"),
        "debug": debug_info,
    }


def _generate_json_with_images(
    *,
    prompt: str,
    model: str,
    images: List[bytes],
    gen_config: Optional[Dict[str, Any]] = None,
) -> Tuple[Dict[str, Any], Optional[str]]:
    if not is_sam_configured():
        return {}, f"{SAM_API_KEY_ENV} is not set"

    config: Dict[str, Any] = {"temperature": 0.1, "top_p": 0.3, "max_tokens": 4096}
    if gen_config:
        if "temperature" in gen_config:
            config["temperature"] = gen_config["temperature"]
        if "top_p" in gen_config:
            config["top_p"] = gen_config["top_p"]
        if "max_output_tokens" in gen_config:
            config["max_tokens"] = gen_config["max_output_tokens"]

    try:
        data = generate_json(
            model=model,
            prompt=prompt,
            images=images,
            temperature=config["temperature"],
            top_p=config["top_p"],
            max_tokens=config["max_tokens"],
        )
        if isinstance(data, dict):
            return data, None
    except json.JSONDecodeError:
        return {}, "grading json parse failed"
    except Exception as exc:
        return {}, f"grading request failed: {exc}"
    return {}, "grading returned invalid format"


def _normalize_warning_list(value: Any) -> List[str]:
    """필요 변수: 경고 문자열 또는 목록. 작동 원리: API 응답·디버그 화면이 안전하게 표시할 문자열 목록으로 정리한다."""
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item) for item in value if str(item).strip()]
    return [str(value)] if str(value).strip() else []


def _normalize_status_list(value: Any, flow_count: int) -> List[Dict[str, Any]]:
    results: List[Dict[str, Any]] = [
        {"flow_number": i, "status": "X"} for i in range(max(flow_count, 0))
    ]
    if flow_count <= 0:
        return results

    def _set_status(index: int, status_value: Any) -> None:
        if index < 0 or index >= flow_count:
            return
        text = str(status_value).strip().upper()
        if text in {"O", "X"}:
            results[index]["status"] = text

    if isinstance(value, list):
        for idx, entry in enumerate(value):
            if isinstance(entry, dict):
                flow_number = entry.get("flow_number")
                if flow_number is None and "step_id" in entry:
                    flow_number = entry.get("step_id")
                if flow_number is None and "index" in entry:
                    flow_number = entry.get("index")
                try:
                    flow_index = int(flow_number)
                except (TypeError, ValueError):
                    flow_index = idx
                _set_status(flow_index, entry.get("status") or entry.get("correct") or entry.get("value"))
            else:
                _set_status(idx, entry)
        return results
    if isinstance(value, dict):
        flow_number = value.get("flow_number")
        try:
            flow_index = int(flow_number)
        except (TypeError, ValueError):
            flow_index = 0
        _set_status(flow_index, value.get("status") or value.get("correct") or value.get("value"))
        return results
    return results


def _normalize_in_panic(value: Any, flow_count: int) -> List[int]:
    if flow_count <= 0:
        return []
    if value is None:
        return []
    candidates: List[int] = []
    if isinstance(value, list):
        raw = value
    else:
        raw = [value]
    for item in raw:
        try:
            idx = int(item)
        except (TypeError, ValueError):
            continue
        if 0 <= idx < flow_count:
            candidates.append(idx)
    # unique preserve order
    seen = set()
    result: List[int] = []
    for idx in candidates:
        if idx in seen:
            continue
        seen.add(idx)
        result.append(idx)
    return result


def _status_to_step_correctness(status: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    results: List[Dict[str, Any]] = []
    for index, item in enumerate(status):
        try:
            flow_number = int(item.get("flow_number", index))
        except (TypeError, ValueError):
            flow_number = index
        status_text = str(item.get("status", "")).strip().upper()
        correct = status_text == "O"
        results.append(
            {
                "step_id": flow_number + 1,
                "flow_number": flow_number,
                "correct": correct,
                "similarity": 1.0 if correct else 0.0,
            }
        )
    return results


def _normalize_nullable_text(value: Any) -> Optional[str]:
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    lowered = text.lower()
    if lowered in {"null", "none", "nil", "?놁쓬"}:
        return None
    return text


def _normalize_ocr_list(value: Any) -> List[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item) for item in value if item is not None]
    if isinstance(value, str):
        return [value]
    return [str(value)]


def _normalize_hash_tags(value: Any) -> List[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]
    text = str(value).strip()
    return [text] if text else []


def _parse_debug_flag(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    text = str(value).strip().lower()
    return text in {"true", "1", "yes", "y", "debug"}


def _normalize_gen_config(value: Any) -> Optional[Dict[str, Any]]:
    if not isinstance(value, dict):
        return None
    config: Dict[str, Any] = {}
    if "temperature" in value:
        try:
            temp = float(value["temperature"])
            config["temperature"] = max(0.0, min(2.0, temp))
        except (TypeError, ValueError):
            pass
    if "top_p" in value:
        try:
            top_p = float(value["top_p"])
            config["top_p"] = max(0.0, min(1.0, top_p))
        except (TypeError, ValueError):
            pass
    if "thinking_level" in value:
        level = str(value["thinking_level"]).strip().upper()
        if level:
            config["thinking_config"] = {"thinking_level": level}
    if "thinking_config" in value and isinstance(value["thinking_config"], dict):
        config["thinking_config"] = dict(value["thinking_config"])
    if "media_resolution" in value:
        media_resolution = str(value["media_resolution"]).strip().upper()
        if media_resolution:
            config["media_resolution"] = media_resolution
    if "top_k" in value:
        try:
            top_k = int(value["top_k"])
            if top_k >= 0:
                config["top_k"] = top_k
        except (TypeError, ValueError):
            pass
    if "max_output_tokens" in value:
        try:
            max_tokens = int(value["max_output_tokens"])
            if max_tokens > 0:
                config["max_output_tokens"] = max_tokens
        except (TypeError, ValueError):
            pass
    return config or None


def _sanitize_payload_for_debug(payload: Dict[str, Any]) -> Dict[str, Any]:
    if not isinstance(payload, dict):
        return {}
    drop_keys = {"student_work_image", "problem_image", "heatmap_image"}
    return {key: value for key, value in payload.items() if key not in drop_keys}


def _build_debug_info(
    *,
    prompt: str,
    model: str,
    gen_config: Optional[Dict[str, Any]] = None,
    payload: Dict[str, Any],
    result_json: Dict[str, Any],
    student_work_image_bytes: Optional[bytes] = None,
    problem_image_bytes: Optional[bytes] = None,
    heatmap_image_bytes: Optional[bytes] = None,
    ocr_all_formulas: Optional[List[str]] = None,
    ocr_purple_formulas: Optional[List[str]] = None,
    ocr_details: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    return {
        "model": model,
        "gen_config": gen_config,
        "prompt": prompt,
        "payload": _sanitize_payload_for_debug(payload),
        "result_json": result_json,
        "ocr": {
            "all_formulas": ocr_all_formulas or [],
            "purple_formulas": ocr_purple_formulas or [],
            **(ocr_details or {}),
        },
        "image_sizes": {
            "student_work": len(student_work_image_bytes or b""),
            "problem": len(problem_image_bytes or b""),
            "heatmap": len(heatmap_image_bytes or b""),
        },
    }


def _safe_json_dumps(value: Any) -> str:
    try:
        return json.dumps(value, ensure_ascii=False, default=str)
    except Exception:
        return json.dumps(str(value), ensure_ascii=False)


def _decode_base64(raw: Any) -> bytes:
    if not raw:
        return b""
    if not isinstance(raw, str):
        return b""
    try:
        return base64.b64decode(raw)
    except Exception:
        return b""


def _augment_grading_prompt(
    *,
    analysis_prompt: str,
    quest_title: str,
    quest_answer: str,
    quest_image: Optional[str],
    flow_steps: List[Dict[str, Any]],
    ocr_all_formulas: List[str],
    ocr_purple_formulas: List[str],
) -> str:
    sections = [analysis_prompt.strip()]
    sections.append("QUEST_TITLE:\n" + (quest_title or ""))
    sections.append("QUEST_ANSWER:\n" + (quest_answer or ""))
    sections.append("QUEST_IMAGE:\n" + (quest_image if quest_image else "none"))
    sections.append("FLOW_STEPS:\n" + _safe_json_dumps(flow_steps))
    sections.append("OCR_ALL_FORMULAS:\n" + _safe_json_dumps(ocr_all_formulas))
    sections.append("OCR_PURPLE_FORMULAS:\n" + _safe_json_dumps(ocr_purple_formulas))
    return "\n\n".join(section for section in sections if section)


def _augment_ocr_prompt(
    *,
    analysis_prompt: str,
) -> str:
    sections = [analysis_prompt.strip()]
    return "\n\n".join(section for section in sections if section)


def _build_grading_context(
    quest: Optional[Dict[str, Any]],
    payload: Dict[str, Any],
) -> Dict[str, Any]:
    clean_payload = build_clean_payload(quest if isinstance(quest, dict) else None)
    if not clean_payload.get("quest_title"):
        clean_payload["quest_title"] = (
            _normalize_optional_text(payload.get("problem")) or ""
        )
    if not clean_payload.get("quest_answer"):
        clean_payload["quest_answer"] = (
            _normalize_optional_text(payload.get("answer"))
            or _normalize_optional_text(payload.get("quest_answer"))
            or ""
        )
    if not clean_payload.get("flows"):
        clean_payload["flows"] = _reference_steps_to_flows(
            payload.get("reference_steps")
        )
    return clean_payload


def _reference_steps_to_flows(value: Any) -> List[Dict[str, Any]]:
    if not isinstance(value, list):
        return []
    flows: List[Dict[str, Any]] = []
    for index, entry in enumerate(value):
        if not isinstance(entry, dict):
            continue
        flow_number = entry.get("flow_number")
        if flow_number is None:
            flow_number = entry.get("step_id")
            try:
                flow_number = int(flow_number) - 1
            except (TypeError, ValueError):
                flow_number = index
        try:
            flow_index = int(flow_number)
        except (TypeError, ValueError):
            flow_index = index
        answer_text = (
            _normalize_optional_text(entry.get("answer_riddle"))
            or _normalize_optional_text(entry.get("answer_text"))
            or _normalize_optional_text(entry.get("flow_text"))
            or _normalize_optional_text(entry.get("hint_text"))
            or ""
        )
        flows.append(
            {
                "flow_number": flow_index,
                "hash_tag": _normalize_hash_tags(
                    entry.get("hash_tags") or entry.get("hash_tag")
                ),
                "answer_riddle": answer_text,
            }
        )
    return flows


def _extract_models(quest: Optional[Dict[str, Any]]) -> List[str]:
    if not quest:
        return []
    header = quest.get("header", {}) or {}
    quest_model = header.get("quest_model")
    if isinstance(quest_model, dict):
        models = quest_model.get("models")
    else:
        models = quest_model
    if isinstance(models, list):
        return [str(model) for model in models if str(model).strip()]
    if isinstance(models, str):
        return [models]
    return []


def _extract_models_from_payload(payload: Dict[str, Any]) -> List[str]:
    raw = payload.get("quest_model")
    if isinstance(raw, list):
        return [str(model) for model in raw if str(model).strip()]
    if isinstance(raw, dict):
        models = raw.get("models")
        if isinstance(models, list):
            return [str(model) for model in models if str(model).strip()]
    if isinstance(raw, str) and raw.strip():
        return [raw.strip()]
    return []


def _normalize_optional_text(value: Any) -> Optional[str]:
    if value is None:
        return None
    text = str(value).strip()
    return text if text else None
