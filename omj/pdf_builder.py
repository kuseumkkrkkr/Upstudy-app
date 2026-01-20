import os
import textwrap
from io import BytesIO
from typing import Dict, List

try:
    from reportlab.lib.pagesizes import A4
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.pdfgen import canvas

    _REPORTLAB_AVAILABLE = True
except Exception:
    A4 = (595.28, 841.89)
    _REPORTLAB_AVAILABLE = False

from storage.storage import get_quest

_GRID_COLUMNS = 2
_GRID_ROWS = 2
_LARGE_FLOW_THRESHOLD = 5
_HEADER_TEXT = "Powered By AIFlow | 수학영역 | 학번 | 이름"


def build_exam_pdf(items: List[Dict[str, object]]) -> bytes:
    if _REPORTLAB_AVAILABLE:
        return _build_reportlab_pdf(items)
    return _build_simple_pdf(items)


def _build_reportlab_pdf(items: List[Dict[str, object]]) -> bytes:
    buffer = BytesIO()
    page_width, page_height = A4
    margin = 36
    font_name = _get_font_name()
    font_size = 11

    c = canvas.Canvas(buffer, pagesize=A4)
    pages = _layout_items(items)

    total_pages = max(1, len(pages))
    for page_index, page in enumerate(pages or [{"entries": [], "column_spans": [False, False]}]):
        header_height = 36 if page_index == 0 else 0
        grid_top = page_height - margin - header_height
        grid_height = page_height - margin * 2 - header_height
        column_width = (page_width - margin * 2) / _GRID_COLUMNS
        row_height = grid_height / _GRID_ROWS

        c.rect(margin, margin, page_width - margin * 2, page_height - margin * 2, stroke=1, fill=0)

        if header_height > 0:
            c.setFont(font_name, font_size)
            c.drawString(margin + 6, page_height - margin - 18, _HEADER_TEXT)
            c.line(margin, grid_top, page_width - margin, grid_top)

        mid_x = margin + column_width
        c.line(mid_x, margin, mid_x, grid_top)
        mid_y = margin + row_height
        if not page["column_spans"][0]:
            c.line(margin, mid_y, mid_x, mid_y)
        if not page["column_spans"][1]:
            c.line(mid_x, mid_y, page_width - margin, mid_y)

        for entry in page["entries"]:
            item = entry["item"]
            column = entry["col"]
            row = entry["row"]
            row_span = entry["row_span"]
            x = margin + column * column_width
            top_y = grid_top - row * row_height
            text = _get_item_text(item)
            _draw_wrapped_text(
                c,
                text,
                x=x + 6,
                y=top_y - 18,
                max_width=column_width - 12,
                font_name=font_name,
                font_size=font_size,
            )

        c.setFont(font_name, 9)
        c.drawRightString(
            page_width - margin - 4,
            margin + 6,
            f"{page_index + 1} / {total_pages}",
        )
        c.showPage()

    c.save()
    return buffer.getvalue()


