import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from omj.generater.codebase_runner import (
    _normalize_legacy_result,
    _coerce_blocks,
    _validate_sympy_meta,
)

def sample_legacy_result() -> dict:
