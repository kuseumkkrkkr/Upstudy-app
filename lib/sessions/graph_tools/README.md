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

- AIFlow-aligned compact header and card layout
- searchable subject example catalog
- JSXGraph-backed function, line, and scatter rendering
- fast viewport reset and zoom controls
- simple graph settings for axes, grid, degree mode, and viewport lock

## Platform Notes

- Web uses `iframe srcdoc`
- Native uses `InAppWebView`
- Rendering depends on the official `JSXGraph` CDN
