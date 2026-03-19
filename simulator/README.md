# Rating Simulator (Standalone)

Run:

```bash
python simulator/rating_simulator.py
```

Notes
- This GUI simulates the same rating logic as the backend (barrier, confidence, time penalty, tag-based updates).
- Keep constants in sync with `omj/rating_config.py` if you change them.
- Steps input format:
  - `enter_huddle | tag1,tag2 | correct`
  - `correct` is optional (`1`/`0`, `true`/`false`). If omitted, global correctness is used.

Examples:
```
3 | diff | 1
6 | diff,exp | 0
4 | exp | 1
```

Buttons
- Apply Submission: applies one update using the form inputs.
- Run Random Sim: runs N random problems with random steps and correctness.
- Reset: clears user state and history.
```
