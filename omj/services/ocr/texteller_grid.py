"""학생 stroke를 2차원 수식 셀로 묶어 TexTeller batch OCR을 수행한다."""

from __future__ import annotations

import io
import hashlib
import os
import re
import struct
import threading
import time
from collections import Counter, OrderedDict
from copy import deepcopy
from dataclasses import dataclass
from functools import lru_cache
from statistics import median
from typing import Any

from PIL import Image, ImageDraw


@dataclass(frozen=True, slots=True)
class StrokeBox:
    """stroke 또는 수식 셀의 이미지 좌표 경계를 보관한다."""

    left: float
    top: float
    right: float
    bottom: float

    @property
    def width(self) -> float:
        """필요 변수: 좌우 좌표. 작동 원리: 음수가 되지 않는 폭을 반환한다."""
        return max(0.0, self.right - self.left)

    @property
    def height(self) -> float:
        """필요 변수: 상하 좌표. 작동 원리: 음수가 되지 않는 높이를 반환한다."""
        return max(0.0, self.bottom - self.top)

    @property
    def center_y(self) -> float:
        """필요 변수: 상하 좌표. 작동 원리: 같은 수식 행 판별에 쓸 중심을 반환한다."""
        return (self.top + self.bottom) / 2

    def union(self, other: "StrokeBox") -> "StrokeBox":
        """필요 변수: 다른 경계. 작동 원리: 두 경계를 모두 포함하는 최소 상자를 만든다."""
        return StrokeBox(min(self.left, other.left), min(self.top, other.top), max(self.right, other.right), max(self.bottom, other.bottom))


@dataclass(frozen=True, slots=True)
class ProductStroke:
    """Flutter에서 전달한 한 번의 연속 필기 획이다."""

    stroke_id: int
    points: tuple[tuple[float, float], ...]
    width: float

    @property
    def box(self) -> StrokeBox:
        """필요 변수: 필기점·굵기. 작동 원리: 선 반지름까지 포함한 경계를 계산한다."""
        radius = self.width / 2
        return StrokeBox(
            min(point[0] for point in self.points) - radius,
            min(point[1] for point in self.points) - radius,
            max(point[0] for point in self.points) + radius,
            max(point[1] for point in self.points) + radius,
        )


@dataclass(frozen=True, slots=True)
class FormulaGrid:
    """TexTeller batch 한 항목에 대응하는 stroke 그룹이다."""

    index: int
    box: StrokeBox
    stroke_ids: tuple[int, ...]


class _DisjointSet:
    """stroke 그룹 병합을 경로 압축으로 관리한다."""

    def __init__(self, size: int) -> None:
        """필요 변수: stroke 수. 작동 원리: 각 stroke를 독립 그룹으로 초기화한다."""
        self.parent = list(range(size))

    def find(self, value: int) -> int:
        """필요 변수: stroke 인덱스. 작동 원리: 대표 노드를 찾으며 경로를 압축한다."""
        while self.parent[value] != value:
            self.parent[value] = self.parent[self.parent[value]]
            value = self.parent[value]
        return value

    def union(self, first: int, second: int) -> None:
        """필요 변수: 두 stroke 인덱스. 작동 원리: 서로 다른 대표 그룹을 하나로 연결한다."""
        root_first = self.find(first)
        root_second = self.find(second)
        if root_first != root_second:
            self.parent[root_second] = root_first


_TEXTELLER_SLOTS = threading.BoundedSemaphore(max(1, int(os.getenv("OCR_TEXTELLER_MAX_CONCURRENT", "1"))))
_QUEUE_TIMEOUT_SECONDS = max(0.0, float(os.getenv("OCR_TEXTELLER_QUEUE_TIMEOUT_SECONDS", "0.05")))
_RESULT_CACHE: OrderedDict[str, tuple[float, dict[str, Any]]] = OrderedDict()
_RESULT_CACHE_LOCK = threading.Lock()


