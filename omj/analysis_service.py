import base64
import json
import os
from typing import Any, Dict, List, Optional, Tuple

from google import genai

from storage.storage import get_quest


COMETAPI_KEY = os.environ.get("COMETAPI_KEY")
BASE_URL = "https://api.cometapi.com"
VISION_MODEL = os.environ.get("OMJ_VISION_MODEL", "gemini-2.5-flash")
ANALYSIS_MODEL = os.environ.get("OMJ_ANALYSIS_MODEL", "gemini-2.5-flash-lite")

_client = genai.Client(
    http_options={"api_version": "v1beta", "base_url": BASE_URL},
    api_key=COMETAPI_KEY,
)


def analyze_submission(payload: Dict[str, Any]) -> Dict[str, Any]:
    quest_id = _normalize_optional_text(payload.get("quest_id"))
    quest = get_quest(quest_id) if quest_id else None
    quest_models = _extract_models(quest)
    if not quest_models:
        quest_models = _extract_models_from_payload(payload)

    recognized_text = payload.get("recognized_text") or []
    image_b64 = payload.get("student_work_image")
    ocr_source = "client"
    warnings: List[str] = []

    if not recognized_text and image_b64:
        image_bytes = _decode_base64(image_b64)
        if image_bytes:
            if "gemini-vision" in quest_models or not quest_models:
                recognized_text, warning = _run_gemini_vision_ocr(image_bytes)
                if warning:
                    warnings.append(warning)
                ocr_source = "gemini-vision"
            elif "pix2text" in quest_models:
                recognized_text, warning = _run_pix2text_ocr(image_bytes)
                if warning:
                    warnings.append(warning)
                ocr_source = "pix2text"

    writing_events = payload.get("writing_events") or []
    writing_events = _limit_list(writing_events, 20)
    step_correctness = payload.get("step_correctness") or []
    time_weakness = payload.get("time_weakness") or []

    analysis_prompt = _build_analysis_prompt(
        problem=_normalize_optional_text(payload.get("problem")),
        recognized_text=recognized_text,
        writing_events=writing_events,
        step_correctness=step_correctness,
        time_weakness=time_weakness,
        reference_steps=_extract_reference_steps(quest),
    )

    analysis_text = ""
    if analysis_prompt:
        analysis_text = _generate_text(analysis_prompt)

    return {
        "analysis": analysis_text,
        "recognized_text": recognized_text,
        "ocr_source": ocr_source,
        "quest_id": quest_id,
        "quest_model": quest_models,
        "warnings": warnings,
    }


def _generate_text(prompt: str) -> str:
    if not COMETAPI_KEY:
        raise RuntimeError("COMETAPI_KEY is not set")
    response = _client.models.generate_content(
        model=ANALYSIS_MODEL,
        contents=prompt,
    )
    text = (response.text or "").strip()
    return _strip_code_fences(text)


def _run_gemini_vision_ocr(image_bytes: bytes) -> Tuple[List[Dict[str, Any]], Optional[str]]:
    if not COMETAPI_KEY:
        return [], "COMETAPI_KEY is not set"

    prompt = (
        "Extract handwritten text and formulas from the image.\n"
        "Return JSON array only. Each item:\n"
        '{ "text": "...", "bbox": [x1, y1, x2, y2] }\n'
        "bbox should be normalized 0~1 relative to image size."
    )
    contents = _build_image_contents(prompt, image_bytes)
    response = _client.models.generate_content(
        model=VISION_MODEL,
        contents=contents,
        config={"response_mime_type": "application/json"},
    )
    raw = _strip_code_fences((response.text or "").strip())
    try:
        data = json.loads(raw)
        if isinstance(data, list):
            return data, None
    except Exception:
        return [], "gemini-vision json parse failed"
    return [], "gemini-vision returned invalid format"


def _run_pix2text_ocr(image_bytes: bytes) -> Tuple[List[Dict[str, Any]], Optional[str]]:
    try:
        from pix2text import Pix2Text
    except Exception:
        return [], "pix2text not installed"

    try:
        import tempfile
        with tempfile.NamedTemporaryFile(suffix=".png", delete=True) as tmp:
            tmp.write(image_bytes)
            tmp.flush()
            p2t = Pix2Text()
            page = p2t(tmp.name)
    except Exception:
        return [], "pix2text failed"

    blocks = _extract_pix2text_blocks(page)
    results = []
    for block in blocks:
        if isinstance(block, dict):
            text = block.get("text") or block.get("content") or ""
            bbox = block.get("box") or block.get("bbox")
            if bbox is None:
                continue
            results.append({"text": text, "bbox": _normalize_bbox(bbox)})
    return results, None


