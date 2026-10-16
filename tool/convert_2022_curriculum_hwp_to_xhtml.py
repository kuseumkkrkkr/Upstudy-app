"""Convert the official locally downloaded 2022 mathematics HWP to XHTML."""
from __future__ import annotations

import hashlib
from pathlib import Path

from lxml import etree
from hwp5.hwp5html import HTMLTransform
from hwp5.xmlmodel import Hwp5File

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "work/official-curriculum/2022_appendix8_math.hwp"
OUTPUT = ROOT / "work/official-curriculum/2022_appendix8_math.xhtml"
SOURCE_HASH = ROOT / "work/official-curriculum/2022_appendix8_math.source.sha256"


def compile_xslt(stylesheet_path: str, **params: object):
    stylesheet = etree.XSLT(etree.parse(stylesheet_path))

    def transform(source_path: str, output_stream) -> None:
        result = stylesheet(etree.parse(source_path), **params)
        output_stream.write(bytes(result))

    return transform


def main() -> None:
    if not SOURCE.is_file():
        raise FileNotFoundError(f"Official source HWP is missing: {SOURCE}")
    digest = hashlib.sha256(SOURCE.read_bytes()).hexdigest().upper()
    if OUTPUT.is_file() and SOURCE_HASH.is_file() and SOURCE_HASH.read_text(encoding="ascii").strip() == digest:
        print(f"XHTML cache matches official HWP SHA-256 {digest}")
        return
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    hwp = Hwp5File(str(SOURCE))
    with OUTPUT.open("wb") as stream:
        HTMLTransform(xslt_compile=compile_xslt).transform_hwp5_to_xhtml(hwp, stream)
    if not OUTPUT.is_file() or OUTPUT.stat().st_size == 0:
        raise RuntimeError("HWP to XHTML conversion returned an empty output")
    SOURCE_HASH.write_text(digest + "\n", encoding="ascii")
    print(f"Converted {SOURCE.name} to {OUTPUT.name} ({OUTPUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