def extract_math_with_texteller_grid(image_bytes: bytes, writing_events: Any = None) -> dict[str, Any]:
    """필요 변수: 학생 PNG·상대 stroke 목록. 작동 원리: 그리딩→셀 렌더링→TexTeller batch→구조 검증을 한 슬롯에서 수행한다."""
    if os.getenv("OCR_TEXTELLER_ENABLED", "true").strip().lower() in {"0", "false", "no"}:
        return _rejected("texteller_disabled", "TexTeller OCR is disabled")
    if not image_bytes:
        return _rejected("texteller_no_image", "TexTeller OCR received no image")
    strokes = parse_writing_events(writing_events)
    if not strokes:
        # raster 단독 입력은 그럴듯한 오인식을 검출하기 어려우므로 Qwen 경로에 맡긴다.
        return _rejected("texteller_no_strokes", "TexTeller grid OCR requires valid writing events")
    cache_key = _result_cache_key(image_bytes, strokes)
    cached = _get_cached_result(cache_key)
    if cached is not None:
        cached["ocr_source"] = "texteller_grid_cache"
        cached["cache_hit"] = True
        return cached
    if not _TEXTELLER_SLOTS.acquire(timeout=_QUEUE_TIMEOUT_SECONDS):
        return _rejected("texteller_capacity_exhausted", "TexTeller OCR capacity exhausted")
    try:
        source_image = Image.open(io.BytesIO(image_bytes))
        if source_image.width * source_image.height > int(os.getenv("OCR_TEXTELLER_MAX_IMAGE_PIXELS", "12000000")):
            return _rejected("texteller_image_too_large", "TexTeller OCR image pixel limit exceeded")
        image = source_image.convert("RGB")
        grids = build_formula_grids(strokes)
        warnings: list[str] = []
        maximum_grids = max(1, int(os.getenv("OCR_TEXTELLER_MAX_GRIDS", "8")))
        if not grids or len(grids) > maximum_grids:
            grids = [FormulaGrid(0, StrokeBox(0, 0, image.width, image.height), tuple(stroke.stroke_id for stroke in strokes))]
            if strokes:
                warnings.append("formula grid count exceeded limit; full image fallback used")
        cell_images = render_grid_images(image, strokes, grids)
        runtime = _load_texteller()
        formulas: list[str] = []
        batch_size = max(1, min(maximum_grids, int(os.getenv("OCR_TEXTELLER_BATCH_SIZE", "4"))))
        for start in range(0, len(cell_images), batch_size):
            formulas.extend(runtime.recognize_batch(cell_images[start : start + batch_size]))
        formulas = [normalize_prediction(value) for value in formulas]
        accepted = bool(formulas) and all(is_valid_formula(value) for value in formulas)
        if not accepted:
            warnings.append("TexTeller returned an empty or structurally invalid formula")
        result = {
            "all_formulas": formulas if accepted else [],
            "purple_formulas": [],
            "all_ocr": "\n".join(formulas),
            "user_answer": "\n".join(formulas),
            "ocr_source": "texteller_grid" if accepted else "texteller_invalid",
            "accepted": accepted,
            "grids": [
                {
                    "index": grid.index,
                    "box": [grid.box.left, grid.box.top, grid.box.right, grid.box.bottom],
                    "stroke_ids": list(grid.stroke_ids),
                    "latex": formulas[index] if index < len(formulas) else "",
                }
                for index, grid in enumerate(grids)
            ],
            "warnings": warnings,
            "cache_hit": False,
        }
        if accepted:
            _put_cached_result(cache_key, result)
        return result
    except Exception as error:
        return _rejected("texteller_unavailable", f"TexTeller OCR failed: {type(error).__name__}: {error}")
    finally:
        _TEXTELLER_SLOTS.release()


def parse_writing_events(value: Any) -> list[ProductStroke]:
    """필요 변수: API writing_events. 작동 원리: 유효 숫자 좌표가 두 개 이상인 stroke만 제한적으로 변환한다."""
    if not isinstance(value, list):
        return []
    maximum_strokes = max(1, int(os.getenv("OCR_TEXTELLER_MAX_STROKES", "2000")))
    maximum_points = max(2, int(os.getenv("OCR_TEXTELLER_MAX_POINTS_PER_STROKE", "4096")))
    maximum_total_points = max(2, int(os.getenv("OCR_TEXTELLER_MAX_TOTAL_POINTS", "200000")))
    total_points = 0
    strokes: list[ProductStroke] = []
    for fallback_id, item in enumerate(value[:maximum_strokes]):
        if not isinstance(item, dict) or not isinstance(item.get("points"), list):
            continue
        points: list[tuple[float, float]] = []
        for point in item["points"][:maximum_points]:
            if not isinstance(point, dict):
                continue
            try:
                x = float(point["x"])
                y = float(point["y"])
            except (KeyError, TypeError, ValueError):
                continue
            if abs(x) <= 20000 and abs(y) <= 20000:
                points.append((x, y))
        if len(points) < 2:
            continue
        if total_points + len(points) > maximum_total_points:
            break
        try:
            stroke_id = int(item.get("stroke_id", fallback_id))
            width = min(32.0, max(0.5, float(item.get("width", 3.0))))
        except (TypeError, ValueError):
            continue
        strokes.append(ProductStroke(stroke_id, tuple(points), width))
        total_points += len(points)
    return strokes


