# Courses API Routes

FastAPI router for the V2 course domain.

## Files

| File | Purpose |
|---|---|
| `router.py` | FastAPI `APIRouter` for `/courses/v2/*` endpoints |

## Endpoints

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/courses/v2` | teacher, admin | Create a V2 course (auto-inserts forced WA modules) |
| GET | `/courses/v2/{id}` | student, teacher, admin | Retrieve a V2 course |
| PUT | `/courses/v2/{id}` | teacher, admin | Update a V2 course |
| DELETE | `/courses/v2/{id}` | admin | Delete a V2 course |
| GET | `/courses/v2` | student, teacher, admin | List V2 courses with filters |
| POST | `/courses/v2/{id}/runtime/next` | student, teacher, admin | Evaluate next module for a student |
| POST | `/courses/v2/{id}/validate` | teacher, admin | Run validation on a stored course |

## Dependencies

- `omj.app.api.routes.auth.middleware.require_role`
- `omj.app.schemas.common.ApiResponse`
- `omj.domain.course.v2_models`
- `omj.domain.course.v2_repository`
- `omj.domain.course.engine`
