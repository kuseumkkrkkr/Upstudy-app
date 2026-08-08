import unittest
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from generater.fix_gen import (
    allowed_generation_tags,
    generation_tag_groups,
    validate_generation_tags,
)


class GenerationTagRegistryTests(unittest.TestCase):
    def test_registry_exposes_fix_gen_tags(self) -> None:
        groups = generation_tag_groups()
        tags = allowed_generation_tags()

        self.assertEqual(len(groups), 8)
        self.assertEqual(len(tags), 320)
        self.assertIn("직선기울기", tags)
        self.assertIn("공통수학2", {group["label"] for group in groups})
        self.assertIn("확률과 통계", {group["label"] for group in groups})
        self.assertIn("기초·선수학습", {group["label"] for group in groups})

    def test_validation_normalizes_hash_prefix_and_deduplicates(self) -> None:
        self.assertEqual(
            validate_generation_tags(
                ["#직선기울기", "직선기울기", " 직선의방정식 "]
            ),
            ["직선기울기", "직선의방정식"],
        )

    def test_validation_rejects_unknown_tags(self) -> None:
        with self.assertRaises(ValueError):
            validate_generation_tags(["직선기울기", "없는태그"])

    def test_validation_rejects_empty_by_default(self) -> None:
        with self.assertRaises(ValueError):
            validate_generation_tags([])


if __name__ == "__main__":
    unittest.main()
