# Graph Tools Session

This session handles JSX graph rendering and embedding for mathematical graph tools.

## Structure

- `session/` – Entry pages and session-level logic
- `ui/pages/` – Page-level widgets
- `ui/widgets/` – Reusable widgets (JSX graph embed variants: web, native, stub)
- `ui/modals/` – Dialogs and bottom sheets
- `shared/` – Models and utilities shared within the session
- `business/` – Business logic and state management

## Moved Files

- `lib/pages/jsx_graph_page.dart` -> `session/jsx_graph_page.dart`
- `lib/pages/jsx_graph_embed.dart` -> `ui/widgets/jsx_graph_embed.dart`
- `lib/pages/jsx_graph_embed_web.dart` -> `ui/widgets/jsx_graph_embed_web.dart`
- `lib/pages/jsx_graph_embed_native.dart` -> `ui/widgets/jsx_graph_embed_native.dart`
- `lib/pages/jsx_graph_embed_stub.dart` -> `ui/widgets/jsx_graph_embed_stub.dart`
