# AIFlow Project Instructions

## Repo Map
- `lib/`: Main Flutter app (Dart).
- `landpage/`: Landing page Flutter app (Dart).
- `omj/`: Backend API server (FastAPI, Python).

## General
- Keep source files and text assets in UTF-8. If Korean strings look garbled, fix encoding before commit.
- Avoid debug `print` in UI code; use logging or remove.
- Keep `main.dart` lean; push logic into pages/services/widgets.

## Flutter (lib/, landpage/)
- Use `LayoutBuilder` constraints to choose responsive layouts; avoid hard-coding mobile-only layouts.
- For remote images, add placeholders/error handling or use assets for critical backgrounds.
- Prefer `const` widgets and reuse theme styles.

## Backend (omj/)
- Prefer auth tokens in the `Authorization` header; avoid query-string tokens.
- Limit concurrent generation work; batch or add a semaphore in exam-generation paths.
- Use response models for endpoints and raise `HTTPException` with clear messages.

## Files
- Canonical instructions live in this file.
- `.github/copilot-instructions.md` should remain a short summary and pointer here.