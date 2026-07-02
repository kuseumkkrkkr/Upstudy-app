# Quest Domain

Provides:
- **QuestVariant** — AI-generated problem variants (easier, harder, hint-heavy, scaffolded, speed-drill, proof-variant)
- **QuestFlow** — teacher-defined quest sequences with gating/branching rules

## Modules

| File | Purpose |
|------|---------|
| `models.py` | Pydantic models with `ConfigDict(from_attributes=True)` |
| `variant_engine.py` | `generate_variant`, `apply_difficulty_adjustment`, `_scaffold_problem`, `_speed_drill_variant` |
| `repository.py` | SQLite CRUD (`quests.db`) + `_ensure_quest_tables()` |

## Status

Wave 3 complete
