# AIFlow Flutter App - Coding Instructions

## Architecture Overview

**AIFlow** is a Flutter web/mobile app for exam content generation with modular architecture:

- **Entry Point** (`main.dart`): MaterialApp configuration only - no business logic
- **Pages** (`lib/pages/`): `MainpageWidget` - stateful screen with menu items and header
- **Widgets** (`lib/widgets/`): `HeaderBar` - reusable top navigation bar with search/menu callbacks
- **Services** (`lib/services/`): `DialogService.openDialog()` - centralized dialog management
- **Dialogs** (`lib/dialogs/`): `BuildboxWidget` (main dialog container), `ConceptTagDialog` (hierarchical tag picker)
- **Models** (`lib/models/`): `ConceptTag` - tree-structured concept data with expand/select states

**Data Flow**: MainpageWidget menu list → DialogService.openDialog(context, title) → BuildboxWidget displays with ConceptTagDialog integration

## File Organization Pattern

- **Keep `main.dart` lean**: Only MaterialApp config, no widgets beyond MyApp
- **Use pages/ for stateful screens**: Each page encapsulates its state, business logic, and menu data
- **Extract reusable UI to widgets/**: Use composition with callback functions (no complex state)
- **Use services/ for logic**: Static methods for cross-cutting concerns (dialogs, APIs, etc.)
- **Use lib/dialogs/ for dialog UIs**: Place dialog-specific widgets separate from main pages

**Example import structure**:
```dart
import 'package:flutter/material.dart';
import '../services/dialog_service.dart';
import '../widgets/header_bar.dart';
```

## Key Patterns

### Dialog Management
Dialog opening is centralized in `DialogService.openDialog()`. All dialogs flow through this:
- Takes `BuildContext` and `title` parameter
- Returns empty dialog UI (intentional - expand per feature needs)
- Called from page widgets: `DialogService.openDialog(context, title: '빠른 생성')`

### Component Callbacks
Widgets receive callbacks for interactivity - no widget should manage page-level state:
```dart
// HeaderBar in MainpageWidget
HeaderBar(
  onSearchPressed: () => DialogService.openDialog(context, title: '검색'),
  onMenuPressed: () => DialogService.openDialog(context, title: '메뉴'),
)

// ConceptTagDialog callback pattern
ConceptTagDialog(
  onTagsSelected: (tags) {
    // Handle selected tags, update parent state
    Navigator.pop(context);
  },
)
```

### ConceptTag Model (Hierarchical Data)
`ConceptTag` represents exam concepts in a tree structure with selection/expansion state:
- **Properties**: `name`, `displayName`, `children` (recursive), `isExpanded`, `isSelected`
- **Used in**: `ConceptTagDialog` for multi-level tag selection (deep copy pattern to preserve original data)
- **Pattern**: Dialog manages tag state locally, returns selected tags via callback to parent

### Typography & Styling
- Use `google_fonts/google_fonts.dart` for custom fonts (Inter family used throughout)
- Color scheme: `Color(0xFF1B402B)` for header (dark green), `Colors.grey[100]` for backgrounds
- Apply consistent GoogleFonts.inter() styling to all Text widgets

## Development Workflow

### Running the App
```bash
# Web (Chrome debugging)
flutter run -d chrome

# Mobile (Android/iOS)
flutter run -d android
flutter run -d ios
```

### Adding New Menu Items
1. Add to `menuItems` list in `MainpageWidget` with `title` and `image` URL
2. Update `_onMenuItemPressed()` if feature-specific logic is needed
3. No other files need changes (composition handles the rest)

### Adding New Features
1. If it's a dialog feature, update `DialogService.openDialog()` to build different UIs based on title
2. If it's a new page, create `lib/pages/new_page.dart` and update `main.dart` home route
3. Always extract common widgets to `lib/widgets/`

## Dependencies

- **flutter/material.dart**: Material Design UI components
- **google_fonts**: Custom fonts (Inter family used throughout for headers and text)
- **flutter_slidable** (^3.0.0): Swipe actions for list items in dialogs
- Minimize external dependencies; leverage Flutter's built-in Material Design

## Conventions

- **Naming**: PascalCase for classes/widgets, camelCase for methods/variables
- **Korean Comments**: Codebase uses Korean comments (preserve this style)
- **const Constructors**: Always use `const` for widgets when possible (StatelessWidget by default)
- **BuildContext param**: Pages/services receive context for navigation/dialogs, not stored as state
