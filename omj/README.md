# Quest Generator

CLI and API server that build math quest data with SAM OpenAI-compatible models and store results in a SQLite database.

## Requirements
- Python 3.10+ (sqlite3 is built-in)
- pip packages: pydantic, openai, google-genai
- API packages: fastapi, uvicorn, pyjwt, reportlab

## Setup
- Create a `.env` file (recommended) and set `SAM_API_KEY`.
  - Example: `SAM_API_KEY=...`
- Or set `SAM_API_KEY` in your shell environment.
  - PowerShell example: `$env:SAM_API_KEY="..."`.
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

`--reload`는 Python 파일 변경 때 프로세스를 다시 만들므로 TexTeller도 다시 적재한다. OCR 체감 속도를 확인하거나 운영할 때는 reload 없이 실행한다.

```bash
cd omj
python scripts/prefetch_texteller.py
uvicorn server:app --host 0.0.0.0 --port 8000
```

`OCR_TEXTELLER_WARMUP_ON_STARTUP=true`이면 서버가 요청을 받기 전에 모델을 한 번 적재한다. 동일 필기의 재채점·디버그 재실행은 `OCR_TEXTELLER_CACHE_TTL_SECONDS` 동안 결과 캐시를 사용한다.

Environment variables:
- `SAM_API_KEY`: required for AI generation.
- `OMJ_JWT_SECRET`: secret for JWT tokens (defaults to a dev value).
- `OMJ_PDF_FONT_PATH`: optional TTF font path for PDF rendering (recommended for non-ASCII text).
- `OCR_TEXTELLER_WARMUP_ON_STARTUP`: 서버 시작 중 로컬 OCR 모델을 미리 적재한다.
- `OCR_TEXTELLER_CACHE_MAX_ENTRIES`: 동일 필기 재실행 결과의 프로세스별 최대 캐시 수다.
- `OCR_TEXTELLER_CACHE_TTL_SECONDS`: OCR 결과 캐시 유지 시간(초)이다.

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

Rating / ELO documentation:
- [RATING_ALGORITHM.md](./RATING_ALGORITHM.md) - rating input variables, derived signals, and output fields.

Difficulty formula:
`difficulty = 1*hashtag_count + 4*total_flow_count + 3*branch_lane_count + 2*sum(enter_huddle)`. Branching flows are stored as JSON in the `branches` column of `solve_step`.

## Structure
- `main.py`: CLI entry point.
- `generater/`: prompt building, AI call, and result normalization.
- `storage/storage.py`: SQLite persistence.
