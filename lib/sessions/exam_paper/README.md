# exam_paper Session

Migrated from `lib/pages/exam_paper_page.dart` + `lib/pages/exam_paper/`

## Structure

```
lib/sessions/exam_paper/
├── session/
│   └── exam_paper_page.dart      # Library file (ExamPaperPage widget)
├── business/
│   ├── exam_paper_state.dart            # Base state class
│   ├── exam_paper_state_interaction.dart # Zoom, pan, stroke input, undo
│   ├── exam_paper_state_grading.dart     # Grading, heatmap, submission
│   └── exam_paper_layout.dart           # 2×2 page layout algorithm
├── shared/
│   └── exam_paper_models.dart           # Data models (Stroke, GradeResult, etc.)
└── ui/
    ├── exam_paper_state_ui.dart          # Build methods, main UI
    ├── exam_paper_content.dart           # Exam paper page rendering
    ├── exam_grading_report_page.dart     # Grading report screen
    ├── exam_paper_toolbar_widgets.dart   # Toolbar icon widgets
    ├── exam_paper_painter.dart           # Custom painters
    └── mini_chooser.dart                 # Compact button group widgets
```

## Shim files

Original paths remain as shims exporting the new locations:

- `lib/pages/exam_paper_page.dart` → `lib/sessions/exam_paper/session/exam_paper_page.dart`
- `lib/pages/exam_paper/logic/*.dart` → stub comments
- `lib/pages/exam_paper/models/*.dart` → stub comments
- `lib/pages/exam_paper/widgets/*.dart` → stub comments
