# Quest API Routes

FastAPI router for the Quest Variant domain.

## Endpoints

| Method | Path | Access | Description |
|--------|------|--------|-------------|
| POST | `/quests/{quest_id}/variants` | student | Enqueue variant generation (returns job id) |
| GET  | `/quests/{quest_id}/variants` | student | List variants for a quest |
| POST | `/quests/flows` | teacher, admin | Create a custom quest flow |
| GET  | `/quests/flows/{flow_id}` | teacher, admin | Retrieve a quest flow |

All responses are wrapped in `CommonResponse`.

## Status

Wave 3 complete
