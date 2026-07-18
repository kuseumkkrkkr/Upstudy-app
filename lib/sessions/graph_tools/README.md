# Graph Tools Session

This session provides the `AIFlow Graph` experience: a concise AIFlow-style graph explorer backed by `JSXGraph`.

## Structure

- `session/` – page entry points
- `ui/widgets/` – platform-specific HTML embed adapters
- `shared/aiflow_graph_document.dart` – graph scene document API
- `shared/aiflow_graph_example_catalog.dart` – searchable subject example catalog
- `shared/jsx_graph_html_builder.dart` – HTML renderer builder
- `API.md` – public session API and renderer contract

## Current UX Goals

- shared app bar actions with no duplicate graph-title header
- blank direct-expression workspace on first entry
- searchable subject example catalog
- JSXGraph-backed function, line, and scatter rendering
- direct grid presentation with compact +/- zoom and drag/touch panning
- simple graph settings for axes, grid, degree mode, and viewport lock

`JsxGraphPage` is an independent student practice tool, not a textbook graph
authoring surface. Textbook readers receive completed graph documents and keep
their embedded parameter controls; this page keeps editing controls in its
right-side panel and uses catalog examples only when the student explicitly
loads one. While the global drawer is open, the platform graph view is removed
temporarily so the drawer remains the active touch layer.

## Platform Notes

- Web uses `iframe srcdoc`
- Native uses `InAppWebView`
- Rendering depends on the official `JSXGraph` CDN