def build_formula_grids(strokes: list[ProductStroke]) -> list[FormulaGrid]:
    """필요 변수: 정규화 stroke. 작동 원리: 같은 행·첨자·분수선·행렬 괄호 관계로 2차원 수식 셀을 만든다."""
    if not strokes:
        return []
    minimum_baseline = float(os.getenv("OCR_GRID_BASELINE_TOLERANCE", "24"))
    minimum_expression_gap = float(os.getenv("OCR_GRID_EXPRESSION_GAP", "72"))
    minimum_structure_gap = float(os.getenv("OCR_GRID_STRUCTURE_GAP", "52"))
    padding = float(os.getenv("OCR_GRID_PADDING", "12"))
    boxes = [stroke.box for stroke in strokes]
    # 기기 해상도에 따라 같은 글자도 수십~수백 px이므로 대표 획 높이를 기준으로 임계값을 확장한다.
    typical_height = median(box.height for box in boxes)
    baseline = max(minimum_baseline, typical_height * 0.50)
    expression_gap = max(minimum_expression_gap, typical_height * 1.25)
    structure_gap = max(minimum_structure_gap, typical_height * 0.80)
    attachment_gap = max(18.0, typical_height * 0.18)
    groups = _DisjointSet(len(strokes))
    for first in range(len(strokes)):
        for second in range(first + 1, len(strokes)):
            horizontal_gap = _axis_gap(boxes[first].left, boxes[first].right, boxes[second].left, boxes[second].right)
            vertical_gap = _axis_gap(boxes[first].top, boxes[first].bottom, boxes[second].top, boxes[second].bottom)
            center_gap = abs(boxes[first].center_y - boxes[second].center_y)
            same_line = center_gap <= baseline and horizontal_gap <= expression_gap
            attachment = horizontal_gap <= attachment_gap and vertical_gap <= attachment_gap and center_gap <= max(boxes[first].height, boxes[second].height) * 1.35 + attachment_gap
            if same_line or attachment:
                groups.union(first, second)
    for bridge_index, bridge in enumerate(boxes):
        horizontal_bridge = bridge.width >= 30 and bridge.width >= bridge.height * 4
        vertical_bridge = bridge.height >= 45 and bridge.height >= bridge.width * 2.5
        if not horizontal_bridge and not vertical_bridge:
            continue
        for other_index, other in enumerate(boxes):
            if other_index == bridge_index:
                continue
            if horizontal_bridge:
                overlap = _overlap(bridge.left, bridge.right, other.left, other.right)
                if overlap / max(1.0, min(bridge.width, other.width)) >= 0.20 and _axis_gap(bridge.top, bridge.bottom, other.top, other.bottom) <= structure_gap:
                    groups.union(bridge_index, other_index)
            elif bridge.top - 18 <= other.center_y <= bridge.bottom + 18 and _axis_gap(bridge.left, bridge.right, other.left, other.right) <= structure_gap:
                groups.union(bridge_index, other_index)
    members: dict[int, list[int]] = {}
    for index in range(len(strokes)):
        members.setdefault(groups.find(index), []).append(index)
    raw: list[tuple[StrokeBox, tuple[int, ...]]] = []
    for indices in members.values():
        box = boxes[indices[0]]
        for index in indices[1:]:
            box = box.union(boxes[index])
        box = StrokeBox(box.left - padding, box.top - padding, box.right + padding, box.bottom + padding)
        raw.append((box, tuple(sorted(strokes[index].stroke_id for index in indices))))
    raw.sort(key=lambda item: (round(item[0].top / max(1.0, baseline)), item[0].left))
    return [FormulaGrid(index, box, ids) for index, (box, ids) in enumerate(raw)]


def render_grid_images(image: Image.Image, strokes: list[ProductStroke], grids: list[FormulaGrid]) -> list[Image.Image]:
    """필요 변수: 원본 이미지·stroke·그리드. 작동 원리: stroke가 있으면 셀 소속 획만 재렌더링하고 없으면 원본을 자른다."""
    if not strokes:
        return [_crop(image, grid.box) for grid in grids]
    stroke_by_id = {stroke.stroke_id: stroke for stroke in strokes}
    results: list[Image.Image] = []
    for grid in grids:
        canvas = Image.new("RGB", image.size, "white")
        draw = ImageDraw.Draw(canvas)
        for stroke_id in grid.stroke_ids:
            stroke = stroke_by_id.get(stroke_id)
            if stroke is None:
                continue
            draw.line(stroke.points, fill="black", width=max(1, round(stroke.width)), joint="curve")
        results.append(_crop(canvas, grid.box))
    return results


