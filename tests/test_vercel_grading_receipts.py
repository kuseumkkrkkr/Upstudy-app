"""Vercel grading receipts bind to canonical content; legacy Lightning grading is retired."""
from __future__ import annotations

import asyncio
import importlib
import json
import os
import unittest
import uuid
from unittest.mock import patch

import jwt
from fastapi import HTTPException


class _Request:
    def __init__(self, payload):
        self.payload = payload

    async def json(self):
        return self.payload


class _DataApi:
    def __init__(self, row):
        self.row = row

    def request(self, *_args, **_kwargs):
        return [self.row]


class VercelGradingRouteTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module = importlib.import_module("api.index")

    def setUp(self):
        self.secret = "test-only-grade-receipt-secret-32bytes"
        self.env = patch.dict(os.environ, {
            "OMJ_JWT_SECRET": self.secret,
            "KILN_API_KEY": "test-kiln-key",
            "KILN_GRADING_MODEL": "qwen3-32b",
        })
        self.env.start()
        self.addCleanup(self.env.stop)

    def test_variant_grade_uses_vercel_question_and_issues_receipt(self):
        payload = self.module.VariantGradeRequest(
            quest_id="canonical-question-1",
            selected_index=1,
            flow_order=[0, 1],
            submission_id="solve:test:1",
        )
        question = {
            "header": {"quest_id": "canonical-question-1"},
            "data": {"quest_options": ["1", "2"], "choice_answer_index": 1},
            "solves": [{"flow": "첫 단계"}, {"flow": "둘째 단계"}],
        }
        with patch.object(self.module, "_find_marketplace_question", return_value=question):
            result = self.module.grade_variant_solve(payload, user_id="student-1")

        self.assertTrue(result["raw_correct"])
        self.assertTrue(result["answer_correct"])
        self.assertTrue(result["flow_correct"])
        self.assertEqual(result["step_correctness"], [
            {"step_id": 1, "flow_number": 1, "correct": True},
            {"step_id": 2, "flow_number": 2, "correct": True},
        ])
        claims = jwt.decode(result["grade_proof"], self.secret, algorithms=["HS256"])
        self.assertEqual(claims["sub"], "student-1")
        self.assertEqual(claims["quest_sha256"], self.module._grade_question_digest(question))
        self.assertEqual(claims["submission_id"], "solve:test:1")

    def test_variant_grade_rejects_wrong_flow_even_with_correct_answer(self):
        payload = self.module.VariantGradeRequest(
            quest_id="canonical-question-1",
            selected_index=1,
            flow_order=[1, 0],
            submission_id="solve:test:wrong-flow",
        )
        question = {
            "header": {"quest_id": "canonical-question-1"},
            "data": {"quest_options": ["1", "2"], "choice_answer_index": 1},
            "solves": [{"flow": "첫 단계"}, {"flow": "둘째 단계"}],
        }
        with patch.object(self.module, "_find_marketplace_question", return_value=question):
            result = self.module.grade_variant_solve(payload, user_id="student-1")
        self.assertFalse(result["raw_correct"])
        self.assertTrue(result["answer_correct"])
        self.assertFalse(result["flow_correct"])
        self.assertEqual(result["reason"], "incorrect_flow")

    def test_legacy_analysis_route_is_retired(self):
        with self.assertRaises(HTTPException) as error:
            asyncio.run(self.module.analyze_solve(_user_id="student-1"))
        self.assertEqual(error.exception.status_code, 410)

    def test_ocr_get_returns_only_server_persisted_grade_result(self):
        grade_result = {
            "quest_id": "canonical-question-1",
            "is_correct": True,
            "step_correctness": [{"step_id": 1, "correct": True}],
        }
        row = {
            "id": str(uuid.uuid4()),
            "status": "completed",
            "result": {"all_formulas": ["1+1=2"]},
            "grade_status": "completed",
            "grade_result": grade_result,
            "payload": {
                "quest_id": "canonical-question-1",
                "submission_id": "solve:test:3",
            },
        }
        with patch.object(self.module, "_data_api", return_value=_DataApi(row)):
            result = self.module.get_ocr_job(uuid.UUID(row["id"]), user_id="student-1")

        self.assertEqual(result["grade_status"], "completed")
        self.assertEqual(result["grade_result"], grade_result)
        self.assertNotIn("grade_proof", result["result"])

    def test_client_question_json_is_never_exposed_as_a_grade_receipt(self):
        row = {
            "id": str(uuid.uuid4()),
            "status": "completed",
            "result": {"is_correct": True, "step_correctness": []},
            "grade_status": "not_required",
            "grade_result": None,
            "payload": {
                "quest_id": "requested-question",
                "submission_id": "solve:test:4",
                "quest_json": {"header": {"quest_id": "client-controlled"}},
            },
        }
        with patch.object(self.module, "_data_api", return_value=_DataApi(row)):
            result = self.module.get_ocr_job(uuid.UUID(row["id"]), user_id="student-1")

        self.assertEqual(result["grade_status"], "not_required")
        self.assertIsNone(result["grade_result"])

    def test_ocr_job_without_grading_columns_defaults_to_not_required(self):
        row = {"id": str(uuid.uuid4()), "status": "completed", "result": {}}
        with patch.object(self.module, "_data_api", return_value=_DataApi(row)):
            result = self.module.get_ocr_job(uuid.UUID(row["id"]), user_id="student-1")
        self.assertEqual(result["grade_status"], "not_required")
        self.assertIsNone(result["grade_result"])

    def test_handwriting_grade_uses_canonical_question_and_kiln_text_only(self):
        question = {
            "header": {"quest_id": "canonical-question-1", "quest_model": {"models": ["algebra"]}},
            "data": {"quest_title": "x + 1 = 2", "quest_answer": "x = 1"},
            "solves": [{"answer_riddle": "양변에서 1을 뺀다."}],
        }
        captured = {}

        class _Response:
            def __enter__(self):
                return self

            def __exit__(self, *_args):
                return False

            def read(self, _limit):
                return json.dumps({
                    "choices": [{"message": {"content": json.dumps({
                        "status": [{"flow_number": 0, "status": "O"}],
                        "in_panic": [], "ai_opinion": "풀이가 타당합니다.",
                    }, ensure_ascii=False)}}],
                }).encode("utf-8")

        def _urlopen(request, timeout):
            captured["url"] = request.full_url
            captured["authorization"] = request.get_header("Authorization")
            captured["body"] = json.loads(request.data)
            captured["timeout"] = timeout
            return _Response()

        with (
            patch.object(self.module, "_find_vercel_question", return_value=question),
            patch.object(self.module.urllib.request, "urlopen", side_effect=_urlopen),
        ):
            result = self.module._request_solve_grade(
                user_id="student-1", quest_id="canonical-question-1",
                submission_id="solve:test:grade", quest=question,
                ocr_result={"all_formulas": ["x=1"], "purple_formulas": ["x=1"]},
            )

        self.assertEqual(captured["url"], "https://api.bricksum.com/v1/chat/completions")
        self.assertEqual(captured["authorization"], "Bearer test-kiln-key")
        self.assertNotIn("image", json.dumps(captured["body"]).lower())
        self.assertEqual(result["status"], [{"flow_number": 0, "status": "O"}])
        self.assertTrue(result["is_correct"])
        claims = jwt.decode(result["grade_proof"], self.secret, algorithms=["HS256"])
        self.assertEqual(claims["quest_sha256"], self.module._grade_question_digest(question))


if __name__ == "__main__":
    unittest.main()