def _extract_pix2text_blocks(page: Any) -> List[Any]:
    if isinstance(page, (list, tuple)):
        return list(page)
    for name in ("blocks", "data", "elements", "lines"):
        if hasattr(page, name):
            attr = getattr(page, name)
            return list(attr() if callable(attr) else attr)
    if hasattr(page, "to_list"):
        return list(page.to_list())
    if hasattr(page, "to_dict"):
        data = page.to_dict()
        if isinstance(data, dict) and "blocks" in data:
            return list(data["blocks"])
        if isinstance(data, list):
            return data
    return [page]


def _normalize_bbox(value: Any) -> List[float]:
    if isinstance(value, dict):
        return [
            float(value.get("x1", 0)),
            float(value.get("y1", 0)),
            float(value.get("x2", 0)),
            float(value.get("y2", 0)),
        ]
    if isinstance(value, (list, tuple)) and len(value) >= 4:
        return [float(value[0]), float(value[1]), float(value[2]), float(value[3])]
    return [0.0, 0.0, 0.0, 0.0]


def _build_image_contents(prompt: str, image_bytes: bytes) -> Any:
    try:
        from google.genai import types

        return [
            types.Content(
                role="user",
                parts=[
                    types.Part.from_text(prompt),
                    types.Part.from_bytes(data=image_bytes, mime_type="image/png"),
                ],
            )
        ]
    except Exception:
        encoded = base64.b64encode(image_bytes).decode("utf-8")
        return [
            {
                "role": "user",
                "parts": [
                    {"text": prompt},
                    {"inline_data": {"mime_type": "image/png", "data": encoded}},
                ],
            }
        ]


def _build_analysis_prompt(
    *,
    problem: Optional[str],
    recognized_text: List[Dict[str, Any]],
    writing_events: List[Dict[str, Any]],
    step_correctness: List[Dict[str, Any]],
    time_weakness: List[Dict[str, Any]],
    reference_steps: List[str],
) -> str:
    sections: List[str] = [
        "You are a math tutor analyzing a student's handwritten solution.",
        "Summarize the solving process, find likely mistakes, and provide feedback.",
        "Do not mention raw stroke data. Use writing_events only.",
    ]

    if problem:
        sections.append(f"Problem:\n{problem}")

    if reference_steps:
        steps_text = "\n".join(f"{i+1}. {step}" for i, step in enumerate(reference_steps))
        sections.append(f"Reference steps:\n{steps_text}")

    if recognized_text:
        sections.append(
            "Recognized text (OCR/Vision):\n"
            f"{json.dumps(recognized_text, ensure_ascii=False)}"
        )

    if writing_events:
        sections.append(
            "Writing events:\n"
            f"{json.dumps(writing_events, ensure_ascii=False)}"
        )

    if step_correctness:
        sections.append(
            "Step correctness:\n"
            f"{json.dumps(step_correctness, ensure_ascii=False)}"
        )

    if time_weakness:
        sections.append(
            "Time weakness:\n"
            f"{json.dumps(time_weakness, ensure_ascii=False)}"
        )

    sections.append(
        "Respond with 3-5 bullet points in Korean, focusing on reasoning gaps and next steps."
    )
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


def _extract_reference_steps(quest: Optional[Dict[str, Any]]) -> List[str]:
    if not quest:
        return []
    solves = quest.get("solves") or []
    steps: List[str] = []

    def visit(step: Dict[str, Any]) -> None:
        flow = _content_to_text(step.get("flow"))
        if flow:
            steps.append(flow)
        for branch in step.get("branches") or []:
            if isinstance(branch, dict):
                visit(branch)

    for step in solves:
        if isinstance(step, dict):
            visit(step)
    return steps


def _content_to_text(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, dict):
        blocks = value.get("blocks")
        if isinstance(blocks, list):
            return " ".join(
                str(block.get("content", "")).strip()
                for block in blocks
                if isinstance(block, dict) and block.get("content")
            ).strip()
        if "content" in value:
            return str(value.get("content") or "").strip()
    if isinstance(value, list):
        return " ".join(
            str(block.get("content", "")).strip()
            if isinstance(block, dict)
            else str(block).strip()
            for block in value
            if str(block).strip()
        ).strip()
    return str(value).strip()


def _decode_base64(raw: str) -> bytes:
    if not raw:
        return b""
    try:
        return base64.b64decode(raw)
    except Exception:
        return b""


def _limit_list(values: List[Any], limit: int) -> List[Any]:
    if limit <= 0:
        return []
    return list(values[:limit])


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
