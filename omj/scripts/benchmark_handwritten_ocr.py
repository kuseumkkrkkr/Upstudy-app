"""공개 MathWriting 필기 수식 표본으로 Qwen·TexTeller OCR을 비교한다."""
from __future__ import annotations

import argparse
import io
import json
import re
import sys
import tarfile
import time
import xml.etree.ElementTree as ET
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any
from urllib.request import urlopen

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from analysis_service import QWEN_OCR_MODEL
from services.ai.prompts import solve_ocr_prompt
from services.ai.sam_client import generate_json
from services.ocr.texteller_grid import extract_math_with_texteller_grid


DATASET_NAME = "Google MathWriting 2024 excerpt/test"
DATASET_URL = "https://storage.googleapis.com/mathwriting_data/mathwriting-2024-excerpt.tgz"
INKML_NAMESPACE = {"ink": "http://www.w3.org/2003/InkML"}


def _normalize_formula(value: str) -> str:
    """필요 변수: 정답 또는 OCR 수식. 작동 원리: LaTex 표기·공백·동등한 연산자 차이를 최소한으로 정리해 문자열 비교 편향을 낮춘다."""
    text = (value or "").lower().strip()
    text = text.replace("\\left", "").replace("\\right", "")
    text = text.replace("\\times", "*").replace("×", "*").replace("−", "-")
    text = text.replace("{", "").replace("}", "")
    text = re.sub(r"\\text\{([^}]*)\}", r"\1", text)
    return re.sub(r"\s+", "", text)


def _best_formula(value: Any) -> str:
    """필요 변수: 모델의 all_formulas 값. 작동 원리: 첫 번째 비어 있지 않은 수식을 선택해 한 줄 수식 데이터셋과 비교한다."""
    if not isinstance(value, list):
        return ""
    return next((str(item).strip() for item in value if str(item).strip()), "")


def _score(expected: str, actual: str) -> dict[str, Any]:
    """필요 변수: 정답·OCR 결과. 작동 원리: 정규화 후 정확 일치와 문자열 유사도를 함께 산출한다."""
    normalized_expected = _normalize_formula(expected)
    normalized_actual = _normalize_formula(actual)
    return {
        "exact": bool(normalized_expected) and normalized_expected == normalized_actual,
        "similarity": round(
            SequenceMatcher(None, normalized_expected, normalized_actual).ratio(), 4
        ),
    }


def _fetch_samples(count: int) -> list[dict[str, Any]]:
    """필요 변수: 표본 수. 작동 원리: 공식 MathWriting excerpt의 test InkML을 메모리에서 획·정답·PNG로 변환한다."""
    with urlopen(DATASET_URL, timeout=60) as response:  # nosec B310 - Google 공식 고정 HTTPS 자료만 사용한다.
        archive = tarfile.open(fileobj=io.BytesIO(response.read()), mode="r:gz")
    names = sorted(name for name in archive.getnames() if "/test/" in name and name.endswith(".inkml"))[:count]
    return [_parse_inkml_sample(archive.extractfile(name).read(), name) for name in names]


def _parse_inkml_sample(content: bytes, name: str) -> dict[str, Any]:
    """필요 변수: InkML 바이트·파일명. 작동 원리: 좌표를 제품 화면 범위로 정규화하고 동일 획으로 검은 PNG를 렌더링한다."""
    root = ET.fromstring(content)
    truth = next(
        (
            annotation.text or ""
            for annotation in root.findall("ink:annotation", INKML_NAMESPACE)
            if annotation.attrib.get("type") == "normalizedLabel"
        ),
        "",
    )
    strokes: list[list[tuple[float, float]]] = []
    for trace in root.findall("ink:trace", INKML_NAMESPACE):
        points: list[tuple[float, float]] = []
        for item in (trace.text or "").replace("\n", " ").split(","):
            values = item.strip().split()
            if len(values) >= 2:
                points.append((float(values[0]), float(values[1])))
        if len(points) >= 2:
            strokes.append(points)
    min_x = min(x for stroke in strokes for x, _ in stroke)
    min_y = min(y for stroke in strokes for _, y in stroke)
    max_x = max(x for stroke in strokes for x, _ in stroke)
    max_y = max(y for stroke in strokes for _, y in stroke)
    scale = min(1.0, 900 / max(1.0, max_x - min_x, max_y - min_y))
    events = [
        {
            "stroke_id": index,
            "width": 3.0,
            "points": [
                {"x": (x - min_x) * scale + 20, "y": (y - min_y) * scale + 20}
                for x, y in stroke
            ],
        }
        for index, stroke in enumerate(strokes)
    ]
    width = max(60, round((max_x - min_x) * scale + 40))
    height = max(60, round((max_y - min_y) * scale + 40))
    image = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(image)
    for event in events:
        draw.line([(point["x"], point["y"]) for point in event["points"]], fill="black", width=3, joint="curve")
    output = io.BytesIO()
    image.save(output, format="PNG")
    return {"id": Path(name).stem, "truth": truth, "image_bytes": output.getvalue(), "writing_events": events}


