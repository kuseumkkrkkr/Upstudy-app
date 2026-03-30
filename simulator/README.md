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

# Character Chat Simulator (Standalone)

Run:

```bash
python simulator/character_chat_simulator.py
```

Notes
- Requires the backend API running (default `http://localhost:8000`).
- Use `--base-url` to point at a different server.
- Type `/help` inside the simulator for commands.


# Character Chat Simulator (PyQt)

Run:

```bash
python simulator/character_chat_pyqt.py
```

Notes
- Requires PyQt5 and google-genai installed.
- Requires COMETAPI_KEY in the environment.
- After 10 user questions, the assistant will announce the final answer and explain it.

# Heatmap Stroke Simulator (PyQt)

Run:

```bash
python simulator/heatmap_simulator.py
```

Notes
- Pen strokes are highlighted when gap between strokes exceeds the threshold (4th stroke onward), or after 5+ undo presses.
- Erase heatmap uses grid counts per eraser stroke; 3/5/7+ hits increase overlay opacity.
- Gap time is capped at 6 seconds for detection.
