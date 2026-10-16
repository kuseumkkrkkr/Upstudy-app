"""Cross-platform SHA-256 helpers for UTF-8 JSON textbook source files."""
from __future__ import annotations

import hashlib
from pathlib import Path


def canonical_utf8_bytes(data: bytes) -> bytes:
    """Normalize Windows CRLF to LF while preserving all other UTF-8 bytes."""
    return data.replace(b"\r\n", b"\n")


def canonical_file_sha256(path: Path) -> str:
    """Return uppercase SHA-256 independent of checkout newline conversion."""
    return hashlib.sha256(canonical_utf8_bytes(path.read_bytes())).hexdigest().upper()
