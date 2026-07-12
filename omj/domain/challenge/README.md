# Daily Quest Plan

## Data

- `daily_challenge_template` stores editable daily quest templates in `quests.db`.
- The bundled seed catalog contains 60 templates:
  - `easy`: 20 templates, 10 points each
  - `medium`: 20 templates, 20 points each
  - `hard`: 20 templates, 40 points each
- Daily quota is fixed to 5 challenges:
  - `easy`: 2
  - `medium`: 2
  - `hard`: 1
- The daily total is 100 points, matching `student_account_store.DAILY_POINT_LIMIT`.

## Assignment Algorithm

1. Load enabled templates from `daily_challenge_template`.
2. Apply a course `challenge_settings.available_types` filter when present.
3. Compute course module type ratios from `CourseV2.modules`.
4. Weight templates by matching `module_types` against the course ratios.
5. Select the fixed quota with a deterministic random seed:
   `user_id:course_id:date`.
6. Save the assigned daily set in `user_kv` under
   `daily_quests:{course_id}:{YYYY-MM-DD}`.

This keeps the same daily quest set stable for a student during the day,
while future days reflect teacher edits to the DB templates.

## Completion And Reward

- Runtime events only update progress and mark a challenge as `completed`.
- Points are awarded only when the student presses the reward button.
- Direct reward claims before completing the required action return
  `verification_required` and do not grant points.
- Awarding is still deduplicated by `student_point_ledger`.

## Teacher/Admin API

- `GET /challenges/daily-quest-templates`
- `PUT /challenges/daily-quest-templates`
- `POST /challenges/daily-quest-templates/reset-defaults`

The teacher app can use these endpoints to edit titles, descriptions, targets,
difficulty, reward points, module affinity, and enabled state.
