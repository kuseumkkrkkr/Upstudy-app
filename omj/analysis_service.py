import base64
import json
import os
from typing import Any, Dict, List, Optional, Tuple

from google import genai

from storage.storage import get_quest
from clean_riddles import build_clean_payload
from env_loader import load_env

load_env()


COMETAPI_KEY = os.environ.get("COMETAPI_KEY")
BASE_URL = "https://api.cometapi.com"
ANALYSIS_MODEL = os.environ.get("OMJ_ANALYSIS_MODEL", "gemini-3.1-flash-lite")

_client = genai.Client(
    http_options={"api_version": "v1beta", "base_url": BASE_URL},
    api_key=COMETAPI_KEY,
)

_DEFAULT_OCR_PROMPT = """
너는 수학 OCR 추출기다.
목표:
1) 이미지 내 모든 공식/식/등식/표현을 그대로 추출한다.
2) 히트맵에서 보라색(쓰기+지우기)과 겹치는 공식만 따로 추출한다.

규칙:
- 보정/교정/정규화 금지. 보이는 그대로 출력한다.
- 의미 추정 금지.
- 중복은 그대로 두어도 된다.
- 텍스트 설명 금지. JSON만 출력.

출력 JSON 키:
- all_formulas: [string, ...]  # 이미지 내 모든 공식
- purple_formulas: [string, ...]  # 보라색 겹침 공식
- all_ocr: null
- hit_mapped: null
- user_answer: null
"""

