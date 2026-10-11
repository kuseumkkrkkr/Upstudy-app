import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import analysis_service


def test_pregrade_uses_only_texteller_for_handwriting(monkeypatch):
    """TexTeller가 유일한 필기 인식기이며 이미지를 다른 모델로 보내지 않는지 확인한다."""
    calls = []

    def fake_texteller(image, writing_events):
        calls.append((image, writing_events))
        return {
            "accepted": True,
            "all_formulas": [r"x^2=4"],
            "purple_formulas": [],
            "all_ocr": r"x^2=4",
            "user_answer": r"x^2=4",
            "ocr_source": "texteller_grid",
            "warnings": [],
        }

    monkeypatch.setattr(analysis_service, "extract_math_with_texteller_grid", fake_texteller)
    monkeypatch.setattr(
        analysis_service,
        "_generate_json_with_images",
        lambda **_: (_ for _ in ()).throw(AssertionError("OCR must not call a language model")),
    )

    result = analysis_service.analyze_pregrade(
        {"writing_events": [{"x": 1}]}, student_work_image_bytes=b"handwriting"
    )

    assert calls == [(b"handwriting", [{"x": 1}])]
    assert result["all_formulas"] == [r"x^2=4"]
    assert result["ocr_source"] == "texteller_grid"


def test_pregrade_does_not_fallback_when_texteller_rejects_handwriting(monkeypatch):
    """판독 실패는 빈 결과와 경고로 반환하며 다른 모델로 전환하지 않는다."""
    calls = []
    monkeypatch.setattr(
        analysis_service,
        "extract_math_with_texteller_grid",
        lambda *_: {
            "accepted": False,
            "all_formulas": [],
            "ocr_source": "texteller_invalid",
            "warnings": ["invalid handwriting transcription"],
        },
    )
    monkeypatch.setattr(
        analysis_service,
        "_generate_json_with_images",
        lambda **kwargs: (calls.append(kwargs) or ({}, None)),
    )

    result = analysis_service.analyze_pregrade({}, student_work_image_bytes=b"handwriting")

    assert calls == []
    assert result["all_formulas"] == []
    assert result["ocr_source"] == "texteller_invalid"
    assert "invalid handwriting transcription" in result["warnings"]


def test_pregrade_keeps_texteller_output_unchanged_without_secondary_guard(monkeypatch):
    expected = {
        "accepted": True,
        "all_formulas": [r"x+1"],
        "purple_formulas": [],
        "ocr_source": "texteller_grid",
        "warnings": [],
    }
    monkeypatch.setattr(analysis_service, "extract_math_with_texteller_grid", lambda *_: expected)
    monkeypatch.setattr(
        analysis_service,
        "_generate_json_with_images",
        lambda **_: (_ for _ in ()).throw(AssertionError("No secondary OCR or grading call")),
    )

    result = analysis_service.analyze_pregrade({}, student_work_image_bytes=b"handwriting")

    assert result["all_formulas"] == expected["all_formulas"]
    assert result["ocr_source"] == "texteller_grid"
    assert result["ocr_guard"] is None
