# Quest Generator

CLI and API server that build math quest data with a Gemini-based model and store results in a SQLite database.

## Requirements
- Python 3.10+ (sqlite3 is built-in)
- pip packages: pydantic, google-genai
- API packages: fastapi, uvicorn, pyjwt, reportlab

## Setup
- Create a `.env` file (recommended) and set `COMETAPI_KEY`.
  - Example: `COMETAPI_KEY=...`
- Or set `COMETAPI_KEY` in your shell environment.
  - PowerShell example: `$env:COMETAPI_KEY="..."`.
- Install deps: `pip install -r requirements.txt`

## Run (CLI)
```bash
python main.py
```

Inputs:
- `hash_tags`: comma-separated tags. Allowed tags come from `SUBJECT_TAG_RULES` in `generater/fix_gen.py`.
- `solves_count`: integer >= 1 (root flow count).
- `strategy_level`: 1~3, controls prompt difficulty and sets `main_huddle`.
- `branch_conditions`: integer >= 0, number of conditional lanes to branch.
- `reference_quest_id`: optional quest id from `quests.db`.

## Run (API)
```bash
cd omj
uvicorn server:app --reload
```

Environment variables:
- `COMETAPI_KEY`: required for AI generation.
- `OMJ_JWT_SECRET`: secret for JWT tokens (defaults to a dev value).
- `OMJ_PDF_FONT_PATH`: optional TTF font path for PDF rendering (recommended for non-ASCII text).

API endpoints:
- `POST /auth/anonymous`: issue a JWT token.
- `POST /exams`: create an exam.
- `GET /exams/{exam_id}`: exam status and items.
- `GET /exams/{exam_id}/pdf`: download PDF (`?inline=1` for browser preview).

## Output and storage
- Prints generated JSON to stdout.
- Stores records in `quests.db`:
- `quest_header`, `quest_info`, `quest_data`, `solve_step`.
 - `exam`, `exam_item` for exam sessions.

Difficulty formula:
`difficulty = 1*hashtag_count + 4*total_flow_count + 3*branch_lane_count + 2*sum(enter_huddle)`. Branching flows are stored as JSON in the `branches` column of `solve_step`.

## Structure
- `main.py`: CLI entry point.
- `generater/`: prompt building, AI call, and result normalization.
- `storage/storage.py`: SQLite persistence.
