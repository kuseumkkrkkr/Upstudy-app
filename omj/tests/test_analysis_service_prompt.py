import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import analysis_service
from services.ai.prompts import solve_grading_prompt


def test_handwriting_grading_prompt_is_fair_and_tolerant():
    prompt = solve_grading_prompt()

    assert "관대하게 평가" in prompt
    assert "동치 표기" in prompt
    assert "정답 인정 쪽으로 판단" in prompt
    assert "낙관 편향을 낮춰서 엄격하게" not in prompt


def test_lightning_worker_uses_kiln_only_for_textual_grading(monkeypatch):
    providers = []

    def fake_generate_json(**kwargs):
        providers.append(kwargs["provider"])
        assert kwargs["images"] == []
        return {
            "status": [{"flow_number": 0, "status": "O"}],
            "in_panic": [],
            "ai_opinion": "표현 차이는 정답으로 인정했습니다.",
        }

    monkeypatch.setattr(analysis_service, "is_kiln_configured", lambda: True)
    monkeypatch.setattr(analysis_service, "generate_json", fake_generate_json)
    monkeypatch.setattr(
        analysis_service,
        "analyze_pregrade",
        lambda *_args, **_kwargs: {
            "all_formulas": ["x = 2"],
            "purple_formulas": [],
            "warnings": [],
            "ocr_source": "texteller_grid",
        },
    )

    result = analysis_service.analyze_submission(
        {
            "quest_id": "question-1",
            "quest_json": {
                "header": {"quest_id": "question-1"},
                "data": {"quest_title": "x를 구하라", "quest_answer": "2"},
                "solves": [{"flow": "양변을 정리한다."}],
            },
        },
        student_work_image_bytes=b"fixture-only",
    )

    assert providers == ["kiln"]
    assert result["is_correct"] is True


def test_analyze_submission_uses_reference_steps_when_quest_is_missing(monkeypatch):
    prompts = []

    def fake_generate_json_with_images(
        *, prompt, model, images, gen_config=None, provider=None
    ):
        prompts.append(prompt)
        if len(prompts) == 1:
            return {"all_formulas": ["x=1"], "purple_formulas": []}, None
        return {
            "status": [{"flow_number": 0, "status": "O"}],
            "in_panic": [],
            "ai_opinion": "ok",
        }, None

    monkeypatch.setattr(
        analysis_service,
        "_generate_json_with_images",
        fake_generate_json_with_images,
    )

    result = analysis_service.analyze_submission(
        {
            "problem": "x를 구하라.",
            "reference_steps": [
                {
                    "step_id": 1,
                    "answer_text": "x=1을 얻는다.",
                    "hash_tags": ["linear_equation"],
                }
            ],
            "debug": True,
        },
        student_work_image_bytes=b"fake",
        heatmap_image_bytes=b"fake",
    )

    assert result["is_correct"] is True
    assert result["status"] == [{"flow_number": 0, "status": "O"}]
    prompt = result["debug"]["prompt"]
    assert "QUEST_TITLE:\nx를 구하라." in prompt
    assert '"answer_riddle": "x=1을 얻는다."' in prompt
    assert '"hash_tag": ["linear_equation"]' in prompt


def test_grading_prompt_override_does_not_replace_ocr_prompt(monkeypatch):
    prompts = []

    def fake_generate_json_with_images(
        *, prompt, model, images, gen_config=None, provider=None
    ):
        prompts.append(prompt)
        if len(prompts) == 1:
            return {"all_formulas": ["x=1"], "purple_formulas": []}, None
        return {
            "status": [{"flow_number": 0, "status": "X"}],
            "in_panic": [],
            "ai_opinion": "bad",
        }, None

    monkeypatch.setattr(
        analysis_service,
        "_generate_json_with_images",
        fake_generate_json_with_images,
    )

    analysis_service.analyze_submission(
        {
            "analysis_prompt": "CUSTOM_GRADING_PROMPT",
            "reference_steps": [{"step_id": 1, "answer_text": "x=1"}],
        },
        student_work_image_bytes=b"fake",
        heatmap_image_bytes=b"fake",
    )

    assert "너는 수학 OCR 추출기다." in prompts[0]
    assert "CUSTOM_GRADING_PROMPT" not in prompts[0]
    assert "CUSTOM_GRADING_PROMPT" in prompts[1]
