# Course Domain

Pydantic v2 models and SQLite repository for the V2 course engine.

## Files

| File | Purpose |
|---|---|
| `v2_models.py` | `CourseV2`, `CourseModule`, policy models, `CourseModuleType` enum |
| `v2_repository.py` | SQLite CRUD for the `course_v2` table (JSON columns) |
| `engine.py` | Module pass/fail evaluator, forced wrong-answer insertion, next-module resolver |

## Dependencies

- `omj.storage.storage` (canonical `DB_PATH`)
- `omj.app.schemas.common` (ApiResponse envelope — used by router, not domain)

## Key Design Decisions

1. **Forced wrong-answer insertion**: `engine.insert_forced_wrong_answer_modules` scans a `CourseV2` and appends `wrong_answer_review` modules after any module with `required_accuracy < 100`. These review modules bypass `flow_policy` restrictions (`mode="full"`).
2. **Policy fallback**: module-level `pass_policy` / `flow_policy` overrides course-level defaults.
3. **Max problems per module**: capped at 10 for `problem_solve` and `wrong_answer_review`.
4. **Runtime state**: `CourseModule.state` is transient and NOT stored in the DB schema.