def is_valid_formula(value: str) -> bool:
    """필요 변수: 인식 LaTeX. 작동 원리: 빈 값·중괄호 불균형·반복 폭주를 Qwen 전환 신호로 판별한다."""
    text = normalize_prediction(value)
    if not text or len(text) > 1000 or text.count("{") != text.count("}"):
        return False
    return re.search(r"(.)\1{15,}", text) is None


class _TexTellerRuntime:
    """고정 TexTeller 모델을 요청 간 재사용하는 batch 런타임이다."""

    MODEL_ID = "OleehyO/TexTeller"
    MODEL_REVISION = "7b96df06b9d81cdb129c3bef68b7250bc3e2b0ea"
    IMAGE_SIZE = 448
    IMAGE_MEAN = 0.9545467
    IMAGE_STD = 0.15394445

    def __init__(self) -> None:
        """필요 변수: CUDA·토큰 환경 설정. 작동 원리: 검증 revision을 선택 장치에 한 번 적재한다."""
        import torch
        from transformers import RobertaTokenizerFast, VisionEncoderDecoderModel

        self.torch = torch
        self.device = torch.device("cuda" if torch.cuda.is_available() and os.getenv("OCR_USE_CUDA", "1") != "0" else "cpu")
        self.max_tokens = max(16, min(384, int(os.getenv("OCR_TEXTELLER_MAX_TOKENS", "192"))))
        self.tokenizer = RobertaTokenizerFast.from_pretrained(self.MODEL_ID, revision=self.MODEL_REVISION)
        self.model = VisionEncoderDecoderModel.from_pretrained(self.MODEL_ID, revision=self.MODEL_REVISION).to(self.device).eval()

    def recognize_batch(self, images: list[Image.Image]) -> list[str]:
        """필요 변수: 셀 이미지 batch. 작동 원리: 한 생성 호출로 셀 순서의 LaTeX를 반환한다."""
        from transformers import GenerationConfig

        values = self.torch.stack([self._tensor(image) for image in images], dim=0).to(self.device)
        config = GenerationConfig(
            max_new_tokens=self.max_tokens,
            num_beams=1,
            do_sample=False,
            pad_token_id=self.tokenizer.pad_token_id,
            eos_token_id=self.tokenizer.eos_token_id,
            bos_token_id=self.tokenizer.bos_token_id,
            no_repeat_ngram_size=0,
        )
        with self.torch.inference_mode():
            predictions = self.model.generate(pixel_values=values, generation_config=config)
        return [normalize_prediction(value) for value in self.tokenizer.batch_decode(predictions, skip_special_tokens=True)]

    def _tensor(self, image: Image.Image):
        """필요 변수: 셀 이미지. 작동 원리: 잉크 여백 제거 후 448 정규화·패딩 tensor를 만든다."""
        import numpy as np

        pixels = np.array(image.convert("RGB"), copy=True)
        corners = [tuple(pixels[0, 0]), tuple(pixels[0, -1]), tuple(pixels[-1, 0]), tuple(pixels[-1, -1])]
        background = np.array(Counter(corners).most_common(1)[0][0], dtype=np.int16)
        locations = np.argwhere(np.max(np.abs(pixels.astype(np.int16) - background), axis=2) > 15)
        if len(locations):
            top, left = locations.min(axis=0)
            bottom, right = locations.max(axis=0) + 1
            pixels = pixels[top:bottom, left:right]
        gray = Image.fromarray(pixels).convert("L")
        scale = min(self.IMAGE_SIZE / max(1, gray.width), self.IMAGE_SIZE / max(1, gray.height))
        width = max(1, min(self.IMAGE_SIZE, round(gray.width * scale)))
        height = max(1, min(self.IMAGE_SIZE, round(gray.height * scale)))
        resized = gray.resize((width, height), Image.Resampling.BICUBIC)
        normalized = (np.asarray(resized, dtype=np.float32) / 255.0 - self.IMAGE_MEAN) / self.IMAGE_STD
        padded = np.zeros((self.IMAGE_SIZE, self.IMAGE_SIZE), dtype=np.float32)
        padded[:height, :width] = normalized
        return self.torch.from_numpy(padded).unsqueeze(0)


