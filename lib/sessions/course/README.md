# Course Session

This directory contains the migrated course feature code originally located in `lib/pages/course_pages*`.

## Structure

| Path | Description |
|------|-------------|
| `session/` | Entrypoint barrel file and the learning page |
| `ui/` | Catalog and detail pages |
| `shared/` | Shared constants, color tokens, and small widgets used across the course UI |

## Files

- `session/course_pages.dart` - Barrel export for external consumers
- `session/course_learning_page.dart` - Active course learning view (units, missions, problems)
- `ui/course_catalog_page.dart` - Course listing/search with OVR-based recommendations
- `ui/course_detail_page.dart` - Course detail, enrollment, and unit overview
- `shared/shared.dart` - Common colors, scale helper, `MetaPill` widget

## Backward Compatibility

The original paths (`lib/pages/course_pages.dart`, `lib/pages/course_learning_page.dart`, `lib/pages/course_pages/*.dart`) still exist as shim files that export their new counterparts.


