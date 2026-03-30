from PyQt5.QtCore import Qt, QPoint, QSize
from PyQt5.QtGui import QPainter, QPen, QColor, QImage, QPainterPath, QPainterPathStroker
from PyQt5.QtWidgets import (
    QApplication,
    QWidget,
    QVBoxLayout,
    QHBoxLayout,
    QPushButton,
    QLabel,
    QSpinBox,
    QDoubleSpinBox,
    QCheckBox,
    QGroupBox,
)

import sys
import time


class HeatmapCanvas(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAttribute(Qt.WA_StaticContents)
        self.setMouseTracking(True)

        self.mode = "pen"  # or "eraser"
        self.pen_color = QColor(30, 30, 30)
        self.highlight_color = QColor(220, 80, 40)
        self.pen_heat_color = QColor(20, 80, 220)
        self.eraser_radius = 12
        self.pen_width = 3

        self.image = QImage(1020, 1080, QImage.Format_ARGB32_Premultiplied)
        self.image.fill(Qt.transparent)

        self.grid_size = 10
        self.erase_counts = self._make_grid()
        self.pen_counts = self._make_grid()

        self.pen_strokes = []

        self.pen_level1 = 1
        self.pen_level2 = 3
        self.pen_level3 = 5
        self.erase_level1 = 4
        self.erase_level2 = 6
        self.erase_level3 = 8
        self.over_dark_cells = set()
        self.over_dark_color = QColor(255, 111, 216)

        self.history = []  # list of (image, erase_counts)
        self.undo_counter = 0

        self.pen_stroke_count = 0
        self.last_pen_end_ts = None
        self.ignore_first_strokes = 3
        self.gap_threshold_sec = 3.0
        self.max_gap_sec = 6.0
        self.highlight_last_reason = "-"

        self.show_grid = True
        self.show_pen_heat = True
        self.show_erase_heat = True
        self.draw_grid = False

        self._drawing = False
        self._last_point = QPoint()
        self._current_pen_highlight = False
        self._current_eraser_cells = set()
        self._current_pen_cells = set()
        self._current_pen_path = None
        self._current_eraser_path = None

        self.on_update = None

    def sizeHint(self):
        return QSize(self.image.width(), self.image.height())

    def _make_grid(self):
        cols = max(1, self.image.width() // self.grid_size)
        rows = max(1, self.image.height() // self.grid_size)
        return [[0 for _ in range(cols)] for _ in range(rows)]

    def _clone_grid(self):
        return [row[:] for row in self.erase_counts]

    def _push_history(self):
        self.history.append((self.image.copy(), self._clone_grid()))

    def _restore_from_history(self):
        if not self.history:
            return
        self.image, self.erase_counts = self.history.pop()
        self.update()

    def set_mode(self, mode):
        self.mode = mode

    def set_grid_size(self, size):
        self.grid_size = max(10, size)
        self.erase_counts = self._make_grid()
        self.pen_counts = self._make_grid()
        self.history = []
        self.update()

    def set_canvas_size(self, width, height):
        width = max(100, int(width))
        height = max(100, int(height))
        self.image = QImage(width, height, QImage.Format_ARGB32_Premultiplied)
        self.image.fill(Qt.transparent)
        self.setFixedSize(width, height)
        self.erase_counts = self._make_grid()
        self.pen_counts = self._make_grid()
        self.history = []
        self.pen_strokes = []
        self.pen_stroke_count = 0
        self.last_pen_end_ts = None
        self.undo_counter = 0
        self.highlight_last_reason = "-"
        self.update()

    def set_gap_threshold(self, sec):
        self.gap_threshold_sec = sec

    def set_pen_thresholds(self, level1, level2, level3):
        level2 = max(level2, level1)
        level3 = max(level3, level2)
        self.pen_level1 = max(1, int(level1))
        self.pen_level2 = max(1, int(level2))
        self.pen_level3 = max(1, int(level3))
        self.update()

    def set_erase_thresholds(self, level1, level2, level3):
        level2 = max(level2, level1)
        level3 = max(level3, level2)
        self.erase_level1 = max(1, int(level1))
        self.erase_level2 = max(1, int(level2))
        self.erase_level3 = max(1, int(level3))
        self.update()

    def set_show_grid(self, enabled):
        self.show_grid = enabled
        self.update()

    def set_show_pen_heat(self, enabled):
        self.show_pen_heat = enabled
        self.update()

    def set_show_erase_heat(self, enabled):
        self.show_erase_heat = enabled
        self.update()

    def clear_all(self):
        self.image.fill(Qt.transparent)
        self.erase_counts = self._make_grid()
        self.pen_counts = self._make_grid()
        self.history = []
        self.pen_strokes = []
        self.pen_stroke_count = 0
        self.last_pen_end_ts = None
        self.undo_counter = 0
        self.highlight_last_reason = "-"
        self.update()

    def undo(self):
        if self.history:
            self._restore_from_history()
        self.undo_counter += 1

    def mousePressEvent(self, event):
        if event.button() != Qt.LeftButton:
            return
        self._drawing = True
        self._last_point = event.pos()
        self._current_eraser_cells = set()

        if self.mode == "pen":
            self._current_pen_path = QPainterPath()
            self._current_pen_path.moveTo(self._last_point)
            self._current_pen_cells = set()
            self._current_pen_highlight = self._should_highlight_pen_stroke()
        else:
            self._current_pen_highlight = False
            self._current_eraser_path = QPainterPath()
            self._current_eraser_path.moveTo(self._last_point)

    def mouseMoveEvent(self, event):
        if not (event.buttons() & Qt.LeftButton) or not self._drawing:
            return

        if self.mode == "pen":
            self._draw_line_to(event.pos(), highlight=self._current_pen_highlight)
        else:
            self._erase_at(event.pos())

        self._last_point = event.pos()
        self.update()

    def mouseReleaseEvent(self, event):
        if event.button() != Qt.LeftButton or not self._drawing:
            return
        self._drawing = False

        if self.mode == "pen":
            self._draw_line_to(event.pos(), highlight=self._current_pen_highlight)
            if self._current_pen_path is not None:
                self.pen_strokes.append(
                    {
                        "path": self._current_pen_path,
                        "highlight": self._current_pen_highlight,
                    }
                )
            if self._current_pen_cells:
                for cell in self._current_pen_cells:
                    r, c = cell
                    if 0 <= r < len(self.pen_counts) and 0 <= c < len(self.pen_counts[0]):
                        self.pen_counts[r][c] += 1
            self._current_pen_path = None
            self._current_pen_cells = set()
            self.pen_stroke_count += 1
            self.last_pen_end_ts = time.time()
            self._update_over_dark_cells()
            self._redraw_image()
        else:
            self._erase_at(event.pos())
            self._apply_eraser_to_strokes()
            if self._current_eraser_cells:
                for cell in self._current_eraser_cells:
                    r, c = cell
                    if 0 <= r < len(self.erase_counts) and 0 <= c < len(self.erase_counts[0]):
                        if self.pen_counts[r][c] >= self.pen_level1:
                            self.erase_counts[r][c] += 1
            self._current_eraser_cells = set()
            self._current_eraser_path = None
            self._update_over_dark_cells()
            self._redraw_image()

        self._push_history()
        if self.on_update:
            self.on_update()
        self.update()

    def _should_highlight_pen_stroke(self):
        reason = None
        if self.undo_counter >= 5:
            reason = f"undo>=5 ({self.undo_counter})"
        # gap-based highlight disabled
        if reason:
            self.highlight_last_reason = reason
            self.undo_counter = 0
            return True
        self.highlight_last_reason = "-"
        return False

    def _draw_line_to(self, end_point, highlight=False):
        painter = QPainter(self.image)
        pen = QPen(
            self.highlight_color if highlight else self.pen_color,
            self.pen_width,
            Qt.SolidLine,
            Qt.RoundCap,
            Qt.RoundJoin,
        )
        painter.setPen(pen)
        painter.drawLine(self._last_point, end_point)
        painter.end()
        if self._current_pen_path is not None:
            self._current_pen_path.lineTo(end_point)
            self._record_pen_cells(end_point)
            self._record_pen_cells(self._last_point)

    def _erase_at(self, pos):
        if self._current_eraser_path is not None:
            self._current_eraser_path.lineTo(pos)

        # Record cells touched in this eraser stroke
        self._record_eraser_cells(pos)
        self._record_eraser_cells(self._last_point)

    def _record_eraser_cells(self, pos):
        col = int(pos.x() // self.grid_size)
        row = int(pos.y() // self.grid_size)
        for dr in range(-4, 5):
            for dc in range(-4, 5):
                self._current_eraser_cells.add((row + dr, col + dc))

    def _record_pen_cells(self, pos):
        col = int(pos.x() // self.grid_size)
        row = int(pos.y() // self.grid_size)
        for dr in (-1, 0, 1):
            for dc in (-1, 0, 1):
                self._current_pen_cells.add((row + dr, col + dc))

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.fillRect(0, 0, self.image.width(), self.image.height(), QColor(255, 255, 255))
        if self.show_pen_heat:
            self._draw_heatmap(
                painter,
                self.pen_counts,
                self.pen_heat_color,
                self.pen_level1,
                self.pen_level2,
                self.pen_level3,
            )
        if self.show_erase_heat:
            self._draw_heatmap(
                painter,
                self.erase_counts,
                QColor(230, 60, 60),
                self.erase_level1,
                self.erase_level2,
                self.erase_level3,
            )
        painter.drawImage(0, 0, self.image)
        if self.show_grid:
            self._draw_grid_lines(painter)
        painter.end()

    def _draw_heatmap(self, painter, counts, base_color, level1, level2, level3):
        rows = len(counts)
        cols = len(counts[0]) if rows else 0
        if rows == 0 or cols == 0:
            return
        for r in range(rows):
            for c in range(cols):
                count = counts[r][c]
                if count >= level3:
                    color = QColor(base_color.red(), base_color.green(), base_color.blue(), 160)
                elif count >= level2:
                    color = QColor(base_color.red(), base_color.green(), base_color.blue(), 110)
                elif count >= level1:
                    color = QColor(base_color.red(), base_color.green(), base_color.blue(), 70)
                else:
                    continue
                painter.fillRect(
                    c * self.grid_size,
                    r * self.grid_size,
                    self.grid_size,
                    self.grid_size,
                    color,
                )

    def _draw_grid_lines(self, painter):
        pen = QPen(QColor(200, 200, 200, 120), 1)
        painter.setPen(pen)
        width = self.image.width()
        height = self.image.height()
        for x in range(0, width, self.grid_size):
            painter.drawLine(x, 0, x, height)
        for y in range(0, height, self.grid_size):
            painter.drawLine(0, y, width, y)

    def _update_over_dark_cells(self):
        rows = len(self.pen_counts)
        cols = len(self.pen_counts[0]) if rows else 0
        if rows == 0 or cols == 0:
            self.over_dark_cells = set()
            return
        cells = set()
        for r in range(rows):
            for c in range(cols):
                if self.pen_counts[r][c] >= self.pen_level2 and self.erase_counts[r][c] >= self.erase_level2:
                    cells.add((r, c))
        self.over_dark_cells = cells

    def _apply_eraser_to_strokes(self):
        if not self._current_eraser_path or not self.pen_strokes:
            return
        eraser_stroker = QPainterPathStroker()
        eraser_stroker.setWidth(self.eraser_radius * 2)
        eraser_stroker.setCapStyle(Qt.RoundCap)
        eraser_stroker.setJoinStyle(Qt.RoundJoin)
        eraser_shape = eraser_stroker.createStroke(self._current_eraser_path)

        pen_stroker = QPainterPathStroker()
        pen_stroker.setWidth(self.pen_width)
        pen_stroker.setCapStyle(Qt.RoundCap)
        pen_stroker.setJoinStyle(Qt.RoundJoin)

        remaining = []
        for stroke in self.pen_strokes:
            stroke_shape = pen_stroker.createStroke(stroke["path"])
            if not eraser_shape.intersects(stroke_shape):
                remaining.append(stroke)
        if len(remaining) != len(self.pen_strokes):
            self.pen_strokes = remaining
            self._redraw_image()

    def _redraw_image(self):
        self.image.fill(Qt.transparent)
        painter = QPainter(self.image)
        for stroke in self.pen_strokes:
            use_lime = self._stroke_hits_over_dark(stroke["path"])
            pen = QPen(
                self.over_dark_color if use_lime else (self.highlight_color if stroke["highlight"] else self.pen_color),
                self.pen_width,
                Qt.SolidLine,
                Qt.RoundCap,
                Qt.RoundJoin,
            )
            painter.setPen(pen)
            painter.drawPath(stroke["path"])
        painter.end()

    def _stroke_hits_over_dark(self, path):
        if not self.over_dark_cells:
            return False
        rect = path.boundingRect()
        min_col = max(0, int(rect.left() // self.grid_size))
        max_col = min(len(self.pen_counts[0]) - 1, int(rect.right() // self.grid_size))
        min_row = max(0, int(rect.top() // self.grid_size))
        max_row = min(len(self.pen_counts) - 1, int(rect.bottom() // self.grid_size))
        for r in range(min_row, max_row + 1):
            for c in range(min_col, max_col + 1):
                if (r, c) in self.over_dark_cells:
                    return True
        return False

    @staticmethod
    def sum_counts(counts):
        total = 0
        for row in counts:
            total += sum(row)
        return total

    @staticmethod
    def sum_overlap(counts_a, counts_b):
        total = 0
        rows = min(len(counts_a), len(counts_b))
        cols = min(len(counts_a[0]), len(counts_b[0])) if rows else 0
        for r in range(rows):
            for c in range(cols):
                total += min(counts_a[r][c], counts_b[r][c])
        return total

class HeatmapSimulator(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Heatmap Stroke Simulator")
        self.canvas = HeatmapCanvas(self)
        self.canvas.on_update = self._sync_info

        self.info_label = QLabel("stroke=0 | undo=0 | last-highlight=-")
        self.metric_label = QLabel("erase_total=0 | rewrite_total=0")
        self._make_ui()
        self._sync_info()

    def _make_ui(self):
        root = QVBoxLayout()
        root.addWidget(self.canvas)

        controls = QHBoxLayout()

        pen_btn = QPushButton("Pen")
        pen_btn.clicked.connect(lambda: self.canvas.set_mode("pen"))
        eraser_btn = QPushButton("Eraser")
        eraser_btn.clicked.connect(lambda: self.canvas.set_mode("eraser"))
        undo_btn = QPushButton("Undo")
        undo_btn.clicked.connect(self._on_undo)
        clear_btn = QPushButton("Clear")
        clear_btn.clicked.connect(self._on_clear)

        controls.addWidget(pen_btn)
        controls.addWidget(eraser_btn)
        controls.addWidget(undo_btn)
        controls.addWidget(clear_btn)
        controls.addStretch(1)

        settings = QGroupBox("Settings")
        settings_layout = QHBoxLayout()

        grid_spin = QSpinBox()
        grid_spin.setRange(10, 80)
        grid_spin.setValue(self.canvas.grid_size)
        grid_spin.valueChanged.connect(self.canvas.set_grid_size)

        width_spin = QSpinBox()
        width_spin.setRange(100, 2000)
        width_spin.setValue(self.canvas.image.width())

        height_spin = QSpinBox()
        height_spin.setRange(100, 2000)
        height_spin.setValue(self.canvas.image.height())

        def _apply_canvas_size():
            self.canvas.set_canvas_size(width_spin.value(), height_spin.value())
            width_spin.setValue(self.canvas.image.width())
            height_spin.setValue(self.canvas.image.height())

        width_spin.valueChanged.connect(_apply_canvas_size)
        height_spin.valueChanged.connect(_apply_canvas_size)

        gap_spin = QDoubleSpinBox()
        gap_spin.setRange(0.5, 6.0)
        gap_spin.setSingleStep(0.5)
        gap_spin.setValue(self.canvas.gap_threshold_sec)
        gap_spin.valueChanged.connect(self.canvas.set_gap_threshold)

        pen_level1_spin = QSpinBox()
        pen_level1_spin.setRange(1, 50)
        pen_level1_spin.setValue(self.canvas.pen_level1)

        pen_level2_spin = QSpinBox()
        pen_level2_spin.setRange(1, 50)
        pen_level2_spin.setValue(self.canvas.pen_level2)

        pen_level3_spin = QSpinBox()
        pen_level3_spin.setRange(1, 50)
        pen_level3_spin.setValue(self.canvas.pen_level3)

        erase_level1_spin = QSpinBox()
        erase_level1_spin.setRange(1, 50)
        erase_level1_spin.setValue(self.canvas.erase_level1)

        erase_level2_spin = QSpinBox()
        erase_level2_spin.setRange(1, 50)
        erase_level2_spin.setValue(self.canvas.erase_level2)

        erase_level3_spin = QSpinBox()
        erase_level3_spin.setRange(1, 50)
        erase_level3_spin.setValue(self.canvas.erase_level3)

        def _apply_pen_levels():
            self.canvas.set_pen_thresholds(
                pen_level1_spin.value(),
                pen_level2_spin.value(),
                pen_level3_spin.value(),
            )
            pen_level1_spin.setValue(self.canvas.pen_level1)
            pen_level2_spin.setValue(self.canvas.pen_level2)
            pen_level3_spin.setValue(self.canvas.pen_level3)

        def _apply_erase_levels():
            self.canvas.set_erase_thresholds(
                erase_level1_spin.value(),
                erase_level2_spin.value(),
                erase_level3_spin.value(),
            )
            erase_level1_spin.setValue(self.canvas.erase_level1)
            erase_level2_spin.setValue(self.canvas.erase_level2)
            erase_level3_spin.setValue(self.canvas.erase_level3)

        pen_level1_spin.valueChanged.connect(_apply_pen_levels)
        pen_level2_spin.valueChanged.connect(_apply_pen_levels)
        pen_level3_spin.valueChanged.connect(_apply_pen_levels)

        erase_level1_spin.valueChanged.connect(_apply_erase_levels)
        erase_level2_spin.valueChanged.connect(_apply_erase_levels)
        erase_level3_spin.valueChanged.connect(_apply_erase_levels)

        grid_check = QCheckBox("Show Grid")
        grid_check.setChecked(True)
        grid_check.stateChanged.connect(lambda v: self.canvas.set_show_grid(v == Qt.Checked))

        pen_heat_check = QCheckBox("Pen Heat")
        pen_heat_check.setChecked(True)
        pen_heat_check.stateChanged.connect(lambda v: self.canvas.set_show_pen_heat(v == Qt.Checked))

        erase_heat_check = QCheckBox("Erase Heat")
        erase_heat_check.setChecked(True)
        erase_heat_check.stateChanged.connect(lambda v: self.canvas.set_show_erase_heat(v == Qt.Checked))

        undo_add_spin = QSpinBox()
        undo_add_spin.setRange(1, 20)
        undo_add_spin.setValue(5)

        undo_add_btn = QPushButton("Undo +N")
        undo_add_btn.clicked.connect(lambda: self._add_undo(undo_add_spin.value()))

        settings_layout.addWidget(QLabel("Grid"))
        settings_layout.addWidget(grid_spin)
        settings_layout.addWidget(QLabel("Canvas W/H"))
        settings_layout.addWidget(width_spin)
        settings_layout.addWidget(height_spin)
        settings_layout.addWidget(QLabel("Gap Threshold"))
        settings_layout.addWidget(gap_spin)
        settings_layout.addWidget(QLabel("Pen L1/L2/L3"))
        settings_layout.addWidget(pen_level1_spin)
        settings_layout.addWidget(pen_level2_spin)
        settings_layout.addWidget(pen_level3_spin)
        settings_layout.addWidget(QLabel("Erase L1/L2/L3"))
        settings_layout.addWidget(erase_level1_spin)
        settings_layout.addWidget(erase_level2_spin)
        settings_layout.addWidget(erase_level3_spin)
        settings_layout.addWidget(pen_heat_check)
        settings_layout.addWidget(erase_heat_check)
        settings_layout.addWidget(QLabel("Undo Add"))
        settings_layout.addWidget(undo_add_spin)
        settings_layout.addWidget(undo_add_btn)
        settings_layout.addWidget(grid_check)
        settings_layout.addStretch(1)
        settings.setLayout(settings_layout)

        root.addLayout(controls)
        root.addWidget(settings)
        root.addWidget(self.info_label)
        root.addWidget(self.metric_label)

        self.setLayout(root)

    def _on_undo(self):
        self.canvas.undo()
        self._sync_info()

    def _on_clear(self):
        self.canvas.clear_all()
        self._sync_info()

    def _add_undo(self, count):
        self.canvas.undo_counter += count
        self._sync_info()

    def _sync_info(self):
        self.info_label.setText(
            f"stroke={self.canvas.pen_stroke_count} | undo={self.canvas.undo_counter} | last-highlight={self.canvas.highlight_last_reason}"
        )
        erase_total = self.canvas.sum_counts(self.canvas.erase_counts)
        rewrite_total = self.canvas.sum_overlap(self.canvas.pen_counts, self.canvas.erase_counts)
        self.metric_label.setText(
            f"erase_total={erase_total} | rewrite_total={rewrite_total}"
        )


def main():
    app = QApplication(sys.argv)
    window = HeatmapSimulator()
    window.resize(1000, 720)
    window.show()
    sys.exit(app.exec_())


if __name__ == "__main__":
    main()