_DEFAULT_GRADING_PROMPT = """
너는 수학 채점 교사다. 낙관 편향을 낮춰서 엄격하게 채점하라.

입력:
- QUEST_TITLE: 문제 본문(평문)
- QUEST_ANSWER: 정답(평문)
- QUEST_IMAGE: 문제 이미지가 있으면 제공됨 (없으면 "none")
- FLOW_STEPS: flow_number(0부터), answer_riddle(풀이 설명), hash_tag
- OCR_ALL_FORMULAS: OCR로 추출된 전체 공식 목록
- OCR_PURPLE_FORMULAS: 보라색(쓰기+지우기 겹침) 영역 공식 목록

채점 원칙(중요):
1) OCR_ALL_FORMULAS에 명시적으로 존재하는 공식만 인정한다. 없으면 "X".
2) 애매하면 "X". 추측 금지.
3) 중간 단계 누락, 논리 비약, 계산 실수 가능성이 있으면 "X".
4) 정답만 맞고 과정이 전혀 확인되지 않으면 "X".
5) 각 flow는 독립적으로 판단하되, 다음 단계가 성립하려면 이전 단계가 명확해야 한다.
6) 최종 결과가 QUEST_ANSWER와 불일치하면 마지막 flow는 반드시 "X".
7) 채점은 OCR 목록만 사용하며, 이미지 내용을 직접 추정하지 않는다.

작업:
1) 각 flow를 순서대로 O/X 판단.
2) OCR_PURPLE_FORMULAS와 매칭되는 flow_number를 in_panic에 넣는다. 없으면 [].
3) OCR 목록을 근거로 ai_opinion을 짧게 기록한다.

출력은 JSON만:
{
  "status": [
    {"flow_number": 0, "status": "O"},
    {"flow_number": 1, "status": "X"}
  ],
  "in_panic": [1],
  "ai_opinion": "...",
  "o_reasons": [
    {"flow_number": 0, "reason": "O로 판단한 근거 요약"}
  ]
}

추가 규칙:
- status에는 모든 flow_number가 반드시 포함되어야 한다.
- status 값은 "O" 또는 "X"만 허용.
- in_panic에는 중복 없이 flow_number만 넣는다.
- o_reasons는 O인 flow만 포함하고, 이유는 한두 문장으로 간단히 쓴다.
- JSON 외의 텍스트 금지.
"""


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
    if not ocr_all_formulas and not ocr_purple_formulas:
        ocr_result = analyze_pregrade(
            payload,
            student_work_image_bytes=student_work_image_bytes,
            heatmap_image_bytes=heatmap_image_bytes,
        )
        ocr_all_formulas = _normalize_ocr_list(ocr_result.get("all_formulas"))
        ocr_purple_formulas = _normalize_ocr_list(ocr_result.get("purple_formulas"))

    clean_payload = build_clean_payload(quest if isinstance(quest, dict) else None)
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
        )
        if debug_mode
        else None
    )
    return {
        "status": status,
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
    analysis_model = _normalize_optional_text(payload.get("analysis_model")) or ANALYSIS_MODEL
    gen_config = _normalize_gen_config(payload.get("gen_config"))

    if student_work_image_bytes is None and payload.get("student_work_image"):
        student_work_image_bytes = _decode_base64(payload.get("student_work_image"))
    if heatmap_image_bytes is None and payload.get("heatmap_image"):
        heatmap_image_bytes = _decode_base64(payload.get("heatmap_image"))

    prompt = _augment_ocr_prompt(
        analysis_prompt=analysis_prompt,
    )
    images: List[bytes] = []
    if student_work_image_bytes:
        images.append(student_work_image_bytes)
    if heatmap_image_bytes:
        images.append(heatmap_image_bytes)
    result_json, warning = _generate_json_with_images(
        prompt=prompt,
        model=analysis_model,
        images=images,
        gen_config=gen_config,
    )
    if warning:
        warnings.append(warning)
    all_formulas = _normalize_ocr_list(result_json.get("all_formulas"))
    purple_formulas = _normalize_ocr_list(result_json.get("purple_formulas"))
    all_ocr = result_json.get("all_ocr")
    hit_mapped = result_json.get("hit_mapped")
    user_answer = result_json.get("user_answer")
    print(
        "[ocr payload] all_formulas=%s purple_formulas=%s"
        % (len(all_formulas), len(purple_formulas))
    )
    debug_info = (
        _build_debug_info(
            prompt=prompt,
            model=analysis_model,
            gen_config=gen_config,
            payload=payload,
            result_json=result_json,
            student_work_image_bytes=student_work_image_bytes,
            heatmap_image_bytes=heatmap_image_bytes,
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
        "ocr_source": "gemini",
        "debug": debug_info,
    }


def _build_multi_image_contents(
    prompt: str,
    images: List[bytes],
) -> Any:
    images = [img for img in images if img]
    if not images:
        return prompt
    try:
        from google.genai import types

        parts = [types.Part.from_text(prompt)]
        for image_bytes in images:
            parts.append(
                types.Part.from_bytes(
                    data=image_bytes, mime_type=_infer_mime_type(image_bytes)
                )
            )
        return [types.Content(role="user", parts=parts)]
    except Exception:
        parts = [{"text": prompt}]
        for image_bytes in images:
            encoded = base64.b64encode(image_bytes).decode("utf-8")
            parts.append(
                {
                    "inline_data": {
                        "mime_type": _infer_mime_type(image_bytes),
                        "data": encoded,
                    }
                }
            )
        return [{"role": "user", "parts": parts}]
def _generate_json_with_images(
    *,
    prompt: str,
    model: str,
    images: List[bytes],
    gen_config: Optional[Dict[str, Any]] = None,
) -> Tuple[Dict[str, Any], Optional[str]]:
    if not COMETAPI_KEY:
        return {}, "COMETAPI_KEY is not set"
    contents = _build_multi_image_contents(prompt, images)
    # Default model behaviors based on the provided example
    config: Dict[str, Any] = {
        "response_mime_type": "application/json",
        "temperature": 0.1,
        "top_p": 0.3,
        "media_resolution": "MEDIA_RESOLUTION_MEDIUM",
    }
    if gen_config:
        config.update(gen_config)
    response = _client.models.generate_content(
        model=model,
        contents=contents,
        config=config,
    )
    raw = _strip_code_fences((response.text or "").strip())
    try:
        data = json.loads(raw)
        if isinstance(data, dict):
            return data, None
    except Exception:
        return {}, "grading json parse failed"
    return {}, "grading returned invalid format"
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


def _infer_mime_type(image_bytes: bytes) -> str:
    if len(image_bytes) >= 3 and image_bytes[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if len(image_bytes) >= 8 and image_bytes[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    return "application/octet-stream"


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


def _delete_uploaded_files(files: List[Any]) -> None:
    if not files:
        return
    for uploaded in files:
        try:
            name = getattr(uploaded, "name", None) or getattr(uploaded, "id", None)
            if name:
                _client.files.delete(name)
        except Exception:
            continue


def _normalize_optional_text(value: Any) -> Optional[str]:
    if value is None:
        return None
    text = str(value).strip()
    return text if text else None


def _strip_code_fences(text: str) -> str:
    if text.startswith("```"):
        text = text.lstrip("`").split("\n", 1)[-1]
    if text.endswith("```"):
        text = text.rsplit("\n", 1)[0]
    return text.strip()





