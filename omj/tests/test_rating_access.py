"""친구 관계 기반 사용자 레이팅 조회 권한을 검증한다."""

import unittest
from types import SimpleNamespace
from unittest.mock import patch

from fastapi import HTTPException

import server


class RatingAccessTests(unittest.TestCase):
    """필요 변수: 요청자, 조회 대상, 친구 관계와 레이팅 결과.

    작동 원리: 친구의 요약 레이팅은 허용하고, 관계없는 사용자의 조회는
    403으로 차단하는 API 권한 경계를 직접 검증한다.
    """

    def test_friend_can_read_target_rating(self) -> None:
        """필요 변수: 친구 관계인 요청자와 대상 사용자 ID.

        작동 원리: 권한 확인 뒤 요청자 레이팅이 아닌 대상 사용자의 레이팅을
        반환하는지 확인한다.
        """
        target_rating = SimpleNamespace(
            rating=1420.0,
            ovr=1400.0,
            ovr_delta=12.0,
            recent_accuracy=0.8,
            lose_streak=0,
        )
        with (
            patch.object(server, "are_friends", return_value=True),
            patch.object(server, "fetch_user_rating", return_value=target_rating) as fetch,
        ):
            response = server.get_user_rating("friend-id", "requester-id")

        fetch.assert_called_once_with("friend-id")
        self.assertEqual(response.rating, 1420.0)
        self.assertEqual(response.ovr, 1400.0)

    def test_non_friend_cannot_read_target_rating(self) -> None:
        """필요 변수: 친구 관계가 아닌 요청자와 대상 사용자 ID.

        작동 원리: 대상 사용자의 레이팅 저장소를 조회하기 전에 403으로
        차단하여 비친구의 정보 노출을 막는다.
        """
        with (
            patch.object(server, "are_friends", return_value=False),
            patch.object(server, "fetch_user_rating") as fetch,
        ):
            with self.assertRaises(HTTPException) as raised:
                server.get_user_rating("stranger-id", "requester-id")

        self.assertEqual(raised.exception.status_code, 403)
        fetch.assert_not_called()

    def test_friend_rankings_skip_only_failed_user_rating(self) -> None:
        """필요 변수: 정상 사용자 둘과 레이팅 조회가 실패하는 친구 한 명.

        작동 원리: 실패한 친구만 결과에서 제외하고 정상 사용자는 OVR 순서로
        계속 반환하는지 검증한다.
        """
        ratings = {
            "requester-id": SimpleNamespace(ovr=1200.0),
            "healthy-friend": SimpleNamespace(ovr=1500.0),
        }

        def fetch_rating(user_id: str):
            if user_id == "broken-friend":
                raise ValueError("invalid rating row")
            return ratings[user_id]

        with (
            patch.object(
                server,
                "get_social_user_by_id",
                return_value={"user_id": "requester-id", "username": "나"},
            ),
            patch.object(
                server,
                "get_friends",
                return_value=[
                    {"user_id": "broken-friend", "username": "오류 사용자"},
                    {"user_id": "healthy-friend", "username": "정상 사용자"},
                ],
            ),
            patch.object(server, "fetch_user_rating", side_effect=fetch_rating),
        ):
            response = server.list_friend_rankings("requester-id")

        self.assertEqual(
            [item.user_id for item in response.ranks],
            ["healthy-friend", "requester-id"],
        )
        self.assertNotIn(
            "broken-friend",
            {item.user_id for item in response.ranks},
        )


if __name__ == "__main__":
    unittest.main()