def _build_simple_pdf(items: List[Dict[str, object]]) -> bytes:
    page_width, page_height = A4
    margin = 36
    font_name = "Helvetica"
    font_size = 11

    pages = _layout_items(items)
    objects: List[str] = []

    pages_id = _add_obj(objects, "")
    font_id = _add_obj(objects, f"<< /Type /Font /Subtype /Type1 /BaseFont /{font_name} >>")

    page_ids: List[int] = []
    total_pages = max(1, len(pages))
    for page_index, page in enumerate(pages or [{"entries": [], "column_spans": [False, False]}]):
        header_height = 36 if page_index == 0 else 0
        grid_top = page_height - margin - header_height
        grid_height = page_height - margin * 2 - header_height
        column_width = (page_width - margin * 2) / _GRID_COLUMNS
        row_height = grid_height / _GRID_ROWS
        mid_x = margin + column_width
        mid_y = margin + row_height

        stream_parts: List[str] = []
        stream_parts.append(
            f"{margin:.2f} {margin:.2f} {page_width - margin * 2:.2f} {page_height - margin * 2:.2f} re S"
        )
        if header_height > 0:
            stream_parts.append(
                f"{margin:.2f} {grid_top:.2f} m {page_width - margin:.2f} {grid_top:.2f} l S"
            )
            stream_parts.append(
                f"BT /F1 {font_size} Tf {margin + 6:.2f} {page_height - margin - 18:.2f} Td "
                f"({ _pdf_escape(_HEADER_TEXT) }) Tj ET"
            )
        stream_parts.append(
            f"{mid_x:.2f} {margin:.2f} m {mid_x:.2f} {grid_top:.2f} l S"
        )
        if not page["column_spans"][0]:
            stream_parts.append(
                f"{margin:.2f} {mid_y:.2f} m {mid_x:.2f} {mid_y:.2f} l S"
            )
        if not page["column_spans"][1]:
            stream_parts.append(
                f"{mid_x:.2f} {mid_y:.2f} m {page_width - margin:.2f} {mid_y:.2f} l S"
            )

        for entry in page["entries"]:
            item = entry["item"]
            column = entry["col"]
            row = entry["row"]
            row_span = entry["row_span"]
            x = margin + column * column_width
            top_y = grid_top - row * row_height
            text = _get_item_text(item)
            lines = _wrap_text_simple(text, max_width=column_width - 12)
            text_x = x + 6
            text_y = top_y - 18
            line_height = font_size + 2
            stream_parts.append(f"BT /F1 {font_size} Tf {text_x:.2f} {text_y:.2f} Td")
            for line in lines:
                stream_parts.append(f"({ _pdf_escape(line) }) Tj")
                stream_parts.append(f"0 {-line_height:.2f} Td")
            stream_parts.append("ET")

        stream_parts.append(
            f"BT /F1 9 Tf {page_width - margin - 4:.2f} {margin + 6:.2f} Td "
            f"({page_index + 1} / {total_pages}) Tj ET"
        )

        stream = "\n".join(stream_parts)
        content_id = _add_obj(
            objects,
            f"<< /Length {len(stream.encode('utf-8'))} >>\nstream\n{stream}\nendstream",
        )
        page_id = _add_obj(
            objects,
            (
                f"<< /Type /Page /Parent {pages_id} 0 R "
                f"/Resources << /Font << /F1 {font_id} 0 R >> >> "
                f"/MediaBox [0 0 {page_width:.2f} {page_height:.2f}] "
                f"/Contents {content_id} 0 R >>"
            ),
        )
        page_ids.append(page_id)

    kids = " ".join(f"{page_id} 0 R" for page_id in page_ids)
    objects[pages_id - 1] = f"<< /Type /Pages /Kids [{kids}] /Count {len(page_ids)} >>"
    catalog_id = _add_obj(objects, f"<< /Type /Catalog /Pages {pages_id} 0 R >>")

    return _render_pdf(objects, catalog_id)


def _add_obj(objects: List[str], obj: str) -> int:
    objects.append(obj)
    return len(objects)


def _render_pdf(objects: List[str], catalog_id: int) -> bytes:
    buffer = BytesIO()
    buffer.write(b"%PDF-1.4\n")
    offsets = [0]
    for idx, obj in enumerate(objects, start=1):
        offsets.append(buffer.tell())
        buffer.write(f"{idx} 0 obj\n".encode("ascii"))
        buffer.write(obj.encode("utf-8"))
        buffer.write(b"\nendobj\n")
    xref_offset = buffer.tell()
    buffer.write(f"xref\n0 {len(objects)+1}\n".encode("ascii"))
    buffer.write(b"0000000000 65535 f \n")
    for offset in offsets[1:]:
        buffer.write(f"{offset:010d} 00000 n \n".encode("ascii"))
    buffer.write(
        f"trailer\n<< /Size {len(objects)+1} /Root {catalog_id} 0 R >>\n".encode("ascii")
    )
    buffer.write(f"startxref\n{xref_offset}\n%%EOF".encode("ascii"))
    return buffer.getvalue()


def _pdf_escape(text: str) -> str:
    return text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")


def _wrap_text_simple(text: str, max_width: float) -> List[str]:
    if not text:
        return [""]
    max_chars = max(10, int(max_width / 6))
    return textwrap.wrap(text, width=max_chars)


