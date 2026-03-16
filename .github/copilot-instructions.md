# AIFlow Coding Instructions (Summary)

Canonical instructions: `md_store/INSTRUCTIONS.md`

## Repo Layout
- `lib/`: main Flutter app (Dart).
- `landpage/`: landing page Flutter app (Dart).
- `omj/`: backend API server (FastAPI, Python).

## Flutter Patterns
- Keep `main.dart` lean: MaterialApp config only.
- `pages/`: stateful screens.
- `widgets/`: reusable UI with callbacks.
- `services/`: cross-cutting logic (dialogs, APIs).
- `dialogs/`: dialog UI components.
- Use GoogleFonts Inter and the `0xFF1B402B` seed color scheme.

## Backend Patterns
- FastAPI app lives in `omj/server.py` with Pydantic request/response models.
- Auth via bearer tokens.
- CORS configured by `OMJ_CORS_ORIGINS`.

## Conventions
- Keep files UTF-8 to avoid garbled Korean text.
- Prefer `const` widgets.
- Avoid debug `print` in UI code.