def _run_remote(image_bytes: bytes) -> tuple[str, str | None, float]:
    """필요 변수: 필기 이미지. 작동 원리: Qwen 원격 비전 OCR만 단독 실행해 fallback 성능이 섞이지 않게 측정한다."""
    started = time.perf_counter()
    try:
        result = generate_json(
            model=QWEN_OCR_MODEL,
            prompt=solve_ocr_prompt(),
            images=[image_bytes],
            temperature=0.0,
            top_p=0.1,
            max_tokens=512,
        )
        return _best_formula(result.get("all_formulas")), None, time.perf_counter() - started
    except Exception as exc:
        return "", f"{type(exc).__name__}: {exc}", time.perf_counter() - started


def _run_local(image_bytes: bytes, writing_events: list[dict[str, Any]]) -> tuple[str, str | None, float, str]:
    """필요 변수: 필기 이미지. 작동 원리: 운영과 같은 TexTeller 엔진을 실행하고 결과·경고·출처를 기록한다."""
    started = time.perf_counter()
    result = extract_math_with_texteller_grid(image_bytes, writing_events)
    warning = "; ".join(str(item) for item in result.get("warnings") or []) or None
    return _best_formula(result.get("all_formulas")), warning, time.perf_counter() - started, str(result.get("ocr_source") or "")


def run_benchmark(count: int) -> dict[str, Any]:
    """필요 변수: 표본 수. 작동 원리: 동일한 공개 필기 이미지에 원격과 로컬을 순차 적용하고 표본별·평균 지표를 만든다."""
    rows: list[dict[str, Any]] = []
    for sample in _fetch_samples(count):
        image_bytes = sample["image_bytes"]
        remote_text, remote_error, remote_seconds = _run_remote(image_bytes)
        local_text, local_error, local_seconds, local_source = _run_local(image_bytes, sample["writing_events"])
        rows.append(
            {
                "id": sample["id"],
                "truth": sample["truth"],
                "remote": {"text": remote_text, "error": remote_error, "seconds": round(remote_seconds, 3), **_score(sample["truth"], remote_text)},
                "local": {"text": local_text, "error": local_error, "source": local_source, "seconds": round(local_seconds, 3), **_score(sample["truth"], local_text)},
            }
        )
    def summary(key: str) -> dict[str, float]:
        values = [row[key] for row in rows]
        return {
            "exact_rate": round(sum(item["exact"] for item in values) / len(values), 4) if values else 0.0,
            "mean_similarity": round(sum(item["similarity"] for item in values) / len(values), 4) if values else 0.0,
            "mean_seconds": round(sum(item["seconds"] for item in values) / len(values), 3) if values else 0.0,
        }
    return {"dataset": DATASET_NAME, "sample_count": len(rows), "remote_model": QWEN_OCR_MODEL, "summary": {"remote": summary("remote"), "local": summary("local")}, "samples": rows}


def main() -> None:
    """필요 변수: CLI 표본 수·결과 경로. 작동 원리: 벤치마크 결과를 UTF-8 JSON으로만 기록해 재현과 후속 분석에 사용한다."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--count", type=int, default=20)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = run_benchmark(max(1, min(args.count, 50)))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(result["summary"], ensure_ascii=False))


if __name__ == "__main__":
    main()
