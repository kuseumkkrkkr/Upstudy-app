"""소셜 목록의 개별 사용자·행 오류가 전체 응답으로 전파되지 않는지 검증한다."""

import unittest
from unittest.mock import patch

import server


class SocialExceptionIsolationTests(unittest.TestCase):
    """필요 변수: 정상 소셜 데이터와 조회·검증 오류가 나는 단일 데이터.

    작동 원리: 오류 행만 제외하거나 안전한 사용자 ID로 대체되고 정상 행은
    계속 응답되는지 각 목록 경계에서 확인한다.
    """

    def test_friend_profiles_skip_invalid_user_row(self) -> None:
        """필요 변수: 정상 프로필과 필수 사용자명이 없는 프로필.

        작동 원리: Pydantic 검증 실패 행만 제외하고 정상 프로필을 보존한다.
        """
        profiles = server._friend_profiles_from_rows(
            [
                {"user_id": "healthy-user", "username": "정상 사용자"},
                {"user_id": "broken-user"},
            ],
            source="test",
        )

        self.assertEqual([item.user_id for item in profiles], ["healthy-user"])

    def test_friend_requests_skip_only_failed_user_lookup(self) -> None:
        """필요 변수: 상대 조회가 실패하는 요청과 정상 요청.

        작동 원리: 실패 요청만 제외하고 다른 친구 요청 알림은 반환한다.
        """
        requests = [
            {
                "id": "broken-request",
                "from_user_id": "broken-user",
                "to_user_id": "me",
                "status": "pending",
                "created_at": "2026-07-16T00:00:00Z",
            },
            {
                "id": "healthy-request",
                "from_user_id": "healthy-user",
                "to_user_id": "me",
                "status": "pending",
                "created_at": "2026-07-16T00:00:00Z",
            },
        ]

        def get_user(user_id: str):
            if user_id == "broken-user":
                raise RuntimeError("temporary lookup failure")
            return {"user_id": user_id, "username": "정상 사용자"}

        with patch.object(server, "get_social_user_by_id", side_effect=get_user):
            responses = server._friend_request_responses_safely(
                requests,
                me_user_id="me",
            )

        self.assertEqual([item.id for item in responses], ["healthy-request"])

    def test_conversations_keep_thread_when_peer_lookup_fails(self) -> None:
        """필요 변수: 프로필 조회가 실패하는 대화 상대와 정상 메시지 행.

        작동 원리: 상대 이름 대신 사용자 ID를 사용해 대화 목록 자체는 유지한다.
        """
        messages = [
            {
                "id": "message-1",
                "peer_id": "broken-peer",
                "text": "안녕하세요",
                "created_at": "2026-07-16T00:00:00Z",
                "is_mine": False,
            }
        ]

        def get_user(user_id: str):
            if user_id == "broken-peer":
                raise RuntimeError("temporary lookup failure")
            return {"user_id": user_id, "username": "나"}

        with (
            patch.object(server, "list_conversations", return_value=messages),
            patch.object(server, "get_social_user_by_id", side_effect=get_user),
        ):
            response = server.list_conversations_handler(user_id="me")

        self.assertEqual(len(response.messages), 1)
        self.assertEqual(response.messages[0].from_, "broken-peer")


if __name__ == "__main__":
    unittest.main()
