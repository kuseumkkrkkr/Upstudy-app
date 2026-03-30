from __future__ import annotations

import sys
from pathlib import Path


def _ensure_repo_on_path() -> None:
    root = Path(__file__).resolve().parents[1]
    root_str = str(root)
    if root_str not in sys.path:
        sys.path.insert(0, root_str)


def main() -> None:
    _ensure_repo_on_path()
    from simulator.csat_codebase.ui import main as run_ui

    run_ui()


if __name__ == "__main__":
    main()
