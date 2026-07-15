"""PostgreSQL 레이팅 계산 계약 단위 테스트."""
from __future__ import annotations

import unittest
from contextlib import contextmanager
from copy import deepcopy
from unittest.mock import patch

import rating_service


class _FakeRatingStore:
    """DB 연결 없이 서버 원본 태그·가중치·중복방지 계산을 검증하는 최소 저장소다."""

    def __init__(self) -> None:
        self.user = {
            "rating": 1200.0,
            "ovr": 1200.0,
            "ovr_prev": 1200.0,
            "lose_streak": 0,
            "last_attempt_at": None,
            "recent_results": [],
            "recent_index": 0,
            "recent_count": 0,
            "recent_sum": 0,
        }
        self.tags = {}
        self.responses = {}

    @contextmanager
    def transaction(self):
        """필요 변수: 없음. 작동 원리: 실제 트랜잭션과 같은 문맥 관리자 형태로 더미 커서를 제공한다."""
        yield object()

    def claim_submission(self, cur, *, user_id, submission_id, quest_id):
        """필요 변수: 제출 키. 작동 원리: 처음이면 선점하고 이후에는 저장된 결과를 반환한다."""
        del cur, user_id, quest_id
        if submission_id in self.responses:
            return deepcopy(self.responses[submission_id])
        return None

    def get_or_create_user(self, cur, user_id, *, for_update):
        """필요 변수: 사용자 ID. 작동 원리: 메모리 사용자 상태 복사본을 반환한다."""
        del cur, user_id, for_update
        return deepcopy(self.user)

    def get_tag_stats(self, cur, user_id, tags):
        """필요 변수: 서버가 결정한 태그. 작동 원리: 해당 태그의 기존 상태만 반환한다."""
        del cur, user_id
        return {tag: deepcopy(self.tags[tag]) for tag in tags if tag in self.tags}

    def upsert_tag_stats(self, cur, rows):
        """필요 변수: 태그 갱신 목록. 작동 원리: 메모리 상태에 최신 값을 덮어쓴다."""
        del cur
        for row in rows:
            self.tags[row["tag"]] = deepcopy(row)

    def compute_ovr(self, cur, user_id, fallback):
        """필요 변수: 태그 상태. 작동 원리: 테스트에서는 단순 평균으로 응답 형식만 유지한다."""
        del cur, user_id
        if not self.tags:
            return fallback
        return sum(row["rating"] for row in self.tags.values()) / len(self.tags)

    def update_user(self, cur, values):
        """필요 변수: 계산 결과. 작동 원리: 메모리 사용자 상태를 갱신한다."""
        del cur
        self.user.update(deepcopy(values))

    def save_submission_response(self, cur, *, user_id, submission_id, response):
        """필요 변수: 제출 키·응답. 작동 원리: 재전송 검증을 위해 결과 스냅샷을 보관한다."""
        del cur, user_id
        self.responses[submission_id] = deepcopy(response)


def _quest(tags):
    """필요 변수: 문제 원본 태그. 작동 원리: 모든 태그가 같은 두 풀이 단계에 걸린 표준 문제를 만든다."""
    return {
        "header": {"quest_id": "q-1"},
        "info": {
            "hash_tag": tags,
            "difficulty_score": 40,
            "main_huddle": 1,
            "flow_rate": 1,
        },
        "solves": [
            {"enter_huddle": 1, "hash_tag": tags},
            {"enter_huddle": 1, "hash_tag": tags},
        ],
    }


class RatingServiceContractTests(unittest.TestCase):
    def _submit(self, tags, submission_id="submission-1"):
        """필요 변수: 서버 문제 태그·제출 키. 작동 원리: 가짜 PostgreSQL 저장소에 단일 정답을 반영한다."""
        store = _FakeRatingStore()
        with patch.object(rating_service, "postgres_rating_store", store):
            result = rating_service.apply_rating_update(
                user_id="user-1",
                quest=_quest(tags),
                is_correct=True,
                step_outcomes=[],
                submission_ref=submission_id,
            )
        return store, result

    def test_multi_tag_problem_does_not_amplify_user_delta(self):
        """필요 변수: 동일 난도 1태그·2태그 문제. 작동 원리: 태그 흐름 합이 1이라 사용자 변화량이 같아야 한다."""
        _, one = self._submit(["대수"])
        _, two = self._submit(["대수", "함수"])
        self.assertAlmostEqual(one.rating, two.rating, places=9)

    def test_only_canonical_quest_tags_are_updated(self):
        """필요 변수: 서버 문제 원본 태그. 작동 원리: 서비스 입력에 클라이언트 태그 인자가 없고 원본 태그만 저장된다."""
        store, _ = self._submit(["#대수", "함수"])
        self.assertEqual({"대수", "함수"}, set(store.tags))

    def test_duplicate_submission_returns_exact_saved_response(self):
        """필요 변수: 같은 제출 키의 재전송. 작동 원리: 두 번째 호출은 계산하지 않고 첫 응답을 그대로 반환한다."""
        store = _FakeRatingStore()
        with patch.object(rating_service, "postgres_rating_store", store):
            first = rating_service.apply_rating_update(
                user_id="user-1", quest=_quest(["대수"]), is_correct=True,
                step_outcomes=[], submission_ref="same-key",
            )
            second = rating_service.apply_rating_update(
                user_id="user-1", quest=_quest(["대수"]), is_correct=False,
                step_outcomes=[], submission_ref="same-key",
            )
        self.assertEqual(first, second)
        self.assertEqual(1, store.user["recent_count"])

    def test_k_factor_is_not_changed_by_lose_streak(self):
        """필요 변수: 서로 다른 연패 수. 작동 원리: 제출 순서 편향 제거 후 K가 모두 같아야 한다."""
        self.assertEqual(rating_service.compute_k_factor(0), rating_service.compute_k_factor(20))

    def test_tag_delta_uses_its_own_rating_expectation(self):
        """필요 변수: 전체보다 낮은 태그 레이팅. 작동 원리: 정답 시 태그가 전체보다 더 빠르게 회복해야 한다."""
        store = _FakeRatingStore()
        store.tags["대수"] = {
            "tag": "대수", "attempts": 10, "rating": 800.0, "rating_prev": 800.0,
        }
        with patch.object(rating_service, "postgres_rating_store", store):
            result = rating_service.apply_rating_update(
                user_id="user-1", quest=_quest(["대수"]), is_correct=True,
                step_outcomes=[], submission_ref="tag-recovery",
            )
        tag_gain = store.tags["대수"]["rating"] - 800.0
        global_gain = result.rating - 1200.0
        self.assertGreater(tag_gain, global_gain)


if __name__ == "__main__":
    unittest.main()
