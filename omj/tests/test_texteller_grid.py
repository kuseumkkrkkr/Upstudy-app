import io
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from services.ocr import texteller_grid


def _png_bytes() -> bytes:
    """필요 변수: 없음. 작동 원리: 외부 파일 없이 엔진 테스트용 흰 PNG를 메모리에 생성한다."""
    output = io.BytesIO()
    Image.new("RGB", (120, 100), "white").save(output, format="PNG")
    return output.getvalue()


def _stroke(stroke_id: int, points: list[tuple[float, float]], width: float = 3) -> dict:
    """필요 변수: 획 ID·좌표·굵기. 작동 원리: Flutter writing_events와 같은 테스트 payload를 만든다."""
    return {
        "stroke_id": stroke_id,
        "width": width,
        "points": [{"x": x, "y": y, "pressure": 1.0} for x, y in points],
    }


def test_fraction_strokes_are_grouped_into_one_formula_grid():
    """필요 변수: 분자·분수선·분모 획. 작동 원리: 가로 구조선이 위아래 획을 한 수식 셀로 묶는지 검증한다."""
    strokes = texteller_grid.parse_writing_events(
        [
            _stroke(0, [(24, 20), (36, 20)]),
            _stroke(1, [(10, 42), (60, 42)]),
            _stroke(2, [(24, 64), (36, 64)]),
        ]
    )

    grids = texteller_grid.build_formula_grids(strokes)

    assert len(grids) == 1
    assert grids[0].stroke_ids == (0, 1, 2)


def test_large_device_coordinates_keep_one_baseline_formula():
    """필요 변수: 큰 화면 좌표의 같은 행 획. 작동 원리: 고정 px 간격 때문에 한 수식이 여러 셀로 쪼개지지 않는지 검증한다."""
    strokes = texteller_grid.parse_writing_events(
        [
            _stroke(0, [(20, 20), (100, 180)]),
            _stroke(1, [(190, 30), (260, 170)]),
            _stroke(2, [(350, 35), (430, 175)]),
        ]
    )

    grids = texteller_grid.build_formula_grids(strokes)

    assert len(grids) == 1
    assert grids[0].stroke_ids == (0, 1, 2)


def test_raster_only_request_is_sent_to_qwen_without_loading_texteller(monkeypatch):
    """필요 변수: 획이 없는 PNG. 작동 원리: 검증하기 어려운 raster 단독 추론을 채택하지 않고 Qwen 전환 신호를 내는지 검증한다."""
    monkeypatch.setattr(
        texteller_grid,
        "_load_texteller",
        lambda: (_ for _ in ()).throw(AssertionError("model must not load")),
    )

    result = texteller_grid.extract_math_with_texteller_grid(_png_bytes())

    assert result["accepted"] is False
    assert result["ocr_source"] == "texteller_no_strokes"


def test_texteller_batch_result_is_normalized_and_accepted(monkeypatch):
    """필요 변수: 가짜 TexTeller 출력과 획 payload. 작동 원리: 그리딩 결과가 정규화된 LaTeX 응답으로 이어지는지 검증한다."""
    class FakeRuntime:
        def recognize_batch(self, images):
            assert len(images) == 1
            return [r"\[ x+1=2 \]"]

    monkeypatch.setattr(texteller_grid, "_load_texteller", lambda: FakeRuntime())
    events = [_stroke(0, [(10, 30), (25, 30)]), _stroke(1, [(30, 30), (45, 30)])]

    result = texteller_grid.extract_math_with_texteller_grid(_png_bytes(), events)

    assert result["accepted"] is True
    assert result["ocr_source"] == "texteller_grid"
    assert result["all_formulas"] == ["x+1=2"]
    assert result["grids"][0]["stroke_ids"] == [0, 1]


def test_identical_writing_rerun_uses_result_cache(monkeypatch):
    """필요 변수: 동일 PNG·획의 연속 요청. 작동 원리: 두 번째 요청이 모델을 다시 실행하지 않고 짧은 LRU 결과를 쓰는지 검증한다."""
    calls = []

    class FakeRuntime:
        def recognize_batch(self, _images):
            calls.append(True)
            return ["x=1"]

    texteller_grid._RESULT_CACHE.clear()
    monkeypatch.setattr(texteller_grid, "_load_texteller", lambda: FakeRuntime())
    events = [_stroke(77, [(13, 27), (31, 27)])]
    image = _png_bytes()

    first = texteller_grid.extract_math_with_texteller_grid(image, events)
    second = texteller_grid.extract_math_with_texteller_grid(image, events)

    assert calls == [True]
    assert first["cache_hit"] is False
    assert second["cache_hit"] is True
    assert second["ocr_source"] == "texteller_grid_cache"


def test_invalid_texteller_output_requests_qwen_fallback(monkeypatch):
    """필요 변수: 중괄호가 깨진 모델 출력. 작동 원리: 잘못된 LaTeX를 채점 근거로 채택하지 않는지 검증한다."""
    class FakeRuntime:
        def recognize_batch(self, _images):
            return [r"\frac{1{2}"]

    monkeypatch.setattr(texteller_grid, "_load_texteller", lambda: FakeRuntime())

    result = texteller_grid.extract_math_with_texteller_grid(
        _png_bytes(), [_stroke(0, [(10, 20), (30, 20)])]
    )

    assert result["accepted"] is False
    assert result["all_formulas"] == []
    assert result["ocr_source"] == "texteller_invalid"
