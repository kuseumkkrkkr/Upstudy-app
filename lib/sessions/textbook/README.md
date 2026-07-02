# Textbook Session

This session handles textbook content, DOCX rendering, study modes, and editor functionality.

## Structure

- `session/` – Entry pages and session-level logic
- `ui/pages/` – Page-level widgets (book, docx)
- `ui/modals/` – Dialogs and bottom sheets (buildbox, concept tags, web fixed dialog, book mode)
- `ui/widgets/` – Reusable widgets
- `shared/` – Models and utilities shared within the session
- `business/` – Business logic and state management

## Moved Files

- `lib/pages/textbook_editor_page.dart` -> `session/textbook_editor_page.dart`
- `lib/book_page.dart` -> `ui/pages/book_page.dart`
- `lib/docx_box.dart` -> `ui/pages/docx_box.dart`
- `lib/dialogs/buildbox_widget.dart` -> `ui/modals/buildbox_widget.dart`
- `lib/dialogs/concept_tag_dialog.dart` -> `ui/modals/concept_tag_dialog.dart`
- `lib/dialogs/web_fixed_dialog.dart` -> `ui/modals/web_fixed_dialog.dart`
- `lib/widgets/modals/study_modes/book_mode.dart` -> `ui/modals/book_mode.dart`