def _get_font_name() -> str:
    if not _REPORTLAB_AVAILABLE:
        return "Helvetica"
    font_path = os.environ.get("OMJ_PDF_FONT_PATH")
    if not font_path:
        font_path = _find_default_font_path()
    if font_path and os.path.exists(font_path):
        font_name = "OmjCustomFont"
        if font_name not in pdfmetrics.getRegisteredFontNames():
            pdfmetrics.registerFont(TTFont(font_name, font_path))
        return font_name
    return "Helvetica"


def _find_default_font_path() -> str | None:
    candidates = [
        r"C:\Windows\Fonts\malgun.ttf",
        r"C:\Windows\Fonts\malgunsl.ttf",
        "/System/Library/Fonts/AppleSDGothicNeo.ttc",
        "/System/Library/Fonts/Supplemental/AppleGothic.ttf",
        "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/truetype/noto/NotoSansCJKkr-Regular.otf",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/truetype/nanum/NanumGothic.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            return path
    return None


def _layout_items(items: List[Dict[str, object]]) -> List[Dict[str, object]]:
    pages: List[Dict[str, object]] = []
    entries: List[Dict[str, object]] = []
    column_spans = [False, False]
    occupied = [[False, False], [False, False]]

    def flush() -> None:
        nonlocal entries, column_spans
        if entries:
            pages.append(
                {
                    "entries": entries,
                    "column_spans": column_spans,
                }
            )
        entries = []
        column_spans = [False, False]
        occupied[:] = [[False, False], [False, False]]

    def find_free_column() -> int | None:
        for col in range(_GRID_COLUMNS):
            if not occupied[col][0] and not occupied[col][1]:
                return col
        return None

    def find_free_slot() -> tuple[int, int] | None:
        for col in range(_GRID_COLUMNS):
            for row in range(_GRID_ROWS):
                if not occupied[col][row]:
                    return col, row
        return None

    for item in items:
        flow_count = item.get("flow_count") or item.get("solves_count") or 0
        is_large = flow_count > _LARGE_FLOW_THRESHOLD
        if is_large:
            column = find_free_column()
            if column is None:
                flush()
                column = find_free_column() or 0
            entries.append(
                {
                    "item": item,
                    "col": column,
                    "row": 0,
                    "row_span": 2,
                }
            )
            column_spans[column] = True
            occupied[column][0] = True
            occupied[column][1] = True
            continue

        slot = find_free_slot()
        if slot is None:
            flush()
            slot = find_free_slot() or (0, 0)
        entries.append(
            {
                "item": item,
                "col": slot[0],
                "row": slot[1],
                "row_span": 1,
            }
        )
        occupied[slot[0]][slot[1]] = True

    if entries:
        pages.append(
            {
                "entries": entries,
                "column_spans": column_spans,
            }
        )
    return pages


def _get_item_text(item: Dict[str, object]) -> str:
    quest_title = None
    if item.get("quest_id"):
        quest = get_quest(item["quest_id"])
        if quest:
            quest_title = quest.get("data", {}).get("quest_title")
    if not quest_title:
        quest_title = "Generating..."
    return f"{item.get('item_index')}. {quest_title}"


def _draw_wrapped_text(
    c: canvas.Canvas,
    text: str,
    *,
    x: float,
    y: float,
    max_width: float,
    font_name: str,
    font_size: int,
) -> None:
    c.setFont(font_name, font_size)
    wrapped_lines = _wrap_text(text, max_width, font_name, font_size)
    line_height = font_size + 2
    text_obj = c.beginText(x, y)
    for line in wrapped_lines:
        text_obj.textLine(line)
    c.drawText(text_obj)


def _wrap_text(text: str, max_width: float, font_name: str, font_size: int) -> List[str]:
    if not text:
        return [""]
    words = text.split(" ")
    if len(words) == 1:
        return textwrap.wrap(text, width=80)
    lines: List[str] = []
    current = ""
    for word in words:
        candidate = f"{current} {word}".strip()
        width = pdfmetrics.stringWidth(candidate, font_name, font_size)
        if width <= max_width or not current:
            current = candidate
        else:
            lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines
