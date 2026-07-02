# Challenge API Routes

## Endpoints

| Method | Path | Role | Description |
|--------|------|------|-------------|
| GET | /challenges | student, teacher, admin | List active challenges |
| POST | /challenges/{id}/attempt | student | Submit answers, returns score |
| GET | /challenges/{id}/progress | student, teacher, admin | Get own progress (student) or any progress (teacher/admin) |
| POST | /challenges/generate/daily | teacher, admin | Generate daily challenge |
| POST | /challenges/generate/weekly | teacher, admin | Generate weekly challenge |

## Status
Wave 4 complete
