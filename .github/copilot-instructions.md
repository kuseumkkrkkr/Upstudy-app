# AIFlow Flutter App - Coding Instructions

## Architecture Overview

**AIFlow** is a Flutter web/mobile app with a modular architecture that separates concerns:

- **Entry Point** (`main.dart`): Simple MaterialApp configuration with no business logic
- **Pages** (`lib/pages/`): Screen-level widgets (currently `MainpageWidget`) managing state and layout
- **Widgets** (`lib/widgets/`): Reusable UI components (`HeaderBar`, `MenuButton`) - pure presentation
- **Services** (`lib/services/`): Cross-cutting concerns like dialog management (`DialogService`)
- **Dialogs** (`lib/dialogs/`): Dialog-specific UI components (future expansion for custom dialogs)

**Data Flow**: Menu items (hardcoded in `_MainpageWidgetState`) → MenuButton component → DialogService.openDialog()

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
import '../widgets/menu_button.dart';
```

## Key Patterns

### Dialog Management
Dialog opening is centralized in `DialogService.openDialog()`. All dialogs flow through this:
- Takes `BuildContext` and `title` parameter
- Returns empty dialog UI (intentional - expand per feature needs)
- Called from page widgets: `DialogService.openDialog(context, title: '빠른 생성')`

### Component Callbacks
Widgets receive callbacks rather than managing state:
```dart
// HeaderBar receives VoidCallbacks
HeaderBar(
  onSearchPressed: () => DialogService.openDialog(context),
  onMenuPressed: () => DialogService.openDialog(context),
)

// MenuButton receives onTap callback
MenuButton(
  title: item['title']!,
  onTap: () => _onMenuItemPressed(item['title']!),
)
```

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

- **flutter/material.dart**: Material Design (required)
- **google_fonts**: Custom font support (Inter family)
- Avoid adding large dependencies; prioritize Flutter's built-in APIs

## Conventions

- **Naming**: PascalCase for classes/widgets, camelCase for methods/variables
- **Korean Comments**: Codebase uses Korean comments (preserve this style)
- **const Constructors**: Always use `const` for widgets when possible (StatelessWidget by default)
- **BuildContext param**: Pages/services receive context for navigation/dialogs, not stored as state
