# OVR Rating Simulation (`sim_data`)

## What was verified from `lib`

The Flutter client under `lib` does **not** contain the true rating update algorithm (correct/wrong -> rating delta).  
It sends answer results to server API and receives computed rating values.

Key references:
- `lib/services/api_client.dart:1425` (`submitRating`)
- `lib/services/api_client.dart:1434` (`/rating/submit`)
- `lib/tryout/build_page_widget.dart:1866` (submit call with `isCorrect`, `tags`)
- `lib/pages/exam_paper/logic/exam_paper_state_grading.dart:869` (submit call)

## Exact formula replicated from app display logic

From `lib/mainstudent.dart` and tag modal code:
- `rating_floor = 1200`
- `display_max = 32767`
- `ovr_divider = 128`

Display conversion:
- `display = clamp(max(rating, 1200) - 1200, 0, 32767)`
- `ovr = display / 128`

This is implemented exactly in `rating_model.py`.

## About the simulated update algorithm

Because update logic is server-side only, this folder uses a **proxy** model:
- Correct answer on random tag: rating increases
- Wrong answer on random tag: rating decreases
- Difficulty and expected score are used (Elo-like)
- Parameters are tunable and auto-adjusted when validation fails

## Run

```powershell
python sim_data/run_simulation.py
```

Outputs:
- `sim_data/results_latest.json`
- `sim_data/results_<timestamp>.json`
