import unittest

from domain.course import engine
from domain.course.v2_models import (
    CourseModule,
    CourseModuleType,
    CourseV2,
    PassPolicy,
    RuntimeFlags,
)


class CourseWrongAnswerInsertionTests(unittest.TestCase):
    def test_reviews_are_appended_after_regular_modules(self) -> None:
        course = CourseV2(
            id="c1",
            title="Course",
            modules=[
                CourseModule(
                    id="m1",
                    type=CourseModuleType.problem_solve,
                    title="M1",
                    position=0,
                    pass_policy=PassPolicy(required_accuracy=90),
                ),
                CourseModule(
                    id="m2",
                    type=CourseModuleType.exam_solve,
                    title="M2",
                    position=1,
                    pass_policy=PassPolicy(required_accuracy=80),
                ),
            ],
        )

        updated = engine.insert_forced_wrong_answer_modules(course)

        self.assertEqual(
            [module.id for module in updated.modules],
            ["m1", "m2", "m1_wa_1", "m2_wa_2"],
        )
        self.assertEqual(
            [module.position for module in updated.modules],
            [0, 1, 2, 3],
        )

    def test_global_toggle_disables_reviews(self) -> None:
        course = CourseV2(
            id="c1",
            title="Course",
            runtime_flags=RuntimeFlags(enable_wrong_answer_auto_insert=False),
            modules=[
                CourseModule(
                    id="m1",
                    type=CourseModuleType.problem_solve,
                    title="M1",
                    pass_rate=90,
                ),
            ],
        )

        updated = engine.insert_forced_wrong_answer_modules(course)

        self.assertEqual([module.id for module in updated.modules], ["m1"])

    def test_module_toggle_disables_one_review(self) -> None:
        course = CourseV2(
            id="c1",
            title="Course",
            modules=[
                CourseModule(
                    id="m1",
                    type=CourseModuleType.problem_solve,
                    title="M1",
                    pass_rate=90,
                    wrong_answer_review_enabled=False,
                ),
                CourseModule(
                    id="m2",
                    type=CourseModuleType.exam_solve,
                    title="M2",
                    pass_rate=90,
                ),
            ],
        )

        updated = engine.insert_forced_wrong_answer_modules(course)

        self.assertEqual([module.id for module in updated.modules], ["m1", "m2", "m2_wa_1"])


if __name__ == "__main__":
    unittest.main()
