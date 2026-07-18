import unittest
from unittest.mock import patch

import serverchat


class ServerChatProfileTest(unittest.TestCase):
    """필요 변수: 런타임 채팅 모델 환경값. 작동 원리: 프로필 응답이 현재 모델 식별자를 노출하는지 검증한다."""

    def test_serverchat_profile_exposes_runtime_model(self):
        """필요 변수: 임시 모델명. 작동 원리: 프로필의 캐릭터와 모델 값이 서버 설정을 그대로 반영하는지 확인한다."""
        with patch.object(serverchat, "MODEL_NAME", "gemma-test-model"):
            profile = serverchat.get_character_profile("student-1")

        self.assertEqual(profile["character"], "gemma")
        self.assertEqual(profile["model"], "gemma-test-model")


if __name__ == "__main__":
    unittest.main()
