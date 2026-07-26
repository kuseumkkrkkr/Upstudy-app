import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import analysis_service


def test_pregrade_uses_texteller_without_qwen_call(monkeypatch):
    """필요 변수: 성공한 TexTeller 응답 + 가드 ON 상태.
    작동 원리: 가드가 켜져도 Qwen이 보조 후보로 참여해 교차검증이 수행되는지 확인한다."""
    monkeypatch.setattr(
        analysis_service,
        "_run_qwen_ocr",
        lambda **_: {
            "all_formulas": [r"x^2=4"],
            "purple_formulas": [],
            "warnings": [],
            "ocr_source": "qwen_vision",
            "accepted": True,
        },
    )
    monkeypatch.setattr(
        analysis_service,
        "extract_math_with_texteller_grid",
        lambda *_: {
            "accepted": True,
            "all_formulas": [r"x^2=4"],
            "purple_formulas": [],
            "all_ocr": r"x^2=4",
            "user_answer": r"x^2=4",
            "ocr_source": "texteller_grid",
            "warnings": [],
        },
    )

    result = analysis_service.analyze_pregrade(
        {"writing_events": []}, student_work_image_bytes=b"student"
    )

    assert result["all_formulas"] == [r"x^2=4"]
    assert result["ocr_source"] == "texteller_grid+qwen_discrete_guard"
    assert result["ocr_guard"]["enabled"] is True


def test_pregrade_calls_qwen_once_after_texteller_rejection(monkeypatch):
    """필요 변수: TexTeller 실패와 Qwen 수식. 작동 원리: 실패 요청만 Qwen으로 한 번 전환하는지 검증한다."""
    calls = []
    monkeypatch.setattr(
        analysis_service,
        "extract_math_with_texteller_grid",
        lambda *_: {
            "accepted": False,
            "all_formulas": [],
            "ocr_source": "texteller_invalid",
            "warnings": ["invalid latex"],
        },
    )
    monkeypatch.setattr(
        analysis_service,
        "_generate_json_with_images",
        lambda **_: (calls.append(True) or ({"all_formulas": [r"x^2=4"]}, None)),
    )

    result = analysis_service.analyze_pregrade({}, student_work_image_bytes=b"student")

    assert calls == [True]
    assert result["all_formulas"] == [r"x^2=4"]
    assert result["ocr_source"] == "qwen_vision"
    assert "invalid latex" in result["warnings"]


def test_pregrade_uses_discrete_guard_when_enabled(monkeypatch):
    """필요 변수: Texteller 성공, Qwen 비교 후보.
    작동 원리: 텍스트 수식 후보를 이산확률로 재점수화해 최종 문자열을 결정한다."""
    monkeypatch.setattr(
        analysis_service,
        "DISCRETE_GUARD_ENABLED",
        True,
    )
    monkeypatch.setattr(
        analysis_service,
        "extract_math_with_texteller_grid",
        lambda *_: {
            "accepted": True,
            "all_formulas": [r"x+1"],
            "purple_formulas": [],
            "all_ocr": r"x+1",
            "user_answer": r"x+1",
            "ocr_source": "texteller_grid",
            "warnings": [],
        },
    )
    called = []
    monkeypatch.setattr(
        analysis_service,
        "_run_qwen_ocr",
        lambda **kwargs: (
            called.append(True)
            or {
                "all_formulas": [r"x-1"],
                "purple_formulas": [],
                "warnings": [],
                "ocr_source": "qwen_vision",
                "accepted": True,
            }
        ),
    )

    result = analysis_service.analyze_pregrade({}, student_work_image_bytes=b"student")

    assert called == [True]
    assert result["all_formulas"] == [r"x+1"]
    assert result["ocr_source"] == "texteller_grid+qwen_discrete_guard"


def test_pregrade_with_discrete_guard_disabled_skips_qwen(monkeypatch):
    """필요 변수: DISCRETE_GUARD_ENABLED 비활성.
    작동 원리: guard false일 때 기존 single-track 동작을 유지한다."""
    monkeypatch.setattr(
        analysis_service,
        "DISCRETE_GUARD_ENABLED",
        False,
    )
    monkeypatch.setattr(
        analysis_service,
        "_run_qwen_ocr",
        lambda **_: (_ for _ in ()).throw(AssertionError("Qwen should not be called")),
    )
    monkeypatch.setattr(
        analysis_service,
        "extract_math_with_texteller_grid",
        lambda *_: {
            "accepted": True,
            "all_formulas": [r"x^2=4"],
            "purple_formulas": [],
            "all_ocr": r"x^2=4",
            "user_answer": r"x^2=4",
            "ocr_source": "texteller_grid",
            "warnings": [],
        },
    )

    result = analysis_service.analyze_pregrade(
        {"writing_events": []}, student_work_image_bytes=b"student"
    )

    assert result["all_formulas"] == [r"x^2=4"]
    assert result["ocr_source"] == "texteller_grid"


def test_pregrade_returns_empty_when_both_tracks_fail(monkeypatch):
    """필요 변수: 두 엔진의 빈 결과. 작동 원리: 허위 수식을 만들지 않고 빈 OCR과 경고를 반환하는지 검증한다."""
    monkeypatch.setattr(
        analysis_service,
        "extract_math_with_texteller_grid",
        lambda *_: {
            "accepted": False,
            "all_formulas": [],
            "ocr_source": "texteller_unavailable",
            "warnings": ["model unavailable"],
        },
    )
    monkeypatch.setattr(analysis_service, "_generate_json_with_images", lambda **_: ({}, None))

    result = analysis_service.analyze_pregrade({}, student_work_image_bytes=b"student")

    assert result["all_formulas"] == []
    assert result["ocr_source"] == "qwen_vision_empty"
    assert "model unavailable" in result["warnings"]
    assert "Qwen OCR returned no formulas" in result["warnings"]