@lru_cache(maxsize=1)
def _load_texteller() -> _TexTellerRuntime:
    """필요 변수: 없음. 작동 원리: 프로세스당 TexTeller 런타임을 정확히 한 번 생성한다."""
    return _TexTellerRuntime()


def warm_texteller_runtime() -> str | None:
    """필요 변수: TexTeller 설치·모델 캐시. 작동 원리: 서버 준비 단계에서 모델을 적재하고 실패는 Qwen 전환용 경고로 반환한다."""
    if os.getenv("OCR_TEXTELLER_ENABLED", "true").strip().lower() in {"0", "false", "no"}:
        return None
    try:
        _load_texteller()
        return None
    except Exception as error:
        return f"TexTeller warmup failed: {type(error).__name__}: {error}"


def normalize_prediction(value: str) -> str:
    """필요 변수: 모델 원시 출력. 작동 원리: 표시 구분자와 연속 공백만 제거해 수식 의미를 보존한다."""
    text = (value or "").strip()
    if text.startswith(r"\[") and text.endswith(r"\]"):
        text = text[2:-2].strip()
    return " ".join(text.split())


def _result_cache_key(image_bytes: bytes, strokes: list[ProductStroke]) -> str:
    """필요 변수: 렌더링 PNG와 정규화 획. 작동 원리: 사용자 원문을 보관하지 않는 고정 길이 재채점 캐시 키를 만든다."""
    digest = hashlib.blake2b(digest_size=20)
    digest.update(image_bytes)
    for stroke in strokes:
        digest.update(str(stroke.stroke_id).encode("ascii", errors="ignore"))
        digest.update(struct.pack("!d", stroke.width))
        for x, y in stroke.points:
            digest.update(struct.pack("!dd", x, y))
    return digest.hexdigest()


def _get_cached_result(key: str) -> dict[str, Any] | None:
    """필요 변수: OCR 입력 해시. 작동 원리: TTL 안의 결과만 LRU 순서를 갱신해 복사 반환한다."""
    ttl = max(0.0, float(os.getenv("OCR_TEXTELLER_CACHE_TTL_SECONDS", "300")))
    if ttl <= 0:
        return None
    now = time.monotonic()
    with _RESULT_CACHE_LOCK:
        entry = _RESULT_CACHE.get(key)
        if entry is None:
            return None
        created_at, result = entry
        if now - created_at > ttl:
            _RESULT_CACHE.pop(key, None)
            return None
        _RESULT_CACHE.move_to_end(key)
        return deepcopy(result)


def _put_cached_result(key: str, result: dict[str, Any]) -> None:
    """필요 변수: OCR 입력 해시·성공 결과. 작동 원리: 작은 결과만 제한된 LRU에 저장해 이미지 메모리 누적을 막는다."""
    maximum = max(0, int(os.getenv("OCR_TEXTELLER_CACHE_MAX_ENTRIES", "256")))
    if maximum <= 0:
        return
    with _RESULT_CACHE_LOCK:
        _RESULT_CACHE[key] = (time.monotonic(), deepcopy(result))
        _RESULT_CACHE.move_to_end(key)
        while len(_RESULT_CACHE) > maximum:
            _RESULT_CACHE.popitem(last=False)


def _crop(image: Image.Image, box: StrokeBox) -> Image.Image:
    """필요 변수: 원본 이미지·셀 경계. 작동 원리: 경계를 이미지 안 정수 좌표로 제한해 crop한다."""
    left = max(0, min(image.width - 1, int(box.left)))
    top = max(0, min(image.height - 1, int(box.top)))
    right = max(left + 1, min(image.width, int(box.right + 0.999)))
    bottom = max(top + 1, min(image.height, int(box.bottom + 0.999)))
    return image.crop((left, top, right, bottom))


def _axis_gap(first_start: float, first_end: float, second_start: float, second_end: float) -> float:
    """필요 변수: 두 축 구간. 작동 원리: 겹치면 0, 아니면 가장 가까운 끝점 거리를 반환한다."""
    return max(0.0, max(first_start, second_start) - min(first_end, second_end))


def _overlap(first_start: float, first_end: float, second_start: float, second_end: float) -> float:
    """필요 변수: 두 축 구간. 작동 원리: 두 구간 교집합 길이를 반환한다."""
    return max(0.0, min(first_end, second_end) - max(first_start, second_start))


def _rejected(source: str, warning: str) -> dict[str, Any]:
    """필요 변수: 실패 출처·경고. 작동 원리: Qwen fallback이 해석할 공통 빈 결과를 만든다."""
    return {"all_formulas": [], "purple_formulas": [], "accepted": False, "ocr_source": source, "warnings": [warning]}
